import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'global_header_shortcuts_bar.dart';

/// Top-level ISO-8601 week number calculation for backward compatibility.
int getIsoWeekNumber(DateTime date) => WorldTimezoneHelper.getIsoWeekNumber(date);

/// Helper engine for accurate international time calculations, daylight saving rules,
/// and working hours across the company's major supply & shipping jurisdictions.
class WorldTimezoneHelper {
  static const String egyptFlag = '🇪🇬';
  static const String franceItalySpainFlag = '🇪🇺';
  static const String franceItalyFlag = '🇪🇺';
  static const String franceFlag = '🇫🇷';
  static const String italyFlag = '🇮🇹';
  static const String spainFlag = '🇪🇸';
  static const String ukFlag = '🇬🇧';
  static const String turkeyLithuaniaFlag = '🇹🇷 🇱🇹';
  static const String turkeyFlag = '🇹🇷';
  static const String lithuaniaFlag = '🇱🇹';
  static const String chinaFlag = '🇨🇳';
  static const String uaeFlag = '🇦🇪';
  static const String usFlag = '🇺🇸';

  static const String egyptName = 'مصر';
  static const String franceItalySpainName = 'فرنسا وإيطاليا وإسبانيا';
  static const String franceItalyName = 'فرنسا وإيطاليا';
  static const String franceName = 'فرنسا';
  static const String italyName = 'إيطاليا';
  static const String spainName = 'إسبانيا';
  static const String ukName = 'إنجلترا';
  static const String turkeyLithuaniaName = 'تركيا وليتوانيا';
  static const String turkeyName = 'تركيا';
  static const String lithuaniaName = 'ليتوانيا';
  static const String chinaName = 'الصين';
  static const String uaeName = 'الإمارات';
  static const String usName = 'أمريكا';

