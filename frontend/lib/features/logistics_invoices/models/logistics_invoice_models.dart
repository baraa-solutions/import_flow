// 🎯 Logistics Service Invoices & Payments Models
// Covers: Freight, Customs Clearance, Inspection, Marine Insurance, Advances, Knock-offs

class LogisticsInvoiceModel {
  final int invoiceId;
  final String invoiceCode;
  final int shipmentId;
  final String? blNumber;
  final int partnerId;
  final String partnerType; // freight, clearance, inspection, insurance
  final String partnerName;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String currency;
  final double totalAmountFx;
  final double exchangeRate;
  final double totalAmountEgp;
  final bool vatIncluded;
  final double vatAmount;
  final bool whtDeducted;
  final double whtAmount;
  final double netPayableEgp;
  final double paidAmountEgp;
  final double remainingAmountEgp;
  final String paymentStatus;
  final String status;
  final String approvalStatus;
  final int? insurancePolicyId;
  final String? documentUrl;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;
  final List<LogisticsInvoiceLineModel> lines;
  final List<LogisticsInvoiceContainerModel> containers;

  LogisticsInvoiceModel({
    required this.invoiceId,
    required this.invoiceCode,
    required this.shipmentId,
    this.blNumber,
    required this.partnerId,
    required this.partnerType,
    required this.partnerName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.currency,
    required this.totalAmountFx,
    required this.exchangeRate,
    required this.totalAmountEgp,
    required this.vatIncluded,
    required this.vatAmount,
    required this.whtDeducted,
    required this.whtAmount,
    required this.netPayableEgp,
    required this.paidAmountEgp,
    required this.remainingAmountEgp,
    required this.paymentStatus,
    required this.status,
    required this.approvalStatus,
    this.insurancePolicyId,
    this.documentUrl,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
    this.lines = const [],
    this.containers = const [],
  });

