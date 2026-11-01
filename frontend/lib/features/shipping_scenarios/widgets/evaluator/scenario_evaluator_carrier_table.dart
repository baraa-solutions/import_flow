import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../currencies/models/currency_model.dart';
import '../../../external_service_providers/models/partner_model.dart';
import '../../models/shipping_scenario_model.dart';
import '../carrier_option_evaluation_tile.dart';

/// Carrier options section, evaluation cards, and the side-by-side comparison enterprise data table.
class ScenarioEvaluatorCarrierTable extends StatelessWidget {
  final List<ShippingScenarioItemModel> items;
  final List<Map<String, dynamic>> calculatedScenarios;
  final Map<int, bool> expandedQuotes;
  final int? editingSessionId;
  final int editFormVersion;
  final VoidCallback onAddCarrierOption;
  final ValueChanged<int> onToggleExpanded;
  final void Function(int index, ShippingScenarioItemModel updated) onUpdateItem;
  final ValueChanged<int> onCloneOption;
  final ValueChanged<int> onDeleteOption;
  final List<PartnerModel> partnersList;
  final List<dynamic> portsList;
  final List<CurrencyModel> currenciesList;
  final VoidCallback? onRefreshData;

  const ScenarioEvaluatorCarrierTable({
    super.key,
    required this.items,
    required this.calculatedScenarios,
    required this.expandedQuotes,
    required this.editingSessionId,
    required this.editFormVersion,
    required this.onAddCarrierOption,
    required this.onToggleExpanded,
    required this.onUpdateItem,
    required this.onCloneOption,
    required this.onDeleteOption,
    required this.partnersList,
    required this.portsList,
    required this.currenciesList,
    this.onRefreshData,
  });

  /// Factory helper to create a default blank shipping carrier option.
  static ShippingScenarioItemModel createBlankOption(
    DateTime cargoReadyDate, {
    bool isRecommended = false,
  }) {
    return ShippingScenarioItemModel(
      providerName: '',
      vesselName: '',
      voyageNumber: '',
      sailingDate: cargoReadyDate.add(const Duration(days: 2)).toString().substring(0, 10),
      estimatedArrivalDate: cargoReadyDate.add(const Duration(days: 22)).toString().substring(0, 10),
      expectedLineDelayDays: 2,
      quotationCurrency: 'USD',
      freeTimeDays: 21,
      container40ftApplicable: true,
      container40ftPrice: 0.0,
      container40ftQty: 1,
      container40ftCurrency: 'USD',
      container20ftApplicable: false,
      container20ftPrice: 0.0,
      container20ftQty: 0,
      container20ftCurrency: 'USD',
      bookingCancellationApplicable: false,
      bookingCancellationPrice: 0.0,
      bookingCancellationCurrency: 'USD',
      isRecommended: isRecommended,
      riskLevel: 'Low',
      notes: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

    final freightForwarders = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('freight forwarder') || t.contains('forwarder') || t.contains('شحن') || t.contains('لوجستي');
    }).toList();

