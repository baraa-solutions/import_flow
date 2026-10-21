import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/smart_checklists/models/checklist_item_model.dart';
import 'package:frontend/features/smart_checklists/providers/smart_checklists_provider.dart';
import 'package:frontend/features/smart_checklists/widgets/checklist_item_card.dart';
import 'package:frontend/features/smart_checklists/widgets/smart_checklist_dialog.dart';

class _SimpleLocaleDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _SimpleLocaleDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) async => const DefaultMaterialLocalizations();
  @override
  bool shouldReload(_SimpleLocaleDelegate old) => false;
}

class MockSmartChecklistNotifier extends SmartChecklistNotifier {
  MockSmartChecklistNotifier(ChecklistSummaryModel mockSummary) : super(Dio()) {
    state = SmartChecklistState(summary: mockSummary, isLoading: false);
  }

  @override
  Future<void> fetchChecklist(int fileId) async {
    // Keep mock state
  }

  @override
  Future<void> autoSync(int fileId) async {
    // Keep mock state
  }
}

void main() {
  group('Smart Checklist Bilingual Model Tests', () {
    test('ChecklistItemModel handles bilingual getters correctly', () {
      const item = ChecklistItemModel(
        itemId: 1,
        importFileId: 101,
        questionCode: 'CHK-001',
        phaseCode: 'PRE_SHIPMENT',
        responsibleRole: 'COORDINATOR',
        questionTitleAr: 'التحقق من شرط التسليم Incoterms ومصفوفة التكاليف',
        questionTitleEn: 'Verification of Incoterms rule and cost responsibility matrix',
        descriptionAr: 'تحديد شروط الشحن والمسؤولية',
        descriptionEn: 'Determine freight terms and cost split',
        isMandatory: true,
        verificationType: 'AUTOMATIC',
        status: 'PASSED',
        verifiedBy: 'AutoCheck',
        notes: 'Verified via PO',
      );

      // Arabic getter
      expect(item.getTitle(true), 'التحقق من شرط التسليم Incoterms ومصفوفة التكاليف');
      expect(item.getDescription(true), 'تحديد شروط الشحن والمسؤولية');

      // English getter
      expect(item.getTitle(false), 'Verification of Incoterms rule and cost responsibility matrix');
      expect(item.getDescription(false), 'Determine freight terms and cost split');

      // Fallback when EN is null
      const itemFallback = ChecklistItemModel(
        itemId: 2,
        importFileId: 101,
        questionCode: 'CHK-002',
        phaseCode: 'PRE_SHIPMENT',
        responsibleRole: 'SUPPLIER',
        questionTitleAr: 'شهادة المنشأ الأصلية',
        questionTitleEn: null,
        descriptionAr: 'مطلوبة للتخليص',
        descriptionEn: null,
        isMandatory: true,
        verificationType: 'MANUAL',
        status: 'PENDING',
      );
      expect(itemFallback.getTitle(false), 'شهادة المنشأ الأصلية');
      expect(itemFallback.getDescription(false), 'مطلوبة للتخليص');
    });

    test('ChecklistItemModel serialization and copyWith maintain bilingual fields', () {
      final json = {
        'item_id': 5,
        'import_file_id': 20,
        'question_code': 'CHK-005',
        'phase_code': 'IN_TRANSIT',
        'responsible_role': 'CUSTOMS_BROKER',
        'question_title_ar': 'بوليصة الشحن',
        'question_title_en': 'Bill of Lading verification',
        'description_ar': 'مطابقة رقم الحاوية',
        'description_en': 'Match container number',
        'is_mandatory': true,
        'verification_type': 'AUTOMATIC',
        'status': 'PENDING',
      };

      final model = ChecklistItemModel.fromJson(json);
      expect(model.questionTitleEn, 'Bill of Lading verification');
      expect(model.descriptionEn, 'Match container number');

      final serialized = model.toJson();
      expect(serialized['question_title_en'], 'Bill of Lading verification');
      expect(serialized['description_en'], 'Match container number');

      final copied = model.copyWith(questionTitleEn: 'Updated English Title');
      expect(copied.questionTitleEn, 'Updated English Title');
      expect(copied.questionTitleAr, 'بوليصة الشحن');
    });
  });

  group('ChecklistItemCard Widget Tests (Light & Dark, AR & EN)', () {
    const sampleItem = ChecklistItemModel(
      itemId: 10,
      importFileId: 50,
      questionCode: 'CHK-010',
      phaseCode: 'PRE_SHIPMENT',
      responsibleRole: 'COORDINATOR',
      questionTitleAr: 'التحقق من صحة البند الجمركي HS Code',
      questionTitleEn: 'HS Code classification verification',
      descriptionAr: 'التأكد من دقة كود التعريفة الجمركية',
      descriptionEn: 'Ensure accurate tariff classification',
      isMandatory: true,
      verificationType: 'AUTOMATIC',
      status: 'PENDING',
    );

    testWidgets('Renders ChecklistItemCard in Arabic (Light Mode)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('ar'),
            home: Localizations(
              locale: const Locale('ar'),
              delegates: const [_SimpleLocaleDelegate(), DefaultWidgetsLocalizations.delegate],
              child: const Scaffold(
                body: ChecklistItemCard(item: sampleItem, fileId: 50),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('التحقق من صحة البند الجمركي HS Code'), findsOneWidget);
      expect(find.text('التأكد من دقة كود التعريفة الجمركية'), findsOneWidget);
      expect(find.text('إلزامي [Gatekeeper]'), findsOneWidget);
      expect(find.text('👤 المنسق'), findsOneWidget);
      expect(find.text('🤖 فحص آلي'), findsOneWidget);
      expect(find.text('تجاوز مشروط'), findsOneWidget);
    });

    testWidgets('Renders ChecklistItemCard in English (Dark Mode)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.darkTheme,
            home: Localizations(
              locale: const Locale('en'),
              delegates: const [_SimpleLocaleDelegate(), DefaultWidgetsLocalizations.delegate],
              child: const Scaffold(
                body: ChecklistItemCard(item: sampleItem, fileId: 50),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HS Code classification verification'), findsOneWidget);
      expect(find.text('Ensure accurate tariff classification'), findsOneWidget);
      expect(find.text('Mandatory [Gatekeeper]'), findsOneWidget);
      expect(find.text('👤 Coordinator'), findsOneWidget);
      expect(find.text('🤖 Auto Check'), findsOneWidget);
      expect(find.text('Override'), findsOneWidget);
    });

    testWidgets('Tapping Override opens bilingual and dark-themed modal', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.darkTheme,
            home: Localizations(
              locale: const Locale('en'),
              delegates: const [_SimpleLocaleDelegate(), DefaultWidgetsLocalizations.delegate],
              child: const Scaffold(
                body: ChecklistItemCard(item: sampleItem, fileId: 50),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Override
      await tester.tap(find.text('Override'));
      await tester.pumpAndSettle();

      expect(find.text('Conditional Override Request'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Approve Override'), findsOneWidget);
    });
  });

  group('SmartChecklistDialog Widget Tests (Bilingual & Dark Mode)', () {
    final sampleFile = ImportFileModel(
      importFileId: 101,
      importFileCode: 'IMP-2026-001',
      companyName: 'Test Company',
      supplierName: 'Global Exporter Inc',
      shipmentMode: 'SEA',
      incotermCode: 'FOB',
      priority: 'HIGH',
      shipmentCategory: 'COMMERCIAL',
      invoicesData: [],
      packingListsData: [],
      projectIds: [],
      isCustomsReleased: false,
      estimatedCost: 150000,
      estimatedCostCurrency: 'USD',
      currentModule: 'PRE_SHIPMENT',
      currentStage: 'INITIAL_REVIEW',
      progressPercent: 25.0,
      nextAction: 'Review Checklist',
      acidNumber: '1234567890123456789',
      createdAt: '2026-09-13T12:00:00Z',
      updatedAt: '2026-09-13T12:00:00Z',
    );

    const mockSummary = ChecklistSummaryModel(
      importFileId: 101,
      importFileCode: 'IMP-2026-001',
      totalItems: 2,
      passedItems: 1,
      pendingItems: 1,
      waivedItems: 0,
      mandatoryPendingItems: 1,
      readinessScorePct: 50,
      isGateBlocked: true,
      blockingQuestions: ['CHK-002'],
      items: [
        ChecklistItemModel(
          itemId: 101,
          importFileId: 101,
          questionCode: 'CHK-001',
          phaseCode: 'PRE_SHIPMENT',
          responsibleRole: 'COORDINATOR',
          questionTitleAr: 'التحقق من شرط التسليم Incoterms ومصفوفة التكاليف',
          questionTitleEn: 'Verification of Incoterms rule and cost responsibility matrix',
          descriptionAr: 'تحديد شروط الشحن والمسؤولية',
          descriptionEn: 'Determine freight terms and cost split',
          isMandatory: true,
          verificationType: 'AUTOMATIC',
          status: 'PASSED',
        ),
        ChecklistItemModel(
          itemId: 102,
          importFileId: 101,
          questionCode: 'CHK-002',
          phaseCode: 'PRE_SHIPMENT',
          responsibleRole: 'SUPPLIER',
          questionTitleAr: 'شهادة المنشأ الأصلية',
          questionTitleEn: 'Original Certificate of Origin',
          descriptionAr: 'مطلوبة للتخليص الجمركي',
          descriptionEn: 'Required for customs clearance',
          isMandatory: true,
          verificationType: 'MANUAL',
          status: 'PENDING',
        ),
      ],
    );

    testWidgets('Renders SmartChecklistDialog in Arabic with Gatekeeper Block Alert', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smartChecklistProvider.overrideWith((ref) => MockSmartChecklistNotifier(mockSummary)),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            home: Localizations(
              locale: const Locale('ar'),
              delegates: const [_SimpleLocaleDelegate(), DefaultWidgetsLocalizations.delegate],
              child: Scaffold(
                body: SmartChecklistDialog(file: sampleFile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قائمة التحقق التشغيلية الذكية'), findsOneWidget);
      expect(find.text('مؤشر الجاهزية'), findsOneWidget);
      expect(find.text('معلق مانع [Gate]'), findsOneWidget);
      expect(find.text('فحص آلي مع الداتابيز'), findsOneWidget);
      expect(find.text('تصفية المسؤول: '), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);
      expect(find.textContaining('تنبيه بوابات الحظر: يوجد 1 بند إلزامي معلق'), findsOneWidget);
    });

    testWidgets('Renders SmartChecklistDialog in English (Dark Mode) with Gatekeeper Alert', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smartChecklistProvider.overrideWith((ref) => MockSmartChecklistNotifier(mockSummary)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.darkTheme,
            home: Localizations(
              locale: const Locale('en'),
              delegates: const [_SimpleLocaleDelegate(), DefaultWidgetsLocalizations.delegate],
              child: Scaffold(
                body: SmartChecklistDialog(file: sampleFile),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Smart Import Operational Checklist'), findsOneWidget);
      expect(find.text('Readiness Index'), findsOneWidget);
      expect(find.text('Gate Blocked'), findsOneWidget);
      expect(find.text('Auto-Check with DB'), findsOneWidget);
      expect(find.text('Filter by Role: '), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('Gatekeeper Alert: 1 mandatory pending item(s) block automatic stage progression.'), findsOneWidget);
    });
  });
}
