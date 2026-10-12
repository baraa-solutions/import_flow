class ShippingScenarioItemModel {
  final int? itemId;
  final int? providerId;
  final String providerName;
  final int? customsBrokerId;
  final String? customsBrokerName;
  final String vesselName;
  final String? voyageNumber;
  final int? portOfLoadingId;
  final int? portOfDischargeId;
  final String? polName;
  final String? podName;
  final String sailingDate;
  final String estimatedArrivalDate;
  final int expectedLineDelayDays;
  final bool isExcludedFromAverage;
  final bool isRecommended;
  final bool isSelected;
  final String riskLevel;
  final String? notes;

  // Calculated fields
  final int vesselLeadTimeDays;
  final int readyForShippingDays;
  final int expectedTotalDaysToWarehouse;
  final String expectedWarehouseArrivalDate;

  // Quotation breakdown fields
  final int freeTimeDays;
  final String quotationCurrency;
  final double totalQuotationAmount;

  final bool container40ftApplicable;
  final double container40ftPrice;
  final String container40ftCurrency;
  final int container40ftQty;

  final bool container20ftApplicable;
  final double container20ftPrice;
  final String container20ftCurrency;
  final int container20ftQty;

  final bool lclCbmApplicable;
  final double lclCbmPrice;
  final String lclCbmCurrency;
  final double lclCbmQty;

  final bool expressCourierApplicable;
  final double expressCourierPrice;
  final String expressCourierCurrency;

  final bool eurAtrApplicable;
  final double eurAtrPrice;
  final String eurAtrCurrency;

  final bool solasVgmApplicable;
  final double solasVgmPrice;
  final String solasVgmCurrency;

  final bool vgmNotificationApplicable;
  final double vgmNotificationPrice;
  final String vgmNotificationCurrency;

  final bool telexReleaseApplicable;
  final double telexReleasePrice;
  final String telexReleaseCurrency;

  final bool insuranceApplicable;
  final double insurancePrice;
  final String insuranceCurrency;

  final bool bookingCancellationApplicable;
  final double bookingCancellationPrice;
  final String bookingCancellationCurrency;

  // 4 New fee fields requested by user
  final bool ics2FilingFeeApplicable;
  final double ics2FilingFeePrice;
  final String ics2FilingFeeCurrency;

  final bool othersFeeApplicable;
  final double othersFeePrice;
  final String othersFeeCurrency;

  final bool documentFeesApplicable;
  final double documentFeesPrice;
  final String documentFeesCurrency;

  final bool waiverLetterFeeApplicable;
  final double waiverLetterFeePrice;
  final String waiverLetterFeeCurrency;

  // New quotation fees: DTHC, Storage per week, Extra day storage
  final bool dthcApplicable;
  final double dthcPrice;
  final String dthcCurrency;

  final bool storagePerWeekApplicable;
  final double storagePerWeekPrice;
  final String storagePerWeekCurrency;

  final bool extraDayStorageApplicable;
  final double extraDayStoragePrice;
  final String extraDayStorageCurrency;

  // Customs clearance quotation integration fields
  final bool clearanceFeeApplicable;
  final double clearanceFeePrice;
  final String clearanceFeeCurrency;

  final bool inspectionFeeApplicable;
  final double inspectionFeePrice;
  final String inspectionFeeCurrency;

  final bool inlandTransportFeeApplicable;
  final double inlandTransportFeePrice;
  final String inlandTransportFeeCurrency;

  final bool portExpensesApplicable;
  final double portExpensesPrice;
  final String portExpensesCurrency;

  ShippingScenarioItemModel({
    this.itemId,
    this.providerId,
    required this.providerName,
    this.customsBrokerId,
    this.customsBrokerName,
    required this.vesselName,
    this.voyageNumber,
    this.portOfLoadingId,
    this.portOfDischargeId,
    this.polName,
    this.podName,
    required this.sailingDate,
    required this.estimatedArrivalDate,
    this.expectedLineDelayDays = 0,
    this.isExcludedFromAverage = false,
    this.isRecommended = false,
    this.isSelected = false,
    this.riskLevel = 'Low',
    this.notes,
    this.vesselLeadTimeDays = 0,
    this.readyForShippingDays = 0,
    this.expectedTotalDaysToWarehouse = 0,
    this.expectedWarehouseArrivalDate = '',
    
    // Quotation defaults
    this.freeTimeDays = 14,
    this.quotationCurrency = 'USD',
    this.totalQuotationAmount = 0.0,
    
    this.container40ftApplicable = false,
    this.container40ftPrice = 0.0,
    this.container40ftCurrency = 'USD',
    this.container40ftQty = 0,
    
    this.container20ftApplicable = false,
    this.container20ftPrice = 0.0,
    this.container20ftCurrency = 'USD',
    this.container20ftQty = 0,
    
    this.lclCbmApplicable = false,
    this.lclCbmPrice = 0.0,
    this.lclCbmCurrency = 'USD',
    this.lclCbmQty = 0.0,
    
    this.expressCourierApplicable = false,
    this.expressCourierPrice = 0.0,
    this.expressCourierCurrency = 'USD',
    
    this.eurAtrApplicable = false,
    this.eurAtrPrice = 0.0,
    this.eurAtrCurrency = 'USD',
    
    this.solasVgmApplicable = false,
    this.solasVgmPrice = 0.0,
    this.solasVgmCurrency = 'USD',
    
    this.vgmNotificationApplicable = false,
    this.vgmNotificationPrice = 0.0,
    this.vgmNotificationCurrency = 'USD',
    
    this.telexReleaseApplicable = false,
    this.telexReleasePrice = 0.0,
    this.telexReleaseCurrency = 'USD',
    
    this.insuranceApplicable = false,
    this.insurancePrice = 0.0,
    this.insuranceCurrency = 'USD',
    
    this.bookingCancellationApplicable = false,
    this.bookingCancellationPrice = 0.0,
    this.bookingCancellationCurrency = 'USD',

    // New fee defaults
    this.ics2FilingFeeApplicable = false,
    this.ics2FilingFeePrice = 0.0,
    this.ics2FilingFeeCurrency = 'USD',

    this.othersFeeApplicable = false,
    this.othersFeePrice = 0.0,
    this.othersFeeCurrency = 'USD',

    this.documentFeesApplicable = false,
    this.documentFeesPrice = 0.0,
    this.documentFeesCurrency = 'USD',

    this.waiverLetterFeeApplicable = false,
    this.waiverLetterFeePrice = 0.0,
    this.waiverLetterFeeCurrency = 'USD',

    this.dthcApplicable = false,
    this.dthcPrice = 0.0,
    this.dthcCurrency = 'USD',

    this.storagePerWeekApplicable = false,
    this.storagePerWeekPrice = 0.0,
    this.storagePerWeekCurrency = 'USD',

    this.extraDayStorageApplicable = false,
    this.extraDayStoragePrice = 0.0,
    this.extraDayStorageCurrency = 'USD',

    this.clearanceFeeApplicable = false,
    this.clearanceFeePrice = 0.0,
    this.clearanceFeeCurrency = 'EGP',

    this.inspectionFeeApplicable = false,
    this.inspectionFeePrice = 0.0,
    this.inspectionFeeCurrency = 'EGP',

    this.inlandTransportFeeApplicable = false,
    this.inlandTransportFeePrice = 0.0,
    this.inlandTransportFeeCurrency = 'EGP',

    this.portExpensesApplicable = false,
    this.portExpensesPrice = 0.0,
    this.portExpensesCurrency = 'EGP',
  });

  factory ShippingScenarioItemModel.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }
    int toInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? 0;
    }

    return ShippingScenarioItemModel(
      itemId: json['item_id'],
      providerId: json['provider_id'],
      providerName: json['provider_name'] ?? '',
      customsBrokerId: json['customs_broker_id'],
      customsBrokerName: json['customs_broker_name'],
      vesselName: json['vessel_name'] ?? '',
      voyageNumber: json['voyage_number'],
      portOfLoadingId: json['port_of_loading_id'],
      portOfDischargeId: json['port_of_discharge_id'],
      polName: json['pol_name'],
      podName: json['pod_name'],
      sailingDate: json['sailing_date'] ?? '',
      estimatedArrivalDate: json['estimated_arrival_date'] ?? '',
      expectedLineDelayDays: toInt(json['expected_line_delay_days']),
      isExcludedFromAverage: json['is_excluded_from_average'] ?? false,
      isRecommended: json['is_recommended'] ?? false,
      isSelected: json['is_selected'] ?? false,
      riskLevel: json['risk_level'] ?? 'Low',
      notes: json['notes'],
      vesselLeadTimeDays: toInt(json['vessel_lead_time_days']),
      readyForShippingDays: toInt(json['ready_for_shipping_days']),
      expectedTotalDaysToWarehouse: toInt(json['expected_total_days_to_warehouse']),
      expectedWarehouseArrivalDate: json['expected_warehouse_arrival_date'] ?? '',

      // Quotation values
      freeTimeDays: toInt(json['free_time_days'] ?? 14),
      quotationCurrency: json['quotation_currency'] ?? 'USD',
      totalQuotationAmount: toDouble(json['total_quotation_amount']),
      
      container40ftApplicable: json['container_40ft_applicable'] ?? false,
      container40ftPrice: toDouble(json['container_40ft_price']),
      container40ftCurrency: json['container_40ft_currency'] ?? 'USD',
      container40ftQty: toInt(json['container_40ft_qty']),

      container20ftApplicable: json['container_20ft_applicable'] ?? false,
      container20ftPrice: toDouble(json['container_20ft_price']),
      container20ftCurrency: json['container_20ft_currency'] ?? 'USD',
      container20ftQty: toInt(json['container_20ft_qty']),

      lclCbmApplicable: json['lcl_cbm_applicable'] ?? false,
      lclCbmPrice: toDouble(json['lcl_cbm_price']),
      lclCbmCurrency: json['lcl_cbm_currency'] ?? 'USD',
      lclCbmQty: toDouble(json['lcl_cbm_qty']),

      expressCourierApplicable: json['express_courier_applicable'] ?? false,
      expressCourierPrice: toDouble(json['express_courier_price']),
      expressCourierCurrency: json['express_courier_currency'] ?? 'USD',

      eurAtrApplicable: json['eur_atr_applicable'] ?? false,
      eurAtrPrice: toDouble(json['eur_atr_price']),
      eurAtrCurrency: json['eur_atr_currency'] ?? 'USD',

      solasVgmApplicable: json['solas_vgm_applicable'] ?? false,
      solasVgmPrice: toDouble(json['solas_vgm_price']),
      solasVgmCurrency: json['solas_vgm_currency'] ?? 'USD',

      vgmNotificationApplicable: json['vgm_notification_applicable'] ?? false,
      vgmNotificationPrice: toDouble(json['vgm_notification_price']),
      vgmNotificationCurrency: json['vgm_notification_currency'] ?? 'USD',

      telexReleaseApplicable: json['telex_release_applicable'] ?? false,
      telexReleasePrice: toDouble(json['telex_release_price']),
      telexReleaseCurrency: json['telex_release_currency'] ?? 'USD',

      insuranceApplicable: json['insurance_applicable'] ?? false,
      insurancePrice: toDouble(json['insurance_price']),
      insuranceCurrency: json['insurance_currency'] ?? 'USD',

      bookingCancellationApplicable: json['booking_cancellation_applicable'] ?? false,
      bookingCancellationPrice: toDouble(json['booking_cancellation_price']),
      bookingCancellationCurrency: json['booking_cancellation_currency'] ?? 'USD',

      // New fee fields parsing
      ics2FilingFeeApplicable: json['ics2_filing_fee_applicable'] ?? false,
      ics2FilingFeePrice: toDouble(json['ics2_filing_fee_price']),
      ics2FilingFeeCurrency: json['ics2_filing_fee_currency'] ?? 'USD',

      othersFeeApplicable: json['others_fee_applicable'] ?? false,
      othersFeePrice: toDouble(json['others_fee_price']),
      othersFeeCurrency: json['others_fee_currency'] ?? 'USD',

      documentFeesApplicable: json['document_fees_applicable'] ?? false,
      documentFeesPrice: toDouble(json['document_fees_price']),
      documentFeesCurrency: json['document_fees_currency'] ?? 'USD',

      waiverLetterFeeApplicable: json['waiver_letter_fee_applicable'] ?? false,
      waiverLetterFeePrice: toDouble(json['waiver_letter_fee_price']),
      waiverLetterFeeCurrency: json['waiver_letter_fee_currency'] ?? 'USD',

      dthcApplicable: json['dthc_applicable'] ?? false,
      dthcPrice: toDouble(json['dthc_price']),
      dthcCurrency: json['dthc_currency'] ?? 'USD',

      storagePerWeekApplicable: json['storage_per_week_applicable'] ?? false,
      storagePerWeekPrice: toDouble(json['storage_per_week_price']),
      storagePerWeekCurrency: json['storage_per_week_currency'] ?? 'USD',

      extraDayStorageApplicable: json['extra_day_storage_applicable'] ?? false,
      extraDayStoragePrice: toDouble(json['extra_day_storage_price']),
      extraDayStorageCurrency: json['extra_day_storage_currency'] ?? 'USD',

      clearanceFeeApplicable: json['clearance_fee_applicable'] ?? false,
      clearanceFeePrice: toDouble(json['clearance_fee_price']),
      clearanceFeeCurrency: json['clearance_fee_currency'] ?? 'EGP',

      inspectionFeeApplicable: json['inspection_fee_applicable'] ?? false,
      inspectionFeePrice: toDouble(json['inspection_fee_price']),
      inspectionFeeCurrency: json['inspection_fee_currency'] ?? 'EGP',

      inlandTransportFeeApplicable: json['inland_transport_fee_applicable'] ?? false,
      inlandTransportFeePrice: toDouble(json['inland_transport_fee_price']),
      inlandTransportFeeCurrency: json['inland_transport_fee_currency'] ?? 'EGP',

      portExpensesApplicable: json['port_expenses_applicable'] ?? false,
      portExpensesPrice: toDouble(json['port_expenses_price']),
      portExpensesCurrency: json['port_expenses_currency'] ?? 'EGP',
    );
  }

  Map<String, dynamic> toJson() => toCreateJson();

  Map<String, dynamic> toCreateJson() {
    return {
      if (itemId != null) 'item_id': itemId,
      if (providerId != null) 'provider_id': providerId,
      'provider_name': providerName,
      if (customsBrokerId != null) 'customs_broker_id': customsBrokerId,
      if (customsBrokerName != null && customsBrokerName!.isNotEmpty) 'customs_broker_name': customsBrokerName,
      'vessel_name': vesselName,
      if (voyageNumber != null && voyageNumber!.isNotEmpty) 'voyage_number': voyageNumber,
      if (portOfLoadingId != null) 'port_of_loading_id': portOfLoadingId,
      if (portOfDischargeId != null) 'port_of_discharge_id': portOfDischargeId,
      if (polName != null && polName!.isNotEmpty) 'pol_name': polName,
      if (podName != null && podName!.isNotEmpty) 'pod_name': podName,
      'sailing_date': sailingDate,
      'estimated_arrival_date': estimatedArrivalDate,
      'expected_line_delay_days': expectedLineDelayDays,
      'is_excluded_from_average': isExcludedFromAverage,
      'is_recommended': isRecommended,
      'is_selected': isSelected,
      'risk_level': riskLevel,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,

      // Quotation values
      'free_time_days': freeTimeDays,
      'quotation_currency': quotationCurrency,
      'total_quotation_amount': totalQuotationAmount,
      
      'container_40ft_applicable': container40ftApplicable,
      'container_40ft_price': container40ftPrice,
      'container_40ft_currency': container40ftCurrency,
      'container_40ft_qty': container40ftQty,

      'container_20ft_applicable': container20ftApplicable,
      'container_20ft_price': container20ftPrice,
      'container_20ft_currency': container20ftCurrency,
      'container_20ft_qty': container20ftQty,

      'lcl_cbm_applicable': lclCbmApplicable,
      'lcl_cbm_price': lclCbmPrice,
      'lcl_cbm_currency': lclCbmCurrency,
      'lcl_cbm_qty': lclCbmQty,

      'express_courier_applicable': expressCourierApplicable,
      'express_courier_price': expressCourierPrice,
      'express_courier_currency': expressCourierCurrency,

      'eur_atr_applicable': eurAtrApplicable,
      'eur_atr_price': eurAtrPrice,
      'eur_atr_currency': eurAtrCurrency,

      'solas_vgm_applicable': solasVgmApplicable,
      'solas_vgm_price': solasVgmPrice,
      'solas_vgm_currency': solasVgmCurrency,

      'vgm_notification_applicable': vgmNotificationApplicable,
      'vgm_notification_price': vgmNotificationPrice,
      'vgm_notification_currency': vgmNotificationCurrency,

      'telex_release_applicable': telexReleaseApplicable,
      'telex_release_price': telexReleasePrice,
      'telex_release_currency': telexReleaseCurrency,

      'insurance_applicable': insuranceApplicable,
      'insurance_price': insurancePrice,
      'insurance_currency': insuranceCurrency,

      'booking_cancellation_applicable': bookingCancellationApplicable,
      'booking_cancellation_price': bookingCancellationPrice,
      'booking_cancellation_currency': bookingCancellationCurrency,

      // New fee fields serialization
      'ics2_filing_fee_applicable': ics2FilingFeeApplicable,
      'ics2_filing_fee_price': ics2FilingFeePrice,
      'ics2_filing_fee_currency': ics2FilingFeeCurrency,

      'others_fee_applicable': othersFeeApplicable,
      'others_fee_price': othersFeePrice,
      'others_fee_currency': othersFeeCurrency,

      'document_fees_applicable': documentFeesApplicable,
      'document_fees_price': documentFeesPrice,
      'document_fees_currency': documentFeesCurrency,

      'waiver_letter_fee_applicable': waiverLetterFeeApplicable,
      'waiver_letter_fee_price': waiverLetterFeePrice,
      'waiver_letter_fee_currency': waiverLetterFeeCurrency,

      'dthc_applicable': dthcApplicable,
      'dthc_price': dthcPrice,
      'dthc_currency': dthcCurrency,

      'storage_per_week_applicable': storagePerWeekApplicable,
      'storage_per_week_price': storagePerWeekPrice,
      'storage_per_week_currency': storagePerWeekCurrency,

      'extra_day_storage_applicable': extraDayStorageApplicable,
      'extra_day_storage_price': extraDayStoragePrice,
      'extra_day_storage_currency': extraDayStorageCurrency,

      'clearance_fee_applicable': clearanceFeeApplicable,
      'clearance_fee_price': clearanceFeePrice,
      'clearance_fee_currency': clearanceFeeCurrency,

      'inspection_fee_applicable': inspectionFeeApplicable,
      'inspection_fee_price': inspectionFeePrice,
      'inspection_fee_currency': inspectionFeeCurrency,

      'inland_transport_fee_applicable': inlandTransportFeeApplicable,
      'inland_transport_fee_price': inlandTransportFeePrice,
      'inland_transport_fee_currency': inlandTransportFeeCurrency,

      'port_expenses_applicable': portExpensesApplicable,
      'port_expenses_price': portExpensesPrice,
      'port_expenses_currency': portExpensesCurrency,
    };
  }

  ShippingScenarioItemModel copyWith({
    int? itemId,
    int? providerId,
    String? providerName,
    int? customsBrokerId,
    String? customsBrokerName,
    String? vesselName,
    String? voyageNumber,
    int? portOfLoadingId,
    int? portOfDischargeId,
    String? polName,
    String? podName,
    String? sailingDate,
    String? estimatedArrivalDate,
    int? expectedLineDelayDays,
    bool? isExcludedFromAverage,
    bool? isRecommended,
    bool? isSelected,
    String? riskLevel,
    String? notes,
    int? freeTimeDays,
    String? quotationCurrency,
    double? totalQuotationAmount,
    bool? container40ftApplicable,
    double? container40ftPrice,
    String? container40ftCurrency,
    int? container40ftQty,
    bool? container20ftApplicable,
    double? container20ftPrice,
    String? container20ftCurrency,
    int? container20ftQty,
    bool? lclCbmApplicable,
    double? lclCbmPrice,
    String? lclCbmCurrency,
    double? lclCbmQty,
    bool? expressCourierApplicable,
    double? expressCourierPrice,
    String? expressCourierCurrency,
    bool? eurAtrApplicable,
    double? eurAtrPrice,
    String? eurAtrCurrency,
    bool? solasVgmApplicable,
    double? solasVgmPrice,
    String? solasVgmCurrency,
    bool? vgmNotificationApplicable,
    double? vgmNotificationPrice,
    String? vgmNotificationCurrency,
    bool? telexReleaseApplicable,
    double? telexReleasePrice,
    String? telexReleaseCurrency,
    bool? insuranceApplicable,
    double? insurancePrice,
    String? insuranceCurrency,
    bool? bookingCancellationApplicable,
    double? bookingCancellationPrice,
    String? bookingCancellationCurrency,

    // New fee fields copyWith
    bool? ics2FilingFeeApplicable,
    double? ics2FilingFeePrice,
    String? ics2FilingFeeCurrency,

    bool? othersFeeApplicable,
    double? othersFeePrice,
    String? othersFeeCurrency,

    bool? documentFeesApplicable,
    double? documentFeesPrice,
    String? documentFeesCurrency,

    bool? waiverLetterFeeApplicable,
    double? waiverLetterFeePrice,
    String? waiverLetterFeeCurrency,

    bool? dthcApplicable,
    double? dthcPrice,
    String? dthcCurrency,

    bool? storagePerWeekApplicable,
    double? storagePerWeekPrice,
    String? storagePerWeekCurrency,

    bool? extraDayStorageApplicable,
    double? extraDayStoragePrice,
    String? extraDayStorageCurrency,

    bool? clearanceFeeApplicable,
    double? clearanceFeePrice,
    String? clearanceFeeCurrency,

    bool? inspectionFeeApplicable,
    double? inspectionFeePrice,
    String? inspectionFeeCurrency,

    bool? inlandTransportFeeApplicable,
    double? inlandTransportFeePrice,
    String? inlandTransportFeeCurrency,

    bool? portExpensesApplicable,
    double? portExpensesPrice,
    String? portExpensesCurrency,
  }) {
    return ShippingScenarioItemModel(
      itemId: itemId ?? this.itemId,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      customsBrokerId: customsBrokerId ?? this.customsBrokerId,
      customsBrokerName: customsBrokerName ?? this.customsBrokerName,
      vesselName: vesselName ?? this.vesselName,
      voyageNumber: voyageNumber ?? this.voyageNumber,
      portOfLoadingId: portOfLoadingId ?? this.portOfLoadingId,
      portOfDischargeId: portOfDischargeId ?? this.portOfDischargeId,
      polName: polName ?? this.polName,
      podName: podName ?? this.podName,
      sailingDate: sailingDate ?? this.sailingDate,
      estimatedArrivalDate: estimatedArrivalDate ?? this.estimatedArrivalDate,
      expectedLineDelayDays: expectedLineDelayDays ?? this.expectedLineDelayDays,
      isExcludedFromAverage: isExcludedFromAverage ?? this.isExcludedFromAverage,
      isRecommended: isRecommended ?? this.isRecommended,
      isSelected: isSelected ?? this.isSelected,
      riskLevel: riskLevel ?? this.riskLevel,
      notes: notes ?? this.notes,
      
      freeTimeDays: freeTimeDays ?? this.freeTimeDays,
      quotationCurrency: quotationCurrency ?? this.quotationCurrency,
      totalQuotationAmount: totalQuotationAmount ?? this.totalQuotationAmount,
      container40ftApplicable: container40ftApplicable ?? this.container40ftApplicable,
      container40ftPrice: container40ftPrice ?? this.container40ftPrice,
      container40ftCurrency: container40ftCurrency ?? this.container40ftCurrency,
      container40ftQty: container40ftQty ?? this.container40ftQty,
      container20ftApplicable: container20ftApplicable ?? this.container20ftApplicable,
      container20ftPrice: container20ftPrice ?? this.container20ftPrice,
      container20ftCurrency: container20ftCurrency ?? this.container20ftCurrency,
      container20ftQty: container20ftQty ?? this.container20ftQty,
      lclCbmApplicable: lclCbmApplicable ?? this.lclCbmApplicable,
      lclCbmPrice: lclCbmPrice ?? this.lclCbmPrice,
      lclCbmCurrency: lclCbmCurrency ?? this.lclCbmCurrency,
      lclCbmQty: lclCbmQty ?? this.lclCbmQty,
      expressCourierApplicable: expressCourierApplicable ?? this.expressCourierApplicable,
      expressCourierPrice: expressCourierPrice ?? this.expressCourierPrice,
      expressCourierCurrency: expressCourierCurrency ?? this.expressCourierCurrency,
      eurAtrApplicable: eurAtrApplicable ?? this.eurAtrApplicable,
      eurAtrPrice: eurAtrPrice ?? this.eurAtrPrice,
      eurAtrCurrency: eurAtrCurrency ?? this.eurAtrCurrency,
      solasVgmApplicable: solasVgmApplicable ?? this.solasVgmApplicable,
      solasVgmPrice: solasVgmPrice ?? this.solasVgmPrice,
      solasVgmCurrency: solasVgmCurrency ?? this.solasVgmCurrency,
      vgmNotificationApplicable: vgmNotificationApplicable ?? this.vgmNotificationApplicable,
      vgmNotificationPrice: vgmNotificationPrice ?? this.vgmNotificationPrice,
      vgmNotificationCurrency: vgmNotificationCurrency ?? this.vgmNotificationCurrency,
      telexReleaseApplicable: telexReleaseApplicable ?? this.telexReleaseApplicable,
      telexReleasePrice: telexReleasePrice ?? this.telexReleasePrice,
      telexReleaseCurrency: telexReleaseCurrency ?? this.telexReleaseCurrency,
      insuranceApplicable: insuranceApplicable ?? this.insuranceApplicable,
      insurancePrice: insurancePrice ?? this.insurancePrice,
      insuranceCurrency: insuranceCurrency ?? this.insuranceCurrency,
      bookingCancellationApplicable: bookingCancellationApplicable ?? this.bookingCancellationApplicable,
      bookingCancellationPrice: bookingCancellationPrice ?? this.bookingCancellationPrice,
      bookingCancellationCurrency: bookingCancellationCurrency ?? this.bookingCancellationCurrency,

      // New fee fields copyWith mapping
      ics2FilingFeeApplicable: ics2FilingFeeApplicable ?? this.ics2FilingFeeApplicable,
      ics2FilingFeePrice: ics2FilingFeePrice ?? this.ics2FilingFeePrice,
      ics2FilingFeeCurrency: ics2FilingFeeCurrency ?? this.ics2FilingFeeCurrency,

      othersFeeApplicable: othersFeeApplicable ?? this.othersFeeApplicable,
      othersFeePrice: othersFeePrice ?? this.othersFeePrice,
      othersFeeCurrency: othersFeeCurrency ?? this.othersFeeCurrency,

      documentFeesApplicable: documentFeesApplicable ?? this.documentFeesApplicable,
      documentFeesPrice: documentFeesPrice ?? this.documentFeesPrice,
      documentFeesCurrency: documentFeesCurrency ?? this.documentFeesCurrency,

      waiverLetterFeeApplicable: waiverLetterFeeApplicable ?? this.waiverLetterFeeApplicable,
      waiverLetterFeePrice: waiverLetterFeePrice ?? this.waiverLetterFeePrice,
      waiverLetterFeeCurrency: waiverLetterFeeCurrency ?? this.waiverLetterFeeCurrency,

      dthcApplicable: dthcApplicable ?? this.dthcApplicable,
      dthcPrice: dthcPrice ?? this.dthcPrice,
      dthcCurrency: dthcCurrency ?? this.dthcCurrency,

      storagePerWeekApplicable: storagePerWeekApplicable ?? this.storagePerWeekApplicable,
      storagePerWeekPrice: storagePerWeekPrice ?? this.storagePerWeekPrice,
      storagePerWeekCurrency: storagePerWeekCurrency ?? this.storagePerWeekCurrency,

      extraDayStorageApplicable: extraDayStorageApplicable ?? this.extraDayStorageApplicable,
      extraDayStoragePrice: extraDayStoragePrice ?? this.extraDayStoragePrice,
      extraDayStorageCurrency: extraDayStorageCurrency ?? this.extraDayStorageCurrency,

      clearanceFeeApplicable: clearanceFeeApplicable ?? this.clearanceFeeApplicable,
      clearanceFeePrice: clearanceFeePrice ?? this.clearanceFeePrice,
      clearanceFeeCurrency: clearanceFeeCurrency ?? this.clearanceFeeCurrency,

      inspectionFeeApplicable: inspectionFeeApplicable ?? this.inspectionFeeApplicable,
      inspectionFeePrice: inspectionFeePrice ?? this.inspectionFeePrice,
      inspectionFeeCurrency: inspectionFeeCurrency ?? this.inspectionFeeCurrency,

      inlandTransportFeeApplicable: inlandTransportFeeApplicable ?? this.inlandTransportFeeApplicable,
      inlandTransportFeePrice: inlandTransportFeePrice ?? this.inlandTransportFeePrice,
      inlandTransportFeeCurrency: inlandTransportFeeCurrency ?? this.inlandTransportFeeCurrency,

      portExpensesApplicable: portExpensesApplicable ?? this.portExpensesApplicable,
      portExpensesPrice: portExpensesPrice ?? this.portExpensesPrice,
      portExpensesCurrency: portExpensesCurrency ?? this.portExpensesCurrency,
    );
  }
}

