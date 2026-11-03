import '../../../shipping_scenarios/models/shipping_scenario_model.dart';
import '../../services/booking_charge_builder.dart';

/// Mutable state snapshot for freight quote items and breakdown values.
class BookingQuoteFormData {
  String mainQuoteCurrency = 'USD';
  double? originalQuoteTotalUsd;
  double? originalContainer40ftPrice, originalContainer20ftPrice, originalLclCbmPrice, originalExpressCourierPrice;

  bool container40ftApp = false, container20ftApp = false, lclCbmApp = false, expressCourierApp = false;
  bool eurAtrApp = false, solasVgmApp = false, vgmNotifApp = false, telexReleaseApp = false;
  bool insuranceApp = false, cancellationApp = false, ics2App = false, otherFeesApp = false;
  bool docFeesApp = false, waiverApp = false, dthcApp = false, storagePerWeekApp = false, extraDayStorageApp = false;

  double container40ftPrice = 0.0, container20ftPrice = 0.0, lclCbmPrice = 0.0, expressCourierPrice = 0.0;
  double eurAtrPrice = 0.0, solasVgmPrice = 0.0, vgmNotifPrice = 0.0, telexReleasePrice = 0.0;
  double insurancePrice = 0.0, cancellationPrice = 0.0, ics2Price = 0.0, otherFeesPrice = 0.0;
  double docFeesPrice = 0.0, waiverPrice = 0.0, dthcPrice = 0.0, storagePerWeekPrice = 0.0, extraDayStoragePrice = 0.0;

  String container40ftCur = 'USD', container20ftCur = 'USD', lclCbmCur = 'USD', expressCourierCur = 'USD';
  String eurAtrCur = 'USD', solasVgmCur = 'USD', vgmNotifCur = 'USD', telexReleaseCur = 'USD';
  String insuranceCur = 'USD', cancellationCur = 'USD', ics2Cur = 'USD', otherFeesCur = 'USD';
  String docFeesCur = 'USD', waiverCur = 'USD', dthcCur = 'USD', storagePerWeekCur = 'USD', extraDayStorageCur = 'USD';

  int container40ftQty = 1, container20ftQty = 0;
  double lclCbmQty = 0.0;

  void loadFromMap(Map<String, dynamic> q, {double? fallbackOriginalQuoteTotalUsd}) {
    mainQuoteCurrency = q['main_quote_currency'] ?? 'USD';
    originalQuoteTotalUsd = (q['original_quote_total_usd'] as num?)?.toDouble() ?? fallbackOriginalQuoteTotalUsd;
    originalContainer40ftPrice = (q['original_container_40ft_price'] as num?)?.toDouble();
    originalContainer20ftPrice = (q['original_container_20ft_price'] as num?)?.toDouble();
    originalLclCbmPrice = (q['original_lcl_cbm_price'] as num?)?.toDouble();
    originalExpressCourierPrice = (q['original_express_courier_price'] as num?)?.toDouble();

    double dbl(String k) => (q[k] as num?)?.toDouble() ?? 0.0;
    container40ftApp = q['container_40ft_app'] ?? false;
    container40ftPrice = dbl('container_40ft_price');
    container40ftCur = q['container_40ft_cur'] ?? 'USD';
    container40ftQty = q['container_40ft_qty'] ?? 1;

    container20ftApp = q['container_20ft_app'] ?? false;
    container20ftPrice = dbl('container_20ft_price');
    container20ftCur = q['container_20ft_cur'] ?? 'USD';
    container20ftQty = q['container_20ft_qty'] ?? 0;

    lclCbmApp = q['lcl_cbm_app'] ?? false;
    lclCbmPrice = dbl('lcl_cbm_price');
    lclCbmCur = q['lcl_cbm_cur'] ?? 'USD';
    lclCbmQty = dbl('lcl_cbm_qty');

    expressCourierApp = q['express_courier_app'] ?? false;
    expressCourierPrice = dbl('express_courier_price');
    expressCourierCur = q['express_courier_cur'] ?? 'USD';

    eurAtrApp = q['eur_atr_app'] ?? false;
    eurAtrPrice = dbl('eur_atr_price');
    eurAtrCur = q['eur_atr_cur'] ?? 'USD';

    solasVgmApp = q['solas_vgm_app'] ?? false;
    solasVgmPrice = dbl('solas_vgm_price');
    solasVgmCur = q['solas_vgm_cur'] ?? 'USD';

    vgmNotifApp = q['vgm_notif_app'] ?? false;
    vgmNotifPrice = dbl('vgm_notif_price');
    vgmNotifCur = q['vgm_notif_cur'] ?? 'USD';

    telexReleaseApp = q['telex_release_app'] ?? false;
    telexReleasePrice = dbl('telex_release_price');
    telexReleaseCur = q['telex_release_cur'] ?? 'USD';

    insuranceApp = q['insurance_app'] ?? false;
    insurancePrice = dbl('insurance_price');
    insuranceCur = q['insurance_cur'] ?? 'USD';

    cancellationApp = q['cancellation_app'] ?? false;
    cancellationPrice = dbl('cancellation_price');
    cancellationCur = q['cancellation_cur'] ?? 'USD';

    ics2App = q['ics2_app'] ?? false;
    ics2Price = dbl('ics2_price');
    ics2Cur = q['ics2_cur'] ?? 'USD';

    otherFeesApp = q['other_fees_app'] ?? false;
    otherFeesPrice = dbl('other_fees_price');
    otherFeesCur = q['other_fees_cur'] ?? 'USD';

    docFeesApp = q['doc_fees_app'] ?? false;
    docFeesPrice = dbl('doc_fees_price');
    docFeesCur = q['doc_fees_cur'] ?? 'USD';

    waiverApp = q['waiver_app'] ?? false;
    waiverPrice = dbl('waiver_price');
    waiverCur = q['waiver_cur'] ?? 'USD';

    dthcApp = q['dthc_app'] ?? false;
    dthcPrice = dbl('dthc_price');
    dthcCur = q['dthc_cur'] ?? 'USD';

    storagePerWeekApp = q['storage_per_week_app'] ?? false;
    storagePerWeekPrice = dbl('storage_per_week_price');
    storagePerWeekCur = q['storage_per_week_cur'] ?? 'USD';

    extraDayStorageApp = q['extra_day_storage_app'] ?? false;
    extraDayStoragePrice = dbl('extra_day_storage_price');
    extraDayStorageCur = q['extra_day_storage_cur'] ?? 'USD';
  }

