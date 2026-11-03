class BrokerSettlementReceiptModel {
  final int id;
  final int advanceId;
  final String receiptType;
  final String receiptNumber;
  final String receiptDate;
  final String issuingEntity;
  final double amount;
  final double taxWithholdingRate;
  final double taxWithheldAmount;
  final double netAmount;
  final String? eInvoiceUuid;
  final bool isOfficialReceipt;
  final String verificationStatus;
  final String? notes;

  const BrokerSettlementReceiptModel({
    required this.id,
    required this.advanceId,
    required this.receiptType,
    required this.receiptNumber,
    required this.receiptDate,
    required this.issuingEntity,
    required this.amount,
    required this.taxWithholdingRate,
    required this.taxWithheldAmount,
    required this.netAmount,
    this.eInvoiceUuid,
    required this.isOfficialReceipt,
    required this.verificationStatus,
    this.notes,
  });

  factory BrokerSettlementReceiptModel.fromJson(Map<String, dynamic> json) {
    return BrokerSettlementReceiptModel(
      id: json['id'] as int? ?? 0,
      advanceId: json['advance_id'] as int? ?? 0,
      receiptType: json['receipt_type'] as String? ?? 'OTHER_OFFICIAL_RECEIPT',
      receiptNumber: json['receipt_number'] as String? ?? '',
      receiptDate: json['receipt_date'] as String? ?? '',
      issuingEntity: json['issuing_entity'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      taxWithholdingRate: (json['tax_withholding_rate'] as num?)?.toDouble() ?? 0.0,
      taxWithheldAmount: (json['tax_withheld_amount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
      eInvoiceUuid: json['e_invoice_uuid'] as String?,
      isOfficialReceipt: json['is_official_receipt'] as bool? ?? true,
      verificationStatus: json['verification_status'] as String? ?? 'PENDING',
      notes: json['notes'] as String?,
    );
  }

  String get localizedReceiptType {
    switch (receiptType) {
      case 'WHITE_RECEIPT_CUSTOMS_DUTIES':
        return 'إيصال سداد جمركي أبيض (ضرائب ورسوم)';
      case 'RED_RECEIPT_EXAMINATION_INSPECTION':
        return 'إيصال كشف ومعاينة أحمر (لجان فحص)';
      case 'PORT_AUTHORITY_RECEIPT':
        return 'إيصال هيئة الميناء ومصاريف الشحن والتفريغ';
      case 'BROKER_SERVICE_FEE':
        return 'فاتورة أتعاب التخليص الجمركي (أ.ت.ص)';
      case 'STORAGE_RECEIPT':
        return 'إيصال رسوم التخزين والأرضيات';
      case 'OTHER_OFFICIAL_RECEIPT':
      default:
        return 'إيصال ومستند رسمي معتمد';
    }
  }

  String get localizedStatus {
    switch (verificationStatus) {
      case 'VERIFIED':
        return 'مدقق ومعتمد';
      case 'REJECTED':
        return 'مرفوض';
      case 'PENDING':
      default:
        return 'قيد المراجعة والتدقيق';
    }
  }
}

class CustomsBrokerAdvanceModel {
  final int id;
  final String advanceCode;
  final int importFileId;
  final int brokerId;
  final String brokerName;
  final double advanceAmount;
  final String disbursementDate;
  final String paymentMethod;
  final String status;
  final double settledAmount;
  final double remainingBalance;
  final String? notes;
  final List<BrokerSettlementReceiptModel> receipts;

  const CustomsBrokerAdvanceModel({
    required this.id,
    required this.advanceCode,
    required this.importFileId,
    required this.brokerId,
    required this.brokerName,
    required this.advanceAmount,
    required this.disbursementDate,
    required this.paymentMethod,
    required this.status,
    required this.settledAmount,
    required this.remainingBalance,
    this.notes,
    this.receipts = const [],
  });

  factory CustomsBrokerAdvanceModel.fromJson(Map<String, dynamic> json) {
    final rawReceipts = json['receipts'] as List? ?? [];
    return CustomsBrokerAdvanceModel(
      id: json['id'] as int? ?? 0,
      advanceCode: json['advance_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      brokerId: json['broker_id'] as int? ?? 0,
      brokerName: json['broker_name'] as String? ?? '',
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0.0,
      disbursementDate: json['disbursement_date'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'BANK_TRANSFER',
      status: json['status'] as String? ?? 'OPEN',
      settledAmount: (json['settled_amount'] as num?)?.toDouble() ?? 0.0,
      remainingBalance: (json['remaining_balance'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      receipts: rawReceipts
          .map((r) => BrokerSettlementReceiptModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  String get localizedStatus {
    switch (status) {
      case 'SETTLED':
        return 'مسددة ومقفلة بالكامل';
      case 'PARTIALLY_SETTLED':
        return 'تسوية جزئية جارية';
      case 'OPEN':
      default:
        return 'عهدة مفتوحة تحت الصرف';
    }
  }

  String get localizedPaymentMethod {
    switch (paymentMethod) {
      case 'CASH':
        return 'صرف نقدي من الخزينة';
      case 'CHECK':
        return 'شيك مصرفي مسحوب';
      case 'BANK_TRANSFER':
      default:
        return 'تحويل بنكي رسمي';
    }
  }
}

class CustomsSettlementVarianceModel {
  final int advanceId;
  final String advanceCode;
  final double advanceAmount;
  final double totalReceiptsAmount;
  final double totalTaxWithheld;
  final double totalNetSettled;
  final double varianceAmount;
  final String status;
  final double whiteReceiptsTotal;
  final double redReceiptsTotal;
  final double portReceiptsTotal;
  final double brokerFeesTotal;
  final double otherReceiptsTotal;
  final int verifiedReceiptsCount;
  final int pendingReceiptsCount;

  const CustomsSettlementVarianceModel({
    required this.advanceId,
    required this.advanceCode,
    required this.advanceAmount,
    required this.totalReceiptsAmount,
    required this.totalTaxWithheld,
    required this.totalNetSettled,
    required this.varianceAmount,
    required this.status,
    required this.whiteReceiptsTotal,
    required this.redReceiptsTotal,
    required this.portReceiptsTotal,
    required this.brokerFeesTotal,
    required this.otherReceiptsTotal,
    required this.verifiedReceiptsCount,
    required this.pendingReceiptsCount,
  });

  factory CustomsSettlementVarianceModel.fromJson(Map<String, dynamic> json) {
    return CustomsSettlementVarianceModel(
      advanceId: json['advance_id'] as int? ?? 0,
      advanceCode: json['advance_code'] as String? ?? '',
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0.0,
      totalReceiptsAmount: (json['total_receipts_amount'] as num?)?.toDouble() ?? 0.0,
      totalTaxWithheld: (json['total_tax_withheld'] as num?)?.toDouble() ?? 0.0,
      totalNetSettled: (json['total_net_settled'] as num?)?.toDouble() ?? 0.0,
      varianceAmount: (json['variance_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'OPEN',
      whiteReceiptsTotal: (json['white_receipts_total'] as num?)?.toDouble() ?? 0.0,
      redReceiptsTotal: (json['red_receipts_total'] as num?)?.toDouble() ?? 0.0,
      portReceiptsTotal: (json['port_receipts_total'] as num?)?.toDouble() ?? 0.0,
      brokerFeesTotal: (json['broker_fees_total'] as num?)?.toDouble() ?? 0.0,
      otherReceiptsTotal: (json['other_receipts_total'] as num?)?.toDouble() ?? 0.0,
      verifiedReceiptsCount: json['verified_receipts_count'] as int? ?? 0,
      pendingReceiptsCount: json['pending_receipts_count'] as int? ?? 0,
    );
  }
}
