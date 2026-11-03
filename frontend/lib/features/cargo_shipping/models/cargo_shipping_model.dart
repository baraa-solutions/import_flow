import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

class ContainerLoadingModel {
  final String containerType;
  final int quantity;
  final String containerNo;
  final String sealNo;
  final double tareWeightKg;
  final double netWeightKg;
  final double grossWeightKg;
  final String vgmStatus;
  final String? vgmRefNo;
  final List<Map<String, String>> individualUnits;

  // 5-Milestones Tracking & 48h SLA fields
  final String? containerAssignmentDate;
  final String? arrivalAtSupplierAt;
  final String? loadingStartAt;
  final String? loadingEndAt;
  final String? portGateInAt;
  final String? slaDeadlineAt;
  final bool isSlaBreached;
  final String trackingStatus;
  final List<Map<String, dynamic>> trackingHistory;
  final Map<String, String> milestoneNotes;

  ContainerLoadingModel({
    this.containerType = '40HC',
    this.quantity = 1,
    required this.containerNo,
    required this.sealNo,
    this.tareWeightKg = 0.0,
    this.netWeightKg = 0.0,
    this.grossWeightKg = 0.0,
    this.vgmStatus = "Submitted",
    this.vgmRefNo,
    this.individualUnits = const [],
    this.containerAssignmentDate,
    this.arrivalAtSupplierAt,
    this.loadingStartAt,
    this.loadingEndAt,
    this.portGateInAt,
    this.slaDeadlineAt,
    this.isSlaBreached = false,
    this.trackingStatus = "PENDING_ASSIGNMENT",
    this.trackingHistory = const [],
    this.milestoneNotes = const {},
  });

  factory ContainerLoadingModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> notesMap = {};
    if (json['milestone_notes'] != null && json['milestone_notes'] is Map) {
      (json['milestone_notes'] as Map).forEach((k, v) {
        if (v != null) notesMap[k.toString()] = v.toString();
      });
    }