class ShippingEvaluationModel {
  final int? sessionId;
  final String sessionCode;
  final String? title;
  final int? importFileId;
  final String cargoReadyDate;
  final String? pickUpAddress;
  final int? portOfLoadingId;
  final int? portOfDischargeId;
  final int avgForm4Days;
  final int avgClearanceDays;
  final int? poId;
  final int? projectId;
  final String? notes;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  final String? importFileCode;
  final String? poNumber;
  final String? projectName;
  final String? polName;
  final String? podName;

  final List<ShippingScenarioItemModel> items;

  // Calculated metrics
  final double avgExpectedTransitDays;
  final String? avgExpectedWarehouseArrivalDate;
  final String? earliestArrivalScenarioProvider;
  final String? earliestArrivalDate;
  final String? latestArrivalScenarioProvider;
  final String? latestArrivalDate;
  final String? recommendedScenarioProvider;

  ShippingEvaluationModel({
    this.sessionId,
    required this.sessionCode,
    this.title,
    this.importFileId,
    required this.cargoReadyDate,
    this.pickUpAddress,
    this.portOfLoadingId,
    this.portOfDischargeId,
    this.avgForm4Days = 5,
    this.avgClearanceDays = 7,
    this.poId,
    this.projectId,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.importFileCode,
    this.poNumber,
    this.projectName,
    this.polName,
    this.podName,
    this.items = const [],
    this.avgExpectedTransitDays = 0.0,
    this.avgExpectedWarehouseArrivalDate,
    this.earliestArrivalScenarioProvider,
    this.earliestArrivalDate,
    this.latestArrivalScenarioProvider,
    this.latestArrivalDate,
    this.recommendedScenarioProvider,
  });