  /// Computes the ISO-8601 week number for any given [date].
  static int getIsoWeekNumber(DateTime date) {
    final thursday = DateTime(date.year, date.month, date.day + (4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstMonday = DateTime(thursday.year, 1, 4 - (firstThursday.weekday - 1));
    return (thursday.difference(firstMonday).inDays ~/ 7) + 1;
  }

  /// Calculates whether the given UTC time falls within Egyptian Summer Time (DST).
  /// Law No. 24 of 2023:
  /// Starts: Last Friday of April at 00:00 (local time)
  /// Ends: Last Thursday of October at 24:00 (local time)
  static bool isEgyptSummerTime(DateTime utc) {
    if (utc.month < 4 || utc.month > 10) return false;
    if (utc.month > 4 && utc.month < 10) return true;
    if (utc.month == 4) {
      final apr30 = DateTime.utc(utc.year, 4, 30);
      final diff = apr30.weekday >= DateTime.friday
          ? apr30.weekday - DateTime.friday
          : apr30.weekday + 2;
      final lastFri = 30 - diff;
      return utc.day >= lastFri;
    }
    // month == 10
    final oct31 = DateTime.utc(utc.year, 10, 31);
    final diff = oct31.weekday >= DateTime.thursday
        ? oct31.weekday - DateTime.thursday
        : oct31.weekday + 3;
    final lastThu = 31 - diff;
    return utc.day <= lastThu;
  }

  /// Calculates whether the given UTC time falls within European / UK Summer Time (DST).
  /// EU/UK Directive:
  /// Starts: Last Sunday of March at 01:00 UTC
  /// Ends: Last Sunday of October at 01:00 UTC
  static bool isEuUkSummerTime(DateTime utc) {
    final march31 = DateTime.utc(utc.year, 3, 31);
    final marchOffset = march31.weekday % 7;
    final start = DateTime.utc(utc.year, 3, 31 - marchOffset, 1, 0, 0);

    final oct31 = DateTime.utc(utc.year, 10, 31);
    final octOffset = oct31.weekday % 7;
    final end = DateTime.utc(utc.year, 10, 31 - octOffset, 1, 0, 0);

    return utc.isAfter(start) && utc.isBefore(end);
  }

  /// Calculates whether the given UTC time falls within US Daylight Saving Time (DST).
  /// Energy Policy Act: 2nd Sunday in March to 1st Sunday in November.
  static bool isUsSummerTime(DateTime utc) {
    if (utc.month < 3 || utc.month > 11) return false;
    if (utc.month > 3 && utc.month < 11) return true;
    if (utc.month == 3) {
      final march1 = DateTime.utc(utc.year, 3, 1);
      final daysUntilFirstSunday = (DateTime.sunday - march1.weekday + 7) % 7;
      final secondSunday = 1 + daysUntilFirstSunday + 7;
      final start = DateTime.utc(utc.year, 3, secondSunday, 7, 0, 0);
      return utc.isAfter(start);
    }
    // month == 11
    final nov1 = DateTime.utc(utc.year, 11, 1);
    final daysUntilFirstSunday = (DateTime.sunday - nov1.weekday + 7) % 7;
    final firstSunday = 1 + daysUntilFirstSunday;
    final end = DateTime.utc(utc.year, 11, firstSunday, 6, 0, 0);
    return utc.isBefore(end);
  }

  /// 1. Egypt (Cairo): UTC+3 summer, UTC+2 winter
  static DateTime getEgyptTime([DateTime? baseUtc]) {
    final utc = (baseUtc ?? DateTime.now()).toUtc();
    final offsetHours = isEgyptSummerTime(utc) ? 3 : 2;
    return utc.add(Duration(hours: offsetHours));
  }

  /// 2. France, Italy & Spain (Paris, Rome & Madrid): UTC+2 summer, UTC+1 winter (Central European Time)
  static DateTime getFranceTime([DateTime? baseUtc]) {
    final utc = (baseUtc ?? DateTime.now()).toUtc();
    final offsetHours = isEuUkSummerTime(utc) ? 2 : 1;
    return utc.add(Duration(hours: offsetHours));
  }

  static DateTime getItalyTime([DateTime? baseUtc]) => getFranceTime(baseUtc);
  static DateTime getSpainTime([DateTime? baseUtc]) => getFranceTime(baseUtc);
  static DateTime getFranceItalySpainTime([DateTime? baseUtc]) => getFranceTime(baseUtc);

  /// 3. England / UK (London): UTC+1 summer, UTC+0 winter
  static DateTime getUkTime([DateTime? baseUtc]) {
    final utc = (baseUtc ?? DateTime.now()).toUtc();
    final offsetHours = isEuUkSummerTime(utc) ? 1 : 0;
    return utc.add(Duration(hours: offsetHours));
  }

  /// Turkey (Istanbul / Ankara): UTC+3 fixed year-round (TRT - Turkey Time)
  static DateTime getTurkeyTime([DateTime? baseUtc]) {
    final utc = (baseUtc ?? DateTime.now()).toUtc();
    return utc.add(const Duration(hours: 3));
  }

  /// 4. Lithuania (Vilnius): UTC+3 summer, UTC+2 winter
  static DateTime getLithuaniaTime([DateTime? baseUtc]) {
    final utc = (baseUtc ?? DateTime.now()).toUtc();
    final offsetHours = isEuUkSummerTime(utc) ? 3 : 2;
    return utc.add(Duration(hours: offsetHours));
  }

  /// Combined Turkey & Lithuania (Istanbul & Vilnius):
  /// In summer, both share UTC+3. In winter, Turkey is UTC+3 and Lithuania is UTC+2.
  static DateTime getTurkeyLithuaniaTime([DateTime? baseUtc]) => getTurkeyTime(baseUtc);

  /// 5. China (Beijing / Shanghai): UTC+8 fixed year-round
  static DateTime getChinaTime([DateTime? baseUtc]) {
    final utc = (baseUtc ?? DateTime.now()).toUtc();
    return utc.add(const Duration(hours: 8));
  }

  /// 6. United Arab Emirates (Dubai / Abu Dhabi): UTC+4 fixed year-round
  static DateTime getUaeTime([DateTime? baseUtc]) {
    final utc = (baseUtc ?? DateTime.now()).toUtc();
    return utc.add(const Duration(hours: 4));
  }

  /// 7. United States (New York / Eastern Time): UTC-4 summer, UTC-5 winter
  static DateTime getUsEasternTime([DateTime? baseUtc]) {
    final utc = (baseUtc ?? DateTime.now()).toUtc();
    final offsetHours = isUsSummerTime(utc) ? -4 : -5;
    return utc.add(Duration(hours: offsetHours));
  }

  /// Check if a given country time is within official business working hours:
  /// - For Egypt (مصر): Sunday through Thursday, 08:00 to 17:00 (Friday & Saturday are official weekend holidays).
  /// - For other jurisdictions: Monday through Friday, 08:00 to 17:00 (Saturday & Sunday are weekend holidays).
  static bool isBusinessHours(DateTime time, {String? countryKey}) {
    if (countryKey == 'egypt') {
      // In Egypt: Friday and Saturday are the official weekend holidays
      if (time.weekday == DateTime.friday || time.weekday == DateTime.saturday) {
        return false;
      }
      return time.hour >= 8 && time.hour < 17;
    }
    // Standard international working days: Monday through Friday
    if (time.weekday < DateTime.monday || time.weekday > DateTime.friday) {
      return false;
    }
    return time.hour >= 8 && time.hour < 17;
  }

  /// Returns local time for any standard country key.
  static DateTime getTimeForCountry(String key, [DateTime? baseUtc]) {
    switch (key) {
      case 'egypt':
        return getEgyptTime(baseUtc);
      case 'france_italy_spain':
      case 'france_italy':
      case 'france':
      case 'italy':
      case 'spain':
        return getFranceItalySpainTime(baseUtc);
      case 'uk':
        return getUkTime(baseUtc);
      case 'turkey_lithuania':
      case 'turkey':
        return getTurkeyLithuaniaTime(baseUtc);
      case 'lithuania':
        return getLithuaniaTime(baseUtc);
      case 'china':
        return getChinaTime(baseUtc);
      case 'uae':
        return getUaeTime(baseUtc);
      case 'us':
        return getUsEasternTime(baseUtc);
      default:
        return (baseUtc ?? DateTime.now()).toUtc();
    }
  }

  /// Formats time in 24-hour format: HH:mm (or HH:mm:ss if showSeconds is true).
  /// Seconds are hidden by default to keep the widget compact and save screen space.
  static String formatTime24h(DateTime time, {bool showSeconds = false}) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    if (showSeconds) {
      final s = time.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$h:$m';
  }

  /// Arabic Day of the Week
  static String getArabicDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday: return 'الإثنين';
      case DateTime.tuesday: return 'الثلاثاء';
      case DateTime.wednesday: return 'الأربعاء';
      case DateTime.thursday: return 'الخميس';
      case DateTime.friday: return 'الجمعة';
      case DateTime.saturday: return 'السبت';
      case DateTime.sunday: return 'الأحد';
      default: return '';
    }
  }

