class ImportRequirementHSCodeItemModel {
  final String hsCode;
  final String? commodityDescription;
  final String? itemCode;
  final String? countryOfOrigin;
  final String? currency;
  final double itemValue;
  final double quantity;
  /// Null when the backend has no unit (no default is invented here).
  final String? unitOfMeasure;

  // Pillar 1: Decree 43 & Factory Registration
  final bool decree43Applicable;
  final bool whiteListRequired;
  final bool whiteListVerified;
  final String? factoryRegistrationNo;
  final String? decree43Action; // 'verified', 'justified', 'task_created', 'pending'
  final String? decree43Justification; // سبب الاعتماد / مبرر الاستثناء
  final String? decree43Notes;

  // Pillar 2: COO & Trade Agreements
  final bool cooRequired;
  final String? cooType;
  final String cooStatus;
  final String? cooNotes;

  // Pillar 3: Pre-Shipment Inspection
  final bool inspectionRequired;
  final String? inspectionBody;
  final String inspectionStatus;
  final String? inspectionReportNo;
  final String? inspectionNotes;

  // Pillar 4: Prior Regulatory Permits
  final bool permitRequired;
  final String? regulatoryAuthority;
  final String? permitNumber;
  final String permitStatus;
  final String? permitNotes;

  // Pillar 5: Technical Certificates
  final bool msdsRequired;
  final String msdsStatus;
  final String? msdsNotes;
  final bool halalCertRequired;
  final String halalCertStatus;
  final String? halalCertNotes;
  final bool coaRequired;
  final String coaStatus;
  final String? coaNotes;
  final String? specialNotes;
  final String? technicalNotes;

  ImportRequirementHSCodeItemModel({
    required this.hsCode,
    this.commodityDescription,
    this.itemCode,
    this.countryOfOrigin,
    this.currency,
    this.itemValue = 0.0,
    this.quantity = 1.0,
    this.unitOfMeasure,
    this.decree43Applicable = false,
    this.whiteListRequired = false,
    this.whiteListVerified = false,
    this.factoryRegistrationNo,
    this.decree43Action,
    this.decree43Justification,
    this.decree43Notes,
    this.cooRequired = false,
    this.cooType,
    this.cooStatus = 'Not Required',
    this.cooNotes,
    this.inspectionRequired = false,
    this.inspectionBody,
    this.inspectionStatus = 'Not Required',
    this.inspectionReportNo,
    this.inspectionNotes,
    this.permitRequired = false,
    this.regulatoryAuthority,
    this.permitNumber,
    this.permitStatus = 'Not Required',
    this.permitNotes,
    this.msdsRequired = false,
    this.msdsStatus = 'Not Required',
    this.msdsNotes,
    this.halalCertRequired = false,
    this.halalCertStatus = 'Not Required',
    this.halalCertNotes,
    this.coaRequired = false,
    this.coaStatus = 'Not Required',
    this.coaNotes,
    this.specialNotes,
    this.technicalNotes,
  });

  bool isPillarFulfilled(int pillarIndex) {
    switch (pillarIndex) {
      case 0:
        return !decree43Applicable || whiteListVerified || (decree43Justification != null && decree43Justification!.trim().isNotEmpty);
      case 1:
        return !cooRequired || ['Obtained', 'Waived', 'Approved', 'Verified'].contains(cooStatus);
      case 2:
        return !inspectionRequired || ['Completed', 'Approved', 'Verified'].contains(inspectionStatus);
      case 3:
        return !permitRequired || ['Approved', 'Verified'].contains(permitStatus);
      case 4:
        return (!msdsRequired || ['Obtained', 'Approved', 'Verified'].contains(msdsStatus)) &&
               (!halalCertRequired || ['Obtained', 'Approved', 'Verified'].contains(halalCertStatus)) &&
               (!coaRequired || ['Obtained', 'Approved', 'Verified'].contains(coaStatus));
      default:
        return false;
    }
  }