  Map<String, dynamic> toMap() => {
        'main_quote_currency': mainQuoteCurrency,
        'container_40ft_app': container40ftApp,
        'container_40ft_price': container40ftPrice,
        'container_40ft_cur': container40ftCur,
        'container_40ft_qty': container40ftQty,
        'container_20ft_app': container20ftApp,
        'container_20ft_price': container20ftPrice,
        'container_20ft_cur': container20ftCur,
        'container_20ft_qty': container20ftQty,
        'lcl_cbm_app': lclCbmApp,
        'lcl_cbm_price': lclCbmPrice,
        'lcl_cbm_cur': lclCbmCur,
        'lcl_cbm_qty': lclCbmQty,
        'express_courier_app': expressCourierApp,
        'express_courier_price': expressCourierPrice,
        'express_courier_cur': expressCourierCur,
        'eur_atr_app': eurAtrApp,
        'eur_atr_price': eurAtrPrice,
        'eur_atr_cur': eurAtrCur,
        'solas_vgm_app': solasVgmApp,
        'solas_vgm_price': solasVgmPrice,
        'solas_vgm_cur': solasVgmCur,
        'vgm_notif_app': vgmNotifApp,
        'vgm_notif_price': vgmNotifPrice,
        'vgm_notif_cur': vgmNotifCur,
        'telex_release_app': telexReleaseApp,
        'telex_release_price': telexReleasePrice,
        'telex_release_cur': telexReleaseCur,
        'insurance_app': insuranceApp,
        'insurance_price': insurancePrice,
        'insurance_cur': insuranceCur,
        'cancellation_app': cancellationApp,
        'cancellation_price': cancellationPrice,
        'cancellation_cur': cancellationCur,
        'ics2_app': ics2App,
        'ics2_price': ics2Price,
        'ics2_cur': ics2Cur,
        'other_fees_app': otherFeesApp,
        'other_fees_price': otherFeesPrice,
        'other_fees_cur': otherFeesCur,
        'doc_fees_app': docFeesApp,
        'doc_fees_price': docFeesPrice,
        'doc_fees_cur': docFeesCur,
        'waiver_app': waiverApp,
        'waiver_price': waiverPrice,
        'waiver_cur': waiverCur,
        'dthc_app': dthcApp,
        'dthc_price': dthcPrice,
        'dthc_cur': dthcCur,
        'storage_per_week_app': storagePerWeekApp,
        'storage_per_week_price': storagePerWeekPrice,
        'storage_per_week_cur': storagePerWeekCur,
        'extra_day_storage_app': extraDayStorageApp,
        'extra_day_storage_price': extraDayStoragePrice,
        'extra_day_storage_cur': extraDayStorageCur,
        if (originalQuoteTotalUsd != null) 'original_quote_total_usd': originalQuoteTotalUsd,
        if (originalContainer40ftPrice != null) 'original_container_40ft_price': originalContainer40ftPrice,
        if (originalContainer20ftPrice != null) 'original_container_20ft_price': originalContainer20ftPrice,
        if (originalLclCbmPrice != null) 'original_lcl_cbm_price': originalLclCbmPrice,
        if (originalExpressCourierPrice != null) 'original_express_courier_price': originalExpressCourierPrice,
      };

