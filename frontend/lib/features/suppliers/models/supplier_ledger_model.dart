// Foreign vendor multi-currency sub-ledger, aging and credit limit (Trello GzFff0Pc).
// Mirrors modules/suppliers/schemas.py (SupplierStatementResponse, SupplierAgingResponse,
// SupplierCreditStatusResponse). Amounts are per currency; EGP equivalents may be null when no rate exists.

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
double? _numOrNull(dynamic v) => (v as num?)?.toDouble();
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class SupplierLedgerWarning {
  final String code;
  final int? importFileId;
  final String? importFileCode;
  final String? reason;

  const SupplierLedgerWarning({required this.code, this.importFileId, this.importFileCode, this.reason});

  factory SupplierLedgerWarning.fromJson(Map<String, dynamic> json) => SupplierLedgerWarning(
        code: json['code']?.toString() ?? '',
        importFileId: json['import_file_id'] as int?,
        importFileCode: json['import_file_code']?.toString(),
        reason: json['reason']?.toString(),
      );
}

class SupplierCurrencyBalance {
  final String currency;
  final double billedFx;
  final double paidFx;
  final double balanceFx;
  final double openPayableFx;
  final double unappliedFx;
  final double openCommitmentsFx;
  final double bookBalanceEgp;
  final double? currentRate;
  final double? currentBalanceEgp;

  const SupplierCurrencyBalance({
    required this.currency,
    this.billedFx = 0,
    this.paidFx = 0,
    this.balanceFx = 0,
    this.openPayableFx = 0,
    this.unappliedFx = 0,
    this.openCommitmentsFx = 0,
    this.bookBalanceEgp = 0,
    this.currentRate,
    this.currentBalanceEgp,
  });

  /// A negative balance is an unapplied advance: the supplier owes goods.
  bool get isAdvance => balanceFx < 0;

  factory SupplierCurrencyBalance.fromJson(Map<String, dynamic> json) => SupplierCurrencyBalance(
        currency: json['currency']?.toString() ?? '',
        billedFx: _num(json['billed_fx']),
        paidFx: _num(json['paid_fx']),
        balanceFx: _num(json['balance_fx']),
        openPayableFx: _num(json['open_payable_fx']),
        unappliedFx: _num(json['unapplied_fx']),
        openCommitmentsFx: _num(json['open_commitments_fx']),
        bookBalanceEgp: _num(json['book_balance_egp']),
        currentRate: _numOrNull(json['current_rate']),
        currentBalanceEgp: _numOrNull(json['current_balance_egp']),
      );
}

class SupplierLedgerLine {
  final String? entryCode;
  final String sourceKey;
  final String entryType;
  final String direction; // CREDIT, DEBIT, MEMO
  final String? paymentPathway;
  final String? reference;
  final String? description;
  final int? importFileId;
  final DateTime? entryDate;
  final DateTime? dueDate;
  final String currency;
  final double amountFx;
  final double? exchangeRate;
  final double amountEgp;
  final double openAmountFx;
  final String status;
  final double balanceFx;
  final double balanceEgp;

  const SupplierLedgerLine({
    this.entryCode,
    required this.sourceKey,
    required this.entryType,
    required this.direction,
    this.paymentPathway,
    this.reference,
    this.description,
    this.importFileId,
    this.entryDate,
    this.dueDate,
    required this.currency,
    required this.amountFx,
    this.exchangeRate,
    required this.amountEgp,
    required this.openAmountFx,
    required this.status,
    required this.balanceFx,
    required this.balanceEgp,
  });

  bool get isMemo => direction == 'MEMO';

  /// Liability increase (invoice) shown in the credit column, payments in the debit column.
  double get creditFx => direction == 'CREDIT' ? amountFx : 0;
  double get debitFx => direction == 'DEBIT' ? amountFx : 0;

  factory SupplierLedgerLine.fromJson(Map<String, dynamic> json) => SupplierLedgerLine(
        entryCode: json['entry_code']?.toString(),
        sourceKey: json['source_key']?.toString() ?? '',
        entryType: json['entry_type']?.toString() ?? '',
        direction: json['direction']?.toString() ?? '',
        paymentPathway: json['payment_pathway']?.toString(),
        reference: json['reference']?.toString(),
        description: json['description']?.toString(),
        importFileId: json['import_file_id'] as int?,
        entryDate: _date(json['entry_date']),
        dueDate: _date(json['due_date']),
        currency: json['currency']?.toString() ?? '',
        amountFx: _num(json['amount_fx']),
        exchangeRate: _numOrNull(json['exchange_rate']),
        amountEgp: _num(json['amount_egp']),
        openAmountFx: _num(json['open_amount_fx']),
        status: json['status']?.toString() ?? '',
        balanceFx: _num(json['balance_fx']),
        balanceEgp: _num(json['balance_egp']),
      );
}

class SupplierCurrencyStatement {
  final String currency;
  final double openingBalanceFx;
  final double openingBalanceEgp;
  final double closingBalanceFx;
  final double closingBalanceEgp;
  final List<SupplierLedgerLine> lines;

