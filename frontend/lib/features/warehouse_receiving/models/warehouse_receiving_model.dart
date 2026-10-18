class GrnItemModel {
  final String itemCode;
  final String itemName;
  final int invoicedQty;
  final int acceptedQty;
  final int shortageQty;
  final int damagedQty;
  final bool quarantineFlag;
  final String? poNumber;

  GrnItemModel({
    required this.itemCode,
    required this.itemName,
    this.invoicedQty = 0,
    this.acceptedQty = 0,
    this.shortageQty = 0,
    this.damagedQty = 0,
    this.quarantineFlag = false,
    this.poNumber,
  });

  factory GrnItemModel.fromJson(Map<String, dynamic> json) {
    return GrnItemModel(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      invoicedQty: (json['invoiced_qty'] as num?)?.toInt() ?? 0,
      acceptedQty: (json['accepted_qty'] as num?)?.toInt() ?? 0,
      shortageQty: (json['shortage_qty'] as num?)?.toInt() ?? 0,
      damagedQty: (json['damaged_qty'] as num?)?.toInt() ?? 0,
      quarantineFlag: json['quarantine_flag'] ?? false,
      poNumber: json['po_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'invoiced_qty': invoicedQty,
      'accepted_qty': acceptedQty,
      'shortage_qty': shortageQty,
      'damaged_qty': damagedQty,
      'quarantine_flag': quarantineFlag,
      if (poNumber != null) 'po_number': poNumber,
    };
  }
}

class WarehouseReceivingModel {
  final int receivingId;
  final String grnCode;
  final int importFileId;
  final String warehouseName;
  final String arrivalDatetime;
  final String? truckPlateNumber;
  final String? driverName;
  final String? driverPhone;
  final String? sealNumber;
  final bool sealIntact;
  final List<GrnItemModel> grnItems;
  final int totalInvoicedQty;
  final int totalAcceptedQty;
  final int totalShortageQty;
  final int totalDamagedQty;
  final String discrepancyType;
  final String? discrepancyNotes;
  final bool quarantineZoneAssigned;
  final bool insuranceClaimFiled;
  final String? insuranceClaimRef;
  final String? inspectionDate;
  final String? inspectionCommittee;
  final String? inspectionProtocolNumber;
  final String? inspectionVerdict;
  final String? rootCause;
  final bool supplierClaimFiled;
  final String? supplierClaimRef;
  final double? claimAmountEstimated;
  final String claimCurrency;
  final double? discrepancyRatePercent;
  final String status;
  final String inspectorName;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  WarehouseReceivingModel({
    required this.receivingId,
    required this.grnCode,
    required this.importFileId,
    this.warehouseName = 'Main Warehouse - Cairo',
    required this.arrivalDatetime,
    this.truckPlateNumber,
    this.driverName,
    this.driverPhone,
    this.sealNumber,
    this.sealIntact = true,
    this.grnItems = const [],
    this.totalInvoicedQty = 0,
    this.totalAcceptedQty = 0,
    this.totalShortageQty = 0,
    this.totalDamagedQty = 0,
    this.discrepancyType = 'None',
    this.discrepancyNotes,
    this.quarantineZoneAssigned = false,
    this.insuranceClaimFiled = false,
    this.insuranceClaimRef,
    this.inspectionDate,
    this.inspectionCommittee,
    this.inspectionProtocolNumber,
    this.inspectionVerdict = 'PENDING',
    this.rootCause,
    this.supplierClaimFiled = false,
    this.supplierClaimRef,
    this.claimAmountEstimated,
    this.claimCurrency = 'EGP',
    this.discrepancyRatePercent,
    this.status = 'Goods Received',
    this.inspectorName = 'Kamal',
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WarehouseReceivingModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['grn_items'] as List<dynamic>? ?? [];
    return WarehouseReceivingModel(
      receivingId: json['receiving_id'],
      grnCode: json['grn_code'] ?? '',
      importFileId: json['import_file_id'],
      warehouseName: json['warehouse_name'] ?? 'Main Warehouse - Cairo',
      arrivalDatetime: json['arrival_datetime'] ?? '',
      truckPlateNumber: json['truck_plate_number'],
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      sealNumber: json['seal_number'],
      sealIntact: json['seal_intact'] ?? true,
      grnItems: rawItems.map((e) => GrnItemModel.fromJson(e)).toList(),
      totalInvoicedQty: (json['total_invoiced_qty'] as num?)?.toInt() ?? 0,
      totalAcceptedQty: (json['total_accepted_qty'] as num?)?.toInt() ?? 0,
      totalShortageQty: (json['total_shortage_qty'] as num?)?.toInt() ?? 0,
      totalDamagedQty: (json['total_damaged_qty'] as num?)?.toInt() ?? 0,
      discrepancyType: json['discrepancy_type'] ?? 'None',
      discrepancyNotes: json['discrepancy_notes'],
      quarantineZoneAssigned: json['quarantine_zone_assigned'] ?? false,
      insuranceClaimFiled: json['insurance_claim_filed'] ?? false,
      insuranceClaimRef: json['insurance_claim_ref'],
      inspectionDate: json['inspection_date'],
      inspectionCommittee: json['inspection_committee'],
      inspectionProtocolNumber: json['inspection_protocol_number'],
      inspectionVerdict: json['inspection_verdict'] ?? 'PENDING',
      rootCause: json['root_cause'],
      supplierClaimFiled: json['supplier_claim_filed'] ?? false,
      supplierClaimRef: json['supplier_claim_ref'],
      claimAmountEstimated: (json['claim_amount_estimated'] as num?)?.toDouble(),
      claimCurrency: json['claim_currency'] ?? 'EGP',
      discrepancyRatePercent: (json['discrepancy_rate_percent'] as num?)?.toDouble(),
      status: json['status'] ?? 'Goods Received',
      inspectorName: json['inspector_name'] ?? 'Kamal',
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receiving_id': receivingId,
      'grn_code': grnCode,
      'import_file_id': importFileId,
      'warehouse_name': warehouseName,
      'arrival_datetime': arrivalDatetime,
      'truck_plate_number': truckPlateNumber,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'seal_number': sealNumber,
      'seal_intact': sealIntact,
      'grn_items': grnItems.map((e) => e.toJson()).toList(),
      'total_invoiced_qty': totalInvoicedQty,
      'total_accepted_qty': totalAcceptedQty,
      'total_shortage_qty': totalShortageQty,
      'total_damaged_qty': totalDamagedQty,
      'discrepancy_type': discrepancyType,
      'discrepancy_notes': discrepancyNotes,
      'quarantine_zone_assigned': quarantineZoneAssigned,
      'insurance_claim_filed': insuranceClaimFiled,
      'insurance_claim_ref': insuranceClaimRef,
      'inspection_date': inspectionDate,
      'inspection_committee': inspectionCommittee,
      'inspection_protocol_number': inspectionProtocolNumber,
      'inspection_verdict': inspectionVerdict,
      'root_cause': rootCause,
      'supplier_claim_filed': supplierClaimFiled,
      'supplier_claim_ref': supplierClaimRef,
      'claim_amount_estimated': claimAmountEstimated,
      'claim_currency': claimCurrency,
      'discrepancy_rate_percent': discrepancyRatePercent,
      'status': status,
      'inspector_name': inspectorName,
      'notes': notes,
    };
  }
}
