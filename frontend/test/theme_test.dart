import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dark Theme & Palette Architecture Tests', () {
    test('AppTheme.darkTheme is configured with correct enterprise palette and contrast', () {
      final darkTheme = AppTheme.darkTheme;

      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(darkTheme.primaryColor, equals(AppTheme.cobalt));
      expect(darkTheme.scaffoldBackgroundColor, equals(AppTheme.darkScaffoldBackground));
      expect(darkTheme.cardColor, equals(AppTheme.darkCardBackground));
      expect(darkTheme.colorScheme.surface, equals(AppTheme.darkSurface));
      expect(darkTheme.colorScheme.onSurface, equals(AppTheme.darkTextPrimary));
      expect(darkTheme.colorScheme.primary, equals(AppTheme.cobalt));
      expect(darkTheme.colorScheme.secondary, equals(AppTheme.emerald));
      expect(darkTheme.colorScheme.error, equals(AppTheme.crimson));
      expect(darkTheme.dialogTheme.backgroundColor, equals(AppTheme.darkElevatedSurface));
    });

    test('AppTheme.lightTheme maintains standard enterprise light palette', () {
      final lightTheme = AppTheme.lightTheme;

      expect(lightTheme.brightness, equals(Brightness.light));
      expect(lightTheme.primaryColor, equals(AppTheme.cobalt));
      expect(lightTheme.scaffoldBackgroundColor, equals(AppTheme.cloudWhite));
      expect(lightTheme.cardColor, equals(Colors.white));
      expect(lightTheme.colorScheme.surface, equals(Colors.white));
      expect(lightTheme.colorScheme.onSurface, equals(AppTheme.charcoal));
    });

    testWidgets('Adaptive decoration helpers switch correctly between Light and Dark', (tester) async {
      late BoxDecoration lightCardDeco;
      late BoxDecoration darkCardDeco;
      late BoxDecoration lightToolbarDeco;
      late BoxDecoration darkToolbarDeco;
      late BoxDecoration lightPillDeco;
      late BoxDecoration darkPillDeco;

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.lightTheme,
            child: Builder(
              builder: (context) {
                lightCardDeco = AppTheme.cardDecorationOf(context);
                lightToolbarDeco = AppTheme.toolbarDecorationOf(context);
                lightPillDeco = AppTheme.pillDecorationOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(lightCardDeco.color, equals(Colors.white));
      expect(lightToolbarDeco.color, equals(Colors.white));
      expect(lightPillDeco.color, equals(Colors.white));

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.darkTheme,
            child: Builder(
              builder: (context) {
                darkCardDeco = AppTheme.cardDecorationOf(context);
                darkToolbarDeco = AppTheme.toolbarDecorationOf(context);
                darkPillDeco = AppTheme.pillDecorationOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(darkCardDeco.color, equals(AppTheme.darkCardBackground));
      expect(darkToolbarDeco.color, equals(AppTheme.darkSurface));
      expect(darkPillDeco.color, equals(AppTheme.darkSurface));
    });
  });

  group('ThemeModeNotifier State Tests', () {
    test('ThemeModeNotifier initializes and toggles between Light and Dark', () async {
      final notifier = ThemeModeNotifier();

      expect(notifier.state, equals(ThemeMode.light));
      expect(notifier.isDarkMode, isFalse);

      await notifier.toggleTheme();
      expect(notifier.state, equals(ThemeMode.dark));
      expect(notifier.isDarkMode, isTrue);

      await notifier.toggleTheme();
      expect(notifier.state, equals(ThemeMode.light));
      expect(notifier.isDarkMode, isFalse);

      await notifier.setThemeMode(ThemeMode.system);
      expect(notifier.state, equals(ThemeMode.system));
      expect(notifier.isDarkMode, isFalse);
    });
  });

  group('Theme Localization & Language Consistency Tests', () {
    final latinRegex = RegExp(r'[a-zA-Z]');

    test('Arabic theme strings are non-empty and contain 0 Latin characters', () {
      const ar = AppLocalizationsAr();

      expect(ar.themeToggleTooltip.isNotEmpty, isTrue);
      expect(ar.darkMode.isNotEmpty, isTrue);
      expect(ar.lightMode.isNotEmpty, isTrue);
      expect(ar.systemMode.isNotEmpty, isTrue);

      expect(latinRegex.hasMatch(ar.themeToggleTooltip), isFalse,
          reason: 'themeToggleTooltip in Arabic must have 0 Latin characters');
      expect(latinRegex.hasMatch(ar.darkMode), isFalse,
          reason: 'darkMode in Arabic must have 0 Latin characters');
      expect(latinRegex.hasMatch(ar.lightMode), isFalse,
          reason: 'lightMode in Arabic must have 0 Latin characters');
      expect(latinRegex.hasMatch(ar.systemMode), isFalse,
          reason: 'systemMode in Arabic must have 0 Latin characters');
    });

    test('English theme strings are non-empty and properly phrased', () {
      const en = AppLocalizationsEn();

      expect(en.themeToggleTooltip, equals('Toggle Dark / Light Mode'));
      expect(en.darkMode, equals('Dark Mode'));
      expect(en.lightMode, equals('Light Mode'));
      expect(en.systemMode, equals('System Default'));
    });
  });
}
