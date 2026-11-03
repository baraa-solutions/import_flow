import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../currencies/models/currency_model.dart';
import '../../models/shipping_scenario_model.dart';
import '../../utils/shipping_scenario_calculator.dart';
import 'carrier_cost_breakdown_row.dart';

class CarrierQuotationBreakdownCard extends StatelessWidget {
  final int index;
  final ShippingScenarioItemModel item;
  final List<CurrencyModel> currenciesList;
  final int? editingSessionId;
  final int editFormVersion;
  final ValueChanged<ShippingScenarioItemModel> onUpdateItem;

  const CarrierQuotationBreakdownCard({
    super.key,
    required this.index,
    required this.item,
    required this.currenciesList,
    required this.editingSessionId,
    required this.editFormVersion,
    required this.onUpdateItem,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentContainersCount = (item.container40ftApplicable ? item.container40ftQty : 0) +
        (item.container20ftApplicable ? item.container20ftQty : 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInputBackground : AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.request_quote, color: AppTheme.cobalt, size: 18),
              const SizedBox(width: 6),
              Text(l.quoteDetails, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
            ],
          ),
          const Divider(height: 16),

          // Row A: Free time & Main Quote Currency
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('freetime_${editingSessionId ?? "new"}_${index}_$editFormVersion'),
                  initialValue: item.freeTimeDays.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.freeTimeDaysCol, isDense: true, suffixText: 'd'),
                  onChanged: (v) {
                    final ft = int.tryParse(v) ?? 14;
                    onUpdateItem(item.copyWith(freeTimeDays: ft));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SearchableDropdownField<String>(
                  value: currenciesList.any((c) => c.currencyCode == item.quotationCurrency)
                      ? item.quotationCurrency
                      : (currenciesList.isNotEmpty ? currenciesList.first.currencyCode : 'USD'),
                  labelText: l.quoteCurrencyCol,
                  items: currenciesList.map((c) => SearchableDropdownItem(
                        value: c.currencyCode,
                        label: '${c.currencyCode} - ${c.currencySymbol}',
                      )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      onUpdateItem(item.copyWith(quotationCurrency: v));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table/Grid of Cost Items
          CarrierCostBreakdownRow(
            rowKey: 'container40ft_$index',
            title: '1. ${l.container40ftItem}',
            applicable: item.container40ftApplicable,
            price: item.container40ftPrice,
            currency: item.container40ftCurrency,
            qty: item.container40ftQty.toDouble(),
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(container40ftApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(container40ftPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(container40ftCurrency: v)),
            onQtyChanged: (v) => onUpdateItem(item.copyWith(container40ftQty: v.toInt())),
            showQty: true,
            isIntegerQty: true,
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'container20ft_$index',
            title: '2. ${l.container20ftItem}',
            applicable: item.container20ftApplicable,
            price: item.container20ftPrice,
            currency: item.container20ftCurrency,
            qty: item.container20ftQty.toDouble(),
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(container20ftApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(container20ftPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(container20ftCurrency: v)),
            onQtyChanged: (v) => onUpdateItem(item.copyWith(container20ftQty: v.toInt())),
            showQty: true,
            isIntegerQty: true,
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'lclCbm_$index',
            title: '3. ${l.lclCbmItem}',
            applicable: item.lclCbmApplicable,
            price: item.lclCbmPrice,
            currency: item.lclCbmCurrency,
            qty: item.lclCbmQty,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(lclCbmApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(lclCbmPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(lclCbmCurrency: v)),
            onQtyChanged: (v) => onUpdateItem(item.copyWith(lclCbmQty: v)),
            showQty: true,
            isIntegerQty: false,
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),

          // Total containers label
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(
              l.totalContainersCount(
                currentContainersCount,
                item.container40ftApplicable ? item.container40ftQty : 0,
                item.container20ftApplicable ? item.container20ftQty : 0,
              ),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt),
            ),
          ),

          CarrierCostBreakdownRow(
            rowKey: 'expressCourier_$index',
            title: '4. ${l.expressCourierItem}',
            applicable: item.expressCourierApplicable,
            price: item.expressCourierPrice,
            currency: item.expressCourierCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(expressCourierApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(expressCourierPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(expressCourierCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'eurAtr_$index',
            title: '5. ${l.eurAtrItem}',
            applicable: item.eurAtrApplicable,
            price: item.eurAtrPrice,
            currency: item.eurAtrCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(eurAtrApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(eurAtrPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(eurAtrCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'solasVgm_$index',
            title: '6. ${l.solasVgmItem}',
            applicable: item.solasVgmApplicable,
            price: item.solasVgmPrice,
            currency: item.solasVgmCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(solasVgmApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(solasVgmPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(solasVgmCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'vgmNotification_$index',
            title: '7. ${l.vgmNotificationItem}',
            applicable: item.vgmNotificationApplicable,
            price: item.vgmNotificationPrice,
            currency: item.vgmNotificationCurrency,
            qty: currentContainersCount.toDouble(),
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(vgmNotificationApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(vgmNotificationPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(vgmNotificationCurrency: v)),
            showQty: true,
            qtyReadOnly: true,
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'telexRelease_$index',
            title: '8. ${l.telexReleaseItem}',
            applicable: item.telexReleaseApplicable,
            price: item.telexReleasePrice,
            currency: item.telexReleaseCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(telexReleaseApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(telexReleasePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(telexReleaseCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'insurance_$index',
            title: '9. ${l.insuranceItem}',
            applicable: item.insuranceApplicable,
            price: item.insurancePrice,
            currency: item.insuranceCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(insuranceApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(insurancePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(insuranceCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'bookingCancellation_$index',
            title: '10. ${l.bookingCancellationItem}',
            applicable: item.bookingCancellationApplicable,
            price: item.bookingCancellationPrice,
            currency: item.bookingCancellationCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(bookingCancellationApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(bookingCancellationPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(bookingCancellationCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'ics2FilingFee_$index',
            title: '11. ${l.ics2FilingFeeItem}',
            applicable: item.ics2FilingFeeApplicable,
            price: item.ics2FilingFeePrice,
            currency: item.ics2FilingFeeCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(ics2FilingFeeApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(ics2FilingFeePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(ics2FilingFeeCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'documentFees_$index',
            title: '12. ${l.documentFeesItem}',
            applicable: item.documentFeesApplicable,
            price: item.documentFeesPrice,
            currency: item.documentFeesCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(documentFeesApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(documentFeesPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(documentFeesCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'waiverLetterFee_$index',
            title: '13. ${l.waiverLetterFeeItem}',
            applicable: item.waiverLetterFeeApplicable,
            price: item.waiverLetterFeePrice,
            currency: item.waiverLetterFeeCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(waiverLetterFeeApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(waiverLetterFeePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(waiverLetterFeeCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'othersFee_$index',
            title: '14. ${l.othersFeeItem}',
            applicable: item.othersFeeApplicable,
            price: item.othersFeePrice,
            currency: item.othersFeeCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(othersFeeApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(othersFeePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(othersFeeCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'dthc_$index',
            title: '15. ${l.dthcItem}',
            applicable: item.dthcApplicable,
            price: item.dthcPrice,
            currency: item.dthcCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(dthcApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(dthcPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(dthcCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'storagePerWeek_$index',
            title: '16. ${l.storagePerWeekItem}',
            applicable: item.storagePerWeekApplicable,
            price: item.storagePerWeekPrice,
            currency: item.storagePerWeekCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(storagePerWeekApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(storagePerWeekPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(storagePerWeekCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'extraDayStorage_$index',
            title: '17. ${l.extraDayStorageItem}',
            applicable: item.extraDayStorageApplicable,
            price: item.extraDayStoragePrice,
            currency: item.extraDayStorageCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(extraDayStorageApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(extraDayStoragePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(extraDayStorageCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'clearanceFee_$index',
            title: '18. ${l.clearanceBrokerFeeItem}',
            applicable: item.clearanceFeeApplicable,
            price: item.clearanceFeePrice,
            currency: item.clearanceFeeCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(clearanceFeeApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(clearanceFeePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(clearanceFeeCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'inspectionFee_$index',
            title: '19. ${l.inspectionFeeItem}',
            applicable: item.inspectionFeeApplicable,
            price: item.inspectionFeePrice,
            currency: item.inspectionFeeCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(inspectionFeeApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(inspectionFeePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(inspectionFeeCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'inlandTransport_$index',
            title: '20. ${l.inlandTransportFeeItem}',
            applicable: item.inlandTransportFeeApplicable,
            price: item.inlandTransportFeePrice,
            currency: item.inlandTransportFeeCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(inlandTransportFeeApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(inlandTransportFeePrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(inlandTransportFeeCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),
          CarrierCostBreakdownRow(
            rowKey: 'portExpenses_$index',
            title: '21. ${l.portClearanceExpensesItem}',
            applicable: item.portExpensesApplicable,
            price: item.portExpensesPrice,
            currency: item.portExpensesCurrency,
            onApplicableChanged: (v) => onUpdateItem(item.copyWith(portExpensesApplicable: v)),
            onPriceChanged: (v) => onUpdateItem(item.copyWith(portExpensesPrice: v)),
            onCurrencyChanged: (v) => onUpdateItem(item.copyWith(portExpensesCurrency: v)),
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
          ),

          const Divider(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l.totalQuoteValue}:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
                if (item.totalQuotationAmount != null)
                  Text(
                    '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? "—"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cobalt),
                  )
                else
                  Builder(
                    builder: (context) {
                      final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(
                        item: item,
                        currencies: currenciesList,
                      ).missingCurrencies;
                      final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.wcagOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.wcagOrange, width: 0.8),
                            ),
                            child: Text(
                              l.rateMissingWarning(missingStr),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '—',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.wcagOrange),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
