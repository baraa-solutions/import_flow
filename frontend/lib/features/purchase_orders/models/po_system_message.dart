import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/system_messages/system_message_renderer.dart';

/// A coded backend message `{code, params, severity}` (see docs/system_message_codes.json).
/// The text is rendered from the code in the user's language.
class POSystemMessage {
  const POSystemMessage({required this.code, this.params = const {}, this.severity = 'warning'});

  static const overShipped = 'OVER_SHIPPED';

  final String code;
  final Map<String, dynamic> params;

  /// `error` or `warning`.
  final String severity;

  bool get isError => severity == 'error';

  factory POSystemMessage.fromJson(Map<String, dynamic> json) => POSystemMessage(
        code: (json['code'] ?? '').toString(),
        params: json['params'] is Map ? Map<String, dynamic>.from(json['params'] as Map) : const {},
        severity: (json['severity'] ?? 'warning').toString(),
      );

  /// Tolerant list parse: null / non-list / malformed entries are skipped.
  static List<POSystemMessage> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map && e['code'] != null) POSystemMessage.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// Rendered text, or [fallback] (e.g. the backend's English text) when the code is unknown to this build.
  String text(AppLocalizations l10n, {String fallback = ''}) => SystemMessageRenderer.render(
        code: code,
        params: params,
        part: SystemMessagePart.note,
        l10n: l10n,
        fallback: fallback,
      );
}

/// Response of `POST /purchase-orders/{id}/allocations`.
class POAllocationResult {
  const POAllocationResult({
    required this.allocationId,
    required this.shipmentRef,
    required this.shippedQuantity,
    this.messages = const [],
  });

  final int allocationId;
  final String shipmentRef;
  final double shippedQuantity;

  /// Warnings about this allocation, e.g. OVER_SHIPPED (over-allocation is allowed).
  final List<POSystemMessage> messages;

  bool get isOverShipped => messages.any((m) => m.code == POSystemMessage.overShipped);

  factory POAllocationResult.fromJson(Map<String, dynamic> json) => POAllocationResult(
        allocationId: (json['allocation_id'] as num?)?.toInt() ?? 0,
        shipmentRef: (json['shipment_ref'] ?? '').toString(),
        shippedQuantity: (json['shipped_quantity'] as num?)?.toDouble() ?? 0.0,
        messages: POSystemMessage.listFromJson(json['messages']),
      );
}

/// Response of `GET /purchase-orders/{id}/packing-list-report` (the parts the UI shows).
class POPackingListReport {
  const POPackingListReport({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.messages = const [],
  });

  final bool isValid;

  /// English texts kept by the backend for old clients.
  final List<String> errors;
  final List<String> warnings;

  /// Coded twin of `errors + warnings`, same order.
  final List<POSystemMessage> messages;

  factory POPackingListReport.fromJson(Map<String, dynamic> json) => POPackingListReport(
        isValid: json['is_valid'] as bool? ?? true,
        errors: [for (final e in (json['errors'] as List? ?? const [])) e.toString()],
        warnings: [for (final e in (json['warnings'] as List? ?? const [])) e.toString()],
        messages: POSystemMessage.listFromJson(json['messages']),
      );

  /// Error lines then warning lines, each rendered from its code when present and
  /// known to this build, otherwise the English text.
  List<String> lines(AppLocalizations l10n) {
    final english = [...errors, ...warnings];
    return [
      for (var i = 0; i < english.length; i++)
        i < messages.length ? messages[i].text(l10n, fallback: english[i]) : english[i],
    ];
  }
}
