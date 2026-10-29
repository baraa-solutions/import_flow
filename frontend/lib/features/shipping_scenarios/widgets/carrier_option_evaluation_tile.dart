import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../currencies/models/currency_model.dart';
import '../../external_service_providers/models/partner_model.dart';
import '../models/shipping_scenario_model.dart';
import '../utils/shipping_scenario_calculator.dart';

/// كرت مقارنة وتقييم خط الشحن والناقل
class CarrierOptionEvaluationTile extends StatelessWidget {
  final int index;
  final ShippingScenarioItemModel item;
  final Map<String, dynamic> calculation;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<ShippingScenarioItemModel> onUpdateItem;
  final VoidCallback onClone;
  final VoidCallback onDelete;
  final List<PartnerModel> freightForwarders;
  final List<PartnerModel> shippingLines;
  final List<PartnerModel> customsBrokers;
  final List<dynamic> portsList;
  final List<CurrencyModel> currenciesList;
  final int? editingSessionId;
  final int editFormVersion;
  final VoidCallback? onRefreshData;

  const CarrierOptionEvaluationTile({
    super.key,
    required this.index,
    required this.item,
    required this.calculation,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onUpdateItem,
    required this.onClone,
    required this.onDelete,
    required this.freightForwarders,
    required this.shippingLines,
    required this.customsBrokers,
    required this.portsList,
    required this.currenciesList,
    required this.editingSessionId,
    required this.editFormVersion,
    this.onRefreshData,
  });

  void _handleUpdateItem(ShippingScenarioItemModel updated) {
    final rawTotal = ShippingScenarioCalculator.calculateTotalQuoteValue(
      item: updated,
      currencies: currenciesList,
    ).total;
    final totalAmount = rawTotal?.roundToDouble();
    final finalItem = updated.copyWith(
      totalQuotationAmount: totalAmount,
      clearTotalQuotationAmount: totalAmount == null,
    );
    onUpdateItem(finalItem);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

    // Automatically compute containers total count for displays
    final currentContainersCount = (item.container40ftApplicable ? item.container40ftQty : 0) +
        (item.container20ftApplicable ? item.container20ftQty : 0);

    return Card(
      elevation: 1.5,
      color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: item.isRecommended
              ? AppTheme.emerald
              : (item.isExcludedFromAverage
                  ? (isDark ? AppTheme.textStrong : AppTheme.textMuted)
                  : (isDark ? AppTheme.darkBorder : AppTheme.cobaltBorder)),
          width: item.isRecommended ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, cardConstraints) {
            final isNarrowCard = cardConstraints.maxWidth < 800;

            final avatarWidget = CircleAvatar(
              radius: 14,
              backgroundColor: item.isRecommended ? AppTheme.emerald : AppTheme.cobalt,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            );

            final forwarderDropdown = SearchableDropdownField<int?>(
              value: item.providerId,
              labelText: l.freightForwarderCol,
              searchHintText: l.forwarderSearchHint,
              items: [
                SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                ...freightForwarders.map((p) => SearchableDropdownItem<int?>(
                      value: p.providerId,
                      label: '${p.partnerName}${p.partnerCode.isNotEmpty ? " (${p.partnerCode})" : ""}',
                      searchValue: '${p.partnerName} ${p.partnerCode} ${p.partnerType}',
                    )),
              ],
              onChanged: (val) {
                final partner = freightForwarders.where((p) => p.providerId == val).firstOrNull;
                _handleUpdateItem(item.copyWith(
                  providerId: val,
                  providerName: partner != null ? partner.partnerName : item.providerName,
                ));
              },
            );

            final shippingLineDropdown = SearchableDropdownField<String>(
              value: shippingLines.any((p) => p.partnerName == item.providerName)
                  ? item.providerName
                  : (item.providerName.isNotEmpty ? item.providerName : ''),
              labelText: '${l.shippingLineCol} *',
              searchHintText: l.shippingLineSearchHint,
              items: [
                SearchableDropdownItem<String>(value: '', label: l.unassigned),
                if (item.providerName.isNotEmpty && !shippingLines.any((p) => p.partnerName == item.providerName))
                  SearchableDropdownItem<String>(
                    value: item.providerName,
                    label: '★ ${item.providerName} (${l.suggestedSuffix})',
                    searchValue: item.providerName,
                  ),
                ...shippingLines.map((p) => SearchableDropdownItem<String>(
                      value: p.partnerName,
                      label: '${p.partnerName}${p.scacCode != null && p.scacCode!.isNotEmpty ? " (${p.scacCode})" : ""}',
                      searchValue: '${p.partnerName} ${p.partnerCode} ${p.scacCode ?? ""} ${p.partnerType}',
                      subtitle: p.scacCode != null && p.scacCode!.isNotEmpty ? 'SCAC: ${p.scacCode}' : p.partnerCode,
                    )),
              ],
              onChanged: (val) {
                if (val != null && val.isNotEmpty) {
                  _handleUpdateItem(item.copyWith(providerName: val));
                }
              },
            );

            final addShippingLineBtn = IconButton(
              icon: const Icon(Icons.add_business_outlined, color: AppTheme.emerald, size: 20),
              tooltip: l.addNewLineTooltip,
              onPressed: () => UniversalEntityExtractorDialog.showShippingLineExtractor(
                context,
                onSaved: () => onRefreshData?.call(),
              ),
            );

            final vesselField = TextFormField(
              key: ValueKey('vessel_${editingSessionId ?? "new"}_${index}_$editFormVersion'),
              initialValue: item.vesselName,
              decoration: InputDecoration(labelText: '${l.vesselNameCol} *', isDense: true),
              validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
              onChanged: (v) => _handleUpdateItem(item.copyWith(vesselName: v.trim())),
            );

            final voyageField = TextFormField(
              key: ValueKey('voyage_${editingSessionId ?? "new"}_${index}_$editFormVersion'),
              initialValue: item.voyageNumber ?? '',
              decoration: InputDecoration(labelText: l.voyageCol, isDense: true),
              onChanged: (v) => _handleUpdateItem(item.copyWith(voyageNumber: v.trim())),
            );

            final cloneCarrierBtn = IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
              tooltip: l.cloneCarrierOptionTooltip,
              onPressed: onClone,
            );

            final deleteCarrierBtn = IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
              onPressed: onDelete,
            );

