import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/providers/focus_mode_provider.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/core/providers/workspace_tabs_provider.dart';
import 'package:frontend/features/app_update/providers/app_update_providers.dart';
import 'package:frontend/features/app_update/widgets/update_banner.dart';
import 'package:frontend/features/app_update/widgets/update_dialog.dart';
import 'package:frontend/features/app_update/widgets/update_indicator_pill.dart';
import 'package:frontend/features/app_update/widgets/update_notifier_host.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:frontend/features/home/widgets/multi_tab_workspace_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_app_update_service.dart';
import 'helpers/localized_app.dart';

const _screenSize = Size(1920, 1080);
const en = AppLocalizationsEn();

Future<ProviderContainer> _pumpHome(
  WidgetTester tester,
  FakeAppUpdateService fake, {
  bool focus = false,
  bool twoTabs = false,
}) async {
  tester.view.physicalSize = _screenSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(overrides: [
    navigationIndexProvider.overrideWith((ref) => 32),
    appUpdateServiceProvider.overrideWithValue(fake),
    canInstallUpdatesProvider.overrideWithValue(true),
    updateUserIdProvider.overrideWithValue(1),
  ]);
  addTearDown(container.dispose);
  container.read(localeProvider.notifier).setLocale(AppLocales.english);
  if (focus) container.read(focusModeProvider.notifier).enable();
  if (twoTabs) {
    // A second tab shows MultiTabWorkspaceBar, a conditional Column child AFTER the
    // old host position: this is the layout where an unkeyed host got re-created.
    container.read(workspaceTabsProvider.notifier).openTab(
          id: 'import_companies',
          title: 'Import Companies',
          icon: Icons.business_outlined,
          routeIndex: 32,
        );
  }

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: localizedApp(locale: AppLocales.english, home: const HomeScreen()),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

Future<void> _drain(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
  // Dispose the tree (and the host's 24 h timer) before the pending-timer check;
  // the extra pump flushes zero-delay Dio timers of the dashboard providers.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// The dark sidebar container (full width 255).
Finder _sidebar() => find.byWidgetPredicate(
      (w) => w is AnimatedContainer && w.constraints?.maxWidth == 255,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the update pill sits in the sidebar footer and the host is mounted', (tester) async {
    await _pumpHome(tester, FakeAppUpdateService(check: optionalCheck));

    final pill = find.descendant(of: _sidebar(), matching: find.byType(UpdateIndicatorPill));
    expect(pill, findsOneWidget);
    expect(find.descendant(of: pill, matching: find.text(en.updatePillAvailable('2.1.0'))), findsOneWidget);
    // Footer = bottom of the sidebar.
    expect(tester.getRect(pill).bottom, greaterThan(_screenSize.height - 60));
    expect(find.byType(UpdateNotifierHost), findsOneWidget);
    expect(find.byType(UpdateBanner), findsOneWidget);

    await _drain(tester);
  });

  testWidgets('focus mode: banner and sidebar hidden, host still mounted and opens the mandatory dialog',
      (tester) async {
    await _pumpHome(tester, FakeAppUpdateService(check: mandatoryCheck), focus: true);
    await tester.pump();

    expect(find.byType(UpdateBanner), findsNothing);
    expect(find.byType(UpdateIndicatorPill), findsNothing);
    expect(find.byType(UpdateNotifierHost), findsOneWidget);
    expect(find.byType(UpdateDialog), findsOneWidget);
    expect(find.byKey(UpdateDialog.signOutKey), findsOneWidget);

    await _drain(tester);
  });

  testWidgets('toggling focus mode keeps the same host (no remount, no extra /check)', (tester) async {
    final fake = FakeAppUpdateService(check: optionalCheck);
    final container = await _pumpHome(tester, fake, twoTabs: true);
    expect(find.byType(MultiTabWorkspaceBar), findsOneWidget);
    final hostState = tester.state(find.byType(UpdateNotifierHost));
    expect(fake.checkCalls, 1);
    final statusCalls = fake.statusCalls;

    for (var i = 0; i < 3; i++) {
      container.read(focusModeProvider.notifier).toggle();
      await tester.pump();
      await tester.pump();
      expect(find.byType(UpdateNotifierHost), findsOneWidget);
      expect(tester.state(find.byType(UpdateNotifierHost)), same(hostState));
    }
    expect(fake.checkCalls, 1, reason: 'a remount would re-check the cached result');
    expect(fake.statusCalls, statusCalls);

    await _drain(tester);
  });
}