  const SupplierCurrencyStatement({
    required this.currency,
    this.openingBalanceFx = 0,
    this.openingBalanceEgp = 0,
    this.closingBalanceFx = 0,
    this.closingBalanceEgp = 0,
    this.lines = const [],
  });

  factory SupplierCurrencyStatement.fromJson(Map<String, dynamic> json) => SupplierCurrencyStatement(
        currency: json['currency']?.toString() ?? '',
        openingBalanceFx: _num(json['opening_balance_fx']),
        openingBalanceEgp: _num(json['opening_balance_egp']),
        closingBalanceFx: _num(json['closing_balance_fx']),
        closingBalanceEgp: _num(json['closing_balance_egp']),
        lines: _list(json['lines']).map(SupplierLedgerLine.fromJson).toList(),
      );
}

class SupplierStatement {
  final int supplierId;
  final String supplierCode;
  final String companyName;
  final List<SupplierCurrencyBalance> balances;
  final List<SupplierCurrencyStatement> statements;
  final List<SupplierLedgerWarning> warnings;

  const SupplierStatement({
    required this.supplierId,
    required this.supplierCode,
    required this.companyName,
    this.balances = const [],
    this.statements = const [],
    this.warnings = const [],
  });

  List<String> get currencies => balances.map((b) => b.currency).toList();

  factory SupplierStatement.fromJson(Map<String, dynamic> json) => SupplierStatement(
        supplierId: json['supplier_id'] as int? ?? 0,
        supplierCode: json['supplier_code']?.toString() ?? '',
        companyName: json['company_name']?.toString() ?? '',
        balances: _list(json['balances']).map(SupplierCurrencyBalance.fromJson).toList(),
        statements: _list(json['statements']).map(SupplierCurrencyStatement.fromJson).toList(),
        warnings: _list(json['warnings']).map(SupplierLedgerWarning.fromJson).toList(),
      );
}

class SupplierAgingItem {
  final String? entryCode;
  final String? reference;
  final int? importFileId;
  final String? paymentPathway;
  final DateTime? entryDate;
  final DateTime? dueDate;
  final double amountFx;
  final double openAmountFx;
  final int daysPastDue;
  final String bucket;

  const SupplierAgingItem({
    this.entryCode,
    this.reference,
    this.importFileId,
    this.paymentPathway,
    this.entryDate,
    this.dueDate,
    required this.amountFx,
    required this.openAmountFx,
    required this.daysPastDue,
    required this.bucket,
  });

  factory SupplierAgingItem.fromJson(Map<String, dynamic> json) => SupplierAgingItem(
        entryCode: json['entry_code']?.toString(),
        reference: json['reference']?.toString(),
        importFileId: json['import_file_id'] as int?,
        paymentPathway: json['payment_pathway']?.toString(),
        entryDate: _date(json['entry_date']),
        dueDate: _date(json['due_date']),
        amountFx: _num(json['amount_fx']),
        openAmountFx: _num(json['open_amount_fx']),
        daysPastDue: json['days_past_due'] as int? ?? 0,
        bucket: json['bucket']?.toString() ?? '',
      );
}

/// Aging bucket of a number of days past due (same boundaries as the backend `aging_bucket`).
String agingBucketForDays(int daysPastDue) {
  if (daysPastDue <= 0) return 'CURRENT';
  if (daysPastDue <= 30) return '1_30';
  if (daysPastDue <= 60) return '31_60';
  if (daysPastDue <= 90) return '61_90';
  return 'OVER_90';
}

class SupplierCurrencyAging {
  final String currency;
  final double current;
  final double days1To30;
  final double days31To60;
  final double days61To90;
  final double over90;
  final double totalOpenFx;
  final double unappliedFx;
  final double? currentRate;
  final double? totalOpenEgp;
  final List<SupplierAgingItem> items;

  const SupplierCurrencyAging({
    required this.currency,
    this.current = 0,
    this.days1To30 = 0,
    this.days31To60 = 0,
    this.days61To90 = 0,
    this.over90 = 0,
    this.totalOpenFx = 0,
    this.unappliedFx = 0,
    this.currentRate,
    this.totalOpenEgp,
    this.items = const [],
  });

  /// Overdue part (everything past due).
  double get overdueFx => days1To30 + days31To60 + days61To90 + over90;

  Map<String, double> get buckets => {
        'CURRENT': current,
        '1_30': days1To30,
        '31_60': days31To60,
        '61_90': days61To90,
        'OVER_90': over90,
      };

  factory SupplierCurrencyAging.fromJson(Map<String, dynamic> json) => SupplierCurrencyAging(
        currency: json['currency']?.toString() ?? '',
        current: _num(json['current']),
        days1To30: _num(json['days_1_30']),
        days31To60: _num(json['days_31_60']),
        days61To90: _num(json['days_61_90']),
        over90: _num(json['over_90']),
        totalOpenFx: _num(json['total_open_fx']),
        unappliedFx: _num(json['unapplied_fx']),
        currentRate: _numOrNull(json['current_rate']),
        totalOpenEgp: _numOrNull(json['total_open_egp']),
        items: _list(json['items']).map(SupplierAgingItem.fromJson).toList(),
      );
}