            final polDropdown = SearchableDropdownField<int?>(
              value: item.portOfLoadingId,
              labelText: l.portOfLoadingCol,
              items: [
                SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                ...portsList.map((p) => SearchableDropdownItem<int?>(
                      value: p.locationId,
                      label: '${p.unLocode} - ${p.locationName} (${p.country})',
                    )),
              ],
              onChanged: (val) {
                final selectedPort = portsList.where((p) => p.locationId == val).firstOrNull;
                _handleUpdateItem(item.copyWith(
                  portOfLoadingId: val,
                  polName: selectedPort != null ? selectedPort.locationName : item.polName,
                ));
              },
            );

            final podDropdown = SearchableDropdownField<int?>(
              value: item.portOfDischargeId,
              labelText: l.portOfDischargeCol,
              items: [
                SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                ...portsList.map((p) => SearchableDropdownItem<int?>(
                      value: p.locationId,
                      label: '${p.unLocode} - ${p.locationName} (${p.country})',
                    )),
              ],
              onChanged: (val) {
                final selectedPort = portsList.where((p) => p.locationId == val).firstOrNull;
                _handleUpdateItem(item.copyWith(
                  portOfDischargeId: val,
                  podName: selectedPort != null ? selectedPort.locationName : item.podName,
                ));
              },
            );

