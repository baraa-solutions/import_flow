import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';

/// Short-lived JWT renewal in the shared HTTP clients (Trello UOroUoqq):
/// proactive refresh before a request, refresh-not-logout on an upload 401,
/// single-flight refresh, and no refresh cascade / infinite retry.

const _user = {
  'user_id': 1,
  'username': 'admin',
  'email': 'admin@importflow.com',
  'full_name': 'System Admin',
  'role': 'ADMIN',
  'is_active': true,
};

int _seq = 0;

String _jwt({required int expInSeconds}) {
  String enc(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expInSeconds;
  _seq++;
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': '1', 'exp': exp, 'jti': 'j$_seq'})}.sig';
}

typedef _Handler = ({int status, Object body}) Function(RequestOptions options);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final _Handler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    requests.add(options);
    // Yield so concurrent callers really overlap.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final result = handler(options);
    return ResponseBody.fromString(
      jsonEncode(result.body),
      result.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Harness {
  _Harness._(this.container, this.authBackend, this.apiBackend);

  final ProviderContainer container;
  final _FakeAdapter authBackend;
  final _FakeAdapter apiBackend;

  int get refreshCalls => authBackend.requests.where((r) => r.path.endsWith('/auth/refresh')).length;
  AuthState get auth => container.read(authProvider);

  static Future<_Harness> create({
    required String token,
    bool refreshSucceeds = true,
    required _Handler api,
    bool upload = false,
  }) async {
    FlutterSecureStorage.setMockInitialValues({
      'importflow_jwt_token': token,
      'importflow_user_profile': jsonEncode(_user),
    });
    final authBackend = _FakeAdapter((options) {
      if (options.path.endsWith('/auth/refresh')) {
        if (!refreshSucceeds) return (status: 401, body: {'detail': 'Invalid or revoked token.'});
        return (status: 200, body: {'access_token': _jwt(expInSeconds: 3600), 'user': _user});
      }
      if (options.path.endsWith('/auth/me')) return (status: 200, body: _user);
      return (status: 404, body: {'detail': 'not found'});
    });
    final authDio = Dio()..httpClientAdapter = authBackend;
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith((ref) => AuthNotifier(authDio, const FlutterSecureStorage())),
    ]);
    container.read(authProvider);
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final apiBackend = _FakeAdapter(api);
    final dio = container.read(upload ? uploadDioProvider : dioProvider);
    dio.httpClientAdapter = apiBackend;
    return _Harness._(container, authBackend, apiBackend);
  }

  Dio get dio => container.read(dioProvider);
  Dio get uploadDio => container.read(uploadDioProvider);
}