    return ContainerLoadingModel(
      containerType: json['container_type'] ?? '40HC',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      containerNo: json['container_no'] ?? '',
      sealNo: json['seal_no'] ?? '',
      tareWeightKg: (json['tare_weight_kg'] as num?)?.toDouble() ?? 0.0,
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      vgmStatus: json['vgm_status'] ?? 'Submitted',
      vgmRefNo: json['vgm_ref_no'],
      individualUnits: (json['individual_units'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      containerAssignmentDate: json['container_assignment_date'],
      arrivalAtSupplierAt: json['arrival_at_supplier_at'],
      loadingStartAt: json['loading_start_at'],
      loadingEndAt: json['loading_end_at'],
      portGateInAt: json['port_gate_in_at'],
      slaDeadlineAt: json['sla_deadline_at'],
      isSlaBreached: json['is_sla_breached'] ?? false,
      trackingStatus: json['tracking_status'] ?? 'PENDING_ASSIGNMENT',
      trackingHistory: (json['tracking_history'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      milestoneNotes: notesMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'container_type': containerType,
      'quantity': quantity,
      'container_no': containerNo,
      'seal_no': sealNo,
      'tare_weight_kg': tareWeightKg,
      'net_weight_kg': netWeightKg,
      'gross_weight_kg': grossWeightKg,
      'vgm_status': vgmStatus,
      'vgm_ref_no': vgmRefNo,
      'individual_units': individualUnits,
      'container_assignment_date': containerAssignmentDate,
      'arrival_at_supplier_at': arrivalAtSupplierAt,
      'loading_start_at': loadingStartAt,
      'loading_end_at': loadingEndAt,
      'port_gate_in_at': portGateInAt,
      'sla_deadline_at': slaDeadlineAt,
      'is_sla_breached': isSlaBreached,
      'tracking_status': trackingStatus,
      'tracking_history': trackingHistory,
      'milestone_notes': milestoneNotes,
    };
  }

  ContainerLoadingModel copyWith({
    String? containerType,
    int? quantity,
    String? containerNo,
    String? sealNo,
    double? tareWeightKg,
    double? netWeightKg,
    double? grossWeightKg,
    String? vgmStatus,
    String? vgmRefNo,
    List<Map<String, String>>? individualUnits,
    String? containerAssignmentDate,
    String? arrivalAtSupplierAt,
    String? loadingStartAt,
    String? loadingEndAt,
    String? portGateInAt,
    String? slaDeadlineAt,
    bool? isSlaBreached,
    String? trackingStatus,
    List<Map<String, dynamic>>? trackingHistory,
    Map<String, String>? milestoneNotes,
  }) {
    return ContainerLoadingModel(
      containerType: containerType ?? this.containerType,
      quantity: quantity ?? this.quantity,
      containerNo: containerNo ?? this.containerNo,
      sealNo: sealNo ?? this.sealNo,
      tareWeightKg: tareWeightKg ?? this.tareWeightKg,
      netWeightKg: netWeightKg ?? this.netWeightKg,
      grossWeightKg: grossWeightKg ?? this.grossWeightKg,
      vgmStatus: vgmStatus ?? this.vgmStatus,
      vgmRefNo: vgmRefNo ?? this.vgmRefNo,
      individualUnits: individualUnits ?? this.individualUnits,
      containerAssignmentDate: containerAssignmentDate ?? this.containerAssignmentDate,
      arrivalAtSupplierAt: arrivalAtSupplierAt ?? this.arrivalAtSupplierAt,
      loadingStartAt: loadingStartAt ?? this.loadingStartAt,
      loadingEndAt: loadingEndAt ?? this.loadingEndAt,
      portGateInAt: portGateInAt ?? this.portGateInAt,
      slaDeadlineAt: slaDeadlineAt ?? this.slaDeadlineAt,
      isSlaBreached: isSlaBreached ?? this.isSlaBreached,
      trackingStatus: trackingStatus ?? this.trackingStatus,
      trackingHistory: trackingHistory ?? this.trackingHistory,
      milestoneNotes: milestoneNotes ?? this.milestoneNotes,
    );
  }

  int get progressStepIndex {
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
        return 5;
      case 'LOADING_COMPLETED':
        return 4;
      case 'LOADING_IN_PROGRESS':
        return 3;
      case 'ARRIVED_AT_SUPPLIER':
      case 'ARRIVED_AT_CFS':
        return 2;
      case 'ASSIGNED':
      case 'EN_ROUTE_TO_SUPPLIER':
        return 1;
      default:
        return 0;
    }
  }

  String getLocalizedStatus(AppLocalizations l10n) {
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
        return l10n.cargoShippingStatusGatedIn;
      case 'LOADING_COMPLETED':
        return l10n.cargoShippingStatusLoadingCompleted;
      case 'LOADING_IN_PROGRESS':
        return l10n.cargoShippingStatusLoadingInProgress;
      case 'ARRIVED_AT_SUPPLIER':
        return l10n.cargoShippingStatusArrivedAtSupplier;
      case 'ASSIGNED':
        return l10n.cargoShippingStatusAssigned;
      default:
        return l10n.cargoShippingStatusPendingAssignment;
    }
  }

  String get arabicStatusLabel {
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
        return 'دخلت الميناء';
      case 'LOADING_COMPLETED':
        return 'اكتمل التحميل';
      case 'LOADING_IN_PROGRESS':
        return 'جاري التحميل';
      case 'ARRIVED_AT_SUPPLIER':
        return 'وصلت لدى المورد';
      case 'ASSIGNED':
        return 'تم التخصيص';
      default:
        return 'قيد التخصيص';
    }
  }

  Color get statusColor {
    if (isSlaBreached) return AppTheme.crimson;
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
        return AppTheme.emerald;
      case 'LOADING_COMPLETED':
        return AppTheme.emerald;
      case 'LOADING_IN_PROGRESS':
      case 'ARRIVED_AT_SUPPLIER':
        return AppTheme.orange;
      case 'ASSIGNED':
        return AppTheme.cobalt;
      default:
        return AppTheme.textSecondary;
    }
  }

  /// Severity of the tracking status (SLA breach wins) for status chips.
  AppSeverity get statusSeverity {
    if (isSlaBreached) return AppSeverity.danger;
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
      case 'LOADING_COMPLETED':
        return AppSeverity.success;
      case 'LOADING_IN_PROGRESS':
      case 'ARRIVED_AT_SUPPLIER':
        return AppSeverity.warning;
      default:
        return AppSeverity.info;
    }
  }
}

class LclLoadingTrackingModel {
  final String shipmentType;
  final String? cfsWarehouseName;
  final String? consolidationScheduledDate;
  final String? arrivalAtCfsAt;
  final String? stuffingStartAt;
  final String? stuffingEndAt;
  final String? portGateInAt;
  final String? slaDeadlineAt;
  final bool isSlaBreached;
  final String trackingStatus;
  final List<Map<String, dynamic>> trackingHistory;

