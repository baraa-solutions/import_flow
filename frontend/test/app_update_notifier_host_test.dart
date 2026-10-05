import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/app_update/models/update_models.dart';
import 'package:frontend/features/app_update/providers/app_update_providers.dart';
import 'package:frontend/features/app_update/widgets/update_banner.dart';
import 'package:frontend/features/app_update/widgets/update_dialog.dart';
import 'package:frontend/features/app_update/widgets/update_indicator_pill.dart';
import 'package:frontend/features/app_update/widgets/update_notifier_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_app_update_service.dart';

const en = AppLocalizationsEn();

Widget _app({
  required FakeAppUpdateService fake,
  required Widget child,
  bool admin = true,
  int userId = 1,
  List<Override> extra = const [],
}) {
  return ProviderScope(
    overrides: [
      appUpdateServiceProvider.overrideWithValue(fake),
      canInstallUpdatesProvider.overrideWithValue(admin),
      updateUserIdProvider.overrideWithValue(userId),
      updatePollIntervalProvider.overrideWithValue(const Duration(milliseconds: 5)),
      ...extra,
    ],
    child: AppLocalizationsProvider(
      locale: const Locale('en'),
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

/// Replaces the tree so ProviderScope (and its timers) are disposed before
/// the end-of-test pending-timer check.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

const _ready = UpdateStatus(state: UpdateState.ready, version: '2.1.0');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UpdateNotifierHost', () {
    testWidgets('opens the mandatory dialog even without the banner (focus mode)', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(fake: FakeAppUpdateService(check: mandatoryCheck), child: const UpdateNotifierHost()));
      await tester.pumpAndSettle();

      expect(find.byType(UpdateBanner), findsNothing);
      expect(find.byType(UpdateDialog), findsOneWidget);
      expect(find.byKey(UpdateDialog.remindLaterKey), findsNothing);
      expect(find.byKey(UpdateDialog.signOutKey), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('mandatory dialog opens once per version', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(check: mandatoryCheck);
      await tester.pumpWidget(_app(fake: fake, child: const UpdateNotifierHost()));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsOneWidget);

      // A re-check returning the same version must not stack a second dialog.
      await tester.pump(const Duration(hours: 24));
      await tester.pumpAndSettle();
      expect(fake.checkCalls, 2);
      expect(find.byType(UpdateDialog), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('optional update never auto-opens the dialog', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(fake: FakeAppUpdateService(check: optionalCheck), child: const UpdateNotifierHost()));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsNothing);
      await _unmount(tester);
    });

    testWidgets('checks once on first mount, re-checks a cached result on remount and every 24 h', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService();
      await tester.pumpWidget(_app(fake: fake, child: const UpdateNotifierHost()));
      await tester.pumpAndSettle();
      expect(fake.checkCalls, 1);
      expect(fake.statusCalls, 1);

      await tester.pumpWidget(_app(fake: fake, child: const SizedBox()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(fake: fake, child: const UpdateNotifierHost()));
      await tester.pumpAndSettle();
      expect(fake.checkCalls, 2);
      expect(fake.statusCalls, 2);

      await tester.pump(const Duration(hours: 24));
      await tester.pumpAndSettle();
      expect(fake.checkCalls, 3);
      expect(fake.statusCalls, 3);
      await _unmount(tester);
    });

    testWidgets('ready SnackBar is shown to admins once per version', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(check: optionalCheck, statuses: const [_ready]);
      await tester.pumpWidget(_app(fake: fake, child: const UpdateNotifierHost()));
      await tester.pumpAndSettle();
      expect(find.text(en.updateReadySnack('2.1.0')), findsOneWidget);
      expect(find.byKey(UpdateNotifierHost.readySnackInstallKey), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('app_update_ready_announced_1'), '2.1.0');

      // Restart (new ProviderScope, same prefs): not announced again.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(fake: fake, child: const UpdateNotifierHost()));
      await tester.pumpAndSettle();
      expect(find.text(en.updateReadySnack('2.1.0')), findsNothing);
      await _unmount(tester);
    });

    testWidgets('ready SnackBar is not shown to non-admins', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(check: optionalCheck, statuses: const [_ready]);
      await tester.pumpWidget(_app(fake: fake, admin: false, child: const UpdateNotifierHost()));
      await tester.pumpAndSettle();
      expect(find.text(en.updateReadySnack('2.1.0')), findsNothing);
      await _unmount(tester);
    });

    testWidgets('SnackBar Install action applies the update', (tester) async {
      _bigView(tester);
      var exited = 0;
      final fake = FakeAppUpdateService(check: optionalCheck, statuses: const [_ready]);
      await tester.pumpWidget(_app(
        fake: fake,
        child: const UpdateNotifierHost(),
        extra: [appExitProvider.overrideWithValue(() => exited++)],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateNotifierHost.readySnackInstallKey));
      await tester.pump();
      await tester.pump();
      expect(fake.calls, contains('apply:2.1.0'));
      await tester.pump(updateExitDelay);
      expect(exited, 1);
      await _unmount(tester);
    });

    testWidgets('a newer release clears the stored snooze of the older one', (tester) async {
      _bigView(tester);
      SharedPreferences.setMockInitialValues({
        'app_update_snooze_1': '2.0.9|${DateTime.now().toUtc().toIso8601String()}',
      });
      await tester.pumpWidget(_app(
        fake: FakeAppUpdateService(check: optionalCheck),
        child: const Column(children: [UpdateNotifierHost(), UpdateBanner()]),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateBanner.remindLaterKey), findsOneWidget);
      expect((await SharedPreferences.getInstance()).containsKey('app_update_snooze_1'), isFalse);
      await _unmount(tester);
    });
  });

  group('UpdateBanner (slim)', () {
    testWidgets('remind me later is stored for that version and survives a restart', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(check: optionalCheck);
      await tester.pumpWidget(_app(fake: fake, child: const UpdateBanner()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateBanner.remindLaterKey));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateBanner.detailsKey), findsNothing);
      expect((await SharedPreferences.getInstance()).getString('app_update_snooze_1'), startsWith('2.1.0|'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(fake: fake, child: const UpdateBanner()));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateBanner.detailsKey), findsNothing);
      await _unmount(tester);
    });

    testWidgets('snooze of one user does not hide the banner for another user', (tester) async {
      _bigView(tester);
      SharedPreferences.setMockInitialValues({
        'app_update_snooze_1': '2.1.0|${DateTime.now().toUtc().toIso8601String()}',
      });
      await tester.pumpWidget(_app(fake: FakeAppUpdateService(check: optionalCheck), userId: 2, child: const UpdateBanner()));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateBanner.detailsKey), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('ready: emerald Install now for admins only', (tester) async {
      _bigView(tester);
      final fake = FakeAppUpdateService(check: optionalCheck, statuses: const [_ready]);
      await tester.pumpWidget(_app(fake: fake, child: const UpdateBanner()));
      await tester.pumpAndSettle();
      expect(find.text(en.updateReadyBanner('2.1.0')), findsOneWidget);
      expect(find.byKey(UpdateBanner.installKey), findsOneWidget);
      expect(find.byKey(UpdateBanner.remindLaterKey), findsNothing);

      await tester.pumpWidget(_app(fake: fake, admin: false, child: const UpdateBanner()));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateBanner.installKey), findsNothing);
      await _unmount(tester);
    });

    testWidgets('download shows inline progress sized by the installer', (tester) async {
      _bigView(tester);
      // Older backend: total = installer + rollback copy.
      final fake = FakeAppUpdateService(check: optionalCheck, statuses: [
        const UpdateStatus(
          state: UpdateState.downloading,
          version: '2.1.0',
          downloadedBytes: 212650000 ~/ 2,
          totalBytes: 212650000 + 150000000,
        ),
      ]);
      await tester.pumpWidget(_app(fake: fake, child: const UpdateBanner()));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(UpdateBanner.progressKey), findsOneWidget);
      expect(find.text(en.updateDownloading('101.4', '202.8')), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('UpdateIndicatorPill', () {
    Future<void> pumpPill(WidgetTester tester, FakeAppUpdateService fake, {bool admin = true, bool compact = false}) async {
      _bigView(tester);
      await tester.pumpWidget(_app(
        fake: fake,
        admin: admin,
        child: Align(alignment: AlignmentDirectional.topStart, child: UpdateIndicatorPill(compact: compact)),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('hidden when up to date', (tester) async {
      await pumpPill(tester, FakeAppUpdateService());
      expect(find.byKey(UpdateIndicatorPill.pillKey), findsNothing);
      await _unmount(tester);
    });

    testWidgets('available, and still visible after remind me later', (tester) async {
      await pumpPill(tester, FakeAppUpdateService(check: optionalCheck));
      expect(find.text(en.updatePillAvailable('2.1.0')), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(UpdateIndicatorPill)));
      await container.read(updateSnoozeProvider.notifier).snooze('2.1.0');
      await tester.pump();
      expect(find.text(en.updatePillAvailable('2.1.0')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('mandatory', (tester) async {
      await pumpPill(tester, FakeAppUpdateService(check: mandatoryCheck));
      expect(find.text(en.updatePillMandatory('2.1.0')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('downloading shows a ring and the percent', (tester) async {
      await pumpPill(
        tester,
        FakeAppUpdateService(check: optionalCheck, statuses: const [
          UpdateStatus(state: UpdateState.downloading, version: '2.1.0', downloadedBytes: 21265000, totalBytes: 212650000),
        ]),
      );
      expect(find.text(en.updatePillDownloading('10')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('preparing rollback copy shows a ring', (tester) async {
      await pumpPill(
        tester,
        FakeAppUpdateService(check: optionalCheck, statuses: const [
          UpdateStatus(state: UpdateState.verifying, phase: UpdatePhase.rollbackCopy, downloadedBytes: 1, totalBytes: 4),
        ]),
      );
      expect(find.text(en.updatePreparingRollbackCopyShort), findsOneWidget);
      expect(tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value, 0.25);
      await _unmount(tester);
    });

    testWidgets('ready (admin) and failed (admin)', (tester) async {
      await pumpPill(tester, FakeAppUpdateService(check: optionalCheck, statuses: const [_ready]));
      expect(find.text(en.updatePillReady), findsOneWidget);
      await _unmount(tester);

      await pumpPill(
        tester,
        FakeAppUpdateService(check: optionalCheck, statuses: const [UpdateStatus(state: UpdateState.failed)]),
      );
      expect(find.text(en.updateFailed), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('non-admin: info only with the administrator tooltip', (tester) async {
      await pumpPill(tester, FakeAppUpdateService(check: optionalCheck, statuses: const [_ready]), admin: false);
      expect(find.text(en.updatePillReady), findsNothing);
      expect(find.text(en.updatePillAvailable('2.1.0')), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tooltip.message, contains(en.updateAdminRequiredTooltip));
      await _unmount(tester);
    });

    testWidgets('tap opens the update dialog', (tester) async {
      await pumpPill(tester, FakeAppUpdateService(check: optionalCheck));
      await tester.tap(find.byKey(UpdateIndicatorPill.pillKey));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsOneWidget);
      expect(find.text(en.updateDialogTitle('2.1.0')), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('lays out as a non-flex Row child in RTL (sidebar footer)', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(_app(
        fake: FakeAppUpdateService(check: mandatoryCheck),
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 240,
            child: Row(children: [Expanded(child: Text('v2.0.3 (Build 207)')), UpdateIndicatorPill()]),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(UpdateIndicatorPill.pillKey)).width,
          lessThanOrEqualTo(UpdateIndicatorPill.maxPillWidth));
      await _unmount(tester);
    });

    testWidgets('compact renders a dot without text and still opens the dialog', (tester) async {
      await pumpPill(tester, FakeAppUpdateService(check: mandatoryCheck), compact: true);
      expect(find.text(en.updatePillMandatory('2.1.0')), findsNothing);
      await tester.tap(find.byKey(UpdateIndicatorPill.pillKey));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateDialog), findsOneWidget);
      await _unmount(tester);
    });
  });
}
