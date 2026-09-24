import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_error.dart';

DioException _err(int status, dynamic data) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: data),
    type: DioExceptionType.badResponse,
    message: 'bad response',
  );
}

void main() {
  group('ApiError', () {
    test('detects 403 and extracts backend detail', () {
      final e = _err(403, {'detail': 'Admin role required'});
      expect(ApiError.isForbidden(e), isTrue);
      expect(ApiError.message(e), 'Admin role required');
    });

    test('non-403 and validation-list detail', () {
      final e = _err(422, {'detail': [{'msg': 'field required'}]});
      expect(ApiError.isForbidden(e), isFalse);
      expect(ApiError.message(e), 'field required');
    });

    test('falls back to Dio message then toString', () {
      expect(ApiError.message(_err(500, 'oops')), 'bad response');
      expect(ApiError.message(Exception('boom')), contains('boom'));
      expect(ApiError.isForbidden(Exception('x')), isFalse);
    });
  });
}
