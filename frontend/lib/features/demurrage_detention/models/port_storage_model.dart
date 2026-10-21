class PortTierDetailModel {
  final String tierName;
  final int days;
  final double ratePerDay;
  final double totalAmount;

  PortTierDetailModel({
    required this.tierName,
    required this.days,
    required this.ratePerDay,
    required this.totalAmount,
  });

  factory PortTierDetailModel.fromJson(Map<String, dynamic> json) {
    return PortTierDetailModel(
      tierName: json['tier_name'] ?? '',
      days: json['days'] ?? 0,
      ratePerDay: (json['rate_per_day'] ?? 0.0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
    );
  }
}

class PortStorageBreakdownModel {
  final String terminalCode;
  final String terminalName;
  final String containerSize;
  final bool isReefer;
  final String gateInDate;
  final String endDate;
  final int totalDays;
  final int freeDaysAllowed;
  final int chargeableDays;
  final int tier1Days;
  final double tier1Rate;
  final double tier1Amount;
  final int tier2Days;
  final double tier2Rate;
  final double tier2Amount;
  final int penalDays;
  final double penalRate;
  final double penalAmount;
  final double storageChargesEgp;
  final double reeferPluggingChargesEgp;
  final double xrayScanFeeEgp;
  final double scaleFeeEgp;
  final double totalPortStorageEgp;
  final String currency;
  final List<PortTierDetailModel> tierDetails;

  PortStorageBreakdownModel({
    required this.terminalCode,
    required this.terminalName,
    required this.containerSize,
    required this.isReefer,
    required this.gateInDate,
    required this.endDate,
    required this.totalDays,
    required this.freeDaysAllowed,
    required this.chargeableDays,
    required this.tier1Days,
    required this.tier1Rate,
    required this.tier1Amount,
    required this.tier2Days,
    required this.tier2Rate,
    required this.tier2Amount,
    required this.penalDays,
    required this.penalRate,
    required this.penalAmount,
    required this.storageChargesEgp,
    required this.reeferPluggingChargesEgp,
    required this.xrayScanFeeEgp,
    required this.scaleFeeEgp,
    required this.totalPortStorageEgp,
    this.currency = 'EGP',
    this.tierDetails = const [],
  });

  factory PortStorageBreakdownModel.fromJson(Map<String, dynamic> json) {
    var rawTiers = json['tier_details'] as List? ?? [];
    return PortStorageBreakdownModel(
      terminalCode: json['terminal_code'] ?? '',
      terminalName: json['terminal_name'] ?? '',
      containerSize: json['container_size'] ?? '20ft',
      isReefer: json['is_reefer'] ?? false,
      gateInDate: json['gate_in_date'] ?? '',
      endDate: json['end_date'] ?? '',
      totalDays: json['total_days'] ?? 0,
      freeDaysAllowed: json['free_days_allowed'] ?? 0,
      chargeableDays: json['chargeable_days'] ?? 0,
      tier1Days: json['tier1_days'] ?? 0,
      tier1Rate: (json['tier1_rate'] ?? 0.0).toDouble(),
      tier1Amount: (json['tier1_amount'] ?? 0.0).toDouble(),
      tier2Days: json['tier2_days'] ?? 0,
      tier2Rate: (json['tier2_rate'] ?? 0.0).toDouble(),
      tier2Amount: (json['tier2_amount'] ?? 0.0).toDouble(),
      penalDays: json['penal_days'] ?? 0,
      penalRate: (json['penal_rate'] ?? 0.0).toDouble(),
      penalAmount: (json['penal_amount'] ?? 0.0).toDouble(),
      storageChargesEgp: (json['storage_charges_egp'] ?? 0.0).toDouble(),
      reeferPluggingChargesEgp: (json['reefer_plugging_charges_egp'] ?? 0.0).toDouble(),
      xrayScanFeeEgp: (json['xray_scan_fee_egp'] ?? 0.0).toDouble(),
      scaleFeeEgp: (json['scale_fee_egp'] ?? 0.0).toDouble(),
      totalPortStorageEgp: (json['total_port_storage_egp'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'EGP',
      tierDetails: rawTiers.map((t) => PortTierDetailModel.fromJson(t)).toList(),
    );
  }
}

class PortTerminalRateModel {
  final int rateId;
  final String terminalCode;
  final String terminalName;
  final String containerSize;
  final bool isReefer;
  final int freeDays;
  final double tier1DailyRate;
  final double tier2DailyRate;
  final double penalDailyRate;
  final double reeferPlugDailyRate;
  final double xrayScanFee;
  final double scaleFee;
  final String effectiveDate;

  PortTerminalRateModel({
    required this.rateId,
    required this.terminalCode,
    required this.terminalName,
    required this.containerSize,
    this.isReefer = false,
    this.freeDays = 3,
    required this.tier1DailyRate,
    required this.tier2DailyRate,
    required this.penalDailyRate,
    this.reeferPlugDailyRate = 0.0,
    this.xrayScanFee = 0.0,
    this.scaleFee = 0.0,
    required this.effectiveDate,
  });

  factory PortTerminalRateModel.fromJson(Map<String, dynamic> json) {
    return PortTerminalRateModel(
      rateId: json['rate_id'] ?? 0,
      terminalCode: json['terminal_code'] ?? '',
      terminalName: json['terminal_name'] ?? '',
      containerSize: json['container_size'] ?? '20ft',
      isReefer: json['is_reefer'] ?? false,
      freeDays: json['free_days'] ?? 3,
      tier1DailyRate: (json['tier1_daily_rate'] ?? 0.0).toDouble(),
      tier2DailyRate: (json['tier2_daily_rate'] ?? 0.0).toDouble(),
      penalDailyRate: (json['penal_daily_rate'] ?? 0.0).toDouble(),
      reeferPlugDailyRate: (json['reefer_plug_daily_rate'] ?? 0.0).toDouble(),
      xrayScanFee: (json['xray_scan_fee'] ?? 0.0).toDouble(),
      scaleFee: (json['scale_fee'] ?? 0.0).toDouble(),
      effectiveDate: json['effective_date'] ?? '',
    );
  }
}