  int get fulfilledPillarsCount {
    int count = 0;
    for (int i = 0; i < 5; i++) {
      if (isPillarFulfilled(i)) count++;
    }
    return count;
  }

  bool get isFullyCompliant => fulfilledPillarsCount == 5;

  ImportRequirementHSCodeItemModel copyWith({
    String? hsCode,
    String? commodityDescription,
    String? itemCode,
    String? countryOfOrigin,
    String? currency,
    double? itemValue,
    double? quantity,
    String? unitOfMeasure,
    bool? decree43Applicable,
    bool? whiteListRequired,
    bool? whiteListVerified,
    String? factoryRegistrationNo,
    String? decree43Action,
    String? decree43Justification,
    String? decree43Notes,
    bool? cooRequired,
    String? cooType,
    String? cooStatus,
    String? cooNotes,
    bool? inspectionRequired,
    String? inspectionBody,
    String? inspectionStatus,
    String? inspectionReportNo,
    String? inspectionNotes,
    bool? permitRequired,
    String? regulatoryAuthority,
    String? permitNumber,
    String? permitStatus,
    String? permitNotes,
    bool? msdsRequired,
    String? msdsStatus,
    String? msdsNotes,
    bool? halalCertRequired,
    String? halalCertStatus,
    String? halalCertNotes,
    bool? coaRequired,
    String? coaStatus,
    String? coaNotes,
    String? specialNotes,
    String? technicalNotes,
  }) {
    return ImportRequirementHSCodeItemModel(
      hsCode: hsCode ?? this.hsCode,
      commodityDescription: commodityDescription ?? this.commodityDescription,
      itemCode: itemCode ?? this.itemCode,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      currency: currency ?? this.currency,
      itemValue: itemValue ?? this.itemValue,
      quantity: quantity ?? this.quantity,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      decree43Applicable: decree43Applicable ?? this.decree43Applicable,
      whiteListRequired: whiteListRequired ?? this.whiteListRequired,
      whiteListVerified: whiteListVerified ?? this.whiteListVerified,
      factoryRegistrationNo: factoryRegistrationNo ?? this.factoryRegistrationNo,
      decree43Action: decree43Action ?? this.decree43Action,
      decree43Justification: decree43Justification ?? this.decree43Justification,
      decree43Notes: decree43Notes ?? this.decree43Notes,
      cooRequired: cooRequired ?? this.cooRequired,
      cooType: cooType ?? this.cooType,
      cooStatus: cooStatus ?? this.cooStatus,
      cooNotes: cooNotes ?? this.cooNotes,
      inspectionRequired: inspectionRequired ?? this.inspectionRequired,
      inspectionBody: inspectionBody ?? this.inspectionBody,
      inspectionStatus: inspectionStatus ?? this.inspectionStatus,
      inspectionReportNo: inspectionReportNo ?? this.inspectionReportNo,
      inspectionNotes: inspectionNotes ?? this.inspectionNotes,
      permitRequired: permitRequired ?? this.permitRequired,
      regulatoryAuthority: regulatoryAuthority ?? this.regulatoryAuthority,
      permitNumber: permitNumber ?? this.permitNumber,
      permitStatus: permitStatus ?? this.permitStatus,
      permitNotes: permitNotes ?? this.permitNotes,
      msdsRequired: msdsRequired ?? this.msdsRequired,
      msdsStatus: msdsStatus ?? this.msdsStatus,
      msdsNotes: msdsNotes ?? this.msdsNotes,
      halalCertRequired: halalCertRequired ?? this.halalCertRequired,
      halalCertStatus: halalCertStatus ?? this.halalCertStatus,
      halalCertNotes: halalCertNotes ?? this.halalCertNotes,
      coaRequired: coaRequired ?? this.coaRequired,
      coaStatus: coaStatus ?? this.coaStatus,
      coaNotes: coaNotes ?? this.coaNotes,
      specialNotes: specialNotes ?? this.specialNotes,
      technicalNotes: technicalNotes ?? this.technicalNotes,
    );
  }

