/// Unified display formatting for numbers, money, percentages and dates.
///
/// Single source of truth for the ad-hoc `_formatNumber` / `_formatDate` /
/// `toStringAsFixed` + regex helpers scattered across the UI and exports.
///
/// Conventions (match the existing exports and system messages):
/// - Western digits in both languages (the app never uses Arabic-Indic digits).
/// - `,` thousands separator, `.` decimal separator.
/// - ISO dates `yyyy-MM-dd` and `yyyy-MM-dd HH:mm` (unambiguous in AR and EN).
/// - `null`, empty, `'null'` and unparsable input render as [AppFormat.empty].
///
/// Pure Dart (no `intl` dependency) so it is usable in models, services,
/// exports and widgets alike.
abstract final class AppFormat {
  /// Placeholder rendered for missing values.
  static const String empty = '-';

  /// Grouped number rounded to [decimals] places (half away from zero).
  ///
  /// With [trimZeros] trailing fractional zeros are dropped
  /// (`1,234.50` -> `1,234.5`, `1,000.00` -> `1,000`).
  /// Non-finite values (NaN / Infinity) are returned via `toString()`.
  static String number(
    num? value, {
    int decimals = 2,
    bool trimZeros = false,
    String fallback = empty,
  }) {
    assert(decimals >= 0 && decimals <= 10, 'decimals must be in 0..10');
    if (value == null) return fallback;
    if (!value.isFinite) return value.toString();

    final int scale = _pow10(decimals);
    final int scaled = (value.abs() * scale).round();
    final int whole = scaled ~/ scale;
    final int fraction = scaled % scale;

    final String grouped = _groupThousands(whole.toString());
    String text = grouped;
    if (decimals > 0) {
      String frac = fraction.toString().padLeft(decimals, '0');
      if (trimZeros) frac = frac.replaceFirst(RegExp(r'0+$'), '');
      if (frac.isNotEmpty) text = '$grouped.$frac';
    }
    final bool negative = value < 0 && scaled != 0;
    return negative ? '-$text' : text;
  }

  /// Grouped integer (`12,500`).
  static String integer(num? value, {String fallback = empty}) =>
      number(value, decimals: 0, fallback: fallback);

  /// Monetary amount with fixed [decimals] and optional ISO [currency] suffix
  /// (`1,234.50 USD`). The currency follows the amount so mixed AR/EN rows
  /// stay aligned in tables.
  static String money(
    num? value, {
    String? currency,
    int decimals = 2,
    String fallback = empty,
  }) {
    if (value == null) return fallback;
    final String amount = number(value, decimals: decimals);
    final String code = currency?.trim() ?? '';
    return code.isEmpty ? amount : '$amount $code';
  }

  /// Percentage from a value already expressed in percent (`14` -> `14%`).
  static String percent(
    num? value, {
    int decimals = 2,
    String fallback = empty,
  }) {
    if (value == null) return fallback;
    return '${number(value, decimals: decimals, trimZeros: true)}%';
  }

  /// Parses `DateTime` / ISO string input; `null` when it is not a date.
  static DateTime? parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final String text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == empty) return null;
    return DateTime.tryParse(text);
  }

  /// `yyyy-MM-dd`. Unparsable non-empty strings are returned unchanged (after
  /// trimming) so legacy free-text dates are never lost on screen or export.
  static String date(Object? value, {String fallback = empty}) {
    final DateTime? parsed = parseDate(value);
    if (parsed != null) return _ymd(parsed);
    return _rawOrFallback(value, fallback);
  }

  /// `yyyy-MM-dd HH:mm` (24h). Unparsable input behaves like [date].
  static String dateTime(Object? value, {String fallback = empty}) {
    final DateTime? parsed = parseDate(value);
    if (parsed != null) return '${_ymd(parsed)} ${_two(parsed.hour)}:${_two(parsed.minute)}';
    return _rawOrFallback(value, fallback);
  }

  // ── internals ────────────────────────────────────────────────────────────

  static String _rawOrFallback(Object? value, String fallback) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == empty) return fallback;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text)) return text.substring(0, 10);
    return text;
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static int _pow10(int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  static String _groupThousands(String digits) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
