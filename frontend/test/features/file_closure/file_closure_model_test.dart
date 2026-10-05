import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/file_closure/models/file_closure_model.dart';
import 'package:frontend/features/file_closure/providers/file_closure_provider.dart';
import 'package:frontend/features/file_closure/widgets/official_file_closure_dialog.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, ResponseBody Function(RequestOptions)> routes = {};

  static ResponseBody json(Object body, [int status = 200]) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  _Adapter on(String key, ResponseBody Function(RequestOptions) f) {
    routes[key] = f;
    return this;
  }

  int count(String method, String part) =>
      requests.where((r) => r.method == method && r.uri.path.contains(part)).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    for (final e in routes.entries) {
      final sp = e.key.indexOf(' ');
      if (options.method == e.key.substring(0, sp) && options.uri.path.contains(e.key.substring(sp + 1))) {
        return e.value(options);
      }
    }
    return json(<dynamic>[]);
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(_Adapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s >= 200 && s < 300))..httpClientAdapter = adapter;
  final c = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    uploadDioProvider.overrideWithValue(dio),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 150));

Map<String, dynamic> _certJson() => {
      'success': true,
      'closure_id': 1,
      'closure_code': 'CLR-2026-0001',
      'import_file_id': 5,
      'import_file_code': 'IMP-2026-005',
      'status': 'Closed',
    };

void main() {
  group('ClosureChecklistModel (FE-07)', () {
    test('a key the server did not send is NOT passed', () {
      final c = ClosureChecklistModel.fromJson(const {});
      expect(c.docsVerified, isFalse);
      expect(c.customsCleared, isFalse);
      expect(c.warehouseReceived, isFalse);
      expect(c.landedCostSettled, isFalse);
      expect(c.tasksClosed, isFalse);
      expect(c.isAllCompleted, isFalse);
    });

    test('the default constructor is all false', () {
      final c = ClosureChecklistModel();
      expect(c.docsVerified || c.customsCleared || c.warehouseReceived || c.landedCostSettled || c.tasksClosed, isFalse);
    });

    test('only an explicit true passes (a null or string does not)', () {
      final c = ClosureChecklistModel.fromJson({'docs_verified': true, 'customs_cleared': null, 'tasks_closed': 'true'});
      expect(c.docsVerified, isTrue);
      expect(c.customsCleared, isFalse);
      expect(c.tasksClosed, isFalse);
    });

    test('eir_returned is read as empty_containers_returned (old closure_readiness key)', () {
      expect(ClosureChecklistModel.fromJson({'eir_returned': true}).emptyContainersReturned, isTrue);
      expect(
        ClosureChecklistModel.fromJson({'eir_returned': false, 'empty_containers_returned': true}).emptyContainersReturned,
        isTrue,
      );
    });

    test('fromStatusMap treats missing keys as not passed', () {
      final c = ClosureChecklistModel.fromStatusMap({'docs_verified': true, 'customs_cleared': true});
      expect(c.docsVerified, isTrue);
      expect(c.warehouseReceived, isFalse);
      expect(c.isAllCompleted, isFalse);
    });

    test('a closure row without auditor / vault shows empty text, not an invented one', () {
      final r = ImportFileClosureModel.fromJson({
        'closure_id': 1,
        'import_file_id': 5,
        'closure_checklist': <String, dynamic>{},
      });
      expect(r.auditorName, '');
      expect(r.archiveLocation, '');
    });
  });

  group('ClosurePillars', () {
    test('an empty server status shows every pillar as failed', () {
      final p = ClosurePillars.fromStatus(const {});
      expect([p.customs, p.warehouse, p.landedCost, p.dossier, p.emptyContainers, p.tasks], everyElement(isFalse));
    });

    test('reads the six server keys', () {
      final p = ClosurePillars.fromStatus({
        'customs_cleared': true,
        'warehouse_received': true,
        'landed_cost_settled': false,
        'dossier_exported': true,
        'empty_containers_returned': false,
        'tasks_closed': true,
      });
      expect(p.customs, isTrue);
      expect(p.landedCost, isFalse);
      expect(p.dossier, isTrue);
      expect(p.emptyContainers, isFalse);
    });
  });

  group('precheck messages (additive contract)', () {
    test('without coded messages the legacy text lists are shown', () {
      final pre = ClosurePrecheckResponseModel.fromJson({
        'can_close': false,
        'blocking_reasons': ['legacy block'],
        'warnings': ['legacy warn'],
      });
      const l10n = AppLocalizationsEn();
      expect(pre.blockingTexts(l10n), ['legacy block']);
      expect(pre.warningTexts(l10n), ['legacy warn']);
    });

    test('an unknown code falls back to the server text', () {
      final pre = ClosurePrecheckResponseModel.fromJson({
        'can_close': false,
        'blocking_reasons': ['legacy block'],
        'blocking_messages': [
          {'msg_code': 'NOT_A_REAL_CODE_X', 'text': 'server text'},
        ],
      });
      expect(pre.blockingTexts(const AppLocalizationsEn()), ['server text']);
    });
  });

  group('FileClosureNotifier', () {
    test('official close invalidates the import files list and surfaces the certificate', () async {
      final a = _Adapter()..on('POST /official-close', (_) => _Adapter.json(_certJson()));
      final c = _container(a);
      c.listen(importFilesProvider, (_, __) {});
      final notifier = c.read(fileClosureProvider.notifier);
      await _settle();
      final filesBefore = a.count('GET', 'import-files');

      final cert = await notifier.officialCloseImportFile({'import_file_id': 5});
      await _settle();

      expect(cert.closureCode, 'CLR-2026-0001');
      expect(a.count('GET', 'import-files'), greaterThan(filesBefore));
    });

    test('a 409 from the server is rethrown, not swallowed', () async {
      final a = _Adapter()
        ..on('POST /official-close', (_) => _Adapter.json({
              'detail': {'code': 'FC_ALREADY_CLOSED', 'message': 'File already closed'}
            }, 409));
      final c = _container(a);
      final notifier = c.read(fileClosureProvider.notifier);
      await _settle();

      await expectLater(notifier.officialCloseImportFile({'import_file_id': 5}), throwsA(isA<DioException>()));
    });

    test('delete invalidates the import files list', () async {
      final a = _Adapter()..on('DELETE /file-closure/9', (_) => _Adapter.json({'ok': true}));
      final c = _container(a);
      c.listen(importFilesProvider, (_, __) {});
      final notifier = c.read(fileClosureProvider.notifier);
      await _settle();
      final before = a.count('GET', 'import-files');

      await notifier.softDeleteClosure(9);
      await _settle();

      expect(a.count('GET', 'import-files'), greaterThan(before));
    });
  });
}