  LclLoadingTrackingModel({
    this.shipmentType = 'LCL',
    this.cfsWarehouseName,
    this.consolidationScheduledDate,
    this.arrivalAtCfsAt,
    this.stuffingStartAt,
    this.stuffingEndAt,
    this.portGateInAt,
    this.slaDeadlineAt,
    this.isSlaBreached = false,
    this.trackingStatus = 'PENDING_ASSIGNMENT',
    this.trackingHistory = const [],
  });

  factory LclLoadingTrackingModel.fromJson(Map<String, dynamic> json) {
    return LclLoadingTrackingModel(
      shipmentType: json['shipment_type'] ?? 'LCL',
      cfsWarehouseName: json['cfs_warehouse_name'],
      consolidationScheduledDate: json['consolidation_scheduled_date'],
      arrivalAtCfsAt: json['arrival_at_cfs_at'],
      stuffingStartAt: json['stuffing_start_at'],
      stuffingEndAt: json['stuffing_end_at'],
      portGateInAt: json['port_gate_in_at'],
      slaDeadlineAt: json['sla_deadline_at'],
      isSlaBreached: json['is_sla_breached'] ?? false,
      trackingStatus: json['tracking_status'] ?? 'PENDING_ASSIGNMENT',
      trackingHistory: (json['tracking_history'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_type': shipmentType,
      'cfs_warehouse_name': cfsWarehouseName,
      'consolidation_scheduled_date': consolidationScheduledDate,
      'arrival_at_cfs_at': arrivalAtCfsAt,
      'stuffing_start_at': stuffingStartAt,
      'stuffing_end_at': stuffingEndAt,
      'port_gate_in_at': portGateInAt,
      'sla_deadline_at': slaDeadlineAt,
      'is_sla_breached': isSlaBreached,
      'tracking_status': trackingStatus,
      'tracking_history': trackingHistory,
    };
  }

  int get progressStepIndex {
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
        return 5;
      case 'LOADING_COMPLETED':
        return 4;
      case 'LOADING_IN_PROGRESS':
        return 3;
      case 'ARRIVED_AT_SUPPLIER':
      case 'ARRIVED_AT_CFS':
        return 2;
      case 'ASSIGNED':
        return 1;
      default:
        return 0;
    }
  }

  String getLocalizedStatus(AppLocalizations l10n) {
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
        return l10n.cargoShippingStatusGatedIn;
      case 'LOADING_COMPLETED':
        return l10n.cargoShippingStatusLoadingCompleted;
      case 'LOADING_IN_PROGRESS':
        return l10n.cargoShippingStatusLoadingInProgress;
      case 'ARRIVED_AT_SUPPLIER':
      case 'ARRIVED_AT_CFS':
        return l10n.cargoShippingStatusArrivedAtCfs;
      case 'ASSIGNED':
        return l10n.cargoShippingStatusAssigned;
      default:
        return l10n.cargoShippingStatusPendingAssignment;
    }
  }

  String get arabicStatusLabel {
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
        return 'دخلت الميناء';
      case 'LOADING_COMPLETED':
        return 'اكتملت التعبئة بالمخزن';
      case 'LOADING_IN_PROGRESS':
        return 'جاري التعبئة بمخزن التجميع';
      case 'ARRIVED_AT_SUPPLIER':
      case 'ARRIVED_AT_CFS':
        return 'وصلت لمخزن التجميع المشترك';
      case 'ASSIGNED':
        return 'تمت جدولة التجميع';
      default:
        return 'قيد الجدولة';
    }
  }

  Color get statusColor {
    if (isSlaBreached) return AppTheme.crimson;
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
        return AppTheme.emerald;
      case 'LOADING_COMPLETED':
        return AppTheme.emerald;
      case 'LOADING_IN_PROGRESS':
      case 'ARRIVED_AT_SUPPLIER':
      case 'ARRIVED_AT_CFS':
        return AppTheme.orange;
      case 'ASSIGNED':
        return AppTheme.cobalt;
      default:
        return AppTheme.textSecondary;
    }
  }

  /// Severity of the tracking status (SLA breach wins) for status chips.
  AppSeverity get statusSeverity {
    if (isSlaBreached) return AppSeverity.danger;
    switch (trackingStatus) {
      case 'GATED_IN_AT_PORT':
      case 'LOADING_COMPLETED':
        return AppSeverity.success;
      case 'LOADING_IN_PROGRESS':
      case 'ARRIVED_AT_SUPPLIER':
      case 'ARRIVED_AT_CFS':
        return AppSeverity.warning;
      default:
        return AppSeverity.info;
    }
  }
}

