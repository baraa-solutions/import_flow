import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/system_messages/coded_item_text.dart';
import '../../../core/localization/system_messages/system_message_renderer.dart';
import '../../../core/utils/bidi_text.dart';

class AcidDiscrepancyItem {
  final String field;
  final String labelAr;
  final String labelEn;
  final String requestedValue;
  final String generatedValue;
  final bool isMatched;
  final String severity; // error, warning, info

  AcidDiscrepancyItem({
    required this.field,
    required this.labelAr,
    required this.labelEn,
    required this.requestedValue,
    required this.generatedValue,
    required this.isMatched,
    required this.severity,
  });

  factory AcidDiscrepancyItem.fromJson(Map<String, dynamic> json) {
    return AcidDiscrepancyItem(
      field: json['field'] ?? '',
      labelAr: json['label_ar'] ?? '',
      labelEn: json['label_en'] ?? '',
      requestedValue: json['requested_value']?.toString() ?? '',
      generatedValue: json['generated_value']?.toString() ?? '',
      isMatched: json['is_matched'] ?? false,
      severity: json['severity'] ?? 'info',
    );
  }

  Map<String, dynamic> toJson() => {
    'field': field,
    'label_ar': labelAr,
    'label_en': labelEn,
    'requested_value': requestedValue,
    'generated_value': generatedValue,
    'is_matched': isMatched,
    'severity': severity,
  };
}

class AcidComparisonResult {
  final bool allMatched;
  final bool hasCriticalError;
  final double matchPercentage;
  final int totalComparedFields;
  final int matchedCount;
  final int discrepantCount;
  final List<AcidDiscrepancyItem> items;

  AcidComparisonResult({
    required this.allMatched,
    required this.hasCriticalError,
    required this.matchPercentage,
    required this.totalComparedFields,
    required this.matchedCount,
    required this.discrepantCount,
    required this.items,
  });

