import 'dart:convert';

import '../../services/display_name_resolver.dart';
import '../app_localizations.dart';
import '../domain_enum_labels.dart';
import 'system_message_catalog_ar.dart';
import 'system_message_catalog_en.dart';
import '../../utils/bidi_text.dart';

/// Parts a system message can have (see docs/system_message_codes.json).
class SystemMessagePart {
  SystemMessagePart._();

  static const title = 'title';
  static const body = 'body';
  static const note = 'note';
  static const action = 'action';
  static const stage = 'stage';
  static const module = 'module';
  static const evidence = 'evidence';
  static const reason = 'reason';
}

/// Renders a backend system message (`msg_code` + `msg_params`) in the user's
/// language (docs/plans/single-language-storage-plan.md, tier T1).
///
/// The stored text column is always passed as `fallback`: it is shown when the
/// code is null (legacy rows, user-written tasks), unknown to this build (newer
/// backend), the part has no template, or a param the template needs is missing.
///
/// Params are formatted by their name:
/// - `step_code` / `*_step_code`  -> step name ([DisplayNameResolver.resolveStepName])
/// - `phase_id` / `*_phase_id`    -> phase title ([phaseTitles], the backend's 6 phases)
/// - `month` (1-12)               -> month name
/// - `*_date` (ISO)               -> `29 Sep 2026` / `29 سبتمبر 2026`
/// - [numberNames] / [numberSuffixes] -> grouped number (Western digits)
/// - `*_enum_<type>`              -> T3 label ([DomainEnums.label]); comma-separated lists allowed
/// - anything else                -> verbatim; in Arabic, Latin/digit values are
///   wrapped in an LTR isolate so codes like `IMP-2026-001` keep their order.
class SystemMessageRenderer {
  SystemMessageRenderer._();

  static const Map<String, Map<String, Map<String, String>>> _catalogs = {
    'en': systemMessageCatalogEn,
    'ar': systemMessageCatalogAr,
  };

  static final RegExp _placeholder = RegExp(r'\{([a-z_][a-z0-9_]*)\}');
  static final RegExp _arabicLetter = RegExp('[\u0600-\u06FF]');
  static final RegExp _ltrContent = RegExp('[A-Za-z0-9]');

  /// Left-to-right isolate / pop directional isolate.
  static const lri = '\u2066';
  static const pdi = '\u2069';

  /// The rendered [part] of [code], or [fallback] when it cannot be rendered.
  static String render({
    required String? code,
    required Map<String, dynamic>? params,
    required String part,
    required AppLocalizations l10n,
    required String fallback,
  }) =>
      tryRender(code: code, params: params, part: part, l10n: l10n) ?? fallback;

  /// The rendered [part] of [code], or `null` when it cannot be rendered.
  /// Use it when the fallback needs extra cleanup (e.g. `cleanTaskTitle`).
  static String? tryRender({
    required String? code,
    required Map<String, dynamic>? params,
    required String part,
    required AppLocalizations l10n,
  }) {
    if (code == null || code.isEmpty) return null;
    final template = templateOf(code, part, isArabic: l10n.isArabic);
    if (template == null) return null;
    final values = params ?? const <String, dynamic>{};
    var missing = false;
    final text = template.replaceAllMapped(_placeholder, (m) {
      final name = m.group(1)!;
      final value = values[name];
      if (value == null) {
        missing = true;
        return m.group(0)!;
      }
      return formatParam(name, value, l10n);
    });
    return missing ? null : text;
  }

  /// Whether this build has a template for [code] / [part].
  static bool hasTemplate(String? code, String part) =>
      code != null && systemMessageCatalogEn[code]?[part] != null;

  /// The raw template of [code] / [part] in the requested language.
  static String? templateOf(String code, String part, {required bool isArabic}) =>
      _catalogs[isArabic ? 'ar' : 'en']![code]?[part];

