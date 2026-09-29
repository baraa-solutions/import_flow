import '../app_localizations.dart';
import '../domain_enum_labels.dart';
import '../stored_text.dart';
import '../../utils/bidi_text.dart';
import 'system_message_renderer.dart';

/// Renders the text and values of backend comparison items (document review
/// matrices, reconciliation headers) in the user's language.
///
/// Storage shape (docs/plans/single-language-storage-plan.md):
/// - a text field `X` keeps its English render and gets siblings `X_code` +
///   `X_params` (a system message, part `note`); legacy rows hold Arabic `X`
///   and no code, so the stored text is shown as is;
/// - a value field `V` may be described by `structured_values[V]`:
///   `{"placeholder": VALUE_PLACEHOLDER code}`, `{"number": n, "unit": MEASURE_UNIT code}`
///   or `{"number": null, "raw": text, "unit": ...}`; the stored `V` (English) is the fallback.
class CodedItemText {
  CodedItemText._();

  static const structuredKey = 'structured_values';

  /// Text field [field] of [item]: the `<field>_code` message rendered in the
  /// language of [l10n], else the stored text.
  static String text(
    Map<dynamic, dynamic> item,
    String field,
    AppLocalizations l10n, {
    String part = SystemMessagePart.note,
  }) {
    final stored = item[field]?.toString() ?? '';
    return SystemMessageRenderer.render(
      code: SystemMessageRenderer.parseCode(item['${field}_code']),
      params: SystemMessageRenderer.parseParams(item['${field}_params']),
      part: part,
      l10n: l10n,
      fallback: stored,
    );
  }

  /// Value field [field] of [item]: its structured description rendered in the
  /// language of [l10n], else the stored value (`null` -> [fallback]).
  static String value(
    Map<dynamic, dynamic> item,
    String field,
    AppLocalizations l10n, {
    String fallback = '',
  }) {
    final structured = item[structuredKey];
    if (structured is Map) {
      final rendered = structuredValue(structured[field], l10n);
      if (rendered != null) return rendered;
    }
    final stored = item[field];
    return stored == null ? fallback : stored.toString();
  }

  /// Renders one `structured_values` entry; `null` when it is not a known shape.
  static String? structuredValue(Object? spec, AppLocalizations l10n) {
    if (spec is! Map) return null;
    final placeholder = spec['placeholder']?.toString();
    if (placeholder != null && placeholder.isNotEmpty) {
      return DomainEnums.label(l10n, DomainEnumType.valuePlaceholder, placeholder, fallback: placeholder);
    }
    final unit = spec['unit']?.toString();
    if (unit == null || unit.isEmpty) return null;
    final unitLabel = DomainEnums.label(l10n, DomainEnumType.measureUnit, unit, fallback: unit);
    final raw = spec['number'];
    final number = raw is num ? raw : num.tryParse(raw?.toString().trim() ?? '');
    if (number == null) {
      final rawText = spec['raw']?.toString();
      if (rawText == null || rawText.isEmpty) return null;
      return '$rawText $unitLabel';
    }
    return '${formatMeasure(number, unit)} $unitLabel';
  }

  /// `1,234.50` for kg / CBM, `1,234` for package counts (the backend English
  /// render uses the same shapes).
  static String formatMeasure(num number, String unit) {
    final counted = unit == 'PACKAGES' || unit == 'PACKAGES_PALLETS';
    return formatGrouped(number, counted && number == number.roundToDouble() ? 0 : 2);
  }

  /// [number] with thousands separators and exactly [decimals] decimals.
  static String formatGrouped(num number, int decimals) {
    final fixed = number.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final digits = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    final sign = number < 0 ? '-' : '';
    return parts.length > 1 ? '$sign$buf.${parts[1]}' : '$sign$buf';
  }

