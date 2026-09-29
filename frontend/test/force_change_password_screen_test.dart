import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/auth/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/providers/password_change_provider.dart';
import 'package:frontend/features/auth/screens/force_change_password_screen.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:frontend/main.dart';

Map<String, dynamic> _userJson({required bool mustChange}) => {
      'user_id': 1,
      'username': 'admin',
      'email': 'admin@importflow.com',
      'full_name': 'System Admin',
      'role': 'ADMIN',
      'is_active': true,
      'must_change_password': mustChange,
    };

class _FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _FakeAuthNotifier({required bool mustChange})
      : super(AuthState(
          isAuthenticated: true,
          token: 't',
          user: UserModel.fromJson(_userJson(mustChange: mustChange)),
        ));

  int logoutCalls = 0;

  @override
  Future<void> applyUserJson(Map<String, dynamic> userJson) async {
    state = state.copyWith(user: UserModel.fromJson(userJson));
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AuthState();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepository extends PasswordChangeRepository {
  _FakeRepository({this.error}) : super(Dio());

  final PasswordChangeException? error;
  final List<(String, String)> calls = [];

  @override
  Future<PasswordChangeResult> changePassword({required String currentPassword, required String newPassword}) async {
    calls.add((currentPassword, newPassword));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (error != null) throw error!;
    final json = _userJson(mustChange: false);
    return PasswordChangeResult(user: UserModel.fromJson(json), userJson: json);
  }
}

void _desktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1366, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeAuthNotifier auth,
  required _FakeRepository repo,
  Widget home = const ForceChangePasswordScreen(),
  Locale locale = const Locale('ar'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => auth),
        passwordChangeRepositoryProvider.overrideWithValue(repo),
      ],
      child: AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: MaterialApp(home: home),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String current = 'Admin@123', String next = 'N3w-Secure!', String? confirm}) async {
  await tester.enterText(find.descendant(of: find.byKey(const ValueKey('force_pwd_current')), matching: find.byType(TextField)), current);
  await tester.enterText(find.descendant(of: find.byKey(const ValueKey('force_pwd_new')), matching: find.byType(TextField)), next);
  await tester.enterText(
    find.descendant(of: find.byKey(const ValueKey('force_pwd_confirm')), matching: find.byType(TextField)),
    confirm ?? next,
  );
}

