class LinkedPOItemModel {
  final int poId;
  final String poNumber;
  final String? poReference;
  final String? piNumber;
  final int? projectId;
  final String? projectName;
  final String paymentTerms;
  final String currency;
  final double totalAmount;
  final String status;

  String get displayName =>
      (poReference != null && poReference!.trim().isNotEmpty)
          ? poReference!.trim()
          : poNumber;

  LinkedPOItemModel({
    required this.poId,
    required this.poNumber,
    this.poReference,
    this.piNumber,
    this.projectId,
    this.projectName,
    required this.paymentTerms,
    required this.currency,
    required this.totalAmount,
    required this.status,
  });

  factory LinkedPOItemModel.fromJson(Map<String, dynamic> json) {
    return LinkedPOItemModel(
      poId: json['po_id'] ?? 0,
      poNumber: json['po_number'] ?? '',
      poReference: json['po_reference'],
      piNumber: json['pi_number'],
      projectId: json['project_id'],
      projectName: json['project_name'],
      paymentTerms: json['payment_terms'] ?? '',
      currency: json['currency'] ?? 'USD',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Draft',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'po_id': poId,
      'po_number': poNumber,
      'po_reference': poReference,
      'pi_number': piNumber,
      'project_id': projectId,
      'project_name': projectName,
      'payment_terms': paymentTerms,
      'currency': currency,
      'total_amount': totalAmount,
      'status': status,
    };
  }
}

class BudgetPrefillModel {
  final int importFileId;
  final String importFileCode;
  final String importFileTitle;
  final String incoterm;
  final int? supplierId;
  final String supplierName;
  final String? beneficiaryName;
  final String? bankName;
  final String? swiftCode;
  final String? accountNumber;
  final String? iban;
  final String paymentTermsSummary;
  final List<LinkedPOItemModel> linkedPos;
  final double totalInvoiceAmount;
  final String invoiceCurrency;
  final double totalInvoiceAmountEgp;
  final double estimatedFreightCost;
  final String freightCurrency;
  final double estimatedFreightCostEgp;
  final double estimatedCustomsDutiesEgp;
  final double estimatedClearanceFeesEgp;
  final int? brokerId;
  final String? brokerName;
  final double estimatedGrandTotalEgp;
  final double exchangeRate;

  BudgetPrefillModel({
    required this.importFileId,
    required this.importFileCode,
    required this.importFileTitle,
    required this.incoterm,
    this.supplierId,
    required this.supplierName,
    this.beneficiaryName,
    this.bankName,
    this.swiftCode,
    this.accountNumber,
    this.iban,
    required this.paymentTermsSummary,
    required this.linkedPos,
    required this.totalInvoiceAmount,
    this.invoiceCurrency = 'USD',
    required this.totalInvoiceAmountEgp,
    required this.estimatedFreightCost,
    this.freightCurrency = '',
    required this.estimatedFreightCostEgp,
    required this.estimatedCustomsDutiesEgp,
    required this.estimatedClearanceFeesEgp,
    this.brokerId,
    this.brokerName,
    required this.estimatedGrandTotalEgp,
    this.exchangeRate = 0.0,
  });

