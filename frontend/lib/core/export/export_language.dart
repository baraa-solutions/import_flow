import 'package:shared_preferences/shared_preferences.dart';

/// Supported export languages for Sorour Logistics ERP downloads (PDF, Excel, CSV).
enum ExportLanguage {
  ar,
  en;

  String get code => name;

  bool get isArabic => this == ExportLanguage.ar;
  bool get isEnglish => this == ExportLanguage.en;

  String get displayNameAr => isArabic ? 'العربية' : 'الإنجليزية';
  String get displayNameEn => isArabic ? 'Arabic' : 'English';

  /// Returns user-facing label depending on context.
  String get label => isArabic ? 'العربية (Arabic)' : 'English (الإنجليزية)';

  static ExportLanguage fromCode(String? code, {ExportLanguage fallback = ExportLanguage.ar}) {
    if (code == null) return fallback;
    final normalized = code.trim().toLowerCase();
    if (normalized == 'en' || normalized == 'english') return ExportLanguage.en;
    return ExportLanguage.ar;
  }

  // ── SharedPreferences Keys & Values ──
  static const String prefKeyDefaultLanguage = 'export_default_language';
  static const String prefKeyLastChosenLanguage = 'export_last_chosen_language';

  static const String optionAsk = 'ask';
  static const String optionAr = 'ar';
  static const String optionEn = 'en';

  /// Loads saved default export language setting: 'ask', 'ar', or 'en'.
  static Future<String> getSavedDefaultOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(prefKeyDefaultLanguage) ?? optionAsk;
    } catch (_) {
      return optionAsk;
    }
  }

  /// Saves the user's default export language setting.
  static Future<void> saveDefaultOption(String option) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyDefaultLanguage, option);
    } catch (_) {}
  }

  /// Loads the last language chosen by the user, or null if never chosen.
  static Future<ExportLanguage?> getLastChosenLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(prefKeyLastChosenLanguage);
      if (code != null) return fromCode(code);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Saves the last language chosen by the user.
  static Future<void> saveLastChosenLanguage(ExportLanguage lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyLastChosenLanguage, lang.code);
    } catch (_) {}
  }
}
