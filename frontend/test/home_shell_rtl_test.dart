import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/core/widgets/directional_icon.dart';
import 'package:frontend/features/home/home_screen.dart';

import 'helpers/localized_app.dart';

const _screenSize = Size(1920, 1080);

Future<void> _pumpShell(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = _screenSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(overrides: [
    // Import Companies (32) is inside the first hub, so its selected row is visible
    // once the hub is expanded.
    navigationIndexProvider.overrideWith((ref) => 32),
  ]);
  addTearDown(container.dispose);
  container.read(localeProvider.notifier).setLocale(locale);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: localizedApp(locale: locale, home: const HomeScreen()),
  ));
  await tester.pump();
}

Future<void> _drain(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

/// The dark sidebar container (full width 255).
Finder _sidebar() => find.byWidgetPredicate(
      (w) => w is AnimatedContainer && w.constraints?.maxWidth == 255,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Home shell direction', () {
    testWidgets('Arabic: sidebar sits on the right edge, content to its left', (tester) async {
      await _pumpShell(tester, AppLocales.arabic);

      final ctx = tester.element(find.byType(HomeScreen));
      expect(Directionality.of(ctx), TextDirection.rtl);

      final rect = tester.getRect(_sidebar());
      expect(rect.right, moreOrLessEquals(_screenSize.width));
      expect(rect.left, moreOrLessEquals(_screenSize.width - 255));

      // Hub title text is inside the right-hand sidebar.
      final hub = tester.getCenter(find.text('البيانات والجداول الأساسية'));
      expect(hub.dx, greaterThan(_screenSize.width - 255));

      await _drain(tester);
    });

    testWidgets('English: sidebar stays on the left edge', (tester) async {
      await _pumpShell(tester, AppLocales.english);

      final rect = tester.getRect(_sidebar());
      expect(rect.left, moreOrLessEquals(0));
      expect(tester.getCenter(find.text('Master Data & Tables')).dx, lessThan(255));

      await _drain(tester);
    });

    testWidgets('Arabic: collapse arrow is mirrored (points to the right-hand edge)', (tester) async {
      await _pumpShell(tester, AppLocales.arabic);

      final collapse = find.byWidgetPredicate(
          (w) => w is DirectionalIcon && w.icon == Icons.keyboard_double_arrow_left);
      expect(collapse, findsOneWidget);
      final flip = tester.widget<Transform>(
          find.descendant(of: collapse, matching: find.byType(Transform)).first);
      expect(flip.transform.storage[0], -1.0);

      await _drain(tester);
    });

    testWidgets('Arabic: selected menu item accent border is on the start (right) side', (tester) async {
      await _pumpShell(tester, AppLocales.arabic);

      await tester.tap(find.text('البيانات والجداول الأساسية'));
      await tester.pumpAndSettle();

      final item = find.text('الشركات المستوردة');
      expect(item, findsOneWidget);
      // Selecting opens the screen as the active tab, which marks the row selected.
      await tester.tap(item);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final border = tester
          .widgetList<Container>(find.ancestor(of: item, matching: find.byType(Container)))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<BorderDirectional>()
          .first;
      expect(border.start.width, 3);
      expect(border.end, BorderSide.none);

      await _drain(tester);
    });
  });
}
