import 'package:flutter/foundation.dart';

@immutable
class BrokerExpenseItemModel {
  final int itemId;
  final int advanceId;
  final String expenseCategory;
  final bool isEInvoiceBacked;
  final String? eInvoiceUuid;
  final String? receiptReference;
  final double amount;
  final double taxWithholdingRate;
  final double taxWithheldAmount;
  final double netSettledAmount;
  final String approvalStatus; // PENDING, APPROVED, REJECTED
  final String? verifiedBy;
  final String? notes;

  const BrokerExpenseItemModel({
    required this.itemId,
    required this.advanceId,
    required this.expenseCategory,
    required this.isEInvoiceBacked,
    this.eInvoiceUuid,
    this.receiptReference,
    required this.amount,
    required this.taxWithholdingRate,
    required this.taxWithheldAmount,
    required this.netSettledAmount,
    required this.approvalStatus,
    this.verifiedBy,
    this.notes,
  });

  factory BrokerExpenseItemModel.fromJson(Map<String, dynamic> json) {
    return BrokerExpenseItemModel(
      itemId: json['item_id'] as int? ?? 0,
      advanceId: json['advance_id'] as int? ?? 0,
      expenseCategory: json['expense_category'] as String? ?? '',
      isEInvoiceBacked: json['is_e_invoice_backed'] as bool? ?? false,
      eInvoiceUuid: json['e_invoice_uuid'] as String?,
      receiptReference: json['receipt_reference'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      taxWithholdingRate: (json['tax_withholding_rate'] as num?)?.toDouble() ?? 0.01,
      taxWithheldAmount: (json['tax_withheld_amount'] as num?)?.toDouble() ?? 0.0,
      netSettledAmount: (json['net_settled_amount'] as num?)?.toDouble() ?? 0.0,
      approvalStatus: json['approval_status'] as String? ?? 'PENDING',
      verifiedBy: json['verified_by'] as String?,
      notes: json['notes'] as String?,
    );
  }

  String get categoryLabelAr {
    switch (expenseCategory) {
      case 'OFFICIAL_DUTIES_TAXES':
        return 'ضرائب ورسوم جمركية رسمية';
      case 'PORT_AUTHORITY_FEES':
        return 'رسوم وأرضيات هيئة الميناء';
      case 'LAB_TESTING_FEES':
        return 'رسوم فحص معملي وسحب عينات';
      case 'HANDLING_AND_PORTERAGE':
        return 'عتالة ومصروفات مناولة';
      case 'INSPECTION_TRANSPORT':
        return 'انتقالات لجان الكشف والمعاينة';
      case 'SUNDRY_PETTY_CASH':
      default:
        return 'نثريات ومصروفات متنوعة';
    }
  }
}

@immutable
class BrokerCustodyAdvanceModel {
  final int advanceId;
  final String advanceCode;
  final int importFileId;
  final String? importFileCode;
  final int brokerId;
  final String brokerName;
  final double advanceAmount;
  final String disbursementDate;
  final String paymentMethod;
  final String status; // OPEN, PARTIALLY_SETTLED, SETTLED
  final double settledAmount;
  final double remainingBalance;
  final String? notes;
  final List<BrokerExpenseItemModel> expenseItems;

  const BrokerCustodyAdvanceModel({
    required this.advanceId,
    required this.advanceCode,
    required this.importFileId,
    this.importFileCode,
    required this.brokerId,
    required this.brokerName,
    required this.advanceAmount,
    required this.disbursementDate,
    required this.paymentMethod,
    required this.status,
    required this.settledAmount,
    required this.remainingBalance,
    this.notes,
    required this.expenseItems,
  });

  factory BrokerCustodyAdvanceModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['expense_items'] as List<dynamic>?)
            ?.map((e) => BrokerExpenseItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return BrokerCustodyAdvanceModel(
      advanceId: json['advance_id'] as int? ?? 0,
      advanceCode: json['advance_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      importFileCode: json['import_file_code'] as String?,
      brokerId: json['broker_id'] as int? ?? 0,
      brokerName: json['broker_name'] as String? ?? '',
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0.0,
      disbursementDate: json['disbursement_date'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'BANK_TRANSFER',
      status: json['status'] as String? ?? 'OPEN',
      settledAmount: (json['settled_amount'] as num?)?.toDouble() ?? 0.0,
      remainingBalance: (json['remaining_balance'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      expenseItems: itemsList,
    );
  }

  String get statusLabelAr {
    switch (status) {
      case 'SETTLED':
        return 'تمت التسوية بالكامل 🟢';
      case 'PARTIALLY_SETTLED':
        return 'تسوية جزئية 🟡';
      case 'OPEN':
      default:
        return 'عهدة مفتوحة 🔵';
    }
  }
}

@immutable
class SettlementReconciliationModel {
  final int advanceId;
  final String advanceCode;
  final double advanceAmount;
  final double totalExpensesClaimed;
  final double totalTaxWithheldW41;
  final double totalNetSettled;
  final double balanceRemaining;
  final String status;
  final int approvedItemsCount;
  final int pendingItemsCount;
  final String reconciliationSummary;

  const SettlementReconciliationModel({
    required this.advanceId,
    required this.advanceCode,
    required this.advanceAmount,
    required this.totalExpensesClaimed,
    required this.totalTaxWithheldW41,
    required this.totalNetSettled,
    required this.balanceRemaining,
    required this.status,
    required this.approvedItemsCount,
    required this.pendingItemsCount,
    required this.reconciliationSummary,
  });

  factory SettlementReconciliationModel.fromJson(Map<String, dynamic> json) {
    return SettlementReconciliationModel(
      advanceId: json['advance_id'] as int? ?? 0,
      advanceCode: json['advance_code'] as String? ?? '',
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0.0,
      totalExpensesClaimed: (json['total_expenses_claimed'] as num?)?.toDouble() ?? 0.0,
      totalTaxWithheldW41: (json['total_tax_withheld_w41'] as num?)?.toDouble() ?? 0.0,
      totalNetSettled: (json['total_net_settled'] as num?)?.toDouble() ?? 0.0,
      balanceRemaining: (json['balance_remaining'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'OPEN',
      approvedItemsCount: json['approved_items_count'] as int? ?? 0,
      pendingItemsCount: json['pending_items_count'] as int? ?? 0,
      reconciliationSummary: json['reconciliation_summary'] as String? ?? '',
    );
  }
}
