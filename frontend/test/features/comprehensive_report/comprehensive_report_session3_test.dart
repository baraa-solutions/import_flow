import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/features/comprehensive_report/screens/import_file_comprehensive_report_screen.dart';
import 'package:frontend/features/comprehensive_report/services/comprehensive_dossier_service.dart';
import 'package:frontend/features/comprehensive_report/models/comprehensive_dossier_model.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    String jsonStr = '[]';
    if (path.contains('shipment-updates')) {
      jsonStr = '{"items":[],"total":0}';
    } else if (path.contains('smart-checklists')) {
      jsonStr = '{"readinessScorePct":100,"isGateBlocked":false,"items":[]}';
    } else if (path.contains('purchase-orders')) {
      jsonStr = '[]';
    } else if (path.contains('customs-clearance')) {
      jsonStr = '[]';
    } else if (path.contains('warehouse-receiving')) {
      jsonStr = '[]';
    }
    return ResponseBody.fromString(jsonStr, 200, headers: {
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

class _MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> _files;
  _MockImportFilesNotifier(this._files, Dio dio) : super(dio) {
    state = AsyncValue.data(_files);
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
    state = AsyncValue.data(_files);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleFile = ImportFileModel(
    importFileId: 105,
    importFileCode: 'IMP-2026-0005',
    customFileNumber: 'CFN-8899',
    companyName: 'SCAS For Construction And Finishing',
    supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
    status: 'In Progress',
    currentStage: 'Phase 5: International Cargo Shipping',
    currentModule: 'P5',
    currentPhaseId: 5,
    progressPercent: 50.0,
    nextAction: 'Cargo Arrival',
    shipmentMode: 'Sea FCL',
    incotermCode: 'EXW',
    shipmentCategory: 'Standard Commercial',
    priority: 'High',
    form4No: null, // Pending Form 4
    acidNumber: '5281534391023010013',
    owner: 'Operations Team',
    createdAt: '2026-10-01T10:00:00Z',
    updatedAt: '2026-10-25T14:30:00Z',
  );

  final sampleDossier = ComprehensiveShipmentDossierModel(
    importFileId: 105,
    importFileCode: 'IMP-2026-0005',
    customFileNumber: 'CFN-8899',
    status: 'In Progress',
    currentStage: 'Phase 5: International Cargo Shipping',
    currentModule: 'P5',
    progressPercent: 50.0,
    nextAction: 'Cargo Arrival',
    companyId: 1,
    companyName: 'SCAS For Construction And Finishing',
    supplierId: 2,
    supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
    shipmentMode: 'Sea FCL',
    incotermCode: 'EXW',
    shipmentCategory: 'Standard Commercial',
    priority: 'High',
    commodity: 'PET Acoustic Panels',
    portOfLoading: 'Shanghai Port',
    portOfDischarge: 'El Dekheila Port',
    totalPackages: 144,
    grossWeightKg: 10510.0,
    netWeightKg: 10080.0,
    totalCbm: 66.388,
    targetFreeDays: 21,
    acidNumber: '5281534391023010013',
    createdAt: '2026-10-01',
    updatedAt: '2026-10-25',
    smartRecommendation: 'اقتراح شحن بحري حاوية كاملة (Sea FCL) لأن الحجم (66.39 m³) يبلغ 15 m³ أو أكثر.',
  );

  Widget createTestWidget({
    int? initialFileId,
    int? providerFileId,
  }) {
    final testDio = _createTestDio();
    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(testDio),
        if (providerFileId != null)
          selectedComprehensiveReportFileIdProvider.overrideWith((ref) => providerFileId),
        importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([sampleFile], testDio)),
        comprehensiveDossierProvider(105).overrideWith((ref) async => sampleDossier),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocales.supportedLocales,
        localizationsDelegates: AppLocales.localizationsDelegates,
        home: AppLocalizationsProvider(
          locale: const Locale('ar'),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ImportFileComprehensiveReportScreen(initialFileId: initialFileId),
          ),
        ),
      ),
    );
  }

  group('Session 3: Comprehensive Report Screen Engineering', () {
    testWidgets('3.1 Auto-Select via Deep Link / Parameter loads shipment 105 automatically', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(initialFileId: 105));
      await tester.pumpAndSettle();

      // Verify that the file displayName IMP-2026-0005 is selected and displayed
      expect(find.text('IMP-2026-0005'), findsWidgets);
      expect(find.byKey(const Key('openOperationalDetailsHeaderBtn')), findsOneWidget);
    });

    testWidgets('3.2 BiDi / RTL Fix displays recommendation text and isolation marks smoothly', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(initialFileId: 105));
      await tester.pumpAndSettle();

      // Find the rich text recommendation banner
      final recommendationFinder = find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          final plainText = widget.text.toPlainText();
          return plainText.contains('اقتراح شحن بحري حاوية كاملة') &&
                 plainText.contains('Sea FCL') &&
                 plainText.contains('m³');
        }
        return false;
      });

      expect(recommendationFinder, findsWidgets);
    });

    testWidgets('3.3 Displays importing company SCAS For Construction And Finishing clearly in header', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(initialFileId: 105));
      await tester.pumpAndSettle();

      // Header should display importing company
      expect(find.textContaining('الشركة المستوردة: SCAS For Construction And Finishing'), findsWidgets);
      // Header should display foreign supplier
      expect(find.textContaining('المورد الأجنبي: Suzhou Yuheng Textile Co.,Ltd'), findsWidgets);
    });

    testWidgets('3.4 Interactive Action Triggers: Reverse button and Form 4 quick dialog trigger', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(initialFileId: 105));
      await tester.pumpAndSettle();

      // 1. Reverse Button in Header
      final reverseBtnFinder = find.byKey(const Key('openOperationalDetailsHeaderBtn'));
      expect(reverseBtnFinder, findsOneWidget);
      expect(find.text('فتح شاشة التشغيل والمحطات P5 ↵'), findsOneWidget);

      // 2. Bank Form 4 pending trigger in Documents Card
      final form4QuickBtn = find.byKey(const Key('openForm4DialogQuickBtn'));
      expect(form4QuickBtn, findsOneWidget);
      expect(find.text('معلق'), findsWidgets);
    });
  });
}
