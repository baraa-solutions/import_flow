import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Locale wiring for `MaterialApp`.
///
/// App strings come from the hand-maintained `AppLocalizations` classes, which
/// `AppLocalizationsProvider` exposes above `MaterialApp`. These lists only make
/// Flutter's own `Localizations` resolve `ar` instead of falling back to en_US.
/// That fallback used to give every screen an LTR [Directionality] and English
/// Material strings (date pickers, tooltips, "Paste", ...) under Arabic.
class AppLocales {
  AppLocales._();

  static const Locale english = Locale('en');

  /// Plain `ar` (not `ar_EG`) on purpose: one Arabic variant, Western digits.
  static const Locale arabic = Locale('ar');

  /// English first: it is the fallback for any unsupported device locale.
  static const List<Locale> supportedLocales = [english, arabic];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Text direction the app uses for [locale].
  static TextDirection textDirectionFor(Locale locale) =>
      locale.languageCode == arabic.languageCode ? TextDirection.rtl : TextDirection.ltr;
}
