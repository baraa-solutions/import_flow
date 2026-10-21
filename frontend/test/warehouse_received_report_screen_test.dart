import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/dio_client.dart';
import 'package:frontend/features/warehouse_receiving/models/warehouse_receiving_model.dart';
import 'package:frontend/features/warehouse_receiving/providers/warehouse_receiving_provider.dart';
import 'package:frontend/features/warehouse_receiving/screens/warehouse_received_report_screen.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('[]', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockHttpClientAdapter();
  return dio;
}

class _MockWarehouseReceivingNotifier extends WarehouseReceivingNotifier {
  final List<WarehouseReceivingModel> mockRecords;
  _MockWarehouseReceivingNotifier(this.mockRecords, Dio dio) : super(dio) {
    state = AsyncValue.data(mockRecords);
  }

  @override
  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search, int skip = 0, int limit = 200}) async {
    state = AsyncValue.data(mockRecords);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockRecord1 = WarehouseReceivingModel(
    receivingId: 1,
    grnCode: 'GRN-2026-001',
    importFileId: 101,
    warehouseName: 'Main Warehouse - Cairo',
    arrivalDatetime: '2026-09-08 10:00:00',
    truckPlateNumber: 'TRK-987',
    driverName: 'Mohamed',
    grnItems: [
      GrnItemModel(
        poNumber: 'PO-MAIN-101',
        itemCode: 'SKU-001',
        itemName: 'Industrial Ball Bearings',
        invoicedQty: 500,
        acceptedQty: 485,
        shortageQty: 10,
        damagedQty: 5,
      ),
    ],
    totalInvoicedQty: 500,
    totalAcceptedQty: 485,
    totalShortageQty: 10,
    totalDamagedQty: 5,
    createdAt: '2026-09-08',
    updatedAt: '2026-09-08',
  );

  final mockRecord2 = WarehouseReceivingModel(
    receivingId: 2,
    grnCode: 'GRN-2026-002',
    importFileId: 102,
    warehouseName: 'Alexandria Hub',
    arrivalDatetime: '2026-09-09 11:30:00',
    truckPlateNumber: 'TRK-456',
    driverName: 'Ahmed',
    grnItems: [
      GrnItemModel(
        itemCode: 'SKU-002',
        itemName: 'Electronic Flow Sensor',
        invoicedQty: 200,
        acceptedQty: 200,
        shortageQty: 0,
        damagedQty: 0,
      ),
    ],
    totalInvoicedQty: 200,
    totalAcceptedQty: 200,
    totalShortageQty: 0,
    totalDamagedQty: 0,
    createdAt: '2026-09-09',
    updatedAt: '2026-09-09',
  );

  String? lastCopiedText;

  setUp(() {
    lastCopiedText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          lastCopiedText = (methodCall.arguments as Map)['text'] as String?;
          return null;
        }
        return null;
      },
    );
  });

  Widget buildTestScreen({
    Locale locale = const Locale('ar'),
    List<WarehouseReceivingModel>? records,
  }) {
    final testDio = _createTestDio();
    final receivingRecords = records ?? [mockRecord1, mockRecord2];
    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(testDio),
        warehouseReceivingProvider.overrideWith(
          (ref) => _MockWarehouseReceivingNotifier(receivingRecords, testDio),
        ),
        // The report shows the real file code from the import files list (no invented "IMP-{id}").
        importFilesProvider.overrideWith((ref) => _FileCodesNotifier([
              ImportFileModel.fromJson({'import_file_id': 101, 'import_file_code': 'IMP-101'}),
              ImportFileModel.fromJson({'import_file_id': 102, 'import_file_code': 'IMP-102'}),
            ])),
      ],
      child: AppLocalizationsProvider(
        locale: locale,
        child: MaterialApp(
          home: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: const Scaffold(
              body: WarehouseReceivedReportScreen(isEmbedded: true),
            ),
          ),
        ),
      ),
    );
  }

  group('Screen 64: WarehouseReceivedReportScreen Widget & Copy Tests', () {
    testWidgets('Renders with SelectionArea and 4 export toolbar buttons (Arabic)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // 1. SelectionArea root verification
      expect(find.byType(SelectionArea), findsWidgets);

      // 2. Export toolbar buttons
      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget); // TSV
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget); // Excel
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget); // PDF
      expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget); // Dossier
    });

    testWidgets('Renders 6 KPI metric cards with correct calculated values', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // Invoiced: 500 + 200 = 700
      expect(find.text('700 وحدة'), findsOneWidget);
      // Received: 485 + 200 = 685
      expect(find.text('685 وحدة'), findsOneWidget);
      // Damaged: 5
      expect(find.text('5 وحدة'), findsOneWidget);
      // Shortage: 10
      expect(find.text('10 وحدة'), findsOneWidget);
      // Variance: -15
      expect(find.text('-15 وحدة'), findsOneWidget);
    });

    testWidgets('Search bar with copy suffix button copies query and clear button clears text', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final searchFinder = find.byType(TextField);
      expect(searchFinder, findsOneWidget);

      await tester.enterText(searchFinder, 'SKU-001');
      await tester.pumpAndSettle();

      // Search filters rows to 1 item
      expect(find.text('IMP-101'), findsOneWidget);
      expect(find.text('IMP-102'), findsNothing);

      // Copy suffix button appears
      final copySuffixFinder = find.byIcon(Icons.copy_rounded);
      expect(copySuffixFinder, findsWidgets);

      await tester.tap(copySuffixFinder.first);
      await tester.pumpAndSettle();
      expect(lastCopiedText, 'SKU-001');

      // Clear button clears search
      final clearFinder = find.byIcon(Icons.clear);
      expect(clearFinder, findsOneWidget);
      await tester.tap(clearFinder);
      await tester.pumpAndSettle();

      expect(find.text('IMP-101'), findsOneWidget);
      expect(find.text('IMP-102'), findsOneWidget);
    });

    testWidgets('Clickable copy badges copy importFileCode, poNumber, and itemCode to clipboard', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // Copy Import File Code
      final impFinder = find.text('IMP-101');
      expect(impFinder, findsOneWidget);
      await tester.ensureVisible(impFinder);
      await tester.tap(impFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(lastCopiedText, 'IMP-101');

      // Copy PO Number
      final poFinder = find.text('PO-MAIN-101');
      expect(poFinder, findsOneWidget);
      await tester.ensureVisible(poFinder);
      await tester.tap(poFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(lastCopiedText, 'PO-MAIN-101');

      // Copy Item Code
      final itemFinder = find.text('SKU-001');
      expect(itemFinder, findsOneWidget);
      await tester.ensureVisible(itemFinder);
      await tester.tap(itemFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(lastCopiedText, 'SKU-001');
    });

    testWidgets('Quick row summary copy button copies formatted row summary', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // Find copy row buttons
      final rowCopyButtons = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'نسخ ملخص بيانات السطر',
      );
      expect(rowCopyButtons, findsNWidgets(2));

      await tester.ensureVisible(rowCopyButtons.first);
      await tester.tap(rowCopyButtons.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(lastCopiedText, isNotNull);
      expect(lastCopiedText, contains('IMP-101'));
      expect(lastCopiedText, contains('PO-MAIN-101'));
      expect(lastCopiedText, contains('SKU-001'));
      expect(lastCopiedText, contains('500'));
      expect(lastCopiedText, contains('485'));
    });

    testWidgets('Renders in English mode with zero issues', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestScreen(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.text('Export TSV'), findsOneWidget);
      expect(find.text('Export Excel'), findsOneWidget);
      expect(find.text('Print PDF Report'), findsOneWidget);
      expect(find.text('Copy Comprehensive Dossier'), findsOneWidget);
      expect(find.text('700 units'), findsOneWidget);
      expect(find.text('IMP-101'), findsOneWidget);
      // No invented "Approved & Received": the mock records carry no status, so none is shown.
      expect(find.text('Approved & Received'), findsNothing);
    });
  });
}


class _FileCodesNotifier extends StateNotifier<AsyncValue<List<ImportFileModel>>> implements ImportFilesNotifier {
  _FileCodesNotifier(List<ImportFileModel> files) : super(AsyncValue.data(files));

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