  factory ImportRequirementHSCodeItemModel.fromJson(Map<String, dynamic> json) {
    return ImportRequirementHSCodeItemModel(
      hsCode: json['hs_code'] ?? '',
      commodityDescription: json['commodity_description'],
      itemCode: json['item_code'],
      countryOfOrigin: json['country_of_origin'],
      currency: json['currency'],
      itemValue: (json['item_value'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitOfMeasure: json['unit_of_measure'],
      decree43Applicable: json['decree_43_applicable'] ?? false,
      whiteListRequired: json['white_list_required'] ?? false,
      whiteListVerified: json['white_list_verified'] ?? false,
      factoryRegistrationNo: json['factory_registration_no'],
      decree43Action: json['decree_43_action'],
      decree43Justification: json['decree_43_justification'],
      decree43Notes: json['decree_43_notes'],
      cooRequired: json['coo_required'] ?? false,
      cooType: json['coo_type'],
      cooStatus: json['coo_status'] ?? 'Not Required',
      cooNotes: json['coo_notes'],
      inspectionRequired: json['inspection_required'] ?? false,
      inspectionBody: json['inspection_body'],
      inspectionStatus: json['inspection_status'] ?? 'Not Required',
      inspectionReportNo: json['inspection_report_no'],
      inspectionNotes: json['inspection_notes'],
      permitRequired: json['permit_required'] ?? false,
      regulatoryAuthority: json['regulatory_authority'],
      permitNumber: json['permit_number'],
      permitStatus: json['permit_status'] ?? 'Not Required',
      permitNotes: json['permit_notes'],
      msdsRequired: json['msds_required'] ?? false,
      msdsStatus: json['msds_status'] ?? 'Not Required',
      msdsNotes: json['msds_notes'],
      halalCertRequired: json['halal_cert_required'] ?? false,
      halalCertStatus: json['halal_cert_status'] ?? 'Not Required',
      halalCertNotes: json['halal_cert_notes'],
      coaRequired: json['coa_required'] ?? false,
      coaStatus: json['coa_status'] ?? 'Not Required',
      coaNotes: json['coa_notes'],
      specialNotes: json['special_notes'],
      technicalNotes: json['technical_notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hs_code': hsCode,
      'commodity_description': commodityDescription,
      'item_code': itemCode,
      'country_of_origin': countryOfOrigin,
      'currency': currency,
      'item_value': itemValue,
      'quantity': quantity,
      'unit_of_measure': unitOfMeasure,
      'decree_43_applicable': decree43Applicable,
      'white_list_required': whiteListRequired,
      'white_list_verified': whiteListVerified,
      'factory_registration_no': factoryRegistrationNo,
      'decree_43_action': decree43Action,
      'decree_43_justification': decree43Justification,
      'decree_43_notes': decree43Notes,
      'coo_required': cooRequired,
      'coo_type': cooType,
      'coo_status': cooStatus,
      'coo_notes': cooNotes,
      'inspection_required': inspectionRequired,
      'inspection_body': inspectionBody,
      'inspection_status': inspectionStatus,
      'inspection_report_no': inspectionReportNo,
      'inspection_notes': inspectionNotes,
      'permit_required': permitRequired,
      'regulatory_authority': regulatoryAuthority,
      'permit_number': permitNumber,
      'permit_status': permitStatus,
      'permit_notes': permitNotes,
      'msds_required': msdsRequired,
      'msds_status': msdsStatus,
      'msds_notes': msdsNotes,
      'halal_cert_required': halalCertRequired,
      'halal_cert_status': halalCertStatus,
      'halal_cert_notes': halalCertNotes,
      'coa_required': coaRequired,
      'coa_status': coaStatus,
      'coa_notes': coaNotes,
      'special_notes': specialNotes,
      'technical_notes': technicalNotes,
    };
  }
}

/// A backend system message: `{code, params}`. The client renders it from the code.
class PrefillMessage {
  const PrefillMessage({required this.code, this.params = const {}, this.severity = 'warning'});

  static const noHs = 'PREFILL_NO_HS';
  static const lineNoHs = 'PREFILL_LINE_NO_HS';
  static const mixedCurrency = 'PREFILL_MIXED_CURRENCY';

  final String code;
  final Map<String, dynamic> params;

  /// `warning` (default) or `error`.
  final String severity;

  factory PrefillMessage.fromJson(Map<String, dynamic> json) => PrefillMessage(
        code: (json['code'] ?? '').toString(),
        params: json['params'] is Map ? Map<String, dynamic>.from(json['params'] as Map) : const {},
        severity: (json['severity'] ?? 'warning').toString(),
      );

  /// Tolerant list parse: null / non-list / malformed entries are skipped.
  static List<PrefillMessage> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map && e['code'] != null) PrefillMessage.fromJson(Map<String, dynamic>.from(e)),
    ];
  }
}