  factory AcidComparisonResult.fromJson(Map<String, dynamic> json) {
    return AcidComparisonResult(
      allMatched: json['all_matched'] ?? true,
      hasCriticalError: json['has_critical_error'] ?? false,
      matchPercentage: (json['match_percentage'] as num?)?.toDouble() ?? 100.0,
      totalComparedFields: json['total_compared_fields'] ?? 0,
      matchedCount: json['matched_count'] ?? 0,
      discrepantCount: json['discrepant_count'] ?? 0,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => AcidDiscrepancyItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'all_matched': allMatched,
    'has_critical_error': hasCriticalError,
    'match_percentage': matchPercentage,
    'total_compared_fields': totalComparedFields,
    'matched_count': matchedCount,
    'discrepant_count': discrepantCount,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class AcidRegistrationModel {
  final int acidId;
  final String acidCode;
  final String acidNumber;
  final int? importFileId;
  final String? importFileCode;
  final int? poId;
  final String? poNumber;
  final String? poDate;

  final int? importerId;
  final String importerName;
  final String importerTaxId;
  final String? importerAddress;

  final int? supplierId;
  final String exporterName;
  final String? exporterRegType;
  final String exporterRegId;
  final String exporterCountry;
  final String? exporterCountryCode;
  final String? exporterAddress;
  final String? exporterPhone;
  final String? cargoxId;

  final String proformaInvoiceNo;
  final String? proformaInvoiceDate;
  final String? invoiceDate;
  final String? invoiceType;
  final String? invoiceAttachmentName;

  final String polName;
  final String podName;

  final int? customsBrokerId;
  final String? customsBrokerName;
  final String? customsBrokerPhone;

  final String? requestedDate;
  final String? generatedDate;
  final String? expiryDate;
  final int? executionDays;

  final String? rawNafezaText;
  final Map<String, dynamic>? requestedData;
  final Map<String, dynamic>? generatedData;
  final Map<String, dynamic>? discrepanciesData;
  final String? discrepancyOverrideReason;

  final bool isImporterMatched;
  final bool isExporterMatched;
  final bool isInvoiceMatched;
  final bool isPortsMatched;
  final bool hasDiscrepancies;
  final String? verificationNotes;
  final String status;
  final int daysToExpiry;
  final bool isVerified;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  AcidRegistrationModel({
    required this.acidId,
    required this.acidCode,
    required this.acidNumber,
    this.importFileId,
    this.importFileCode,
    this.poId,
    this.poNumber,
    this.poDate,
    this.importerId,
    required this.importerName,
    required this.importerTaxId,
    this.importerAddress,
    this.supplierId,
    required this.exporterName,
    this.exporterRegType = 'VAT Number',
    required this.exporterRegId,
    required this.exporterCountry,
    this.exporterCountryCode,
    this.exporterAddress,
    this.exporterPhone,
    this.cargoxId,
    required this.proformaInvoiceNo,
    this.proformaInvoiceDate,
    this.invoiceDate,
    this.invoiceType = 'Proforma Invoice',
    this.invoiceAttachmentName,
    required this.polName,
    required this.podName,
    this.customsBrokerId,
    this.customsBrokerName,
    this.customsBrokerPhone,
    this.requestedDate,
    this.generatedDate,
    this.expiryDate,
    this.executionDays,
    this.rawNafezaText,
    this.requestedData,
    this.generatedData,
    this.discrepanciesData,
    this.discrepancyOverrideReason,
    this.isImporterMatched = true,
    this.isExporterMatched = true,
    this.isInvoiceMatched = true,
    this.isPortsMatched = true,
    this.hasDiscrepancies = false,
    this.verificationNotes,
    required this.status,
    this.daysToExpiry = 90,
    this.isVerified = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AcidRegistrationModel.fromJson(Map<String, dynamic> json) {
    return AcidRegistrationModel(
      acidId: json['acid_id'] ?? 0,
      acidCode: json['acid_code'] ?? '',
      acidNumber: json['acid_number'] ?? '',
      importFileId: json['import_file_id'],
      importFileCode: json['import_file_code'],
      poId: json['po_id'],
      poNumber: json['po_number'],
      poDate: json['po_date'],
      importerId: json['importer_id'],
      importerName: json['importer_name'] ?? '',
      importerTaxId: json['importer_tax_id'] ?? '',
      importerAddress: json['importer_address'],
      supplierId: json['supplier_id'],
      exporterName: json['exporter_name'] ?? '',
      exporterRegType: json['exporter_reg_type'] ?? 'VAT Number',
      exporterRegId: json['exporter_reg_id'] ?? '',
      exporterCountry: json['exporter_country'] ?? '',
      exporterCountryCode: json['exporter_country_code'],
      exporterAddress: json['exporter_address'],
      exporterPhone: json['exporter_phone'],
      cargoxId: json['cargox_id'],
      proformaInvoiceNo: json['proforma_invoice_no'] ?? '',
      proformaInvoiceDate: json['proforma_invoice_date'],
      invoiceDate: json['invoice_date'],
      invoiceType: json['invoice_type'] ?? 'Proforma Invoice',
      invoiceAttachmentName: json['invoice_attachment_name'],
      polName: json['pol_name'] ?? '',
      podName: json['pod_name'] ?? '',
      customsBrokerId: json['customs_broker_id'],
      customsBrokerName: json['customs_broker_name'],
      customsBrokerPhone: json['customs_broker_phone'],
      requestedDate: json['requested_date'],
      generatedDate: json['generated_date'],
      expiryDate: json['expiry_date'],
      executionDays: json['execution_days'] as int?,
      rawNafezaText: json['raw_nafeza_text'],
      requestedData: json['requested_data'] != null ? Map<String, dynamic>.from(json['requested_data']) : null,
      generatedData: json['generated_data'] != null ? Map<String, dynamic>.from(json['generated_data']) : null,
      discrepanciesData: json['discrepancies_data'] != null ? Map<String, dynamic>.from(json['discrepancies_data']) : null,
      discrepancyOverrideReason: json['discrepancy_override_reason'],
      isImporterMatched: json['is_importer_matched'] ?? true,
      isExporterMatched: json['is_exporter_matched'] ?? true,
      isInvoiceMatched: json['is_invoice_matched'] ?? true,
      isPortsMatched: json['is_ports_matched'] ?? true,
      hasDiscrepancies: json['has_discrepancies'] ?? false,
      verificationNotes: json['verification_notes'],
      status: json['status'] ?? 'Requested',
      daysToExpiry: json['days_to_expiry'] ?? 90,
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'acid_id': acidId,
      'acid_code': acidCode,
      'acid_number': acidNumber,
      if (importFileId != null) 'import_file_id': importFileId,
      if (importFileCode != null) 'import_file_code': importFileCode,
      if (poId != null) 'po_id': poId,
      if (poNumber != null) 'po_number': poNumber,
      if (poDate != null) 'po_date': poDate,
      if (importerId != null) 'importer_id': importerId,
      'importer_name': importerName,
      'importer_tax_id': importerTaxId,
      if (importerAddress != null) 'importer_address': importerAddress,
      if (supplierId != null) 'supplier_id': supplierId,
      'exporter_name': exporterName,
      'exporter_reg_type': exporterRegType,
      'exporter_reg_id': exporterRegId,
      'exporter_country': exporterCountry,
      if (exporterCountryCode != null) 'exporter_country_code': exporterCountryCode,
      if (exporterAddress != null) 'exporter_address': exporterAddress,
      if (exporterPhone != null) 'exporter_phone': exporterPhone,
      if (cargoxId != null) 'cargox_id': cargoxId,
      'proforma_invoice_no': proformaInvoiceNo,
      if (proformaInvoiceDate != null) 'proforma_invoice_date': proformaInvoiceDate,
      if (invoiceDate != null) 'invoice_date': invoiceDate,
      'invoice_type': invoiceType,
      if (invoiceAttachmentName != null) 'invoice_attachment_name': invoiceAttachmentName,
      'pol_name': polName,
      'pod_name': podName,
      if (customsBrokerId != null) 'customs_broker_id': customsBrokerId,
      if (customsBrokerName != null) 'customs_broker_name': customsBrokerName,
      if (customsBrokerPhone != null) 'customs_broker_phone': customsBrokerPhone,
      if (requestedDate != null) 'requested_date': requestedDate,
      if (generatedDate != null) 'generated_date': generatedDate,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (executionDays != null) 'execution_days': executionDays,
      if (rawNafezaText != null) 'raw_nafeza_text': rawNafezaText,
      if (requestedData != null) 'requested_data': requestedData,
      if (generatedData != null) 'generated_data': generatedData,
      if (discrepanciesData != null) 'discrepancies_data': discrepanciesData,
      if (discrepancyOverrideReason != null) 'discrepancy_override_reason': discrepancyOverrideReason,
      'is_importer_matched': isImporterMatched,
      'is_exporter_matched': isExporterMatched,
      'is_invoice_matched': isInvoiceMatched,
      'is_ports_matched': isPortsMatched,
      'has_discrepancies': hasDiscrepancies,
      if (verificationNotes != null) 'verification_notes': verificationNotes,
      'status': status,
    };
  }
}

class BankingDocumentModel {
  final int bankDocId;
  final String bankDocCode;
  final String docType;
  final int? importFileId;
  final int? poId;
  final int? bankId;
  final String bankName;
  final String docReferenceNumber;
  final double amount;
  final String currencyCode;
  final String? requestDate;
  final String? receivedDate;
  final int executionDays;
  final String issueDate;
  final String? expiryDate;
  final String status;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? importFileCode;
  final String? importerName;
  final String? supplierName;
  final String? poNumber;

  BankingDocumentModel({
    required this.bankDocId,
    required this.bankDocCode,
    required this.docType,
    this.importFileId,
    this.poId,
    this.bankId,
    required this.bankName,
    required this.docReferenceNumber,
    required this.amount,
    this.currencyCode = 'USD',
    this.requestDate,
    this.receivedDate,
    this.executionDays = 0,
    required this.issueDate,
    this.expiryDate,
    required this.status,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.importFileCode,
    this.importerName,
    this.supplierName,
    this.poNumber,
  });

  factory BankingDocumentModel.fromJson(Map<String, dynamic> json) {
    return BankingDocumentModel(
      bankDocId: json['bank_doc_id'] ?? 0,
      bankDocCode: json['bank_doc_code'] ?? '',
      docType: json['doc_type'] ?? 'Form 4',
      importFileId: json['import_file_id'],
      poId: json['po_id'],
      bankId: json['bank_id'],
      bankName: json['bank_name'] ?? '',
      docReferenceNumber: json['doc_reference_number'] ?? 'PENDING',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currency_code'] ?? 'USD',
      requestDate: json['request_date']?.toString(),
      receivedDate: json['received_date']?.toString(),
      executionDays: (json['execution_days'] as num?)?.toInt() ?? 0,
      issueDate: json['issue_date']?.toString() ?? '',
      expiryDate: json['expiry_date']?.toString(),
      status: json['status'] ?? 'Requested',
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      importFileCode: json['import_file_code'],
      importerName: json['importer_name'],
      supplierName: json['supplier_name'],
      poNumber: json['po_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_doc_id': bankDocId,
      'bank_doc_code': bankDocCode,
      'doc_type': docType,
      if (importFileId != null) 'import_file_id': importFileId,
      'po_id': poId,
      'bank_id': bankId,
      'bank_name': bankName,
      'doc_reference_number': docReferenceNumber,
      'amount': amount,
      'currency_code': currencyCode,
      if (requestDate != null) 'request_date': requestDate,
      if (receivedDate != null) 'received_date': receivedDate,
      'execution_days': executionDays,
      'issue_date': issueDate,
      'expiry_date': expiryDate,
      'status': status,
      'notes': notes,
      'is_active': isActive,
    };
  }
}

class ShipmentDocumentModel {
  final int documentId;
  final String documentCode;
  final int? importFileId;
  final int? poId;
  final String docName;
  final String docNumber;
  final String issueDate;
  final String? receivedDate;
  final String status;
  final bool isCargoxUploaded;
  final String? cargoxEnvelopeId;
  final bool isBlEndorsed;
  final String? endorsementNumber;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? importFileCode;

  ShipmentDocumentModel({
    required this.documentId,
    required this.documentCode,
    this.importFileId,
    this.poId,
    required this.docName,
    required this.docNumber,
    required this.issueDate,
    this.receivedDate,
    required this.status,
    this.isCargoxUploaded = false,
    this.cargoxEnvelopeId,
    this.isBlEndorsed = false,
    this.endorsementNumber,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.importFileCode,
  });

  factory ShipmentDocumentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentDocumentModel(
      documentId: json['document_id'],
      documentCode: json['document_code'] ?? '',
      importFileId: json['import_file_id'],
      poId: json['po_id'],
      docName: json['doc_name'] ?? '',
      docNumber: json['doc_number'] ?? '',
      issueDate: json['issue_date'] ?? '',
      receivedDate: json['received_date'],
      status: json['status'] ?? 'Approved',
      isCargoxUploaded: json['is_cargox_uploaded'] ?? false,
      cargoxEnvelopeId: json['cargox_envelope_id'],
      isBlEndorsed: json['is_bl_endorsed'] ?? false,
      endorsementNumber: json['endorsement_number'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      importFileCode: json['import_file_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'document_id': documentId,
      'document_code': documentCode,
      if (importFileId != null) 'import_file_id': importFileId,
      'po_id': poId,
      'doc_name': docName,
      'doc_number': docNumber,
      'issue_date': issueDate,
      'received_date': receivedDate,
      'status': status,
      'is_cargox_uploaded': isCargoxUploaded,
      'cargox_envelope_id': cargoxEnvelopeId,
      'is_bl_endorsed': isBlEndorsed,
      'endorsement_number': endorsementNumber,
      'notes': notes,
      'is_active': isActive,
    };
  }
}

class CustomsDeclarationModel {
  final int declarationId;
  final String declarationCode;
  final int? importFileId;
  final int? poId;
  final String acidNumber;
  final String? form4Number;
  final String? blNumber;
  final double totalCifValEgp;
  final double totalCustomsDutiesEgp;
  final double totalVatEgp;
  final String declarationStatus;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final String? importFileCode;

  CustomsDeclarationModel({
    required this.declarationId,
    required this.declarationCode,
    this.importFileId,
    this.poId,
    required this.acidNumber,
    this.form4Number,
    this.blNumber,
    this.totalCifValEgp = 0.0,
    this.totalCustomsDutiesEgp = 0.0,
    this.totalVatEgp = 0.0,
    required this.declarationStatus,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.importFileCode,
  });

  factory CustomsDeclarationModel.fromJson(Map<String, dynamic> json) {
    return CustomsDeclarationModel(
      declarationId: json['declaration_id'],
      declarationCode: json['declaration_code'] ?? '',
      importFileId: json['import_file_id'],
      poId: json['po_id'],
      acidNumber: json['acid_number'] ?? '',
      form4Number: json['form4_number'],
      blNumber: json['bl_number'],
      totalCifValEgp: (json['total_cif_val_egp'] as num?)?.toDouble() ?? 0.0,
      totalCustomsDutiesEgp: (json['total_customs_duties_egp'] as num?)?.toDouble() ?? 0.0,
      totalVatEgp: (json['total_vat_egp'] as num?)?.toDouble() ?? 0.0,
      declarationStatus: json['declaration_status'] ?? 'Draft Prepared',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      importFileCode: json['import_file_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'declaration_id': declarationId,
      'declaration_code': declarationCode,
      if (importFileId != null) 'import_file_id': importFileId,
      'po_id': poId,
      'acid_number': acidNumber,
      'form4_number': form4Number,
      'bl_number': blNumber,
      'total_cif_val_egp': totalCifValEgp,
      'total_customs_duties_egp': totalCustomsDutiesEgp,
      'total_vat_egp': totalVatEgp,
      'declaration_status': declarationStatus,
      'is_active': isActive,
    };
  }
}

class AcidTrackerItemModel {
  final int? importFileId;
  final String? importFileCode;
  final String? customFileNumber;
  final int? acidSessionId;
  final String? acidCode;
  final String acidNumber;
  final String importerName;
  final String supplierName;
  final String? poNumber;
  final String? piNumber;
  final String? shipmentMode;
  final String? currentStage;
  final String? customsBrokerName;

  final String? acidIssueDate;
  final String? acidExpiryDate;
  final int? executionDays;
  final int daysRemaining;
  final int totalValidityDays;
  final double validityPercentage;

  final bool isCustomsReleased;
  final String? customsReleasedAt;
  final String? releasePermitNo;

  final String status;
  final String statusLabelAr;
  final bool alertRequired;

  AcidTrackerItemModel({
    this.importFileId,
    this.importFileCode,
    this.customFileNumber,
    this.acidSessionId,
    this.acidCode,
    required this.acidNumber,
    required this.importerName,
    required this.supplierName,
    this.poNumber,
    this.piNumber,
    this.shipmentMode,
    this.currentStage,
    this.customsBrokerName,
    this.acidIssueDate,
    this.acidExpiryDate,
    this.executionDays,
    required this.daysRemaining,
    this.totalValidityDays = 90,
    required this.validityPercentage,
    this.isCustomsReleased = false,
    this.customsReleasedAt,
    this.releasePermitNo,
    required this.status,
    required this.statusLabelAr,
    required this.alertRequired,
  });

  factory AcidTrackerItemModel.fromJson(Map<String, dynamic> json) {
    return AcidTrackerItemModel(
      importFileId: json['import_file_id'],
      importFileCode: json['import_file_code'],
      customFileNumber: json['custom_file_number'],
      acidSessionId: json['acid_session_id'],
      acidCode: json['acid_code'],
      acidNumber: json['acid_number'] ?? '',
      importerName: json['importer_name'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      poNumber: json['po_number'],
      piNumber: json['pi_number'],
      shipmentMode: json['shipment_mode'],
      currentStage: json['current_stage'],
      customsBrokerName: json['customs_broker_name'],
      acidIssueDate: json['acid_issue_date'],
      acidExpiryDate: json['acid_expiry_date'],
      executionDays: json['execution_days'] as int?,
      daysRemaining: json['days_remaining'] ?? 0,
      totalValidityDays: json['total_validity_days'] ?? 90,
      validityPercentage: (json['validity_percentage'] as num?)?.toDouble() ?? 0.0,
      isCustomsReleased: json['is_customs_released'] ?? false,
      customsReleasedAt: json['customs_released_at'],
      releasePermitNo: json['release_permit_no'],
      status: json['status'] ?? 'Valid',
      statusLabelAr: json['status_label_ar'] ?? '',
      alertRequired: json['alert_required'] ?? false,
    );
  }
}

class AcidTrackerSummaryModel {
  final int totalAcidsCount;
  final int validCount;
  final int expiringSoonCount;
  final int expiredCount;
  final int customsReleasedCount;
  final int pendingIssueCount;
  final List<AcidTrackerItemModel> items;

  AcidTrackerSummaryModel({
    required this.totalAcidsCount,
    required this.validCount,
    required this.expiringSoonCount,
    required this.expiredCount,
    required this.customsReleasedCount,
    required this.pendingIssueCount,
    required this.items,
  });

  factory AcidTrackerSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    return AcidTrackerSummaryModel(
      totalAcidsCount: json['total_acids_count'] ?? 0,
      validCount: json['valid_count'] ?? 0,
      expiringSoonCount: json['expiring_soon_count'] ?? 0,
      expiredCount: json['expired_count'] ?? 0,
      customsReleasedCount: json['customs_released_count'] ?? 0,
      pendingIssueCount: json['pending_issue_count'] ?? 0,
      items: rawItems.map((i) => AcidTrackerItemModel.fromJson(i)).toList(),
    );
  }
}

// ==============================================================================
// PHASE 6: DART MODELS FOR DOCUMENT VERIFICATION & REGULATORY COMPLIANCE
// ==============================================================================

class POReconciliationItemModel {
  final int? poItemId;
  /// Packing-list row this line updates (C4). Packing rows are only updated
  /// by the backend when this is sent.
  final int? packingItemId;
  final String itemCode;
  final String description;
  final String? hsCode;
  final String packageType;
  final double initialQuantity;
  final double finalQuantity;
  final double initialUnitPrice;
  final double unitPrice;
  final double finalUnitPrice;
  final double initialPackagesCount;
  final double finalPackagesCount;
  final double initialNetWeightKg;
  final double finalNetWeightKg;
  final double initialGrossWeightKg;
  final double finalGrossWeightKg;
  final double initialCbm;
  final double finalCbm;
  final double variancePercentage;
  final double priceVariancePercentage;
  final double weightVariancePercentage;
  final String? notes;

  POReconciliationItemModel({
    this.poItemId,
    this.packingItemId,
    required this.itemCode,
    required this.description,
    this.hsCode,
    this.packageType = 'Carton',
    required this.initialQuantity,
    required this.finalQuantity,
    this.initialUnitPrice = 0.0,
    required this.unitPrice,
    this.finalUnitPrice = 0.0,
    this.initialPackagesCount = 0.0,
    this.finalPackagesCount = 0.0,
    this.initialNetWeightKg = 0.0,
    required this.finalNetWeightKg,
    this.initialGrossWeightKg = 0.0,
    required this.finalGrossWeightKg,
    this.initialCbm = 0.0,
    required this.finalCbm,
    this.variancePercentage = 0.0,
    this.priceVariancePercentage = 0.0,
    this.weightVariancePercentage = 0.0,
    this.notes,
  });

  factory POReconciliationItemModel.fromJson(Map<String, dynamic> json) {
    double initPrice = (json['initial_unit_price'] as num?)?.toDouble() ?? (json['unit_price'] as num?)?.toDouble() ?? 0.0;
    double finPrice = (json['final_unit_price'] as num?)?.toDouble() ?? (json['unit_price'] as num?)?.toDouble() ?? 0.0;

    return POReconciliationItemModel(
      poItemId: json['po_item_id'] as int?,
      packingItemId: json['packing_item_id'] as int?,
      itemCode: json['item_code'] ?? '',
      description: json['description'] ?? '',
      hsCode: json['hs_code'],
      // null = no package type recorded (PO line without a packing row): keep it empty, never invent one.
      packageType: json['package_type'] as String? ?? '',
      initialQuantity: (json['initial_quantity'] as num?)?.toDouble() ?? 0.0,
      finalQuantity: (json['final_quantity'] as num?)?.toDouble() ?? 0.0,
      initialUnitPrice: initPrice,
      unitPrice: finPrice,
      finalUnitPrice: finPrice,
      initialPackagesCount: (json['initial_packages_count'] as num?)?.toDouble() ?? 0.0,
      finalPackagesCount: (json['final_packages_count'] as num?)?.toDouble() ?? 0.0,
      initialNetWeightKg: (json['initial_net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      finalNetWeightKg: (json['final_net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      initialGrossWeightKg: (json['initial_gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      finalGrossWeightKg: (json['final_gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      initialCbm: (json['initial_cbm'] as num?)?.toDouble() ?? 0.0,
      finalCbm: (json['final_cbm'] as num?)?.toDouble() ?? 0.0,
      variancePercentage: (json['variance_percentage'] as num?)?.toDouble() ?? 0.0,
      priceVariancePercentage: (json['price_variance_percentage'] as num?)?.toDouble() ?? 0.0,
      weightVariancePercentage: (json['weight_variance_percentage'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
    );
  }

  POReconciliationItemModel copyWith({
    int? poItemId,
    int? packingItemId,
    String? itemCode,
    String? description,
    String? hsCode,
    String? packageType,
    double? initialQuantity,
    double? finalQuantity,
    double? initialUnitPrice,
    double? unitPrice,
    double? finalUnitPrice,
    double? initialPackagesCount,
    double? finalPackagesCount,
    double? initialNetWeightKg,
    double? finalNetWeightKg,
    double? initialGrossWeightKg,
    double? finalGrossWeightKg,
    double? initialCbm,
    double? finalCbm,
    double? variancePercentage,
    double? priceVariancePercentage,
    double? weightVariancePercentage,
    String? notes,
  }) {
    return POReconciliationItemModel(
      poItemId: poItemId ?? this.poItemId,
      packingItemId: packingItemId ?? this.packingItemId,
      itemCode: itemCode ?? this.itemCode,
      description: description ?? this.description,
      hsCode: hsCode ?? this.hsCode,
      packageType: packageType ?? this.packageType,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      finalQuantity: finalQuantity ?? this.finalQuantity,
      initialUnitPrice: initialUnitPrice ?? this.initialUnitPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      finalUnitPrice: finalUnitPrice ?? this.finalUnitPrice,
      initialPackagesCount: initialPackagesCount ?? this.initialPackagesCount,
      finalPackagesCount: finalPackagesCount ?? this.finalPackagesCount,
      initialNetWeightKg: initialNetWeightKg ?? this.initialNetWeightKg,
      finalNetWeightKg: finalNetWeightKg ?? this.finalNetWeightKg,
      initialGrossWeightKg: initialGrossWeightKg ?? this.initialGrossWeightKg,
      finalGrossWeightKg: finalGrossWeightKg ?? this.finalGrossWeightKg,
      initialCbm: initialCbm ?? this.initialCbm,
      finalCbm: finalCbm ?? this.finalCbm,
      variancePercentage: variancePercentage ?? this.variancePercentage,
      priceVariancePercentage: priceVariancePercentage ?? this.priceVariancePercentage,
      weightVariancePercentage: weightVariancePercentage ?? this.weightVariancePercentage,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'po_item_id': poItemId,
    if (packingItemId != null) 'packing_item_id': packingItemId,
    'item_code': itemCode,
    'description': description,
    'hs_code': hsCode,
    'package_type': packageType,
    'initial_quantity': initialQuantity,
    'final_quantity': finalQuantity,
    'initial_unit_price': initialUnitPrice,
    'unit_price': unitPrice,
    'final_unit_price': finalUnitPrice,
    'initial_packages_count': initialPackagesCount,
    'final_packages_count': finalPackagesCount,
    'initial_net_weight_kg': initialNetWeightKg,
    'final_net_weight_kg': finalNetWeightKg,
    'initial_gross_weight_kg': initialGrossWeightKg,
    'final_gross_weight_kg': finalGrossWeightKg,
    'initial_cbm': initialCbm,
    'final_cbm': finalCbm,
    'variance_percentage': variancePercentage,
    'price_variance_percentage': priceVariancePercentage,
    'weight_variance_percentage': weightVariancePercentage,
    'total_amount': finalQuantity * (finalUnitPrice > 0 ? finalUnitPrice : unitPrice),
    'notes': notes,
  };
}

class POReconciliationResultModel {
  final String status;
  final String message;
  final int importFileId;
  final String finalInvoiceNumber;
  final String finalPackingListNumber;
  final int totalItemsCount;
  final double totalNetWeightKg;
  final double totalGrossWeightKg;
  final double totalCbm;
  final double totalFinalAmount;
  final List<POReconciliationItemModel> items;

  POReconciliationResultModel({
    required this.status,
    required this.message,
    required this.importFileId,
    required this.finalInvoiceNumber,
    required this.finalPackingListNumber,
    required this.totalItemsCount,
    required this.totalNetWeightKg,
    required this.totalGrossWeightKg,
    required this.totalCbm,
    required this.totalFinalAmount,
    required this.items,
  });

  factory POReconciliationResultModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    return POReconciliationResultModel(
      status: json['status'] ?? 'success',
      message: json['message'] ?? '',
      importFileId: json['import_file_id'] ?? 0,
      finalInvoiceNumber: json['final_invoice_number'] ?? '',
      finalPackingListNumber: json['final_packing_list_number'] ?? '',
      totalItemsCount: json['total_items_count'] ?? 0,
      totalNetWeightKg: (json['total_net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      totalGrossWeightKg: (json['total_gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      totalCbm: (json['total_cbm'] as num?)?.toDouble() ?? 0.0,
      totalFinalAmount: (json['total_final_amount'] as num?)?.toDouble() ?? 0.0,
      items: rawItems.map((i) => POReconciliationItemModel.fromJson(i)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'import_file_id': importFileId,
    'final_invoice_number': finalInvoiceNumber,
    'final_packing_list_number': finalPackingListNumber,
    'total_items_count': totalItemsCount,
    'total_net_weight_kg': totalNetWeightKg,
    'total_gross_weight_kg': totalGrossWeightKg,
    'total_cbm': totalCbm,
    'total_final_amount': totalFinalAmount,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class DraftBLDiscrepancyItemModel {
  final String fieldKey;
  final String fieldLabelAr;
  final String fieldLabelEn;
  final String sourceDocument;
  final dynamic systemValue;
  final dynamic draftValue;
  final String matchStatus; // MATCH, MISMATCH_CRITICAL, MISMATCH_MINOR, MISSING_IN_DRAFT
  final String severity; // NONE, WARNING, BLOCKING
  final double tolerancePercentage;
  final String details; // English render of detailsCode (legacy rows: Arabic text, no code)
  final String? detailsCode;
  final Map<String, dynamic>? detailsParams;
  final Map<String, dynamic>? structuredValues;

  DraftBLDiscrepancyItemModel({
    required this.fieldKey,
    required this.fieldLabelAr,
    required this.fieldLabelEn,
    required this.sourceDocument,
    this.systemValue,
    this.draftValue,
    required this.matchStatus,
    required this.severity,
    this.tolerancePercentage = 0.0,
    required this.details,
    this.detailsCode,
    this.detailsParams,
    this.structuredValues,
  });

  /// The details in the language of [l10n] (stored text for legacy rows).
  String displayDetails(AppLocalizations l10n) => CodedItemText.text(_asItem(), 'details', l10n);

  /// The system value in the language of [l10n].
  String displaySystemValue(AppLocalizations l10n) =>
      CodedItemText.value(_asItem(), 'system_value', l10n, fallback: '—');

  /// The draft value in the language of [l10n].
  String displayDraftValue(AppLocalizations l10n) =>
      CodedItemText.value(_asItem(), 'draft_value', l10n, fallback: '—');

  Map<String, dynamic> _asItem() => {
        'details': details,
        'details_code': detailsCode,
        'details_params': detailsParams,
        'system_value': systemValue,
        'draft_value': draftValue,
        CodedItemText.structuredKey: structuredValues,
      };

  factory DraftBLDiscrepancyItemModel.fromJson(Map<String, dynamic> json) {
    return DraftBLDiscrepancyItemModel(
      fieldKey: json['field_key'] ?? '',
      fieldLabelAr: json['field_label_ar'] ?? '',
      fieldLabelEn: json['field_label_en'] ?? '',
      sourceDocument: json['source_document'] ?? json['source_entity'] ?? '',
      systemValue: json['system_value'],
      draftValue: json['draft_value'],
      matchStatus: json['match_status'] ?? 'MATCH',
      severity: json['severity'] ?? 'NONE',
      tolerancePercentage: (json['tolerance_percentage'] as num?)?.toDouble() ?? 0.0,
      details: json['details'] ?? '',
      detailsCode: SystemMessageRenderer.parseCode(json['details_code']),
      detailsParams: SystemMessageRenderer.parseParams(json['details_params']),
      structuredValues: SystemMessageRenderer.parseParams(json[CodedItemText.structuredKey]),
    );
  }

  Map<String, dynamic> toJson() => {
    'field_key': fieldKey,
    'field_label_ar': fieldLabelAr,
    'field_label_en': fieldLabelEn,
    'source_document': sourceDocument,
    'source_entity': sourceDocument,
    'system_value': systemValue,
    'draft_value': draftValue,
    'match_status': matchStatus,
    'severity': severity,
    'tolerance_percentage': tolerancePercentage,
    'details': details,
    'details_code': detailsCode,
    'details_params': detailsParams,
    if (structuredValues != null) CodedItemText.structuredKey: structuredValues,
  };
}

class DraftBLChecklistItemModel {
  final String fieldKey;
  final String fieldLabelAr;
  final String fieldLabelEn;
  final String sourceEntity;
  final dynamic systemValue;
  final dynamic draftValue;
  String status; // 'Correct', 'Incorrect', 'N/A'
  String? requiredCorrection;
  String? reason; // English render of reasonCode; the user's own text once edited
  String? reasonCode; // cleared when the user edits the reason
  Map<String, dynamic>? reasonParams;
  String? notes;
  String? responsibleParty;
  bool isLocked;
  String? previousStatus;

  DraftBLChecklistItemModel({
    required this.fieldKey,
    required this.fieldLabelAr,
    required this.fieldLabelEn,
    required this.sourceEntity,
    this.systemValue,
    this.draftValue,
    this.status = 'Correct',
    this.requiredCorrection,
    this.reason,
    this.reasonCode,
    this.reasonParams,
    this.notes,
    this.responsibleParty,
    this.isLocked = false,
    this.previousStatus,
  });

  /// The reason in the language of [l10n]: the system message while the code is
  /// set, the user's typed text otherwise.
  String displayReason(AppLocalizations l10n) =>
      CodedItemText.text({'reason': reason, 'reason_code': reasonCode, 'reason_params': reasonParams}, 'reason', l10n);

  factory DraftBLChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return DraftBLChecklistItemModel(
      fieldKey: json['field_key'] ?? '',
      fieldLabelAr: json['field_label_ar'] ?? '',
      fieldLabelEn: json['field_label_en'] ?? '',
      sourceEntity: json['source_entity'] ?? json['source_document'] ?? '',
      systemValue: json['system_value'],
      draftValue: json['draft_value'],
      status: json['status'] ?? 'Correct',
      requiredCorrection: json['required_correction'],
      reason: json['reason'],
      reasonCode: SystemMessageRenderer.parseCode(json['reason_code']),
      reasonParams: SystemMessageRenderer.parseParams(json['reason_params']),
      notes: json['notes'],
      responsibleParty: json['responsible_party'],
      isLocked: json['is_locked'] ?? false,
      previousStatus: json['previous_status'],
    );
  }

  Map<String, dynamic> toJson() => {
    'field_key': fieldKey,
    'field_label_ar': fieldLabelAr,
    'field_label_en': fieldLabelEn,
    'source_entity': sourceEntity,
    'system_value': systemValue,
    'draft_value': draftValue,
    'status': status,
    'required_correction': requiredCorrection,
    'reason': reason,
    'reason_code': reasonCode,
    'reason_params': reasonParams,
    'notes': notes,
    'responsible_party': responsibleParty,
    'is_locked': isLocked,
    'previous_status': previousStatus,
  };
}

class RevisionReportItemModel {
  final String item;
  final String requiredAction;
  final String responsible;
  final String? reason;
  final String? notes;

  RevisionReportItemModel({
    required this.item,
    required this.requiredAction,
    required this.responsible,
    this.reason,
    this.notes,
  });

  factory RevisionReportItemModel.fromJson(Map<String, dynamic> json) {
    return RevisionReportItemModel(
      item: json['item'] ?? '',
      requiredAction: json['required_action'] ?? '',
      responsible: json['responsible'] ?? '',
      reason: json['reason'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'item': item,
    'required_action': requiredAction,
    'responsible': responsible,
    'reason': reason,
    'notes': notes,
  };
}

/// Parses `blocking_reasons_coded`; null when absent (old rows).
List<Map<String, dynamic>>? parseBlockingReasonsCoded(dynamic raw) {
  if (raw is! List) return null;
  return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

/// Blocking reasons in the user's language: the coded list when present (and every
/// entry renders), else the stored English text. [forExport] strips bidi isolates.
List<String> displayBlockingReasons(
  AppLocalizations l10n,
  List<String> stored,
  List<Map<String, dynamic>>? coded, {
  bool forExport = false,
}) {
  var out = stored;
  if (coded != null && coded.isNotEmpty) {
    out = [
      for (var i = 0; i < coded.length; i++)
        SystemMessageRenderer.render(
          code: coded[i]['code']?.toString(),
          params: (coded[i]['params'] as Map?)?.cast<String, dynamic>(),
          part: SystemMessagePart.reason,
          l10n: l10n,
          fallback: i < stored.length ? stored[i] : '',
        ),
    ];
  }
  return forExport ? out.map(stripBidiIsolates).toList() : out;
}

class DraftBLComparisonResultModel {
  final int importFileId;
  final String stage;
  final Map<String, dynamic> systemData;
  final Map<String, dynamic> draftData;
  final List<DraftBLDiscrepancyItemModel> matrix;
  final List<DraftBLChecklistItemModel> checklist;
  final List<RevisionReportItemModel> revisionReport;
  final bool hasDiscrepancies;
  final bool hasBlockingMismatch;
  final int openDiscrepanciesCount;
  final List<String> blockingReasons;
  /// `[{code, params}]` twin of [blockingReasons] (null on old rows).
  final List<Map<String, dynamic>>? blockingReasonsCoded;
  final String status;
  final String correctionRequestLetter;

  DraftBLComparisonResultModel({
    required this.importFileId,
    this.stage = 'Stage 1: Draft Review',
    required this.systemData,
    required this.draftData,
    required this.matrix,
    this.checklist = const [],
    this.revisionReport = const [],
    required this.hasDiscrepancies,
    required this.hasBlockingMismatch,
    this.openDiscrepanciesCount = 0,
    required this.blockingReasons,
    this.blockingReasonsCoded,
    required this.status,
    required this.correctionRequestLetter,
  });

  factory DraftBLComparisonResultModel.fromJson(Map<String, dynamic> json) {
    var rawMatrix = json['comparison_matrix'] as List<dynamic>? ?? json['matrix'] as List<dynamic>? ?? [];
    var rawChecklist = json['checklist_data'] as List<dynamic>? ?? [];
    var rawRevision = json['revision_report_data'] as List<dynamic>? ?? [];
    var rawReasons = json['blocking_reasons'] as List<dynamic>? ?? [];
    return DraftBLComparisonResultModel(
      importFileId: json['import_file_id'] ?? 0,
      stage: json['stage'] ?? 'Stage 1: Draft Review',
      systemData: json['system_snapshot_data'] as Map<String, dynamic>? ?? json['system_data'] as Map<String, dynamic>? ?? {},
      draftData: json['draft_input_data'] as Map<String, dynamic>? ?? json['draft_data'] as Map<String, dynamic>? ?? {},
      matrix: rawMatrix.map((m) => DraftBLDiscrepancyItemModel.fromJson(m)).toList(),
      checklist: rawChecklist.map((c) => DraftBLChecklistItemModel.fromJson(c)).toList(),
      revisionReport: rawRevision.map((r) => RevisionReportItemModel.fromJson(r)).toList(),
      hasDiscrepancies: json['has_discrepancies'] ?? false,
      hasBlockingMismatch: json['has_blocking_mismatch'] ?? false,
      openDiscrepanciesCount: json['open_discrepancies_count'] ?? 0,
      blockingReasons: rawReasons.map((r) => r.toString()).toList(),
      blockingReasonsCoded: parseBlockingReasonsCoded(json['blocking_reasons_coded']),
      status: json['status'] ?? 'Draft',
      correctionRequestLetter: json['correction_request_letter'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'import_file_id': importFileId,
    'stage': stage,
    'system_snapshot_data': systemData,
    'draft_input_data': draftData,
    'comparison_matrix': matrix.map((m) => m.toJson()).toList(),
    'checklist_data': checklist.map((c) => c.toJson()).toList(),
    'revision_report_data': revisionReport.map((r) => r.toJson()).toList(),
    'has_discrepancies': hasDiscrepancies,
    'has_blocking_mismatch': hasBlockingMismatch,
    'open_discrepancies_count': openDiscrepanciesCount,
    'blocking_reasons': blockingReasons,
    'blocking_reasons_coded': blockingReasonsCoded,
    'status': status,
    'correction_request_letter': correctionRequestLetter,
  };
}

class DraftBLReviewModel {
  final int blReviewId;
  final String blReviewCode;
  final int? importFileId;
  final int? poId;
  final int? bookingId;
  final String draftBlNumber;
  final String? shippingLine;
  final String? vesselName;
  final String? voyageNumber;
  final String? bookingNumber;
  final String? polName;
  final String? podName;
  final String? freightTerms;
  final String? placeOfDelivery;
  final String? importerTaxId;
  final String? shipperRegId;
  final double measurementCbm;
  final double netWeightKg;
  final int packagesCount;
  final String? containerSummary;
  final int versionNumber;
  final int? parentSessionId;
  final String stage;
  final Map<String, dynamic>? systemDataSnapshot;
  final Map<String, dynamic>? draftExtractedData;
  final List<DraftBLDiscrepancyItemModel> comparisonMatrix;
  final List<DraftBLChecklistItemModel> checklistData;
  final List<RevisionReportItemModel> revisionReportData;
  final bool hasDiscrepancies;
  final bool hasBlockingMismatch;
  final int openDiscrepanciesCount;
  final List<String> blockingReasons;
  /// `[{code, params}]` twin of [blockingReasons] (null on old rows).
  final List<Map<String, dynamic>>? blockingReasonsCoded;
  final String importerApprovalStatus;
  final String? importerApprovedBy;
  final String? importerApprovalDate;
  final String? importerApprovalNotes;
  final String brokerApprovalStatus;
  final String? brokerApprovedBy;
  final String? brokerApprovalDate;
  final String? brokerApprovalNotes;
  final String status;
  final String? approvedBy;
  final String? approvedAt;
  final String? correctionRequestLetter;
  final String? notes;
  final bool isDraft;
  final bool isActive;
  final String createdAt;

  DraftBLReviewModel({
    required this.blReviewId,
    required this.blReviewCode,
    this.importFileId,
    this.poId,
    this.bookingId,
    required this.draftBlNumber,
    this.shippingLine,
    this.vesselName,
    this.voyageNumber,
    this.bookingNumber,
    this.polName,
    this.podName,
    this.freightTerms,
    this.placeOfDelivery,
    this.importerTaxId,
    this.shipperRegId,
    this.measurementCbm = 0.0,
    this.netWeightKg = 0.0,
    this.packagesCount = 0,
    this.containerSummary,
    this.versionNumber = 1,
    this.parentSessionId,
    this.stage = 'Stage 1: Draft Review',
    this.systemDataSnapshot,
    this.draftExtractedData,
    required this.comparisonMatrix,
    this.checklistData = const [],
    this.revisionReportData = const [],
    required this.hasDiscrepancies,
    required this.hasBlockingMismatch,
    this.openDiscrepanciesCount = 0,
    required this.blockingReasons,
    this.blockingReasonsCoded,
    this.importerApprovalStatus = 'Pending',
    this.importerApprovedBy,
    this.importerApprovalDate,
    this.importerApprovalNotes,
    this.brokerApprovalStatus = 'Pending',
    this.brokerApprovedBy,
    this.brokerApprovalDate,
    this.brokerApprovalNotes,
    required this.status,
    this.isDraft = false,
    this.approvedBy,
    this.approvedAt,
    this.correctionRequestLetter,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  String get version => 'v$versionNumber';

  factory DraftBLReviewModel.fromJson(Map<String, dynamic> json) {
    var rawMatrix = json['comparison_matrix'] as List<dynamic>? ?? [];
    var rawChecklist = json['checklist_data'] as List<dynamic>? ?? [];
    var rawRevision = json['revision_report_data'] as List<dynamic>? ?? [];
    var rawReasons = json['blocking_reasons'] as List<dynamic>? ?? [];
    return DraftBLReviewModel(
      blReviewId: json['bl_review_id'] ?? 0,
      blReviewCode: json['bl_review_code'] ?? '',
      importFileId: json['import_file_id'],
      poId: json['po_id'],
      bookingId: json['booking_id'],
      draftBlNumber: json['draft_bl_number'] ?? 'DRAFT-BL',
      shippingLine: json['shipping_line'],
      vesselName: json['vessel_name'],
      voyageNumber: json['voyage_number'],
      bookingNumber: json['booking_no'] ?? json['booking_number'],
      polName: json['pol'] ?? json['pol_name'],
      podName: json['pod'] ?? json['pod_name'],
      freightTerms: json['freight_terms'],
      placeOfDelivery: json['place_of_delivery'],
      importerTaxId: json['importer_tax_id'],
      shipperRegId: json['shipper_reg_id'],
      measurementCbm: (json['measurement_cbm'] as num?)?.toDouble() ?? 0.0,
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      packagesCount: (json['packages_count'] as num?)?.toInt() ?? 0,
      containerSummary: json['container_summary'],
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      parentSessionId: json['parent_session_id'],
      stage: json['stage'] ?? 'Stage 1: Draft Review',
      systemDataSnapshot: json['system_snapshot_data'] as Map<String, dynamic>? ?? json['system_data_snapshot'] as Map<String, dynamic>?,
      draftExtractedData: json['draft_input_data'] as Map<String, dynamic>? ?? json['draft_extracted_data'] as Map<String, dynamic>?,
      comparisonMatrix: rawMatrix.map((m) => DraftBLDiscrepancyItemModel.fromJson(m)).toList(),
      checklistData: rawChecklist.map((c) => DraftBLChecklistItemModel.fromJson(c)).toList(),
      revisionReportData: rawRevision.map((r) => RevisionReportItemModel.fromJson(r)).toList(),
      hasDiscrepancies: json['has_discrepancies'] ?? false,
      hasBlockingMismatch: json['has_blocking_mismatch'] ?? false,
      openDiscrepanciesCount: json['open_discrepancies_count'] ?? 0,
      blockingReasons: rawReasons.map((r) => r.toString()).toList(),
      blockingReasonsCoded: parseBlockingReasonsCoded(json['blocking_reasons_coded']),
      importerApprovalStatus: json['importer_approval_status'] ?? 'Pending',
      importerApprovedBy: json['importer_approved_by'],
      importerApprovalDate: json['importer_approval_date']?.toString(),
      importerApprovalNotes: json['importer_approval_notes'],
      brokerApprovalStatus: json['broker_approval_status'] ?? 'Pending',
      brokerApprovedBy: json['broker_approved_by'],
      brokerApprovalDate: json['broker_approval_date']?.toString(),
      brokerApprovalNotes: json['broker_approval_notes'],
      status: json['status'] ?? 'Draft',
      isDraft: json['is_draft'] == true || json['is_draft'] == 1 || json['status'] == 'DRAFT',
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at']?.toString(),
      correctionRequestLetter: json['correction_request_letter'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'bl_review_id': blReviewId,
    'bl_review_code': blReviewCode,
    'import_file_id': importFileId,
    'po_id': poId,
    'booking_id': bookingId,
    'draft_bl_number': draftBlNumber,
    'shipping_line': shippingLine,
    'vessel_name': vesselName,
    'voyage_number': voyageNumber,
    'booking_no': bookingNumber,
    'pol_name': polName,
    'pod_name': podName,
    'freight_terms': freightTerms,
    'place_of_delivery': placeOfDelivery,
    'importer_tax_id': importerTaxId,
    'shipper_reg_id': shipperRegId,
    'measurement_cbm': measurementCbm,
    'net_weight_kg': netWeightKg,
    'packages_count': packagesCount,
    'container_summary': containerSummary,
    'version_number': versionNumber,
    'parent_session_id': parentSessionId,
    'stage': stage,
    'system_snapshot_data': systemDataSnapshot,
    'draft_input_data': draftExtractedData,
    'comparison_matrix': comparisonMatrix.map((m) => m.toJson()).toList(),
    'checklist_data': checklistData.map((c) => c.toJson()).toList(),
    'revision_report_data': revisionReportData.map((r) => r.toJson()).toList(),
    'has_discrepancies': hasDiscrepancies,
    'has_blocking_mismatch': hasBlockingMismatch,
    'open_discrepancies_count': openDiscrepanciesCount,
    'blocking_reasons': blockingReasons,
    'blocking_reasons_coded': blockingReasonsCoded,
    'importer_approval_status': importerApprovalStatus,
    'importer_approved_by': importerApprovedBy,
    'importer_approval_date': importerApprovalDate,
    'importer_approval_notes': importerApprovalNotes,
    'broker_approval_status': brokerApprovalStatus,
    'broker_approved_by': brokerApprovedBy,
    'broker_approval_date': brokerApprovalDate,
    'broker_approval_notes': brokerApprovalNotes,
    'status': status,
    'is_draft': isDraft,
    'approved_by': approvedBy,
    'approved_at': approvedAt,
    'correction_request_letter': correctionRequestLetter,
    'notes': notes,
    'is_active': isActive,
    'created_at': createdAt,
  };
}

class CertificateOfOriginReviewModel {
  final int cooReviewId;
  final String cooReviewCode;
  final int? importFileId;
  final String certificateType;
  final String certificateNumber;
  final String? rawText;
  final String? documentFileUrl;
  final Map<String, dynamic>? systemSnapshotData;
  final Map<String, dynamic>? draftInputData;
  final List<dynamic> comparisonMatrix;
  final bool hasDiscrepancies;
  final bool hasCriticalMismatch;
  final String status;
  final bool isDraft;
  final String? approvedBy;
  final String? approvedAt;
  final String? notes;
  final bool isActive;
  final String createdAt;

  CertificateOfOriginReviewModel({
    required this.cooReviewId,
    required this.cooReviewCode,
    this.importFileId,
    required this.certificateType,
    required this.certificateNumber,
    this.rawText,
    this.documentFileUrl,
    this.systemSnapshotData,
    this.draftInputData,
    required this.comparisonMatrix,
    required this.hasDiscrepancies,
    required this.hasCriticalMismatch,
    required this.status,
    this.isDraft = false,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  factory CertificateOfOriginReviewModel.fromJson(Map<String, dynamic> json) {
    return CertificateOfOriginReviewModel(
      cooReviewId: json['coo_review_id'] ?? 0,
      cooReviewCode: json['coo_review_code'] ?? '',
      importFileId: json['import_file_id'],
      certificateType: json['certificate_type'] ?? 'EUR.1',
      certificateNumber: json['certificate_number'] ?? 'DRAFT-COO',
      rawText: json['raw_text'],
      documentFileUrl: json['document_file_url'],
      systemSnapshotData: json['system_snapshot_data'] as Map<String, dynamic>?,
      draftInputData: json['draft_input_data'] as Map<String, dynamic>?,
      comparisonMatrix: json['comparison_matrix'] as List<dynamic>? ?? [],
      hasDiscrepancies: json['has_discrepancies'] ?? false,
      hasCriticalMismatch: json['has_critical_mismatch'] ?? false,
      status: json['status'] ?? 'Draft',
      isDraft: json['is_draft'] == true || json['is_draft'] == 1 || json['status'] == 'Draft Generated' || json['status'] == 'DRAFT',
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'coo_review_id': cooReviewId,
    'coo_review_code': cooReviewCode,
    'import_file_id': importFileId,
    'certificate_type': certificateType,
    'certificate_number': certificateNumber,
    'raw_text': rawText,
    'document_file_url': documentFileUrl,
    'system_snapshot_data': systemSnapshotData,
    'draft_input_data': draftInputData,
    'comparison_matrix': comparisonMatrix,
    'has_discrepancies': hasDiscrepancies,
    'has_critical_mismatch': hasCriticalMismatch,
    'status': status,
    'is_draft': isDraft,
    'approved_by': approvedBy,
    'approved_at': approvedAt,
    'notes': notes,
    'is_active': isActive,
    'created_at': createdAt,
  };
}

class InspectionCertificateReviewModel {
  final int inspectionReviewId;
  final String inspectionReviewCode;
  final int? importFileId;
  final String inspectionType;
  final String inspectionAgency;
  final String certificateNumber;
  final String? rawText;
  final String? documentFileUrl;
  final Map<String, dynamic>? systemSnapshotData;
  final Map<String, dynamic>? draftInputData;
  final List<dynamic> comparisonMatrix;
  final bool hasDiscrepancies;
  final bool hasCriticalMismatch;
  final String status;
  final String? approvedBy;
  final String? approvedAt;
  final String? notes;
  final bool isActive;
  final String createdAt;

  InspectionCertificateReviewModel({
    required this.inspectionReviewId,
    required this.inspectionReviewCode,
    this.importFileId,
    required this.inspectionType,
    required this.inspectionAgency,
    required this.certificateNumber,
    this.rawText,
    this.documentFileUrl,
    this.systemSnapshotData,
    this.draftInputData,
    required this.comparisonMatrix,
    required this.hasDiscrepancies,
    required this.hasCriticalMismatch,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  factory InspectionCertificateReviewModel.fromJson(Map<String, dynamic> json) {
    return InspectionCertificateReviewModel(
      inspectionReviewId: json['inspection_review_id'] ?? 0,
      inspectionReviewCode: json['inspection_review_code'] ?? '',
      importFileId: json['import_file_id'],
      inspectionType: json['inspection_type'] ?? 'COC (Certificate of Conformity)',
      inspectionAgency: json['inspection_agency'] ?? 'SGS',
      certificateNumber: json['certificate_number'] ?? 'DRAFT-INSP',
      rawText: json['raw_text'],
      documentFileUrl: json['document_file_url'],
      systemSnapshotData: json['system_snapshot_data'] as Map<String, dynamic>?,
      draftInputData: json['draft_input_data'] as Map<String, dynamic>?,
      comparisonMatrix: json['comparison_matrix'] as List<dynamic>? ?? [],
      hasDiscrepancies: json['has_discrepancies'] ?? false,
      hasCriticalMismatch: json['has_critical_mismatch'] ?? false,
      status: json['status'] ?? 'Draft',
      approvedBy: json['approved_by'],
      approvedAt: json['approved_at'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class LegalDocAlertItemModel {
  final String docType;
  final String docNumber;
  final String expiryDate;
  final int daysUntilExpiry;
  final int daysAfterEta;
  final bool isExpired;
  final bool isCriticalBreach;
  final String alertMessage;
  final String status;

  LegalDocAlertItemModel({
    required this.docType,
    required this.docNumber,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.daysAfterEta,
    required this.isExpired,
    required this.isCriticalBreach,
    required this.alertMessage,
    required this.status,
  });

  factory LegalDocAlertItemModel.fromJson(Map<String, dynamic> json) {
    return LegalDocAlertItemModel(
      docType: json['doc_type'] ?? '',
      docNumber: json['doc_number']?.toString() ?? '—',
      expiryDate: json['expiry_date']?.toString() ?? '',
      daysUntilExpiry: json['days_until_expiry'] ?? 0,
      daysAfterEta: json['days_after_eta'] ?? 0,
      isExpired: json['is_expired'] ?? false,
      isCriticalBreach: json['is_critical_breach'] ?? false,
      alertMessage: json['alert_message'] ?? '',
      status: json['status'] ?? 'VALID',
    );
  }

  Map<String, dynamic> toJson() => {
    'doc_type': docType,
    'doc_number': docNumber,
    'expiry_date': expiryDate,
    'days_until_expiry': daysUntilExpiry,
    'days_after_eta': daysAfterEta,
    'is_expired': isExpired,
    'is_critical_breach': isCriticalBreach,
    'alert_message': alertMessage,
    'status': status,
  };
}

class LegalDocsExpiryComplianceModel {
  final int importFileId;
  final String importFileCode;
  final String companyName;
  final String etaDate;
  final String etaSource;
  final String safetyWindowDate;
  final bool hasCriticalAlerts;
  final String overallComplianceStatus;
  final String? persistentBannerText;
  final List<LegalDocAlertItemModel> alerts;

  LegalDocsExpiryComplianceModel({
    required this.importFileId,
    required this.importFileCode,
    required this.companyName,
    required this.etaDate,
    required this.etaSource,
    required this.safetyWindowDate,
    required this.hasCriticalAlerts,
    required this.overallComplianceStatus,
    this.persistentBannerText,
    required this.alerts,
  });

  factory LegalDocsExpiryComplianceModel.fromJson(Map<String, dynamic> json) {
    var rawAlerts = json['alerts'] as List<dynamic>? ?? [];
    return LegalDocsExpiryComplianceModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      companyName: json['company_name'] ?? '',
      etaDate: json['eta_date']?.toString() ?? '',
      etaSource: json['eta_source'] ?? '',
      safetyWindowDate: json['safety_window_date']?.toString() ?? '',
      hasCriticalAlerts: json['has_critical_alerts'] ?? false,
      overallComplianceStatus: json['overall_compliance_status'] ?? 'COMPLIANT',
      persistentBannerText: json['persistent_banner_text'],
      alerts: rawAlerts.map((a) => LegalDocAlertItemModel.fromJson(a)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'import_file_id': importFileId,
    'import_file_code': importFileCode,
    'company_name': companyName,
    'eta_date': etaDate,
    'eta_source': etaSource,
    'safety_window_date': safetyWindowDate,
    'has_critical_alerts': hasCriticalAlerts,
    'overall_compliance_status': overallComplianceStatus,
    'persistent_banner_text': persistentBannerText,
    'alerts': alerts.map((a) => a.toJson()).toList(),
  };
}



/// Which approval actions the draft B/L approval step offers.
enum DraftBLApprovalMode {
  /// Neither role approved yet, or the caller cannot use the single step:
  /// show the dual-approval actions (`POST /draft-bl/dual-approval`).
  dual,

  /// Exactly one role approved by somebody else: the caller completes the
  /// missing role with `POST /draft-bl/{id}/approve`.
  singleStep,
}

/// The role (`importer` / `customs_broker`) that `/approve` would complete, or
/// null when the single step is not available.
String? draftBlSingleStepRole(DraftBLReviewModel? s, {required Set<String> currentUserNames}) {
  if (s == null) return null;
  final impDone = s.importerApprovalStatus == 'Approved';
  final brkDone = s.brokerApprovalStatus == 'Approved';
  if (impDone == brkDone) return null; // none or both approved
  final approver = (impDone ? s.importerApprovedBy : s.brokerApprovedBy)?.trim().toLowerCase() ?? '';
  final me = currentUserNames.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
  if (approver.isNotEmpty && me.contains(approver)) return null; // same user would get 409
  return impDone ? 'customs_broker' : 'importer';
}

DraftBLApprovalMode draftBlApprovalMode(DraftBLReviewModel? s, {required Set<String> currentUserNames}) =>
    draftBlSingleStepRole(s, currentUserNames: currentUserNames) == null
        ? DraftBLApprovalMode.dual
        : DraftBLApprovalMode.singleStep;
