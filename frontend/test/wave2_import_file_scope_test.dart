// Wave 2 screens (split shipments, multimodal freight, container tracking) must not call the
// backend with a guessed shipment id: they wait for an import file to be picked, then use its id.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/widgets/import_file_scope_selector.dart';
import 'package:frontend/core/widgets/searchable_dropdown_field.dart';
import 'package:frontend/features/container_tracking/container_tracking_board_screen.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/multimodal_freight/multimodal_freight_screen.dart';
import 'package:frontend/features/split_shipments/split_shipments_screen.dart';

class _FakeImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> files;
  _FakeImportFilesNotifier(this.files) : super(Dio()) {
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

ImportFileModel _file(int id, String code) => ImportFileModel(
      importFileId: id,
      importFileCode: code,
      companyId: 1,
      companyName: 'Importer Co',
      supplierId: 2,
      supplierName: 'Supplier Co',
      shipmentMode: 'Sea FCL',
      incotermCode: 'CFR',
      priority: 'Normal',
      shipmentCategory: 'Commercial',
      status: 'Active',
      owner: 'Admin',
      progressPercent: 0.0,
      estimatedCost: 0.0,
      estimatedCostCurrency: 'USD',
      currentModule: 'Split',
      currentStage: 'Draft',
      nextAction: '',
      invoicesData: const [],
      packingListsData: const [],
      projectIds: const [],
      skippedStages: const [],
      createdAt: '2026-11-01T00:00:00Z',
      updatedAt: '2026-11-01T00:00:00Z',
    );

/// Records every request path and answers module endpoints with backend-shaped JSON.
Dio _recordingDio(List<String> paths, [List<Object?>? bodies]) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final path = options.path;
    // Query included: the air-freight records of a file are scoped by `?import_file_id=`.
    paths.add(options.queryParameters.isEmpty
        ? path
        : '$path?${Uri(queryParameters: options.queryParameters.map((k, v) => MapEntry(k, '$v'))).query}');
    bodies?.add(options.data);
    Object data = <String, dynamic>{};
    if (path.endsWith('/unallocated-po-items')) {
      data = {
        'shipment_id': 77,
        'bl_number': 'MSCU7700001',
        'total': 1,
        'items': [
          {
            'po_item_id': 501,
            'po_id': 50,
            'po_number': 'PO-REAL-7701',
            'item_sku': 'SKU-REAL-1',
            'item_name': 'بند حقيقي من أمر الشراء',
            'unit_of_measure': 'PCS',
            'total_quantity': 40,
            'allocated_quantity': 10,
            'remaining_quantity': 30,
          },
        ],
      };
    } else if (path.endsWith('/allocations')) {
      data = {
        'items': [
          {
            'id': 9,
            'shipment_id': 77,
            'parent_bl_number': 'MSCU7700001',
            'split_bl_number': 'MSCU7700001-A',
            'po_id': 50,
            'po_item_id': 501,
            'item_sku': 'SKU-REAL-1',
            'allocated_quantity': 10,
            'total_item_quantity': 40,
            'allocation_ratio': 0.25,
            'prorated_customs_cost': 0,
            'prorated_freight_cost': 0,
            'currency': 'EGP',
          },
        ],
        'total': 1,
      };
    } else if (path.contains('/split-shipments/')) {
      data = {'items': [], 'total': 0};
    } else if (path.contains('/multimodal-freight/') || path.contains('/container-tracking/')) {
      data = {'items': [], 'total': 0};
    } else if (path.contains('/air-freight/')) {
      data = <dynamic>[];
    }
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: data));
  }));
  return dio;
}

