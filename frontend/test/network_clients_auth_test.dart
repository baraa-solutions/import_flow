import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart' as central;
import 'package:frontend/core/network/dio_client.dart' as legacy;
import 'package:frontend/features/auth/providers/auth_provider.dart';

String _validJwt() {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${enc({'sub': '1', 'username': 'admin', 'role': 'ADMIN', 'exp': exp})}.sig';
}

/// Captures the outgoing request headers and short-circuits the call so no
/// network traffic happens.
void _captureHeaders(Dio dio, List<RequestOptions> sink) {
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    sink.add(options);
    handler.resolve(Response(requestOptions: options, statusCode: 200, data: const {}));
  }));
}

Future<ProviderContainer> _containerWithToken(String? token) async {
  FlutterSecureStorage.setMockInitialValues({
    if (token != null) 'importflow_jwt_token': token,
    if (token != null)
      'importflow_user_profile': jsonEncode({
        'user_id': 1,
        'username': 'admin',
        'email': 'admin@importflow.com',
        'full_name': 'System Admin',
        'role': 'ADMIN',
        'is_active': true,
      }),
  });
  final container = ProviderContainer();
  container.read(authProvider);
  // Let _initFromStorage finish.
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Network clients authentication', () {
    test('dio_client.uploadDioProvider resolves to the authenticated central client', () async {
      final container = await _containerWithToken(null);
      addTearDown(container.dispose);

      expect(
        identical(container.read(legacy.uploadDioProvider), container.read(central.uploadDioProvider)),
        isTrue,
      );
      expect(
        identical(container.read(legacy.dioProvider), container.read(central.dioProvider)),
        isTrue,
      );
    });

    test('dioProvider injects Authorization: Bearer when a token is present', () async {
      final token = _validJwt();
      final container = await _containerWithToken(token);
      addTearDown(container.dispose);
      expect(container.read(authProvider).token, token);

      final captured = <RequestOptions>[];
      final dio = container.read(central.dioProvider);
      _captureHeaders(dio, captured);
      await dio.get('/import-files');

      expect(captured.single.headers['Authorization'], 'Bearer $token');
      // Relative paths resolve under /api/v1 exactly once.
      expect(captured.single.uri.path, '/api/v1/import-files');
    });

    test('uploadDioProvider (via dio_client) injects Authorization: Bearer', () async {
      final token = _validJwt();
      final container = await _containerWithToken(token);
      addTearDown(container.dispose);

      final captured = <RequestOptions>[];
      final dio = container.read(legacy.uploadDioProvider);
      _captureHeaders(dio, captured);
      await dio.post('/smart-upload/upload', data: FormData.fromMap({'raw_text': 'x'}));

      expect(captured.single.headers['Authorization'], 'Bearer $token');
    });

    test('no Authorization header is sent when there is no token', () async {
      final container = await _containerWithToken(null);
      addTearDown(container.dispose);

      final captured = <RequestOptions>[];
      final dio = container.read(central.dioProvider);
      _captureHeaders(dio, captured);
      await dio.get('/import-files');

      expect(captured.single.headers.containsKey('Authorization'), isFalse);
    });
  });
}
