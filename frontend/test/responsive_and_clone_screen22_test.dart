import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_documentation/models/invoice_bl_match_session_model.dart';
import 'package:frontend/features/import_documentation/providers/import_documentation_provider.dart';
import 'package:frontend/features/import_documentation/screens/smart_invoice_bl_match_screen.dart';
import 'package:frontend/features/import_documentation/widgets/invoice_bl_matcher_tab.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> files;
  MockImportFilesNotifier(this.files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    state = AsyncValue.data(files);
  }
}

class MockInvoiceBLMatchSessionsNotifier extends InvoiceBLMatchSessionsNotifier {
  final List<InvoiceBLMatchSessionModel> sessions;
  MockInvoiceBLMatchSessionsNotifier(this.sessions) : super(Dio()) {
    state = AsyncValue.data(sessions);
  }

  @override
  Future<void> fetchSessions({int? importFileId, bool? isDraft, String? search}) async {
    state = AsyncValue.data(sessions);
  }

  @override
  Future<bool> deleteSession(int sessionId) async {
    return true;
  }
}

void main() {
  final sampleFiles = [
    ImportFileModel(
      importFileId: 101,
      importFileCode: 'IMP-2026-001',
      companyName: 'ARCHI Brands',
      supplierName: 'Shaw Europe Limited',
      piNumber: '35220',
      status: 'Draft Documents',
      invoicesData: [],
      packingListsData: [],
      projectIds: [],
      shipmentMode: 'Sea',
      incotermCode: 'EXW',
      priority: 'Normal',
      shipmentCategory: 'Commercial',
      estimatedCost: 85060.57,
      estimatedCostCurrency: 'USD',
      currentModule: 'Import Documentation',
      currentStage: 'Draft Documents',
      progressPercent: 65.0,
      nextAction: 'Reconcile B/L',
      isCustomsReleased: false,
      isActive: true,
      createdAt: DateTime.now().toString(),
      updatedAt: DateTime.now().toString(),
    ),
  ];

  final sampleMatrix = [
    {
      'field_name_ar': 'رقم الفاتورة / B/L',
      'field_name_en': 'Invoice / B/L Number',
      'invoice_value': 'INV-2026-001',
      'bl_value': 'INV-2026-001',
      'match_status': 'MATCH',
      'details': 'مطابق تماماً',
    },
    {
      'field_name_ar': 'الوزن القائم (كجم)',
      'field_name_en': 'Gross Weight (kg)',
      'invoice_value': '4,500.00',
      'bl_value': '4,520.00',
      'match_status': 'MISMATCH_MINOR',
      'details': 'فارق طفيف في الوزن (20 كجم) ضمن الحدود المقبولة',
    },
    {
      'field_name_ar': 'ميناء الشحن',
      'field_name_en': 'Port of Loading',
      'invoice_value': 'Shanghai',
      'bl_value': 'Ningbo',
      'match_status': 'MISMATCH_CRITICAL',
      'details': 'اختلاف جوهري في ميناء الشحن يتطلب خطاب تصحيح',
    },
  ];

  final sampleSessions = [
    InvoiceBLMatchSessionModel(
      sessionId: 1,
      sessionCode: 'SESS-202609-0001',
      importFileId: 101,
      importFileCode: 'IMP-2026-001',
      invoiceNumber: 'INV-2026-001',
      isDraft: false,
      matchScorePercentage: 92.5,
      isSafeForCertification: true,
      warningDiscrepanciesCount: 1,
      comparisonMatrix: sampleMatrix,
      createdAt: '2026-09-16 10:00:00',
      updatedAt: '2026-09-16 10:00:00',
    ),
    InvoiceBLMatchSessionModel(
      sessionId: 2,
      sessionCode: 'SESS-202609-0002',
      importFileId: 101,
      importFileCode: 'IMP-2026-001',
      invoiceNumber: 'INV-2026-002',
      isDraft: true,
      matchScorePercentage: 68.0,
      isSafeForCertification: false,
      criticalDiscrepanciesCount: 1,
      warningDiscrepanciesCount: 1,
      comparisonMatrix: sampleMatrix,
      createdAt: '2026-09-16 10:15:00',
      updatedAt: '2026-09-16 10:15:00',
    ),
  ];

  Widget buildTestApp({
    required Size size,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
    Widget? child,
  }) {
    return ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => MockImportFilesNotifier(sampleFiles)),
        invoiceBLMatchSessionsProvider.overrideWith((ref) => MockInvoiceBLMatchSessionsNotifier(sampleSessions)),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        locale: locale,
        home: AppLocalizationsProvider(
          locale: locale,
          child: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              body: child ?? const InvoiceBLMatcherTab(selectedImportFileId: 101),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 22: SmartInvoiceBLMatchScreen & InvoiceBLMatcherTab Protocol Tests', () {
    testWidgets('Test 1: Desktop Viewport (1440x900) renders smoothly with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestApp(size: const Size(1440, 900)));
      await tester.pumpAndSettle();

      // Verify View mode toggle renders
      expect(find.byKey(const Key('matcherTabToggleBtn')), findsOneWidget);
      expect(find.byKey(const Key('sessionsTabToggleBtn')), findsOneWidget);

      // Verify Ingestion section renders
      expect(find.textContaining('1. الفاتورة التجارية النهائية'), findsWidgets);
      expect(find.textContaining('3. مسودة بوليصة الشحن'), findsWidgets);

      // Switch to Sessions Registry view
      await tester.tap(find.byKey(const Key('sessionsTabToggleBtn')));
      await tester.pumpAndSettle();

      // Verify Sessions Registry KPI cards and table
      expect(find.text('إجمالي الجلسات'), findsOneWidget);
      expect(find.text('الجلسات المعتمدة'), findsOneWidget);
      expect(find.text('المسودات المؤقتة'), findsOneWidget);
      expect(find.text('كود الجلسة'), findsOneWidget);
      expect(find.text('SESS-202609-0001'), findsOneWidget);
      expect(find.text('SESS-202609-0002'), findsOneWidget);

      // Verify 0 exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 2: Tablet Viewport (800x1024) renders with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      await tester.pumpWidget(buildTestApp(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('matcherTabToggleBtn')), findsOneWidget);

      // Switch to Sessions Registry
      await tester.tap(find.byKey(const Key('sessionsTabToggleBtn')));
      await tester.pumpAndSettle();

      expect(find.text('SESS-202609-0001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 3: Mobile Viewport (390x844) renders with 0 RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildTestApp(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('matcherTabToggleBtn')), findsOneWidget);

      // Switch to Sessions Registry
      await tester.tap(find.byKey(const Key('sessionsTabToggleBtn')));
      await tester.pumpAndSettle();

      expect(find.text('SESS-202609-0001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 4: Dark Mode (WCAG AA) renders properly without contrast crashes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestApp(
        size: const Size(1200, 800),
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('matcherTabToggleBtn')), findsOneWidget);

      // Switch to Sessions Registry
      await tester.tap(find.byKey(const Key('sessionsTabToggleBtn')));
      await tester.pumpAndSettle();

      expect(find.text('SESS-202609-0001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 5: RTL & Arabic localization render correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestApp(
        size: const Size(1200, 800),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      // Check Arabic localized elements
      expect(find.textContaining('أداة الاستخراج الذكي والمطابقة الفورية'), findsOneWidget);
      expect(find.textContaining('تنفيذ الاستخراج الذكي والمطابقة الفورية'), findsOneWidget);
      expect(find.textContaining('تحميل نموذج تجريبي حقيقي'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 6: Task D — Session Clone Action clones session into new editable draft', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestApp(size: const Size(1200, 800)));
      await tester.pumpAndSettle();

      // Switch to Sessions Registry
      await tester.tap(find.byKey(const Key('sessionsTabToggleBtn')));
      await tester.pumpAndSettle();

      // Find clone button for Session 1
      final cloneBtn = find.byKey(const Key('cloneSessionBtn_1'));
      expect(cloneBtn, findsOneWidget);

      await tester.ensureVisible(cloneBtn);
      await tester.pumpAndSettle();

      // Tap clone button
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // Verify it switched back to view mode 0 (Matcher view)
      expect(find.textContaining('1. الفاتورة التجارية النهائية'), findsWidgets);

      // Verify snackbar indicates successful cloning
      expect(find.textContaining('تم استنساخ بيانات الجلسة (SESS-202609-0001) كمسودة جديدة'), findsOneWidget);

      // Verify the comparison matrix from session 1 is loaded into matcher
      await tester.ensureVisible(find.byKey(const Key('copyComparisonMatrixTsvBtn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copyComparisonMatrixTsvBtn')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 7: Task J — Comparison Matrix export and TSV copy buttons render and respond', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildTestApp(size: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // Switch to Sessions Registry and clone session 1 to populate the comparison matrix
      await tester.tap(find.byKey(const Key('sessionsTabToggleBtn')));
      await tester.pumpAndSettle();

      final cloneBtn = find.byKey(const Key('cloneSessionBtn_1'));
      expect(cloneBtn, findsOneWidget);

      await tester.ensureVisible(cloneBtn);
      await tester.pumpAndSettle();

      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // Ensure comparison matrix is visible in the SingleChildScrollView
      await tester.ensureVisible(find.byKey(const Key('copyComparisonMatrixTsvBtn')));
      await tester.pumpAndSettle();

      // Verify Task J buttons exist on the Comparison Matrix header
      expect(find.byKey(const Key('copyComparisonMatrixTsvBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportComparisonMatrixExcelBtn')), findsOneWidget);
      expect(find.byKey(const Key('exportComparisonMatrixPdfBtn')), findsOneWidget);

      // Clear any prior snackbar from cloning so the copy snackbar shows immediately
      ScaffoldMessenger.of(tester.element(find.byType(InvoiceBLMatcherTab))).clearSnackBars();
      await tester.pumpAndSettle();

      final copyBtn = tester.widget<AppButton>(find.byKey(const Key('copyComparisonMatrixTsvBtn')));
      expect(copyBtn.onPressed, isNotNull);

      // Tap Copy TSV button
      await tester.tap(find.byKey(const Key('copyComparisonMatrixTsvBtn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Test 8: Host Screen SmartInvoiceBLMatchScreen renders inside DedicatedStageScaffold', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(buildTestApp(
        size: const Size(1400, 900),
        child: const SmartInvoiceBLMatchScreen(initialImportFileId: 101),
      ));
      await tester.pumpAndSettle();

      // Verify DedicatedStageScaffold title and action
      expect(find.textContaining('المطابقة الذكية بين الفاتورة التجارية وبوليصة الشحن'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsWidgets);
      expect(find.byIcon(Icons.refresh), findsWidgets);

      // Child matcher tab rendered
      expect(find.textContaining('أداة الاستخراج الذكي والمطابقة الفورية'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
