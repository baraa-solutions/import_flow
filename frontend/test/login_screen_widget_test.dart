import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';

Widget _buildTestApp({Locale locale = const Locale('ar'), bool showDemoLogins = true}) {
  return ProviderScope(
    child: MaterialApp(
      home: AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection:
              locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: LoginScreen(showDemoLogins: showDemoLogins),
        ),
      ),
    ),
  );
}

void main() {
  group('LoginScreen Widget & Copy Functionality Tests', () {
    testWidgets('LoginScreen wraps form card inside SelectionArea for desktop selectable text', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Renders username and password fields with copy suffix buttons', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byIcon(Icons.copy_rounded), findsAtLeastNWidgets(2));
    });

    testWidgets('Renders Quick Demo Account chips with copy actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final ar = AppLocalizationsAr();
      expect(find.text(ar.loginRoleAdmin), findsOneWidget);
      expect(find.text(ar.loginRoleManager), findsOneWidget);
      expect(find.text(ar.loginRoleSpecialist), findsOneWidget);
    });

    testWidgets('Renders properly in English mode with pure English text', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(locale: const Locale('en')));
      await tester.pumpAndSettle();

      final en = AppLocalizationsEn();
      expect(find.text(en.loginButtonLabel), findsOneWidget);
      expect(find.text(en.loginRoleAdmin), findsOneWidget);
      expect(find.text(en.loginRoleManager), findsOneWidget);
      expect(find.text(en.loginRoleSpecialist), findsOneWidget);
    });

    testWidgets('Validates empty fields and shows red validation messages', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final ar = AppLocalizationsAr();
      // Tap Sign in without filling anything
      await tester.tap(find.text(ar.loginButtonLabel));
      await tester.pumpAndSettle();

      expect(find.text(ar.loginUsernameRequired), findsOneWidget);
      expect(find.text(ar.loginPasswordRequired), findsOneWidget);
    });

    testWidgets('Demo quick-login chips are hidden when demo logins are off (release: !kDebugMode)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(locale: const Locale('en'), showDemoLogins: false));
      await tester.pumpAndSettle();

      final en = AppLocalizationsEn();
      expect(find.text(en.loginQuickDemoAccess), findsNothing);
      expect(find.text(en.loginRoleAdmin), findsNothing);
      expect(find.text(en.loginRoleManager), findsNothing);
      expect(find.text(en.loginRoleSpecialist), findsNothing);
      expect(find.byTooltip(en.loginDemoCredentialsTooltip), findsNothing);
      // The login form itself is still there.
      expect(find.text(en.loginButtonLabel), findsOneWidget);
    });

    test('LoginScreen defaults showDemoLogins to kDebugMode', () {
      expect(const LoginScreen().showDemoLogins, kDebugMode);
    });
  });
}