class ImportRequirementPrefillModel {
  final int importFileId;
  final String importFileCode;
  final String? importerName;
  final int? supplierId;
  final String? supplierName;
  final String? countryOfOrigin;
  final String? foreignExporterId;
  final String? currency;
  final double? shipmentValue;
  final String? poNumber;
  final String? piNumber;
  final String? acidNumber;
  final String? hsCode;
  final String? commodityDescription;
  final List<ImportRequirementHSCodeItemModel> hsCodeItems;

  final int? consultationId;
  final String? consultationCode;
  final String? brokerName;
  final String? consultationStatus;
  final double readinessPercentage;

  final bool decree43Applicable;
  final bool whiteListRequired;
  final bool whiteListVerified;
  final String? factoryRegistrationNo;

  final bool cooRequired;
  final String? cooType;
  final String cooStatus;
  final String? cooNotes;

  final bool inspectionRequired;
  final String? inspectionBody;
  final String inspectionStatus;
  final String? inspectionNotes;

  final bool importPermitRequired;
  final String? permitIssuingAuthority;
  final String permitStatus;
  final String? permitNotes;

  final bool msdsRequired;
  final String msdsStatus;
  final bool halalCertRequired;
  final String halalCertStatus;
  final bool coaRequired;
  final String coaStatus;
  final String? specialNotes;

  /// System messages `{code, params}` (PREFILL_NO_HS, PREFILL_LINE_NO_HS); see [PrefillMessage].
  final List<PrefillMessage> messages;

  ImportRequirementPrefillModel({
    required this.importFileId,
    required this.importFileCode,
    this.importerName,
    this.supplierId,
    this.supplierName,
    this.countryOfOrigin,
    this.foreignExporterId,
    this.currency,
    this.shipmentValue,
    this.poNumber,
    this.piNumber,
    this.acidNumber,
    this.hsCode,
    this.commodityDescription,
    this.hsCodeItems = const [],
    this.consultationId,
    this.consultationCode,
    this.brokerName,
    this.consultationStatus,
    this.readinessPercentage = 0.0,
    this.decree43Applicable = false,
    this.whiteListRequired = false,
    this.whiteListVerified = false,
    this.factoryRegistrationNo,
    this.cooRequired = false,
    this.cooType,
    this.cooStatus = 'Not Required',
    this.cooNotes,
    this.inspectionRequired = false,
    this.inspectionBody,
    this.inspectionStatus = 'Not Required',
    this.inspectionNotes,
    this.importPermitRequired = false,
    this.permitIssuingAuthority,
    this.permitStatus = 'Not Required',
    this.permitNotes,
    this.msdsRequired = false,
    this.msdsStatus = 'Not Required',
    this.halalCertRequired = false,
    this.halalCertStatus = 'Not Required',
    this.coaRequired = false,
    this.coaStatus = 'Not Required',
    this.specialNotes,
    this.messages = const [],
  });

