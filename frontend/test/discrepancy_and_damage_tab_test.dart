import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/customs_clearance/widgets/discrepancy_and_damage_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockProtocols = [
    {
      'protocol_no': 'DMG-ALX-001',
      'declaration_no': '46-ALX-IMP-2026-001',
      'container_no': 'MSCU1234567',
      'damage_type': 'كسر أختام وبلل مياه بحر',
      'damaged_qty': '10 طرود',
      'estimated_loss_egp': 35000.0,
      'responsible_party': 'التوكيل الملاحي',
      'insurance_claim_status': 'APPROVED',
      'committee': 'ممثل الجمارك والتوكيل والتأمين',
      'date': '2026-09-08',
      'notes': 'تم فتح الحاوية بحضور اللجنة وإثبات التلف',
    },
    {
      'protocol_no': 'DMG-DKH-002',
      'declaration_no': '46-DKH-IMP-2026-099',
      'container_no': 'TGHU7654321',
      'damage_type': 'تهشم منصات وسقوط رافعة',
      'damaged_qty': '2 باليتة',
      'estimated_loss_egp': 18500.5,
      'responsible_party': 'شركة التفريغ بالميناء',
      'insurance_claim_status': 'CLAIM_SUBMITTED',
      'committee': 'مندوب التفريغ والمستودع',
      'date': '2026-09-09',
      'notes': 'سقطت المنصة أثناء مناولة ونش الرصيف',
    },
  ];

  Widget buildTestWidget({
    Locale locale = const Locale('ar'),
    List<Map<String, dynamic>>? protocols,
    ValueChanged<Map<String, dynamic>>? onAddProtocol,
  }) {
    return MaterialApp(
      home: AppLocalizationsProvider(
        locale: locale,
        child: Scaffold(
          body: DiscrepancyAndDamageTab(
            records: const [],
            discrepancyProtocols: protocols ?? List.from(mockProtocols),
            onAddProtocol: onAddProtocol,
          ),
        ),
      ),
    );
  }

  group('Screen 61: DiscrepancyAndDamageTab Widget Tests', () {
    testWidgets('Renders inside SelectionArea and displays banner with 4 export actions', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.text('إثبات الفاقد والتلف الجمركي ومحاضر النقص'), findsOneWidget);

      // 4 Export Toolbar Actions
      expect(find.text('تصدير جدول نصي'), findsOneWidget);
      expect(find.text('تصدير جدول إكسيل'), findsOneWidget);
      expect(find.text('طباعة تقرير بي دي إف'), findsOneWidget);
      expect(find.text('نسخ حافظة المحاضر'), findsOneWidget);

      // Add Protocol Button
      expect(find.text('تحرير محضر مشترك جديد'), findsOneWidget);
    });

    testWidgets('Renders 4 KPI metrics correctly', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Total Protocols
      expect(find.text('إجمالي المحاضر'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Total Estimated Loss = 35000 + 18500.50 = 53500.50
      // Design refresh: the currency moved into the KPI title and the value
      // is grouped with thousands separators (CcFormat.money).
      expect(find.text('إجمالي الخسائر المقدرة (جنيه)'), findsOneWidget);
      expect(find.textContaining('53,500.50'), findsOneWidget);

      // Claims Submitted & Approved
      expect(find.text('مطالبات قيد المتابعة'), findsOneWidget);
      expect(find.text('مطالبات معتمدة للتعويض'), findsOneWidget);
    });

    testWidgets('Renders DataTable with clickable copy badges and quick row summary copy button', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Protocol badges
      expect(find.text('DMG-ALX-001'), findsOneWidget);
      expect(find.text('DMG-DKH-002'), findsOneWidget);

      // Container badges
      expect(find.text('MSCU1234567'), findsOneWidget);
      expect(find.text('TGHU7654321'), findsOneWidget);

      // Row summary copy icons
      expect(find.byIcon(Icons.copy_rounded), findsNWidgets(2));
    });

    testWidgets('Search field filters protocols by query', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('DMG-ALX-001'), findsOneWidget);
      expect(find.text('DMG-DKH-002'), findsOneWidget);

      final searchInput = find.byType(TextField).first;
      await tester.enterText(searchInput, 'DKH');
      await tester.pumpAndSettle();

      expect(find.text('DMG-ALX-001'), findsNothing);
      expect(find.text('DMG-DKH-002'), findsOneWidget);
    });

    testWidgets('Status filter chips filter the protocols list', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap 'معتمدة للتعويض' (APPROVED) chip
      await tester.tap(find.text('معتمدة للتعويض').first);
      await tester.pumpAndSettle();

      expect(find.text('DMG-ALX-001'), findsOneWidget);
      expect(find.text('DMG-DKH-002'), findsNothing);
    });

    testWidgets('Empty protocols list shows empty state illustration and message', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(protocols: []));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد محاضر معاينة مشتركة أو إثبات فاقد مسجلة حالياً.'), findsOneWidget);
    });

    testWidgets('Add Protocol dialog opens, shows copy icons and cancels cleanly', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap 'تحرير محضر مشترك جديد'
      await tester.tap(find.text('تحرير محضر مشترك جديد'));
      await tester.pumpAndSettle();

      expect(find.text('تحرير محضر تلف وفاقد جمركي ومعاينة مشتركة'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsWidgets);

      // Cancel dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('تحرير محضر تلف وفاقد جمركي ومعاينة مشتركة'), findsNothing);
    });

    testWidgets('Renders cleanly in English mode with 0 Arabic stacking', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Discrepancy & Damage Protocols Registry'), findsOneWidget);
      expect(find.text('Export TSV'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);
      expect(find.text('Print PDF Report'), findsOneWidget);
      expect(find.text('Copy Protocols Dossier'), findsOneWidget);
      expect(find.text('New Joint Protocol'), findsOneWidget);
      expect(find.text('Total Protocols'), findsOneWidget);
      expect(find.text('Total Estimated Loss (EGP)'), findsOneWidget);
      expect(find.text('Claims Under Review'), findsOneWidget);
      expect(find.text('Claims Approved'), findsOneWidget);
    });
  });
}
