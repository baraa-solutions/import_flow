class CargoXDocumentModel {
  final int docId;
  final int envelopeId;
  final String docType;
  final String? docNumber;
  final String fileName;
  final String? fileHash;
  final double fileSizeKb;
  final bool isMandatory;
  final bool isUploaded;
  final DateTime uploadedAt;
  final bool verifiedAgainstAcid;
  final String? pkiSignature;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  CargoXDocumentModel({
    required this.docId,
    required this.envelopeId,
    required this.docType,
    this.docNumber,
    required this.fileName,
    this.fileHash,
    required this.fileSizeKb,
    required this.isMandatory,
    required this.isUploaded,
    required this.uploadedAt,
    required this.verifiedAgainstAcid,
    this.pkiSignature,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  factory CargoXDocumentModel.fromJson(Map<String, dynamic> json) {
    return CargoXDocumentModel(
      docId: json['doc_id'] as int? ?? 0,
      envelopeId: json['envelope_id'] as int? ?? 0,
      docType: json['doc_type'] as String? ?? '',
      docNumber: json['doc_number'] as String?,
      fileName: json['file_name'] as String? ?? '',
      fileHash: json['file_hash'] as String?,
      fileSizeKb: (json['file_size_kb'] as num?)?.toDouble() ?? 0.0,
      isMandatory: json['is_mandatory'] as bool? ?? true,
      isUploaded: json['is_uploaded'] as bool? ?? true,
      uploadedAt: json['uploaded_at'] != null ? DateTime.parse(json['uploaded_at']) : DateTime.now(),
      verifiedAgainstAcid: json['verified_against_acid'] as bool? ?? true,
      pkiSignature: json['pki_signature'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doc_id': docId,
      'envelope_id': envelopeId,
      'doc_type': docType,
      'doc_number': docNumber,
      'file_name': fileName,
      'file_hash': fileHash,
      'file_size_kb': fileSizeKb,
      'is_mandatory': isMandatory,
      'is_uploaded': isUploaded,
      'uploaded_at': uploadedAt.toIso8601String(),
      'verified_against_acid': verifiedAgainstAcid,
      'pki_signature': pkiSignature,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class CargoXEnvelopeModel {
  final int envelopeId;
  final String envelopeCode;
  final int? importFileId;
  final String? importFileCode;
  final String acidNumber;
  final int? importerCompanyId;
  final String importerCompanyName;
  final String? importerTaxNumber;
  final int? supplierId;
  final String supplierName;
  final String supplierCargoxId;
  final String? blNumber;
  final String status;
  final String? blockchainTxHash;
  final String? pkiSignature;
  final bool isAcidVerified;
  final bool allDocumentsSealed;
  final DateTime? transferredToCustomsAt;
  final String? customsConfirmationReceipt;
  final String? customsRejectionReason;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;
  final List<CargoXDocumentModel> documents;
  final String? integrationMode;
  final bool isSimulated;

  CargoXEnvelopeModel({
    required this.envelopeId,
    required this.envelopeCode,
    this.importFileId,
    this.importFileCode,
    required this.acidNumber,
    this.importerCompanyId,
    required this.importerCompanyName,
    this.importerTaxNumber,
    this.supplierId,
    required this.supplierName,
    required this.supplierCargoxId,
    this.blNumber,
    required this.status,
    this.blockchainTxHash,
    this.pkiSignature,
    required this.isAcidVerified,
    required this.allDocumentsSealed,
    this.transferredToCustomsAt,
    this.customsConfirmationReceipt,
    this.customsRejectionReason,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
    this.documents = const [],
    this.integrationMode,
    this.isSimulated = false,
  });

  factory CargoXEnvelopeModel.fromJson(Map<String, dynamic> json) {
    return CargoXEnvelopeModel(
      envelopeId: json['envelope_id'] as int? ?? 0,
      envelopeCode: json['envelope_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int?,
      importFileCode: json['import_file_code'] as String?,
      acidNumber: json['acid_number'] as String? ?? '',
      importerCompanyId: json['importer_company_id'] as int?,
      importerCompanyName: json['importer_company_name'] as String? ?? '',
      importerTaxNumber: json['importer_tax_number'] as String?,
      supplierId: json['supplier_id'] as int?,
      supplierName: json['supplier_name'] as String? ?? '',
      supplierCargoxId: json['supplier_cargox_id'] as String? ?? '',
      blNumber: json['bl_number'] as String?,
      status: json['status'] as String? ?? 'DRAFT',
      blockchainTxHash: json['blockchain_tx_hash'] as String?,
      pkiSignature: json['pki_signature'] as String?,
      isAcidVerified: json['is_acid_verified'] as bool? ?? false,
      allDocumentsSealed: json['all_documents_sealed'] as bool? ?? false,
      transferredToCustomsAt: json['transferred_to_customs_at'] != null ? DateTime.parse(json['transferred_to_customs_at']) : null,
      customsConfirmationReceipt: json['customs_confirmation_receipt'] as String?,
      customsRejectionReason: json['customs_rejection_reason'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      createdBy: json['created_by'] as String? ?? 'SYSTEM',
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      updatedBy: json['updated_by'] as String? ?? 'SYSTEM',
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => CargoXDocumentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      integrationMode: json['integration_mode'] as String?,
      isSimulated: json['is_simulated'] as bool? ?? (json['integration_mode'] == 'MOCK'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'envelope_id': envelopeId,
      'envelope_code': envelopeCode,
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'acid_number': acidNumber,
      'importer_company_id': importerCompanyId,
      'importer_company_name': importerCompanyName,
      'importer_tax_number': importerTaxNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'supplier_cargox_id': supplierCargoxId,
      'bl_number': blNumber,
      'status': status,
      'blockchain_tx_hash': blockchainTxHash,
      'pki_signature': pkiSignature,
      'is_acid_verified': isAcidVerified,
      'all_documents_sealed': allDocumentsSealed,
      'transferred_to_customs_at': transferredToCustomsAt?.toIso8601String(),
      'customs_confirmation_receipt': customsConfirmationReceipt,
      'customs_rejection_reason': customsRejectionReason,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
      'documents': documents.map((e) => e.toJson()).toList(),
      'integration_mode': integrationMode,
      'is_simulated': isSimulated,
    };
  }
}

class ACIDVerificationItemModel {
  final String docType;
  final String? docNumber;
  final String documentAcid;
  final bool isMatched;
  final String status;
  final String? notes;

  ACIDVerificationItemModel({
    required this.docType,
    this.docNumber,
    required this.documentAcid,
    required this.isMatched,
    required this.status,
    this.notes,
  });

  factory ACIDVerificationItemModel.fromJson(Map<String, dynamic> json) {
    return ACIDVerificationItemModel(
      docType: json['doc_type'] as String? ?? '',
      docNumber: json['doc_number'] as String?,
      documentAcid: json['document_acid'] as String? ?? '',
      isMatched: json['is_matched'] as bool? ?? false,
      status: json['status'] as String? ?? '',
      notes: json['notes'] as String?,
    );
  }
}

class CargoXAcidVerificationReportModel {
  final int envelopeId;
  final String envelopeCode;
  final String targetAcidNumber;
  final bool allMatched;
  final int verifiedCount;
  final int totalDocuments;
  final String verificationStatus;
  final List<ACIDVerificationItemModel> items;

  CargoXAcidVerificationReportModel({
    required this.envelopeId,
    required this.envelopeCode,
    required this.targetAcidNumber,
    required this.allMatched,
    required this.verifiedCount,
    required this.totalDocuments,
    required this.verificationStatus,
    this.items = const [],
  });

  factory CargoXAcidVerificationReportModel.fromJson(Map<String, dynamic> json) {
    return CargoXAcidVerificationReportModel(
      envelopeId: json['envelope_id'] as int? ?? 0,
      envelopeCode: json['envelope_code'] as String? ?? '',
      targetAcidNumber: json['target_acid_number'] as String? ?? '',
      allMatched: json['all_matched'] as bool? ?? false,
      verifiedCount: json['verified_count'] as int? ?? 0,
      totalDocuments: json['total_documents'] as int? ?? 0,
      verificationStatus: json['verification_status'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ACIDVerificationItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DigitalManifestModel {
  final int envelopeId;
  final String envelopeCode;
  final String acidNumber;
  final Map<String, dynamic> manifestJson;
  final DateTime exportedAt;
  final String formattedSummary;

  DigitalManifestModel({
    required this.envelopeId,
    required this.envelopeCode,
    required this.acidNumber,
    required this.manifestJson,
    required this.exportedAt,
    required this.formattedSummary,
  });

  factory DigitalManifestModel.fromJson(Map<String, dynamic> json) {
    return DigitalManifestModel(
      envelopeId: json['envelope_id'] as int? ?? 0,
      envelopeCode: json['envelope_code'] as String? ?? '',
      acidNumber: json['acid_number'] as String? ?? '',
      manifestJson: json['manifest_json'] as Map<String, dynamic>? ?? {},
      exportedAt: json['exported_at'] != null ? DateTime.parse(json['exported_at']) : DateTime.now(),
      formattedSummary: json['formatted_summary'] as String? ?? '',
    );
  }
}

// ============================================================================
// STANDARD EXCEL COMMERCIAL INVOICE MODELS (BP-025 / CGX-002)
// ============================================================================

class StandardInvoiceLineItemModel {
  final int index;
  final String? productCode;
  final String? manufacturer;
  final String? brandName;
  final String? model;
  final String hsCode;
  final String countryOfOrigin;
  final String description;
  final double quantity;
  final String qtyUnit;
  final String? expiryDate;
  final double unitPrice;
  final String? unitPriceBasis;
  final double grossWeightKg;
  final double netWeightKg;
  final String weightUnit;
  final double totalAmount;

  StandardInvoiceLineItemModel({
    required this.index,
    this.productCode,
    this.manufacturer,
    this.brandName,
    this.model,
    required this.hsCode,
    required this.countryOfOrigin,
    required this.description,
    required this.quantity,
    this.qtyUnit = 'PCE',
    this.expiryDate,
    required this.unitPrice,
    this.unitPriceBasis = 'PCS',
    this.grossWeightKg = 0.0,
    this.netWeightKg = 0.0,
    this.weightUnit = 'KGM',
    required this.totalAmount,
  });

  factory StandardInvoiceLineItemModel.fromJson(Map<String, dynamic> json) {
    return StandardInvoiceLineItemModel(
      index: json['index'] as int? ?? 1,
      productCode: json['product_code'] as String?,
      manufacturer: json['manufacturer'] as String?,
      brandName: json['brand_name'] as String?,
      model: json['model'] as String?,
      hsCode: json['hs_code'] as String? ?? '',
      countryOfOrigin: json['country_of_origin'] as String? ?? 'EG',
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      qtyUnit: json['qty_unit'] as String? ?? 'PCE',
      expiryDate: json['expiry_date'] as String?,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      unitPriceBasis: json['unit_price_basis'] as String? ?? 'PCS',
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      weightUnit: json['weight_unit'] as String? ?? 'KGM',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'product_code': productCode,
      'manufacturer': manufacturer,
      'brand_name': brandName,
      'model': model,
      'hs_code': hsCode,
      'country_of_origin': countryOfOrigin,
      'description': description,
      'quantity': quantity,
      'qty_unit': qtyUnit,
      'expiry_date': expiryDate,
      'unit_price': unitPrice,
      'unit_price_basis': unitPriceBasis,
      'gross_weight_kg': grossWeightKg,
      'net_weight_kg': netWeightKg,
      'weight_unit': weightUnit,
      'total_amount': totalAmount,
    };
  }
}

class StandardInvoicePayloadModel {
  final String? sellerName;
  final String? sellerAddress;
  final String? sellerCity;
  final String? sellerCityCode;
  final String? sellerCountryCode;
  final String? sellerTaxId;
  final String? sellerContactName;
  final String? sellerPhone;
  final String? sellerFax;
  final String? sellerEmail;
  final String? sellerWebsite;
  final String? buyerName;
  final String? buyerAddress;
  final String? buyerTaxId;
  final String? buyerContactName;
  final String? buyerPhone;
  final String? buyerFax;
  final String? buyerEmail;
  final String? acidNumber;
  final String invoiceType;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? purchaseOrderNumber;
  final String? purchaseOrderDate;
  final String? proformaInvoiceNumber;
  final String? originPort;
  final String? destinationPort;
  final String currencyCode;
  final String? incoterm;
  final double grossWeight;
  final double netWeight;
  final String weightUnit;
  final List<StandardInvoiceLineItemModel> items;
  final double subtotal;
  final double freightCost;
  final double insuranceCost;
  final double otherCosts;
  final double totalAmount;

  StandardInvoicePayloadModel({
    this.sellerName,
    this.sellerAddress,
    this.sellerCity,
    this.sellerCityCode,
    this.sellerCountryCode,
    this.sellerTaxId,
    this.sellerContactName,
    this.sellerPhone,
    this.sellerFax,
    this.sellerEmail,
    this.sellerWebsite,
    this.buyerName,
    this.buyerAddress,
    this.buyerTaxId,
    this.buyerContactName,
    this.buyerPhone,
    this.buyerFax,
    this.buyerEmail,
    this.acidNumber,
    this.invoiceType = 'Commercial Invoice',
    this.invoiceNumber,
    this.invoiceDate,
    this.purchaseOrderNumber,
    this.purchaseOrderDate,
    this.proformaInvoiceNumber,
    this.originPort,
    this.destinationPort,
    this.currencyCode = 'EUR',
    this.incoterm,
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
    this.weightUnit = 'KGM',
    this.items = const [],
    this.subtotal = 0.0,
    this.freightCost = 0.0,
    this.insuranceCost = 0.0,
    this.otherCosts = 0.0,
    this.totalAmount = 0.0,
  });

  factory StandardInvoicePayloadModel.fromJson(Map<String, dynamic> json) {
    return StandardInvoicePayloadModel(
      sellerName: json['seller_name'] as String?,
      sellerAddress: json['seller_address'] as String?,
      sellerCity: json['seller_city'] as String?,
      sellerCityCode: json['seller_city_code'] as String?,
      sellerCountryCode: json['seller_country_code'] as String?,
      sellerTaxId: json['seller_tax_id'] as String?,
      sellerContactName: json['seller_contact_name'] as String?,
      sellerPhone: json['seller_phone'] as String?,
      sellerFax: json['seller_fax'] as String?,
      sellerEmail: json['seller_email'] as String?,
      sellerWebsite: json['seller_website'] as String?,
      buyerName: json['buyer_name'] as String?,
      buyerAddress: json['buyer_address'] as String?,
      buyerTaxId: json['buyer_tax_id'] as String?,
      buyerContactName: json['buyer_contact_name'] as String?,
      buyerPhone: json['buyer_phone'] as String?,
      buyerFax: json['buyer_fax'] as String?,
      buyerEmail: json['buyer_email'] as String?,
      acidNumber: json['acid_number'] as String?,
      invoiceType: json['invoice_type'] as String? ?? 'Commercial Invoice',
      invoiceNumber: json['invoice_number'] as String?,
      invoiceDate: json['invoice_date'] as String?,
      purchaseOrderNumber: json['purchase_order_number'] as String?,
      purchaseOrderDate: json['purchase_order_date'] as String?,
      proformaInvoiceNumber: json['proforma_invoice_number'] as String?,
      originPort: json['origin_port'] as String?,
      destinationPort: json['destination_port'] as String?,
      currencyCode: json['currency_code'] as String? ?? 'EUR',
      incoterm: json['incoterm'] as String?,
      grossWeight: (json['gross_weight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (json['net_weight'] as num?)?.toDouble() ?? 0.0,
      weightUnit: json['weight_unit'] as String? ?? 'KGM',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => StandardInvoiceLineItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      freightCost: (json['freight_cost'] as num?)?.toDouble() ?? 0.0,
      insuranceCost: (json['insurance_cost'] as num?)?.toDouble() ?? 0.0,
      otherCosts: (json['other_costs'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seller_name': sellerName,
      'seller_address': sellerAddress,
      'seller_city': sellerCity,
      'seller_city_code': sellerCityCode,
      'seller_country_code': sellerCountryCode,
      'seller_tax_id': sellerTaxId,
      'seller_contact_name': sellerContactName,
      'seller_phone': sellerPhone,
      'seller_fax': sellerFax,
      'seller_email': sellerEmail,
      'seller_website': sellerWebsite,
      'buyer_name': buyerName,
      'buyer_address': buyerAddress,
      'buyer_tax_id': buyerTaxId,
      'buyer_contact_name': buyerContactName,
      'buyer_phone': buyerPhone,
      'buyer_fax': buyerFax,
      'buyer_email': buyerEmail,
      'acid_number': acidNumber,
      'invoice_type': invoiceType,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate,
      'purchase_order_number': purchaseOrderNumber,
      'purchase_order_date': purchaseOrderDate,
      'proforma_invoice_number': proformaInvoiceNumber,
      'origin_port': originPort,
      'destination_port': destinationPort,
      'currency_code': currencyCode,
      'incoterm': incoterm,
      'gross_weight': grossWeight,
      'net_weight': netWeight,
      'weight_unit': weightUnit,
      'items': items.map((e) => e.toJson()).toList(),
      'subtotal': subtotal,
      'freight_cost': freightCost,
      'insurance_cost': insuranceCost,
      'other_costs': otherCosts,
      'total_amount': totalAmount,
    };
  }
}

class StandardInvoiceComparisonRowModel {
  final String fieldKey;
  final String fieldLabelAr;
  final String fieldLabelEn;
  final String? systemValue;
  final String? supplierValue;
  final String status;
  final String? difference;
  final String? notes;

  StandardInvoiceComparisonRowModel({
    required this.fieldKey,
    required this.fieldLabelAr,
    required this.fieldLabelEn,
    this.systemValue,
    this.supplierValue,
    required this.status,
    this.difference,
    this.notes,
  });

  factory StandardInvoiceComparisonRowModel.fromJson(Map<String, dynamic> json) {
    return StandardInvoiceComparisonRowModel(
      fieldKey: json['field_key'] as String? ?? '',
      fieldLabelAr: json['field_label_ar'] as String? ?? '',
      fieldLabelEn: json['field_label_en'] as String? ?? '',
      systemValue: json['system_value'] as String?,
      supplierValue: json['supplier_value'] as String?,
      status: json['status'] as String? ?? 'MATCH',
      difference: json['difference'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class StandardInvoiceLineComparisonRowModel {
  final int index;
  final String productCode;
  final String? hsCodeSystem;
  final String? hsCodeSupplier;
  final String? descriptionSystem;
  final String? descriptionSupplier;
  final double qtySystem;
  final double qtySupplier;
  final double unitPriceSystem;
  final double unitPriceSupplier;
  final double totalSystem;
  final double totalSupplier;
  final double grossWeightSystem;
  final double grossWeightSupplier;
  final String status;
  final String? notes;

  StandardInvoiceLineComparisonRowModel({
    required this.index,
    required this.productCode,
    this.hsCodeSystem,
    this.hsCodeSupplier,
    this.descriptionSystem,
    this.descriptionSupplier,
    required this.qtySystem,
    required this.qtySupplier,
    required this.unitPriceSystem,
    required this.unitPriceSupplier,
    required this.totalSystem,
    required this.totalSupplier,
    required this.grossWeightSystem,
    required this.grossWeightSupplier,
    required this.status,
    this.notes,
  });

  factory StandardInvoiceLineComparisonRowModel.fromJson(Map<String, dynamic> json) {
    return StandardInvoiceLineComparisonRowModel(
      index: json['index'] as int? ?? 1,
      productCode: json['product_code'] as String? ?? '',
      hsCodeSystem: json['hs_code_system'] as String?,
      hsCodeSupplier: json['hs_code_supplier'] as String?,
      descriptionSystem: json['description_system'] as String?,
      descriptionSupplier: json['description_supplier'] as String?,
      qtySystem: (json['qty_system'] as num?)?.toDouble() ?? 0.0,
      qtySupplier: (json['qty_supplier'] as num?)?.toDouble() ?? 0.0,
      unitPriceSystem: (json['unit_price_system'] as num?)?.toDouble() ?? 0.0,
      unitPriceSupplier: (json['unit_price_supplier'] as num?)?.toDouble() ?? 0.0,
      totalSystem: (json['total_system'] as num?)?.toDouble() ?? 0.0,
      totalSupplier: (json['total_supplier'] as num?)?.toDouble() ?? 0.0,
      grossWeightSystem: (json['gross_weight_system'] as num?)?.toDouble() ?? 0.0,
      grossWeightSupplier: (json['gross_weight_supplier'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'MATCH',
      notes: json['notes'] as String?,
    );
  }
}

class StandardInvoiceComparisonResponseModel {
  final int importFileId;
  final String importFileCode;
  final String? acidNumber;
  final bool hasDiscrepancies;
  final bool hasCriticalMismatch;
  final int totalDiscrepanciesCount;
  final int criticalMismatchesCount;
  final int warningsCount;
  final List<StandardInvoiceComparisonRowModel> headerComparisons;
  final List<StandardInvoiceComparisonRowModel> financialComparisons;
  final List<StandardInvoiceLineComparisonRowModel> lineItemComparisons;
  final StandardInvoicePayloadModel? systemSnapshot;
  final StandardInvoicePayloadModel? supplierData;
  final String? rectificationNoticeEn;
  final String? rectificationNoticeAr;

  StandardInvoiceComparisonResponseModel({
    required this.importFileId,
    required this.importFileCode,
    this.acidNumber,
    required this.hasDiscrepancies,
    required this.hasCriticalMismatch,
    required this.totalDiscrepanciesCount,
    required this.criticalMismatchesCount,
    required this.warningsCount,
    this.headerComparisons = const [],
    this.financialComparisons = const [],
    this.lineItemComparisons = const [],
    this.systemSnapshot,
    this.supplierData,
    this.rectificationNoticeEn,
    this.rectificationNoticeAr,
  });

  factory StandardInvoiceComparisonResponseModel.fromJson(Map<String, dynamic> json) {
    return StandardInvoiceComparisonResponseModel(
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String? ?? '',
      acidNumber: json['acid_number'] as String?,
      hasDiscrepancies: json['has_discrepancies'] as bool? ?? false,
      hasCriticalMismatch: json['has_critical_mismatch'] as bool? ?? false,
      totalDiscrepanciesCount: json['total_discrepancies_count'] as int? ?? 0,
      criticalMismatchesCount: json['critical_mismatches_count'] as int? ?? 0,
      warningsCount: json['warnings_count'] as int? ?? 0,
      headerComparisons: (json['header_comparisons'] as List<dynamic>?)
              ?.map((e) => StandardInvoiceComparisonRowModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      financialComparisons: (json['financial_comparisons'] as List<dynamic>?)
              ?.map((e) => StandardInvoiceComparisonRowModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lineItemComparisons: (json['line_item_comparisons'] as List<dynamic>?)
              ?.map((e) => StandardInvoiceLineComparisonRowModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      systemSnapshot: json['system_snapshot'] != null
          ? StandardInvoicePayloadModel.fromJson(json['system_snapshot'] as Map<String, dynamic>)
          : null,
      supplierData: json['supplier_data'] != null
          ? StandardInvoicePayloadModel.fromJson(json['supplier_data'] as Map<String, dynamic>)
          : null,
      rectificationNoticeEn: json['rectification_notice_en'] as String?,
      rectificationNoticeAr: json['rectification_notice_ar'] as String?,
    );
  }
}

class StandardInvoiceSessionModel {
  final int sessionId;
  final String sessionCode;
  final int importFileId;
  final String importFileCode;
  final String? acidNumber;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String invoiceType;
  final int? purchaseOrderId;
  final String? purchaseOrderNumber;
  final int? supplierId;
  final String? exporterName;
  final String? exporterTaxId;
  final String? exporterCountryCode;
  final int? importerCompanyId;
  final String? importerName;
  final String? importerTaxId;
  final String currencyCode;
  final String? incoterm;
  final String? polCode;
  final String? podCode;
  final double grossWeightKg;
  final double netWeightKg;
  final String weightUnit;
  final double subtotalAmount;
  final double freightCost;
  final double insuranceCost;
  final double otherCosts;
  final double totalAmount;
  final int lineItemsCount;
  final bool hasDiscrepancies;
  final bool hasCriticalMismatch;
  final String? discrepancyOverrideReason;
  final String status;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  StandardInvoiceSessionModel({
    required this.sessionId,
    required this.sessionCode,
    required this.importFileId,
    required this.importFileCode,
    this.acidNumber,
    this.invoiceNumber,
    this.invoiceDate,
    this.invoiceType = 'Commercial Invoice',
    this.purchaseOrderId,
    this.purchaseOrderNumber,
    this.supplierId,
    this.exporterName,
    this.exporterTaxId,
    this.exporterCountryCode,
    this.importerCompanyId,
    this.importerName,
    this.importerTaxId,
    this.currencyCode = 'EUR',
    this.incoterm,
    this.polCode,
    this.podCode,
    this.grossWeightKg = 0.0,
    this.netWeightKg = 0.0,
    this.weightUnit = 'KGM',
    this.subtotalAmount = 0.0,
    this.freightCost = 0.0,
    this.insuranceCost = 0.0,
    this.otherCosts = 0.0,
    this.totalAmount = 0.0,
    this.lineItemsCount = 0,
    this.hasDiscrepancies = false,
    this.hasCriticalMismatch = false,
    this.discrepancyOverrideReason,
    this.status = 'DRAFT',
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = 'SYSTEM',
    this.updatedBy = 'SYSTEM',
  });

  factory StandardInvoiceSessionModel.fromJson(Map<String, dynamic> json) {
    return StandardInvoiceSessionModel(
      sessionId: json['session_id'] as int? ?? 0,
      sessionCode: json['session_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String? ?? '',
      acidNumber: json['acid_number'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      invoiceDate: json['invoice_date'] as String?,
      invoiceType: json['invoice_type'] as String? ?? 'Commercial Invoice',
      purchaseOrderId: json['purchase_order_id'] as int?,
      purchaseOrderNumber: json['purchase_order_number'] as String?,
      supplierId: json['supplier_id'] as int?,
      exporterName: json['exporter_name'] as String?,
      exporterTaxId: json['exporter_tax_id'] as String?,
      exporterCountryCode: json['exporter_country_code'] as String?,
      importerCompanyId: json['importer_company_id'] as int?,
      importerName: json['importer_name'] as String?,
      importerTaxId: json['importer_tax_id'] as String?,
      currencyCode: json['currency_code'] as String? ?? 'EUR',
      incoterm: json['incoterm'] as String?,
      polCode: json['pol_code'] as String?,
      podCode: json['pod_code'] as String?,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      weightUnit: json['weight_unit'] as String? ?? 'KGM',
      subtotalAmount: (json['subtotal_amount'] as num?)?.toDouble() ?? 0.0,
      freightCost: (json['freight_cost'] as num?)?.toDouble() ?? 0.0,
      insuranceCost: (json['insurance_cost'] as num?)?.toDouble() ?? 0.0,
      otherCosts: (json['other_costs'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      lineItemsCount: json['line_items_count'] as int? ?? 0,
      hasDiscrepancies: json['has_discrepancies'] as bool? ?? false,
      hasCriticalMismatch: json['has_critical_mismatch'] as bool? ?? false,
      discrepancyOverrideReason: json['discrepancy_override_reason'] as String?,
      status: json['status'] as String? ?? 'DRAFT',
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      createdBy: json['created_by'] as String? ?? 'SYSTEM',
      updatedBy: json['updated_by'] as String? ?? 'SYSTEM',
    );
  }
}

// ============================================================================
// CGX-003: MULTI-PATH EXTRACTION & CUSTOMS TRACK MODELS
// ============================================================================

class ExtractionResultItemModel {
  final String? invoiceNumber;
  final StandardInvoicePayloadModel payload;

  const ExtractionResultItemModel({
    this.invoiceNumber,
    required this.payload,
  });

  factory ExtractionResultItemModel.fromJson(Map<String, dynamic> json) {
    return ExtractionResultItemModel(
      invoiceNumber: json['invoice_number'] as String?,
      payload: StandardInvoicePayloadModel.fromJson(json['payload'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_number': invoiceNumber,
      'payload': payload.toJson(),
    };
  }
}

class ExtractionResponseModel {
  final int importFileId;
  final String importFileCode;
  final String mode;
  final String groupingMode;
  final int invoicesCount;
  final int totalLineItems;
  final List<ExtractionResultItemModel> results;

  const ExtractionResponseModel({
    required this.importFileId,
    required this.importFileCode,
    required this.mode,
    required this.groupingMode,
    required this.invoicesCount,
    required this.totalLineItems,
    required this.results,
  });

  factory ExtractionResponseModel.fromJson(Map<String, dynamic> json) {
    return ExtractionResponseModel(
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String? ?? '',
      mode: json['mode'] as String? ?? 'all_consolidated',
      groupingMode: json['grouping_mode'] as String? ?? 'by_hs_code',
      invoicesCount: json['invoices_count'] as int? ?? 1,
      totalLineItems: json['total_line_items'] as int? ?? 0,
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => ExtractionResultItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CustomsInvoiceTrackModel {
  final int trackId;
  final String trackCode;
  final int importFileId;
  final String? importFileCode;
  final List<String> sourceInvoiceNumbers;
  final String extractionMode;
  final String groupingMode;
  // CGX-004: Packing List fields
  final String? packingListMode;
  final String? packingListStructure;
  final int? packingListCount;
  final bool includePallets;
  // Totals
  final double customsTotalAmount;
  final double customsGrossWeight;
  final double customsNetWeight;
  final int customsPackagesCount;
  final int lineItemsCount;
  final dynamic customsInvoiceData;
  final dynamic customsPackingListData;
  final String status;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  const CustomsInvoiceTrackModel({
    required this.trackId,
    required this.trackCode,
    required this.importFileId,
    this.importFileCode,
    this.sourceInvoiceNumbers = const [],
    required this.extractionMode,
    required this.groupingMode,
    this.packingListMode,
    this.packingListStructure,
    this.packingListCount,
    this.includePallets = false,
    this.customsTotalAmount = 0.0,
    this.customsGrossWeight = 0.0,
    this.customsNetWeight = 0.0,
    this.customsPackagesCount = 0,
    this.lineItemsCount = 0,
    this.customsInvoiceData,
    this.customsPackingListData,
    this.status = 'DRAFT',
    this.notes,
    this.isActive = true,
    required this.createdAt,
    this.createdBy = 'SYSTEM',
  });

  factory CustomsInvoiceTrackModel.fromJson(Map<String, dynamic> json) {
    return CustomsInvoiceTrackModel(
      trackId: json['track_id'] as int? ?? 0,
      trackCode: json['track_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String?,
      sourceInvoiceNumbers: (json['source_invoice_numbers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      extractionMode: json['extraction_mode'] as String? ?? 'all_consolidated',
      groupingMode: json['grouping_mode'] as String? ?? 'by_hs_code',
      packingListMode: json['packing_list_mode'] as String?,
      packingListStructure: json['packing_list_structure'] as String?,
      packingListCount: json['packing_list_count'] as int?,
      includePallets: json['include_pallets'] as bool? ?? false,
      customsTotalAmount: (json['customs_total_amount'] as num?)?.toDouble() ?? 0.0,
      customsGrossWeight: (json['customs_gross_weight'] as num?)?.toDouble() ?? 0.0,
      customsNetWeight: (json['customs_net_weight'] as num?)?.toDouble() ?? 0.0,
      customsPackagesCount: json['customs_packages_count'] as int? ?? 0,
      lineItemsCount: json['line_items_count'] as int? ?? 0,
      customsInvoiceData: json['customs_invoice_data'],
      customsPackingListData: json['customs_packing_list_data'],
      status: json['status'] as String? ?? 'DRAFT',
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      createdBy: json['created_by'] as String? ?? 'SYSTEM',
    );
  }
}

// ============================================================================
// CGX-004: Packing List Models
// ============================================================================

class PackingListLineItemModel {
  final int lineNumber;
  final String packageRef;
  final String hsCode;
  final String description;
  final String? manufacturer;
  final double quantity;
  final String qtyUnit;
  final double netWeightKg;
  final double grossWeightKg;
  final String? invoiceNumber;
  final String? palletNumber;
  final String? cartonNumbers;
  final String? dimensionsCm;

  const PackingListLineItemModel({
    required this.lineNumber,
    required this.packageRef,
    required this.hsCode,
    required this.description,
    this.manufacturer,
    required this.quantity,
    required this.qtyUnit,
    required this.netWeightKg,
    required this.grossWeightKg,
    this.invoiceNumber,
    this.palletNumber,
    this.cartonNumbers,
    this.dimensionsCm,
  });

  factory PackingListLineItemModel.fromJson(Map<String, dynamic> json) {
    return PackingListLineItemModel(
      lineNumber: json['line_number'] as int? ?? 0,
      packageRef: json['package_ref'] as String? ?? '',
      hsCode: json['hs_code'] as String? ?? '',
      description: json['description'] as String? ?? '',
      manufacturer: json['manufacturer'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      qtyUnit: json['qty_unit'] as String? ?? 'PCS',
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      invoiceNumber: json['invoice_number'] as String?,
      palletNumber: json['pallet_number'] as String?,
      cartonNumbers: json['carton_numbers'] as String?,
      dimensionsCm: json['dimensions_cm'] as String?,
    );
  }
}

class PackingListPayloadModel {
  final String? acidNumber;
  final String? sellerName;
  final String? buyerName;
  final String? invoiceNumber;
  final String? packingListRef;
  final String? originPort;
  final String? destinationPort;
  final int totalPackages;
  final double totalGrossWeightKg;
  final double totalNetWeightKg;
  final String structure;
  final List<PackingListLineItemModel> items;

  const PackingListPayloadModel({
    this.acidNumber,
    this.sellerName,
    this.buyerName,
    this.invoiceNumber,
    this.packingListRef,
    this.originPort,
    this.destinationPort,
    this.totalPackages = 0,
    this.totalGrossWeightKg = 0.0,
    this.totalNetWeightKg = 0.0,
    this.structure = 'by_hs_code',
    this.items = const [],
  });

  factory PackingListPayloadModel.fromJson(Map<String, dynamic> json) {
    return PackingListPayloadModel(
      acidNumber: json['acid_number'] as String?,
      sellerName: json['seller_name'] as String?,
      buyerName: json['buyer_name'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      packingListRef: json['packing_list_ref'] as String?,
      originPort: json['origin_port'] as String?,
      destinationPort: json['destination_port'] as String?,
      totalPackages: json['total_packages'] as int? ?? 0,
      totalGrossWeightKg: (json['total_gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      totalNetWeightKg: (json['total_net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      structure: json['structure'] as String? ?? 'by_hs_code',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PackingListLineItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PackingListResultItemModel {
  final String? packingListRef;
  final String? invoiceNumber;
  final PackingListPayloadModel payload;

  const PackingListResultItemModel({
    this.packingListRef,
    this.invoiceNumber,
    required this.payload,
  });

  factory PackingListResultItemModel.fromJson(Map<String, dynamic> json) {
    return PackingListResultItemModel(
      packingListRef: json['packing_list_ref'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      payload: PackingListPayloadModel.fromJson(
          json['payload'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class DualExtractionResponseModel {
  final int importFileId;
  final String? importFileCode;
  final String invoiceMode;
  final String invoiceGrouping;
  final int invoiceInvoicesCount;
  final int invoiceTotalLineItems;
  final String packingListMode;
  final String packingListStructure;
  final int packingListCount;
  final int packingListTotalItems;
  final List<PackingListResultItemModel> packingListResults;

  const DualExtractionResponseModel({
    required this.importFileId,
    this.importFileCode,
    required this.invoiceMode,
    required this.invoiceGrouping,
    required this.invoiceInvoicesCount,
    required this.invoiceTotalLineItems,
    required this.packingListMode,
    required this.packingListStructure,
    required this.packingListCount,
    required this.packingListTotalItems,
    this.packingListResults = const [],
  });

  factory DualExtractionResponseModel.fromJson(Map<String, dynamic> json) {
    return DualExtractionResponseModel(
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String?,
      invoiceMode: json['invoice_mode'] as String? ?? 'all_consolidated',
      invoiceGrouping: json['invoice_grouping'] as String? ?? 'by_hs_code',
      invoiceInvoicesCount: json['invoice_invoices_count'] as int? ?? 0,
      invoiceTotalLineItems: json['invoice_total_line_items'] as int? ?? 0,
      packingListMode: json['packing_list_mode'] as String? ?? 'all_consolidated',
      packingListStructure: json['packing_list_structure'] as String? ?? 'by_hs_code',
      packingListCount: json['packing_list_count'] as int? ?? 0,
      packingListTotalItems: json['packing_list_total_items'] as int? ?? 0,
      packingListResults: (json['packing_list_results'] as List<dynamic>?)
              ?.map((e) => PackingListResultItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PalletItemInputModel {
  final String hsCode;
  final String description;
  final double quantity;
  final String qtyUnit;
  final double netWeightKg;
  final double grossWeightKg;
  final String? cartonNumbers;

  const PalletItemInputModel({
    required this.hsCode,
    required this.description,
    required this.quantity,
    this.qtyUnit = 'PCS',
    required this.netWeightKg,
    required this.grossWeightKg,
    this.cartonNumbers,
  });

  Map<String, dynamic> toJson() => {
        'hs_code': hsCode,
        'description': description,
        'quantity': quantity,
        'qty_unit': qtyUnit,
        'net_weight_kg': netWeightKg,
        'gross_weight_kg': grossWeightKg,
        if (cartonNumbers != null) 'carton_numbers': cartonNumbers,
      };
}

class PalletInputModel {
  final String palletNumber;
  final String palletType;
  final String? dimensionsCm;
  final double grossWeightKg;
  final double netWeightKg;
  final List<PalletItemInputModel> items;

  const PalletInputModel({
    required this.palletNumber,
    this.palletType = 'EURO',
    this.dimensionsCm,
    required this.grossWeightKg,
    required this.netWeightKg,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
        'pallet_number': palletNumber,
        'pallet_type': palletType,
        if (dimensionsCm != null) 'dimensions_cm': dimensionsCm,
        'gross_weight_kg': grossWeightKg,
        'net_weight_kg': netWeightKg,
        'items': items.map((e) => e.toJson()).toList(),
      };
}


