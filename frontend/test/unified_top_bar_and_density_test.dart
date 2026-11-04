import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/providers/focus_mode_provider.dart';
import 'package:frontend/core/providers/workspace_tabs_provider.dart';
import 'package:frontend/core/theme/density_provider.dart';
import 'package:frontend/core/widgets/system_live_clock_widget.dart';
import 'package:frontend/core/widgets/unified_top_bar.dart';

void main() {
  group('DisplayDensityMode Expansion Tests', () {
    test('Density modes contain correct topBarHeight, tabBarHeight, and tableRowHeight', () {
      expect(DisplayDensityMode.comfortable.topBarHeight, equals(44.0));
      expect(DisplayDensityMode.compact.topBarHeight, equals(38.0));
      expect(DisplayDensityMode.ultraCompact.topBarHeight, equals(32.0));

      expect(DisplayDensityMode.comfortable.tabBarHeight, equals(30.0));
      expect(DisplayDensityMode.compact.tabBarHeight, equals(28.0));
      expect(DisplayDensityMode.ultraCompact.tabBarHeight, equals(26.0));

      expect(DisplayDensityMode.comfortable.tableRowHeight, equals(52.0));
      expect(DisplayDensityMode.compact.tableRowHeight, equals(42.0));
      expect(DisplayDensityMode.ultraCompact.tableRowHeight, equals(34.0));

      expect(DisplayDensityMode.comfortable.contentPadding, equals(const EdgeInsets.all(16.0)));
      expect(DisplayDensityMode.compact.contentPadding, equals(const EdgeInsets.all(10.0)));
      expect(DisplayDensityMode.ultraCompact.contentPadding, equals(const EdgeInsets.all(6.0)));
    });
  });

  group('FocusModeNotifier Tests', () {
    test('defaults to false and toggles correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(focusModeProvider), isFalse);

      container.read(focusModeProvider.notifier).enable();
      expect(container.read(focusModeProvider), isTrue);

      container.read(focusModeProvider.notifier).toggle();
      expect(container.read(focusModeProvider), isFalse);

      container.read(focusModeProvider.notifier).disable();
      expect(container.read(focusModeProvider), isFalse);
    });
  });

  group('WorldClockDropdownButton Widget Tests', () {
    testWidgets('renders pinned default country (Egypt) and formatted time', (tester) async {
      final refUtc = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: WorldClockDropdownButton(
                  currentTimeUtc: refUtc,
                  isArabic: true,
                  defaultCountryKey: 'egypt',
                ),
              ),
            ),
          ),
        ),
      );

      // Egypt in summer is UTC+3 -> 15:00
      expect(find.text('مصر 15:00'), findsOneWidget);
      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    testWidgets('renders English name when isArabic is false', (tester) async {
      final refUtc = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WorldClockDropdownButton(
                currentTimeUtc: refUtc,
                isArabic: false,
                defaultCountryKey: 'egypt',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Egypt 15:00'), findsOneWidget);
    });

    testWidgets('tapping dropdown button opens popup menu with all 7 countries', (tester) async {
      final refUtc = DateTime.utc(2026, 9, 10, 12, 0, 0);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Center(
                  child: WorldClockDropdownButton(
                    currentTimeUtc: refUtc,
                    isArabic: true,
                    defaultCountryKey: 'egypt',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap on the dropdown button
      await tester.tap(find.byType(WorldClockDropdownButton));
      await tester.pumpAndSettle();

      // Verify header contains title, date & week badge, and all 7 countries
      expect(find.text('التوقيت الدولي وساعات العمل'), findsOneWidget);
      expect(find.byType(SystemDateWeekBadge), findsOneWidget);
      expect(find.text('الخميس'), findsOneWidget);
      expect(find.text('2026-09-10'), findsOneWidget);
      expect(find.text('الأسبوع: W37'), findsOneWidget);
      expect(find.text('مصر'), findsOneWidget);
      expect(find.text('فرنسا وإيطاليا وإسبانيا'), findsOneWidget);
      expect(find.text('إنجلترا'), findsOneWidget);
      expect(find.text('تركيا وليتوانيا'), findsOneWidget);
      expect(find.text('الصين'), findsOneWidget);
      expect(find.text('الإمارات'), findsOneWidget);
      expect(find.text('أمريكا'), findsOneWidget);

      // Selecting another country (e.g. China) updates the button
      await tester.tap(find.text('الصين'));
      await tester.pumpAndSettle();

      // China at UTC 12:00 is UTC+8 -> 20:00
      expect(find.text('الصين 20:00'), findsOneWidget);
    });
  });

  group('UnifiedTopBar Widget Tests', () {
    testWidgets('renders brand, breadcrumbs, world clock dropdown, and shortcuts in single row', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: UnifiedTopBar(),
                ),
              ),
            ),
          ),
        ),
      );

      // 1. App Brand
      expect(find.text('سرور'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);

      // 2. Breadcrumbs
      expect(find.text('الرئيسية'), findsOneWidget);

      // 3. World Clocks Dropdown
      expect(find.byType(WorldClockDropdownButton), findsOneWidget);

      // 4. Live sync beacon
      expect(find.text('24H LIVE'), findsOneWidget);
    });

    testWidgets('breadcrumbs reflect active tab when tab is selected', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Open a stage tab: PO & Packing Reconciliation (routeIndex: 21)
      container.read(workspaceTabsProvider.notifier).openTab(
            id: 'po_packing_recon',
            title: 'مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء',
            icon: Icons.fact_check_outlined,
            routeIndex: 21,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: UnifiedTopBar(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text(' / '), findsOneWidget);
      expect(find.text('مراجعة مسودات بوالص الشحن'), findsOneWidget);
    });
  });
}
