import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/demurrage_detention/services/customs_abandonment_service.dart';

/// Records every request and answers with an empty-but-valid payload for its endpoint.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    final String body;
    if (options.path.endsWith('/radars')) {
      body = '[]';
    } else if (options.path.endsWith('/radars/summary')) {
      body = '{"total_radars": 0}';
    } else if (options.path.endsWith('/extension-letter-draft')) {
      body = '{}';
    } else {
      body = '{"radar_id": 7}';
    }
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('customs abandonment service calls the backend /radars routes', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080'))..httpClientAdapter = adapter;
    final service = CustomsAbandonmentService(dio);

    await service.listRadars();
    await service.getSummary();
    await service.requestExtension(7, reason: 'Pending GOEIC test');
    await service.grantExtension(7, extensionGrantedUntil: '2026-12-31');
    try {
      await service.getLetterDraft(7);
    } catch (_) {
      // Only the request path is under test here, not the letter model parsing.
    }

    expect(adapter.requests, [
      'GET /api/v1/customs-abandonment/radars',
      'GET /api/v1/customs-abandonment/radars/summary',
      'POST /api/v1/customs-abandonment/radars/7/request-extension',
      'POST /api/v1/customs-abandonment/radars/7/grant-extension',
      'GET /api/v1/customs-abandonment/radars/7/extension-letter-draft',
    ]);
  });
}
