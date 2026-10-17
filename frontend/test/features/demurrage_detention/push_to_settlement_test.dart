import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/demurrage_detention/models/demurrage_model.dart';
import 'package:frontend/features/demurrage_detention/providers/demurrage_provider.dart';
import 'package:frontend/features/demurrage_detention/screens/demurrage_detention_screen.dart';
import 'package:frontend/features/demurrage_detention/widgets/demurrage_form_dialogs.dart';
import 'package:frontend/features/demurrage_detention/widgets/demurrage_tracking_card.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  List<Map<String, dynamic>> trackings = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final path = options.path;
    if (path.contains('/push-to-settlement')) {
      return ResponseBody.fromString(
        jsonEncode({'success': true, 'settlement_record_id': 99}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    if (path.endsWith('/trackings')) {
      return ResponseBody.fromString(
        jsonEncode(trackings),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    if (path.endsWith('/policies')) {
      return ResponseBody.fromString(
        jsonEncode([]),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _makeTrackingJson({
  required int trackingId,
  int? importFileId,
  String? importFileCode,
  bool isPushed = false,
  double demFx = 150.0,
  double detFx = 80.0,
  double storEgp = 1200.0,
  double? rate = 48.5,
  double totalEgp = 12355.0,
}) {
  return {
    'tracking_id': trackingId,
    'tracking_code': 'DND-2026-0001',
    'import_file_id': importFileId,
    'import_file_code': importFileCode,
    'carrier_name': 'MSC',
    'bill_of_lading_no': 'MEDU1234567',
    'port_name': 'Alexandria Port',
    'discharge_date': '2026-03-01',
    'containers': [],
    'total_demurrage_fx': demFx,
    'total_detention_fx': detFx,
    'total_storage_egp': storEgp,
    'currency': 'USD',
    'exchange_rate': rate,
    'total_cost_egp': totalEgp,
    'status': 'Free Time Active',
    'is_pushed_to_settlement': isPushed,
    'is_active': true,
  };
}

DemurrageTrackingModel _makeTracking({
  required int trackingId,
  int? importFileId,
  String? importFileCode,
  bool isPushed = false,
  double demFx = 150.0,
  double detFx = 80.0,
  double storEgp = 1200.0,
  double? rate = 48.5,
  double totalEgp = 12355.0,
}) {
  return DemurrageTrackingModel.fromJson(
    _makeTrackingJson(
      trackingId: trackingId,
      importFileId: importFileId,
      importFileCode: importFileCode,
      isPushed: isPushed,
      demFx: demFx,
      detFx: detFx,
      storEgp: storEgp,
      rate: rate,
      totalEgp: totalEgp,
    ),
  );
}

Widget _wrapWidget(Widget child, {ProviderContainer? container, Locale locale = const Locale('en')}) {
  final app = AppLocalizationsProvider(
    locale: locale,
    child: MaterialApp(
      locale: locale,
      home: Scaffold(body: child),
    ),
  );
  if (container != null) {
    return UncontrolledProviderScope(container: container, child: app);
  }
  return ProviderScope(child: app);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FE05-T01: DemurrageNotifier.pushToSettlement provider method', () {
    test('sends import_file_id ONLY when importFileId is non-null', () async {
      final adapter = _RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(demurrageProvider.notifier);

      // Call without importFileId
      await notifier.pushToSettlement(42);
      final pushReq1 = adapter.requests.firstWhere(
        (r) => r.path.contains('/demurrage-detention/trackings/push-to-settlement'),
      );
      final data1 = pushReq1.data as Map;
      expect(data1['tracking_id'], 42);
      expect(data1.containsKey('import_file_id'), isFalse);

      // Call with importFileId == 7
      adapter.requests.clear();
      await notifier.pushToSettlement(42, importFileId: 7);
      final pushReq2 = adapter.requests.firstWhere(
        (r) => r.path.contains('/demurrage-detention/trackings/push-to-settlement'),
      );
      final data2 = pushReq2.data as Map;
      expect(data2['tracking_id'], 42);
      expect(data2['import_file_id'], 7);
    });
  });

  group('FE05-T01: DemurrageTrackingCard button state & tooltip', () {
    testWidgets('unlinked tracking (importFileId == null) disables push button with tooltip', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final item = _makeTracking(trackingId: 10, importFileId: null);
      bool pushed = false;

      await tester.pumpWidget(
        _wrapWidget(
          DemurrageTrackingCard(
            item: item,
            onCopySummary: () {},
            onPrintSlip: () {},
            onOpenRadar: () {},
            onUpdateDates: () {},
            onReturnContainers: () {},
            onPushToSettlement: () => pushed = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final btnFinder = find.byKey(const Key('pushToSettlementBtn_10'));
      expect(btnFinder, findsOneWidget);

      // Button is disabled
      final elevatedBtn = tester.widget<ElevatedButton>(
        find.descendant(of: btnFinder, matching: find.byType(ElevatedButton)),
      );
      expect(elevatedBtn.onPressed, isNull);

      // Tooltip is present with demPushNeedsLinkedFile explanation
      final tooltipFinder = find.descendant(of: btnFinder, matching: find.byType(Tooltip));
      expect(tooltipFinder, findsOneWidget);
      final tooltip = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltip.message, contains('link an import file first'));

      // Tapping does nothing
      await tester.tap(btnFinder);
      await tester.pump();
      expect(pushed, isFalse);
    });

    testWidgets('linked tracking (importFileId == 7) enables push button and invokes callback', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final item = _makeTracking(trackingId: 10, importFileId: 7, importFileCode: 'IMP-2026-0007');
      bool pushed = false;

      await tester.pumpWidget(
        _wrapWidget(
          DemurrageTrackingCard(
            item: item,
            onCopySummary: () {},
            onPrintSlip: () {},
            onOpenRadar: () {},
            onUpdateDates: () {},
            onReturnContainers: () {},
            onPushToSettlement: () => pushed = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final btnFinder = find.byKey(const Key('pushToSettlementBtn_10'));
      expect(btnFinder, findsOneWidget);

      final elevatedBtn = tester.widget<ElevatedButton>(
        find.descendant(of: btnFinder, matching: find.byType(ElevatedButton)),
      );
      expect(elevatedBtn.onPressed, isNotNull);

      await tester.tap(btnFinder);
      await tester.pump();
      expect(pushed, isTrue);
    });

    testWidgets('already pushed tracking shows alreadyPushedToSettlementBtn disabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final item = _makeTracking(trackingId: 10, importFileId: 7, isPushed: true);

      await tester.pumpWidget(
        _wrapWidget(
          DemurrageTrackingCard(
            item: item,
            onCopySummary: () {},
            onPrintSlip: () {},
            onOpenRadar: () {},
            onUpdateDates: () {},
            onReturnContainers: () {},
            onPushToSettlement: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('alreadyPushedToSettlementBtn_10')), findsOneWidget);
      expect(find.byKey(const Key('pushToSettlementBtn_10')), findsNothing);
    });
  });

  group('FE05-T01: DemurragePushToSettlementConfirmDialog', () {
    testWidgets('renders all cost breakdown details and handles cancel/confirm', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final item = _makeTracking(
        trackingId: 12,
        importFileId: 7,
        importFileCode: 'IMP-2026-0007',
        demFx: 350.0,
        detFx: 120.0,
        storEgp: 2400.0,
        rate: 50.0,
        totalEgp: 25900.0,
      );

      bool? result;

      await tester.pumpWidget(
        _wrapWidget(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await DemurragePushToSettlementConfirmDialog.show(ctx, item);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pushToSettlementConfirmDialog')), findsOneWidget);
      expect(find.text('IMP-2026-0007'), findsWidgets);
      expect(find.text('350.00 USD'), findsOneWidget);
      expect(find.text('120.00 USD'), findsOneWidget);
      expect(find.text('2400.00 EGP'), findsOneWidget);
      expect(find.text('50.0000'), findsOneWidget);
      expect(find.text('25900.00 EGP'), findsOneWidget);

      // Cancel button pops with false/null
      await tester.tap(find.byKey(const Key('pushToSettlementCancelBtn')));
      await tester.pumpAndSettle();
      expect(result, isNull);

      // Open dialog again and confirm
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pushToSettlementConfirmBtn')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('FE05-T01: DemurrageDetentionScreen full push flow', () {
    testWidgets('linked tracking confirms before API call', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adapter = _RecordingAdapter();
      adapter.trackings = [
        _makeTrackingJson(trackingId: 77, importFileId: 7, importFileCode: 'IMP-007'),
      ];

      final dio = Dio()..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrapWidget(
          const DemurrageDetentionScreen(),
          container: container,
        ),
      );
      // Pump initial frames for postFrameCallback to fetch trackings
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap push button on tracking 77
      final pushBtn = find.byKey(const Key('pushToSettlementBtn_77'));
      expect(pushBtn, findsOneWidget);
      await tester.tap(pushBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Confirm dialog appears
      expect(find.byKey(const Key('pushToSettlementConfirmDialog')), findsOneWidget);
      expect(adapter.requests.where((r) => r.path.contains('push-to-settlement')), isEmpty);

      // Confirm push
      await tester.tap(find.byKey(const Key('pushToSettlementConfirmBtn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify API was called with import_file_id == 7
      final pushRequests = adapter.requests.where((r) => r.path.contains('push-to-settlement')).toList();
      expect(pushRequests.length, 1);
      final reqData = pushRequests.first.data as Map;
      expect(reqData['tracking_id'], 77);
      expect(reqData['import_file_id'], 7);
    });
  });

  group('FE05-T01: Source code scan for default import_file_id', () {
    test('never defaults importFileId to 1 in demurrage_detention', () {
      final dir = Directory('lib/features/demurrage_detention');
      final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final content = file.readAsStringSync();
        expect(
          content.contains('importFileId ?? 1'),
          isFalse,
          reason: '${file.path} contains "importFileId ?? 1"',
        );
        expect(
          content.contains('import_file_id: 1') || content.contains("'import_file_id': 1"),
          isFalse,
          reason: '${file.path} contains hardcoded import_file_id: 1',
        );
      }
    });
  });
}