  void applyScenarioItem(ShippingScenarioItemModel item) {
    if (item.quotationCurrency != null) mainQuoteCurrency = item.quotationCurrency!;
    originalQuoteTotalUsd = item.totalQuotationAmount;
    originalContainer40ftPrice = item.container40ftPrice;
    originalContainer20ftPrice = item.container20ftPrice;
    originalLclCbmPrice = item.lclCbmPrice;
    originalExpressCourierPrice = item.expressCourierPrice;

    container40ftApp = item.container40ftApplicable;
    container40ftPrice = item.container40ftPrice;
    container40ftCur = item.container40ftCurrency ?? container40ftCur;
    container40ftQty = item.container40ftQty > 0 ? item.container40ftQty : 1;

    container20ftApp = item.container20ftApplicable;
    container20ftPrice = item.container20ftPrice;
    container20ftCur = item.container20ftCurrency ?? container20ftCur;
    container20ftQty = item.container20ftQty;

    lclCbmApp = item.lclCbmApplicable;
    lclCbmPrice = item.lclCbmPrice;
    lclCbmCur = item.lclCbmCurrency ?? lclCbmCur;
    lclCbmQty = item.lclCbmQty;

    expressCourierApp = item.expressCourierApplicable;
    expressCourierPrice = item.expressCourierPrice;
    expressCourierCur = item.expressCourierCurrency ?? expressCourierCur;

    eurAtrApp = item.eurAtrApplicable;
    eurAtrPrice = item.eurAtrPrice;
    eurAtrCur = item.eurAtrCurrency ?? eurAtrCur;

    solasVgmApp = item.solasVgmApplicable;
    solasVgmPrice = item.solasVgmPrice;
    solasVgmCur = item.solasVgmCurrency ?? solasVgmCur;

    vgmNotifApp = item.vgmNotificationApplicable;
    vgmNotifPrice = item.vgmNotificationPrice;
    vgmNotifCur = item.vgmNotificationCurrency ?? vgmNotifCur;

    telexReleaseApp = item.telexReleaseApplicable;
    telexReleasePrice = item.telexReleasePrice;
    telexReleaseCur = item.telexReleaseCurrency ?? telexReleaseCur;

    insuranceApp = item.insuranceApplicable;
    insurancePrice = item.insurancePrice;
    insuranceCur = item.insuranceCurrency ?? insuranceCur;

    cancellationApp = item.bookingCancellationApplicable;
    cancellationPrice = item.bookingCancellationPrice;
    cancellationCur = item.bookingCancellationCurrency ?? cancellationCur;

    ics2App = item.ics2FilingFeeApplicable;
    ics2Price = item.ics2FilingFeePrice;
    ics2Cur = item.ics2FilingFeeCurrency ?? ics2Cur;

    otherFeesApp = item.othersFeeApplicable;
    otherFeesPrice = item.othersFeePrice;
    otherFeesCur = item.othersFeeCurrency ?? otherFeesCur;

    docFeesApp = item.documentFeesApplicable;
    docFeesPrice = item.documentFeesPrice;
    docFeesCur = item.documentFeesCurrency ?? docFeesCur;

    waiverApp = item.waiverLetterFeeApplicable;
    waiverPrice = item.waiverLetterFeePrice;
    waiverCur = item.waiverLetterFeeCurrency ?? waiverCur;

    dthcApp = item.dthcApplicable;
    dthcPrice = item.dthcPrice;
    dthcCur = item.dthcCurrency ?? dthcCur;

    storagePerWeekApp = item.storagePerWeekApplicable;
    storagePerWeekPrice = item.storagePerWeekPrice;
    storagePerWeekCur = item.storagePerWeekCurrency ?? storagePerWeekCur;

    extraDayStorageApp = item.extraDayStorageApplicable;
    extraDayStoragePrice = item.extraDayStoragePrice;
    extraDayStorageCur = item.extraDayStorageCurrency ?? extraDayStorageCur;
  }