  /// English Day of the Week
  static String getEnglishDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday: return 'Monday';
      case DateTime.tuesday: return 'Tuesday';
      case DateTime.wednesday: return 'Wednesday';
      case DateTime.thursday: return 'Thursday';
      case DateTime.friday: return 'Friday';
      case DateTime.saturday: return 'Saturday';
      case DateTime.sunday: return 'Sunday';
      default: return '';
    }
  }

  /// Day of the Week with language setting support
  static String getDayName(DateTime date, {bool isArabic = true}) {
    return isArabic ? getArabicDayName(date) : getEnglishDayName(date);
  }

  /// Country display name localized
  static String getCountryName(String countryKey, {bool isArabic = true}) {
    switch (countryKey) {
      case 'egypt':
        return isArabic ? egyptName : 'Egypt';
      case 'france_italy_spain':
        return isArabic ? franceItalySpainName : 'France, Italy & Spain';
      case 'spain':
        return isArabic ? spainName : 'Spain';
      case 'france':
        return isArabic ? franceName : 'France';
      case 'italy':
        return isArabic ? italyName : 'Italy';
      case 'france_italy':
        return isArabic ? franceItalySpainName : 'France, Italy & Spain';
      case 'uk':
        return isArabic ? ukName : 'UK';
      case 'turkey_lithuania':
        return isArabic ? turkeyLithuaniaName : 'Turkey & Lithuania';
      case 'turkey':
        return isArabic ? turkeyName : 'Turkey';
      case 'lithuania':
        return isArabic ? lithuaniaName : 'Lithuania';
      case 'china':
        return isArabic ? chinaName : 'China';
      case 'uae':
        return isArabic ? uaeName : 'UAE';
      case 'us':
        return isArabic ? usName : 'USA';
      default:
        return '';
    }
  }

  /// Format Date: YYYY-MM-DD
  static String formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Resolves whether Arabic is active based on explicit flag, Directionality, or Locale.
  static bool resolveIsArabic(BuildContext context, [bool? explicit]) {
    if (explicit != null) return explicit;
    final dir = Directionality.maybeOf(context);
    if (dir == TextDirection.rtl) return true;
    final loc = Localizations.maybeLocaleOf(context);
    if (loc?.languageCode == 'ar') return true;
    if (loc?.languageCode == 'en') return false;
    return true; // Default to Arabic in ImportFlow ERP
  }
}

/// Standalone Date & Week Number Badge Widget (سطر التاريخ + رقم الأسبوع لوحده).
/// Automatically respects language settings (Arabic / English).
class SystemDateWeekBadge extends StatelessWidget {
  final DateTime currentTime;
  final bool isDark;
  final bool? isArabic;

