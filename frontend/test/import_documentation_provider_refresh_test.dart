import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/import_documentation/models/import_documentation_model.dart';
import 'package:frontend/features/import_documentation/models/original_documents_collection_model.dart';
import 'package:frontend/features/import_documentation/providers/import_documentation_provider.dart';
import 'package:frontend/features/import_documentation/providers/original_documents_collection_provider.dart';
import 'package:frontend/features/import_documentation/widgets/idoc_feedback.dart';

class _Recorded {
  final String method;
  final String path;
  final Map<String, dynamic> query;
  _Recorded(this.method, this.path, this.query);
}

/// Fake Dio adapter: records requests and answers from a handler.
class _FakeAdapter implements HttpClientAdapter {
  final List<_Recorded> calls = [];
  final ResponseBody Function(RequestOptions) handler;
  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? body, Future<void>? cancel) async {
    calls.add(_Recorded(o.method, o.path, Map<String, dynamic>.from(o.queryParameters)));
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, [int status = 200]) =>
    ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

Dio _dio(_FakeAdapter a) {
  final d = Dio(BaseOptions(baseUrl: 'http://test'));
  d.httpClientAdapter = a;
  return d;
}

void main() {
  test('FED-13: a mutation re-fetches with the last import_file_id', () async {
    final adapter = _FakeAdapter((o) {
      if (o.method == 'GET') return _json('[]');
      return _json('{"status":"ok"}');
    });
    final notifier = DraftBLNotifier(_dio(adapter));
    await Future<void>.delayed(Duration.zero);
    await notifier.fetchReviews(importFileId: 42);
    adapter.calls.clear();

    await notifier.deleteDraftBLReview(9);

    final gets = adapter.calls.where((c) => c.method == 'GET').toList();
    expect(gets, hasLength(1));
    expect(gets.single.query['import_file_id'], 42);
    notifier.dispose();
  });

  test('FED-09: fetchSessionByFile returns null on 404 and throws on 500', () async {
    var status = 404;
    final adapter = _FakeAdapter((o) => _json('{"detail":"x"}', status));
    final dio = _dio(adapter);
    dio.options.validateStatus = (s) => s != null && s >= 200 && s < 300;
    final notifier = OriginalDocumentsCollectionNotifier(dio);
    await Future<void>.delayed(Duration.zero);

    expect(await notifier.fetchSessionByFile(5), isNull);

    status = 500;
    await expectLater(notifier.fetchSessionByFile(5), throwsA(isA<DioException>()));
    notifier.dispose();
  });

  test('FED-05/06: updateDraftBLChecklist sends the given reviewer name', () async {
    final adapter = _FakeAdapter((o) => _json('{}'));
    final notifier = DraftBLNotifier(_dio(adapter));
    await Future<void>.delayed(Duration.zero);
    adapter.calls.clear();
    try {
      await notifier.updateDraftBLChecklist(3, <DraftBLChecklistItemModel>[], reviewerName: 'Sara Ali');
    } catch (_) {
      // The empty fake body cannot be parsed into a review; only the request matters.
    }
    final put = adapter.calls.firstWhere((c) => c.method == 'PUT');
    expect(put.query['reviewer_name'], 'Sara Ali');
    expect(put.path, contains('/draft-bl/3/checklist'));
    notifier.dispose();
  });

  test('isIdocVersionConflict only matches the concurrency 409', () {
    DioException err(int code, Object data) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: code, data: data),
        );
    expect(isIdocVersionConflict(err(409, {'detail': {'current_version': 3}})), isTrue);
    expect(isIdocVersionConflict(err(409, {'detail': {'code': 'DCA_SESSION_FINAL_LOCKED', 'message': 'm'}})), isFalse);
    expect(isIdocVersionConflict(err(400, {'detail': 'bad'})), isFalse);
  });

  test('original docs model: missing audit identity is empty, not ADMIN (FED-23)', () {
    final m = OriginalDocumentsCollectionSessionModel.fromJson({
      'collection_id': 1,
      'import_file_id': 2,
    });
    expect(m.createdBy, '');
    expect(m.updatedBy, '');
  });
}