  void reset() {
    mainQuoteCurrency = 'USD';
    originalQuoteTotalUsd = null;
    originalContainer40ftPrice = originalContainer20ftPrice = originalLclCbmPrice = originalExpressCourierPrice = null;
    container40ftApp = container20ftApp = lclCbmApp = expressCourierApp = eurAtrApp = solasVgmApp = vgmNotifApp = telexReleaseApp = insuranceApp = cancellationApp = ics2App = otherFeesApp = docFeesApp = waiverApp = dthcApp = storagePerWeekApp = extraDayStorageApp = false;
    container40ftPrice = container20ftPrice = lclCbmPrice = expressCourierPrice = eurAtrPrice = solasVgmPrice = vgmNotifPrice = telexReleasePrice = insurancePrice = cancellationPrice = ics2Price = otherFeesPrice = docFeesPrice = waiverPrice = dthcPrice = storagePerWeekPrice = extraDayStoragePrice = 0.0;
    container40ftCur = container20ftCur = lclCbmCur = expressCourierCur = eurAtrCur = solasVgmCur = vgmNotifCur = telexReleaseCur = insuranceCur = cancellationCur = ics2Cur = otherFeesCur = docFeesCur = waiverCur = dthcCur = storagePerWeekCur = extraDayStorageCur = 'USD';
    container40ftQty = 1;
    container20ftQty = 0;
    lclCbmQty = 0.0;
  }

  FbkQuoteState toQuoteState() => FbkQuoteState(
        container40ftApp: container40ftApp,
        container40ftPrice: container40ftPrice,
        container40ftCur: container40ftCur,
        container40ftQty: container40ftQty,
        container20ftApp: container20ftApp,
        container20ftPrice: container20ftPrice,
        container20ftCur: container20ftCur,
        container20ftQty: container20ftQty,
        lclCbmApp: lclCbmApp,
        lclCbmPrice: lclCbmPrice,
        lclCbmCur: lclCbmCur,
        lclCbmQty: lclCbmQty,
        dthcApp: dthcApp,
        dthcPrice: dthcPrice,
        dthcCur: dthcCur,
        storagePerWeekApp: storagePerWeekApp,
        storagePerWeekPrice: storagePerWeekPrice,
        storagePerWeekCur: storagePerWeekCur,
        extraDayStorageApp: extraDayStorageApp,
        extraDayStoragePrice: extraDayStoragePrice,
        extraDayStorageCur: extraDayStorageCur,
        solasVgmApp: solasVgmApp,
        solasVgmPrice: solasVgmPrice,
        solasVgmCur: solasVgmCur,
        vgmNotifApp: vgmNotifApp,
        vgmNotifPrice: vgmNotifPrice,
        vgmNotifCur: vgmNotifCur,
        telexReleaseApp: telexReleaseApp,
        telexReleasePrice: telexReleasePrice,
        telexReleaseCur: telexReleaseCur,
        expressCourierApp: expressCourierApp,
        expressCourierPrice: expressCourierPrice,
        expressCourierCur: expressCourierCur,
        eurAtrApp: eurAtrApp,
        eurAtrPrice: eurAtrPrice,
        eurAtrCur: eurAtrCur,
        insuranceApp: insuranceApp,
        insurancePrice: insurancePrice,
        insuranceCur: insuranceCur,
        docFeesApp: docFeesApp,
        docFeesPrice: docFeesPrice,
        docFeesCur: docFeesCur,
        waiverApp: waiverApp,
        waiverPrice: waiverPrice,
        waiverCur: waiverCur,
        ics2App: ics2App,
        ics2Price: ics2Price,
        ics2Cur: ics2Cur,
        otherFeesApp: otherFeesApp,
        otherFeesPrice: otherFeesPrice,
        otherFeesCur: otherFeesCur,
        cancellationApp: cancellationApp,
        cancellationPrice: cancellationPrice,
        cancellationCur: cancellationCur,
      );
}
