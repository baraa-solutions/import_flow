class CustomsClearanceModel {
  final int customsClearanceId;
  int get clearanceId => customsClearanceId;
  /// Assessed duty: the actual total when positive, else the payable total.
  /// Null when the backend reports both as unknown.
  double? get effectiveDutyTotal {
    final actual = actualDutyTotal;
    if (actual != null && actual > 0) return actual;
    return totalDutyPayable ?? actual;
  }
  final String clearanceCode;
  final int importFileId;
  final String? declaration46No;
  final String? declaration46Date;
  final String? mtsCertificateNumber;
  final int customsTariffItemsCount;
  final String customsOfficeName;
  final int? brokerId;
  final String? brokerName;
  final String? delegationNumber;
  final String? delegationDate;
  final String delegationStatus;
  final String? authorizationNotes;
  final String? mandateLetterCode;
  final String channelType;
  final String? inspectionDate;
  final String inspectionType;
  final String? inspectionYard;
  final String? inspectorName;
  final String? inspectionResult;
  final bool isSampleDrawn;
  final String? samplingDate;
  final String? samplingRecordNo;
  final List<String> sampledRegulatoryBodies;
  final String? goeicCertificateNo;
  final List<String> regulatoryBodies;
  final String sampleTestStatus;
  final String? inspectionNotes;
  final double? cifBaseAmount;
  final double? customsExchangeRate;
  final double? importDutyAmount;
  final double? vatAmount;
  final double? scheduleTaxAmount;
  final double? developmentFeeAmount;
  final double? customsServiceFees;
  final double? whtAmount;
  final double? labServiceFees;
  final double? totalDutyPayable;
  final double? estimatedDutyTotal;
  final double? actualDutyTotal;
  final double? dutyVarianceAmount;
  final double? dutyVariancePercentage;
  final String? dutyVarianceReason;
  final String? nafezaClaimNumber;
  final String? nafezaClaimDate;
  final String assessmentStatus;
  final Map<String, dynamic>? nafezaAssessmentJson;
  final String? portArrivalDate;
  final String? deliveryOrderNumber;
  final String? deliveryOrderDate;
  final String? deliveryOrderExpiry;
  final int freeDaysAllowed;
  final int? shippingAgentId;
  final String? shippingAgentName;
  final double? deliveryOrderFees;
  final String deliveryOrderCurrency;
  final String? deliveryOrderPaymentRef;
  final String? deliveryOrderPaidAt;
  final String deliveryOrderStatus;
  final String? deliveryOrderFileUrl;
  final String? deliveryOrderNotes;
  final String? portGateOutDate;
  final String paymentStatus;
  final String? bankReceiptNo;
  final String? payingBankName;
  final String? paymentDate;
  final String? paymentNotes;
  final String? sadadNumber;
  final String paymentMethod;
  final double? dutyPaidAmount;
  final String? receiptFileUrl;
  final String? releasePermitNo;
  final String? releaseDate;
  final String? releaseOfficerName;
  final String releaseType;
  final String? releaseDocumentUrl;
  final String? gatePassNumber;
  final double? demurrageStorageFees;
  final bool dispatchAuthorized;
  final String? dispatchDate;
  final String? transportInstructions;
  final double? totalClearanceExpensesEgp;
  final double? totalPortExpensesEgp;
  final double? totalHandlingExpensesEgp;
  final int clearanceInvoicesCount;
  final bool isUnderBondRelease;
  final String? bondGuaranteeRef;
  final bool quarantineLock;
  final String labTestResult;
  final String? labCertificateNumber;
  final String? quarantineLiftedDate;
  final String? quarantineLiftedBy;
  final String status;
  final String owner;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  CustomsClearanceModel({
    required this.customsClearanceId,
    required this.clearanceCode,
    required this.importFileId,
    this.declaration46No,
    this.declaration46Date,
    this.mtsCertificateNumber,
    this.customsTariffItemsCount = 1,
    this.customsOfficeName = 'Alexandria Port Customs',
    this.brokerId,
    this.brokerName,
    this.delegationNumber,
    this.delegationDate,
    this.delegationStatus = 'Authorized',
    this.authorizationNotes,
    this.mandateLetterCode,
    this.channelType = 'Red Channel',
    this.inspectionDate,
    this.inspectionType = 'Physical & Sampling',
    this.inspectionYard,
    this.inspectorName,
    this.inspectionResult,
    this.isSampleDrawn = true,
    this.samplingDate,
    this.samplingRecordNo,
    this.sampledRegulatoryBodies = const [],
    this.goeicCertificateNo,
    this.regulatoryBodies = const [],
    this.sampleTestStatus = 'Samples Under Testing',
    this.inspectionNotes,
    this.cifBaseAmount,
    this.customsExchangeRate,
    this.importDutyAmount,
    this.vatAmount,
    this.scheduleTaxAmount,
    this.developmentFeeAmount,
    this.customsServiceFees,
    this.whtAmount,
    this.labServiceFees,
    this.totalDutyPayable,
    this.estimatedDutyTotal,
    this.actualDutyTotal,
    this.dutyVarianceAmount,
    this.dutyVariancePercentage,
    this.dutyVarianceReason,
    this.nafezaClaimNumber,
    this.nafezaClaimDate,
    this.assessmentStatus = 'Assessed',
    this.nafezaAssessmentJson,
    this.portArrivalDate,
    this.deliveryOrderNumber,
    this.deliveryOrderDate,
    this.deliveryOrderExpiry,
    this.freeDaysAllowed = 14,
    this.shippingAgentId,
    this.shippingAgentName,
    this.deliveryOrderFees,
    this.deliveryOrderCurrency = 'EGP',
    this.deliveryOrderPaymentRef,
    this.deliveryOrderPaidAt,
    this.deliveryOrderStatus = 'Pending',
    this.deliveryOrderFileUrl,
    this.deliveryOrderNotes,
    this.portGateOutDate,
    this.paymentStatus = 'Unpaid',
    this.bankReceiptNo,
    this.payingBankName,
    this.paymentDate,
    this.paymentNotes,
    this.sadadNumber,
    this.paymentMethod = 'SADAD_EFINANCE',
    this.dutyPaidAmount,
    this.receiptFileUrl,
    this.releasePermitNo,
    this.releaseDate,
    this.releaseOfficerName,
    this.releaseType = 'FINAL_GREEN',
    this.releaseDocumentUrl,
    this.gatePassNumber,
    this.demurrageStorageFees,
    this.dispatchAuthorized = false,
    this.dispatchDate,
    this.transportInstructions,
    this.totalClearanceExpensesEgp,
    this.totalPortExpensesEgp,
    this.totalHandlingExpensesEgp,
    this.clearanceInvoicesCount = 0,
    this.isUnderBondRelease = false,
    this.bondGuaranteeRef,
    this.quarantineLock = false,
    this.labTestResult = 'NONE',
    this.labCertificateNumber,
    this.quarantineLiftedDate,
    this.quarantineLiftedBy,
    this.status = 'Inspection In Progress',
    this.owner = 'Kamal',
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomsClearanceModel.fromJson(Map<String, dynamic> json) {
    var rawReg = json['regulatory_bodies'] as List<dynamic>? ?? [];
    return CustomsClearanceModel(
      customsClearanceId: json['customs_clearance_id'] ?? 0,
      clearanceCode: json['clearance_code'] ?? '',
      importFileId: json['import_file_id'] ?? 0,
      declaration46No: json['declaration_46_no'],
      declaration46Date: json['declaration_46_date'],
      mtsCertificateNumber: json['mts_certificate_number'],
      customsTariffItemsCount: (json['customs_tariff_items_count'] as num?)?.toInt() ?? 1,
      customsOfficeName: json['customs_office_name'] ?? 'Alexandria Port Customs',
      brokerId: json['broker_id'],
      brokerName: json['broker_name'],
      delegationNumber: json['delegation_number'],
      delegationDate: json['delegation_date'],
      delegationStatus: json['delegation_status'] ?? 'Authorized',
      authorizationNotes: json['authorization_notes'],
      mandateLetterCode: json['mandate_letter_code'],
      channelType: json['channel_type'] ?? 'Red Channel',
      inspectionDate: json['inspection_date'],
      inspectionType: json['inspection_type'] ?? 'Physical & Sampling',
      inspectionYard: json['inspection_yard'],
      inspectorName: json['inspector_name'],
      inspectionResult: json['inspection_result'] as String?,
      isSampleDrawn: json['is_sample_drawn'] ?? true,
      samplingDate: json['sampling_date'],
      samplingRecordNo: json['sampling_record_no'],
      sampledRegulatoryBodies: (json['sampled_regulatory_bodies'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      goeicCertificateNo: json['goeic_certificate_no'],
      regulatoryBodies: rawReg.map((e) => e.toString()).toList(),
      sampleTestStatus: json['sample_test_status'] ?? 'Samples Under Testing',
      inspectionNotes: json['inspection_notes'],
      cifBaseAmount: (json['cif_base_amount'] as num?)?.toDouble(),
      customsExchangeRate: (json['customs_exchange_rate'] as num?)?.toDouble(),
      importDutyAmount: (json['import_duty_amount'] as num?)?.toDouble(),
      vatAmount: (json['vat_amount'] as num?)?.toDouble(),
      scheduleTaxAmount: (json['schedule_tax_amount'] as num?)?.toDouble(),
      developmentFeeAmount: (json['development_fee_amount'] as num?)?.toDouble(),
      customsServiceFees: (json['customs_service_fees'] as num?)?.toDouble(),
      whtAmount: (json['wht_amount'] as num?)?.toDouble(),
      labServiceFees: (json['lab_service_fees'] as num?)?.toDouble(),
      totalDutyPayable: (json['total_duty_payable'] as num?)?.toDouble(),
      estimatedDutyTotal: (json['estimated_duty_total'] as num?)?.toDouble(),
      actualDutyTotal: (json['actual_duty_total'] as num?)?.toDouble() ??
          (json['total_duty_payable'] as num?)?.toDouble(),
      dutyVarianceAmount: (json['duty_variance_amount'] as num?)?.toDouble(),
      dutyVariancePercentage: (json['duty_variance_percentage'] as num?)?.toDouble(),
      dutyVarianceReason: json['duty_variance_reason'],
      nafezaClaimNumber: json['nafeza_claim_number'],
      nafezaClaimDate: json['nafeza_claim_date'],
      assessmentStatus: json['assessment_status'] ?? 'Assessed',
      nafezaAssessmentJson: json['nafeza_assessment_json'] as Map<String, dynamic>?,
      portArrivalDate: json['port_arrival_date'],
      deliveryOrderNumber: json['delivery_order_number'],
      deliveryOrderDate: json['delivery_order_date'],
      deliveryOrderExpiry: json['delivery_order_expiry'],
      freeDaysAllowed: (json['free_days_allowed'] as num?)?.toInt() ?? 14,
      shippingAgentId: json['shipping_agent_id'],
      shippingAgentName: json['shipping_agent_name'],
      deliveryOrderFees: (json['delivery_order_fees'] as num?)?.toDouble(),
      deliveryOrderCurrency: json['delivery_order_currency'] ?? 'EGP',
      deliveryOrderPaymentRef: json['delivery_order_payment_ref'],
      deliveryOrderPaidAt: json['delivery_order_paid_at'],
      deliveryOrderStatus: json['delivery_order_status'] ?? 'Pending',
      deliveryOrderFileUrl: json['delivery_order_file_url'],
      deliveryOrderNotes: json['delivery_order_notes'],
      portGateOutDate: json['port_gate_out_date'],
      paymentStatus: json['payment_status'] ?? 'Unpaid',
      bankReceiptNo: json['bank_receipt_no'],
      payingBankName: json['paying_bank_name'],
      paymentDate: json['payment_date'],
      paymentNotes: json['payment_notes'],
      sadadNumber: json['sadad_number'],
      paymentMethod: json['payment_method'] ?? 'Sadad / E-Finance',
      dutyPaidAmount: (json['duty_paid_amount'] as num?)?.toDouble(),
      receiptFileUrl: json['receipt_file_url'],
      releasePermitNo: json['release_permit_no'],
      releaseDate: json['release_date'],
      releaseOfficerName: json['release_officer_name'],
      releaseType: json['release_type'] ?? 'نهائي وبات (Final Green Release)',
      releaseDocumentUrl: json['release_document_url'],
      gatePassNumber: json['gate_pass_number'],
      demurrageStorageFees: (json['demurrage_storage_fees'] as num?)?.toDouble(),
      dispatchAuthorized: json['dispatch_authorized'] ?? false,
      dispatchDate: json['dispatch_date'],
      transportInstructions: json['transport_instructions'],
      totalClearanceExpensesEgp: (json['total_clearance_expenses_egp'] as num?)?.toDouble(),
      totalPortExpensesEgp: (json['total_port_expenses_egp'] as num?)?.toDouble(),
      totalHandlingExpensesEgp: (json['total_handling_expenses_egp'] as num?)?.toDouble(),
      clearanceInvoicesCount: (json['clearance_invoices_count'] as num?)?.toInt() ?? 0,
      isUnderBondRelease: json['is_under_bond_release'] == true,
      bondGuaranteeRef: json['bond_guarantee_ref']?.toString(),
      quarantineLock: json['quarantine_lock'] == true,
      labTestResult: json['lab_test_result']?.toString() ?? 'NONE',
      labCertificateNumber: json['lab_certificate_number']?.toString(),
      quarantineLiftedDate: json['quarantine_lifted_date']?.toString(),
      quarantineLiftedBy: json['quarantine_lifted_by']?.toString(),
      status: json['status'] ?? 'Inspection In Progress',
      owner: json['owner'] ?? 'Kamal',
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customs_clearance_id': customsClearanceId,
      'clearance_code': clearanceCode,
      'import_file_id': importFileId,
      'declaration_46_no': declaration46No,
      'declaration_46_date': declaration46Date,
      'mts_certificate_number': mtsCertificateNumber,
      'customs_tariff_items_count': customsTariffItemsCount,
      'customs_office_name': customsOfficeName,
      'broker_id': brokerId,
      'broker_name': brokerName,
      'delegation_number': delegationNumber,
      'delegation_date': delegationDate,
      'delegation_status': delegationStatus,
      'authorization_notes': authorizationNotes,
      'mandate_letter_code': mandateLetterCode,
      'channel_type': channelType,
      'inspection_date': inspectionDate,
      'inspection_type': inspectionType,
      'inspection_yard': inspectionYard,
      'inspector_name': inspectorName,
      'inspection_result': inspectionResult,
      'is_sample_drawn': isSampleDrawn,
      'sampling_date': samplingDate,
      'sampling_record_no': samplingRecordNo,
      'sampled_regulatory_bodies': sampledRegulatoryBodies,
      'goeic_certificate_no': goeicCertificateNo,
      'regulatory_bodies': regulatoryBodies,
      'sample_test_status': sampleTestStatus,
      'inspection_notes': inspectionNotes,
      'cif_base_amount': cifBaseAmount,
      'customs_exchange_rate': customsExchangeRate,
      'import_duty_amount': importDutyAmount,
      'vat_amount': vatAmount,
      'schedule_tax_amount': scheduleTaxAmount,
      'development_fee_amount': developmentFeeAmount,
      'customs_service_fees': customsServiceFees,
      'wht_amount': whtAmount,
      'lab_service_fees': labServiceFees,
      'total_duty_payable': totalDutyPayable,
      'estimated_duty_total': estimatedDutyTotal,
      'actual_duty_total': actualDutyTotal,
      'duty_variance_amount': dutyVarianceAmount,
      'duty_variance_percentage': dutyVariancePercentage,
      'duty_variance_reason': dutyVarianceReason,
      'nafeza_claim_number': nafezaClaimNumber,
      'nafeza_claim_date': nafezaClaimDate,
      'assessment_status': assessmentStatus,
      'nafeza_assessment_json': nafezaAssessmentJson,
      'port_arrival_date': portArrivalDate,
      'delivery_order_number': deliveryOrderNumber,
      'delivery_order_date': deliveryOrderDate,
      'delivery_order_expiry': deliveryOrderExpiry,
      'free_days_allowed': freeDaysAllowed,
      'shipping_agent_id': shippingAgentId,
      'shipping_agent_name': shippingAgentName,
      'delivery_order_fees': deliveryOrderFees,
      'delivery_order_currency': deliveryOrderCurrency,
      'delivery_order_payment_ref': deliveryOrderPaymentRef,
      'delivery_order_paid_at': deliveryOrderPaidAt,
      'delivery_order_status': deliveryOrderStatus,
      'delivery_order_file_url': deliveryOrderFileUrl,
      'delivery_order_notes': deliveryOrderNotes,
      'port_gate_out_date': portGateOutDate,
      'payment_status': paymentStatus,
      'bank_receipt_no': bankReceiptNo,
      'paying_bank_name': payingBankName,
      'payment_date': paymentDate,
      'payment_notes': paymentNotes,
      'sadad_number': sadadNumber,
      'payment_method': paymentMethod,
      'duty_paid_amount': dutyPaidAmount,
      'receipt_file_url': receiptFileUrl,
      'release_permit_no': releasePermitNo,
      'release_date': releaseDate,
      if (releaseOfficerName != null) 'release_officer_name': releaseOfficerName,
      'release_type': releaseType,
      if (releaseDocumentUrl != null) 'release_document_url': releaseDocumentUrl,
      if (gatePassNumber != null) 'gate_pass_number': gatePassNumber,
      'demurrage_storage_fees': demurrageStorageFees,
      'dispatch_authorized': dispatchAuthorized,
      'dispatch_date': dispatchDate,
      if (transportInstructions != null) 'transport_instructions': transportInstructions,
      'total_clearance_expenses_egp': totalClearanceExpensesEgp,
      'total_port_expenses_egp': totalPortExpensesEgp,
      'total_handling_expenses_egp': totalHandlingExpensesEgp,
      'clearance_invoices_count': clearanceInvoicesCount,
      'is_under_bond_release': isUnderBondRelease,
      'bond_guarantee_ref': bondGuaranteeRef,
      'quarantine_lock': quarantineLock,
      'lab_test_result': labTestResult,
      'lab_certificate_number': labCertificateNumber,
      'quarantine_lifted_date': quarantineLiftedDate,
      'quarantine_lifted_by': quarantineLiftedBy,
      'status': status,
      'owner': owner,
      'notes': notes,
    };
  }

  /// Returns true only if a sample was actually recorded as drawn by CL-01,
  /// preventing pre-CL-01 records from being fabricated as pending drawn samples.
  bool get hasActuallyDrawnSample =>
      isSampleDrawn &&
      ((samplingRecordNo != null && samplingRecordNo!.trim().isNotEmpty) ||
          (inspectionDate != null && inspectionDate!.trim().isNotEmpty));
}