  factory ImportRequirementPrefillModel.fromJson(Map<String, dynamic> json) {
    var rawHsItems = json['hs_code_items'];
    List<ImportRequirementHSCodeItemModel> items = [];
    if (rawHsItems is List) {
      items = rawHsItems.map((e) => ImportRequirementHSCodeItemModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    return ImportRequirementPrefillModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      importerName: json['importer_name'],
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'],
      countryOfOrigin: json['country_of_origin'],
      foreignExporterId: json['foreign_exporter_id'],
      currency: json['currency'],
      shipmentValue: (json['shipment_value'] as num?)?.toDouble(),
      poNumber: json['po_number'],
      piNumber: json['pi_number'],
      acidNumber: json['acid_number'],
      hsCode: json['hs_code'],
      commodityDescription: json['commodity_description'],
      hsCodeItems: items,
      consultationId: json['consultation_id'],
      consultationCode: json['consultation_code'],
      brokerName: json['broker_name'],
      consultationStatus: json['consultation_status'],
      readinessPercentage: (json['readiness_percentage'] as num?)?.toDouble() ?? 0.0,
      decree43Applicable: json['decree_43_applicable'] ?? false,
      whiteListRequired: json['white_list_required'] ?? false,
      whiteListVerified: json['white_list_verified'] ?? false,
      factoryRegistrationNo: json['factory_registration_no'],
      cooRequired: json['coo_required'] ?? false,
      cooType: json['coo_type'],
      cooStatus: json['coo_status'] ?? 'Not Required',
      cooNotes: json['coo_notes'],
      inspectionRequired: json['inspection_required'] ?? false,
      inspectionBody: json['inspection_body'],
      inspectionStatus: json['inspection_status'] ?? 'Not Required',
      inspectionNotes: json['inspection_notes'],
      importPermitRequired: json['import_permit_required'] ?? false,
      permitIssuingAuthority: json['permit_issuing_authority'],
      permitStatus: json['permit_status'] ?? 'Not Required',
      permitNotes: json['permit_notes'],
      msdsRequired: json['msds_required'] ?? false,
      msdsStatus: json['msds_status'] ?? 'Not Required',
      halalCertRequired: json['halal_cert_required'] ?? false,
      halalCertStatus: json['halal_cert_status'] ?? 'Not Required',
      coaRequired: json['coa_required'] ?? false,
      coaStatus: json['coa_status'] ?? 'Not Required',
      specialNotes: json['special_notes'],
      messages: PrefillMessage.listFromJson(json['messages']),
    );
  }
}

class ImportRequirementModel {
  final int? assessmentId;
  final String assessmentCode;
  final int? importFileId;
  final String? importFileCode;
  final String? hsCode;
  final String? commodityDescription;
  final String? countryOfOrigin;
  final String? currency;
  final double shipmentValue;
  final double shipmentValueUsd;
  final List<ImportRequirementHSCodeItemModel> hsCodeItems;

  // Post-ACID & Consultation confirmation fields
  final String? acidNumber;
  final int? consultationId;
  final String? consultationCode;
  final String confirmationStatus;
  final bool isPostAcidConfirmed;
  final DateTime? confirmedAt;
  final String? confirmedBy;

  // Sailing & Lifecycle Status (من إصدار ACID حتى الإبحار)
  final String sailingStatus;
  final String? sailingDate;

  // Pillar 1: Decree 43 & Foreign Suppliers
  final int? supplierId;
  final String? supplierName;
  final bool decree43Applicable;
  final bool whiteListRequired;
  final bool whiteListVerified;
  final String? factoryRegistrationNo;
  final String? decree43Action;
  final String? decree43Justification;

  // Pillar 2: Certificate of Origin (COO) & Trade Reductions
  final bool cooRequired;
  final String? cooType;
  final String cooStatus;
  final String? cooNotes;

  // Pillar 3: Pre-Shipment Inspection Certificate
  final bool inspectionRequired;
  final String? inspectionBody;
  final String inspectionStatus;
  final String? inspectionReportNo;
  final String? inspectionNotes;

  // Pillar 4: Prior Import Permit & Regulatory Authority
  final bool importPermitRequired;
  final String? permitIssuingAuthority;
  final String? permitNumber;
  final String permitStatus;
  final String? permitNotes;

