/// Models for Container EIR Return & Ledger Management (EPIC-CONT-EIR)
class ContainerLedgerItemModel {
  final int containerId;
  final String containerNumber;
  final String containerType;
  final String? sealNumber;
  final String? customsInspectionSeal;
  final String? carrierName;
  final String? billOfLadingNo;
  final String status;

  final DateTime? dischargeDate;
  final DateTime? gateOutDate;
  final DateTime? gateOutTimestamp;
  final String? truckPlateNumber;

  final DateTime? emptyReturnDate;
  final String? eirNumber;
  final DateTime? eirTimestamp;
  final String? eirConditionStatus;
  final String? depotName;

  final int demurrageDays;
  final int detentionDays;
  final int storageDays;
  final double demurrageCostFx;
  final double detentionCostFx;
  final double storageCostEgp;
  final double totalCostEgp;
  final double individualDemurrageCost;
  final String currency;

  final bool isDemurrageStopped;
  final String? stopReason;
  final String? notes;

  ContainerLedgerItemModel({
    required this.containerId,
    required this.containerNumber,
    required this.containerType,
    this.sealNumber,
    this.customsInspectionSeal,
    this.carrierName,
    this.billOfLadingNo,
    required this.status,
    this.dischargeDate,
    this.gateOutDate,
    this.gateOutTimestamp,
    this.truckPlateNumber,
    this.emptyReturnDate,
    this.eirNumber,
    this.eirTimestamp,
    this.eirConditionStatus,
    this.depotName,
    this.demurrageDays = 0,
    this.detentionDays = 0,
    this.storageDays = 0,
    this.demurrageCostFx = 0.0,
    this.detentionCostFx = 0.0,
    this.storageCostEgp = 0.0,
    this.totalCostEgp = 0.0,
    this.individualDemurrageCost = 0.0,
    this.currency = 'USD',
    this.isDemurrageStopped = false,
    this.stopReason,
    this.notes,
  });

  factory ContainerLedgerItemModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    return ContainerLedgerItemModel(
      containerId: json['container_id'] as int? ?? 0,
      containerNumber: json['container_number'] as String? ?? '',
      containerType: json['container_type'] as String? ?? '40HC',
      sealNumber: json['seal_number'] as String?,
      customsInspectionSeal: json['customs_inspection_seal'] as String?,
      carrierName: json['carrier_name'] as String?,
      billOfLadingNo: json['bill_of_lading_no'] as String?,
      status: json['status'] as String? ?? 'Allocated',
      dischargeDate: parseDt(json['discharge_date']),
      gateOutDate: parseDt(json['gate_out_date']),
      gateOutTimestamp: parseDt(json['gate_out_timestamp']),
      truckPlateNumber: json['truck_plate_number'] as String?,
      emptyReturnDate: parseDt(json['empty_return_date']),
      eirNumber: json['eir_number'] as String?,
      eirTimestamp: parseDt(json['eir_timestamp']),
      eirConditionStatus: json['eir_condition_status'] as String?,
      depotName: json['depot_name'] as String?,
      demurrageDays: json['demurrage_days'] as int? ?? 0,
      detentionDays: json['detention_days'] as int? ?? 0,
      storageDays: json['storage_days'] as int? ?? 0,
      demurrageCostFx: (json['demurrage_cost_fx'] as num?)?.toDouble() ?? 0.0,
      detentionCostFx: (json['detention_cost_fx'] as num?)?.toDouble() ?? 0.0,
      storageCostEgp: (json['storage_cost_egp'] as num?)?.toDouble() ?? 0.0,
      totalCostEgp: (json['total_cost_egp'] as num?)?.toDouble() ?? 0.0,
      individualDemurrageCost: (json['individual_demurrage_cost'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      isDemurrageStopped: json['is_demurrage_stopped'] as bool? ?? false,
      stopReason: json['stop_reason'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class ContainerLedgerResponseModel {
  final int importFileId;
  final int totalContainers;
  final int returnedContainers;
  final int activeContainers;
  final double totalDemurrageCostFx;
  final double totalCostEgp;
  final String currency;
  final List<ContainerLedgerItemModel> items;

  ContainerLedgerResponseModel({
    required this.importFileId,
    required this.totalContainers,
    required this.returnedContainers,
    required this.activeContainers,
    required this.totalDemurrageCostFx,
    required this.totalCostEgp,
    required this.currency,
    required this.items,
  });

  factory ContainerLedgerResponseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ContainerLedgerResponseModel(
      importFileId: json['import_file_id'] as int? ?? 0,
      totalContainers: json['total_containers'] as int? ?? 0,
      returnedContainers: json['returned_containers'] as int? ?? 0,
      activeContainers: json['active_containers'] as int? ?? 0,
      totalDemurrageCostFx: (json['total_demurrage_cost_fx'] as num?)?.toDouble() ?? 0.0,
      totalCostEgp: (json['total_cost_egp'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      items: rawItems.map((e) => ContainerLedgerItemModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ContainerEirReturnRequestModel {
  final String eirNumber;
  final DateTime? eirTimestamp;
  final DateTime? emptyReturnDate;
  final String? eirConditionStatus;
  final String? depotName;
  final String? conditionAtReturn;
  final String? notes;

  ContainerEirReturnRequestModel({
    required this.eirNumber,
    this.eirTimestamp,
    this.emptyReturnDate,
    this.eirConditionStatus,
    this.depotName,
    this.conditionAtReturn,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'eir_number': eirNumber,
      if (eirTimestamp != null) 'eir_timestamp': eirTimestamp!.toIso8601String(),
      if (emptyReturnDate != null)
        'empty_return_date':
            '${emptyReturnDate!.year.toString().padLeft(4, '0')}-${emptyReturnDate!.month.toString().padLeft(2, '0')}-${emptyReturnDate!.day.toString().padLeft(2, '0')}',
      if (eirConditionStatus != null) 'eir_condition_status': eirConditionStatus,
      if (depotName != null) 'depot_name': depotName,
      if (conditionAtReturn != null) 'condition_at_return': conditionAtReturn,
      if (notes != null) 'notes': notes,
    };
  }
}

class ContainerGateOutRequestModel {
  final DateTime? gateOutDate;
  final DateTime? gateOutTimestamp;
  final String? truckPlateNumber;
  final String? customsInspectionSeal;
  final String? driverName;
  final String? notes;

  ContainerGateOutRequestModel({
    this.gateOutDate,
    this.gateOutTimestamp,
    this.truckPlateNumber,
    this.customsInspectionSeal,
    this.driverName,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      if (gateOutDate != null)
        'gate_out_date':
            '${gateOutDate!.year.toString().padLeft(4, '0')}-${gateOutDate!.month.toString().padLeft(2, '0')}-${gateOutDate!.day.toString().padLeft(2, '0')}',
      if (gateOutTimestamp != null) 'gate_out_timestamp': gateOutTimestamp!.toIso8601String(),
      if (truckPlateNumber != null) 'truck_plate_number': truckPlateNumber,
      if (customsInspectionSeal != null) 'customs_inspection_seal': customsInspectionSeal,
      if (driverName != null) 'driver_name': driverName,
      if (notes != null) 'notes': notes,
    };
  }
}