            final brokerDropdown = SearchableDropdownField<int?>(
              value: item.customsBrokerId,
              labelText: l.customsBrokerLabel,
              items: [
                SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                ...customsBrokers.map((p) => SearchableDropdownItem<int?>(
                      value: p.providerId,
                      label: p.partnerName,
                    )),
              ],
              onChanged: (val) {
                final partner = customsBrokers.where((p) => p.providerId == val).firstOrNull;
                final hasClearance = item.clearanceFeePrice > 0;
                _handleUpdateItem(item.copyWith(
                  customsBrokerId: val,
                  customsBrokerName: partner?.partnerName,
                  clearanceFeeApplicable: val != null ? true : item.clearanceFeeApplicable,
                  clearanceFeePrice: (!hasClearance && val != null) ? 2500.0 : item.clearanceFeePrice,
                  clearanceFeeCurrency: "EGP",
                  inspectionFeeApplicable: val != null ? true : item.inspectionFeeApplicable,
                  inspectionFeePrice: (!hasClearance && val != null) ? 3500.0 : item.inspectionFeePrice,
                  inspectionFeeCurrency: "EGP",
                  inlandTransportFeeApplicable: val != null ? true : item.inlandTransportFeeApplicable,
                  inlandTransportFeePrice: (!hasClearance && val != null) ? 14800.0 : item.inlandTransportFeePrice,
                  inlandTransportFeeCurrency: "EGP",
                  portExpensesApplicable: val != null ? true : item.portExpensesApplicable,
                  portExpensesPrice: (!hasClearance && val != null) ? 4750.0 : item.portExpensesPrice,
                  portExpensesCurrency: "EGP",
                ));
              },
            );

