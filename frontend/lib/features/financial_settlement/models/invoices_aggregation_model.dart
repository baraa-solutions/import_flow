import 'actual_landed_cost_model.dart' show SettlementMessageModel;

class AggregatedInvoiceItemModel {
  final String? invoiceId;
  final String invoiceNo;
  final String? invoiceDate;
  final String partyType;
  final String partyTypeAr;
  final String partyName;
  final String category;
  final String categoryAr;
  final String currency;
  final double exchangeRate;
  final double amountFc;
  final double amountEgp;
  final double paidAmountEgp;
  final double remainingAmountEgp;
  final String paymentStatus;
  final String? paymentReference;
  final double withholdingTaxRate;
  final double withholdingTaxAmountEgp;
  final double netPayableEgp;
  final String sourceModule;
  final String? notes;

  AggregatedInvoiceItemModel({
    this.invoiceId,
    required this.invoiceNo,
    this.invoiceDate,
    required this.partyType,
    required this.partyTypeAr,
    required this.partyName,
    required this.category,
    required this.categoryAr,
    this.currency = 'EGP',
    this.exchangeRate = 1.0,
    this.amountFc = 0.0,
    this.amountEgp = 0.0,
    this.paidAmountEgp = 0.0,
    this.remainingAmountEgp = 0.0,
    this.paymentStatus = 'PAID',
    this.paymentReference,
    this.withholdingTaxRate = 0.0,
    this.withholdingTaxAmountEgp = 0.0,
    this.netPayableEgp = 0.0,
    this.sourceModule = 'Manual',
    this.notes,
  });

  factory AggregatedInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return AggregatedInvoiceItemModel(
      invoiceId: json['invoice_id'],
      invoiceNo: json['invoice_no'] ?? '',
      invoiceDate: json['invoice_date'],
      partyType: json['party_type'] ?? 'OTHER',
      partyTypeAr: json['party_type_ar'] ?? 'أخرى',
      partyName: json['party_name'] ?? '',
      category: json['category'] ?? '',
      categoryAr: json['category_ar'] ?? '',
      currency: json['currency'] ?? 'EGP',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      amountFc: (json['amount_fc'] as num?)?.toDouble() ?? 0.0,
      amountEgp: (json['amount_egp'] as num?)?.toDouble() ?? 0.0,
      paidAmountEgp: (json['paid_amount_egp'] as num?)?.toDouble() ?? 0.0,
      remainingAmountEgp: (json['remaining_amount_egp'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] ?? 'PAID',
      paymentReference: json['payment_reference'],
      withholdingTaxRate: (json['withholding_tax_rate'] as num?)?.toDouble() ?? 0.0,
      withholdingTaxAmountEgp: (json['withholding_tax_amount_egp'] as num?)?.toDouble() ?? 0.0,
      netPayableEgp: (json['net_payable_egp'] as num?)?.toDouble() ?? 0.0,
      sourceModule: json['source_module'] ?? 'Manual',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (invoiceId != null) 'invoice_id': invoiceId,
      'invoice_no': invoiceNo,
      if (invoiceDate != null) 'invoice_date': invoiceDate,
      'party_type': partyType,
      'party_type_ar': partyTypeAr,
      'party_name': partyName,
      'category': category,
      'category_ar': categoryAr,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'amount_fc': amountFc,
      'amount_egp': amountEgp,
      'paid_amount_egp': paidAmountEgp,
      'remaining_amount_egp': remainingAmountEgp,
      'payment_status': paymentStatus,
      if (paymentReference != null) 'payment_reference': paymentReference,
      'withholding_tax_rate': withholdingTaxRate,
      'withholding_tax_amount_egp': withholdingTaxAmountEgp,
      'net_payable_egp': netPayableEgp,
      'source_module': sourceModule,
      if (notes != null) 'notes': notes,
    };
  }
}

class InvoicesPartySummaryModel {
  final String partyType;
  final String partyTypeAr;
  final String partyName;
  final int invoicesCount;
  final double totalEgp;
  final double paidEgp;
  final double remainingEgp;
  final double netPayableEgp;