  // Pillar 5: Technical & Special Certificates (MSDS / Halal / COA)
  final bool msdsRequired;
  final String msdsStatus;
  final String? msdsNotes;

  final bool halalCertRequired;
  final String halalCertStatus;
  final String? halalCertNotes;

  final bool coaRequired;
  final String coaStatus;
  final String? coaNotes;

  // Assessment Summary
  final String overallStatus;
  final String riskLevel;
  final String assessedBy;
  final String? assessmentNotes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ImportRequirementModel({
    this.assessmentId,
    required this.assessmentCode,
    this.importFileId,
    this.importFileCode,
    this.hsCode,
    this.commodityDescription,
    this.countryOfOrigin,
    this.currency,
    this.shipmentValue = 0.0,
    required this.shipmentValueUsd,
    this.hsCodeItems = const [],
    this.acidNumber,
    this.consultationId,
    this.consultationCode,
    this.confirmationStatus = 'Pending Confirmation',
    this.isPostAcidConfirmed = false,
    this.confirmedAt,
    this.confirmedBy,
    this.sailingStatus = 'Pre-Sailing',
    this.sailingDate,
    this.supplierId,
    this.supplierName,
    required this.decree43Applicable,
    required this.whiteListRequired,
    this.whiteListVerified = false,
    this.factoryRegistrationNo,
    this.decree43Action,
    this.decree43Justification,
    required this.cooRequired,
    this.cooType,
    required this.cooStatus,
    this.cooNotes,
    required this.inspectionRequired,
    this.inspectionBody,
    required this.inspectionStatus,
    this.inspectionReportNo,
    this.inspectionNotes,
    required this.importPermitRequired,
    this.permitIssuingAuthority,
    this.permitNumber,
    required this.permitStatus,
    this.permitNotes,
    required this.msdsRequired,
    required this.msdsStatus,
    this.msdsNotes,
    required this.halalCertRequired,
    required this.halalCertStatus,
    this.halalCertNotes,
    this.coaRequired = false,
    this.coaStatus = 'Not Required',
    this.coaNotes,
    required this.overallStatus,
    required this.riskLevel,
    required this.assessedBy,
    this.assessmentNotes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ImportRequirementModel.fromJson(Map<String, dynamic> json) {
    var rawHsItems = json['hs_code_items'] ?? json['other_requirements'];
    List<ImportRequirementHSCodeItemModel> items = [];
    if (rawHsItems is List) {
      items = rawHsItems
          .where((e) => e is Map && (e.containsKey('hs_code') || e.containsKey('item_value')))
          .map((e) => ImportRequirementHSCodeItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ImportRequirementModel(
      assessmentId: json['assessment_id'],
      assessmentCode: json['assessment_code'] ?? '',
      importFileId: json['import_file_id'],
      importFileCode: json['import_file_code'],
      hsCode: json['hs_code'],
      commodityDescription: json['commodity_description'],
      countryOfOrigin: json['country_of_origin'],
      currency: json['currency'],
      shipmentValue: (json['shipment_value'] ?? json['shipment_value_usd'] ?? 0.0).toDouble(),
      shipmentValueUsd: (json['shipment_value_usd'] ?? 0.0).toDouble(),
      hsCodeItems: items,
      acidNumber: json['acid_number'],
      consultationId: json['consultation_id'],
      consultationCode: json['consultation_code'],
      confirmationStatus: json['confirmation_status'] ?? 'Pending Confirmation',
      isPostAcidConfirmed: json['is_post_acid_confirmed'] ?? false,
      confirmedAt: json['confirmed_at'] != null ? DateTime.tryParse(json['confirmed_at']) : null,
      confirmedBy: json['confirmed_by'],
      sailingStatus: json['sailing_status'] ?? 'Pre-Sailing',
      sailingDate: json['sailing_date'],
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'],
      decree43Applicable: json['decree_43_applicable'] ?? false,
      whiteListRequired: json['white_list_required'] ?? false,
      whiteListVerified: json['white_list_verified'] ?? false,
      factoryRegistrationNo: json['factory_registration_no'],
      decree43Action: json['decree_43_action'],
      decree43Justification: json['decree_43_justification'],
      cooRequired: json['coo_required'] ?? false,
      cooType: json['coo_type'],
      cooStatus: json['coo_status'] ?? 'Not Required',
      cooNotes: json['coo_notes'],
      inspectionRequired: json['inspection_required'] ?? false,
      inspectionBody: json['inspection_body'],
      inspectionStatus: json['inspection_status'] ?? 'Not Required',
      inspectionReportNo: json['inspection_report_no'],
      inspectionNotes: json['inspection_notes'],
      importPermitRequired: json['import_permit_required'] ?? false,
      permitIssuingAuthority: json['permit_issuing_authority'],
      permitNumber: json['permit_number'],
      permitStatus: json['permit_status'] ?? 'Not Required',
      permitNotes: json['permit_notes'],
      msdsRequired: json['msds_required'] ?? false,
      msdsStatus: json['msds_status'] ?? 'Not Required',
      msdsNotes: json['msds_notes'],
      halalCertRequired: json['halal_cert_required'] ?? false,
      halalCertStatus: json['halal_cert_status'] ?? 'Not Required',
      halalCertNotes: json['halal_cert_notes'],
      coaRequired: json['coa_required'] ?? false,
      coaStatus: json['coa_status'] ?? 'Not Required',
      coaNotes: json['coa_notes'],
      overallStatus: json['overall_status'] ?? 'Draft',
      riskLevel: json['risk_level'] ?? 'Low',
      assessedBy: json['assessed_by'] ?? 'System',
      assessmentNotes: json['assessment_notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assessment_id': assessmentId,
      'assessment_code': assessmentCode,
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'hs_code': hsCode,
      'commodity_description': commodityDescription,
      'country_of_origin': countryOfOrigin,
      'currency': currency,
      'shipment_value': shipmentValue,
      'shipment_value_usd': shipmentValueUsd,
      'hs_code_items': hsCodeItems.map((e) => e.toJson()).toList(),
      'acid_number': acidNumber,
      'consultation_id': consultationId,
      'consultation_code': consultationCode,
      'confirmation_status': confirmationStatus,
      'is_post_acid_confirmed': isPostAcidConfirmed,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'confirmed_by': confirmedBy,
      'sailing_status': sailingStatus,
      'sailing_date': sailingDate,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'decree_43_applicable': decree43Applicable,
      'white_list_required': whiteListRequired,
      'white_list_verified': whiteListVerified,
      'factory_registration_no': factoryRegistrationNo,
      'decree_43_action': decree43Action,
      'decree_43_justification': decree43Justification,
      'coo_required': cooRequired,
      'coo_type': cooType,
      'coo_status': cooStatus,
      'coo_notes': cooNotes,
      'inspection_required': inspectionRequired,
      'inspection_body': inspectionBody,
      'inspection_status': inspectionStatus,
      'inspection_report_no': inspectionReportNo,
      'inspection_notes': inspectionNotes,
      'import_permit_required': importPermitRequired,
      'permit_issuing_authority': permitIssuingAuthority,
      'permit_number': permitNumber,
      'permit_status': permitStatus,
      'permit_notes': permitNotes,
      'msds_required': msdsRequired,
      'msds_status': msdsStatus,
      'msds_notes': msdsNotes,
      'halal_cert_required': halalCertRequired,
      'halal_cert_status': halalCertStatus,
      'halal_cert_notes': halalCertNotes,
      'coa_required': coaRequired,
      'coa_status': coaStatus,
      'coa_notes': coaNotes,
      'overall_status': overallStatus,
      'risk_level': riskLevel,
      'assessed_by': assessedBy,
      'assessment_notes': assessmentNotes,
      'is_active': isActive,
    };
  }
}
