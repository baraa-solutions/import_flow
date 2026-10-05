class CustomsDocumentApprovalModel {
  final int approvalId;
  final String approvalCode;
  final int importFileId;
  final String? importFileCode;
  final int? poId;
  final String documentType;
  final String? documentReferenceNo;
  final String? documentDate;

  final String commercialStatus;
  final String? commercialReviewedBy;
  final String? commercialReviewedAt;
  final String? commercialNotes;

  final String customsStatus;
  final String? customsReviewedBy;
  final String? customsReviewedAt;
  final String? customsBrokerName;
  final String? customsNotes;

  final String overallStatus;
  final Map<String, dynamic>? crossCheckSummary;
  final bool isActive;
  final int version;
  final String createdAt;
  final String updatedAt;

  CustomsDocumentApprovalModel({
    required this.approvalId,
    required this.approvalCode,
    required this.importFileId,
    this.importFileCode,
    this.poId,
    required this.documentType,
    this.documentReferenceNo,
    this.documentDate,
    this.commercialStatus = 'Pending',
    this.commercialReviewedBy,
    this.commercialReviewedAt,
    this.commercialNotes,
    this.customsStatus = 'Pending',
    this.customsReviewedBy,
    this.customsReviewedAt,
    this.customsBrokerName,
    this.customsNotes,
    this.overallStatus = 'Draft',
    this.crossCheckSummary,
    this.isActive = true,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomsDocumentApprovalModel.fromJson(Map<String, dynamic> json) {
    return CustomsDocumentApprovalModel(
      approvalId: json['approval_id'] as int,
      approvalCode: json['approval_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int,
      importFileCode: json['import_file_code'] as String?,
      poId: json['po_id'] as int?,
      documentType: json['document_type'] as String? ?? '',
      documentReferenceNo: json['document_reference_no'] as String?,
      documentDate: json['document_date'] as String?,
      commercialStatus: json['commercial_status'] as String? ?? 'Pending',
      commercialReviewedBy: json['commercial_reviewed_by'] as String?,
      commercialReviewedAt: json['commercial_reviewed_at'] as String?,
      commercialNotes: json['commercial_notes'] as String?,
      customsStatus: json['customs_status'] as String? ?? 'Pending',
      customsReviewedBy: json['customs_reviewed_by'] as String?,
      customsReviewedAt: json['customs_reviewed_at'] as String?,
      customsBrokerName: json['customs_broker_name'] as String?,
      customsNotes: json['customs_notes'] as String?,
      overallStatus: json['overall_status'] as String? ?? 'Draft',
      crossCheckSummary: json['cross_check_summary'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'approval_id': approvalId,
      'approval_code': approvalCode,
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'po_id': poId,
      'document_type': documentType,
      'document_reference_no': documentReferenceNo,
      'document_date': documentDate,
      'commercial_status': commercialStatus,
      'commercial_reviewed_by': commercialReviewedBy,
      'commercial_reviewed_at': commercialReviewedAt,
      'commercial_notes': commercialNotes,
      'customs_status': customsStatus,
      'customs_reviewed_by': customsReviewedBy,
      'customs_reviewed_at': customsReviewedAt,
      'customs_broker_name': customsBrokerName,
      'customs_notes': customsNotes,
      'overall_status': overallStatus,
      'cross_check_summary': crossCheckSummary,
      'is_active': isActive,
      'version': version,
    };
  }
}

class DiscrepancyRectificationTicketModel {
  final int ticketId;
  final String ticketCode;
  final int? approvalId;
  final int importFileId;
  final String? importFileCode;
  final String issueCategory;
  final String severity;
  final String description;
  final String? expectedValue;
  final String? foundValue;
  final String? supplierActionRequired;
  final String? supplierResponse;
  final String status;
  final String? resolvedAt;
  final String? resolvedBy;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  DiscrepancyRectificationTicketModel({
    required this.ticketId,
    required this.ticketCode,
    this.approvalId,
    required this.importFileId,
    this.importFileCode,
    required this.issueCategory,
    this.severity = 'Major',
    required this.description,
    this.expectedValue,
    this.foundValue,
    this.supplierActionRequired,
    this.supplierResponse,
    this.status = 'Open',
    this.resolvedAt,
    this.resolvedBy,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiscrepancyRectificationTicketModel.fromJson(Map<String, dynamic> json) {
    return DiscrepancyRectificationTicketModel(
      ticketId: json['ticket_id'] as int,
      ticketCode: json['ticket_code'] as String? ?? '',
      approvalId: json['approval_id'] as int?,
      importFileId: json['import_file_id'] as int,
      importFileCode: json['import_file_code'] as String?,
      issueCategory: json['issue_category'] as String? ?? '',
      severity: json['severity'] as String? ?? 'Major',
      description: json['description'] as String? ?? '',
      expectedValue: json['expected_value'] as String?,
      foundValue: json['found_value'] as String?,
      supplierActionRequired: json['supplier_action_required'] as String?,
      supplierResponse: json['supplier_response'] as String?,
      status: json['status'] as String? ?? 'Open',
      resolvedAt: json['resolved_at'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticket_id': ticketId,
      'ticket_code': ticketCode,
      'approval_id': approvalId,
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'issue_category': issueCategory,
      'severity': severity,
      'description': description,
      'expected_value': expectedValue,
      'found_value': foundValue,
      'supplier_action_required': supplierActionRequired,
      'supplier_response': supplierResponse,
      'status': status,
      'resolved_at': resolvedAt,
      'resolved_by': resolvedBy,
      'is_active': isActive,
    };
  }
}

int _notCheckedCount(Map<String, dynamic> json) {
  final explicit = json['not_checked_checks'];
  if (explicit is num) return explicit.toInt();
  final checks = json['checks'];
  if (checks is List) {
    return checks.where((c) => c is Map && c['status'] == 'Not Checked').length;
  }
  return 0;
}

class CrossDocumentMatrixResultModel {
  final int importFileId;
  final String importFileCode;
  final String overallCompliance;
  final int totalChecks;
  final int passedChecks;
  final int failedChecks;
  final List<MatrixCheckItemModel> checks;
  final List<String> recommendations;
  final int openTicketsCount;
  final List<String> missingDocuments;
  final double completenessPercent;
  /// Rows the backend could not verify (status "Not Checked"): neutral, not failures.
  final int notCheckedCount;

  CrossDocumentMatrixResultModel({
    required this.importFileId,
    required this.importFileCode,
    required this.overallCompliance,
    required this.totalChecks,
    required this.passedChecks,
    required this.failedChecks,
    required this.checks,
    required this.recommendations,
    required this.openTicketsCount,
    this.missingDocuments = const [],
    this.completenessPercent = 0.0,
    this.notCheckedCount = 0,
  });

  factory CrossDocumentMatrixResultModel.fromJson(Map<String, dynamic> json) {
    return CrossDocumentMatrixResultModel(
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String? ?? '',
      overallCompliance: json['overall_compliance'] as String? ?? 'Pending',
      totalChecks: json['total_checks'] as int? ?? 0,
      passedChecks: json['passed_checks'] as int? ?? 0,
      failedChecks: json['failed_checks'] as int? ?? 0,
      checks: (json['checks'] as List<dynamic>?)
              ?.map((e) => MatrixCheckItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      openTicketsCount: json['open_tickets_count'] as int? ?? 0,
      missingDocuments: (json['missing_documents'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      completenessPercent: (json['completeness_percent'] as num?)?.toDouble() ?? 0.0,
      notCheckedCount: _notCheckedCount(json),
    );
  }
}

class MatrixCheckItemModel {
  final String parameter;
  final String status;
  final String? invoiceVal;
  final String? blVal;
  final String? packingVal;
  final String? cooVal;
  final String? acidVal;
  final String? notes;

  MatrixCheckItemModel({
    required this.parameter,
    required this.status,
    this.invoiceVal,
    this.blVal,
    this.packingVal,
    this.cooVal,
    this.acidVal,
    this.notes,
  });

  factory MatrixCheckItemModel.fromJson(Map<String, dynamic> json) {
    return MatrixCheckItemModel(
      parameter: json['parameter'] as String? ?? '',
      status: json['status'] as String? ?? 'Unknown',
      invoiceVal: json['invoice_val'] as String?,
      blVal: json['bl_val'] as String?,
      packingVal: json['packing_val'] as String?,
      cooVal: json['coo_val'] as String?,
      acidVal: json['acid_val'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