  factory ShippingEvaluationModel.fromJson(Map<String, dynamic> json) {
    return ShippingEvaluationModel(
      sessionId: json['session_id'],
      sessionCode: json['session_code'] ?? '',
      title: json['title'],
      importFileId: json['import_file_id'],
      cargoReadyDate: json['cargo_ready_date'] ?? '',
      pickUpAddress: json['pick_up_address'],
      portOfLoadingId: json['port_of_loading_id'],
      portOfDischargeId: json['port_of_discharge_id'],
      avgForm4Days: json['avg_form4_days'] ?? 5,
      avgClearanceDays: json['avg_clearance_days'] ?? 7,
      poId: json['po_id'],
      projectId: json['project_id'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      importFileCode: json['import_file_code'],
      poNumber: json['po_number'],
      projectName: json['project_name'],
      polName: json['pol_name'],
      podName: json['pod_name'],
      items: (json['items'] as List? ?? [])
          .map((i) => ShippingScenarioItemModel.fromJson(i))
          .toList(),
      avgExpectedTransitDays: (json['avg_expected_transit_days'] as num? ?? 0).toDouble(),
      avgExpectedWarehouseArrivalDate: json['avg_expected_warehouse_arrival_date'],
      earliestArrivalScenarioProvider: json['earliest_arrival_scenario_provider'],
      earliestArrivalDate: json['earliest_arrival_date'],
      latestArrivalScenarioProvider: json['latest_arrival_scenario_provider'],
      latestArrivalDate: json['latest_arrival_date'],
      recommendedScenarioProvider: json['recommended_scenario_provider'],
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      if (title != null && title!.isNotEmpty) 'title': title,
      if (importFileId != null) 'import_file_id': importFileId,
      'cargo_ready_date': cargoReadyDate,
      if (pickUpAddress != null && pickUpAddress!.isNotEmpty) 'pick_up_address': pickUpAddress,
      if (portOfLoadingId != null) 'port_of_loading_id': portOfLoadingId,
      if (portOfDischargeId != null) 'port_of_discharge_id': portOfDischargeId,
      'avg_form4_days': avgForm4Days,
      'avg_clearance_days': avgClearanceDays,
      if (poId != null) 'po_id': poId,
      if (projectId != null) 'project_id': projectId,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'items': items.map((i) => i.toCreateJson()).toList(),
    };
  }
}
