@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/widgets/import_file_details_dialog.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart' as po_models;

class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode([]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockHttpAdapter();
  return dio;
}

ImportFileModel _createSampleImportFile() {
  return ImportFileModel(
    importFileId: 101,
    importFileCode: 'IMP-2026-0001',
    customFileNumber: 'Customs-File-2026-001',
    companyId: 1,
    companyName: 'El Ezz Steel Import Co.',
    supplierId: 2,
    supplierName: 'Shanghai Global Metals Ltd.',
    poNumber: 'PO-2026-089',
    piNumber: 'PI-998822',
    invoicesData: [
      InvoiceItemModel(
        invoiceNo: 'INV-2026-001',
        invoiceType: 'Commercial Invoice',
        amount: 85000.0,
        currency: 'USD',
      ),
    ],
    packingListsData: [
      PackingListItemModel(
        plNo: 'PL-2026-001',
        totalPackages: 120,
        grossWeightKg: 18500.0,
        cbm: 48.5,
        isStackable: true,
      ),
    ],
    shipmentMode: 'Sea FCL',
    incotermCode: 'CIF',
    priority: 'High',
    currentModule: 'Customs Clearance',
    currentStage: 'Customs Valuation',
    progressPercent: 65.0,
    nextAction: 'Pay customs duty and VAT',
    acidNumber: 'ACID-9928371829',
    acidRequestDate: '2026-08-01',
    acidIssueDate: '2026-08-05',
    acidExpiryDate: '2026-11-05',
    acidExecutionDays: 4,
    isCustomsReleased: false,
    form4No: 'F4-8839201',
    form4RequestDate: '2026-08-10',
    form4ReceivedDate: '2026-08-14',
    form4ExecutionDays: 4,
    status: 'In Progress',
    owner: 'Ahmed Sorour',
    createdAt: '2026-08-01T10:00:00',
    updatedAt: '2026-08-15T14:30:00',
  );
}

PurchaseOrderModel _createSamplePO() {
  return PurchaseOrderModel(
    poId: 201,
    poNumber: 'PO-2026-089',
    proformaInvoiceNumber: 'PI-998822',
    countryOfOrigin: 'China',
    importFileId: 101,
    projectId: 1,
    companyId: 1,
    supplierId: 2,
    incotermId: 1,
    currencyId: 1,
    currencyCode: 'USD',
    totalAmountFob: 85000.0,
    totalCbm: 48.5,
    totalGrossWeightKg: 18500.0,
    totalPackagesCount: 120,
    palletCount: 20,
    status: 'In Clearance',
    items: [
      POLineItemModel(
        itemId: 501,
        poId: 201,
        itemCode: 'STL-HR-001',
        descriptionAr: 'لفائف حديد مجلفن عالي المقاومة',
        quantity: 120.0,
        unitPrice: 708.33,
        totalPrice: 85000.0,
        cbmPerUnit: 0.404,
        totalCbm: 48.5,
        grossWeightKg: 18500.0,
        netWeightKg: 18200.0,
      ),
    ],
    packingListItems: [
      po_models.PackingListItemModel(
        packingItemId: 601,
        poId: 201,
        hsCode: '7210.49.00',
        itemCode: 'STL-HR-001',
        qtyPcs: 120.0,
        qtyPkg: 20.0,
        lengthCm: 120.0,
        widthCm: 80.0,
        heightCm: 150.0,
        totalGrossWeightKg: 18500.0,
        totalCbm: 48.5,
        isStackable: true,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modal Dialog: ImportFileDetailsDialog Performance Diagnostics', () {
    testWidgets('Measure Dimension A and Dimension B across 3 runs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleFile = _createSampleImportFile();
      final samplePO = _createSamplePO();
      final testDio = _createTestDio();

      final List<int> navInFirstFrameTimes = [];
      final List<int> navInSettledTimes = [];
      final List<int> navOutTimes = [];

      // Warm-up run to eliminate cold JIT compilation overhead
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(testDio),
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
          ],
          child: MaterialApp(
            home: AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ImportFileDetailsDialog(
                  file: sampleFile,
                  linkedPOs: [samplePO],
                  invoiceNumbers: const {'INV-2026-001'},
                  totalPackingListCbm: 48.5,
                  totalPackingListWeight: 18500.0,
                  totalPackingListsCount: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Empty Destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 1; i <= 3; i++) {
        final navWatch = Stopwatch()..start();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(testDio),
              localeProvider.overrideWith((ref) {
                final n = LocaleNotifier();
                n.setLocale(const Locale('ar'));
                return n;
              }),
            ],
            child: MaterialApp(
              home: AppLocalizationsProvider(
                locale: const Locale('ar'),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ImportFileDetailsDialog(
                    file: sampleFile,
                    linkedPOs: [samplePO],
                    invoiceNumbers: const {'INV-2026-001'},
                    totalPackingListCbm: 48.5,
                    totalPackingListWeight: 18500.0,
                    totalPackingListsCount: 1,
                  ),
                ),
              ),
            ),
          ),
        );

        final firstFrameMs = navWatch.elapsedMilliseconds;
        navInFirstFrameTimes.add(firstFrameMs);

        await tester.pumpAndSettle();
        navWatch.stop();
        final settledMs = navWatch.elapsedMilliseconds;
        navInSettledTimes.add(settledMs);

        final outWatch = Stopwatch()..start();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Empty Destination')),
            ),
          ),
        );

        await tester.pumpAndSettle();
        outWatch.stop();
        final navOutMs = outWatch.elapsedMilliseconds;
        navOutTimes.add(navOutMs);

        debugPrint('Run #$i: Nav-IN (First Frame): ${firstFrameMs}ms | Nav-IN (Settled): ${settledMs}ms | Nav-OUT: ${navOutMs}ms');
      }

      final avgFirstFrame = navInFirstFrameTimes.reduce((a, b) => a + b) ~/ navInFirstFrameTimes.length;
      final avgSettled = navInSettledTimes.reduce((a, b) => a + b) ~/ navInSettledTimes.length;
      final avgNavOut = navOutTimes.reduce((a, b) => a + b) ~/ navOutTimes.length;

      debugPrint('==================================================');
      debugPrint('MODAL (ImportFileDetailsDialog) BENCHMARK RESULTS:');
      debugPrint('Average Nav-IN First Frame: ${avgFirstFrame}ms');
      debugPrint('Average Nav-IN Settled:     ${avgSettled}ms');
      debugPrint('Average Nav-OUT (Disposal): ${avgNavOut}ms');
      debugPrint('==================================================');

      expect(avgFirstFrame, lessThanOrEqualTo(300));
      expect(avgSettled, lessThanOrEqualTo(350));
      expect(avgNavOut, lessThanOrEqualTo(150));
    });
  });
}