            final sailingDatePicker = InkWell(
              onTap: () async {
                final sDate = DateTime.tryParse(item.sailingDate) ?? DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: sDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  _handleUpdateItem(item.copyWith(sailingDate: picked.toString().substring(0, 10)));
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: '${l.sailingDateCol} *', isDense: true),
                child: Text(
                  item.sailingDate.isNotEmpty ? item.sailingDate : l.unassigned,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: item.sailingDate.isNotEmpty
                        ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)
                        : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
                  ),
                ),
              ),
            );

            final etaDatePicker = InkWell(
              onTap: () async {
                final etaDate = DateTime.tryParse(item.estimatedArrivalDate) ?? DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: etaDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  _handleUpdateItem(item.copyWith(estimatedArrivalDate: picked.toString().substring(0, 10)));
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: '${l.estimatedArrivalDateCol} *', isDense: true),
                child: Text(
                  item.estimatedArrivalDate.isNotEmpty ? item.estimatedArrivalDate : l.unassigned,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: item.estimatedArrivalDate.isNotEmpty
                        ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)
                        : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
                  ),
                ),
              ),
            );

            final delayField = TextFormField(
              key: ValueKey('delay_${editingSessionId ?? "new"}_${index}_$editFormVersion'),
              initialValue: item.expectedLineDelayDays.toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.expectedDelayCol, isDense: true),
              onChanged: (v) {
                final delay = int.tryParse(v) ?? 0;
                _handleUpdateItem(item.copyWith(expectedLineDelayDays: delay));
              },
            );

            final riskDropdown = SearchableDropdownField<String>(
              value: item.riskLevel,
              labelText: l.riskLevelCol,
              items: const [
                SearchableDropdownItem(value: 'Low', label: 'Low Risk 🟢'),
                SearchableDropdownItem(value: 'Medium', label: 'Medium Risk 🟠'),
                SearchableDropdownItem(value: 'High', label: 'High Risk 🔴'),
              ],
              onChanged: (v) {
                if (v != null) {
                  _handleUpdateItem(item.copyWith(riskLevel: v));
                }
              },
            );

            final excludedChip = FilterChip(
              label: Text(
                item.isExcludedFromAverage ? l.excludedFromAvg : l.includedInAvg,
                style: TextStyle(
                  fontSize: 11,
                  color: item.isExcludedFromAverage ? AppTheme.crimson : AppTheme.cobalt,
                ),
              ),
              selected: item.isExcludedFromAverage,
              onSelected: (val) {
                _handleUpdateItem(item.copyWith(isExcludedFromAverage: val));
              },
            );

            return Column(
              children: [
                if (isNarrowCard) ...[
                  // Header Row for Narrow Viewports
                  Row(
                    children: [
                      avatarWidget,
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.providerName.isNotEmpty ? item.providerName : '${l.carrierOptionHeader} #${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      cloneCarrierBtn,
                      deleteCarrierBtn,
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Forwarder & Shipping Line
                  Row(
                    children: [
                      Expanded(child: forwarderDropdown),
                      const SizedBox(width: 8),
                      Expanded(child: shippingLineDropdown),
                      addShippingLineBtn,
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Vessel & Voyage
                  Row(
                    children: [
                      Expanded(flex: 2, child: vesselField),
                      const SizedBox(width: 8),
                      Expanded(child: voyageField),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Ports & Broker
                  Row(
                    children: [
                      Expanded(child: polDropdown),
                      const SizedBox(width: 8),
                      Expanded(child: podDropdown),
                    ],
                  ),
                  const SizedBox(height: 10),
                  brokerDropdown,
                  const SizedBox(height: 10),

                  // Sailing Date & ETA
                  Row(
                    children: [
                      Expanded(child: sailingDatePicker),
                      const SizedBox(width: 8),
                      Expanded(child: etaDatePicker),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Delays, Risk & Average exclusion
                  Row(
                    children: [
                      Expanded(child: delayField),
                      const SizedBox(width: 8),
                      Expanded(child: riskDropdown),
                      const SizedBox(width: 8),
                      excludedChip,
                    ],
                  ),
                ] else ...[
                  // Full Desktop Layout
                  // Row 1: Freight Forwarder, Shipping Line, Vessel & Voyage
                  Row(
                    children: [
                      avatarWidget,
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: forwarderDropdown),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: shippingLineDropdown),
                      const SizedBox(width: 4),
                      addShippingLineBtn,
                      const SizedBox(width: 6),
                      Expanded(flex: 2, child: vesselField),
                      const SizedBox(width: 10),
                      Expanded(child: voyageField),
                      const SizedBox(width: 4),
                      cloneCarrierBtn,
                      const SizedBox(width: 4),
                      deleteCarrierBtn,
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 2: POL, POD & Customs Broker Selector
                  Row(
                    children: [
                      Expanded(child: polDropdown),
                      const SizedBox(width: 12),
                      Expanded(child: podDropdown),
                      const SizedBox(width: 12),
                      Expanded(child: brokerDropdown),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 3: Sailing Date, ETA, Delays & Risk
                  Row(
                    children: [
                      Expanded(child: sailingDatePicker),
                      const SizedBox(width: 10),
                      Expanded(child: etaDatePicker),
                      const SizedBox(width: 10),
                      Expanded(child: delayField),
                      const SizedBox(width: 10),
                      Expanded(child: riskDropdown),
                      const SizedBox(width: 10),
                      excludedChip,
                    ],
                  ),
                ],

                // Live Calculation & Expand Quote buttons
                if (calculation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final hasRealDates = item.sailingDate.isNotEmpty && item.estimatedArrivalDate.isNotEmpty;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.cobaltMedium : AppTheme.cobaltLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                hasRealDates
                                    ? l.polToPodLeadTimeStrip(
                                        item.polName ?? '-',
                                        item.podName ?? '-',
                                        calculation["vesselLeadTime"] as int,
                                        calculation["totalDays"] as int,
                                      )
                                    : (isArabic
                                        ? 'يرجى تحديد تواريخ الإبحار والوصول لاحتساب مدد الشحن'
                                        : 'Select sailing & arrival dates to calculate transit lead times'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  AppButton(
                                    label: isExpanded
                                        ? l.hideQuote
                                        : (item.totalQuotationAmount != null
                                            ? '${l.quoteDetails} [${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? "—"}]'
                                            : '${l.quoteDetails} [—]'),
                                    icon: isExpanded ? Icons.expand_less : Icons.expand_more,
                                    variant: AppButtonVariant.secondary,
                                    size: AppButtonSize.small,
                                    onPressed: onToggleExpanded,
                                  ),
                                  if (item.totalQuotationAmount == null) ...[
                                    const SizedBox(width: 6),
                                    Builder(
                                      builder: (context) {
                                        final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(
                                          item: item,
                                          currencies: currenciesList,
                                        ).missingCurrencies;
                                        final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.wcagOrange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppTheme.wcagOrange, width: 0.8),
                                          ),
                                          child: Text(
                                            l.rateMissingWarning(missingStr),
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  if (hasRealDates) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      '${l.avgWarehouseArrivalMetric}: ${calculation["expectedWhDate"]}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // Expandable Quotation Cost Form Section (BP-008 Integration)
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
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
                                  _handleUpdateItem(item.copyWith(freeTimeDays: ft));
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
                                    _handleUpdateItem(item.copyWith(quotationCurrency: v));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Table/Grid of Cost Items
                        _CarrierCostBreakdownRow(
                          rowKey: 'container40ft_$index',
                          title: '1. ${l.container40ftItem}',
                          applicable: item.container40ftApplicable,
                          price: item.container40ftPrice,
                          currency: item.container40ftCurrency,
                          qty: item.container40ftQty.toDouble(),
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(container40ftApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(container40ftPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(container40ftCurrency: v)),
                          onQtyChanged: (v) => _handleUpdateItem(item.copyWith(container40ftQty: v.toInt())),
                          showQty: true,
                          isIntegerQty: true,
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'container20ft_$index',
                          title: '2. ${l.container20ftItem}',
                          applicable: item.container20ftApplicable,
                          price: item.container20ftPrice,
                          currency: item.container20ftCurrency,
                          qty: item.container20ftQty.toDouble(),
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(container20ftApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(container20ftPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(container20ftCurrency: v)),
                          onQtyChanged: (v) => _handleUpdateItem(item.copyWith(container20ftQty: v.toInt())),
                          showQty: true,
                          isIntegerQty: true,
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'lclCbm_$index',
                          title: '3. ${l.lclCbmItem}',
                          applicable: item.lclCbmApplicable,
                          price: item.lclCbmPrice,
                          currency: item.lclCbmCurrency,
                          qty: item.lclCbmQty,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(lclCbmApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(lclCbmPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(lclCbmCurrency: v)),
                          onQtyChanged: (v) => _handleUpdateItem(item.copyWith(lclCbmQty: v)),
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

                        _CarrierCostBreakdownRow(
                          rowKey: 'expressCourier_$index',
                          title: '4. ${l.expressCourierItem}',
                          applicable: item.expressCourierApplicable,
                          price: item.expressCourierPrice,
                          currency: item.expressCourierCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(expressCourierApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(expressCourierPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(expressCourierCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'eurAtr_$index',
                          title: '5. ${l.eurAtrItem}',
                          applicable: item.eurAtrApplicable,
                          price: item.eurAtrPrice,
                          currency: item.eurAtrCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(eurAtrApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(eurAtrPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(eurAtrCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'solasVgm_$index',
                          title: '6. ${l.solasVgmItem}',
                          applicable: item.solasVgmApplicable,
                          price: item.solasVgmPrice,
                          currency: item.solasVgmCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(solasVgmApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(solasVgmPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(solasVgmCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'vgmNotification_$index',
                          title: '7. ${l.vgmNotificationItem}',
                          applicable: item.vgmNotificationApplicable,
                          price: item.vgmNotificationPrice,
                          currency: item.vgmNotificationCurrency,
                          qty: currentContainersCount.toDouble(),
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(vgmNotificationApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(vgmNotificationPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(vgmNotificationCurrency: v)),
                          showQty: true,
                          qtyReadOnly: true,
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'telexRelease_$index',
                          title: '8. ${l.telexReleaseItem}',
                          applicable: item.telexReleaseApplicable,
                          price: item.telexReleasePrice,
                          currency: item.telexReleaseCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(telexReleaseApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(telexReleasePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(telexReleaseCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'insurance_$index',
                          title: '9. ${l.insuranceItem}',
                          applicable: item.insuranceApplicable,
                          price: item.insurancePrice,
                          currency: item.insuranceCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(insuranceApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(insurancePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(insuranceCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'bookingCancellation_$index',
                          title: '10. ${l.bookingCancellationItem}',
                          applicable: item.bookingCancellationApplicable,
                          price: item.bookingCancellationPrice,
                          currency: item.bookingCancellationCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(bookingCancellationApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(bookingCancellationPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(bookingCancellationCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'ics2FilingFee_$index',
                          title: '11. ${l.ics2FilingFeeItem}',
                          applicable: item.ics2FilingFeeApplicable,
                          price: item.ics2FilingFeePrice,
                          currency: item.ics2FilingFeeCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(ics2FilingFeeApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(ics2FilingFeePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(ics2FilingFeeCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'documentFees_$index',
                          title: '12. ${l.documentFeesItem}',
                          applicable: item.documentFeesApplicable,
                          price: item.documentFeesPrice,
                          currency: item.documentFeesCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(documentFeesApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(documentFeesPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(documentFeesCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'waiverLetterFee_$index',
                          title: '13. ${l.waiverLetterFeeItem}',
                          applicable: item.waiverLetterFeeApplicable,
                          price: item.waiverLetterFeePrice,
                          currency: item.waiverLetterFeeCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(waiverLetterFeeApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(waiverLetterFeePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(waiverLetterFeeCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'othersFee_$index',
                          title: '14. ${l.othersFeeItem}',
                          applicable: item.othersFeeApplicable,
                          price: item.othersFeePrice,
                          currency: item.othersFeeCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(othersFeeApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(othersFeePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(othersFeeCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'dthc_$index',
                          title: '15. ${l.dthcItem}',
                          applicable: item.dthcApplicable,
                          price: item.dthcPrice,
                          currency: item.dthcCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(dthcApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(dthcPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(dthcCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'storagePerWeek_$index',
                          title: '16. ${l.storagePerWeekItem}',
                          applicable: item.storagePerWeekApplicable,
                          price: item.storagePerWeekPrice,
                          currency: item.storagePerWeekCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(storagePerWeekApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(storagePerWeekPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(storagePerWeekCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'extraDayStorage_$index',
                          title: '17. ${l.extraDayStorageItem}',
                          applicable: item.extraDayStorageApplicable,
                          price: item.extraDayStoragePrice,
                          currency: item.extraDayStorageCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(extraDayStorageApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(extraDayStoragePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(extraDayStorageCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'clearanceFee_$index',
                          title: '18. ${l.clearanceBrokerFeeItem}',
                          applicable: item.clearanceFeeApplicable,
                          price: item.clearanceFeePrice,
                          currency: item.clearanceFeeCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(clearanceFeeApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(clearanceFeePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(clearanceFeeCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'inspectionFee_$index',
                          title: '19. ${l.inspectionFeeItem}',
                          applicable: item.inspectionFeeApplicable,
                          price: item.inspectionFeePrice,
                          currency: item.inspectionFeeCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(inspectionFeeApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(inspectionFeePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(inspectionFeeCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'inlandTransport_$index',
                          title: '20. ${l.inlandTransportFeeItem}',
                          applicable: item.inlandTransportFeeApplicable,
                          price: item.inlandTransportFeePrice,
                          currency: item.inlandTransportFeeCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(inlandTransportFeeApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(inlandTransportFeePrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(inlandTransportFeeCurrency: v)),
                          currenciesList: currenciesList,
                          editingSessionId: editingSessionId,
                          editFormVersion: editFormVersion,
                        ),
                        _CarrierCostBreakdownRow(
                          rowKey: 'portExpenses_$index',
                          title: '21. ${l.portClearanceExpensesItem}',
                          applicable: item.portExpensesApplicable,
                          price: item.portExpensesPrice,
                          currency: item.portExpensesCurrency,
                          onApplicableChanged: (v) => _handleUpdateItem(item.copyWith(portExpensesApplicable: v)),
                          onPriceChanged: (v) => _handleUpdateItem(item.copyWith(portExpensesPrice: v)),
                          onCurrencyChanged: (v) => _handleUpdateItem(item.copyWith(portExpensesCurrency: v)),
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
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CarrierCostBreakdownRow extends StatelessWidget {
  final String rowKey;
  final String title;
  final bool applicable;
  final double price;
  final String? currency;
  final double qty;
  final ValueChanged<bool> onApplicableChanged;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<double>? onQtyChanged;
  final bool showQty;
  final bool qtyReadOnly;
  final bool isIntegerQty;
  final List<CurrencyModel> currenciesList;
  final int? editingSessionId;
  final int editFormVersion;

  const _CarrierCostBreakdownRow({
    required this.rowKey,
    required this.title,
    required this.applicable,
    required this.price,
    required this.currency,
    this.qty = 1.0,
    required this.onApplicableChanged,
    required this.onPriceChanged,
    required this.onCurrencyChanged,
    this.onQtyChanged,
    this.showQty = false,
    this.qtyReadOnly = false,
    this.isIntegerQty = true,
    required this.currenciesList,
    required this.editingSessionId,
    required this.editFormVersion,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, costConstraints) {
        final isNarrow = costConstraints.maxWidth < 650;

        final priceField = TextFormField(
          key: ValueKey('price_${rowKey}_${editingSessionId ?? "new"}_$editFormVersion'),
          initialValue: price == 0.0 ? '' : price.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.itemPriceCol, isDense: true),
          onChanged: (v) {
            final p = double.tryParse(v) ?? 0.0;
            onPriceChanged(p);
          },
        );

        final currencyField = SearchableDropdownField<String>(
          value: currenciesList.any((c) => c.currencyCode == currency) ? currency : null,
          labelText: l.currency,
          items: currenciesList.map((c) => SearchableDropdownItem(
                value: c.currencyCode,
                label: '${c.currencyCode} (${c.currencySymbol})',
              )).toList(),
          onChanged: (v) {
            if (v != null) {
              onCurrencyChanged(v);
            }
          },
        );

        final qtyField = showQty
            ? TextFormField(
                key: qtyReadOnly
                    ? ValueKey('readonly_qty_${rowKey}_$qty')
                    : ValueKey('qty_${rowKey}_${editingSessionId ?? "new"}_$editFormVersion'),
                readOnly: qtyReadOnly,
                initialValue: qty == 0.0 ? '' : (isIntegerQty ? qty.toInt().toString() : qty.toString()),
                keyboardType: TextInputType.numberWithOptions(decimal: !isIntegerQty),
                decoration: InputDecoration(labelText: l.quantity, isDense: true),
                onChanged: qtyReadOnly
                    ? null
                    : (v) {
                        final q = double.tryParse(v) ?? 0.0;
                        if (onQtyChanged != null) {
                          onQtyChanged!(q);
                        }
                      },
              )
            : null;

        final switchWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: applicable,
              activeThumbColor: AppTheme.cobalt,
              onChanged: onApplicableChanged,
            ),
            Text(
              applicable ? l.applicable : l.notApplicable,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: applicable ? AppTheme.emerald : AppTheme.crimson,
              ),
            ),
          ],
        );

        final totalDisplay = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: applicable ? AppTheme.emeraldLight : AppTheme.crimsonLight,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: applicable
                  ? (isDark ? AppTheme.emerald : AppTheme.emeraldBorder)
                  : (isDark ? AppTheme.crimson : AppTheme.crimsonBorder),
            ),
          ),
          child: Text(
            applicable
                ? '${(price * qty).toStringAsFixed(0)} ${currency ?? ''}'.trim()
                : '0.0 ${currency ?? ''}'.trim(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: applicable ? AppTheme.emerald : AppTheme.crimson,
            ),
            textAlign: TextAlign.center,
          ),
        );

        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    switchWidget,
                    const SizedBox(width: 8),
                    totalDisplay,
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(flex: 2, child: priceField),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: currencyField),
                    if (showQty && qtyField != null) ...[
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: qtyField),
                    ],
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: priceField),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: currencyField),
              if (showQty && qtyField != null) ...[
                const SizedBox(width: 8),
                Expanded(flex: 2, child: qtyField),
              ],
              const SizedBox(width: 12),
              switchWidget,
              const SizedBox(width: 12),
              Expanded(flex: 2, child: totalDisplay),
            ],
          ),
        );
      },
    );
  }
}