class SupplierAging {
  final int supplierId;
  final DateTime? asOf;
  final List<SupplierCurrencyAging> currencies;
  final double? totalOpenEgp;
  final List<SupplierLedgerWarning> warnings;

  const SupplierAging({
    required this.supplierId,
    this.asOf,
    this.currencies = const [],
    this.totalOpenEgp,
    this.warnings = const [],
  });

  factory SupplierAging.fromJson(Map<String, dynamic> json) => SupplierAging(
        supplierId: json['supplier_id'] as int? ?? 0,
        asOf: _date(json['as_of']),
        currencies: _list(json['currencies']).map(SupplierCurrencyAging.fromJson).toList(),
        totalOpenEgp: _numOrNull(json['total_open_egp']),
        warnings: _list(json['warnings']).map(SupplierLedgerWarning.fromJson).toList(),
      );
}

class SupplierCreditCheck {
  final bool hasLimit;
  final String currency;
  final String policy;
  final double limitAmount;
  final double utilizationAmount;
  final double requestedAmount;
  final double projectedAmount;
  final double? availableAmount;
  final double? utilizationPct;
  final bool exceeded;
  final bool allowed;
  final String decision;
  final double openPoAmount; // part of utilization from open, not yet invoiced purchase orders

  const SupplierCreditCheck({
    required this.hasLimit,
    required this.currency,
    required this.policy,
    this.limitAmount = 0,
    this.utilizationAmount = 0,
    this.requestedAmount = 0,
    this.projectedAmount = 0,
    this.availableAmount,
    this.utilizationPct,
    this.exceeded = false,
    this.allowed = true,
    this.decision = 'NO_LIMIT',
    this.openPoAmount = 0,
  });

  /// Progress bar value 0..1 (capped), null when there is no limit.
  double? get utilizationRatio {
    if (!hasLimit || limitAmount <= 0) return null;
    final r = utilizationAmount / limitAmount;
    return r < 0 ? 0 : (r > 1 ? 1 : r);
  }

  factory SupplierCreditCheck.fromJson(Map<String, dynamic> json) => SupplierCreditCheck(
        hasLimit: json['has_limit'] as bool? ?? false,
        currency: json['currency']?.toString() ?? '',
        policy: json['policy']?.toString() ?? 'BLOCK',
        limitAmount: _num(json['limit_amount']),
        utilizationAmount: _num(json['utilization_amount']),
        requestedAmount: _num(json['requested_amount']),
        projectedAmount: _num(json['projected_amount']),
        availableAmount: _numOrNull(json['available_amount']),
        utilizationPct: _numOrNull(json['utilization_pct']),
        exceeded: json['exceeded'] as bool? ?? false,
        allowed: json['allowed'] as bool? ?? true,
        decision: json['decision']?.toString() ?? 'NO_LIMIT',
        openPoAmount: _num(json['open_po_amount']),
      );
}

class SupplierCreditOverride {
  final int overrideId;
  final String context;
  final String? reference;
  final String currency;
  final double limitAmount;
  final double utilizationAmount;
  final double requestedAmount;
  final double projectedAmount;
  final String reason;
  final DateTime? createdAt;
  final String createdBy;

  const SupplierCreditOverride({
    required this.overrideId,
    required this.context,
    this.reference,
    required this.currency,
    required this.limitAmount,
    required this.utilizationAmount,
    required this.requestedAmount,
    required this.projectedAmount,
    required this.reason,
    this.createdAt,
    required this.createdBy,
  });

  factory SupplierCreditOverride.fromJson(Map<String, dynamic> json) => SupplierCreditOverride(
        overrideId: json['override_id'] as int? ?? 0,
        context: json['context']?.toString() ?? '',
        reference: json['reference']?.toString(),
        currency: json['currency']?.toString() ?? '',
        limitAmount: _num(json['limit_amount']),
        utilizationAmount: _num(json['utilization_amount']),
        requestedAmount: _num(json['requested_amount']),
        projectedAmount: _num(json['projected_amount']),
        reason: json['reason']?.toString() ?? '',
        createdAt: _date(json['created_at']),
        createdBy: json['created_by']?.toString() ?? '',
      );
}

class SupplierCreditStatus {
  final int supplierId;
  final SupplierCreditCheck credit;
  final List<SupplierCurrencyBalance> balances;
  final List<SupplierCreditOverride> overrides;

  const SupplierCreditStatus({
    required this.supplierId,
    required this.credit,
    this.balances = const [],
    this.overrides = const [],
  });

  factory SupplierCreditStatus.fromJson(Map<String, dynamic> json) => SupplierCreditStatus(
        supplierId: json['supplier_id'] as int? ?? 0,
        credit: SupplierCreditCheck.fromJson(Map<String, dynamic>.from(json['credit'] as Map? ?? const {})),
        balances: _list(json['balances']).map(SupplierCurrencyBalance.fromJson).toList(),
        overrides: _list(json['overrides']).map(SupplierCreditOverride.fromJson).toList(),
      );
}