class CourierTrackingModel {
  final String courierProvider;
  final String? trackingNumber;
  final String? dispatchDate;
  final String receiptStatus;
  final String? receivedAt;
  final String? receivedBy;

  CourierTrackingModel({
    this.courierProvider = 'DHL Express',
    this.trackingNumber,
    this.dispatchDate,
    this.receiptStatus = 'Dispatched',
    this.receivedAt,
    this.receivedBy,
  });

  factory CourierTrackingModel.fromJson(Map<String, dynamic> json) {
    return CourierTrackingModel(
      courierProvider: json['courier_provider'] ?? 'DHL Express',
      trackingNumber: json['tracking_number'],
      dispatchDate: json['dispatch_date'],
      receiptStatus: json['receipt_status'] ?? 'Dispatched',
      receivedAt: json['received_at'],
      receivedBy: json['received_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courier_provider': courierProvider,
      'tracking_number': trackingNumber,
      'dispatch_date': dispatchDate,
      'receipt_status': receiptStatus,
      'received_at': receivedAt,
      'received_by': receivedBy,
    };
  }
}

class CargoXChecklistRule {
  final String ruleName;
  final bool passed;
  final String? details;

  CargoXChecklistRule({
    required this.ruleName,
    this.passed = false,
    this.details,
  });

  factory CargoXChecklistRule.fromJson(Map<String, dynamic> json) {
    return CargoXChecklistRule(
      ruleName: json['rule_name'] ?? '',
      passed: json['passed'] ?? false,
      details: json['details'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rule_name': ruleName,
      'passed': passed,
      'details': details,
    };
  }
}

class CargoXExchangeModel {
  final String platformProvider;
  final String? envelopeId;
  final String envelopeStatus;
  final String? blockchainTxHash;
  final List<CargoXChecklistRule> verificationChecklist;

  CargoXExchangeModel({
    this.platformProvider = 'CargoX Platform',
    this.envelopeId,
    this.envelopeStatus = 'Created',
    this.blockchainTxHash,
    this.verificationChecklist = const [],
  });