  InvoicesPartySummaryModel({
    required this.partyType,
    required this.partyTypeAr,
    required this.partyName,
    this.invoicesCount = 0,
    this.totalEgp = 0.0,
    this.paidEgp = 0.0,
    this.remainingEgp = 0.0,
    this.netPayableEgp = 0.0,
  });

  factory InvoicesPartySummaryModel.fromJson(Map<String, dynamic> json) {
    return InvoicesPartySummaryModel(
      partyType: json['party_type'] ?? '',
      partyTypeAr: json['party_type_ar'] ?? '',
      partyName: json['party_name'] ?? '',
      invoicesCount: json['invoices_count'] as int? ?? 0,
      totalEgp: (json['total_egp'] as num?)?.toDouble() ?? 0.0,
      paidEgp: (json['paid_egp'] as num?)?.toDouble() ?? 0.0,
      remainingEgp: (json['remaining_egp'] as num?)?.toDouble() ?? 0.0,
      netPayableEgp: (json['net_payable_egp'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'party_type': partyType,
      'party_type_ar': partyTypeAr,
      'party_name': partyName,
      'invoices_count': invoicesCount,
      'total_egp': totalEgp,
      'paid_egp': paidEgp,
      'remaining_egp': remainingEgp,
      'net_payable_egp': netPayableEgp,
    };
  }
}

class InvoicesAggregationResponseModel {
  final int importFileId;
  final String importFileCode;
  final String supplierName;
  final String? currency;
  final double exchangeRate;
  final int totalInvoicesCount;
  final double totalAmountEgp;
  final double totalPaidEgp;
  final double totalRemainingEgp;
  final double totalNetPayableEgp;
  final double totalWithholdingTaxEgp;
  final double settlementReadinessPercent;
  final double? fxDifferenceEgp;
  final String financialSettlementStatus;
  final List<InvoicesPartySummaryModel> partiesSummary;
  final List<AggregatedInvoiceItemModel> invoices;
  final List<String> unsettledWarnings;
  final List<SettlementMessageModel> messages;

  InvoicesAggregationResponseModel({
    required this.importFileId,
    required this.importFileCode,
    required this.supplierName,
    this.currency,
    this.exchangeRate = 0.0,
    this.totalInvoicesCount = 0,
    this.totalAmountEgp = 0.0,
    this.totalPaidEgp = 0.0,
    this.totalRemainingEgp = 0.0,
    this.totalNetPayableEgp = 0.0,
    this.totalWithholdingTaxEgp = 0.0,
    this.settlementReadinessPercent = 0.0,
    this.fxDifferenceEgp,
    this.financialSettlementStatus = 'PENDING_SETTLEMENT',
    this.partiesSummary = const [],
    this.invoices = const [],
    this.unsettledWarnings = const [],
    this.messages = const [],
  });

  factory InvoicesAggregationResponseModel.fromJson(Map<String, dynamic> json) {
    return InvoicesAggregationResponseModel(
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      currency: json['currency']?.toString(),
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 0.0,
      totalInvoicesCount: json['total_invoices_count'] as int? ?? 0,
      totalAmountEgp: (json['total_amount_egp'] as num?)?.toDouble() ?? 0.0,
      totalPaidEgp: (json['total_paid_egp'] as num?)?.toDouble() ?? 0.0,
      totalRemainingEgp: (json['total_remaining_egp'] as num?)?.toDouble() ?? 0.0,
      totalNetPayableEgp: (json['total_net_payable_egp'] as num?)?.toDouble() ?? 0.0,
      totalWithholdingTaxEgp: (json['total_withholding_tax_egp'] as num?)?.toDouble() ?? 0.0,
      settlementReadinessPercent: (json['settlement_readiness_percent'] as num?)?.toDouble() ?? 0.0,
      fxDifferenceEgp: (json['fx_difference_egp'] as num?)?.toDouble(),
      financialSettlementStatus: json['financial_settlement_status'] ?? 'PENDING_SETTLEMENT',
      partiesSummary: (json['parties_summary'] as List<dynamic>?)
              ?.map((p) => InvoicesPartySummaryModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      invoices: (json['invoices'] as List<dynamic>?)
              ?.map((i) => AggregatedInvoiceItemModel.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      unsettledWarnings: (json['unsettled_warnings'] as List<dynamic>?)
              ?.map((w) => w.toString())
              .toList() ??
          [],
      messages: SettlementMessageModel.listFrom(json['messages']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'import_file_code': importFileCode,
      'supplier_name': supplierName,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'total_invoices_count': totalInvoicesCount,
      'total_amount_egp': totalAmountEgp,
      'total_paid_egp': totalPaidEgp,
      'total_remaining_egp': totalRemainingEgp,
      'total_net_payable_egp': totalNetPayableEgp,
      'total_withholding_tax_egp': totalWithholdingTaxEgp,
      'settlement_readiness_percent': settlementReadinessPercent,
      if (fxDifferenceEgp != null) 'fx_difference_egp': fxDifferenceEgp,
      'financial_settlement_status': financialSettlementStatus,
      'parties_summary': partiesSummary.map((p) => p.toJson()).toList(),
      'invoices': invoices.map((i) => i.toJson()).toList(),
      'unsettled_warnings': unsettledWarnings,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

class ConfirmInvoicesSettlementRequestModel {
  final int importFileId;
  /// Ignored by the server (it uses the signed-in user); sent only if set.
  final String? settledBy;
  final String? settlementNotes;
  final List<AggregatedInvoiceItemModel>? invoicesOverrides;
  final bool acknowledgeUnpaid;

  ConfirmInvoicesSettlementRequestModel({
    required this.importFileId,
    this.settledBy,
    this.settlementNotes,
    this.invoicesOverrides,
    this.acknowledgeUnpaid = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      if (settledBy != null) 'settled_by': settledBy,
      if (settlementNotes != null) 'settlement_notes': settlementNotes,
      if (invoicesOverrides != null)
        'invoices_overrides': invoicesOverrides!.map((i) => i.toJson()).toList(),
      if (acknowledgeUnpaid) 'acknowledge_unpaid': true,
    };
  }
}

class ConfirmInvoicesSettlementResponseModel {
  final bool success;
  final int importFileId;
  final String importFileCode;
  final String financialSettlementStatus;
  final String financialSettlementDate;
  final int invoicesCount;
  final double totalSettledEgp;
  final double progressPercent;
  final String currentStage;
  final String currentModule;
  final String nextTaskCode;
  final String nextTaskTitle;
  final String message;

  ConfirmInvoicesSettlementResponseModel({
    required this.success,
    required this.importFileId,
    required this.importFileCode,
    required this.financialSettlementStatus,
    required this.financialSettlementDate,
    required this.invoicesCount,
    required this.totalSettledEgp,
    required this.progressPercent,
    required this.currentStage,
    required this.currentModule,
    required this.nextTaskCode,
    required this.nextTaskTitle,
    required this.message,
  });

  factory ConfirmInvoicesSettlementResponseModel.fromJson(Map<String, dynamic> json) {
    return ConfirmInvoicesSettlementResponseModel(
      success: json['success'] ?? true,
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] ?? '',
      financialSettlementStatus: json['financial_settlement_status'] ?? '',
      financialSettlementDate: json['financial_settlement_date'] ?? '',
      invoicesCount: json['invoices_count'] as int? ?? 0,
      totalSettledEgp: (json['total_settled_egp'] as num?)?.toDouble() ?? 0.0,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      currentStage: json['current_stage'] ?? '',
      currentModule: json['current_module'] ?? '',
      nextTaskCode: json['next_task_code'] ?? '',
      nextTaskTitle: json['next_task_title'] ?? '',
      message: json['message'] ?? '',
    );
  }
}
