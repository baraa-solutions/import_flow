class ExpenseInvoiceModel {
  final String invoiceNo;
  final String category;
  final String providerName;
  final String currency;
  final double amountFx;
  final double exchangeRate;
  final double amountEgp;
  final String allocationRule;

  ExpenseInvoiceModel({
    required this.invoiceNo,
    this.category = 'Freight',
    required this.providerName,
    this.currency = '',
    this.amountFx = 0.0,
    this.exchangeRate = 0.0,
    this.amountEgp = 0.0,
    this.allocationRule = 'Value-Based',
  });

  factory ExpenseInvoiceModel.fromJson(Map<String, dynamic> json) {
    final fx = (json['amount_fx'] as num?)?.toDouble() ?? 0.0;
    final rate = (json['exchange_rate'] as num?)?.toDouble() ?? 0.0;
    // The EGP amount is always computed by the backend; never derived here.
    final egp = (json['amount_egp'] as num?)?.toDouble() ?? 0.0;

    return ExpenseInvoiceModel(
      invoiceNo: json['invoice_no'] ?? '',
      category: json['category'] ?? 'Freight',
      providerName: json['provider_name'] ?? '',
      currency: json['currency'] ?? '',
      amountFx: fx,
      exchangeRate: rate,
      amountEgp: egp,
      allocationRule: json['allocation_rule'] ?? 'Value-Based',
    );
  }

  /// Create payload: only what the user entered. `amount_egp` is computed by
  /// the backend, `exchange_rate` is sent only when the user typed one.
  Map<String, dynamic> toCreateJson() {
    return {
      'invoice_no': invoiceNo,
      'category': category,
      'provider_name': providerName,
      'currency': currency,
      'amount_fx': amountFx,
      if (exchangeRate > 0) 'exchange_rate': exchangeRate,
      'allocation_rule': allocationRule,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_no': invoiceNo,
      'category': category,
      'provider_name': providerName,
      'currency': currency,
      'amount_fx': amountFx,
      'exchange_rate': exchangeRate,
      'amount_egp': amountEgp,
      'allocation_rule': allocationRule,
    };
  }
}

class ItemLandedCostModel {
  final String itemCode;
  final String itemName;
  final double qty;
  final double grossWeightKg;
  final double cbm;
  final double fobUnitEgp;
  final double fobTotalEgp;
  final double allocatedFreightEgp;
  final double allocatedCustomsEgp;
  final double allocatedClearanceEgp;
  final double allocatedTransportEgp;
  final double allocatedOtherEgp;
  final double totalLandedCostEgp;
  final double unitLandedCostEgp;
  final double markupFactor;

  ItemLandedCostModel({
    required this.itemCode,
    required this.itemName,
    this.qty = 1.0,
    this.grossWeightKg = 0.0,
    this.cbm = 0.0,
    this.fobUnitEgp = 0.0,
    this.fobTotalEgp = 0.0,
    this.allocatedFreightEgp = 0.0,
    this.allocatedCustomsEgp = 0.0,
    this.allocatedClearanceEgp = 0.0,
    this.allocatedTransportEgp = 0.0,
    this.allocatedOtherEgp = 0.0,
    this.totalLandedCostEgp = 0.0,
    this.unitLandedCostEgp = 0.0,
    this.markupFactor = 1.0,
  });

  /// Quantity without a trailing `.0` (2.5 stays 2.5, 100.0 shows 100).
  String get qtyLabel => qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();

