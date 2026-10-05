import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_documentation/models/invoice_bl_match_session_model.dart';
import 'package:frontend/features/import_documentation/models/docs_customs_approval_session_model.dart';
import 'package:frontend/features/import_documentation/providers/import_documentation_provider.dart';
import 'package:frontend/features/import_documentation/widgets/invoice_bl_matcher_tab.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class MockImportFilesNotifier extends ImportFilesNotifier {
  MockImportFilesNotifier() : super(Dio()) {
    state = AsyncValue.data([
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
    ]);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

class MockInvoiceBLMatchSessionsNotifier extends InvoiceBLMatchSessionsNotifier {
  MockInvoiceBLMatchSessionsNotifier() : super(Dio()) {
    state = AsyncValue.data([
      InvoiceBLMatchSessionModel(
        sessionId: 1,
        sessionCode: 'SESS-202609-0001',
        importFileId: 101,
        importFileCode: 'IMP-2026-001',
        invoiceNumber: 'INV-1',
        isDraft: false,
        matchScorePercentage: 95.5,
        isSafeForCertification: true,
        comparisonMatrix: [
          {
            'field_name_ar': 'رقم ACID الجمركي',
            'field_name_en': 'ACID Number',
            'invoice_value': '7595528271019210013',
            'bl_value': '7595528271019210013',
            'match_status': 'MATCH',
            'details': 'مطابق تماماً',
          }
        ],
        createdAt: '2026-09-16 10:00:00',
        updatedAt: '2026-09-16 10:00:00',
      ),
      InvoiceBLMatchSessionModel(
        sessionId: 2,
        sessionCode: 'SESS-202609-0002',
        importFileId: 101,
        importFileCode: 'IMP-2026-001',
        invoiceNumber: 'INV-2',
        isDraft: true,
        matchScorePercentage: 68.0,
        isSafeForCertification: false,
        criticalDiscrepanciesCount: 1,
        warningDiscrepanciesCount: 1,
        comparisonMatrix: [],
        createdAt: '2026-09-16 10:15:00',
        updatedAt: '2026-09-16 10:15:00',
      ),
    ]);
  }

  @override
  Future<void> fetchSessions({int? importFileId, bool? isDraft, String? search}) async {}
}

void main() {
  group('InvoiceBLMatchSessionModel and DocsCustomsApprovalSessionModel Unit Tests', () {
    // JSON copied from InvoiceBLMatchSessionResponse (modules/import_documentation/schemas.py).
    final backendJson = <String, dynamic>{
      'session_id': 10,
      'session_code': 'SESS-202609-0010',
      'import_file_id': 50,
      'import_file_code': 'IMP-2026-0050',
      'invoice_number': 'INV-77',
      'bl_number': 'BL-88',
      'packing_list_number': null,
      'acid_number': '7595528271019210013',
      'match_score_percentage': 88.5,
      'overall_status': 'PARTIALLY_MATCHED',
      'is_safe_for_certification': false,
      'is_draft': true,
      'critical_discrepancies_count': 1,
      'warning_discrepancies_count': 2,
      'comparison_matrix': [
        {'field_name_en': 'ACID Number', 'match_status': 'MATCH'}
      ],
      'invoice_data': {'invoice_number': 'INV-77'},
      'bl_data': {'bl_number': 'BL-88'},
      'packing_list_data': null,
      'correction_letter': null,
      'notes': 'audit notes',
      'certified_by': 'Ahmed',
      'is_active': true,
      'created_at': '2026-09-16T10:00:00',
      'updated_at': '2026-09-16T10:00:00',
    };

    test('InvoiceBLMatchSessionModel.fromJson reads the backend response keys', () {
      final m = InvoiceBLMatchSessionModel.fromJson(backendJson);
      expect(m.sessionId, 10);
      expect(m.matchScorePercentage, 88.5);
      expect(m.matchScore, 88.5);
      expect(m.overallStatus, 'PARTIALLY_MATCHED');
      expect(m.criticalDiscrepanciesCount, 1);
      expect(m.warningDiscrepanciesCount, 2);
      expect(m.discrepancyCount, 3);
      expect(m.hasCriticalDiscrepancies, isTrue);
      expect(m.invoiceData, {'invoice_number': 'INV-77'});
      expect(m.blData, {'bl_number': 'BL-88'});
      expect(m.notes, 'audit notes');
      expect(m.certifiedBy, 'Ahmed');
      expect(m.sessionTitle, 'INV-77 / BL-88');
      expect(m.isDraft, isTrue);
    });

    test('toJson round-trips through fromJson', () {
      final restored = InvoiceBLMatchSessionModel.fromJson(
        InvoiceBLMatchSessionModel.fromJson(backendJson).toJson(),
      );
      expect(restored.sessionCode, 'SESS-202609-0010');
      expect(restored.matchScorePercentage, 88.5);
      expect(restored.criticalDiscrepanciesCount, 1);
      expect(restored.blData, {'bl_number': 'BL-88'});
    });

    test('toCreateJson sends only InvoiceBLMatchSessionCreate keys (FED-01)', () {
      final payload = InvoiceBLMatchSessionModel.toCreateJson(
        importFileId: 50,
        isDraft: false,
        notes: 'accepted with a documented reason',
        matchResult: {
          'match_score_percentage': 91.25,
          'overall_status': 'FULLY_MATCHED',
          'is_safe_for_certification': true,
          'critical_discrepancies_count': 0,
          'warning_discrepancies_count': 2,
          'comparison_matrix': [
            {'field_name_en': 'ACID', 'match_status': 'MATCH'}
          ],
          'invoice_data': {'invoice_number': 'INV-9', 'acid_number': '123'},
          'bl_data': {'bl_number': 'BL-9'},
          'packing_list_data': {'packing_list_number': 'PL-9'},
          'correction_letter': '',
        },
      );
      expect(InvoiceBLMatchSessionModel.createKeys.containsAll(payload.keys), isTrue,
          reason: 'unknown keys: ${payload.keys.toSet().difference(InvoiceBLMatchSessionModel.createKeys)}');
      expect(payload['match_score_percentage'], 91.25);
      expect(payload['overall_status'], 'FULLY_MATCHED');
      expect(payload['critical_discrepancies_count'], 0);
      expect(payload['warning_discrepancies_count'], 2);
      expect(payload['invoice_data'], {'invoice_number': 'INV-9', 'acid_number': '123'});
      expect(payload['bl_data'], {'bl_number': 'BL-9'});
      expect(payload['packing_list_data'], {'packing_list_number': 'PL-9'});
      expect(payload['invoice_number'], 'INV-9');
      expect(payload['bl_number'], 'BL-9');
      expect(payload['packing_list_number'], 'PL-9');
      expect(payload['acid_number'], '123');
      expect(payload['notes'], 'accepted with a documented reason');
      expect(payload.containsKey('correction_letter'), isFalse, reason: 'blank letter is not sent');
      // Legacy wrong keys must never come back.
      for (final wrong in const [
        'match_score', 'discrepancy_count', 'has_critical_discrepancies', 'invoice_extracted_data',
        'bl_extracted_data', 'packing_extracted_data', 'session_notes', 'session_title', 'created_by',
        'invoice_raw_text', 'bl_raw_text', 'invoice_file_name',
      ]) {
        expect(payload.containsKey(wrong), isFalse, reason: wrong);
      }
    });

    test('toCreateJson reads the parser key draft_bl_number for the B/L number', () {
      final payload = InvoiceBLMatchSessionModel.toCreateJson(
        importFileId: 1,
        isDraft: true,
        matchResult: {
          'bl_data': {'draft_bl_number': 'MEDU123'},
        },
      );
      expect(payload['bl_number'], 'MEDU123');
    });

    test('toCreateJson without a match result still produces a valid draft payload', () {
      final payload = InvoiceBLMatchSessionModel.toCreateJson(importFileId: 7, isDraft: true);
      expect(payload['import_file_id'], 7);
      expect(payload['is_draft'], isTrue);
      expect(payload['is_safe_for_certification'], isFalse);
      expect(payload.containsKey('invoice_data'), isFalse);
      expect(InvoiceBLMatchSessionModel.createKeys.containsAll(payload.keys), isTrue);
    });

    test('DocsCustomsApprovalSessionModel follows DocsCustomsApprovalSessionResponse', () {
      final json = <String, dynamic>{
        'session_id': 5,
        'session_code': 'CUSTAPPR-202609-0005',
        'version': 3,
        'import_file_id': 50,
        'import_file_code': 'IMP-2026-0050',
        'po_id': null,
        'overall_status': 'APPROVED',
        'is_draft': false,
        'final_invoice_ref': 'INV-1',
        'final_invoice_status': 'Approved',
        'final_pl_ref': null,
        'final_pl_status': 'Approved',
        'draft_bl_ref': 'BL-1',
        'draft_bl_status': 'Approved',
        'coo_ref': null,
        'coo_status': 'Approved',
        'coc_ref': null,
        'coc_status': 'Waived / Not Required',
        'commercial_signoff_by': 'Sara',
        'commercial_signoff_date': '2026-09-16',
        'customs_signoff_by': 'Omar',
        'customs_signoff_date': '2026-09-17',
        'customs_broker_name': 'Broker Co',
        'discrepancies_count': 0,
        'open_tickets_count': 0,
        'session_snapshot': {'a': 1},
        'notes': 'released',
        'created_by': 'Sara',
        'is_active': true,
        'created_at': '2026-09-16T10:00:00',
        'updated_at': '2026-09-16T10:00:00',
      };
      final m = DocsCustomsApprovalSessionModel.fromJson(json);
      expect(m.sessionId, 5);
      expect(m.version, 3);
      expect(m.overallStatus, 'APPROVED');
      expect(m.finalInvoiceRef, 'INV-1');
      expect(m.cocStatus, 'Waived / Not Required');
      expect(m.commercialSignoffBy, 'Sara');
      expect(m.customsSignoffDate, '2026-09-17');
      expect(m.sessionSnapshot, {'a': 1});
      expect(m.notes, 'released');

      final restored = DocsCustomsApprovalSessionModel.fromJson(m.toJson());
      expect(restored.sessionCode, 'CUSTAPPR-202609-0005');
      expect(restored.customsBrokerName, 'Broker Co');
      expect(restored.isDraft, isFalse);
    });
  });

  group('InvoiceBLMatcherTab Sessions Registry Widget Tests', () {
    testWidgets('Renders view mode switcher and toggles to Sessions Registry', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => MockImportFilesNotifier()),
            invoiceBLMatchSessionsProvider.overrideWith((ref) => MockInvoiceBLMatchSessionsNotifier()),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              home: Scaffold(
                body: InvoiceBLMatcherTab(selectedImportFileId: 101),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify top switcher tabs exist
      expect(find.text('⚡ فحص ومطابقة الفاتورة والبوليصة'), findsOneWidget);
      expect(find.text('📋 سجل جلسات المطابقة السابقة'), findsOneWidget);

      // Verify session count badge displays '2'
      expect(find.text('2'), findsWidgets);

      // Switch to Sessions Registry View
      await tester.tap(find.text('📋 سجل جلسات المطابقة السابقة'));
      await tester.pumpAndSettle();

      // Verify Sessions Table and KPI headers rendered
      expect(find.text('إجمالي الجلسات'), findsOneWidget);
      expect(find.text('الجلسات المعتمدة'), findsOneWidget);
      expect(find.text('المسودات المؤقتة'), findsOneWidget);

      // Verify sessions are rendered in table
      expect(find.text('SESS-202609-0001'), findsOneWidget);
      expect(find.text('SESS-202609-0002'), findsOneWidget);
      expect(find.text('معتمدة نهائية'), findsOneWidget);
      expect(find.text('مسودة مؤقتة'), findsOneWidget);
    });
  });
}