  const SystemDateWeekBadge({
    super.key,
    required this.currentTime,
    this.isDark = true,
    this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = WorldTimezoneHelper.resolveIsArabic(context, isArabic);
    final dayName = WorldTimezoneHelper.getDayName(currentTime, isArabic: isAr);
    final dateStr = WorldTimezoneHelper.formatDate(currentTime);
    final weekNum = WorldTimezoneHelper.getIsoWeekNumber(currentTime);
    final weekLabel = isAr ? 'الأسبوع: W$weekNum' : 'Week: W$weekNum';
    final tooltipMsg = isAr
        ? 'التاريخ المعتمد ورقم الأسبوع السنوي للعمليات والشحن (ISO-8601)'
        : 'Official standard date and ISO-8601 annual operational week';

    return Tooltip(
      message: tooltipMsg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: AppTheme.cobalt,
              size: 13.5,
            ),
            const SizedBox(width: 6),
            Text(
              dayName,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.charcoal,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              dateStr,
              style: TextStyle(
                fontFamily: 'monospace',
                color: isDark ? const Color(0xFFE2E8F0) : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 12,
              width: 1,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(width: 8),
            // Week Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.cobalt.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weekLabel,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF64B5F6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone Single Country Clock Chip with flag, country name,
/// 24-hour time, and business hours status dot.
/// - Green (أخضر) if current time is within working hours (08:00 - 17:00)
/// - Red (أحمر) if outside working hours.
/// Respects language settings (Arabic / English).
class WorldClockChip extends StatelessWidget {
  final String? flag;
  final String countryName;
  final String time24h;
  final bool isBusinessHours;
  final String tooltip;
  final bool isPrimary;
  final bool isDark;
  final bool? isArabic;

  const WorldClockChip({
    super.key,
    this.flag,
    required this.countryName,
    required this.time24h,
    required this.isBusinessHours,
    required this.tooltip,
    this.isPrimary = false,
    this.isDark = true,
    this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = WorldTimezoneHelper.resolveIsArabic(context, isArabic);
    final statusColor = isBusinessHours ? AppTheme.emerald : AppTheme.crimson;
    final statusLabel = isBusinessHours
        ? (isAr ? 'مواعيد العمل (08:00 - 17:00)' : 'Business Hours (08:00 - 17:00)')
        : (isAr ? 'خارج مواعيد العمل' : 'Closed (Off Hours)');
    final statusPrefix = isAr ? 'الحالة:' : 'Status:';
    final fullTooltip = '$tooltip\n$statusPrefix $statusLabel';

    return Tooltip(
      message: fullTooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isPrimary
              ? (isBusinessHours
                  ? (isDark ? AppTheme.cobalt.withValues(alpha: 0.22) : const Color(0xFFEBF5FB))
                  : (isDark ? const Color(0xFF2A1C23) : const Color(0xFFFDEDEE)))
              : (isDark
                  ? (isBusinessHours ? const Color(0xFF142B24) : const Color(0xFF2B161B))
                  : (isBusinessHours ? const Color(0xFFEAF8F1) : const Color(0xFFFDEDEE))),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isPrimary
                ? (isDark
                    ? AppTheme.cobalt.withValues(alpha: 0.8)
                    : (isBusinessHours ? AppTheme.cobalt : AppTheme.crimson.withValues(alpha: 0.6)))
                : statusColor.withValues(alpha: isDark ? 0.45 : 0.6),
            width: isPrimary ? 1.0 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Country Localized Name (Flags removed per user requirement: "فى الساعه الغى الاعلام")
            Text(
              countryName,
              style: TextStyle(
                color: isPrimary
                    ? (isDark
                        ? const Color(0xFF90CAF9)
                        : (isBusinessHours ? AppTheme.cobalt : AppTheme.crimson))
                    : (isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800),
                fontSize: countryName.length > 16 ? 9.8 : 10.5,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5.5),
            // 24-hour Digital Time (HH:mm:ss)
            Text(
              time24h,
              style: TextStyle(
                fontFamily: 'monospace',
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 5.5),
            // Business Working Hours Indicator Dot (Green if 8am-5pm, Red if outside)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.75),
                    blurRadius: 3.5,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone Row of the Synchronized World Clocks:
/// 1. Egypt (HQ)
/// 2. France & Italy (Combined)
/// 3. England / UK
/// 4. Lithuania
/// 5. China
/// 6. United Arab Emirates (UAE)
/// 7. United States (USA)
class SystemWorldClocksBar extends StatelessWidget {
  final DateTime currentTimeUtc;
  final bool? isDark;
  final bool? isArabic;
  final bool showSeconds;

  const SystemWorldClocksBar({
    super.key,
    required this.currentTimeUtc,
    this.isDark,
    this.isArabic,
    this.showSeconds = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = isDark ?? AppTheme.isDark(context);
    final isAr = WorldTimezoneHelper.resolveIsArabic(context, isArabic);

    // 1. Egypt (Cairo)
    final egyptTime = WorldTimezoneHelper.getEgyptTime(currentTimeUtc);
    final egyptTz = WorldTimezoneHelper.isEgyptSummerTime(currentTimeUtc) ? 'UTC+3' : 'UTC+2';
    final egyptTooltip = isAr
        ? 'توقيت القاهرة (مقر الشركة) — $egyptTz'
        : 'Cairo Time (Headquarters) — $egyptTz';

    // 2. France, Italy & Spain (Paris, Rome & Madrid) - Combined into one clock
    final franceItalySpainTime = WorldTimezoneHelper.getFranceTime(currentTimeUtc);
    final franceItalySpainTz = WorldTimezoneHelper.isEuUkSummerTime(currentTimeUtc) ? 'UTC+2' : 'UTC+1';
    final franceItalySpainTooltip = isAr
        ? 'توقيت باريس وروما ومدريد (فرنسا وإيطاليا وإسبانيا) — $franceItalySpainTz'
        : 'Paris, Rome & Madrid Time (France, Italy & Spain) — $franceItalySpainTz';

    // 3. England / UK (London)
    final ukTime = WorldTimezoneHelper.getUkTime(currentTimeUtc);
    final ukTz = WorldTimezoneHelper.isEuUkSummerTime(currentTimeUtc) ? 'UTC+1' : 'UTC+0';
    final ukTooltip = isAr
        ? 'توقيت لندن (إنجلترا / المملكة المتحدة) — $ukTz'
        : 'London Time (United Kingdom) — $ukTz';

    // 4. Turkey & Lithuania (Istanbul & Vilnius) - Combined into one clock
    final turkeyLithuaniaTime = WorldTimezoneHelper.getTurkeyLithuaniaTime(currentTimeUtc);
    final isSummerTz = WorldTimezoneHelper.isEuUkSummerTime(currentTimeUtc);
    final turkeyLithuaniaTz = isSummerTz ? 'UTC+3' : 'TR: UTC+3 │ LT: UTC+2';
    final turkeyLithuaniaTooltip = isAr
        ? 'توقيت إسطنبول وفيلنيوس (تركيا وليتوانيا) — $turkeyLithuaniaTz'
        : 'Istanbul & Vilnius Time (Turkey & Lithuania) — $turkeyLithuaniaTz';

    // 5. China (Beijing / Shanghai)
    final chinaTime = WorldTimezoneHelper.getChinaTime(currentTimeUtc);
    const chinaTz = 'UTC+8';
    final chinaTooltip = isAr
        ? 'توقيت بكين وشنغهاي (الصين) — $chinaTz'
        : 'Beijing & Shanghai Time (China) — $chinaTz';

    // 6. United Arab Emirates (Dubai / Abu Dhabi)
    final uaeTime = WorldTimezoneHelper.getUaeTime(currentTimeUtc);
    const uaeTz = 'UTC+4';
    final uaeTooltip = isAr
        ? 'توقيت دبي وأبوظبي (الإمارات العربية المتحدة) — $uaeTz'
        : 'Dubai & Abu Dhabi Time (UAE) — $uaeTz';

    // 7. United States (New York / Eastern Time)
    final usTime = WorldTimezoneHelper.getUsEasternTime(currentTimeUtc);
    final usTz = WorldTimezoneHelper.isUsSummerTime(currentTimeUtc) ? 'UTC-4' : 'UTC-5';
    final usTooltip = isAr
        ? 'توقيت نيويورك والساحل الشرقي (أمريكا) — $usTz'
        : 'New York & Eastern Ports Time (USA) — $usTz';

    final clocks = [
      WorldClockChip(
        countryName: WorldTimezoneHelper.getCountryName('egypt', isArabic: isAr),
        time24h: WorldTimezoneHelper.formatTime24h(egyptTime, showSeconds: showSeconds),
        isBusinessHours: WorldTimezoneHelper.isBusinessHours(egyptTime, countryKey: 'egypt'),
        tooltip: egyptTooltip,
        isPrimary: true,
        isDark: effectiveIsDark,
        isArabic: isAr,
      ),
      WorldClockChip(
        countryName: WorldTimezoneHelper.getCountryName('france_italy_spain', isArabic: isAr),
        time24h: WorldTimezoneHelper.formatTime24h(franceItalySpainTime, showSeconds: showSeconds),
        isBusinessHours: WorldTimezoneHelper.isBusinessHours(franceItalySpainTime),
        tooltip: franceItalySpainTooltip,
        isDark: effectiveIsDark,
        isArabic: isAr,
      ),
      WorldClockChip(
        countryName: WorldTimezoneHelper.getCountryName('uk', isArabic: isAr),
        time24h: WorldTimezoneHelper.formatTime24h(ukTime, showSeconds: showSeconds),
        isBusinessHours: WorldTimezoneHelper.isBusinessHours(ukTime),
        tooltip: ukTooltip,
        isDark: effectiveIsDark,
        isArabic: isAr,
      ),
      WorldClockChip(
        countryName: WorldTimezoneHelper.getCountryName('turkey_lithuania', isArabic: isAr),
        time24h: WorldTimezoneHelper.formatTime24h(turkeyLithuaniaTime, showSeconds: showSeconds),
        isBusinessHours: WorldTimezoneHelper.isBusinessHours(turkeyLithuaniaTime),
        tooltip: turkeyLithuaniaTooltip,
        isDark: effectiveIsDark,
        isArabic: isAr,
      ),
      WorldClockChip(
        countryName: WorldTimezoneHelper.getCountryName('china', isArabic: isAr),
        time24h: WorldTimezoneHelper.formatTime24h(chinaTime, showSeconds: showSeconds),
        isBusinessHours: WorldTimezoneHelper.isBusinessHours(chinaTime),
        tooltip: chinaTooltip,
        isDark: effectiveIsDark,
        isArabic: isAr,
      ),
      WorldClockChip(
        countryName: WorldTimezoneHelper.getCountryName('uae', isArabic: isAr),
        time24h: WorldTimezoneHelper.formatTime24h(uaeTime, showSeconds: showSeconds),
        isBusinessHours: WorldTimezoneHelper.isBusinessHours(uaeTime),
        tooltip: uaeTooltip,
        isDark: effectiveIsDark,
        isArabic: isAr,
      ),
      WorldClockChip(
        countryName: WorldTimezoneHelper.getCountryName('us', isArabic: isAr),
        time24h: WorldTimezoneHelper.formatTime24h(usTime, showSeconds: showSeconds),
        isBusinessHours: WorldTimezoneHelper.isBusinessHours(usTime),
        tooltip: usTooltip,
        isDark: effectiveIsDark,
        isArabic: isAr,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < clocks.length; i++) ...[
            clocks[i],
            if (i < clocks.length - 1) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

/// A smart, compact dropdown button for international world clocks:
/// Shows the default/pinned country (e.g. مصر 15:00 ▾) with live 24h time and working hours status dot.
/// Clicking opens an elegant popover listing all 7 jurisdictions with live auto-updating times,
/// status badges (مفتوح / مغلق), and working hours details.
class WorldClockDropdownButton extends StatefulWidget {
  final DateTime? currentTimeUtc;
  final bool? isDark;
  final bool? isArabic;
  final bool showSeconds;
  final String defaultCountryKey;
  final ValueChanged<String>? onCountryChanged;

  const WorldClockDropdownButton({
    super.key,
    this.currentTimeUtc,
    this.isDark,
    this.isArabic,
    this.showSeconds = false,
    this.defaultCountryKey = 'egypt',
    this.onCountryChanged,
  });

  @override
  State<WorldClockDropdownButton> createState() => _WorldClockDropdownButtonState();
}

class _WorldClockDropdownButtonState extends State<WorldClockDropdownButton> {
  late String _selectedCountryKey;
  Timer? _ticker;
  late DateTime _nowUtc;

  static const List<String> supportedCountryKeys = [
    'egypt',
    'france_italy_spain',
    'uk',
    'turkey_lithuania',
    'china',
    'uae',
    'us',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCountryKey = widget.defaultCountryKey;
    _nowUtc = widget.currentTimeUtc ?? DateTime.now().toUtc();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _nowUtc = widget.currentTimeUtc ?? DateTime.now().toUtc();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant WorldClockDropdownButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTimeUtc != null) {
      _nowUtc = widget.currentTimeUtc!;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = widget.isDark ?? AppTheme.isDark(context);
    final isAr = WorldTimezoneHelper.resolveIsArabic(context, widget.isArabic);

    final activeTime = WorldTimezoneHelper.getTimeForCountry(_selectedCountryKey, _nowUtc);
    final isBusiness = WorldTimezoneHelper.isBusinessHours(activeTime, countryKey: _selectedCountryKey);
    final activeCountryName = WorldTimezoneHelper.getCountryName(_selectedCountryKey, isArabic: isAr);
    final activeTimeStr = WorldTimezoneHelper.formatTime24h(activeTime, showSeconds: widget.showSeconds);
    final statusColor = isBusiness ? AppTheme.emerald : AppTheme.crimson;

    final openLabel = isAr ? 'مفتوح' : 'Open';
    final closedLabel = isAr ? 'مغلق' : 'Closed';
    final hoursSub = isAr ? 'مواعيد العمل (08:00 - 17:00)' : 'Business Hours (08:00 - 17:00)';

    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: effectiveIsDark ? const Color(0xFF1E2631) : Colors.white,
      ),
      child: PopupMenuButton<String>(
        position: PopupMenuPosition.under,
        elevation: 6,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: effectiveIsDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 0.8,
          ),
        ),
        color: effectiveIsDark ? const Color(0xFF1E2631) : Colors.white,
        tooltip: isAr ? 'ساعات الدول ومواعيد العمل الدولية' : 'World Clocks & Business Hours',
        onSelected: (key) {
          setState(() => _selectedCountryKey = key);
          widget.onCountryChanged?.call(key);
        },
        itemBuilder: (context) {
          return [
            // Header Item
            PopupMenuItem<String>(
              enabled: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.public, size: 16, color: AppTheme.cobalt),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isAr ? 'التوقيت الدولي وساعات العمل' : 'World Clocks & Working Hours',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: effectiveIsDark ? Colors.white : AppTheme.charcoal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: const Text(
                          '24H LIVE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.emerald)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          hoursSub,
                          style: TextStyle(fontSize: 10, color: effectiveIsDark ? Colors.white60 : Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.crimson)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          closedLabel,
                          style: TextStyle(fontSize: 10, color: effectiveIsDark ? Colors.white60 : Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: effectiveIsDark ? Colors.white12 : Colors.black12),
                ],
              ),
            ),
            // Country Items
            ...supportedCountryKeys.map((key) {
              final cTime = WorldTimezoneHelper.getTimeForCountry(key, _nowUtc);
              final cIsBusiness = WorldTimezoneHelper.isBusinessHours(cTime, countryKey: key);
              final cName = WorldTimezoneHelper.getCountryName(key, isArabic: isAr);
              final cTimeStr = WorldTimezoneHelper.formatTime24h(cTime, showSeconds: widget.showSeconds);
              final isPinned = key == _selectedCountryKey;

              return PopupMenuItem<String>(
                value: key,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isPinned
                        ? (effectiveIsDark ? AppTheme.cobalt.withValues(alpha: 0.12) : const Color(0xFFEFF6FF))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPinned ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 14,
                        color: isPinned ? AppTheme.cobalt : (effectiveIsDark ? Colors.white30 : Colors.black26),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isPinned ? FontWeight.bold : FontWeight.w500,
                            color: isPinned
                                ? (effectiveIsDark ? const Color(0xFF90CAF9) : AppTheme.cobalt)
                                : (effectiveIsDark ? Colors.white70 : AppTheme.charcoal),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        cTimeStr,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: effectiveIsDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (cIsBusiness ? AppTheme.emerald : AppTheme.crimson).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: (cIsBusiness ? AppTheme.emerald : AppTheme.crimson).withValues(alpha: 0.4),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cIsBusiness ? AppTheme.emerald : AppTheme.crimson,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              cIsBusiness ? openLabel : closedLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: cIsBusiness ? AppTheme.emerald : AppTheme.crimson,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ];
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: effectiveIsDark ? const Color(0xFF1E2631) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: effectiveIsDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 13, color: AppTheme.cobalt),
              const SizedBox(width: 4),
              Text(
                '$activeCountryName $activeTimeStr',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: effectiveIsDark ? Colors.grey.shade300 : AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 5.5,
                height: 5.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.5),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: effectiveIsDark ? Colors.white60 : Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comprehensive 2-Tier Master Header Bar (أعلى كل شاشة من شاشات السيستم):
/// - Tier 1: سطر التاريخ + رقم الأسبوع لوحده
/// - Tier 2: شريط الساعات المتزامنة بنظام 24 ساعة مع تمييز مواعيد العمل (أخضر / أحمر)
/// Automatically respects language settings (Arabic / English).
/// Supports singleRow mode for unified compact density top bars.
class SystemWorldClocksHeader extends StatefulWidget {
  final bool? isDark;
  final bool? isArabic;
  final bool showSeconds;
  final bool singleRow;
  final Widget? leading;

  const SystemWorldClocksHeader({
    super.key,
    this.isDark,
    this.isArabic,
    this.showSeconds = false,
    this.singleRow = false,
    this.leading,
  });

  @override
  State<SystemWorldClocksHeader> createState() => _SystemWorldClocksHeaderState();
}

class _SystemWorldClocksHeaderState extends State<SystemWorldClocksHeader> {
  late DateTime _nowUtc;
  late DateTime _localNow;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _nowUtc = DateTime.now().toUtc();
    _localNow = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _nowUtc = DateTime.now().toUtc();
          _localNow = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = widget.isDark ?? AppTheme.isDark(context);
    final isAr = WorldTimezoneHelper.resolveIsArabic(context, widget.isArabic);
    final bgColor = effectiveIsDark ? (AppTheme.isDark(context) ? const Color(0xFF1E2631) : AppTheme.charcoal) : const Color(0xFFF8FAFC);
    final borderColor = effectiveIsDark ? const Color(0xFF334155) : Colors.grey.shade300;

    final beaconTooltip = isAr
        ? 'أخضر = مواعيد العمل (08:00 - 17:00) │ أحمر = مغلق │ الساعات بنظام 24 ساعة'
        : 'Green = Business Hours (08:00 - 17:00) │ Red = Closed │ 24-Hour Live Format';

    final openLabel = isAr ? 'مفتوح' : 'Open';
    final closedLabel = isAr ? 'مغلق' : 'Closed';
    final legendTooltip = isAr
        ? 'أخضر = ساعات العمل (08:00 - 17:00) │ أحمر = خارج ساعات العمل'
        : 'Green = Business Hours (08:00 - 17:00) │ Red = Closed / Off Hours';

    if (widget.singleRow) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1.0),
          ),
        ),
        child: Row(
          children: [
            widget.leading ??
                SystemDateWeekBadge(
                  currentTime: _localNow,
                  isDark: effectiveIsDark,
                  isArabic: isAr,
                ),
            const SizedBox(width: 8),
            Container(
              height: 18,
              width: 1,
              color: effectiveIsDark ? Colors.white12 : Colors.black12,
            ),
            const SizedBox(width: 8),
            // World clock smart dropdown button
            WorldClockDropdownButton(
              currentTimeUtc: _nowUtc,
              isDark: effectiveIsDark,
              isArabic: isAr,
              showSeconds: widget.showSeconds,
            ),
            const SizedBox(width: 8),
            Container(
              height: 18,
              width: 1,
              color: effectiveIsDark ? Colors.white12 : Colors.black12,
            ),
            const SizedBox(width: 8),
            // Quick action shortcuts toolbar
            const Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                child: GlobalHeaderShortcutsBar(),
              ),
            ),
            const SizedBox(width: 8),
            // Live sync beacon indicator
            Tooltip(
              message: beaconTooltip,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.emerald,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.emerald.withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '24H LIVE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: effectiveIsDark ? Colors.white38 : Colors.black38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: System Date/Week Badge + Quick Action Shortcuts + Business Hours Status & Beacon
          Row(
            children: [
              // Date & Week Number Badge
              SystemDateWeekBadge(
                currentTime: _localNow,
                isDark: effectiveIsDark,
                isArabic: isAr,
              ),
              const SizedBox(width: 8),
              Container(
                height: 18,
                width: 1,
                color: effectiveIsDark ? Colors.white12 : Colors.black12,
              ),
              const SizedBox(width: 8),
              // Quick action shortcuts toolbar
              const Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: BouncingScrollPhysics(),
                  child: GlobalHeaderShortcutsBar(),
                ),
              ),
              const SizedBox(width: 8),
              // Working hours legend & Live sync beacon
              Tooltip(
                message: legendTooltip,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.emerald,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      openLabel,
                      style: TextStyle(
                        color: effectiveIsDark ? Colors.white70 : Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.crimson,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      closedLabel,
                      style: TextStyle(
                        color: effectiveIsDark ? Colors.white54 : Colors.black54,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Live sync beacon indicator
              Tooltip(
                message: beaconTooltip,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.emerald,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '24H LIVE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: effectiveIsDark ? Colors.white38 : Colors.black38,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 3),
          // Row 2: Synchronized World Clocks
          SystemWorldClocksBar(
            currentTimeUtc: _nowUtc,
            isDark: effectiveIsDark,
            isArabic: isAr,
            showSeconds: widget.showSeconds,
          ),
        ],
      ),
    );
  }
}

/// Legacy SystemLiveClockWidget maintained for backward compatibility.
class SystemLiveClockWidget extends StatelessWidget {
  final bool isDark;
  final bool? isArabic;
  final VoidCallback? onTap;

  const SystemLiveClockWidget({
    super.key,
    this.isDark = true,
    this.isArabic,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SystemWorldClocksHeader(isDark: isDark, isArabic: isArabic);
  }
}