    final shippingLines = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('shipping line') ||
          t.contains('carrier') ||
          t.contains('liner') ||
          t.contains('ملاحي') ||
          t.contains('خط شحن') ||
          t.contains('خطوط ملاحية');
    }).toList();

    final customsBrokers = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('customs broker') || t.contains('broker') || t.contains('تخليص') || t.contains('مخلص');
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carrier Options Section Header
        LayoutBuilder(
          builder: (context, headerConstraints) {
            final isNarrowHeader = headerConstraints.maxWidth < 650;
            final titleWidget = Text(
              l.shippingCarrierOptions,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            );
            final addBtn = AppButton(
              label: l.addNewShippingOption,
              icon: Icons.add,
              variant: AppButtonVariant.primary,
              onPressed: onAddCarrierOption,
            );
            if (isNarrowHeader) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleWidget,
                  const SizedBox(height: 8),
                  addBtn,
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleWidget),
                const SizedBox(width: 8),
                addBtn,
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        // Empty state banner
        if (items.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_boat_outlined,
                  size: 40,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  isArabic
                      ? 'لا توجد خيارات أو عروض شحن مضافة حتى الآن'
                      : 'No shipping carrier options added yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isArabic
                      ? 'اضغط "+ إضافة خيار شحن جديد" لإضافة خيار شحن فارغ، أو استخرج العروض تلقائياً من المستندات أعلاه'
                      : 'Click "+ Add New Shipping Option" to add a blank carrier option, or extract quotes above',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: l.addNewShippingOption,
                  icon: Icons.add,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: onAddCarrierOption,
                ),
              ],
            ),
          ),

        // Carrier Option Cards List
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final calc = calculatedScenarios.firstWhere((c) => c['index'] == idx, orElse: () => {});

          return CarrierOptionEvaluationTile(
            key: ValueKey('carrier_tile_${editingSessionId ?? "new"}_${idx}_$editFormVersion'),
            index: idx,
            item: item,
            calculation: calc,
            isExpanded: expandedQuotes[idx] ?? false,
            onToggleExpanded: () => onToggleExpanded(idx),
            onUpdateItem: (updated) => onUpdateItem(idx, updated),
            onClone: () => onCloneOption(idx),
            onDelete: () => onDeleteOption(idx),
            freightForwarders: freightForwarders,
            shippingLines: shippingLines,
            customsBrokers: customsBrokers,
            portsList: portsList,
            currenciesList: currenciesList,
            editingSessionId: editingSessionId,
            editFormVersion: editFormVersion,
            onRefreshData: onRefreshData,
          );
        }),

        const SizedBox(height: 20),

        // Comparison Summary Enterprise Table
        SizedBox(
          height: 380,
          child: EnterpriseDataTable<Map<String, dynamic>>(
            data: calculatedScenarios,
            title: l.sideBySideComparison,
            storageKey: 'shipping_scenarios_comparison_table',
            enableExport: true,
            exportFileName: 'Shipping_Scenarios_Comparison',
            columns: [
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'index',
                title: '#',
                width: 50,
                cellBuilder: (ctx, c, i) => Text('${(c['index'] as int) + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                searchValue: (c) => '${(c['index'] as int) + 1}',
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'provider_name',
                title: l.shippingLineCol,
                width: 140,
                cellBuilder: (ctx, c, i) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  return Text(item.providerName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt));
                },
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).providerName,
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'total_quote',
                title: l.totalQuoteValue,
                width: 130,
                isNumeric: true,
                cellBuilder: (ctx, c, i) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  final totalStr = item.totalQuotationAmount != null
                      ? '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? ""}'
                      : '—';
                  return item.totalQuotationAmount != null
                      ? Text(totalStr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson))
                      : Tooltip(
                          message: l.rateMissingWarning(item.quotationCurrency ?? '—'),
                          child: const Text('—', style: TextStyle(color: AppTheme.wcagOrange, fontWeight: FontWeight.bold)),
                        );
                },
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).totalQuotationAmount?.toString() ?? '',
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'expected_wh_date',
                title: l.whDateCol,
                width: 110,
                cellBuilder: (ctx, c, i) => Text('${c["expectedWhDate"]}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                searchValue: (c) => '${c["expectedWhDate"]}',
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'total_days',
                title: l.avgTransitMetric,
                width: 90,
                isNumeric: true,
                cellBuilder: (ctx, c, i) => Text('${c["totalDays"]} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                searchValue: (c) => '${c["totalDays"]}',
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'customs_broker',
                title: l.customsBrokerLabel,
                width: 140,
                cellBuilder: (ctx, c, i) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  return Text(item.customsBrokerName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600));
                },
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).customsBrokerName ?? '',
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'route',
                title: '${l.portOfLoadingCol} / ${l.portOfDischargeCol}',
                width: 150,
                cellBuilder: (ctx, c, i) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  return Text('${item.polName ?? "-"} ➔ ${item.podName ?? "-"}', style: const TextStyle(fontSize: 11));
                },
                searchValue: (c) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  return '${item.polName} ${item.podName}';
                },
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'vessel',
                title: l.vesselNameCol,
                width: 130,
                cellBuilder: (ctx, c, i) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  return Text('${item.vesselName} (${item.voyageNumber ?? "-"})');
                },
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).vesselName,
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'sailing_date',
                title: l.sailingDateCol,
                width: 105,
                cellBuilder: (ctx, c, i) => Text((c['item'] as ShippingScenarioItemModel).sailingDate),
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).sailingDate,
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'eta_date',
                title: l.estimatedArrivalDateCol,
                width: 105,
                cellBuilder: (ctx, c, i) => Text((c['item'] as ShippingScenarioItemModel).estimatedArrivalDate),
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).estimatedArrivalDate,
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'free_time',
                title: l.freeTimeDaysCol,
                width: 90,
                isNumeric: true,
                cellBuilder: (ctx, c, i) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  return Text('${item.freeTimeDays} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt));
                },
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).freeTimeDays.toString(),
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'risk_level',
                title: l.riskLevelCol,
                width: 100,
                cellBuilder: (ctx, c, i) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  return AppStatusBadge(
                    label: item.riskLevel,
                    severity: item.riskLevel == 'High'
                        ? AppSeverity.danger
                        : item.riskLevel == 'Medium'
                            ? AppSeverity.warning
                            : AppSeverity.success,
                  );
                },
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).riskLevel,
              ),
              EnterpriseColumn<Map<String, dynamic>>(
                id: 'status',
                title: l.statusCol,
                width: 120,
                cellBuilder: (ctx, c, i) {
                  final item = c['item'] as ShippingScenarioItemModel;
                  return Text(
                    item.isExcludedFromAverage ? l.excludedFromAvg : l.includedInAvg,
                    style: TextStyle(
                      color: item.isExcludedFromAverage ? AppTheme.crimson : AppTheme.cobalt,
                      fontSize: 11,
                    ),
                  );
                },
                searchValue: (c) => (c['item'] as ShippingScenarioItemModel).isExcludedFromAverage ? 'Excluded' : 'Included',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
