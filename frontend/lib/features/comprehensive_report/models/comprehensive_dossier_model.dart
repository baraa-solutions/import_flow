/// Models for CLO-03 Comprehensive Shipment Dossier Export
class DossierSectionSummaryModel {
  final String sectionCode;
  final String sectionNameEn;
  final String sectionNameAr;
  final String status;
  final String statusAr;
  final Map<String, dynamic> details;

  DossierSectionSummaryModel({
    required this.sectionCode,
    required this.sectionNameEn,
    required this.sectionNameAr,
    required this.status,
    required this.statusAr,
    this.details = const {},
  });

  factory DossierSectionSummaryModel.fromJson(Map<String, dynamic> json) {
    return DossierSectionSummaryModel(
      sectionCode: json['section_code'] ?? '',
      sectionNameEn: json['section_name_en'] ?? '',
      sectionNameAr: json['section_name_ar'] ?? '',
      status: json['status'] ?? 'PENDING',
      statusAr: json['status_ar'] ?? '',
      details: json['details'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'section_code': sectionCode,
      'section_name_en': sectionNameEn,
      'section_name_ar': sectionNameAr,
      'status': status,
      'status_ar': statusAr,
      'details': details,
    };
  }
}

class ComprehensiveShipmentDossierModel {
  final int importFileId;
  final String importFileCode;
  final String? customFileNumber;
  final String status;
  final String currentStage;
  final String currentModule;
  final double progressPercent;
  final String nextAction;
  final String? owner;
  final String createdAt;
  final String updatedAt;
  final String? dossierExportedAt;
  final String? dossierExportedBy;

  final int? companyId;
  final String companyName;
  final int? supplierId;
  final String supplierName;
  final int? brokerId;
  final String? brokerName;

  final String shipmentMode;
  final String incotermCode;
  final String shipmentCategory;
  final String priority;
  final String? commodity;
  final String? portOfLoading;
  final String? portOfDischarge;
  final int totalPackages;
  final double grossWeightKg;
  final double netWeightKg;
  final double totalCbm;
  final int targetFreeDays;

  final List<Map<String, dynamic>> purchaseOrders;
  final double totalFobFc;
  /// Null when the backend has no customs rate for the FOB currency (no fabricated conversion).
  final double? totalFobEgp;
  final String fobCurrency;
  final int itemsCount;
  final List<Map<String, dynamic>> itemsDetail;

  final String? acidNumber;
  final String? acidIssueDate;
  final String? acidExpiryDate;
  final String? form4No;
  final String? form4Date;
  final String? swiftNo;
  final String? form46No;
  final String? form46Date;
  final String? form46Status;
  final String? cargoxEnvelopeId;
  final String? cargoxTransferredAt;

  final String? customsDeclarationNo;
  final String? customsChannel;
  final String? customsOffice;
  final double customsDutyAmount;
  final double vatAmount;
  final double scheduleTaxAmount;
  final double totalCustomsPaid;
  final String? customsReleasePermitNo;
  final String? customsReleasedAt;

  final String? inlandCarrierName;
  final String? inlandTruckPlateNo;
  final String? inlandDriverName;
  final String? inlandActualArrivalDate;
  final String? warehouseGrnCode;
  final String? warehouseName;
  final int warehouseAcceptedQty;
  final int warehouseShortageQty;
  final int warehouseDamagedQty;
  final String? emptyContainersReturnedAt;
  final String? emptyContainersEirNumbers;

  final String? financialSettlementStatus;
  final int financialSettlementInvoicesCount;
  final double financialSettlementTotalEgp;
  final double actualLandedCostTotalEgp;
  final double actualLandedCostMarkupFactor;
  final double actualLandedCostVarianceEgp;
  final double actualLandedCostVariancePct;
  final String? actualLandedCostCalculatedAt;

  final List<DossierSectionSummaryModel> sections;
  final Map<String, bool> closureReadiness;
  final String? summaryNotes;

