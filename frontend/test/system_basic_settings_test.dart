import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/theme/density_provider.dart';
import 'package:frontend/core/theme/theme_provider.dart';
import 'package:frontend/core/widgets/system_settings_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Core System Basic Settings Providers', () {
    test('localeProvider toggles between English and Arabic accurately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(localeProvider.notifier);

      // Explicit set to English
      notifier.setLocale(const Locale('en'));
      expect(container.read(localeProvider).languageCode, equals('en'));
      expect(notifier.isEnglish, isTrue);
      expect(notifier.isArabic, isFalse);

      // Toggle to Arabic
      notifier.toggleLocale();
      expect(container.read(localeProvider).languageCode, equals('ar'));
      expect(notifier.isArabic, isTrue);
      expect(notifier.isEnglish, isFalse);

      // Toggle back to English
      notifier.toggleLocale();
      expect(container.read(localeProvider).languageCode, equals('en'));
      expect(notifier.isEnglish, isTrue);
    });

    test('themeModeProvider toggles between Light and Dark mode accurately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeModeProvider.notifier);

      // Set to Light mode
      notifier.setThemeMode(ThemeMode.light);
      expect(container.read(themeModeProvider), equals(ThemeMode.light));
      expect(notifier.isDarkMode, isFalse);

      // Toggle to Dark mode
      notifier.toggleTheme();
      expect(container.read(themeModeProvider), equals(ThemeMode.dark));
      expect(notifier.isDarkMode, isTrue);

      // Toggle back to Light mode
      notifier.toggleTheme();
      expect(container.read(themeModeProvider), equals(ThemeMode.light));
      expect(notifier.isDarkMode, isFalse);

      // Set to System mode
      notifier.setThemeMode(ThemeMode.system);
      expect(container.read(themeModeProvider), equals(ThemeMode.system));
    });

    test('displayDensityProvider updates density mode and maps VisualDensity', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(displayDensityProvider.notifier);

      // Comfortable
      notifier.setDensity(DisplayDensityMode.comfortable);
      final comfortable = container.read(displayDensityProvider);
      expect(comfortable, equals(DisplayDensityMode.comfortable));
      expect(comfortable.visualDensity, equals(VisualDensity.standard));
      expect(comfortable.rowHeight, equals(56.0));
      expect(comfortable.toolbarHeight, equals(40.0));

      // Compact
      notifier.setDensity(DisplayDensityMode.compact);
      final compact = container.read(displayDensityProvider);
      expect(compact, equals(DisplayDensityMode.compact));
      expect(compact.visualDensity, equals(VisualDensity.compact));
      expect(compact.rowHeight, equals(48.0));
      expect(compact.toolbarHeight, equals(36.0));

      // Ultra-Compact
      notifier.setDensity(DisplayDensityMode.ultraCompact);
      final ultra = container.read(displayDensityProvider);
      expect(ultra, equals(DisplayDensityMode.ultraCompact));
      expect(ultra.visualDensity, equals(const VisualDensity(horizontal: -3, vertical: -3)));
      expect(ultra.rowHeight, equals(40.0));
      expect(ultra.toolbarHeight, equals(30.0));
    });
  });

  group('SystemSettingsDialog UI Widget Tests', () {
    testWidgets('renders all tabs and sections correctly in Arabic mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: SystemSettingsDialog(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check dialog header
      expect(find.text('الإعدادات الأساسية للنظام'), findsOneWidget);

      // Check tab titles
      expect(find.text('اللغة والاتجاه'), findsOneWidget);
      expect(find.text('المظهر والسمة'), findsOneWidget);
      expect(find.text('كثافة العرض'), findsOneWidget);
      expect(find.text('التشخيص والبيئة'), findsOneWidget);

      // Tab 1: Language options
      expect(find.text('العربية (Arabic)'), findsOneWidget);
      expect(find.text('English (الإنجليزية)'), findsOneWidget);

      // Switch to Tab 2: Theme
      await tester.tap(find.text('المظهر والسمة'));
      await tester.pumpAndSettle();
      expect(find.text('الوضع النهاري (Light Mode)'), findsOneWidget);
      expect(find.text('الوضع الليلي عالي التباين (Dark Mode)'), findsOneWidget);
      expect(find.text('تلقائي حسب نظام التشغيل (System)'), findsOneWidget);

      // Switch to Tab 3: Display Density
      await tester.tap(find.text('كثافة العرض'));
      await tester.pumpAndSettle();
      expect(find.text('مريح (Comfortable - 56px)'), findsOneWidget);
      expect(find.text('مدمج (Compact - 48px)'), findsOneWidget);
      expect(find.text('فائق الكثافة (Ultra-Compact - 40px)'), findsOneWidget);

      // Switch to Tab 4: Diagnostics
      await tester.tap(find.text('التشخيص والبيئة'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sorour Logistics ERP v${ApiConstants.clientVersion} (Build ${ApiConstants.clientBuildNumber})'),
        findsOneWidget,
      );
      expect(find.text('sorour_logistics.db (SQLite WAL Mode)'), findsOneWidget);
      expect(find.text('تحديث فوري'), findsOneWidget);
    });

    testWidgets('renders properly in English mode with LTR layout', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: AppLocalizationsProvider(
            locale: Locale('en'),
            child: MaterialApp(
              locale: Locale('en'),
              home: Scaffold(
                body: SystemSettingsDialog(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // English Header
      expect(find.text('Basic System Settings'), findsOneWidget);
      expect(find.text('Language & RTL'), findsOneWidget);
      expect(find.text('Theme & Mode'), findsOneWidget);
      expect(find.text('Display Density'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);

      // Check Done button
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
