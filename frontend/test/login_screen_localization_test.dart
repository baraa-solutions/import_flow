import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';

void main() {
  group('LoginScreen Localization & Anti-Stacking Tests', () {
    late AppLocalizations ar;
    late AppLocalizations en;

    setUp(() {
      ar = const AppLocalizationsAr();
      en = const AppLocalizationsEn();
    });

    test('All LoginScreen Arabic strings must be non-empty', () {
      final strings = [
        ar.loginScreenTitle,
        ar.loginScreenSubtitle,
        ar.loginUsernameLabel,
        ar.loginUsernameHint,
        ar.loginUsernameRequired,
        ar.loginPasswordLabel,
        ar.loginPasswordRequired,
        ar.loginButtonLabel,
        ar.loginAuthenticating,
        ar.loginQuickDemoAccess,
        ar.loginInvalidCredentials,
        ar.loginRoleAdmin,
        ar.loginRoleManager,
        ar.loginRoleSpecialist,
        ar.loginCopyUsernameTooltip,
        ar.loginUsernameCopied,
        ar.loginCopyPasswordTooltip,
        ar.loginPasswordCopied,
        ar.loginDemoCredentialsCopied,
        ar.loginDemoCredentialsTooltip,
      ];

      for (final s in strings) {
        expect(s.trim().isNotEmpty, isTrue, reason: 'Empty string found');
      }
    });

    test('All LoginScreen Arabic strings must have strictly 0 Latin characters [a-zA-Z]', () {
      final latinRegex = RegExp(r'[a-zA-Z]');
      final strings = [
        ar.loginScreenTitle,
        ar.loginScreenSubtitle,
        ar.loginUsernameLabel,
        ar.loginUsernameHint,
        ar.loginUsernameRequired,
        ar.loginPasswordLabel,
        ar.loginPasswordRequired,
        ar.loginButtonLabel,
        ar.loginAuthenticating,
        ar.loginQuickDemoAccess,
        ar.loginInvalidCredentials,
        ar.loginRoleAdmin,
        ar.loginRoleManager,
        ar.loginRoleSpecialist,
        ar.loginCopyUsernameTooltip,
        ar.loginUsernameCopied,
        ar.loginCopyPasswordTooltip,
        ar.loginPasswordCopied,
        ar.loginDemoCredentialsCopied,
        ar.loginDemoCredentialsTooltip,
      ];

      for (final s in strings) {
        expect(latinRegex.hasMatch(s), isFalse,
            reason: 'Found Latin characters in Arabic string: "$s"');
      }
    });

    test('All LoginScreen Arabic strings must have 0 bilingual slashes /', () {
      final strings = [
        ar.loginScreenTitle,
        ar.loginScreenSubtitle,
        ar.loginUsernameLabel,
        ar.loginUsernameHint,
        ar.loginUsernameRequired,
        ar.loginPasswordLabel,
        ar.loginPasswordRequired,
        ar.loginButtonLabel,
        ar.loginAuthenticating,
        ar.loginQuickDemoAccess,
        ar.loginInvalidCredentials,
        ar.loginRoleAdmin,
        ar.loginRoleManager,
        ar.loginRoleSpecialist,
        ar.loginCopyUsernameTooltip,
        ar.loginUsernameCopied,
        ar.loginCopyPasswordTooltip,
        ar.loginPasswordCopied,
        ar.loginDemoCredentialsCopied,
        ar.loginDemoCredentialsTooltip,
      ];

      for (final s in strings) {
        expect(s.contains('/'), isFalse,
            reason: 'Found bilingual slash in Arabic string: "$s"');
      }
    });

    test('All LoginScreen English strings must be non-empty', () {
      final strings = [
        en.loginScreenTitle,
        en.loginScreenSubtitle,
        en.loginUsernameLabel,
        en.loginUsernameHint,
        en.loginUsernameRequired,
        en.loginPasswordLabel,
        en.loginPasswordRequired,
        en.loginButtonLabel,
        en.loginAuthenticating,
        en.loginQuickDemoAccess,
        en.loginInvalidCredentials,
        en.loginRoleAdmin,
        en.loginRoleManager,
        en.loginRoleSpecialist,
        en.loginCopyUsernameTooltip,
        en.loginUsernameCopied,
        en.loginCopyPasswordTooltip,
        en.loginPasswordCopied,
        en.loginDemoCredentialsCopied,
        en.loginDemoCredentialsTooltip,
      ];

      for (final s in strings) {
        expect(s.trim().isNotEmpty, isTrue, reason: 'Empty English string found');
      }
    });
  });
}