  ComprehensiveShipmentDossierModel({
    required this.importFileId,
    required this.importFileCode,
    this.customFileNumber,
    required this.status,
    required this.currentStage,
    required this.currentModule,
    required this.progressPercent,
    required this.nextAction,
    this.owner,
    required this.createdAt,
    required this.updatedAt,
    this.dossierExportedAt,
    this.dossierExportedBy,
    this.companyId,
    required this.companyName,
    this.supplierId,
    required this.supplierName,
    this.brokerId,
    this.brokerName,
    required this.shipmentMode,
    required this.incotermCode,
    required this.shipmentCategory,
    required this.priority,
    this.commodity,
    this.portOfLoading,
    this.portOfDischarge,
    this.totalPackages = 0,
    this.grossWeightKg = 0.0,
    this.netWeightKg = 0.0,
    this.totalCbm = 0.0,
    this.targetFreeDays = 21,
    this.purchaseOrders = const [],
    this.totalFobFc = 0.0,
    this.totalFobEgp,
    this.fobCurrency = 'USD',
    this.itemsCount = 0,
    this.itemsDetail = const [],
    this.acidNumber,
    this.acidIssueDate,
    this.acidExpiryDate,
    this.form4No,
    this.form4Date,
    this.swiftNo,
    this.form46No,
    this.form46Date,
    this.form46Status,
    this.cargoxEnvelopeId,
    this.cargoxTransferredAt,
    this.customsDeclarationNo,
    this.customsChannel,
    this.customsOffice,
    this.customsDutyAmount = 0.0,
    this.vatAmount = 0.0,
    this.scheduleTaxAmount = 0.0,
    this.totalCustomsPaid = 0.0,
    this.customsReleasePermitNo,
    this.customsReleasedAt,
    this.inlandCarrierName,
    this.inlandTruckPlateNo,
    this.inlandDriverName,
    this.inlandActualArrivalDate,
    this.warehouseGrnCode,
    this.warehouseName,
    this.warehouseAcceptedQty = 0,
    this.warehouseShortageQty = 0,
    this.warehouseDamagedQty = 0,
    this.emptyContainersReturnedAt,
    this.emptyContainersEirNumbers,
    this.financialSettlementStatus,
    this.financialSettlementInvoicesCount = 0,
    this.financialSettlementTotalEgp = 0.0,
    this.actualLandedCostTotalEgp = 0.0,
    this.actualLandedCostMarkupFactor = 1.0,
    this.actualLandedCostVarianceEgp = 0.0,
    this.actualLandedCostVariancePct = 0.0,
    this.actualLandedCostCalculatedAt,
    this.sections = const [],
    this.closureReadiness = const {},
    this.summaryNotes,
  });

