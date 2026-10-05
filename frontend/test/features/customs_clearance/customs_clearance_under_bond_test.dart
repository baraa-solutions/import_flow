import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/customs_clearance/widgets/under_bond_release_dialog.dart';

/// Records every request and answers with a minimal clearance record (POST) or an empty list (GET).
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int? failPostWith;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (options.method == 'POST' && failPostWith != null) {
      return ResponseBody.fromString(
        jsonEncode({
          'detail': {'code': 'X', 'message': 'backend says no'}
        }),
        failPostWith!,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    final body = options.method == 'GET'
        ? jsonEncode([])
        : jsonEncode({
            'customs_clearance_id': 7,
            'clearance_code': 'CLR-2026-0007',
            'import_file_id': 3,
            'is_under_bond_release': true,
            'bond_guarantee_ref': 'BOND-1',
            'quarantine_lock': true,
            'lab_test_result': 'CONFORMING',
          });
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(_RecordingAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
}

void main() {
  group('under-bond / lab payload builders (FE-01)', () {
    test('under-bond payload carries the required temporary_release_date and the warehouse field', () {
      final p = buildUnderBondPayload(
        bondRef: '  BOND-9 ',
        releaseDate: DateTime(2026, 10, 5),
        warehouseLocation: ' Factory ',
      );
      expect(p['bond_guarantee_ref'], 'BOND-9');
      expect(p['temporary_release_date'], DateTime(2026, 10, 5).toIso8601String());
      expect(p['customs_warehouse_location'], 'Factory');
      expect(p.containsKey('quarantine_location'), isFalse);
    });

    test('lab payload uses lab_test_result code + test_completion_date, not is_lab_passed', () {
      final p = buildLabResultPayload(
        verdict: kLabNonConforming,
        certificateNumber: ' LAB-1 ',
        completionDate: DateTime(2026, 10, 6),
        remarks: '   ',
      );
      expect(p['lab_test_result'], 'NON_CONFORMING');
      expect(p['lab_certificate_number'], 'LAB-1');
      expect(p['test_completion_date'], DateTime(2026, 10, 6).toIso8601String());
      expect(p['lift_quarantine_lock'], true);
      expect(p['remarks'], isNull);
      expect(p.containsKey('is_lab_passed'), isFalse);
    });
  });

  group('CustomsClearanceNotifier under-bond endpoints', () {
    test('releaseUnderBond posts to /under-bond-release and refreshes the list', () async {
      final adapter = _RecordingAdapter();
      final c = _container(adapter);
      addTearDown(c.dispose);
      c.read(customsClearanceProvider);
      await Future<void>.delayed(Duration.zero);
      adapter.requests.clear();

      final updated = await c
          .read(customsClearanceProvider.notifier)
          .releaseUnderBond(7, buildUnderBondPayload(bondRef: 'BOND-1', releaseDate: DateTime(2026, 10, 5), warehouseLocation: 'W'));

      expect(updated?.isUnderBondRelease, isTrue);
      final postIdx = adapter.requests.indexWhere((r) => r.method == 'POST');
      expect(postIdx, isNonNegative);
      expect(adapter.requests[postIdx].path, endsWith('/customs-clearance/7/under-bond-release'));
      expect(adapter.requests.skip(postIdx + 1).any((r) => r.method == 'GET' && r.path.endsWith('/customs-clearance')), isTrue);
    });

    test('recordLabTestResult posts to /lab-test-result (not /lab-inspection-result)', () async {
      final adapter = _RecordingAdapter();
      final c = _container(adapter);
      addTearDown(c.dispose);
      await c.read(customsClearanceProvider.notifier).recordLabTestResult(
            7,
            buildLabResultPayload(verdict: kLabConforming, certificateNumber: 'LAB-1', completionDate: DateTime(2026, 10, 6)),
          );
      final post = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(post.path, endsWith('/customs-clearance/7/lab-test-result'));
      expect((post.data as Map)['lab_test_result'], 'CONFORMING');
    });

    test('refresh keeps the filters of the last fetch (FE-10)', () async {
      final adapter = _RecordingAdapter();
      final c = _container(adapter);
      addTearDown(c.dispose);
      final n = c.read(customsClearanceProvider.notifier);
      await n.fetchRecords(importFileId: 3, status: 'Duty Paid', search: 'DEC');
      adapter.requests.clear();
      await n.recordLabTestResult(7, {'lab_test_result': kLabConforming});
      final get = adapter.requests.lastWhere((r) => r.method == 'GET');
      expect(get.queryParameters['import_file_id'], 3);
      expect(get.queryParameters['status'], 'Duty Paid');
      expect(get.queryParameters['search'], 'DEC');
    });
  });

  group('UnderBondReleaseDialog (widget)', () {
    Future<void> pump(WidgetTester tester, ProviderContainer c, {required bool lab}) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: AppLocalizationsProvider(
            locale: const Locale('en'),
            child: MaterialApp(
              locale: const Locale('en'),
              home: Scaffold(
                body: UnderBondReleaseDialog(clearanceId: 7, declarationNo: 'DEC-1', isAlreadyUnderBond: lab),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('under-bond submit sends the corrected payload', (tester) async {
      final adapter = _RecordingAdapter();
      final c = _container(adapter);
      addTearDown(c.dispose);
      await pump(tester, c, lab: false);
      adapter.requests.clear();

      await tester.tap(find.byKey(const Key('underBondConfirmBtn')));
      await tester.pumpAndSettle();

      final post = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(post.path, endsWith('/customs-clearance/7/under-bond-release'));
      final data = post.data as Map;
      expect(data['temporary_release_date'], isNotNull);
      expect(data['bond_guarantee_ref'], isNotEmpty);
      expect(data.containsKey('quarantine_location'), isFalse);
    });

    testWidgets('lab submit sends lab_test_result and shows the backend message on failure', (tester) async {
      final adapter = _RecordingAdapter()..failPostWith = 409;
      final c = _container(adapter);
      addTearDown(c.dispose);
      await pump(tester, c, lab: true);

      await tester.tap(find.byKey(const Key('underBondLabSubmitBtn')));
      await tester.pumpAndSettle();

      final post = adapter.requests.firstWhere((r) => r.method == 'POST');
      expect(post.path, endsWith('/customs-clearance/7/lab-test-result'));
      expect((post.data as Map)['lab_test_result'], 'CONFORMING');
      expect(find.textContaining('backend says no'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });
  });

  group('CustomsClearanceModel under-bond fields (FE-03)', () {
    test('parses the under-bond / quarantine state', () {
      final m = CustomsClearanceModel.fromJson({
        'customs_clearance_id': 1,
        'clearance_code': 'CLR-1',
        'import_file_id': 2,
        'is_under_bond_release': true,
        'bond_guarantee_ref': 'BOND-77',
        'quarantine_lock': true,
        'lab_test_result': 'NON_CONFORMING',
        'lab_certificate_number': 'LAB-5',
        'quarantine_lifted_date': '2026-10-05T10:00:00',
        'quarantine_lifted_by': 'kamal',
        'status': 'Final Release Granted',
      });
      expect(m.isUnderBondRelease, isTrue);
      expect(m.bondGuaranteeRef, 'BOND-77');
      expect(m.quarantineLock, isTrue);
      expect(m.labTestResult, 'NON_CONFORMING');
      expect(m.labCertificateNumber, 'LAB-5');
      expect(m.quarantineLiftedBy, 'kamal');
      expect(m.toJson()['is_under_bond_release'], true);
    });

    test('tolerates missing fields and does not infer bond state from the status text', () {
      final m = CustomsClearanceModel.fromJson({
        'customs_clearance_id': 1,
        'clearance_code': 'CLR-1',
        'import_file_id': 2,
        'status': 'Released Under Bond',
      });
      expect(m.isUnderBondRelease, isFalse);
      expect(m.quarantineLock, isFalse);
      expect(m.labTestResult, 'NONE');
      expect(m.bondGuaranteeRef, isNull);
    });
  });
}