  /// Reads `msg_params` from an API payload: a JSON object, a JSON string or null.
  static Map<String, dynamic>? parseParams(Object? raw) {
    if (raw == null) return null;
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// Reads a nullable code (`msg_code`, `step_code`, ...) from an API payload.
  static String? parseCode(Object? raw) {
    final s = raw?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  // ── Param formatting ────────────────────────────────────────────────────────

  /// Formats one param value by the suffix convention of its [name].
  static String formatParam(String name, Object value, AppLocalizations l10n) {
    final isArabic = l10n.isArabic;
    final enumIndex = name.indexOf('_enum_');
    if (enumIndex >= 0) {
      return _isolate(_enumLabel(name.substring(enumIndex + 6), value.toString(), l10n), isArabic);
    }
    if (name == 'step_code' || name.endsWith('_step_code')) {
      return _isolate(DisplayNameResolver.resolveStepName(value.toString(), isArabic: isArabic), isArabic);
    }
    if (name == 'phase_id' || name.endsWith('_phase_id')) {
      final id = value is num ? value.toInt() : int.tryParse(value.toString().trim());
      final title = id == null ? null : phaseTitle(id, isArabic: isArabic);
      return _isolate(title ?? value.toString(), isArabic);
    }
    if (name == 'month') {
      final m = value is num ? value.toInt() : int.tryParse(value.toString().trim());
      if (m != null && m >= 1 && m <= 12) return monthName(m, isArabic: isArabic);
      return _isolate(value.toString(), isArabic);
    }
    if (name.endsWith('_date')) {
      return _isolate(formatDate(value.toString(), isArabic: isArabic), isArabic);
    }
    if (_isNumberParam(name)) {
      final n = value is num ? value : num.tryParse(value.toString().trim());
      return _isolate(n == null ? value.toString() : formatNumber(n), isArabic);
    }
    return _isolate(value.toString(), isArabic);
  }

  /// `_param_rules` of docs/system_message_codes.json.
  static const List<String> numberNames = ['count', 'hours', 'days_left'];
  static const List<String> numberSuffixes = [
    '_amount', '_pct', '_count', '_days', '_qty', '_gb', '_factor', '_rate', '_num',
  ];

  static bool _isNumberParam(String name) =>
      numberNames.contains(name) || numberSuffixes.any(name.endsWith);

  /// Lifecycle phase titles by `phase_id` (`_phases` of docs/system_message_codes.json
  /// for English; the Arabic titles are the backend PHASES_DEFINITION `title_ar`).
  static const Map<int, List<String>> phaseTitles = {
    1: ['1. Pre-Planning & Studies', 'المرحلة الأولى: التخطيط والدراسات المسبقة'],
    2: ['2. Shipment Initiation', 'المرحلة الثانية: بداية الشحنة'],
    3: ['3. Booking & Doc Prep', 'المرحلة الثالثة: حجز الشحن والتدقيق المستندي المبدئي'],
    4: ['4. Digital & Banking', 'المرحلة الرابعة: التوثيق الرقمي والاعتماد البنكي'],
    5: ['5. Port Operations & Clearance', 'المرحلة الخامسة: عمليات الميناء والتخليص الجمركي'],
    6: ['6. Inbound & Final Closure', 'المرحلة السادسة: الاستلام المخزني والتسوية المالية'],
  };

  /// The title of lifecycle phase [id], or null for an unknown id.
  static String? phaseTitle(int id, {required bool isArabic}) => phaseTitles[id]?[isArabic ? 1 : 0];

  /// Grouped number with at most two decimals and no trailing zeros; Western
  /// digits in both languages (the app never uses Arabic-Indic digits).
  static String formatNumber(num value) {
    if (!value.isFinite) return value.toString();
    final negative = value < 0;
    final rounded = (value.abs() * 100).round();
    final whole = rounded ~/ 100;
    final cents = rounded % 100;
    final digits = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    var text = buf.toString();
    if (cents != 0) {
      var frac = cents.toString().padLeft(2, '0');
      if (frac.endsWith('0')) frac = frac.substring(0, 1);
      text = '$text.$frac';
    }
    return negative ? '-$text' : text;
  }

  static const List<String> _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _monthsAr = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String monthName(int month, {required bool isArabic}) =>
      (isArabic ? _monthsAr : _monthsEn)[month - 1];

  /// `2026-09-29` -> `29 Sep 2026` (en) / `29 سبتمبر 2026` (ar). Unparseable
  /// values are returned as sent.
  static String formatDate(String iso, {required bool isArabic}) {
    final date = DateTime.tryParse(iso.trim());
    if (date == null) return iso;
    final month = isArabic ? _monthsAr[date.month - 1] : _monthsEn[date.month - 1].substring(0, 3);
    return '${date.day} $month ${date.year}';
  }

  /// Backend enum type (lower snake of docs/enum_codes.json keys) -> Flutter type.
  static const Map<String, String> _enumTypes = {
    'release_type': DomainEnumType.releaseType,
    'payment_method': DomainEnumType.paymentMethod,
    'duty_bank': DomainEnumType.dutyBank,
    'clearance_expense_category': DomainEnumType.clearanceExpenseCategory,
    'truck_type': DomainEnumType.truckType,
    'regulatory_body': DomainEnumType.regulatoryBody,
    'clearance_quote_service_category': DomainEnumType.clearanceServiceCategory,
    'broker_expense_category': DomainEnumType.brokerExpenseCategory,
    'pricing_unit': DomainEnumType.brokerUnit,
    'empty_container_depot': DomainEnumType.depot,
    'skip_reason_category': DomainEnumType.skipReasonCategory,
    'hold_reason': DomainEnumType.holdReason,
    'inspection_yard': DomainEnumType.inspectionYard,
    'customs_channel': DomainEnumType.customsChannel,
    'inspection_result': DomainEnumType.inspectionResult,
    'requirement_status': DomainEnumType.requirementStatus,
    'warehouse_inspection_verdict': DomainEnumType.warehouseInspectionVerdict,
    'db_health_verdict': DomainEnumType.dbHealthVerdict,
    'alert_severity': DomainEnumType.alertSeverity,
    'landed_cost_variance_status': DomainEnumType.landedCostVarianceStatus,
  };

  /// PHASE_FOLLOW_UP_TASK labels: only used inside system messages, so they
  /// live here instead of the dropdown enum labels.
  static const Map<String, List<String>> _phaseFollowUpTask = {
    'FREIGHT_SCENARIO_FOLLOW_UP': [
      'Follow up freight studies, scenarios and line availability',
      'متابعة دراسة وسيناريوهات النولون وشغور الخطوط',
    ],
    'PAYMENT_BUDGET_FOLLOW_UP': [
      'Follow up the financial approval and the payment release',
      'متابعة الاعتماد والموافقة المالية وصرف الدفعة',
    ],
    'NAFEZA_ACID_FOLLOW_UP': [
      'Follow up the Nafeza registration and the ACID number',
      'متابعة تسجيل نافذة والحصول على رقم ACID',
    ],
    'BOOKING_BL_FOLLOW_UP': [
      'Follow up the booking, container stuffing and B/L confirmation',
      'متابعة حجز الشحن وتأكيد رص الحاويات وتأكيد البوليصة',
    ],
    'CARGOX_DOCUMENT_TRANSFER': [
      'Receive the commercial invoice and transfer documents via CargoX',
      'استلام الفاتورة التجارية ونقل المستندات عبر CargoX',
    ],
    'ARRIVAL_NOTICE_DECLARATION_46': [
      'Follow up the arrival notice and register declaration 46',
      'متابعة وصول إشعار الوصول وتسجيل إقرار 46 جمارك',
    ],
    'BROKER_RELEASE_FOLLOW_UP': [
      "Execute the broker's notes and obtain the final release",
      'تنفيذ ملاحظات المخلص الجمركي واستخراج إذن الإفراج النهائي',
    ],
    'WAREHOUSE_GRN_REVIEW': [
      'Review cargo integrity, warehouse receiving and the GRN',
      'مراجعة سلامة البضاعة واستلام المخازن وتوليد إذن الإضافة GRN',
    ],
    'LANDED_COST_SETTLEMENT': [
      'Settle the landed cost engine and allocate expenses',
      'تسوية تكلفة الوصول الكلية وتوزيع المصاريف',
    ],
    'ARCHIVE_REVIEW': [
      'Review archiving conditions and close the historical file',
      'مراجعة شروط الأرشفة وإغلاق الملف التاريخي',
    ],
  };

  /// One label, or a comma-separated list of codes (`enum_list_separator`).
  static String _enumLabel(String backendType, String value, AppLocalizations l10n) {
    if (!value.contains(',')) return _enumItemLabel(backendType, value, l10n);
    final items = value.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty);
    return items.map((v) => _enumItemLabel(backendType, v, l10n)).join(l10n.isArabic ? '، ' : ', ');
  }

  static String _enumItemLabel(String backendType, String value, AppLocalizations l10n) {
    if (backendType == 'phase_follow_up_task') {
      final labels = _phaseFollowUpTask[value.trim().toUpperCase()];
      return labels == null ? value : labels[l10n.isArabic ? 1 : 0];
    }
    final type = _enumTypes[backendType];
    if (type == null) return value;
    return DomainEnums.label(l10n, type, value, fallback: value);
  }

  static String _isolate(String text, bool isArabic) {
    if (!isArabic || text.isEmpty) return text;
    if (_arabicLetter.hasMatch(text) || !_ltrContent.hasMatch(text)) return text;
    return '$lri$text$pdi';
  }

  /// Removes the LTR isolates (for exports, clipboard or tests).
  static String stripIsolates(String text) => stripBidiIsolates(text);
}