  factory ComprehensiveShipmentDossierModel.fromJson(Map<String, dynamic> json) {
    var rawSections = json['sections'] as List<dynamic>? ?? [];
    var rawReadiness = json['closure_readiness'] as Map<String, dynamic>? ?? {};
    var rawPos = json['purchase_orders'] as List<dynamic>? ?? [];
    var rawItems = json['items_detail'] as List<dynamic>? ?? [];

    return ComprehensiveShipmentDossierModel(
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      customFileNumber: json['custom_file_number'],
      status: json['status'] ?? 'Open',
      currentStage: json['current_stage'] ?? '',
      currentModule: json['current_module'] ?? '',
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      nextAction: json['next_action'] ?? '',
      owner: json['owner'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      dossierExportedAt: json['dossier_exported_at'],
      dossierExportedBy: json['dossier_exported_by'],
      companyId: json['company_id'],
      companyName: json['company_name'] ?? '',
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'] ?? '',
      brokerId: json['broker_id'],
      brokerName: json['broker_name'],
      shipmentMode: json['shipment_mode'] ?? 'Sea FCL',
      incotermCode: json['incoterm_code'] ?? 'FOB',
      shipmentCategory: json['shipment_category'] ?? 'New Purchase',
      priority: json['priority'] ?? 'High',
      commodity: json['commodity'],
      portOfLoading: json['port_of_loading'],
      portOfDischarge: json['port_of_discharge'],
      totalPackages: json['total_packages'] as int? ?? 0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      totalCbm: (json['total_cbm'] as num?)?.toDouble() ?? 0.0,
      targetFreeDays: json['target_free_days'] as int? ?? 21,
      purchaseOrders: rawPos.map((p) => p as Map<String, dynamic>).toList(),
      totalFobFc: (json['total_fob_fc'] as num?)?.toDouble() ?? 0.0,
      totalFobEgp: (json['total_fob_egp'] as num?)?.toDouble(),
      fobCurrency: json['fob_currency'] ?? 'USD',
      itemsCount: json['items_count'] as int? ?? 0,
      itemsDetail: rawItems.map((i) => i as Map<String, dynamic>).toList(),
      acidNumber: json['acid_number'],
      acidIssueDate: json['acid_issue_date'],
      acidExpiryDate: json['acid_expiry_date'],
      form4No: json['form4_no'],
      form4Date: json['form4_date'],
      swiftNo: json['swift_no'],
      form46No: json['form46_no'],
      form46Date: json['form46_date'],
      form46Status: json['form46_status'],
      cargoxEnvelopeId: json['cargox_envelope_id']?.toString(),
      cargoxTransferredAt: json['cargox_transferred_at'],
      customsDeclarationNo: json['customs_declaration_no'],
      customsChannel: json['customs_channel'],
      customsOffice: json['customs_office'],
      customsDutyAmount: (json['customs_duty_amount'] as num?)?.toDouble() ?? 0.0,
      vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0.0,
      scheduleTaxAmount: (json['schedule_tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalCustomsPaid: (json['total_customs_paid'] as num?)?.toDouble() ?? 0.0,
      customsReleasePermitNo: json['customs_release_permit_no'],
      customsReleasedAt: json['customs_released_at'],
      inlandCarrierName: json['inland_carrier_name'],
      inlandTruckPlateNo: json['inland_truck_plate_no'],
      inlandDriverName: json['inland_driver_name'],
      inlandActualArrivalDate: json['inland_actual_arrival_date'],
      warehouseGrnCode: json['warehouse_grn_code'],
      warehouseName: json['warehouse_name'],
      warehouseAcceptedQty: json['warehouse_accepted_qty'] as int? ?? 0,
      warehouseShortageQty: json['warehouse_shortage_qty'] as int? ?? 0,
      warehouseDamagedQty: json['warehouse_damaged_qty'] as int? ?? 0,
      emptyContainersReturnedAt: json['empty_containers_returned_at'],
      emptyContainersEirNumbers: json['empty_containers_eir_numbers'],
      financialSettlementStatus: json['financial_settlement_status'],
      financialSettlementInvoicesCount: json['financial_settlement_invoices_count'] as int? ?? 0,
      financialSettlementTotalEgp: (json['financial_settlement_total_egp'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostTotalEgp: (json['actual_landed_cost_total_egp'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostMarkupFactor: (json['actual_landed_cost_markup_factor'] as num?)?.toDouble() ?? 1.0,
      actualLandedCostVarianceEgp: (json['actual_landed_cost_variance_egp'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostVariancePct: (json['actual_landed_cost_variance_pct'] as num?)?.toDouble() ?? 0.0,
      actualLandedCostCalculatedAt: json['actual_landed_cost_calculated_at'],
      sections: rawSections.map((s) => DossierSectionSummaryModel.fromJson(s as Map<String, dynamic>)).toList(),
      closureReadiness: rawReadiness.map((k, v) => MapEntry(k, v == true)),
      summaryNotes: json['summary_notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      if (customFileNumber != null) 'custom_file_number': customFileNumber,
      'status': status,
      'current_stage': currentStage,
      'current_module': currentModule,
      'progress_percent': progressPercent,
      'next_action': nextAction,
      if (owner != null) 'owner': owner,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (dossierExportedAt != null) 'dossier_exported_at': dossierExportedAt,
      if (dossierExportedBy != null) 'dossier_exported_by': dossierExportedBy,
      if (companyId != null) 'company_id': companyId,
      'company_name': companyName,
      if (supplierId != null) 'supplier_id': supplierId,
      'supplier_name': supplierName,
      if (brokerId != null) 'broker_id': brokerId,
      if (brokerName != null) 'broker_name': brokerName,
      'shipment_mode': shipmentMode,
      'incoterm_code': incotermCode,
      'shipment_category': shipmentCategory,
      'priority': priority,
      if (commodity != null) 'commodity': commodity,
      if (portOfLoading != null) 'port_of_loading': portOfLoading,
      if (portOfDischarge != null) 'port_of_discharge': portOfDischarge,
      'total_packages': totalPackages,
      'gross_weight_kg': grossWeightKg,
      'net_weight_kg': netWeightKg,
      'total_cbm': totalCbm,
      'target_free_days': targetFreeDays,
      'purchase_orders': purchaseOrders,
      'total_fob_fc': totalFobFc,
      'total_fob_egp': totalFobEgp,
      'fob_currency': fobCurrency,
      'items_count': itemsCount,
      'items_detail': itemsDetail,
      if (acidNumber != null) 'acid_number': acidNumber,
      if (form4No != null) 'form4_no': form4No,
      if (customsDeclarationNo != null) 'customs_declaration_no': customsDeclarationNo,
      if (warehouseGrnCode != null) 'warehouse_grn_code': warehouseGrnCode,
      if (emptyContainersEirNumbers != null) 'empty_containers_eir_numbers': emptyContainersEirNumbers,
      'actual_landed_cost_total_egp': actualLandedCostTotalEgp,
      'actual_landed_cost_markup_factor': actualLandedCostMarkupFactor,
      'actual_landed_cost_variance_egp': actualLandedCostVarianceEgp,
      'actual_landed_cost_variance_pct': actualLandedCostVariancePct,
      if (financialSettlementStatus != null) 'financial_settlement_status': financialSettlementStatus,
      'sections': sections.map((s) => s.toJson()).toList(),
      'closure_readiness': closureReadiness,
      if (summaryNotes != null) 'summary_notes': summaryNotes,
    };
  }
}

class DossierExportConfirmRequestModel {
  final int importFileId;
  final String exportedBy;
  final String exportFormat;
  final String? notes;

  DossierExportConfirmRequestModel({
    required this.importFileId,
    this.exportedBy = 'Finance & Logistics Controller',
    this.exportFormat = 'PDF & Excel Full Bundle',
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'exported_by': exportedBy,
      'export_format': exportFormat,
      if (notes != null) 'notes': notes,
    };
  }
}

class DossierExportConfirmResponseModel {
  final bool success;
  final int importFileId;
  final String importFileCode;
  final String dossierExportedAt;
  final String dossierExportedBy;
  final double progressPercent;
  final String currentStage;
  final String currentModule;
  final String nextTaskCode;
  final String nextTaskTitle;
  final String message;

  DossierExportConfirmResponseModel({
    required this.success,
    required this.importFileId,
    required this.importFileCode,
    required this.dossierExportedAt,
    required this.dossierExportedBy,
    required this.progressPercent,
    required this.currentStage,
    required this.currentModule,
    required this.nextTaskCode,
    required this.nextTaskTitle,
    required this.message,
  });

  factory DossierExportConfirmResponseModel.fromJson(Map<String, dynamic> json) {
    return DossierExportConfirmResponseModel(
      success: json['success'] ?? false,
      importFileId: json['import_file_id'] ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      dossierExportedAt: json['dossier_exported_at'] ?? '',
      dossierExportedBy: json['dossier_exported_by'] ?? '',
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      currentStage: json['current_stage'] ?? '',
      currentModule: json['current_module'] ?? '',
      nextTaskCode: json['next_task_code'] ?? '',
      nextTaskTitle: json['next_task_title'] ?? '',
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'dossier_exported_at': dossierExportedAt,
      'dossier_exported_by': dossierExportedBy,
      'progress_percent': progressPercent,
      'current_stage': currentStage,
      'current_module': currentModule,
      'next_task_code': nextTaskCode,
      'next_task_title': nextTaskTitle,
      'message': message,
    };
  }
}
