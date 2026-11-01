/// Data class representing an extracted freight quotation option.
class ExtractedQuotationOption {
  final int optionId;
  String carrierName;
  String? forwarderName;
  String? vesselName;
  String? voyageNumber;
  String containerType;
  double oceanFreight;
  double? localCharges;
  double? exwCharges;
  double totalEstimatedCost;
  String currency;
  String? incoterm;
  String? originPort;
  String? destinationPort;
  int? transitDays;
  bool isDirect;
  int? freeTimeDays;
  String? etdDate;
  String? etaDate;
  String? notes;
  bool isSelected;

  ExtractedQuotationOption({
    required this.optionId,
    required this.carrierName,
    this.forwarderName,
    this.vesselName,
    this.voyageNumber,
    required this.containerType,
    required this.oceanFreight,
    this.localCharges,
    this.exwCharges,
    required this.totalEstimatedCost,
    this.currency = 'USD',
    this.incoterm,
    this.originPort,
    this.destinationPort,
    this.transitDays,
    this.isDirect = true,
    this.freeTimeDays,
    this.etdDate,
    this.etaDate,
    this.notes,
    this.isSelected = true,
  });

  factory ExtractedQuotationOption.fromMap(Map<String, dynamic> map, int id) {
    final ocean = (map['ocean_freight'] as num?)?.toDouble() ??
        (map['freight_rate'] as num?)?.toDouble() ??
        0.0;
    final local = (map['local_charges'] as num?)?.toDouble();
    final exw = (map['exw_charges'] as num?)?.toDouble();
    final total = (map['total_estimated_cost'] as num?)?.toDouble() ?? (ocean + (local ?? 0.0));

    return ExtractedQuotationOption(
      optionId: id,
      carrierName: (map['carrier_name'] ?? 'Shipping Line').toString(),
      forwarderName: map['forwarder_name']?.toString(),
      vesselName: map['vessel_name']?.toString(),
      voyageNumber: map['voyage_number']?.toString(),
      containerType: (map['container_type'] ?? '40HQ').toString(),
      oceanFreight: ocean,
      localCharges: local,
      exwCharges: exw,
      totalEstimatedCost: total,
      currency: (map['currency'] ?? 'USD').toString(),
      incoterm: map['incoterm']?.toString(),
      originPort: map['origin_port']?.toString(),
      destinationPort: map['destination_port']?.toString(),
      transitDays: map['transit_days'] as int?,
      isDirect: map['is_direct'] as bool? ?? true,
      freeTimeDays: (map['free_time_days'] ?? map['free_days_demurrage']) as int?,
      etdDate: map['etd_date']?.toString(),
      etaDate: map['eta_date']?.toString(),
      notes: map['notes']?.toString(),
      isSelected: true,
    );
  }
}
