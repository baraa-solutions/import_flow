import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../freight_booking_cost_row.dart';
import '../freight_booking_ui.dart';
import 'booking_quote_form_data.dart';

export 'booking_quote_form_data.dart';

/// Cost Breakdown tab rendering the 16 quotation breakdown items and live savings.
class BookingFormChargesTab extends StatelessWidget {
  final BookingQuoteFormData quoteData;
  final int quoteRevision;
  final double computedCurrentExecutedFreight;
  final VoidCallback onQuoteChanged;

  const BookingFormChargesTab({
    super.key,
    required this.quoteData,
    required this.quoteRevision,
    required this.computedCurrentExecutedFreight,
    required this.onQuoteChanged,
  });

  Widget _liveSavingsBanner() {
    final orig = quoteData.originalQuoteTotalUsd;
    if (orig == null || orig <= 0) return const SizedBox.shrink();
    final exec = computedCurrentExecutedFreight;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: FbkSavingsSummary(
        original: orig,
        executed: exec,
        hasSavings: exec < orig,
        hasIncrease: exec > orig,
      ),
    );
  }

  Widget _costRow(
    String title,
    bool app,
    ValueChanged<bool> onApp,
    double price,
    ValueChanged<double> onPrice,
    String cur,
    ValueChanged<String> onCur, {
    int? qty,
    ValueChanged<int>? onQty,
    double? cbm,
    ValueChanged<double>? onCbm,
  }) {
    return FbkCostItemRow(
      key: ValueKey('fbkCost_${title}_$quoteRevision'),
      title: title,
      isApplicable: app,
      onToggle: (v) {
        onApp(v);
        onQuoteChanged();
      },
      price: price,
      onPriceChanged: (v) {
        onPrice(v);
        onQuoteChanged();
      },
      currency: cur,
      onCurrencyChanged: (v) {
        onCur(v);
        onQuoteChanged();
      },
      quantity: qty,
      onQuantityChanged: onQty == null
          ? null
          : (v) {
              onQty(v);
              onQuoteChanged();
            },
      doubleQty: cbm,
      onDoubleQtyChanged: onCbm == null
          ? null
          : (v) {
              onCbm(v);
              onQuoteChanged();
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.freightBookingCostBreakdownTitle,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
              ),
            ),
            AppStatusBadge(
              label: l.freightBookingBaseCurrencyLabel(quoteData.mainQuoteCurrency),
              severity: AppSeverity.info,
              size: AppStatusBadgeSize.small,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _liveSavingsBanner(),
        _costRow(
          l.freightBookingItem40ft,
          quoteData.container40ftApp,
          (v) => quoteData.container40ftApp = v,
          quoteData.container40ftPrice,
          (v) => quoteData.container40ftPrice = v,
          quoteData.container40ftCur,
          (v) => quoteData.container40ftCur = v,
          qty: quoteData.container40ftQty,
          onQty: (v) => quoteData.container40ftQty = v,
        ),
        _costRow(
          l.freightBookingItem20ft,
          quoteData.container20ftApp,
          (v) => quoteData.container20ftApp = v,
          quoteData.container20ftPrice,
          (v) => quoteData.container20ftPrice = v,
          quoteData.container20ftCur,
          (v) => quoteData.container20ftCur = v,
          qty: quoteData.container20ftQty,
          onQty: (v) => quoteData.container20ftQty = v,
        ),
        _costRow(
          l.freightBookingItemLcl,
          quoteData.lclCbmApp,
          (v) => quoteData.lclCbmApp = v,
          quoteData.lclCbmPrice,
          (v) => quoteData.lclCbmPrice = v,
          quoteData.lclCbmCur,
          (v) => quoteData.lclCbmCur = v,
          cbm: quoteData.lclCbmQty,
          onCbm: (v) => quoteData.lclCbmQty = v,
        ),
        _costRow(
          l.freightBookingItemCourier,
          quoteData.expressCourierApp,
          (v) => quoteData.expressCourierApp = v,
          quoteData.expressCourierPrice,
          (v) => quoteData.expressCourierPrice = v,
          quoteData.expressCourierCur,
          (v) => quoteData.expressCourierCur = v,
        ),
        _costRow(
          l.freightBookingItemEur1,
          quoteData.eurAtrApp,
          (v) => quoteData.eurAtrApp = v,
          quoteData.eurAtrPrice,
          (v) => quoteData.eurAtrPrice = v,
          quoteData.eurAtrCur,
          (v) => quoteData.eurAtrCur = v,
        ),
        _costRow(
          l.freightBookingItemVgm,
          quoteData.solasVgmApp,
          (v) => quoteData.solasVgmApp = v,
          quoteData.solasVgmPrice,
          (v) => quoteData.solasVgmPrice = v,
          quoteData.solasVgmCur,
          (v) => quoteData.solasVgmCur = v,
        ),
        _costRow(
          l.freightBookingItemVgmNotif,
          quoteData.vgmNotifApp,
          (v) => quoteData.vgmNotifApp = v,
          quoteData.vgmNotifPrice,
          (v) => quoteData.vgmNotifPrice = v,
          quoteData.vgmNotifCur,
          (v) => quoteData.vgmNotifCur = v,
        ),
        _costRow(
          l.freightBookingItemTelex,
          quoteData.telexReleaseApp,
          (v) => quoteData.telexReleaseApp = v,
          quoteData.telexReleasePrice,
          (v) => quoteData.telexReleasePrice = v,
          quoteData.telexReleaseCur,
          (v) => quoteData.telexReleaseCur = v,
        ),
        if (quoteData.insuranceApp || quoteData.insurancePrice > 0)
          Container(
            key: const ValueKey('fbkInsuranceHint'),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.freightBookingInsuranceHint,
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
              ],
            ),
          ),
        _costRow(
          l.freightBookingItemCancellation,
          quoteData.cancellationApp,
          (v) => quoteData.cancellationApp = v,
          quoteData.cancellationPrice,
          (v) => quoteData.cancellationPrice = v,
          quoteData.cancellationCur,
          (v) => quoteData.cancellationCur = v,
        ),
        _costRow(
          l.freightBookingItemIcs2,
          quoteData.ics2App,
          (v) => quoteData.ics2App = v,
          quoteData.ics2Price,
          (v) => quoteData.ics2Price = v,
          quoteData.ics2Cur,
          (v) => quoteData.ics2Cur = v,
        ),
        _costRow(
          l.freightBookingItemOther,
          quoteData.otherFeesApp,
          (v) => quoteData.otherFeesApp = v,
          quoteData.otherFeesPrice,
          (v) => quoteData.otherFeesPrice = v,
          quoteData.otherFeesCur,
          (v) => quoteData.otherFeesCur = v,
        ),
        _costRow(
          l.freightBookingItemDocFees,
          quoteData.docFeesApp,
          (v) => quoteData.docFeesApp = v,
          quoteData.docFeesPrice,
          (v) => quoteData.docFeesPrice = v,
          quoteData.docFeesCur,
          (v) => quoteData.docFeesCur = v,
        ),
        _costRow(
          l.freightBookingItemWaiver,
          quoteData.waiverApp,
          (v) => quoteData.waiverApp = v,
          quoteData.waiverPrice,
          (v) => quoteData.waiverPrice = v,
          quoteData.waiverCur,
          (v) => quoteData.waiverCur = v,
        ),
        _costRow(
          l.freightBookingItemDthc,
          quoteData.dthcApp,
          (v) => quoteData.dthcApp = v,
          quoteData.dthcPrice,
          (v) => quoteData.dthcPrice = v,
          quoteData.dthcCur,
          (v) => quoteData.dthcCur = v,
        ),
        _costRow(
          l.freightBookingItemStorageWeek,
          quoteData.storagePerWeekApp,
          (v) => quoteData.storagePerWeekApp = v,
          quoteData.storagePerWeekPrice,
          (v) => quoteData.storagePerWeekPrice = v,
          quoteData.storagePerWeekCur,
          (v) => quoteData.storagePerWeekCur = v,
        ),
        _costRow(
          l.freightBookingItemStorageExtra,
          quoteData.extraDayStorageApp,
          (v) => quoteData.extraDayStorageApp = v,
          quoteData.extraDayStoragePrice,
          (v) => quoteData.extraDayStoragePrice = v,
          quoteData.extraDayStorageCur,
          (v) => quoteData.extraDayStorageCur = v,
        ),
      ],
    );
  }
}
