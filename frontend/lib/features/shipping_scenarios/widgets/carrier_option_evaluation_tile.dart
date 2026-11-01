import 'package:flutter/material.dart';

import 'package:frontend/core/theme/app_theme.dart';

import '../../currencies/models/currency_model.dart';
import '../../external_service_providers/models/partner_model.dart';
import '../models/shipping_scenario_model.dart';
import '../utils/shipping_scenario_calculator.dart';
import 'carrier_option/carrier_lead_time_strip.dart';
import 'carrier_option/carrier_quotation_breakdown_card.dart';
import 'carrier_option/carrier_tile_header_fields.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Card(
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

              return Column(
                children: [
                  CarrierTileHeaderFields(
                    index: index,
                    item: item,
                    onUpdateItem: _handleUpdateItem,
                    onClone: onClone,
                    onDelete: onDelete,
                    freightForwarders: freightForwarders,
                    shippingLines: shippingLines,
                    customsBrokers: customsBrokers,
                    portsList: portsList,
                    editingSessionId: editingSessionId,
                    editFormVersion: editFormVersion,
                    isNarrowCard: isNarrowCard,
                    onRefreshData: onRefreshData,
                  ),
                  if (calculation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    CarrierLeadTimeStrip(
                      item: item,
                      calculation: calculation,
                      currenciesList: currenciesList,
                      isExpanded: isExpanded,
                      onToggleExpanded: onToggleExpanded,
                    ),
                  ],
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    CarrierQuotationBreakdownCard(
                      index: index,
                      item: item,
                      currenciesList: currenciesList,
                      editingSessionId: editingSessionId,
                      editFormVersion: editFormVersion,
                      onUpdateItem: _handleUpdateItem,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
