class BankCharge {
  final int id;
  final int financeInstrumentId;
  final String chargeType;
  final String currency;
  final double amount;
  final double amountEgp;
  final String debitDate;
  final String? debitAccount;
  final String? swiftReference;
  final String? notes;

  const BankCharge({
    required this.id,
    required this.financeInstrumentId,
    required this.chargeType,
    required this.currency,
    required this.amount,
    required this.amountEgp,
    required this.debitDate,
    this.debitAccount,
    this.swiftReference,
    this.notes,
  });

  factory BankCharge.fromJson(Map<String, dynamic> json) {
    return BankCharge(
      id: json['id'] as int? ?? 0,
      financeInstrumentId: json['finance_instrument_id'] as int? ?? 0,
      chargeType: json['charge_type'] as String? ?? '',
      currency: json['currency'] as String? ?? 'EGP',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      amountEgp: (json['amount_egp'] as num?)?.toDouble() ?? 0.0,
      debitDate: json['debit_date'] as String? ?? '',
      debitAccount: json['debit_account'] as String?,
      swiftReference: json['swift_reference'] as String?,
      notes: json['notes'] as String?,
    );
  }

  String get localizedChargeType {
    switch (chargeType) {
      case 'ISSUANCE_COMMISSION':
        return 'عمولة فتح الاعتماد المستندي';
      case 'AMENDMENT_FEE':
        return 'مصاريف تعديل شروط الاعتماد';
      case 'SWIFT_CHARGE':
        return 'مصاريف رسائل السويفت البنكية';
      case 'PAYMENT_COMMISSION':
        return 'عمولة السداد والتحويل للمورد';
      case 'CONFIRMATION_FEE':
        return 'مصاريف تعزيز بنكي دولي';
      case 'DISCREPANCY_FEE':
        return 'مصاريف تحفظات ومخالفات مستندية';
      default:
        return chargeType;
    }
  }
}

class FxVarianceRecord {
  final int id;
  final int financeInstrumentId;
  final String foreignCurrency;
  final double originalAmount;
  final String bookingDate;
  final double bookingRate;
  final double bookingTotalEgp;
  final String? settlementDate;
  final double? settlementRate;
  final double? settlementTotalEgp;
  final String? hedgingContractRef;
  final double varianceAmountEgp;
  final String varianceNature;
  final String? notes;

  const FxVarianceRecord({
    required this.id,
    required this.financeInstrumentId,
    required this.foreignCurrency,
    required this.originalAmount,
    required this.bookingDate,
    required this.bookingRate,
    required this.bookingTotalEgp,
    this.settlementDate,
    this.settlementRate,
    this.settlementTotalEgp,
    this.hedgingContractRef,
    required this.varianceAmountEgp,
    required this.varianceNature,
    this.notes,
  });

  factory FxVarianceRecord.fromJson(Map<String, dynamic> json) {
    return FxVarianceRecord(
      id: json['id'] as int? ?? 0,
      financeInstrumentId: json['finance_instrument_id'] as int? ?? 0,
      foreignCurrency: json['foreign_currency'] as String? ?? 'USD',
      originalAmount: (json['original_amount'] as num?)?.toDouble() ?? 0.0,
      bookingDate: json['booking_date'] as String? ?? '',
      bookingRate: (json['booking_rate'] as num?)?.toDouble() ?? 1.0,
      bookingTotalEgp: (json['booking_total_egp'] as num?)?.toDouble() ?? 0.0,
      settlementDate: json['settlement_date'] as String?,
      settlementRate: (json['settlement_rate'] as num?)?.toDouble(),
      settlementTotalEgp: (json['settlement_total_egp'] as num?)?.toDouble(),
      hedgingContractRef: json['hedging_contract_ref'] as String?,
      varianceAmountEgp: (json['variance_amount_egp'] as num?)?.toDouble() ?? 0.0,
      varianceNature: json['variance_nature'] as String? ?? 'NEUTRAL',
      notes: json['notes'] as String?,
    );
  }

  String get localizedNature {
    switch (varianceNature) {
      case 'UNFAVORABLE_LOSS':
        return 'خسائر تقلبات سعر الصرف';
      case 'FAVORABLE_GAIN':
        return 'وفورات وأرباح فروق العملة';
      case 'NEUTRAL':
      default:
        return 'سعر ثابت بدون فروق';
    }
  }
}

class FinanceInstrument {
  final int id;
  final String instrumentType;
  final String instrumentNumber;
  final int importFileId;
  final String issuingBank;
  final String? advisingBank;
  final String currency;
  final double amount;
  final String? issueDate;
  final String? expiryDate;
  final String? shipmentDeadline;
  final int presentationPeriodDays;
  final String? paymentTerms;
  final String status;
  final double tolerancePercentage;
  final String? notes;
  final List<BankCharge> charges;
  final List<FxVarianceRecord> fxRecords;

  const FinanceInstrument({
    required this.id,
    required this.instrumentType,
    required this.instrumentNumber,
    required this.importFileId,
    required this.issuingBank,
    this.advisingBank,
    required this.currency,
    required this.amount,
    this.issueDate,
    this.expiryDate,
    this.shipmentDeadline,
    required this.presentationPeriodDays,
    this.paymentTerms,
    required this.status,
    required this.tolerancePercentage,
    this.notes,
    this.charges = const [],
    this.fxRecords = const [],
  });

  factory FinanceInstrument.fromJson(Map<String, dynamic> json) {
    final rawCharges = json['charges'] as List? ?? [];
    final rawFx = json['fx_records'] as List? ?? [];

    return FinanceInstrument(
      id: json['id'] as int? ?? 0,
      instrumentType: json['instrument_type'] as String? ?? 'LC',
      instrumentNumber: json['instrument_number'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      issuingBank: json['issuing_bank'] as String? ?? '',
      advisingBank: json['advising_bank'] as String?,
      currency: json['currency'] as String? ?? 'USD',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      issueDate: json['issue_date'] as String?,
      expiryDate: json['expiry_date'] as String?,
      shipmentDeadline: json['shipment_deadline'] as String?,
      presentationPeriodDays: json['presentation_period_days'] as int? ?? 21,
      paymentTerms: json['payment_terms'] as String?,
      status: json['status'] as String? ?? 'DRAFT',
      tolerancePercentage: (json['tolerance_percentage'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      charges: rawCharges.map((c) => BankCharge.fromJson(c as Map<String, dynamic>)).toList(),
      fxRecords: rawFx.map((f) => FxVarianceRecord.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }

  String get localizedType {
    switch (instrumentType) {
      case 'LC':
        return 'اعتماد مستندي بنكي';
      case 'CAD':
        return 'تحصيل مستندي ومستندات برسم التحصيل';
      case 'ADVANCE_PAYMENT':
        return 'دفعة نقدية مقدمة للمورد';
      case 'OPEN_ACCOUNT':
        return 'حساب مفتوح وتسهيلات موردين';
      default:
        return instrumentType;
    }
  }

  String get localizedStatus {
    switch (status) {
      case 'DRAFT':
        return 'مسودة قيد التجهيز';
      case 'ISSUED':
        return 'تم الفتح والإصدار البنكي';
      case 'ACCEPTED':
        return 'مستندات مقبولة للدفع';
      case 'SETTLED':
        return 'مسدد بالكامل';
      case 'CANCELLED':
        return 'ملغى';
      default:
        return status;
    }
  }
}