Future<void> _pump(WidgetTester tester, Widget screen, List<String> paths, [List<Object?>? bodies]) async {
  tester.view.physicalSize = const Size(1920, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(_recordingDio(paths, bodies)),
        importFilesProvider.overrideWith(
          (ref) => _FakeImportFilesNotifier([_file(77, 'IMP-2026-0077'), _file(88, 'IMP-2026-0088')]),
        ),
      ],
      child: MaterialApp(
        home: AppLocalizationsProvider(
          locale: const Locale('ar'),
          child: Directionality(textDirection: TextDirection.rtl, child: screen),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pickFile(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(ImportFileScopeSelector.fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(code).last);
  await tester.pumpAndSettle();
}

/// A module call carries the file id in its path (`/shipments/<id>/`) or as the `import_file_id` query.
bool _scopedTo(String uri, int id) => uri.contains('/shipments/$id/') || uri.contains('import_file_id=$id');

bool _isModuleCall(String path) =>
    path.contains('/split-shipments/') ||
    path.contains('/multimodal-freight/') ||
    path.contains('/air-freight/') ||
    path.contains('/container-tracking/');

void main() {
  final screens = <String, Widget Function({int? shipmentId})>{
    'SplitShipmentsScreen': ({int? shipmentId}) => SplitShipmentsScreen(shipmentId: shipmentId),
    'MultimodalFreightScreen': ({int? shipmentId}) => MultimodalFreightScreen(shipmentId: shipmentId),
    'ContainerTrackingBoardScreen': ({int? shipmentId}) => ContainerTrackingBoardScreen(shipmentId: shipmentId),
  };

  for (final entry in screens.entries) {
    group(entry.key, () {
      testWidgets('sends no module request and shows the empty state until a file is chosen', (tester) async {
        final paths = <String>[];
        await _pump(tester, entry.value(), paths);

        expect(find.byKey(ImportFileRequiredState.stateKey), findsOneWidget);
        expect(find.byType(SearchableDropdownField<int>), findsOneWidget);
        expect(paths.where(_isModuleCall), isEmpty);
      });

      testWidgets('uses the chosen file id in its requests', (tester) async {
        final paths = <String>[];
        await _pump(tester, entry.value(), paths);

        await _pickFile(tester, 'IMP-2026-0077');

        final moduleCalls = paths.where(_isModuleCall).toList();
        expect(moduleCalls, isNotEmpty);
        expect(moduleCalls.every((p) => _scopedTo(p, 77)), isTrue, reason: '$moduleCalls');
        expect(find.byKey(ImportFileRequiredState.stateKey), findsNothing);
      });

      testWidgets('keeps a shipmentId passed in from another screen', (tester) async {
        final paths = <String>[];
        await _pump(tester, entry.value(shipmentId: 88), paths);
        await tester.pumpAndSettle();

        final moduleCalls = paths.where(_isModuleCall).toList();
        expect(moduleCalls, isNotEmpty);
        expect(moduleCalls.every((p) => _scopedTo(p, 88)), isTrue, reason: '$moduleCalls');
        expect(find.byKey(ImportFileRequiredState.stateKey), findsNothing);
      });
    });
  }

  testWidgets('SplitShipmentsScreen renders the file\'s real PO lines and no hard-coded PO numbers', (tester) async {
    final paths = <String>[];
    await _pump(tester, const SplitShipmentsScreen(), paths);

    // Nothing PO-related before a file is chosen.
    expect(find.textContaining('PO-'), findsNothing);

    await _pickFile(tester, 'IMP-2026-0077');

    expect(paths, contains('/api/v1/split-shipments/shipments/77/unallocated-po-items'));
    expect(find.text('PO-REAL-7701'), findsOneWidget);
    expect(find.textContaining('PO-2026-4401'), findsNothing);
    expect(find.textContaining('PO-2026-4402'), findsNothing);
    expect(find.textContaining('SKU-INVERTER-5KW'), findsNothing);
    expect(find.textContaining('MEDU-99887766'), findsNothing);
  });

  testWidgets('SplitShipmentsScreen recalculates prorated costs with the pools the user enters', (tester) async {
    final paths = <String>[];
    final bodies = <Object?>[];
    await _pump(tester, const SplitShipmentsScreen(shipmentId: 77), paths, bodies);
    await tester.pumpAndSettle();

    await tester.tap(find.text('التكاليف التناسبية').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تحديث مجمع التكاليف'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('splitPoolCustomsField')), '1234.5');
    await tester.enterText(find.byKey(const Key('splitPoolFreightField')), '678');
    await tester.tap(find.text('تأكيد').last);
    await tester.pumpAndSettle();

    final index = paths.indexOf('/api/v1/split-shipments/shipments/77/calculate-prorated-costs');
    expect(index, isNot(-1));
    final body = bodies[index] as Map<String, dynamic>;
    expect(body['customs_cost_pool'], 1234.5);
    expect(body['freight_cost_pool'], 678.0);
  });
}
