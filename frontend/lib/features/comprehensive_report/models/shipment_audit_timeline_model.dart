class MilestoneAuditItemModel {
  final int seq;
  final String code;
  final String nameAr;
  final String nameEn;
  final int phaseNumber;
  final String? plannedDate;
  final String? actualDate;
  final int varianceDays;
  final String? tatDisplay;
  final String status;
  final String? notes;
  final bool isCriticalWatchpoint;

  const MilestoneAuditItemModel({
    required this.seq,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.phaseNumber,
    this.plannedDate,
    this.actualDate,
    this.varianceDays = 0,
    this.tatDisplay,
    this.status = 'PENDING',
    this.notes,
    this.isCriticalWatchpoint = false,
  });

  factory MilestoneAuditItemModel.fromJson(Map<String, dynamic> json) {
    return MilestoneAuditItemModel(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      code: (json['code'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: (json['name_en'] ?? '').toString(),
      phaseNumber: (json['phase_number'] as num?)?.toInt() ?? 1,
      plannedDate: json['planned_date']?.toString(),
      actualDate: json['actual_date']?.toString(),
      varianceDays: (json['variance_days'] as num?)?.toInt() ?? 0,
      tatDisplay: json['tat_display']?.toString(),
      status: (json['status'] ?? 'PENDING').toString(),
      notes: json['notes']?.toString(),
      isCriticalWatchpoint: json['is_critical_watchpoint'] == true,
    );
  }
}

class VesselTrackingPulseItemModel {
  final int updateSeq;
  final String trackingDate;
  final String vesselLocation;
  final String currentEta;
  final int delayDays;
  final String? remarks;
  final bool isAtaConfirmed;

  const VesselTrackingPulseItemModel({
    required this.updateSeq,
    required this.trackingDate,
    required this.vesselLocation,
    required this.currentEta,
    this.delayDays = 0,
    this.remarks,
    this.isAtaConfirmed = false,
  });

  factory VesselTrackingPulseItemModel.fromJson(Map<String, dynamic> json) {
    return VesselTrackingPulseItemModel(
      updateSeq: (json['update_seq'] as num?)?.toInt() ?? 0,
      trackingDate: (json['tracking_date'] ?? '').toString(),
      vesselLocation: (json['vessel_location'] ?? '').toString(),
      currentEta: (json['current_eta'] ?? '').toString(),
      delayDays: (json['delay_days'] as num?)?.toInt() ?? 0,
      remarks: json['remarks']?.toString(),
      isAtaConfirmed: json['is_ata_confirmed'] == true,
    );
  }
}

class FinancialRadarSummaryModel {
  final String? portStorageStartDate;
  final int portStorageFreeDays;
  final int? portStorageDaysRemaining;
  final String portStorageStatus;
  final String? demurrageStartDate;
  final int demurrageFreeDays;
  final int? demurrageDaysRemaining;
  final String demurrageStatus;
  final String? expectedWarehouseDeliveryDate;
  final String? actualWarehouseDeliveryDate;
  final int? warehouseVarianceDays;
  final String statusOverall;

  const FinancialRadarSummaryModel({
    this.portStorageStartDate,
    this.portStorageFreeDays = 5,
    this.portStorageDaysRemaining,
    this.portStorageStatus = 'SAFE',
    this.demurrageStartDate,
    this.demurrageFreeDays = 14,
    this.demurrageDaysRemaining,
    this.demurrageStatus = 'SAFE',
    this.expectedWarehouseDeliveryDate,
    this.actualWarehouseDeliveryDate,
    this.warehouseVarianceDays,
    this.statusOverall = 'SAFE',
  });

  factory FinancialRadarSummaryModel.fromJson(Map<String, dynamic> json) {
    return FinancialRadarSummaryModel(
      portStorageStartDate: json['port_storage_start_date']?.toString(),
      portStorageFreeDays: (json['port_storage_free_days'] as num?)?.toInt() ?? 5,
      portStorageDaysRemaining: (json['port_storage_days_remaining'] as num?)?.toInt(),
      portStorageStatus: (json['port_storage_status'] ?? 'SAFE').toString(),
      demurrageStartDate: json['demurrage_start_date']?.toString(),
      demurrageFreeDays: (json['demurrage_free_days'] as num?)?.toInt() ?? 14,
      demurrageDaysRemaining: (json['demurrage_days_remaining'] as num?)?.toInt(),
      demurrageStatus: (json['demurrage_status'] ?? 'SAFE').toString(),
      expectedWarehouseDeliveryDate: json['expected_warehouse_delivery_date']?.toString(),
      actualWarehouseDeliveryDate: json['actual_warehouse_delivery_date']?.toString(),
      warehouseVarianceDays: (json['warehouse_variance_days'] as num?)?.toInt(),
      statusOverall: (json['status_overall'] ?? 'SAFE').toString(),
    );
  }
}

class ShipmentAuditTimelineModel {
  final int importFileId;
  final String importFileCode;
  final String? customFileNumber;
  final String companyName;
  final String supplierName;
  final String? shippingLineName;
  final String? billOfLadingNo;
  final String? portOfLoading;
  final String? portOfDischarge;
  final String? containersSummary;
  final String status;
  final FinancialRadarSummaryModel financialRadar;
  final List<MilestoneAuditItemModel> milestones;
  final List<VesselTrackingPulseItemModel> vesselTrackingPulse;
  final String? meetingDirectives;

  const ShipmentAuditTimelineModel({
    required this.importFileId,
    required this.importFileCode,
    this.customFileNumber,
    required this.companyName,
    required this.supplierName,
    this.shippingLineName,
    this.billOfLadingNo,
    this.portOfLoading,
    this.portOfDischarge,
    this.containersSummary,
    this.status = 'Open',
    required this.financialRadar,
    required this.milestones,
    required this.vesselTrackingPulse,
    this.meetingDirectives,
  });

  factory ShipmentAuditTimelineModel.fromJson(Map<String, dynamic> json) {
    return ShipmentAuditTimelineModel(
      importFileId: (json['import_file_id'] as num?)?.toInt() ?? 0,
      importFileCode: (json['import_file_code'] ?? '').toString(),
      customFileNumber: json['custom_file_number']?.toString(),
      companyName: (json['company_name'] ?? '').toString(),
      supplierName: (json['supplier_name'] ?? '').toString(),
      shippingLineName: json['shipping_line_name']?.toString(),
      billOfLadingNo: json['bill_of_lading_no']?.toString(),
      portOfLoading: json['port_of_loading']?.toString(),
      portOfDischarge: json['port_of_discharge']?.toString(),
      containersSummary: json['containers_summary']?.toString(),
      status: (json['status'] ?? 'Open').toString(),
      financialRadar: json['financial_radar'] is Map<String, dynamic>
          ? FinancialRadarSummaryModel.fromJson(json['financial_radar'])
          : const FinancialRadarSummaryModel(),
      milestones: (json['milestones'] as List?)
              ?.map((m) => MilestoneAuditItemModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      vesselTrackingPulse: (json['vessel_tracking_pulse'] as List?)
              ?.map((p) => VesselTrackingPulseItemModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      meetingDirectives: json['meeting_directives']?.toString(),
    );
  }
}
