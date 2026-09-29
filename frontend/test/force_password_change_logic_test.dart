import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_error.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/providers/auth_route_guard.dart';
import 'package:frontend/features/auth/providers/password_change_provider.dart';

Map<String, dynamic> _userJson({bool? mustChange}) => {
      'user_id': 1,
      'username': 'admin',
      'email': 'admin@importflow.com',
      'full_name': 'System Admin',
      'role': 'ADMIN',
      'is_active': true,
      if (mustChange != null) 'must_change_password': mustChange,
    };

String _validJwt() {
  String enc(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': '1', 'exp': exp})}.sig';
}

/// Answers every request from [handler] without touching the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final (int, Object?) Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = handler(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _drain() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

DioException _dioError(int status, Object? body) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: body),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserModel.mustChangePassword', () {
    test('parses the flag when present', () {
      expect(UserModel.fromJson(_userJson(mustChange: true)).mustChangePassword, isTrue);
      expect(UserModel.fromJson(_userJson(mustChange: false)).mustChangePassword, isFalse);
    });

    test('treats a missing or null flag as false (older backends)', () {
      expect(UserModel.fromJson(_userJson()).mustChangePassword, isFalse);
      expect(UserModel.fromJson({..._userJson(), 'must_change_password': null}).mustChangePassword, isFalse);
    });

    test('toJson round-trips the flag and copyWith flips only the flag', () {
      final user = UserModel.fromJson(_userJson(mustChange: true));
      expect(UserModel.fromJson(user.toJson()).mustChangePassword, isTrue);
      final cleared = user.copyWith(mustChangePassword: false);
      expect(cleared.mustChangePassword, isFalse);
      expect(cleared.username, 'admin');
      expect(cleared.role, 'ADMIN');
    });
  });

  group('resolveAuthDestination (route guard)', () {
    test('unauthenticated -> login', () {
      expect(resolveAuthDestination(const AuthState()), AuthDestination.login);
    });

    test('flag true -> force password change', () {
      final state = AuthState(isAuthenticated: true, user: UserModel.fromJson(_userJson(mustChange: true)));
      expect(resolveAuthDestination(state), AuthDestination.forcePasswordChange);
      expect(requiresPasswordChange(state), isTrue);
    });

    test('flag false or missing -> home', () {
      for (final flag in [false, null]) {
        final state = AuthState(isAuthenticated: true, user: UserModel.fromJson(_userJson(mustChange: flag)));
        expect(resolveAuthDestination(state), AuthDestination.home);
        expect(requiresPasswordChange(state), isFalse);
      }
    });
  });

  group('ApiError password-change helpers', () {
    test('detects the structured 403 PASSWORD_CHANGE_REQUIRED', () {
      final err = _dioError(403, {
        'detail': {'code': 'PASSWORD_CHANGE_REQUIRED', 'message': 'غيّر كلمة المرور أولاً'},
      });
      expect(ApiError.isPasswordChangeRequired(err), isTrue);
      expect(ApiError.message(err), 'غيّر كلمة المرور أولاً');
    });

    test('ignores plain 403s and other statuses', () {
      expect(ApiError.isPasswordChangeRequired(_dioError(403, {'detail': 'Admins only'})), isFalse);
      expect(
        ApiError.isPasswordChangeRequired(_dioError(400, {
          'detail': {'code': 'PASSWORD_CHANGE_REQUIRED'},
        })),
        isFalse,
      );
      expect(ApiError.isPasswordChangeRequired(Exception('x')), isFalse);
    });
  });

  group('PasswordChangeValidator', () {
    test('current password is required', () {
      expect(PasswordChangeValidator.current(''), PasswordFieldError.required);
      expect(PasswordChangeValidator.current('Admin@123'), isNull);
    });

    test('new password: required, min length, differs from current', () {
      expect(PasswordChangeValidator.newPassword('', 'Admin@123'), PasswordFieldError.required);
      expect(PasswordChangeValidator.newPassword('short', 'Admin@123'), PasswordFieldError.tooShort);
      expect(PasswordChangeValidator.newPassword('Admin@123', 'Admin@123'), PasswordFieldError.sameAsCurrent);
      expect(PasswordChangeValidator.newPassword('N3w-Secure!', 'Admin@123'), isNull);
      expect(kMinNewPasswordLength, 8);
    });

    test('confirmation must match', () {
      expect(PasswordChangeValidator.confirm('', 'N3w-Secure!'), PasswordFieldError.required);
      expect(PasswordChangeValidator.confirm('other', 'N3w-Secure!'), PasswordFieldError.mismatch);
      expect(PasswordChangeValidator.confirm('N3w-Secure!', 'N3w-Secure!'), isNull);
    });
  });

  group('PasswordChangeRepository', () {
    test('posts current/new password and returns the updated user', () async {
      final adapter = _FakeAdapter((_) => (200, _userJson(mustChange: false)));
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter;

      final result = await PasswordChangeRepository(dio)
          .changePassword(currentPassword: 'Admin@123', newPassword: 'N3w-Secure!');

      expect(result.user.mustChangePassword, isFalse);
      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.uri.path, endsWith('/auth/me/change-password'));
      expect(req.data, {'current_password': 'Admin@123', 'new_password': 'N3w-Secure!'});
    });

    test('400 surfaces the backend detail message', () async {
      final adapter = _FakeAdapter((_) => (400, {'detail': 'كلمة المرور الحالية غير صحيحة'}));
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter;

      expect(
        () => PasswordChangeRepository(dio).changePassword(currentPassword: 'x', newPassword: 'N3w-Secure!'),
        throwsA(isA<PasswordChangeException>()
            .having((e) => e.message, 'message', 'كلمة المرور الحالية غير صحيحة')
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('errors without a detail leave the message to the UI fallback', () async {
      final adapter = _FakeAdapter((_) => (500, {'error': 'boom'}));
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter;

      expect(
        () => PasswordChangeRepository(dio).changePassword(currentPassword: 'x', newPassword: 'N3w-Secure!'),
        throwsA(isA<PasswordChangeException>().having((e) => e.message, 'message', isNull)),
      );
    });
  });

  group('AuthNotifier password-change state', () {
    Future<AuthNotifier> signedIn(_FakeAdapter adapter, {bool? storedFlag}) async {
      FlutterSecureStorage.setMockInitialValues({
        'importflow_jwt_token': _validJwt(),
        'importflow_user_profile': jsonEncode(_userJson(mustChange: storedFlag)),
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final notifier = AuthNotifier(dio, const FlutterSecureStorage());
      await _drain();
      return notifier;
    }

    test('app start with a saved session re-reads /auth/me and picks up the flag', () async {
      final adapter = _FakeAdapter((o) => o.uri.path.endsWith('/auth/me') ? (200, _userJson(mustChange: true)) : (404, null));
      final notifier = await signedIn(adapter);

      expect(adapter.requests.map((r) => r.uri.path), contains(endsWith('/auth/me')));
      expect(adapter.requests.first.headers['Authorization'], startsWith('Bearer '));
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.user!.mustChangePassword, isTrue);
      final stored = jsonDecode((await const FlutterSecureStorage().read(key: 'importflow_user_profile'))!);
      expect(stored['must_change_password'], isTrue);
    });

    test('a failing /auth/me keeps the stored user (offline start)', () async {
      final adapter = _FakeAdapter((_) => (500, {'detail': 'down'}));
      final notifier = await signedIn(adapter, storedFlag: true);

      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.user!.mustChangePassword, isTrue);
    });

    test('markPasswordChangeRequired flags the user once; applyUserJson clears it', () async {
      final adapter = _FakeAdapter((_) => (200, _userJson(mustChange: false)));
      final notifier = await signedIn(adapter);
      expect(notifier.state.user!.mustChangePassword, isFalse);

      final seen = <AuthState>[];
      notifier.addListener(seen.add, fireImmediately: false);
      notifier.markPasswordChangeRequired();
      notifier.markPasswordChangeRequired();
      expect(notifier.state.user!.mustChangePassword, isTrue);
      expect(seen, hasLength(1), reason: 'idempotent: one state change');

      await notifier.applyUserJson(_userJson(mustChange: false));
      expect(notifier.state.user!.mustChangePassword, isFalse);
      expect(notifier.state.isAuthenticated, isTrue);
    });

    test('markPasswordChangeRequired is a no-op when signed out', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final notifier = AuthNotifier(Dio(), const FlutterSecureStorage());
      await _drain();
      notifier.markPasswordChangeRequired();
      expect(notifier.state.user, isNull);
      expect(notifier.state.isAuthenticated, isFalse);
    });
  });

  group('dioProvider 403 PASSWORD_CHANGE_REQUIRED interceptor', () {
    test('flags the signed-in user and surfaces the readable message', () async {
      FlutterSecureStorage.setMockInitialValues({
        'importflow_jwt_token': _validJwt(),
        'importflow_user_profile': jsonEncode(_userJson(mustChange: false)),
      });
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = _FakeAdapter((_) => (200, _userJson(mustChange: false)));
          return AuthNotifier(dio, ref.watch(secureStorageProvider));
        }),
      ]);
      addTearDown(container.dispose);
      container.read(authProvider);
      await _drain();
      expect(container.read(authProvider).user!.mustChangePassword, isFalse);

      final dio = container.read(dioProvider)
        ..httpClientAdapter = _FakeAdapter((_) => (403, {
              'detail': {'code': 'PASSWORD_CHANGE_REQUIRED', 'message': 'يجب تغيير كلمة المرور'},
            }));

      DioException? caught;
      try {
        await dio.get('/import-files');
      } on DioException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.message, 'يجب تغيير كلمة المرور');
      expect(container.read(authProvider).user!.mustChangePassword, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue, reason: 'no logout on this 403');
    });

    test('uploadDioProvider also flags the user on the 403', () async {
      FlutterSecureStorage.setMockInitialValues({
        'importflow_jwt_token': _validJwt(),
        'importflow_user_profile': jsonEncode(_userJson(mustChange: false)),
      });
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = _FakeAdapter((_) => (200, _userJson(mustChange: false)));
          return AuthNotifier(dio, ref.watch(secureStorageProvider));
        }),
      ]);
      addTearDown(container.dispose);
      container.read(authProvider);
      await _drain();
      expect(container.read(authProvider).user!.mustChangePassword, isFalse);

      final upload = container.read(uploadDioProvider)
        ..httpClientAdapter = _FakeAdapter((_) => (403, {
              'detail': {'code': 'PASSWORD_CHANGE_REQUIRED', 'message': 'يجب تغيير كلمة المرور'},
            }));

      await expectLater(upload.post('/smart-upload', data: FormData()), throwsA(isA<DioException>()));
      expect(container.read(authProvider).user!.mustChangePassword, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue, reason: 'no logout on this 403');

      // A plain 403 on the upload client leaves a cleared flag alone.
      await container.read(authProvider.notifier).applyUserJson(_userJson(mustChange: false));
      upload.httpClientAdapter = _FakeAdapter((_) => (403, {'detail': 'Admins only'}));
      await expectLater(upload.post('/smart-upload', data: FormData()), throwsA(isA<DioException>()));
      expect(container.read(authProvider).user!.mustChangePassword, isFalse);
    });

    test('a plain 403 does not flag the user', () async {
      FlutterSecureStorage.setMockInitialValues({
        'importflow_jwt_token': _validJwt(),
        'importflow_user_profile': jsonEncode(_userJson(mustChange: false)),
      });
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = _FakeAdapter((_) => (200, _userJson(mustChange: false)));
          return AuthNotifier(dio, ref.watch(secureStorageProvider));
        }),
      ]);
      addTearDown(container.dispose);
      container.read(authProvider);
      await _drain();

      final dio = container.read(dioProvider)..httpClientAdapter = _FakeAdapter((_) => (403, {'detail': 'Admins only'}));
      await expectLater(dio.get('/users'), throwsA(isA<DioException>()));
      expect(container.read(authProvider).user!.mustChangePassword, isFalse);
    });
  });
}
