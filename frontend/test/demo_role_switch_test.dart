import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';

Future<AuthNotifier> _freshNotifier() async {
  FlutterSecureStorage.setMockInitialValues({});
  final notifier = AuthNotifier(Dio(), const FlutterSecureStorage());
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthNotifier.switchDemoRole', () {
    final original = AuthNotifier.demoRoleSwitchEnabled;
    tearDown(() => AuthNotifier.demoRoleSwitchEnabled = original);

    test('is a no-op when demo role switching is disabled (release builds)', () async {
      AuthNotifier.demoRoleSwitchEnabled = false;
      final notifier = await _freshNotifier();
      final before = notifier.state;

      notifier.switchDemoRole('ADMIN');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(identical(notifier.state, before), isTrue);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.user, isNull);
      expect(await const FlutterSecureStorage().read(key: 'importflow_user_profile'), isNull);
    });

    test('switches the role when enabled (debug builds)', () async {
      AuthNotifier.demoRoleSwitchEnabled = true;
      final notifier = await _freshNotifier();

      notifier.switchDemoRole('MANAGER');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.user?.role, 'MANAGER');
    });
  });
}
