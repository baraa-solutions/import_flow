/// Invoice vs B/L match session, mirroring `InvoiceBLMatchSessionResponse`
/// (`modules/import_documentation/schemas.py`).
///
/// The backend does not store raw texts or file names (open question Q1), so
/// they are not part of the model. The user (`certified_by`) is set by the
/// server from the login.
class InvoiceBLMatchSessionModel {
  final int sessionId;
  final String sessionCode;
  final int importFileId;
  final String? importFileCode;
  final String? invoiceNumber;
  final String? blNumber;
  final String? packingListNumber;
  final String? acidNumber;
  final double matchScorePercentage;
  final String overallStatus;
  final bool isSafeForCertification;
  final bool isDraft;
  final int criticalDiscrepanciesCount;
  final int warningDiscrepanciesCount;
  final List<dynamic>? comparisonMatrix;
  final Map<String, dynamic>? invoiceData;
  final Map<String, dynamic>? blData;
  final Map<String, dynamic>? packingListData;
  final String? correctionLetter;
  final String? notes;
  final String? certifiedBy;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  InvoiceBLMatchSessionModel({
    required this.sessionId,
    required this.sessionCode,
    required this.importFileId,
    this.importFileCode,
    this.invoiceNumber,
    this.blNumber,
    this.packingListNumber,
    this.acidNumber,
    this.matchScorePercentage = 0.0,
    this.overallStatus = '',
    this.isSafeForCertification = false,
    this.isDraft = false,
    this.criticalDiscrepanciesCount = 0,
    this.warningDiscrepanciesCount = 0,
    this.comparisonMatrix,
    this.invoiceData,
    this.blData,
    this.packingListData,
    this.correctionLetter,
    this.notes,
    this.certifiedBy,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---- Convenience accessors used by the registry UI ----

  double get matchScore => matchScorePercentage;
  int get discrepancyCount => criticalDiscrepanciesCount + warningDiscrepanciesCount;
  bool get hasCriticalDiscrepancies => criticalDiscrepanciesCount > 0;
  String? get sessionNotes => notes;
  String? get createdBy => certifiedBy;

  /// Short label built from the document numbers (the backend has no title).
  String? get sessionTitle {
    final parts = <String>[
      if (invoiceNumber != null && invoiceNumber!.isNotEmpty) invoiceNumber!,
      if (blNumber != null && blNumber!.isNotEmpty) blNumber!,
    ];
    return parts.isEmpty ? null : parts.join(' / ');
  }

  static Map<String, dynamic>? _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  factory InvoiceBLMatchSessionModel.fromJson(Map<String, dynamic> json) {
    return InvoiceBLMatchSessionModel(
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      sessionCode: json['session_code'] as String? ?? '',
      importFileId: (json['import_file_id'] as num?)?.toInt() ?? 0,
      importFileCode: json['import_file_code'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      blNumber: json['bl_number'] as String?,
      packingListNumber: json['packing_list_number'] as String?,
      acidNumber: json['acid_number'] as String?,
      matchScorePercentage: (json['match_score_percentage'] as num?)?.toDouble() ?? 0.0,
      overallStatus: json['overall_status'] as String? ?? '',
      isSafeForCertification: json['is_safe_for_certification'] as bool? ?? false,
      isDraft: json['is_draft'] as bool? ?? false,
      criticalDiscrepanciesCount: (json['critical_discrepancies_count'] as num?)?.toInt() ?? 0,
      warningDiscrepanciesCount: (json['warning_discrepancies_count'] as num?)?.toInt() ?? 0,
      comparisonMatrix: json['comparison_matrix'] as List<dynamic>?,
      invoiceData: _map(json['invoice_data']),
      blData: _map(json['bl_data']),
      packingListData: _map(json['packing_list_data']),
      correctionLetter: json['correction_letter'] as String?,
      notes: json['notes'] as String?,
      certifiedBy: json['certified_by'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'session_code': sessionCode,
        'import_file_id': importFileId,
        if (importFileCode != null) 'import_file_code': importFileCode,
        if (invoiceNumber != null) 'invoice_number': invoiceNumber,
        if (blNumber != null) 'bl_number': blNumber,
        if (packingListNumber != null) 'packing_list_number': packingListNumber,
        if (acidNumber != null) 'acid_number': acidNumber,
        'match_score_percentage': matchScorePercentage,
        'overall_status': overallStatus,
        'is_safe_for_certification': isSafeForCertification,
        'is_draft': isDraft,
        'critical_discrepancies_count': criticalDiscrepanciesCount,
        'warning_discrepancies_count': warningDiscrepanciesCount,
        if (comparisonMatrix != null) 'comparison_matrix': comparisonMatrix,
        if (invoiceData != null) 'invoice_data': invoiceData,
        if (blData != null) 'bl_data': blData,
        if (packingListData != null) 'packing_list_data': packingListData,
        if (correctionLetter != null) 'correction_letter': correctionLetter,
        if (notes != null) 'notes': notes,
        if (certifiedBy != null) 'certified_by': certifiedBy,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Keys accepted by `InvoiceBLMatchSessionCreate`. Anything else would be
  /// silently dropped by Pydantic (FED-01).
  static const Set<String> createKeys = {
    'import_file_id',
    'import_file_code',
    'invoice_number',
    'bl_number',
    'packing_list_number',
    'acid_number',
    'match_score_percentage',
    'overall_status',
    'is_safe_for_certification',
    'is_draft',
    'critical_discrepancies_count',
    'warning_discrepancies_count',
    'comparison_matrix',
    'invoice_data',
    'bl_data',
    'packing_list_data',
    'correction_letter',
    'notes',
    'certified_by',
  };

  /// Builds the POST body from the extract-and-match result. Pure function so
  /// the payload can be pinned by a contract test.
  static Map<String, dynamic> toCreateJson({
    required int importFileId,
    required bool isDraft,
    Map<String, dynamic>? matchResult,
    String? notes,
  }) {
    final r = matchResult ?? const <String, dynamic>{};
    String? s(dynamic v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    Map<String, dynamic>? m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
    final inv = m(r['invoice_data']);
    final bl = m(r['bl_data']);
    final pl = m(r['packing_list_data']);

    final payload = <String, dynamic>{
      'import_file_id': importFileId,
      'is_draft': isDraft,
      'match_score_percentage': (r['match_score_percentage'] as num?)?.toDouble() ?? 0.0,
      'is_safe_for_certification': r['is_safe_for_certification'] == true,
      'critical_discrepancies_count': (r['critical_discrepancies_count'] as num?)?.toInt() ?? 0,
      'warning_discrepancies_count': (r['warning_discrepancies_count'] as num?)?.toInt() ?? 0,
      'comparison_matrix': r['comparison_matrix'],
      'invoice_data': inv,
      'bl_data': bl,
      'packing_list_data': pl,
      'invoice_number': s(r['invoice_number'] ?? inv?['invoice_number']),
      'bl_number': s(r['bl_number'] ?? bl?['draft_bl_number'] ?? bl?['bl_number']),
      'packing_list_number': s(r['packing_list_number'] ?? pl?['packing_list_number']),
      'acid_number': s(r['acid_number'] ?? bl?['acid_number'] ?? inv?['acid_number']),
      'correction_letter': s(r['correction_letter']),
      'notes': s(notes),
    };
    // overall_status: only forwarded when the matcher produced one; otherwise
    // the backend default applies.
    final status = s(r['overall_status']);
    if (status != null && status != 'DRAFT_SAVED' && status != 'CERTIFIED_SAVED') {
      payload['overall_status'] = status;
    }
    payload.removeWhere((k, v) => v == null);
    return payload;
  }
}
