import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/metric_card.dart';
import 'package:frontend/features/customs_clearance/widgets/drawing_samples_and_shortage_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockSamples = [
    {
      'sample_id': 'SMP-1001',
      'authority': 'الهيئة العامة للرقابة على الصادرات والواردات',
      'drawing_date': '2026-09-05',
      'receipt_no': 'REC-9911',
      'test_type': 'فحص كيميائي شامل',
      'status': 'PASSED',
      'notes': 'مطابق للمواصفات القياسية المصرية',
    },
    {
      'sample_id': 'SMP-1002',
      'authority': 'الهيئة القومية لسلامة الغذاء',
      'drawing_date': '2026-09-06',
      'receipt_no': 'REC-9912',
      'test_type': 'تحليل بكتيري',
      'status': 'PENDING',
      'notes': 'قيد المعايرة المعملية',
    },
  ];

  final mockShortages = [
    {
      'shortage_id': 'SHR-501',
      'container_no': 'CMAU-4567890',
      'item_desc': 'قطع غيار توربينات',
      'manifest_qty': '80',
      'landed_qty': '75',
      'shortage_qty': '5',
      'shortage_pct': '6.3',
      'action': 'DEDUCT_DUTY',
      'notes': 'محضر كسر رصاص بالميناء',
    },
  ];

  Widget buildTestWidget({Locale locale = const Locale('ar')}) {
    return MaterialApp(
      home: AppLocalizationsProvider(
        locale: locale,
        child: Scaffold(
          body: DrawingSamplesAndShortageTab(
            records: const [],
            drawnSamples: List.from(mockSamples),
            shortageProtocols: List.from(mockShortages),
          ),
        ),
      ),
    );
  }

  group('Screen 60: DrawingSamplesAndShortageTab Tests', () {
    testWidgets('Renders within SelectionArea and displays title and 4 export actions', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.text('سحب العينات وتتبع الفحص وعجز البضائع'), findsOneWidget);
      expect(find.text('تصدير جدول تبويب مفصول'), findsOneWidget);
      expect(find.text('تصدير جدول أكسيل'), findsOneWidget);
      expect(find.text('طباعة تقرير الفحص والعجز'), findsOneWidget);
      expect(find.text('نسخ ملف الحافظة الشامل'), findsOneWidget);
    });

    testWidgets('Displays 4 KPI cards with proper counts', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('إجمالي العينات المسحوبة'), findsOneWidget);
      expect(find.text('عينات مطابقة للمواصفات'), findsOneWidget);
      expect(find.text('عينات قيد الفحص والتحليل'), findsOneWidget);
      expect(find.text('حالات العجز المثبتة'), findsOneWidget);

      expect(find.text('2'), findsWidgets);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('Displays samples and shortages with clickable copy badges', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Sample Badges
      expect(find.text('SMP-1001'), findsOneWidget);
      expect(find.text('SMP-1002'), findsOneWidget);
      expect(find.text('REC-9911'), findsOneWidget);
      expect(find.text('REC-9912'), findsOneWidget);

      // Shortage Badges
      expect(find.text('SHR-501'), findsOneWidget);
      expect(find.text('CMAU-4567890'), findsOneWidget);
      expect(find.text('قطع غيار توربينات'), findsOneWidget);
      expect(find.text('6.3%'), findsOneWidget);

      // Row summary copy buttons
      expect(find.byIcon(Icons.copy_rounded), findsWidgets);
    });

    testWidgets('Filters samples by search query', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('SMP-1001'), findsOneWidget);
      expect(find.text('SMP-1002'), findsOneWidget);

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'بكتيري');
      await tester.pumpAndSettle();

      expect(find.text('SMP-1001'), findsNothing);
      expect(find.text('SMP-1002'), findsOneWidget);
    });

    testWidgets('Opens Add Sample and Add Shortage dialogs with copy suffix buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Add Sample
      final addSampleBtn = find.text('تسجيل سحب عينة');
      expect(addSampleBtn, findsOneWidget);
      await tester.tap(addSampleBtn);
      await tester.pumpAndSettle();

      expect(find.text('تسجيل سحب عينة معملية جديدة'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsWidgets);

      // Cancel dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // Scroll and Tap Add Shortage
      final addShortageBtn = find.text('إثبات محضر عجز جديد');
      expect(addShortageBtn, findsOneWidget);
      await tester.scrollUntilVisible(addShortageBtn, 400, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(addShortageBtn);
      await tester.pumpAndSettle();

      expect(find.text('تسجيل محضر إثبات عجز بضائع مفرغة'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsWidgets);

      // Cancel dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
    });

    testWidgets('Renders cleanly in English mode with 0 Arabic stacking', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Drawing Samples & Shortage Tracking'), findsOneWidget);
      expect(find.text('Export TSV'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);
      expect(find.text('Print PDF Dossier'), findsOneWidget);
      expect(find.text('Copy Complete Dossier'), findsOneWidget);
      expect(find.text('Total Drawn Samples'), findsOneWidget);
      // The same label is also the PASSED status badge in the samples table,
      // so scope the KPI assertion to the metric strip.
      expect(
        find.descendant(of: find.byType(MetricCardStrip), matching: find.text('Compliant & Passed')),
        findsOneWidget,
      );
      expect(find.text('Pending Laboratory Analysis'), findsOneWidget);
      expect(find.text('Documented Shortage Cases'), findsOneWidget);
    });
  });
}