  /// A copy of [item] with every coded text field and structured value replaced
  /// by its rendering in the language of [l10n]. Display code reads the copy;
  /// the original stays untouched for saving. [forExport] strips bidi isolates
  /// (clipboard, CSV/TSV, files).
  static Map<String, dynamic> localizeRow(
    Map<dynamic, dynamic> item,
    AppLocalizations l10n, {
    bool forExport = false,
  }) {
    final row = <String, dynamic>{for (final e in item.entries) e.key.toString(): e.value};
    String finish(String v) => forExport ? stripBidiIsolates(v) : v;

    final structured = item[structuredKey];
    if (structured is Map) {
      for (final key in structured.keys) {
        final rendered = structuredValue(structured[key], l10n);
        if (rendered != null) row[key.toString()] = finish(rendered);
      }
    }
    for (final key in item.keys.map((k) => k.toString()).toList()) {
      if (!key.endsWith('_code')) continue;
      final field = key.substring(0, key.length - 5);
      if (!item.containsKey('${field}_params')) continue;
      final code = SystemMessageRenderer.parseCode(item[key]);
      if (code == null || !SystemMessageRenderer.hasTemplate(code, SystemMessagePart.note)) continue;
      row[field] = finish(text(item, field, l10n));
    }
    return row;
  }

  /// [localizeRow] for a list of rows; entries that are not maps are kept as is.
  static List<dynamic> localizeRows(
    Iterable<dynamic>? rows,
    AppLocalizations l10n, {
    bool forExport = false,
  }) =>
      [
        for (final r in rows ?? const <dynamic>[])
          r is Map ? localizeRow(r, l10n, forExport: forExport) : r,
      ];

  // ── Writer side (client-built items, e.g. the offline reconciliation) ─────
  // Mirrors modules/common/system_messages.py `coded_text` and
  // modules/common/enum_codes.py `finalize_structured_values`.

  /// `{field: English render, field_code: code, field_params: params}`.
  static Map<String, dynamic> coded(String field, String code, [Map<String, Object?> params = const {}]) {
    final safe = <String, dynamic>{
      for (final e in params.entries)
        e.key: (e.value == null || e.value is String || e.value is num || e.value is bool) ? e.value : '${e.value}',
    };
    return {
      field: SystemMessageRenderer.render(
        code: code,
        params: safe,
        part: SystemMessagePart.note,
        l10n: storedText,
        fallback: code,
      ),
      '${field}_code': code,
      '${field}_params': safe,
    };
  }

  /// Replaces [CodedPlaceholder] / [CodedMeasure] values of [item] by their
  /// English text and records the structure under `structured_values`.
  static Map<String, dynamic> finalize(Map<String, dynamic> item) {
    final structured = <String, dynamic>{
      if (item[structuredKey] is Map) ...(item[structuredKey] as Map).map((k, v) => MapEntry(k.toString(), v)),
    };
    for (final key in item.keys.toList()) {
      final value = item[key];
      if (value is CodedPlaceholder) {
        item[key] = DomainEnums.label(storedText, DomainEnumType.valuePlaceholder, value.code, fallback: value.code);
        structured[key] = {'placeholder': value.code};
      } else if (value is CodedMeasure) {
        final unit = DomainEnums.label(storedText, DomainEnumType.measureUnit, value.unit, fallback: value.unit);
        final decimals = value.decimals;
        final number = value.number;
        if (decimals == null) {
          item[key] = '${formatMeasure(number, value.unit)} $unit';
          structured[key] = {'number': number == number.roundToDouble() ? number.toInt() : number, 'unit': value.unit};
        } else {
          item[key] = '${formatGrouped(number, decimals)} $unit';
          structured[key] = {'number': double.parse(number.toStringAsFixed(decimals)), 'unit': value.unit};
        }
      }
    }
    if (structured.isNotEmpty) item[structuredKey] = structured;
    return item;
  }
}

/// A VALUE_PLACEHOLDER code standing where a comparison item has no value.
class CodedPlaceholder {
  const CodedPlaceholder(this.code);
  final String code;
}

/// A number with a MEASURE_UNIT code (`decimals: null` keeps whole numbers whole).
class CodedMeasure {
  const CodedMeasure(this.number, this.unit, {this.decimals = 2});
  final num number;
  final String unit;
  final int? decimals;
}
