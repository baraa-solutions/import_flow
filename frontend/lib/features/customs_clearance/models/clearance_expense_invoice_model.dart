/// CL-05: Clearance Fees & Port Invoices Model
/// تسجيل فواتير المخلص ومصاريف العتالة ونولون الميناء
class ClearanceExpenseInvoiceModel {
  final int invoiceId;
  final String invoiceCode;
  final int importFileId;
  final int? customsClearanceId;
  final String invoiceNumber;
  final String invoiceDate;
  final int? providerId;
  final String providerName;
  final String expenseCategory;
  final String currency;
  final double amountFx;
  final double exchangeRate;
  final double amountEgp;
  final bool vatIncluded;
  final double vatAmount;
  final bool whtDeducted;
  final double whtAmount;
  final double netPayableEgp;
  final String paymentStatus;
  final String? paymentRef;
  final String? documentUrl;
  final String allocationRule;
  final String? notes;
  final bool isVerified;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  ClearanceExpenseInvoiceModel({
    required this.invoiceId,
    required this.invoiceCode,
    required this.importFileId,
    this.customsClearanceId,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.providerId,
    required this.providerName,
    required this.expenseCategory,
    this.currency = 'EGP',
    this.amountFx = 0.0,
    this.exchangeRate = 1.0,
    required this.amountEgp,
    this.vatIncluded = false,
    this.vatAmount = 0.0,
    this.whtDeducted = false,
    this.whtAmount = 0.0,
    required this.netPayableEgp,
    this.paymentStatus = 'Unpaid',
    this.paymentRef,
    this.documentUrl,
    this.allocationRule = 'Equal',
    this.notes,
    this.isVerified = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClearanceExpenseInvoiceModel.fromJson(Map<String, dynamic> json) {
    return ClearanceExpenseInvoiceModel(
      invoiceId: json['invoice_id'] ?? 0,
      invoiceCode: json['invoice_code'] ?? '',
      importFileId: json['import_file_id'] ?? 0,
      customsClearanceId: json['customs_clearance_id'],
      invoiceNumber: json['invoice_number'] ?? '',
      invoiceDate: json['invoice_date'] ?? '',
      providerId: json['provider_id'],
      providerName: json['provider_name'] ?? '',
      expenseCategory: json['expense_category'] ?? 'BROKER_FEES',
      currency: json['currency'] ?? 'EGP',
      amountFx: (json['amount_fx'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      amountEgp: (json['amount_egp'] as num?)?.toDouble() ?? 0.0,
      vatIncluded: json['vat_included'] ?? false,
      vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0.0,
      whtDeducted: json['wht_deducted'] ?? false,
      whtAmount: (json['wht_amount'] as num?)?.toDouble() ?? 0.0,
      netPayableEgp: (json['net_payable_egp'] as num?)?.toDouble() ?? ((json['amount_egp'] as num?)?.toDouble() ?? 0.0),
      paymentStatus: json['payment_status'] ?? 'Unpaid',
      paymentRef: json['payment_ref'],
      documentUrl: json['document_url'],
      allocationRule: json['allocation_rule'] ?? 'Equal',
      notes: json['notes'],
      isVerified: json['is_verified'] ?? true,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'invoice_code': invoiceCode,
      'import_file_id': importFileId,
      if (customsClearanceId != null) 'customs_clearance_id': customsClearanceId,
      'invoice_number': invoiceNumber,
      'invoice_date': invoiceDate,
      if (providerId != null) 'provider_id': providerId,
      'provider_name': providerName,
      'expense_category': expenseCategory,
      'currency': currency,
      'amount_fx': amountFx,
      'exchange_rate': exchangeRate,
      'amount_egp': amountEgp,
      'vat_included': vatIncluded,
      'vat_amount': vatAmount,
      'wht_deducted': whtDeducted,
      'wht_amount': whtAmount,
      'net_payable_egp': netPayableEgp,
      'payment_status': paymentStatus,
      if (paymentRef != null) 'payment_ref': paymentRef,
      if (documentUrl != null) 'document_url': documentUrl,
      'allocation_rule': allocationRule,
      if (notes != null) 'notes': notes,
      'is_verified': isVerified,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class ClearanceInvoicesSummaryModel {
  final int importFileId;
  final int invoicesCount;
  final double totalAmountEgp;
  final double totalVatEgp;
  final double totalWhtEgp;
  final double netPayableEgp;
  final double totalClearanceFeesEgp;
  final double totalPortDuesEgp;
  final double totalHandlingStevedoringEgp;
  final double totalOtherExpensesEgp;
  final List<ClearanceExpenseInvoiceModel> invoices;

  ClearanceInvoicesSummaryModel({
    required this.importFileId,
    required this.invoicesCount,
    required this.totalAmountEgp,
    required this.totalVatEgp,
    required this.totalWhtEgp,
    required this.netPayableEgp,
    required this.totalClearanceFeesEgp,
    required this.totalPortDuesEgp,
    required this.totalHandlingStevedoringEgp,
    required this.totalOtherExpensesEgp,
    required this.invoices,
  });

  factory ClearanceInvoicesSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['invoices'] as List<dynamic>? ?? [];
    return ClearanceInvoicesSummaryModel(
      importFileId: json['import_file_id'] ?? 0,
      invoicesCount: json['invoices_count'] ?? 0,
      totalAmountEgp: (json['total_amount_egp'] as num?)?.toDouble() ?? 0.0,
      totalVatEgp: (json['total_vat_egp'] as num?)?.toDouble() ?? 0.0,
      totalWhtEgp: (json['total_wht_egp'] as num?)?.toDouble() ?? 0.0,
      netPayableEgp: (json['net_payable_egp'] as num?)?.toDouble() ?? 0.0,
      totalClearanceFeesEgp: (json['total_clearance_fees_egp'] as num?)?.toDouble() ?? 0.0,
      totalPortDuesEgp: (json['total_port_dues_egp'] as num?)?.toDouble() ?? 0.0,
      totalHandlingStevedoringEgp: (json['total_handling_stevedoring_egp'] as num?)?.toDouble() ?? 0.0,
      totalOtherExpensesEgp: (json['total_other_expenses_egp'] as num?)?.toDouble() ?? 0.0,
      invoices: rawList.map((e) => ClearanceExpenseInvoiceModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'import_file_id': importFileId,
      'invoices_count': invoicesCount,
      'total_amount_egp': totalAmountEgp,
      'total_vat_egp': totalVatEgp,
      'total_wht_egp': totalWhtEgp,
      'net_payable_egp': netPayableEgp,
      'total_clearance_fees_egp': totalClearanceFeesEgp,
      'total_port_dues_egp': totalPortDuesEgp,
      'total_handling_stevedoring_egp': totalHandlingStevedoringEgp,
      'total_other_expenses_egp': totalOtherExpensesEgp,
      'invoices': invoices.map((e) => e.toJson()).toList(),
    };
  }
}
