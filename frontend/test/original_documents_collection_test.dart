import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:frontend/features/import_documentation/models/original_documents_collection_model.dart';
import 'package:frontend/features/import_documentation/widgets/original_documents_collection_tab.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/import_documentation/providers/original_documents_collection_provider.dart';

class _MockImportFilesNotifier extends ImportFilesNotifier {
  _MockImportFilesNotifier() : super(Dio()) {
    state = AsyncValue.data([
      ImportFileModel(
        importFileId: 1,
        importFileCode: 'IMP-2026-0001',
        companyId: 1,
        companyName: 'Al-Sorour Logistics',
        supplierId: 1,
        supplierName: 'Narbutas International UAB',
        acidNumber: '7595528271020210010',
        status: 'Under Review',
        incotermCode: 'EXW',
        currentModule: 'IMPORT_DOCUMENTATION',
        currentStage: 'Draft Documents',
        nextAction: 'Review COO and Inspection',
        isActive: true,
        createdAt: '2026-08-20T10:00:00Z',
        updatedAt: '2026-08-21T10:00:00Z',
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

class _MockOriginalDocsNotifier extends OriginalDocumentsCollectionNotifier {
  _MockOriginalDocsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchSessions({String? status, String? search}) async {
    state = const AsyncValue.data([]);
  }
}

void main() {
  group('Original Documents Collection Model Tests', () {
    test('CourierEntryModel serialization and deserialization', () {
      final json = {
        'courier_no': 'DHL-99881122',
        'courier_company': 'DHL',
        'dispatch_date': '2026-08-20',
        'is_received': true,
        'received_date': '2026-08-21',
        'received_by': 'Ahmed Salah',
        'notes': 'Original Invoice Package',
      };

      final courier = CourierEntryModel.fromJson(json);
      expect(courier.courierNo, 'DHL-99881122');
      expect(courier.courierCompany, 'DHL');
      expect(courier.isReceived, true);
      expect(courier.receivedBy, 'Ahmed Salah');

      final encoded = courier.toJson();
      expect(encoded['courier_no'], 'DHL-99881122');
      expect(encoded['is_received'], true);
    });

    test('OriginalDocumentItemModel serialization and deserialization', () {
      final json = {
        'category': 'Commercial',
        'document_name': 'Commercial Invoice',
        'is_required': 'Yes',
        'responsible_party': 'Supplier',
        'courier_no': 'DHL-99881122',
        'is_received': true,
        'received_date': '2026-08-21',
        'is_verified': true,
        'verified_by': 'Kamal',
        'verification_date': '2026-08-21',
        'status': 'Verified',
        'remarks': 'Matching stamps',
      };

      final doc = OriginalDocumentItemModel.fromJson(json);
      expect(doc.category, 'Commercial');
      expect(doc.documentName, 'Commercial Invoice');
      expect(doc.isRequired, 'Yes');
      expect(doc.isReceived, true);
      expect(doc.isVerified, true);
      expect(doc.status, 'Verified');

      final encoded = doc.toJson();
      expect(encoded['document_name'], 'Commercial Invoice');
      expect(encoded['status'], 'Verified');
    });

    test('OriginalDocumentsCollectionSessionModel serialization and stats', () {
      final json = {
        'collection_id': 1,
        'collection_code': 'DOC-COL-2026-0001',
        'import_file_id': 1,
        'import_file_code': 'IMP-2026-0001',
        'acid_number': '7595528271020210010',
        'importer_name': 'Al-Sorour Logistics',
        'supplier_name': 'Narbutas International UAB',
        'status': 'PARTIALLY_RECEIVED',
        'couriers_list': [
          {
            'courier_no': 'DHL-99881122',
            'courier_company': 'DHL',
            'dispatch_date': '2026-08-20',
            'is_received': true,
            'received_date': '2026-08-21',
            'received_by': 'Ahmed Salah',
          }
        ],
        'documents_list': [
          {
            'category': 'Commercial',
            'document_name': 'Commercial Invoice',
            'is_required': 'Yes',
            'responsible_party': 'Supplier',
            'courier_no': 'DHL-99881122',
            'is_received': true,
            'is_verified': true,
            'status': 'Verified',
          },
          {
            'category': 'Commercial',
            'document_name': 'Packing List',
            'is_required': 'Yes',
            'responsible_party': 'Supplier',
            'courier_no': 'DHL-99881122',
            'is_received': true,
            'is_verified': false,
            'status': 'Received',
          },
        ],
        'total_documents_count': 2,
        'received_documents_count': 2,
        'verified_documents_count': 1,
        'pending_documents_count': 0,
        'completion_percentage': 50.0,
        'is_active': true,
        'created_at': '2026-08-21T05:00:00Z',
        'created_by': 'ADMIN',
        'updated_at': '2026-08-21T05:00:00Z',
        'updated_by': 'ADMIN',
      };

      final session = OriginalDocumentsCollectionSessionModel.fromJson(json);
      expect(session.collectionId, 1);
      expect(session.collectionCode, 'DOC-COL-2026-0001');
      expect(session.status, 'PARTIALLY_RECEIVED');
      expect(session.couriersList.length, 1);
      expect(session.documentsList.length, 2);
      expect(session.completionPercentage, 50.0);
    });

    test('CourierAlertItemModel and CourierAlertsResponseModel serialization', () {
      final json = {
        'total_active_couriers': 2,
        'pending_receipt_count': 2,
        'delayed_count': 1,
        'delivered_count': 0,
        'alerts': [
          {
            'courier_no': 'DHL-88776655',
            'courier_company': 'DHL',
            'import_file_id': 1,
            'import_file_code': 'IMP-2026-0001',
            'dispatch_date': '2026-09-01',
            'days_in_transit': 6,
            'alert_level': 'CRITICAL',
            'alert_message_ar': 'تأخير حرج: مضى 6 أيام',
            'alert_message_en': 'Critical delay: 6 days',
          }
        ],
      };

      final response = CourierAlertsResponseModel.fromJson(json);
      expect(response.totalActiveCouriers, 2);
      expect(response.delayedCount, 1);
      expect(response.alerts.length, 1);
      expect(response.alerts.first.courierCompany, 'DHL');
      expect(response.alerts.first.alertLevel, 'CRITICAL');
      expect(response.alerts.first.daysInTransit, 6);
    });

    test('CourierFlatItemModel and CourierReceiptProofRequestModel serialization', () {
      final flatJson = {
        'courier_no': 'FDX-112233',
        'courier_company': 'FedEx',
        'import_file_id': 2,
        'import_file_code': 'IMP-2026-0002',
        'is_received': true,
        'received_date': '2026-09-10',
        'received_time': '14:30',
        'received_by': 'Mohamed Ali',
        'pod_reference': 'POD-9988',
        'status': 'DELIVERED',
        'days_in_transit': 3,
        'associated_docs_count': 4,
      };

      final flat = CourierFlatItemModel.fromJson(flatJson);
      expect(flat.courierCompany, 'FedEx');
      expect(flat.isReceived, true);
      expect(flat.receivedBy, 'Mohamed Ali');
      expect(flat.status, 'DELIVERED');
      expect(flat.associatedDocsCount, 4);

      final req = CourierReceiptProofRequestModel(
        importFileId: 2,
        courierNo: 'FDX-112233',
        receivedDate: '2026-09-10',
        receivedTime: '14:30',
        receivedBy: 'Mohamed Ali',
        podReference: 'POD-9988',
        markDocumentsReceived: true,
      );
      final reqJson = req.toJson();
      expect(reqJson['import_file_id'], 2);
      expect(reqJson['courier_no'], 'FDX-112233');
      expect(reqJson['received_by'], 'Mohamed Ali');
      expect(reqJson['mark_documents_received'], true);
    });
  });

  group('OriginalDocumentsCollectionTab Widget Tests', () {
    testWidgets('Renders Original Documents Collection Tab, header, and courier alerts', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier()),
            originalDocumentsSessionsProvider.overrideWith((ref) => _MockOriginalDocsNotifier()),
            courierAlertsProvider.overrideWith((ref) async => CourierAlertsResponseModel(
                  totalActiveCouriers: 1,
                  pendingReceiptCount: 1,
                  delayedCount: 1,
                  alerts: [
                    CourierAlertItemModel(
                      courierNo: 'DHL-99881122',
                      courierCompany: 'DHL',
                      importFileId: 1,
                      importFileCode: 'IMP-2026-0001',
                      dispatchDate: '2026-09-01',
                      daysInTransit: 6,
                      alertLevel: 'CRITICAL',
                      alertMessageAr: 'تأخير حرج: مضى 6 أيام',
                      alertMessageEn: 'Critical delay: 6 days',
                    ),
                  ],
                )),
            allCouriersProvider.overrideWith((ref) async => [
                  CourierFlatItemModel(
                    courierNo: 'DHL-99881122',
                    courierCompany: 'DHL',
                    importFileId: 1,
                    importFileCode: 'IMP-2026-0001',
                    dispatchDate: '2026-09-01',
                    isReceived: false,
                    daysInTransit: 6,
                    associatedDocsCount: 3,
                  ),
                ]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OriginalDocumentsCollectionTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('تحصيل أصول المستندات وتتبع طرود الكورير'), findsOneWidget);
      expect(find.textContaining('اختيار ملف الشحنة'), findsOneWidget);
      expect(find.textContaining('تنبيهات ومتابعة الكورير ومواعيد الاستلام'), findsOneWidget);
      expect(find.textContaining('سجل تتبع الكورير وإثبات ميعاد الاستلام'), findsOneWidget);

      // Tap to switch to Courier Tracking Registry
      final courierTabFinder = find.textContaining('سجل تتبع الكورير وإثبات ميعاد الاستلام');
      await tester.ensureVisible(courierTabFinder);
      await tester.tap(courierTabFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('رقم بوليصة الشحن الجوي'), findsOneWidget);
    });
  });
}