  factory CargoXExchangeModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['verification_checklist'] as List<dynamic>? ?? [];
    return CargoXExchangeModel(
      platformProvider: json['platform_provider'] ?? 'CargoX Platform',
      envelopeId: json['envelope_id'],
      envelopeStatus: json['envelope_status'] ?? 'Created',
      blockchainTxHash: json['blockchain_tx_hash'],
      verificationChecklist: rawList.map((e) => CargoXChecklistRule.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform_provider': platformProvider,
      'envelope_id': envelopeId,
      'envelope_status': envelopeStatus,
      'blockchain_tx_hash': blockchainTxHash,
      'verification_checklist': verificationChecklist.map((e) => e.toJson()).toList(),
    };
  }
}

class CargoShippingModel {
  final int cargoShippingId;
  final String cargoShippingCode;
  final int importFileId;
  final String? importFileCode;
  final String? companyName;
  final int? bookingId;
  final String shipmentType;
  final String? crdDate;
  final String? cargoCutoffDate;
  final bool isCrdValidated;
  final List<ContainerLoadingModel> containersLoadingData;
  final LclLoadingTrackingModel? lclTrackingData;
  final String level1ApprovalStatus;
  final String? level1ApprovedBy;
  final String? level1ApprovedAt;
  final String? level1Notes;
  final String level2ApprovalStatus;
  final String? level2ApprovedBy;
  final String? level2ApprovedAt;
  final String? level2Notes;
  final String dualApprovalStatus;
  final CourierTrackingModel courierTrackingData;
  final CargoXExchangeModel cargoxExchangeData;
  final String? liveTrackingUrl;
  final String status;
  final String owner;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  CargoShippingModel({
    required this.cargoShippingId,
    required this.cargoShippingCode,
    required this.importFileId,
    this.importFileCode,
    this.companyName,
    this.bookingId,
    this.shipmentType = 'FCL',
    this.crdDate,
    this.cargoCutoffDate,
    this.isCrdValidated = true,
    this.containersLoadingData = const [],
    this.lclTrackingData,
    this.level1ApprovalStatus = 'Pending',
    this.level1ApprovedBy,
    this.level1ApprovedAt,
    this.level1Notes,
    this.level2ApprovalStatus = 'Pending',
    this.level2ApprovedBy,
    this.level2ApprovedAt,
    this.level2Notes,
    this.dualApprovalStatus = 'Pending',
    required this.courierTrackingData,
    required this.cargoxExchangeData,
    this.liveTrackingUrl,
    this.status = 'Cargo Ready',
    this.owner = 'Kamal',
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CargoShippingModel.fromJson(Map<String, dynamic> json) {
    var rawCont = json['containers_loading_data'] as List<dynamic>? ?? [];
    return CargoShippingModel(
      cargoShippingId: json['cargo_shipping_id'],
      cargoShippingCode: json['cargo_shipping_code'] ?? '',
      importFileId: json['import_file_id'],
      importFileCode: json['import_file_code'],
      companyName: json['company_name'],
      bookingId: json['booking_id'],
      shipmentType: json['shipment_type'] ?? 'FCL',
      crdDate: json['crd_date'],
      cargoCutoffDate: json['cargo_cutoff_date'],
      isCrdValidated: json['is_crd_validated'] ?? true,
      containersLoadingData: rawCont.map((e) => ContainerLoadingModel.fromJson(e)).toList(),
      lclTrackingData: json['lcl_tracking_data'] != null && (json['lcl_tracking_data'] as Map).isNotEmpty
          ? LclLoadingTrackingModel.fromJson(json['lcl_tracking_data'])
          : null,
      level1ApprovalStatus: json['level1_approval_status'] ?? 'Pending',
      level1ApprovedBy: json['level1_approved_by'],
      level1ApprovedAt: json['level1_approved_at'],
      level1Notes: json['level1_notes'],
      level2ApprovalStatus: json['level2_approval_status'] ?? 'Pending',
      level2ApprovedBy: json['level2_approved_by'],
      level2ApprovedAt: json['level2_approved_at'],
      level2Notes: json['level2_notes'],
      dualApprovalStatus: json['dual_approval_status'] ?? 'Pending',
      courierTrackingData: CourierTrackingModel.fromJson(json['courier_tracking_data'] ?? {}),
      cargoxExchangeData: CargoXExchangeModel.fromJson(json['cargox_exchange_data'] ?? {}),
      liveTrackingUrl: json['live_tracking_url'],
      status: json['status'] ?? 'Cargo Ready',
      owner: json['owner'] ?? 'Kamal',
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cargo_shipping_id': cargoShippingId,
      'cargo_shipping_code': cargoShippingCode,
      'import_file_id': importFileId,
      'booking_id': bookingId,
      'shipment_type': shipmentType,
      'crd_date': crdDate,
      'cargo_cutoff_date': cargoCutoffDate,
      'is_crd_validated': isCrdValidated,
      'containers_loading_data': containersLoadingData.map((e) => e.toJson()).toList(),
      'lcl_tracking_data': lclTrackingData?.toJson(),
      'courier_tracking_data': courierTrackingData.toJson(),
      'cargox_exchange_data': cargoxExchangeData.toJson(),
      'live_tracking_url': liveTrackingUrl,
      'status': status,
      'owner': owner,
      'notes': notes,
    };
  }
}

/// Builds the create/update body for `/cargo-shipping`.
///
/// `status` is sent on create only: sending it on edit would reset a record
/// that already reached a workflow status (Dual Approved, CargoX, Completed)
/// back to "Cargo Ready" (CS-04). `owner` is never sent: the backend takes it
/// from the session user.
Map<String, dynamic> buildCargoShippingPayload({
  required int importFileId,
  required String shipmentType,
  required List<ContainerLoadingModel> containers,
  LclLoadingTrackingModel? lclTracking,
  required bool isEdit,
  int? bookingId,
}) {
  return {
    'import_file_id': importFileId,
    'shipment_type': shipmentType,
    if (bookingId != null) 'booking_id': bookingId,
    'containers_loading_data': containers.map((c) => c.toJson()).toList(),
    'lcl_tracking_data':
        shipmentType == 'LCL' && lclTracking != null ? lclTracking.toJson() : null,
    if (!isEdit) 'status': 'Cargo Ready',
  };
}