  factory LogisticsInvoiceModel.fromJson(Map<String, dynamic> json) {
    return LogisticsInvoiceModel(
      invoiceId: json['invoice_id'] as int? ?? 0,
      invoiceCode: json['invoice_code'] as String? ?? '',
      shipmentId: json['shipment_id'] as int? ?? 0,
      blNumber: json['bl_number'] as String?,
      partnerId: json['partner_id'] as int? ?? 0,
      partnerType: json['partner_type'] as String? ?? 'freight',
      partnerName: json['partner_name'] as String? ?? '',
      invoiceNumber: json['invoice_number'] as String? ?? '',
      invoiceDate: json['invoice_date'] != null
          ? DateTime.tryParse(json['invoice_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      currency: json['currency'] as String? ?? 'EGP',
      totalAmountFx: (json['total_amount_fx'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      totalAmountEgp: (json['total_amount_egp'] as num?)?.toDouble() ?? 0.0,
      vatIncluded: json['vat_included'] as bool? ?? false,
      vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0.0,
      whtDeducted: json['wht_deducted'] as bool? ?? false,
      whtAmount: (json['wht_amount'] as num?)?.toDouble() ?? 0.0,
      netPayableEgp: (json['net_payable_egp'] as num?)?.toDouble() ?? 0.0,
      paidAmountEgp: (json['paid_amount_egp'] as num?)?.toDouble() ?? 0.0,
      remainingAmountEgp: (json['remaining_amount_egp'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      status: json['status'] as String? ?? 'draft',
      approvalStatus: json['approval_status'] as String? ?? 'pending',
      insurancePolicyId: json['insurance_policy_id'] as int?,
      documentUrl: json['document_url'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by'] as String? ?? '',
      lines: (json['lines'] as List<dynamic>?)
              ?.map((e) => LogisticsInvoiceLineModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      containers: (json['containers'] as List<dynamic>?)
              ?.map((e) => LogisticsInvoiceContainerModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_id': shipmentId,
      'bl_number': blNumber,
      'partner_id': partnerId,
      'partner_type': partnerType,
      'partner_name': partnerName,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate.toIso8601String(),
      'currency': currency,
      'total_amount_fx': totalAmountFx,
      'exchange_rate': exchangeRate,
      'total_amount_egp': totalAmountEgp,
      'vat_included': vatIncluded,
      'vat_amount': vatAmount,
      'wht_deducted': whtDeducted,
      'wht_amount': whtAmount,
      'net_payable_egp': netPayableEgp,
      'insurance_policy_id': insurancePolicyId,
      'document_url': documentUrl,
      'notes': notes,
      'lines': lines.map((e) => e.toJson()).toList(),
      'containers': containers.map((e) => e.toJson()).toList(),
    };
  }
}

class LogisticsInvoiceLineModel {
  final int? lineId;
  final int? invoiceId;
  final String? expenseCode;
  final String lineDescription;
  final String? lineGroup; // ocean_freight, port_charges, origin_charges, clearance_fees, inspection, insurance
  final double quantity;
  final double unitPriceFx;
  final String currency;
  final double amountFx;
  final double exchangeRate;
  final double amountEgp;
  final String taxType; // professional_fee, government_fee, insurance_fee, other
  final double vatRate;
  final double vatAmount;
  final double whtRate;
  final double whtAmount;
  final double netAmountEgp;
  final bool isFromQuotation;

  LogisticsInvoiceLineModel({
    this.lineId,
    this.invoiceId,
    this.expenseCode,
    required this.lineDescription,
    this.lineGroup,
    this.quantity = 1.0,
    this.unitPriceFx = 0.0,
    this.currency = 'EGP',
    this.amountFx = 0.0,
    this.exchangeRate = 1.0,
    this.amountEgp = 0.0,
    this.taxType = 'professional_fee',
    this.vatRate = 0.0,
    this.vatAmount = 0.0,
    this.whtRate = 0.0,
    this.whtAmount = 0.0,
    this.netAmountEgp = 0.0,
    this.isFromQuotation = false,
  });

  factory LogisticsInvoiceLineModel.fromJson(Map<String, dynamic> json) {
    return LogisticsInvoiceLineModel(
      lineId: json['line_id'] as int?,
      invoiceId: json['invoice_id'] as int?,
      expenseCode: json['expense_code'] as String?,
      lineDescription: json['line_description'] as String? ?? '',
      lineGroup: json['line_group'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPriceFx: (json['unit_price_fx'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EGP',
      amountFx: (json['amount_fx'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      amountEgp: (json['amount_egp'] as num?)?.toDouble() ?? 0.0,
      taxType: json['tax_type'] as String? ?? 'professional_fee',
      vatRate: (json['vat_rate'] as num?)?.toDouble() ?? 0.0,
      vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0.0,
      whtRate: (json['wht_rate'] as num?)?.toDouble() ?? 0.0,
      whtAmount: (json['wht_amount'] as num?)?.toDouble() ?? 0.0,
      netAmountEgp: (json['net_amount_egp'] as num?)?.toDouble() ?? 0.0,
      isFromQuotation: json['is_from_quotation'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_code': expenseCode,
      'line_description': lineDescription,
      'line_group': lineGroup,
      'quantity': quantity,
      'unit_price_fx': unitPriceFx,
      'currency': currency,
      'amount_fx': amountFx,
      'exchange_rate': exchangeRate,
      'amount_egp': amountEgp,
      'tax_type': taxType,
      'vat_rate': vatRate,
      'vat_amount': vatAmount,
      'wht_rate': whtRate,
      'wht_amount': whtAmount,
      'net_amount_egp': netAmountEgp,
      'is_from_quotation': isFromQuotation,
    };
  }
}

class LogisticsInvoiceContainerModel {
  final int? id;
  final int? invoiceId;
  final String containerNumber;
  final String? sealNumber;

  LogisticsInvoiceContainerModel({
    this.id,
    this.invoiceId,
    required this.containerNumber,
    this.sealNumber,
  });

  factory LogisticsInvoiceContainerModel.fromJson(Map<String, dynamic> json) {
    return LogisticsInvoiceContainerModel(
      id: json['id'] as int?,
      invoiceId: json['invoice_id'] as int?,
      containerNumber: json['container_number'] as String? ?? '',
      sealNumber: json['seal_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'container_number': containerNumber,
      'seal_number': sealNumber,
    };
  }
}

class InsurancePolicyModel {
  final int policyId;
  final String policyCode;
  final int shipmentId;
  final String? blNumber;
  final int insuranceCompanyId;
  final String insuranceCompanyName;
  final String policyNumber;
  final DateTime policyDate;
  final DateTime? coverageStart;
  final DateTime? coverageEnd;
  final String coverageType; // all_risks, icc_a, icc_b, icc_c, war_srcc
  final double insuredValueFx;
  final String insuredValueCurrency;
  final double premiumRate;
  final double premiumAmountFx;
  final double exchangeRate;
  final double premiumAmountEgp;
  final double stampDutyEgp;
  final double supervisoryFeeEgp;
  final double netPremiumEgp;
  final String? beneficiary;
  final String status;
  final String? claimReference;
  final double claimAmountEgp;
  final String? claimStatus;
  final bool invoiceGenerated;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  InsurancePolicyModel({
    required this.policyId,
    required this.policyCode,
    required this.shipmentId,
    this.blNumber,
    required this.insuranceCompanyId,
    required this.insuranceCompanyName,
    required this.policyNumber,
    required this.policyDate,
    this.coverageStart,
    this.coverageEnd,
    required this.coverageType,
    required this.insuredValueFx,
    required this.insuredValueCurrency,
    required this.premiumRate,
    required this.premiumAmountFx,
    required this.exchangeRate,
    required this.premiumAmountEgp,
    required this.stampDutyEgp,
    required this.supervisoryFeeEgp,
    required this.netPremiumEgp,
    this.beneficiary,
    required this.status,
    this.claimReference,
    required this.claimAmountEgp,
    this.claimStatus,
    required this.invoiceGenerated,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
  });

  factory InsurancePolicyModel.fromJson(Map<String, dynamic> json) {
    return InsurancePolicyModel(
      policyId: json['policy_id'] as int? ?? 0,
      policyCode: json['policy_code'] as String? ?? '',
      shipmentId: json['shipment_id'] as int? ?? 0,
      blNumber: json['bl_number'] as String?,
      insuranceCompanyId: json['insurance_company_id'] as int? ?? 0,
      insuranceCompanyName: json['insurance_company_name'] as String? ?? '',
      policyNumber: json['policy_number'] as String? ?? '',
      policyDate: json['policy_date'] != null
          ? DateTime.tryParse(json['policy_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      coverageStart: json['coverage_start'] != null
          ? DateTime.tryParse(json['coverage_start'] as String)
          : null,
      coverageEnd: json['coverage_end'] != null
          ? DateTime.tryParse(json['coverage_end'] as String)
          : null,
      coverageType: json['coverage_type'] as String? ?? 'all_risks',
      insuredValueFx: (json['insured_value_fx'] as num?)?.toDouble() ?? 0.0,
      insuredValueCurrency: json['insured_value_currency'] as String? ?? 'USD',
      premiumRate: (json['premium_rate'] as num?)?.toDouble() ?? 0.0,
      premiumAmountFx: (json['premium_amount_fx'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      premiumAmountEgp: (json['premium_amount_egp'] as num?)?.toDouble() ?? 0.0,
      stampDutyEgp: (json['stamp_duty_egp'] as num?)?.toDouble() ?? 0.0,
      supervisoryFeeEgp: (json['supervisory_fee_egp'] as num?)?.toDouble() ?? 0.0,
      netPremiumEgp: (json['net_premium_egp'] as num?)?.toDouble() ?? 0.0,
      beneficiary: json['beneficiary'] as String?,
      status: json['status'] as String? ?? 'draft',
      claimReference: json['claim_reference'] as String?,
      claimAmountEgp: (json['claim_amount_egp'] as num?)?.toDouble() ?? 0.0,
      claimStatus: json['claim_status'] as String?,
      invoiceGenerated: json['invoice_generated'] as bool? ?? false,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_id': shipmentId,
      'bl_number': blNumber,
      'insurance_company_id': insuranceCompanyId,
      'insurance_company_name': insuranceCompanyName,
      'policy_number': policyNumber,
      'policy_date': policyDate.toIso8601String(),
      'coverage_start': coverageStart?.toIso8601String().split('T').first,
      'coverage_end': coverageEnd?.toIso8601String().split('T').first,
      'coverage_type': coverageType,
      'insured_value_fx': insuredValueFx,
      'insured_value_currency': insuredValueCurrency,
      'premium_rate': premiumRate,
      'premium_amount_fx': premiumAmountFx,
      'exchange_rate': exchangeRate,
      'premium_amount_egp': premiumAmountEgp,
      'stamp_duty_egp': stampDutyEgp,
      'supervisory_fee_egp': supervisoryFeeEgp,
      'net_premium_egp': netPremiumEgp,
      'beneficiary': beneficiary,
      'notes': notes,
    };
  }
}

class InsurancePreviewModel {
  final int shipmentId;
  final double cifValueFx;
  final double insuredValueFx; // CIF + 10%
  final String currency;
  final double exchangeRate;
  final double premiumRate;
  final double premiumAmountFx;
  final double premiumAmountEgp;
  final double stampDutyEgp;
  final double supervisoryFeeEgp;
  final double netPremiumEgp;

  InsurancePreviewModel({
    required this.shipmentId,
    required this.cifValueFx,
    required this.insuredValueFx,
    required this.currency,
    required this.exchangeRate,
    required this.premiumRate,
    required this.premiumAmountFx,
    required this.premiumAmountEgp,
    required this.stampDutyEgp,
    required this.supervisoryFeeEgp,
    required this.netPremiumEgp,
  });

  factory InsurancePreviewModel.fromJson(Map<String, dynamic> json) {
    return InsurancePreviewModel(
      shipmentId: json['shipment_id'] as int? ?? 0,
      cifValueFx: (json['cif_value_fx'] as num?)?.toDouble() ?? 0.0,
      insuredValueFx: (json['insured_value_fx'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      premiumRate: (json['premium_rate'] as num?)?.toDouble() ?? 0.0,
      premiumAmountFx: (json['premium_amount_fx'] as num?)?.toDouble() ?? 0.0,
      premiumAmountEgp: (json['premium_amount_egp'] as num?)?.toDouble() ?? 0.0,
      stampDutyEgp: (json['stamp_duty_egp'] as num?)?.toDouble() ?? 0.0,
      supervisoryFeeEgp: (json['supervisory_fee_egp'] as num?)?.toDouble() ?? 0.0,
      netPremiumEgp: (json['net_premium_egp'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ClearanceAdvancePaymentModel {
  final int advanceId;
  final String advanceCode;
  final int shipmentId;
  final String? blNumber;
  final int clearancePartnerId;
  final String clearancePartnerName;
  final double amount;
  final String currency;
  final double exchangeRate;
  final double amountEgp;
  final DateTime paymentDate;
  final DateTime? cbeRateDate;
  final String disbursedBy;
  final double settledAmountEgp;
  final double remainingAmountEgp;
  final String status;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;
  final List<ClearanceAdvanceSettlementModel> settlements;

  ClearanceAdvancePaymentModel({
    required this.advanceId,
    required this.advanceCode,
    required this.shipmentId,
    this.blNumber,
    required this.clearancePartnerId,
    required this.clearancePartnerName,
    required this.amount,
    required this.currency,
    required this.exchangeRate,
    required this.amountEgp,
    required this.paymentDate,
    this.cbeRateDate,
    required this.disbursedBy,
    required this.settledAmountEgp,
    required this.remainingAmountEgp,
    required this.status,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
    this.settlements = const [],
  });

  factory ClearanceAdvancePaymentModel.fromJson(Map<String, dynamic> json) {
    return ClearanceAdvancePaymentModel(
      advanceId: json['advance_id'] as int? ?? 0,
      advanceCode: json['advance_code'] as String? ?? '',
      shipmentId: json['shipment_id'] as int? ?? 0,
      blNumber: json['bl_number'] as String?,
      clearancePartnerId: json['clearance_partner_id'] as int? ?? 0,
      clearancePartnerName: json['clearance_partner_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EGP',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      amountEgp: (json['amount_egp'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      cbeRateDate: json['cbe_rate_date'] != null
          ? DateTime.tryParse(json['cbe_rate_date'] as String)
          : null,
      disbursedBy: json['disbursed_by'] as String? ?? '',
      settledAmountEgp: (json['settled_amount_egp'] as num?)?.toDouble() ?? 0.0,
      remainingAmountEgp: (json['remaining_amount_egp'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'disbursed',
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by'] as String? ?? '',
      settlements: (json['settlements'] as List<dynamic>?)
              ?.map((e) => ClearanceAdvanceSettlementModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_id': shipmentId,
      'bl_number': blNumber,
      'clearance_partner_id': clearancePartnerId,
      'clearance_partner_name': clearancePartnerName,
      'amount': amount,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'amount_egp': amountEgp,
      'payment_date': paymentDate.toIso8601String(),
      'cbe_rate_date': cbeRateDate?.toIso8601String().split('T').first,
      'notes': notes,
    };
  }
}

class ClearanceAdvanceSettlementModel {
  final int settlementId;
  final int advanceId;
  final int invoiceId;
  final double settledAmountEgp;
  final DateTime settlementDate;
  final String? notes;

  ClearanceAdvanceSettlementModel({
    required this.settlementId,
    required this.advanceId,
    required this.invoiceId,
    required this.settledAmountEgp,
    required this.settlementDate,
    this.notes,
  });

  factory ClearanceAdvanceSettlementModel.fromJson(Map<String, dynamic> json) {
    return ClearanceAdvanceSettlementModel(
      settlementId: json['settlement_id'] as int? ?? 0,
      advanceId: json['advance_id'] as int? ?? 0,
      invoiceId: json['invoice_id'] as int? ?? 0,
      settledAmountEgp: (json['settled_amount_egp'] as num?)?.toDouble() ?? 0.0,
      settlementDate: json['settlement_date'] != null
          ? DateTime.tryParse(json['settlement_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes'] as String?,
    );
  }
}

class LogisticsPaymentVoucherModel {
  final int voucherId;
  final String voucherCode;
  final int? shipmentId;
  final int partnerId;
  final String partnerName;
  final DateTime paymentDate;
  final double amount;
  final String currency;
  final double exchangeRate;
  final double amountEgp;
  final DateTime? cbeRateDate;
  final String paymentMethod;
  final String? bankReference;
  final double allocatedAmountEgp;
  final double unallocatedAmountEgp;
  final String status;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;
  final List<InvoiceKnockoffModel> knockoffs;

  LogisticsPaymentVoucherModel({
    required this.voucherId,
    required this.voucherCode,
    this.shipmentId,
    required this.partnerId,
    required this.partnerName,
    required this.paymentDate,
    required this.amount,
    required this.currency,
    required this.exchangeRate,
    required this.amountEgp,
    this.cbeRateDate,
    required this.paymentMethod,
    this.bankReference,
    required this.allocatedAmountEgp,
    required this.unallocatedAmountEgp,
    required this.status,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
    this.knockoffs = const [],
  });

  factory LogisticsPaymentVoucherModel.fromJson(Map<String, dynamic> json) {
    return LogisticsPaymentVoucherModel(
      voucherId: json['voucher_id'] as int? ?? 0,
      voucherCode: json['voucher_code'] as String? ?? '',
      shipmentId: json['shipment_id'] as int?,
      partnerId: json['partner_id'] as int? ?? 0,
      partnerName: json['partner_name'] as String? ?? '',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EGP',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      amountEgp: (json['amount_egp'] as num?)?.toDouble() ?? 0.0,
      cbeRateDate: json['cbe_rate_date'] != null
          ? DateTime.tryParse(json['cbe_rate_date'] as String)
          : null,
      paymentMethod: json['payment_method'] as String? ?? 'BANK_TRANSFER',
      bankReference: json['bank_reference'] as String?,
      allocatedAmountEgp: (json['allocated_amount_egp'] as num?)?.toDouble() ?? 0.0,
      unallocatedAmountEgp: (json['unallocated_amount_egp'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'completed',
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by'] as String? ?? '',
      knockoffs: (json['knockoffs'] as List<dynamic>?)
              ?.map((e) => InvoiceKnockoffModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class InvoiceKnockoffModel {
  final int knockoffId;
  final int voucherId;
  final int invoiceId;
  final double knockedAmountEgp;
  final DateTime knockDate;
  final String? notes;

  InvoiceKnockoffModel({
    required this.knockoffId,
    required this.voucherId,
    required this.invoiceId,
    required this.knockedAmountEgp,
    required this.knockDate,
    this.notes,
  });

  factory InvoiceKnockoffModel.fromJson(Map<String, dynamic> json) {
    return InvoiceKnockoffModel(
      knockoffId: json['knockoff_id'] as int? ?? 0,
      voucherId: json['voucher_id'] as int? ?? 0,
      invoiceId: json['invoice_id'] as int? ?? 0,
      knockedAmountEgp: (json['knocked_amount_egp'] as num?)?.toDouble() ?? 0.0,
      knockDate: json['knock_date'] != null
          ? DateTime.tryParse(json['knock_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes'] as String?,
    );
  }
}

class PartnerBalanceCardModel {
  final int partnerId;
  final String partnerName;
  final String partnerType;
  final double totalInvoicedEgp;
  final double totalPaidEgp;
  final double balanceDueEgp;
  final int openInvoicesCount;
  final AgingBucketModel aging;

  PartnerBalanceCardModel({
    required this.partnerId,
    required this.partnerName,
    required this.partnerType,
    required this.totalInvoicedEgp,
    required this.totalPaidEgp,
    required this.balanceDueEgp,
    required this.openInvoicesCount,
    required this.aging,
  });

  factory PartnerBalanceCardModel.fromJson(Map<String, dynamic> json) {
    return PartnerBalanceCardModel(
      partnerId: json['partner_id'] as int? ?? 0,
      partnerName: json['partner_name'] as String? ?? '',
      partnerType: json['partner_type'] as String? ?? '',
      totalInvoicedEgp: (json['total_invoiced_egp'] as num?)?.toDouble() ?? 0.0,
      totalPaidEgp: (json['total_paid_egp'] as num?)?.toDouble() ?? 0.0,
      balanceDueEgp: (json['balance_due_egp'] as num?)?.toDouble() ?? 0.0,
      openInvoicesCount: json['open_invoices_count'] as int? ?? 0,
      aging: json['aging'] != null
          ? AgingBucketModel.fromJson(json['aging'] as Map<String, dynamic>)
          : AgingBucketModel(),
    );
  }
}

class AgingBucketModel {
  final double current30Days;
  final double days31To60;
  final double days61To90;
  final double days90Plus;

  AgingBucketModel({
    this.current30Days = 0.0,
    this.days31To60 = 0.0,
    this.days61To90 = 0.0,
    this.days90Plus = 0.0,
  });

  factory AgingBucketModel.fromJson(Map<String, dynamic> json) {
    return AgingBucketModel(
      current30Days: (json['current_30_days'] as num?)?.toDouble() ?? 0.0,
      days31To60: (json['days_31_to_60'] as num?)?.toDouble() ?? 0.0,
      days61To90: (json['days_61_to_90'] as num?)?.toDouble() ?? 0.0,
      days90Plus: (json['days_90_plus'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ContainerLockStatusItemModel {
  final String containerNumber;
  final String? sealNumber;
  final bool isBilled;
  final int? billedByPartnerId;
  final String? billedByPartnerName;
  final String? invoiceNumber;

  ContainerLockStatusItemModel({
    required this.containerNumber,
    this.sealNumber,
    required this.isBilled,
    this.billedByPartnerId,
    this.billedByPartnerName,
    this.invoiceNumber,
  });

  factory ContainerLockStatusItemModel.fromJson(Map<String, dynamic> json) {
    return ContainerLockStatusItemModel(
      containerNumber: json['container_number'] as String? ?? '',
      sealNumber: json['seal_number'] as String?,
      isBilled: json['is_billed'] as bool? ?? false,
      billedByPartnerId: json['billed_by_partner_id'] as int?,
      billedByPartnerName: json['billed_by_partner_name'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
    );
  }
}

class ContainerLockStatusModel {
  final int shipmentId;
  final String blNumber;
  final List<ContainerLockStatusItemModel> containers;

  ContainerLockStatusModel({
    required this.shipmentId,
    required this.blNumber,
    this.containers = const [],
  });

  factory ContainerLockStatusModel.fromJson(Map<String, dynamic> json) {
    return ContainerLockStatusModel(
      shipmentId: json['shipment_id'] as int? ?? 0,
      blNumber: json['bl_number'] as String? ?? '',
      containers: (json['containers'] as List<dynamic>?)
              ?.map((e) => ContainerLockStatusItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ThreeWayMatchModel {
  final int invoiceId;
  final bool isFullyMatched;
  final double totalQuotedEgp;
  final double totalInvoicedEgp;
  final double totalVarianceEgp;
  final List<ThreeWayMatchItemModel> items;

  ThreeWayMatchModel({
    required this.invoiceId,
    required this.isFullyMatched,
    required this.totalQuotedEgp,
    required this.totalInvoicedEgp,
    required this.totalVarianceEgp,
    this.items = const [],
  });

  factory ThreeWayMatchModel.fromJson(Map<String, dynamic> json) {
    return ThreeWayMatchModel(
      invoiceId: json['invoice_id'] as int? ?? 0,
      isFullyMatched: json['is_fully_matched'] as bool? ?? true,
      totalQuotedEgp: (json['total_quoted_egp'] as num?)?.toDouble() ?? 0.0,
      totalInvoicedEgp: (json['total_invoiced_egp'] as num?)?.toDouble() ?? 0.0,
      totalVarianceEgp: (json['total_variance_egp'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ThreeWayMatchItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ThreeWayMatchItemModel {
  final String itemDescription;
  final double quotedAmountEgp;
  final double invoicedAmountEgp;
  final double varianceEgp;
  final bool isMatched;

  ThreeWayMatchItemModel({
    required this.itemDescription,
    required this.quotedAmountEgp,
    required this.invoicedAmountEgp,
    required this.varianceEgp,
    required this.isMatched,
  });

  factory ThreeWayMatchItemModel.fromJson(Map<String, dynamic> json) {
    return ThreeWayMatchItemModel(
      itemDescription: json['item_description'] as String? ?? '',
      quotedAmountEgp: (json['quoted_amount_egp'] as num?)?.toDouble() ?? 0.0,
      invoicedAmountEgp: (json['invoiced_amount_egp'] as num?)?.toDouble() ?? 0.0,
      varianceEgp: (json['variance_egp'] as num?)?.toDouble() ?? 0.0,
      isMatched: json['is_matched'] as bool? ?? true,
    );
  }
}

class PrefillLinesModel {
  final int shipmentId;
  final String partnerType;
  final String currency;
  final double exchangeRate;
  final List<LogisticsInvoiceLineModel> lines;

  PrefillLinesModel({
    required this.shipmentId,
    required this.partnerType,
    required this.currency,
    required this.exchangeRate,
    this.lines = const [],
  });

  factory PrefillLinesModel.fromJson(Map<String, dynamic> json) {
    return PrefillLinesModel(
      shipmentId: json['shipment_id'] as int? ?? 0,
      partnerType: json['partner_type'] as String? ?? '',
      currency: json['currency'] as String? ?? 'EGP',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      lines: (json['lines'] as List<dynamic>?)
              ?.map((e) => LogisticsInvoiceLineModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
