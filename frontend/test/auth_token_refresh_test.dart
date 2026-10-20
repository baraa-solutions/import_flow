import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier Token Expiry & Silent Refresh Unit Tests', () {
    String generateTestJwt({required int expOffsetSeconds}) {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
      final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expOffsetSeconds;
      final payload = base64Url.encode(utf8.encode(jsonEncode({
        'sub': '1',
        'username': 'admin',
        'role': 'ADMIN',
        'exp': exp,
      }))).replaceAll('=', '');
      const sig = 'mock_signature_hash_123456';
      return '$header.$payload.$sig';
    }

    test('isTokenExpired returns false for valid future token', () {
      final validToken = generateTestJwt(expOffsetSeconds: 3600); // 1 hour in future
      expect(AuthNotifier.isTokenExpired(validToken), isFalse);
    });

    test('isTokenExpired returns true for expired past token', () {
      final expiredToken = generateTestJwt(expOffsetSeconds: -100); // 100s in past
      expect(AuthNotifier.isTokenExpired(expiredToken), isTrue);
    });

    test('isTokenExpired returns true for token expiring within 15-second buffer window', () {
      final expiringSoonToken = generateTestJwt(expOffsetSeconds: 10); // 10s in future
      expect(AuthNotifier.isTokenExpired(expiringSoonToken), isTrue);
    });

    test('isTokenExpired returns true for malformed tokens', () {
      expect(AuthNotifier.isTokenExpired('not.a.jwt'), isTrue);
      expect(AuthNotifier.isTokenExpired(''), isTrue);
      expect(AuthNotifier.isTokenExpired('a.b'), isTrue);
    });

    test('handleSessionExpired sets state unauthenticated with friendly error message', () async {
      FlutterSecureStorage.setMockInitialValues({
        'importflow_jwt_token': 'expired_token',
        'importflow_user_profile': jsonEncode({
          'user_id': 1,
          'username': 'admin',
          'email': 'admin@importflow.com',
          'full_name': 'System Admin',
          'role': 'ADMIN',
          'is_active': true,
        }),
      });

      const storage = FlutterSecureStorage();
      final dio = Dio();
      final notifier = AuthNotifier(dio, storage);

      await notifier.handleSessionExpired();

      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.token, isNull);
      expect(notifier.state.user, isNull);
      expect(notifier.state.errorMessage, contains('انتهت صلاحية'));

      final tokenAfter = await storage.read(key: 'importflow_jwt_token');
      expect(tokenAfter, isNull);
    });
  });
}
