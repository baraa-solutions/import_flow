import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';

/// Test host that mirrors the real app's locale wiring (main.dart):
/// `AppLocalizationsProvider` ABOVE `MaterialApp` (so dialogs see
/// `context.l10n`) and `MaterialApp` with the app's supportedLocales and
/// Global* delegates (so `ar` really resolves to Arabic + RTL).
///
/// A bare `MaterialApp(locale: Locale('ar'))` silently falls back to en_US
/// and LTR; do not use that to test Arabic behaviour.
///
/// Wrap the result in a `ProviderScope` when [home] needs Riverpod.
Widget localizedApp({
  required Widget home,
  Locale locale = AppLocales.arabic,
  ThemeData? theme,
}) {
  return AppLocalizationsProvider(
    locale: locale,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocales.supportedLocales,
      localizationsDelegates: AppLocales.localizationsDelegates,
      home: home,
    ),
  );
}
