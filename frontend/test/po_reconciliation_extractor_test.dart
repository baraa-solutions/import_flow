import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_documentation/models/po_reconciliation_session_model.dart';
import 'package:frontend/features/import_documentation/providers/import_documentation_provider.dart';
import 'package:frontend/features/import_documentation/widgets/po_reconciliation_tab.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';

class MockImportFilesNotifier extends StateNotifier<AsyncValue<List<ImportFileModel>>>
    implements ImportFilesNotifier {
  MockImportFilesNotifier()
      : super(
          AsyncValue.data([
            ImportFileModel(
              importFileId: 101,
              importFileCode: 'IMP-2026-00101',
              companyName: 'ECO ASSOCIATES',
              supplierName: 'G.I. INDUSTRIAL HOLDING SPA',
              piNumber: 'V1/ 2562',
              status: 'Draft Documents',
              invoicesData: [],
              packingListsData: [],
              projectIds: [],
              shipmentMode: 'Sea',
              incotermCode: 'EXW',
              priority: 'Normal',
              shipmentCategory: 'Commercial',
              estimatedCost: 37741.0,
              estimatedCostCurrency: 'EUR',
              currentModule: 'Import Documentation',
              currentStage: 'Draft Documents',
              progressPercent: 65.0,
              nextAction: 'Reconcile Final PO',
              isCustomsReleased: false,
              isActive: true,
              createdAt: DateTime.now().toString(),
              updatedAt: DateTime.now().toString(),
            )
          ]),
        );

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPurchaseOrdersNotifier extends StateNotifier<PurchaseOrdersState>
    implements PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier() : super(PurchaseOrdersState());

  @override
  Future<void> fetchPurchaseOrders() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPOReconciliationSessionsNotifier
    extends StateNotifier<AsyncValue<List<POReconciliationSessionModel>>>
    implements POReconciliationSessionsNotifier {
  MockPOReconciliationSessionsNotifier()
      : super(
          AsyncValue.data([
            POReconciliationSessionModel(
              sessionId: 1,
              sessionCode: 'REC-2026-0001',
              importFileId: 101,
              importFileCode: 'IMP-2026-00101',
              importerName: 'ECO ASSOCIATES',
              finalInvoiceNumber: 'V1/2562',
              finalPackingListNumber: 'M26 413',
              acidNumber: '2001830441013710010',
              shipperName: 'G.I. INDUSTRIAL HOLDING SPA',
              totalInvoiceAmount: 37741.0,
              currency: 'EUR',
              totalPackages: 4,
              totalNetWeightKg: 2254.0,
              totalGrossWeightKg: 2274.0,
              totalCbm: 39.99,
              overallStatus: 'FULLY_MATCHED',
              isSafeForCertification: true,
              criticalDiscrepanciesCount: 0,
              warningDiscrepanciesCount: 0,
              createdAt: '2026-08-17 12:00:00',
              updatedAt: '2026-08-17 12:00:00',
            )
          ]),
        );

  @override
  Future<void> fetchSessions({int? importFileId, String? search, String? overallStatus}) async {}

  @override
  Future<POReconciliationSessionModel> createSession(POReconciliationSessionModel payload) async {
    return payload;
  }

  @override
  Future<POReconciliationSessionModel> updateSession(int id, Map<String, dynamic> data) async {
    return state.value!.first;
  }

  @override
  Future<bool> deleteSession(int id) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('POReconciliationTab renders smart extraction tool card and saved sessions in single unified screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importFilesProvider.overrideWith((ref) => MockImportFilesNotifier()),
          purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier()),
          poReconciliationSessionsProvider.overrideWith((ref) => MockPOReconciliationSessionsNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: POReconciliationTab(initialImportFileId: 101),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify presence of Editor and Saved Sessions Sections on Unified Screen
    expect(find.textContaining('سجل جلسات المطابقة المحفوظة'), findsWidgets);

    // Verify presence of the Smart Extraction & 3-Way Reconciliation Tool Card
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);
    expect(find.textContaining('الفاتورة التجارية النهائية'), findsWidgets);
    expect(find.textContaining('قائمة التعبئة والأوزان'), findsWidgets);

    // Verify 1-Click Sample Button
    final sampleButton = find.byIcon(Icons.dataset_linked);
    expect(sampleButton, findsOneWidget);

    // Tap 1-Click Sample Button
    await tester.tap(sampleButton);
    await tester.pumpAndSettle();

    // Verify sample text is loaded into inputs
    expect(find.textContaining('G.I. INDUSTRIAL HOLDING SPA'), findsWidgets);
    expect(find.textContaining('2001830441013710010'), findsWidgets);
    expect(find.textContaining('RTAXT/K/EC/MS 182'), findsWidgets);

    // Verify saved session row exists with REC-2026-0001 in the unified registry below
    expect(find.text('REC-2026-0001'), findsWidgets);
    expect(find.text('ECO ASSOCIATES'), findsWidgets);
    expect(find.text('37741.00 EUR'), findsOneWidget);
  });
}

