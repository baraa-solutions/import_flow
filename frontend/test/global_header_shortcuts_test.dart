import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/global_header_shortcuts_bar.dart';

/// Seeds secure storage so AuthNotifier restores a session for [role]
/// (or no session when [role] is null). The email settings shortcut is
/// admin-only.
void _seedSession(String? role) {
  if (role == null) {
    FlutterSecureStorage.setMockInitialValues({});
    return;
  }
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
  final token = '${enc({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${enc({'sub': '1', 'username': 'u', 'role': role, 'exp': exp})}.sig';
  FlutterSecureStorage.setMockInitialValues({
    'importflow_jwt_token': token,
    'importflow_user_profile': jsonEncode({
      'user_id': 1,
      'username': 'u',
      'email': 'u@importflow.com',
      'full_name': 'Test User',
      'role': role,
      'is_active': true,
    }),
  });
}

void main() {
  setUp(() => _seedSession('ADMIN'));

  Widget buildTestWidget({Locale locale = const Locale('ar')}) {
    return ProviderScope(
      child: MaterialApp(
        home: AppLocalizationsProvider(
          locale: locale,
          child: const Scaffold(
            body: GlobalHeaderShortcutsBar(),
          ),
        ),
      ),
    );
  }

  group('GlobalHeaderShortcutsBar Tests', () {
    testWidgets('renders all 9 shortcut controls in Arabic locale', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // 1. Command Palette pill (Ctrl+K)
      expect(find.text('الأوامر'), findsOneWidget);
      expect(find.text('Ctrl+K'), findsOneWidget);

      // 2. Email listener button
      expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);

      // 3. Email settings button (ADMIN session)
      expect(find.byIcon(Icons.settings_suggest_rounded), findsOneWidget);

      // 4. Language switcher pill
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);

      // 5. Dark mode toggle button
      expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

      // 6. Basic system settings button
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // 7. Keyboard help button
      expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);

      // 8. Fullscreen button
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    });

    testWidgets('renders properly in English locale', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Commands'), findsOneWidget);
      expect(find.text('Ctrl+K'), findsOneWidget);
      expect(find.text('عربي'), findsOneWidget);
    });

    for (final role in <String?>[null, 'OPERATOR']) {
      testWidgets('hides the admin-only email settings button for ${role ?? 'no user'}', (tester) async {
        _seedSession(role);
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestWidget(locale: const Locale('ar')));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.settings_suggest_rounded), findsNothing);
        // Non-admin shortcuts are still there.
        expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
      });
    }
  });
}