String? _bearer(RequestOptions o) => o.headers['Authorization']?.toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tokenExpiresWithin honours the window', () {
    expect(AuthNotifier.tokenExpiresWithin(_jwt(expInSeconds: 60), const Duration(minutes: 2)), isTrue);
    expect(AuthNotifier.tokenExpiresWithin(_jwt(expInSeconds: 3600), const Duration(minutes: 2)), isFalse);
    expect(AuthNotifier.tokenExpiresWithin('garbage', const Duration(minutes: 2)), isTrue);
  });

  test('a token about to expire is refreshed BEFORE the request is sent', () async {
    final oldToken = _jwt(expInSeconds: 60);
    final h = await _Harness.create(token: oldToken, api: (_) => (status: 200, body: {'ok': true}));
    addTearDown(h.container.dispose);

    final response = await h.dio.get('/import-files');

    expect(response.statusCode, 200);
    expect(h.refreshCalls, 1);
    expect(_bearer(h.apiBackend.requests.single), isNot('Bearer $oldToken'));
    expect(_bearer(h.apiBackend.requests.single), 'Bearer ${h.auth.token}');
  });

  test('a fresh token is not refreshed', () async {
    final h = await _Harness.create(token: _jwt(expInSeconds: 3600), api: (_) => (status: 200, body: {'ok': true}));
    addTearDown(h.container.dispose);
    await h.dio.get('/import-files');
    expect(h.refreshCalls, 0);
  });

  test('concurrent requests share ONE refresh (single-flight)', () async {
    final h = await _Harness.create(token: _jwt(expInSeconds: 60), api: (_) => (status: 200, body: {'ok': true}));
    addTearDown(h.container.dispose);

    await Future.wait([h.dio.get('/a'), h.dio.get('/b'), h.dio.get('/c')]);

    expect(h.refreshCalls, 1);
    final sent = h.apiBackend.requests.map(_bearer).toSet();
    expect(sent, {'Bearer ${h.auth.token}'});
  });

  test('upload 401 refreshes the token and keeps the session (asks to retry)', () async {
    final h = await _Harness.create(
      token: _jwt(expInSeconds: 3600),
      upload: true,
      api: (_) => (status: 401, body: {'detail': 'Invalid or expired access token.'}),
    );
    addTearDown(h.container.dispose);
    final before = h.auth.token;

    final error = await h.uploadDio
        .post('/smart-upload/upload', data: FormData.fromMap({'raw_text': 'x'}))
        .then<DioException?>((_) => null, onError: (Object e) => e as DioException);

    expect(error, isNotNull);
    expect(error!.message, kSessionRenewedRetryMessage);
    expect(h.refreshCalls, 1);
    expect(h.auth.isAuthenticated, isTrue);
    expect(h.auth.token, isNot(before));
    // The multipart body was not replayed.
    expect(h.apiBackend.requests.length, 1);
  });

  test('upload 401 with a failing refresh ends the session', () async {
    final h = await _Harness.create(
      token: _jwt(expInSeconds: 3600),
      upload: true,
      refreshSucceeds: false,
      api: (_) => (status: 401, body: {'detail': 'Invalid or expired access token.'}),
    );
    addTearDown(h.container.dispose);

    await expectLater(
      h.uploadDio.post('/smart-upload/upload', data: FormData.fromMap({'raw_text': 'x'})),
      throwsA(isA<DioException>()),
    );
    expect(h.refreshCalls, 1);
    expect(h.auth.isAuthenticated, isFalse);
  });

  test('JSON 401 is retried once with the renewed token', () async {
    var calls = 0;
    final h = await _Harness.create(
      token: _jwt(expInSeconds: 3600),
      api: (_) => ++calls == 1 ? (status: 401, body: {'detail': 'expired'}) : (status: 200, body: {'ok': true}),
    );
    addTearDown(h.container.dispose);

    final response = await h.dio.get('/import-files');

    expect(response.statusCode, 200);
    expect(h.refreshCalls, 1);
    expect(h.apiBackend.requests.length, 2);
    expect(_bearer(h.apiBackend.requests.last), 'Bearer ${h.auth.token}');
    expect(h.auth.isAuthenticated, isTrue);
  });

  test('a request still refused after the retry ends the session without looping', () async {
    final h = await _Harness.create(
      token: _jwt(expInSeconds: 3600),
      api: (_) => (status: 401, body: {'detail': 'revoked'}),
    );
    addTearDown(h.container.dispose);

    await expectLater(h.dio.get('/import-files'), throwsA(isA<DioException>()));

    expect(h.refreshCalls, 1);
    expect(h.apiBackend.requests.length, 2);
    expect(h.auth.isAuthenticated, isFalse);
  });

  test('a 401 for an already-replaced token retries with the current token, no extra refresh', () async {
    final staleToken = _jwt(expInSeconds: 3600);
    late _Harness h;
    var calls = 0;
    h = await _Harness.create(
      token: staleToken,
      api: (options) {
        calls++;
        return _bearer(options) == 'Bearer $staleToken'
            ? (status: 401, body: {'detail': 'revoked'})
            : (status: 200, body: {'ok': true});
      },
    );
    addTearDown(h.container.dispose);

    // Another call renews the token while this request is in flight with the stale one.
    final pending = h.dio.get('/import-files');
    await h.container.read(authProvider.notifier).refreshToken();
    final response = await pending;

    expect(response.statusCode, 200);
    expect(h.refreshCalls, 1);
    expect(calls, 2);
  });
}
