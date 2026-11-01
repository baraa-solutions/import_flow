import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customs_tariff/widgets/hs_code_compliance_insight_card.dart';
import '../../models/purchase_order_model.dart';
import 'items/po_hs_summary_table.dart';
import 'items/po_line_items_breakdown_table.dart';
import 'items/po_package_type_summary_table.dart';
import 'po_details_summary_card.dart';
import 'po_resolved_metrics.dart';

/// Commercial PO Line Items & Reconciliation Summary Tab.
///
/// Features:
/// - PO Details Summary Card (top)
/// - PO Line items breakdown table (prices, quantities, HS codes, weights, volume)
/// - PO Line items summary report grouped by HS code
/// - Regulatory compliance & trade agreement cards for involved HS codes
/// - Package type summary table (if applicable)
class PoDetailsItemsTab extends StatelessWidget {
  final PurchaseOrderModel po;
  final POResolvedMetrics metrics;
  final VoidCallback? onAllocatePressed;

  const PoDetailsItemsTab({
    super.key,
    required this.po,
    required this.metrics,
    this.onAllocatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PoDetailsSummaryCard(
              po: po,
              metrics: metrics,
              onAllocatePressed: onAllocatePressed,
            ),
            const SizedBox(height: 16),
            PoLineItemsBreakdownTable(
              po: po,
              metrics: metrics,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            PoHsSummaryTable(
              po: po,
              metrics: metrics,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            Text(
              l.poRegulatoryConditionsTradeAgreementsByHS,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            ...metrics.poHsSummaryMap.values.map((summary) {
              final summaryHs = '${summary['hs_code']}';
              final tariff = metrics.tariffs.where((t) =>
                  t.hsCode == summaryHs ||
                  t.hsCode.replaceAll('.', '') == summaryHs.replaceAll('.', '')).firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: HsCodeComplianceInsightCard(
                  hsCode: summaryHs,
                  tariff: tariff,
                  countryOfOrigin: po.countryOfOrigin,
                  isDark: isDark,
                  isArabic: isArabic,
                ),
              );
            }),
            if (metrics.packageTypeSummaryMap.isNotEmpty) ...[
              const SizedBox(height: 20),
              PoPackageTypeSummaryTable(
                packageTypeSummaryMap: metrics.packageTypeSummaryMap,
                isDark: isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