  factory BudgetPrefillModel.fromJson(Map<String, dynamic> json) {
    final list = (json['linked_pos'] as List<dynamic>?)
            ?.map((p) => LinkedPOItemModel.fromJson(p))
            .toList() ??
        [];

    return BudgetPrefillModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      importFileTitle: json['import_file_title'] ?? '',
      incoterm: json['incoterm'] ?? '',
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'] ?? '',
      beneficiaryName: json['beneficiary_name'],
      bankName: json['bank_name'],
      swiftCode: json['swift_code'],
      accountNumber: json['account_number'],
      iban: json['iban'],
      paymentTermsSummary: json['payment_terms_summary'] ?? '',
      linkedPos: list,
      totalInvoiceAmount:
          (json['total_invoice_amount'] as num?)?.toDouble() ?? 0.0,
      invoiceCurrency: json['invoice_currency'] ?? 'USD',
      totalInvoiceAmountEgp:
          (json['total_invoice_amount_egp'] as num?)?.toDouble() ?? 0.0,
      estimatedFreightCost:
          (json['estimated_freight_cost'] as num?)?.toDouble() ?? 0.0,
      freightCurrency: json['freight_currency'] ?? '',
      estimatedFreightCostEgp:
          (json['estimated_freight_cost_egp'] as num?)?.toDouble() ?? 0.0,
      estimatedCustomsDutiesEgp:
          (json['estimated_customs_duties_egp'] as num?)?.toDouble() ?? 0.0,
      estimatedClearanceFeesEgp:
          (json['estimated_clearance_fees_egp'] as num?)?.toDouble() ?? 0.0,
      brokerId: json['broker_id'],
      brokerName: json['broker_name'],
      estimatedGrandTotalEgp:
          (json['estimated_grand_total_egp'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PaymentRequestModel {
  final int paymentId;
  final String paymentCode;
  final String title;
  final int? importFileId;
  final int? poId;
  final int? supplierId;
  final String supplierName;
  final int? projectId;
  final String paymentType;
  final double requestedAmount;
  final String currencyCode;
  final double exchangeRate;
  final double requestedAmountEgp;
  final String dueDate;
  final String requestDate;
  final String status;
  final String? beneficiaryName;
  final String? bankName;
  final String? swiftCode;
  final String? ibanAccountNo;
  final String? bankCountry;
  final String? swiftReferenceNo;
  final String? swiftReceiptDate;
  final double? swiftTransferredAmount;
  final String? swiftTransferredCurrency;
  final double? swiftVarianceAmount;
  final String? swiftVarianceStatus;
  final int? swiftProcessingDays;
  final String? swiftReconciliationNotes;
  final String? notes;
  final double? advancePercentage;
  final String? smartTaskCode;
  final int version;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? importFileCode;

  PaymentRequestModel({
    required this.paymentId,
    required this.paymentCode,
    required this.title,
    this.importFileId,
    this.poId,
    this.supplierId,
    required this.supplierName,
    this.projectId,
    required this.paymentType,
    required this.requestedAmount,
    this.currencyCode = 'USD',
    this.exchangeRate = 0.0,
    required this.requestedAmountEgp,
    required this.dueDate,
    required this.requestDate,
    required this.status,
    this.beneficiaryName,
    this.bankName,
    this.swiftCode,
    this.ibanAccountNo,
    this.bankCountry,
    this.swiftReferenceNo,
    this.swiftReceiptDate,
    this.swiftTransferredAmount,
    this.swiftTransferredCurrency,
    this.swiftVarianceAmount,
    this.swiftVarianceStatus,
    this.swiftProcessingDays,
    this.swiftReconciliationNotes,
    this.notes,
    this.advancePercentage,
    this.smartTaskCode,
    this.version = 1,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.importFileCode,
  });

  factory PaymentRequestModel.fromJson(Map<String, dynamic> json) {
    return PaymentRequestModel(
      paymentId: json['payment_id'],
      paymentCode: json['payment_code'] ?? '',
      title: json['title'] ?? '',
      importFileId: json['import_file_id'],
      poId: json['po_id'],
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'] ?? '',
      projectId: json['project_id'],
      paymentType: json['payment_type'] ?? 'Advance Payment',
      requestedAmount: (json['requested_amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currency_code'] ?? 'USD',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 0.0,
      requestedAmountEgp:
          (json['requested_amount_egp'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] ?? '',
      requestDate: json['request_date'] ?? '',
      status: json['status'] ?? 'Draft',
      beneficiaryName: json['beneficiary_name'],
      bankName: json['bank_name'],
      swiftCode: json['swift_code'],
      ibanAccountNo: json['iban_account_no'],
      bankCountry: json['bank_country'],
      swiftReferenceNo: json['swift_reference_no'],
      swiftReceiptDate: json['swift_receipt_date'],
      swiftTransferredAmount:
          (json['swift_transferred_amount'] as num?)?.toDouble(),
      swiftTransferredCurrency: json['swift_transferred_currency'],
      swiftVarianceAmount: (json['swift_variance_amount'] as num?)?.toDouble(),
      swiftVarianceStatus: json['swift_variance_status'],
      swiftProcessingDays: json['swift_processing_days'],
      swiftReconciliationNotes: json['swift_reconciliation_notes'],
      notes: json['notes'],
      advancePercentage: (json['advance_percentage'] as num?)?.toDouble(),
      smartTaskCode: json['smart_task_code'],
      version: json['version'] ?? 1,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      importFileCode: json['import_file_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_id': paymentId,
      'payment_code': paymentCode,
      'title': title,
      if (importFileId != null) 'import_file_id': importFileId,
      'po_id': poId,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'project_id': projectId,
      'payment_type': paymentType,
      'requested_amount': requestedAmount,
      'currency_code': currencyCode,
      'exchange_rate': exchangeRate,
      'requested_amount_egp': requestedAmountEgp,
      'due_date': dueDate,
      'request_date': requestDate,
      'status': status,
      'beneficiary_name': beneficiaryName,
      'bank_name': bankName,
      'swift_code': swiftCode,
      'iban_account_no': ibanAccountNo,
      'bank_country': bankCountry,
      'swift_reference_no': swiftReferenceNo,
      'swift_receipt_date': swiftReceiptDate,
      'swift_transferred_amount': swiftTransferredAmount,
      'swift_transferred_currency': swiftTransferredCurrency,
      'swift_variance_amount': swiftVarianceAmount,
      'swift_variance_status': swiftVarianceStatus,
      'swift_processing_days': swiftProcessingDays,
      'swift_reconciliation_notes': swiftReconciliationNotes,
      'notes': notes,
      'advance_percentage': advancePercentage,
      'smart_task_code': smartTaskCode,
      'version': version,
      'is_active': isActive,
    };
  }
}

class ImportBudgetModel {
  final int budgetId;
  final String budgetCode;
  final String title;
  final int? importFileId;
  final int? poId;
  final int? projectId;
  final double invoiceAmountEgp;
  final double invoiceAmountForeign;
  final String invoiceCurrency;
  final double freightCostEgp;
  final double freightCostForeign;
  final String freightCurrency;
  final double customsDutiesEgp;
  final double clearanceInlandEgp;
  final double exchangeRate;
  final double totalBudgetEgp;
  final String budgetStatus;
  final String? approvedBy;
  final String? approvedDate;
  final int? parentBudgetId;
  final int revisionNumber;
  final String? lastVarianceCheck;
  final bool hasUnresolvedVariance;
  final String? varianceOverrideReason;
  final String? varianceOverriddenBy;
  final String? upstreamModifiedBy;
  final String? notes;
  final int version;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? importFileCode;

  ImportBudgetModel({
    required this.budgetId,
    required this.budgetCode,
    required this.title,
    this.importFileId,
    this.poId,
    this.projectId,
    this.invoiceAmountEgp = 0.0,
    this.invoiceAmountForeign = 0.0,
    this.invoiceCurrency = 'USD',
    this.freightCostEgp = 0.0,
    this.freightCostForeign = 0.0,
    this.freightCurrency = 'USD',
    this.customsDutiesEgp = 0.0,
    this.clearanceInlandEgp = 0.0,
    this.exchangeRate = 0.0,
    required this.totalBudgetEgp,
    required this.budgetStatus,
    this.approvedBy,
    this.approvedDate,
    this.parentBudgetId,
    this.revisionNumber = 1,
    this.lastVarianceCheck,
    this.hasUnresolvedVariance = false,
    this.varianceOverrideReason,
    this.varianceOverriddenBy,
    this.upstreamModifiedBy,
    this.notes,
    this.version = 1,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.importFileCode,
  });

  factory ImportBudgetModel.fromJson(Map<String, dynamic> json) {
    return ImportBudgetModel(
      budgetId: json['budget_id'],
      budgetCode: json['budget_code'] ?? '',
      title: json['title'] ?? '',
      importFileId: json['import_file_id'],
      poId: json['po_id'],
      projectId: json['project_id'],
      invoiceAmountEgp: (json['invoice_amount_egp'] as num?)?.toDouble() ?? 0.0,
      invoiceAmountForeign:
          (json['invoice_amount_foreign'] as num?)?.toDouble() ?? 0.0,
      invoiceCurrency: json['invoice_currency'] ?? 'USD',
      freightCostEgp: (json['freight_cost_egp'] as num?)?.toDouble() ?? 0.0,
      freightCostForeign:
          (json['freight_cost_foreign'] as num?)?.toDouble() ?? 0.0,
      freightCurrency: json['freight_currency'] ?? 'USD',
      customsDutiesEgp: (json['customs_duties_egp'] as num?)?.toDouble() ?? 0.0,
      clearanceInlandEgp:
          (json['clearance_inland_egp'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 0.0,
      totalBudgetEgp: (json['total_budget_egp'] as num?)?.toDouble() ?? 0.0,
      budgetStatus: json['budget_status'] ?? 'Pending Review',
      approvedBy: json['approved_by'],
      approvedDate: json['approved_date'],
      parentBudgetId: json['parent_budget_id'],
      revisionNumber: json['revision_number'] ?? 1,
      lastVarianceCheck: json['last_variance_check'],
      hasUnresolvedVariance: json['has_unresolved_variance'] ?? false,
      varianceOverrideReason: json['variance_override_reason'],
      varianceOverriddenBy: json['variance_overridden_by'],
      upstreamModifiedBy: json['upstream_modified_by'],
      notes: json['notes'],
      version: json['version'] ?? 1,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      importFileCode: json['import_file_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'budget_id': budgetId,
      'budget_code': budgetCode,
      'title': title,
      if (importFileId != null) 'import_file_id': importFileId,
      'po_id': poId,
      'project_id': projectId,
      'invoice_amount_egp': invoiceAmountEgp,
      'invoice_amount_foreign': invoiceAmountForeign,
      'invoice_currency': invoiceCurrency,
      'freight_cost_egp': freightCostEgp,
      'freight_cost_foreign': freightCostForeign,
      'freight_currency': freightCurrency,
      'customs_duties_egp': customsDutiesEgp,
      'clearance_inland_egp': clearanceInlandEgp,
      'exchange_rate': exchangeRate,
      'total_budget_egp': totalBudgetEgp,
      'budget_status': budgetStatus,
      'approved_by': approvedBy,
      'approved_date': approvedDate,
      'parent_budget_id': parentBudgetId,
      'revision_number': revisionNumber,
      'last_variance_check': lastVarianceCheck,
      'has_unresolved_variance': hasUnresolvedVariance,
      'variance_override_reason': varianceOverrideReason,
      'variance_overridden_by': varianceOverriddenBy,
      'upstream_modified_by': upstreamModifiedBy,
      'notes': notes,
      'version': version,
      'is_active': isActive,
    };
  }
}

class SmartSwiftExtractResultModel {
  final bool success;
  final Map<String, dynamic> parsedSwift;
  final Map<String, dynamic>? matchedPaymentRequest;
  final List<dynamic> candidateMatches;
  final String? rawText;
  final String? detectedFilename;
  final String? detectedFileType;
  final String? error;

  SmartSwiftExtractResultModel({
    required this.success,
    required this.parsedSwift,
    this.matchedPaymentRequest,
    this.candidateMatches = const [],
    this.rawText,
    this.detectedFilename,
    this.detectedFileType,
    this.error,
  });

  factory SmartSwiftExtractResultModel.fromJson(Map<String, dynamic> json) {
    return SmartSwiftExtractResultModel(
      success: json['success'] ?? false,
      parsedSwift: json['parsed_swift'] != null
          ? Map<String, dynamic>.from(json['parsed_swift'])
          : {},
      matchedPaymentRequest: json['matched_payment_request'] != null
          ? Map<String, dynamic>.from(json['matched_payment_request'])
          : null,
      candidateMatches: json['candidate_matches'] != null
          ? List<dynamic>.from(json['candidate_matches'])
          : [],
      rawText: json['raw_text'],
      detectedFilename: json['detected_filename'],
      detectedFileType: json['detected_file_type'],
      error: json['error'],
    );
  }
}

class BudgetVarianceLogModel {
  final int id;
  final int budgetId;
  final int importFileId;
  final String fieldName;
  final double oldValue;
  final double newValue;
  final double varianceAmount;
  final double variancePercentage;
  final double thresholdPercentage;
  final bool isHardBlock;
  final String detectedAt;
  final String? modifiedBy;
  final String? resolvedAt;
  final String? resolvedBy;
  final String resolutionType;
  final String? justificationNote;

  BudgetVarianceLogModel({
    required this.id,
    required this.budgetId,
    required this.importFileId,
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    required this.varianceAmount,
    required this.variancePercentage,
    required this.thresholdPercentage,
    required this.isHardBlock,
    required this.detectedAt,
    this.modifiedBy,
    this.resolvedAt,
    this.resolvedBy,
    required this.resolutionType,
    this.justificationNote,
  });

  factory BudgetVarianceLogModel.fromJson(Map<String, dynamic> json) {
    return BudgetVarianceLogModel(
      id: json['id'] ?? 0,
      budgetId: json['budget_id'] ?? 0,
      importFileId: json['import_file_id'] ?? 0,
      fieldName: json['field_name'] ?? '',
      oldValue: (json['old_value'] as num?)?.toDouble() ?? 0.0,
      newValue: (json['new_value'] as num?)?.toDouble() ?? 0.0,
      varianceAmount: (json['variance_amount'] as num?)?.toDouble() ?? 0.0,
      variancePercentage:
          (json['variance_percentage'] as num?)?.toDouble() ?? 0.0,
      thresholdPercentage:
          (json['threshold_percentage'] as num?)?.toDouble() ?? 5.0,
      isHardBlock: json['is_hard_block'] ?? false,
      detectedAt: json['detected_at'] ?? '',
      modifiedBy: json['modified_by'],
      resolvedAt: json['resolved_at'],
      resolvedBy: json['resolved_by'],
      resolutionType: json['resolution_type'] ?? 'pending',
      justificationNote: json['justification_note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'budget_id': budgetId,
      'import_file_id': importFileId,
      'field_name': fieldName,
      'old_value': oldValue,
      'new_value': newValue,
      'variance_amount': varianceAmount,
      'variance_percentage': variancePercentage,
      'threshold_percentage': thresholdPercentage,
      'is_hard_block': isHardBlock,
      'detected_at': detectedAt,
      'modified_by': modifiedBy,
      'resolved_at': resolvedAt,
      'resolved_by': resolvedBy,
      'resolution_type': resolutionType,
      'justification_note': justificationNote,
    };
  }
}

class BudgetSyncResultModel {
  final ImportBudgetModel budget;
  final String actionTaken;
  final bool revisionCreated;
  final String? originalBudgetStatus;
  final List<BudgetVarianceLogModel> varianceLogs;
  final String message;

  BudgetSyncResultModel({
    required this.budget,
    required this.actionTaken,
    this.revisionCreated = false,
    this.originalBudgetStatus,
    this.varianceLogs = const [],
    required this.message,
  });

  factory BudgetSyncResultModel.fromJson(Map<String, dynamic> json) {
    return BudgetSyncResultModel(
      budget: ImportBudgetModel.fromJson(json['budget']),
      actionTaken: json['action_taken'] ?? '',
      revisionCreated: json['revision_created'] ?? false,
      originalBudgetStatus: json['original_budget_status'],
      varianceLogs: (json['variance_logs'] as List<dynamic>?)
              ?.map((l) => BudgetVarianceLogModel.fromJson(l))
              .toList() ??
          [],
      message: json['message'] ?? '',
    );
  }
}

class SwiftFieldModel {
  final int id;
  final int batchId;
  final String fieldKey;
  final String? swiftFieldCode;
  final String fieldLabel;
  final String? rawOcrText;
  final String? parsedValue;
  final double confidenceScore;
  final bool isEditedByUser;
  final String? editedValue;
  final String? finalValue;
  final bool isMandatory;
  final bool isEmpty;

  SwiftFieldModel({
    required this.id,
    required this.batchId,
    required this.fieldKey,
    this.swiftFieldCode,
    required this.fieldLabel,
    this.rawOcrText,
    this.parsedValue,
    required this.confidenceScore,
    required this.isEditedByUser,
    this.editedValue,
    this.finalValue,
    required this.isMandatory,
    required this.isEmpty,
  });

  factory SwiftFieldModel.fromJson(Map<String, dynamic> json) {
    return SwiftFieldModel(
      id: json['id'] ?? 0,
      batchId: json['batch_id'] ?? 0,
      fieldKey: json['field_key'] ?? '',
      swiftFieldCode: json['swift_field_code'],
      fieldLabel: json['field_label'] ?? '',
      rawOcrText: json['raw_ocr_text'],
      parsedValue: json['parsed_value'],
      confidenceScore: () {
        final raw = (json['confidence_score'] as num?)?.toDouble() ?? 0.0;
        return raw > 1.0 ? raw / 100.0 : raw;
      }(),
      isEditedByUser: json['is_edited_by_user'] ?? false,
      editedValue: json['edited_value'],
      finalValue: json['final_value'],
      isMandatory: json['is_mandatory'] ?? false,
      isEmpty: json['is_empty'] ?? false,
    );
  }

  SwiftFieldModel copyWith({
    String? editedValue,
    String? finalValue,
    bool? isEditedByUser,
    bool? isEmpty,
    double? confidenceScore,
  }) {
    return SwiftFieldModel(
      id: id,
      batchId: batchId,
      fieldKey: fieldKey,
      swiftFieldCode: swiftFieldCode,
      fieldLabel: fieldLabel,
      rawOcrText: rawOcrText,
      parsedValue: parsedValue,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      isEditedByUser: isEditedByUser ?? this.isEditedByUser,
      editedValue: editedValue ?? this.editedValue,
      finalValue: finalValue ?? this.finalValue,
      isMandatory: isMandatory,
      isEmpty: isEmpty ?? this.isEmpty,
    );
  }
}

class SwiftBatchModel {
  final int batchId;
  final String batchCode;
  final String? sourceFilename;
  final String? sourceFileType;
  final String rawSourceText;
  final String? normalizedText;
  final String status;
  final String? reviewedBy;
  final String? reviewedAt;
  final int? matchedPaymentId;
  final String? reconciledAt;
  final List<SwiftFieldModel> fields;
  final bool allMandatoryValid;
  final List<String> missingMandatoryFields;

  SwiftBatchModel({
    required this.batchId,
    required this.batchCode,
    this.sourceFilename,
    this.sourceFileType,
    required this.rawSourceText,
    this.normalizedText,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.matchedPaymentId,
    this.reconciledAt,
    required this.fields,
    required this.allMandatoryValid,
    required this.missingMandatoryFields,
  });

  factory SwiftBatchModel.fromJson(Map<String, dynamic> json) {
    return SwiftBatchModel(
      batchId: json['batch_id'] ?? 0,
      batchCode: json['batch_code'] ?? '',
      sourceFilename: json['source_filename'],
      sourceFileType: json['source_file_type'],
      rawSourceText: json['raw_source_text'] ?? '',
      normalizedText: json['normalized_text'],
      status: json['status'] ?? 'EXTRACTED_PENDING_REVIEW',
      reviewedBy: json['reviewed_by'],
      reviewedAt: json['reviewed_at'],
      matchedPaymentId: json['matched_payment_id'],
      reconciledAt: json['reconciled_at'],
      fields: (json['fields'] as List<dynamic>?)
              ?.map((f) => SwiftFieldModel.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      allMandatoryValid: json['all_mandatory_valid'] ?? false,
      missingMandatoryFields:
          (json['missing_mandatory_fields'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
    );
  }
}
