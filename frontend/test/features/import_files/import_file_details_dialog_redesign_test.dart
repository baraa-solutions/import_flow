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
import 'package:frontend/features/import_files/widgets/shipment_milestone_tracker.dart';

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

ImportFileModel _createSampleFile() {
  return ImportFileModel(
    importFileId: 4,
    importFileCode: 'IMP-2026-0004',
    customFileNumber: 'PET Stock',
    companyId: 1,
    companyName: 'SCAS FOR CONSTRUCTION AND FINISHING',
    supplierId: 2,
    supplierName: 'SUZHOU YUHENG TEXTILE CO.,LTD',
    poNumber: 'PO-2026-0004',
    piNumber: 'PI-2026-0004',
    shipmentMode: 'Sea FCL',
    incotermCode: 'CIF',
    priority: 'High',
    currentModule: 'STEP_07 تخصيص وتوزيع الحاويات والـ VGM',
    currentStage: 'Phase 3: Booking & Doc Prep',
    progressPercent: 33.3,
    nextAction: 'تدقيق أوزان VGM واعتماد مسودات مستندات الشحن',
    acidNumber: '5281534391023010013',
    selectedScenario: 'Wan Hai Lines Ltd. (WAN HAI 511)',
    status: 'In Progress',
    productCategory: 'PET Acoustic Panels',
    createdAt: '2026-08-18T10:00:00',
    updatedAt: '2026-09-14T10:00:00',
  );
}

void main() {
  testWidgets('Session 2: ImportFileDetailsDialog renders without overflow on 1366x768', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final file = _createSampleFile();
    final dio = _createTestDio();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          localeProvider.overrideWith((ref) {
            final n = LocaleNotifier();
            n.setLocale(const Locale('ar'));
            return n;
          }),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            return MaterialApp(
              locale: const Locale('ar'),
              home: AppLocalizationsProvider(
                locale: const Locale('ar'),
                child: Scaffold(
                  body: Builder(
                    builder: (ctx) {
                      return ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: ctx,
                            builder: (_) => ImportFileDetailsDialog(
                              file: file,
                              linkedPOs: const [],
                              invoiceNumbers: const {},
                              totalPackingListCbm: 66.39,
                              totalPackingListWeight: 10510.0,
                              totalPackingListsCount: 1,
                            ),
                          );
                        },
                        child: const Text('Open Dialog'),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    // Open Dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify 2.1: Dropdown menus exist instead of 3269px horizontal row
    expect(find.text('نماذج ومحاكاة ▾'), findsOneWidget);
    expect(find.text('مستندات الشحنة ▾'), findsOneWidget);

    // Verify 2.2: Dossier Bridge Action button exists with prominent label
    final bridgeBtn = find.byKey(const Key('openMasterReportScreenBtn'));
    expect(bridgeBtn, findsOneWidget);
    expect(find.text('عرض التقرير والبطاقة الفنية الشاملة ↗'), findsOneWidget);

    // Verify 2.3: Mini Quick-Facts Bar shows volume, weight, and carrier
    expect(find.descendant(of: find.byType(ShipmentMilestoneTracker), matching: find.text('66.39 m³')), findsOneWidget);
    expect(find.descendant(of: find.byType(ShipmentMilestoneTracker), matching: find.text('10,510 كجم')), findsOneWidget);
    expect(find.descendant(of: find.byType(ShipmentMilestoneTracker), matching: find.text('Wan Hai')), findsOneWidget);

    // Verify 2.4: Knowledge Gate for acoustic goods renders smoothly
    expect(find.text('بوابة المعرفة والإنذار التشغيلي'), findsOneWidget);
    expect(find.textContaining('ميناء الوصول يجب أن يكون الإسكندرية حصراً'), findsOneWidget);

    // Tap models & simulations dropdown
    await tester.tap(find.text('نماذج ومحاكاة ▾'));
    await tester.pumpAndSettle();
    expect(find.text('المحاكاة الجمركية'), findsOneWidget);
    expect(find.text('طلب دفعة المورد (FN-01)'), findsOneWidget);

    // Close menu by tapping outside
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Tap Dossier Bridge button
    await tester.tap(bridgeBtn);
    await tester.pumpAndSettle();

    // Dialog should be closed (pop called)
    expect(find.byType(ImportFileDetailsDialog), findsNothing);
  });
}
