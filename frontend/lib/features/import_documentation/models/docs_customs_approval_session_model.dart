/// Final customs-approval session (STEP-09), mirroring
/// `DocsCustomsApprovalSessionResponse` in
/// `modules/docs_customs_approval/schemas.py`.
///
/// Sign-off and creator names are set by the server from the login; a final
/// session is locked (409 `DCA_SESSION_FINAL_LOCKED`).
class DocsCustomsApprovalSessionModel {
  final int sessionId;
  final String sessionCode;
  final int version;
  final int importFileId;
  final String? importFileCode;
  final int? poId;
  final String overallStatus;
  final bool isDraft;

  final String? finalInvoiceRef;
  final String finalInvoiceStatus;
  final String? finalPlRef;
  final String finalPlStatus;
  final String? draftBlRef;
  final String draftBlStatus;
  final String? cooRef;
  final String cooStatus;
  final String? cocRef;
  final String cocStatus;

  final String? commercialSignoffBy;
  final String? commercialSignoffDate;
  final String? customsSignoffBy;
  final String? customsSignoffDate;
  final String? customsBrokerName;

  final int discrepanciesCount;
  final int openTicketsCount;
  final Map<String, dynamic>? sessionSnapshot;
  final String? notes;
  final String? createdBy;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  DocsCustomsApprovalSessionModel({
    required this.sessionId,
    required this.sessionCode,
    this.version = 1,
    required this.importFileId,
    this.importFileCode,
    this.poId,
    this.overallStatus = '',
    this.isDraft = false,
    this.finalInvoiceRef,
    this.finalInvoiceStatus = '',
    this.finalPlRef,
    this.finalPlStatus = '',
    this.draftBlRef,
    this.draftBlStatus = '',
    this.cooRef,
    this.cooStatus = '',
    this.cocRef,
    this.cocStatus = '',
    this.commercialSignoffBy,
    this.commercialSignoffDate,
    this.customsSignoffBy,
    this.customsSignoffDate,
    this.customsBrokerName,
    this.discrepanciesCount = 0,
    this.openTicketsCount = 0,
    this.sessionSnapshot,
    this.notes,
    this.createdBy,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocsCustomsApprovalSessionModel.fromJson(Map<String, dynamic> json) {
    final snapshot = json['session_snapshot'];
    return DocsCustomsApprovalSessionModel(
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      sessionCode: json['session_code'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      importFileId: (json['import_file_id'] as num?)?.toInt() ?? 0,
      importFileCode: json['import_file_code'] as String?,
      poId: (json['po_id'] as num?)?.toInt(),
      overallStatus: json['overall_status'] as String? ?? '',
      isDraft: json['is_draft'] as bool? ?? false,
      finalInvoiceRef: json['final_invoice_ref'] as String?,
      finalInvoiceStatus: json['final_invoice_status'] as String? ?? '',
      finalPlRef: json['final_pl_ref'] as String?,
      finalPlStatus: json['final_pl_status'] as String? ?? '',
      draftBlRef: json['draft_bl_ref'] as String?,
      draftBlStatus: json['draft_bl_status'] as String? ?? '',
      cooRef: json['coo_ref'] as String?,
      cooStatus: json['coo_status'] as String? ?? '',
      cocRef: json['coc_ref'] as String?,
      cocStatus: json['coc_status'] as String? ?? '',
      commercialSignoffBy: json['commercial_signoff_by'] as String?,
      commercialSignoffDate: json['commercial_signoff_date']?.toString(),
      customsSignoffBy: json['customs_signoff_by'] as String?,
      customsSignoffDate: json['customs_signoff_date']?.toString(),
      customsBrokerName: json['customs_broker_name'] as String?,
      discrepanciesCount: (json['discrepancies_count'] as num?)?.toInt() ?? 0,
      openTicketsCount: (json['open_tickets_count'] as num?)?.toInt() ?? 0,
      sessionSnapshot: snapshot is Map ? Map<String, dynamic>.from(snapshot) : null,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'session_code': sessionCode,
        'version': version,
        'import_file_id': importFileId,
        if (importFileCode != null) 'import_file_code': importFileCode,
        if (poId != null) 'po_id': poId,
        'overall_status': overallStatus,
        'is_draft': isDraft,
        if (finalInvoiceRef != null) 'final_invoice_ref': finalInvoiceRef,
        'final_invoice_status': finalInvoiceStatus,
        if (finalPlRef != null) 'final_pl_ref': finalPlRef,
        'final_pl_status': finalPlStatus,
        if (draftBlRef != null) 'draft_bl_ref': draftBlRef,
        'draft_bl_status': draftBlStatus,
        if (cooRef != null) 'coo_ref': cooRef,
        'coo_status': cooStatus,
        if (cocRef != null) 'coc_ref': cocRef,
        'coc_status': cocStatus,
        if (commercialSignoffBy != null) 'commercial_signoff_by': commercialSignoffBy,
        if (commercialSignoffDate != null) 'commercial_signoff_date': commercialSignoffDate,
        if (customsSignoffBy != null) 'customs_signoff_by': customsSignoffBy,
        if (customsSignoffDate != null) 'customs_signoff_date': customsSignoffDate,
        if (customsBrokerName != null) 'customs_broker_name': customsBrokerName,
        'discrepancies_count': discrepanciesCount,
        'open_tickets_count': openTicketsCount,
        if (sessionSnapshot != null) 'session_snapshot': sessionSnapshot,
        if (notes != null) 'notes': notes,
        if (createdBy != null) 'created_by': createdBy,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