  factory ItemLandedCostModel.fromJson(Map<String, dynamic> json) {
    return ItemLandedCostModel(
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 1.0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      cbm: (json['cbm'] as num?)?.toDouble() ?? 0.0,
      fobUnitEgp: (json['fob_unit_egp'] as num?)?.toDouble() ?? 0.0,
      fobTotalEgp: (json['fob_total_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedFreightEgp: (json['allocated_freight_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedCustomsEgp: (json['allocated_customs_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedClearanceEgp: (json['allocated_clearance_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedTransportEgp: (json['allocated_transport_egp'] as num?)?.toDouble() ?? 0.0,
      allocatedOtherEgp: (json['allocated_other_egp'] as num?)?.toDouble() ?? 0.0,
      totalLandedCostEgp: (json['total_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      unitLandedCostEgp: (json['unit_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      markupFactor: (json['markup_factor'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Create payload: only the user-entered identity, quantity, weight, CBM and
  /// unit price. Totals and allocations are computed by the backend.
  Map<String, dynamic> toCreateJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'qty': qty,
      'gross_weight_kg': grossWeightKg,
      'cbm': cbm,
      'fob_unit_egp': fobUnitEgp,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'qty': qty,
      'gross_weight_kg': grossWeightKg,
      'cbm': cbm,
      'fob_unit_egp': fobUnitEgp,
      'fob_total_egp': fobTotalEgp,
      'allocated_freight_egp': allocatedFreightEgp,
      'allocated_customs_egp': allocatedCustomsEgp,
      'allocated_clearance_egp': allocatedClearanceEgp,
      'allocated_transport_egp': allocatedTransportEgp,
      'allocated_other_egp': allocatedOtherEgp,
      'total_landed_cost_egp': totalLandedCostEgp,
      'unit_landed_cost_egp': unitLandedCostEgp,
      'markup_factor': markupFactor,
    };
  }
}

class LandedCostSettlementModel {
  final int settlementId;
  final String settlementCode;
  final int importFileId;
  final List<ExpenseInvoiceModel> expenseInvoices;
  final double totalFobEgp;
  final double totalExpensesEgp;
  final double totalLandedCostEgp;
  final double averageMarkupFactor;
  final List<ItemLandedCostModel> itemLandedCosts;
  final String status;
  final String accountantName;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  LandedCostSettlementModel({
    required this.settlementId,
    required this.settlementCode,
    required this.importFileId,
    this.expenseInvoices = const [],
    this.totalFobEgp = 0.0,
    this.totalExpensesEgp = 0.0,
    this.totalLandedCostEgp = 0.0,
    this.averageMarkupFactor = 1.0,
    this.itemLandedCosts = const [],
    this.status = 'Draft',
    this.accountantName = '',
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LandedCostSettlementModel.fromJson(Map<String, dynamic> json) {
    var rawExpenses = json['expense_invoices'] as List<dynamic>? ?? [];
    var rawItems = json['item_landed_costs'] as List<dynamic>? ?? [];

    return LandedCostSettlementModel(
      settlementId: json['settlement_id'],
      settlementCode: json['settlement_code'] ?? '',
      importFileId: json['import_file_id'],
      expenseInvoices: rawExpenses.map((e) => ExpenseInvoiceModel.fromJson(e)).toList(),
      totalFobEgp: (json['total_fob_egp'] as num?)?.toDouble() ?? 0.0,
      totalExpensesEgp: (json['total_expenses_egp'] as num?)?.toDouble() ?? 0.0,
      totalLandedCostEgp: (json['total_landed_cost_egp'] as num?)?.toDouble() ?? 0.0,
      averageMarkupFactor: (json['average_markup_factor'] as num?)?.toDouble() ?? 1.0,
      itemLandedCosts: rawItems.map((i) => ItemLandedCostModel.fromJson(i)).toList(),
      status: json['status'] ?? 'Draft',
      accountantName: json['accountant_name'] ?? '',
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'settlement_id': settlementId,
      'settlement_code': settlementCode,
      'import_file_id': importFileId,
      'expense_invoices': expenseInvoices.map((e) => e.toJson()).toList(),
      'total_fob_egp': totalFobEgp,
      'total_expenses_egp': totalExpensesEgp,
      'total_landed_cost_egp': totalLandedCostEgp,
      'average_markup_factor': averageMarkupFactor,
      'item_landed_costs': itemLandedCosts.map((i) => i.toJson()).toList(),
      'status': status,
      'accountant_name': accountantName,
      'notes': notes,
    };
  }
}

class OdooJournalLineItemModel {
  final String accountCode;
  final String accountName;
  final String partnerName;
  final String label;
  final double debit;
  final double credit;
  final String currency;
  final double? amountCurrency;
  final String? analyticAccount;
  final String costCategory;

  OdooJournalLineItemModel({
    required this.accountCode,
    required this.accountName,
    required this.partnerName,
    required this.label,
    this.debit = 0.0,
    this.credit = 0.0,
    this.currency = 'EGP',
    this.amountCurrency,
    this.analyticAccount,
    this.costCategory = 'Goods',
  });

  factory OdooJournalLineItemModel.fromJson(Map<String, dynamic> json) {
    return OdooJournalLineItemModel(
      accountCode: json['account_code'] ?? '',
      accountName: json['account_name'] ?? '',
      partnerName: json['partner_name'] ?? '',
      label: json['label'] ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'EGP',
      amountCurrency: (json['amount_currency'] as num?)?.toDouble(),
      analyticAccount: json['analytic_account'],
      costCategory: json['cost_category'] ?? 'Goods',
    );
  }
}

class OdooJournalEntryModel {
  final int settlementId;
  final String settlementCode;
  final String importFileCode;
  final String companyName;
  final String supplierName;
  final String? projectName;
  final String entryDate;
  final String journalName;
  final String reference;
  final double totalDebit;
  final double totalCredit;
  final bool isBalanced;
  final double difference;
  final List<OdooJournalLineItemModel> lines;
  final List<dynamic> itemsBreakdown;

  OdooJournalEntryModel({
    required this.settlementId,
    required this.settlementCode,
    required this.importFileCode,
    required this.companyName,
    required this.supplierName,
    this.projectName,
    required this.entryDate,
    required this.journalName,
    required this.reference,
    required this.totalDebit,
    required this.totalCredit,
    required this.isBalanced,
    this.difference = 0.0,
    this.lines = const [],
    this.itemsBreakdown = const [],
  });

  factory OdooJournalEntryModel.fromJson(Map<String, dynamic> json) {
    var rawLines = json['lines'] as List<dynamic>? ?? [];
    return OdooJournalEntryModel(
      settlementId: json['settlement_id'] ?? 0,
      settlementCode: json['settlement_code'] ?? '',
      importFileCode: json['import_file_code'] ?? '',
      companyName: json['company_name'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      projectName: json['project_name'],
      entryDate: json['entry_date'] ?? '',
      journalName: json['journal_name'] ?? 'Miscellaneous Operations',
      reference: json['reference'] ?? '',
      totalDebit: (json['total_debit'] as num?)?.toDouble() ?? 0.0,
      totalCredit: (json['total_credit'] as num?)?.toDouble() ?? 0.0,
      isBalanced: json['is_balanced'] ?? false,
      difference: (json['difference'] as num?)?.toDouble() ?? 0.0,
      lines: rawLines.map((l) => OdooJournalLineItemModel.fromJson(l)).toList(),
      itemsBreakdown: json['items_breakdown'] as List<dynamic>? ?? [],
    );
  }
}