void main() {
  const ar = AppLocalizationsAr();
  const en = AppLocalizationsEn();

  group('ForceChangePasswordScreen', () {
    testWidgets('explains the first-login requirement (ar and en)', (tester) async {
      _desktopView(tester);
      await _pump(tester, auth: _FakeAuthNotifier(mustChange: true), repo: _FakeRepository());
      expect(find.text(ar.forcePwdTitle), findsOneWidget);
      expect(find.text(ar.forcePwdSubtitle), findsOneWidget);
      expect(find.text('${ar.forcePwdAccountLabel}: admin'), findsOneWidget);

      await _pump(tester, auth: _FakeAuthNotifier(mustChange: true), repo: _FakeRepository(), locale: const Locale('en'));
      expect(find.text(en.forcePwdTitle), findsOneWidget);
      expect(find.text(en.forcePwdSubmit), findsOneWidget);
    });

    testWidgets('empty submit shows required errors and does not call the API', (tester) async {
      _desktopView(tester);
      final repo = _FakeRepository();
      await _pump(tester, auth: _FakeAuthNotifier(mustChange: true), repo: repo);

      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')));
      await tester.pumpAndSettle();

      expect(find.text(ar.forcePwdCurrentRequired), findsOneWidget);
      expect(find.text(ar.forcePwdNewRequired), findsOneWidget);
      expect(find.text(ar.forcePwdConfirmRequired), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('rejects short, unchanged and mismatched passwords', (tester) async {
      _desktopView(tester);
      final repo = _FakeRepository();
      await _pump(tester, auth: _FakeAuthNotifier(mustChange: true), repo: repo);

      await _fill(tester, next: 'short');
      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')));
      await tester.pumpAndSettle();
      expect(find.text(ar.forcePwdTooShort), findsOneWidget);

      await _fill(tester, next: 'Admin@123');
      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')));
      await tester.pumpAndSettle();
      expect(find.text(ar.forcePwdSameAsCurrent), findsOneWidget);

      await _fill(tester, next: 'N3w-Secure!', confirm: 'N3w-Secure?');
      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')));
      await tester.pumpAndSettle();
      expect(find.text(ar.forcePwdMismatch), findsOneWidget);

      expect(repo.calls, isEmpty);
    });

    testWidgets('show/hide toggle reveals the password', (tester) async {
      _desktopView(tester);
      await _pump(tester, auth: _FakeAuthNotifier(mustChange: true), repo: _FakeRepository());
      TextField field() => tester.widget<TextField>(
          find.descendant(of: find.byKey(const ValueKey('force_pwd_new')), matching: find.byType(TextField)));

      expect(field().obscureText, isTrue);
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('force_pwd_new')), matching: find.byTooltip(ar.forcePwdShowPassword)));
      await tester.pump();
      expect(field().obscureText, isFalse);
    });

    testWidgets('success: clears the flag, shows a success SnackBar, blocks double submit', (tester) async {
      _desktopView(tester);
      final auth = _FakeAuthNotifier(mustChange: true);
      final repo = _FakeRepository();
      await _pump(tester, auth: auth, repo: repo);

      await _fill(tester);
      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')));
      await tester.pump();
      // In flight: button shows a spinner and ignores repeat taps.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repo.calls, [('Admin@123', 'N3w-Secure!')]);
      expect(auth.state.user!.mustChangePassword, isFalse);
      expect(find.text(ar.forcePwdSuccess), findsOneWidget);
    });

    testWidgets('backend 400: shows the server message inline and as a SnackBar', (tester) async {
      _desktopView(tester);
      const serverMsg = 'كلمة المرور الحالية غير صحيحة';
      final auth = _FakeAuthNotifier(mustChange: true);
      final repo = _FakeRepository(error: const PasswordChangeException(message: serverMsg, statusCode: 400));
      await _pump(tester, auth: auth, repo: repo);

      await _fill(tester);
      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')));
      await tester.pumpAndSettle();

      expect(find.text(serverMsg), findsNWidgets(2));
      expect(auth.state.user!.mustChangePassword, isTrue);
      expect(find.byType(ForceChangePasswordScreen), findsOneWidget);
    });

    testWidgets('error without detail falls back to the localized message', (tester) async {
      _desktopView(tester);
      final repo = _FakeRepository(error: const PasswordChangeException(statusCode: 500));
      await _pump(tester, auth: _FakeAuthNotifier(mustChange: true), repo: repo);

      await _fill(tester);
      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')));
      await tester.pumpAndSettle();

      expect(find.text(ar.forcePwdFailed), findsNWidgets(2));
    });

    testWidgets('logout is allowed', (tester) async {
      _desktopView(tester);
      final auth = _FakeAuthNotifier(mustChange: true);
      await _pump(tester, auth: auth, repo: _FakeRepository());

      await tester.tap(find.byKey(const ValueKey('force_pwd_logout')));
      await tester.pumpAndSettle();
      expect(auth.logoutCalls, 1);
    });
  });

  group('Shell guard (AuthGate -> HomeScreen)', () {
    testWidgets('flagged user sees only the change screen, then continues to the app', (tester) async {
      _desktopView(tester);
      final auth = _FakeAuthNotifier(mustChange: true);
      await _pump(tester, auth: auth, repo: _FakeRepository(), home: const AuthGate());

      expect(find.byType(ForceChangePasswordScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      await _fill(tester);
      await tester.tap(find.byKey(const ValueKey('force_pwd_submit')));
      await tester.pumpAndSettle();

      expect(find.byType(ForceChangePasswordScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('unflagged user goes straight to the app', (tester) async {
      _desktopView(tester);
      await _pump(tester, auth: _FakeAuthNotifier(mustChange: false), repo: _FakeRepository(), home: const AuthGate());

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ForceChangePasswordScreen), findsNothing);
    });

    testWidgets('logging out from the change screen returns to login', (tester) async {
      _desktopView(tester);
      await _pump(tester, auth: _FakeAuthNotifier(mustChange: true), repo: _FakeRepository(), home: const AuthGate());

      await tester.tap(find.byKey(const ValueKey('force_pwd_logout')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
