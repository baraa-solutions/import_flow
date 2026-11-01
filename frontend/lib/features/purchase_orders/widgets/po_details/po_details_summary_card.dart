import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/purchase_order_model.dart';
import '../../utils/po_packing_matcher.dart';
import '../po_fulfillment_progress_widget.dart';
import 'po_resolved_metrics.dart';

/// Clean, responsive summary card for Purchase Order Details.
///
/// Displays:
/// - Order reference & status badge
/// - Supplier, importing company, project & incoterms
/// - Currencies, exchange rate, and total FOB amounts
/// - Weights (gross / net), CBM volume, and packaging counts
/// - Audit metadata (creator / updater)
/// - PO fulfillment progress bar
class PoDetailsSummaryCard extends StatelessWidget {
  final PurchaseOrderModel po;
  final POResolvedMetrics metrics;
  final VoidCallback? onAllocatePressed;

  const PoDetailsSummaryCard({
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: PO Reference & Status Badge
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    po.displayName != po.poNumber
                        ? '${po.displayName} (${po.poNumber})'
                        : po.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppStatusBadge.fromStatus(
                  status: po.status,
                  label: po.statusLabel(l),
                ),
              ],
            ),

            // Audit Row (Created By / Updated By)
            if (po.createdBy != null || po.updatedBy != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (po.createdBy != null) ...[
                    Text(
                      '${l.poAuditCreatedBy}: ',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    LtrText(
                      po.createdBy!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (po.updatedBy != null) ...[
                    Text(
                      '${l.poAuditUpdatedBy}: ',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    LtrText(
                      po.updatedBy!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ],

            const Divider(height: 18),

            // Fulfillment Progress Widget
            POFulfillmentProgressWidget.fromPO(
              po: po,
              isCompact: true,
              onAllocatePressed: onAllocatePressed,
            ),

            const SizedBox(height: 14),

            // 14 Detail Items Grid / Wrap
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _buildDetailItem(l.projectsAndCostCenters, po.projectName ?? '-', isDark: isDark),
                _buildDetailItem(l.importingCompany, po.companyName ?? '-', isDark: isDark),
                _buildDetailItem(l.foreignSupplier, po.supplierName ?? '-', isDark: isDark),
                _buildDetailItem(l.countryOfOriginCol, po.countryOfOrigin ?? '-', isDark: isDark),
                _buildDetailItem(l.incotermsRules, po.incotermCode ?? '-', isDark: isDark),
                _buildDetailItem(
                  l.currency,
                  '${po.currencyCode ?? "USD"} (${l.exchangeRateLabel}: ${po.exchangeRate})',
                  isDark: isDark,
                ),
                _buildDetailItem(
                  l.poInvoiceDate,
                  po.orderDate != null
                      ? "${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}"
                      : '-',
                  isDark: isDark,
                ),
                _buildDetailItem(
                  l.poQtyUnit,
                  po.items.isNotEmpty ? po.items.first.unitOfMeasure : 'PCS',
                  isDark: isDark,
                ),
                _buildDetailItem(l.paymentTermsLabel, po.paymentTerms ?? '-', isDark: isDark),
                _buildDetailItem(
                  l.totalFobMetric,
                  '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
                  isDark: isDark,
                ),
                _buildDetailItem(
                  l.totalCargoCbmMetric,
                  '${metrics.effectivePackingListCbm.toStringAsFixed(3)} m³${metrics.totalPalletCount > 0 ? " (${metrics.totalPalletCount})" : ""}',
                  isDark: isDark,
                ),
                _buildDetailItem(
                  l.grossWeightMetric,
                  '${POResolvedMetrics.formatWeight(metrics.effectivePackingListGrossWeight)} kg',
                  isDark: isDark,
                ),
                _buildDetailItem(
                  l.netWeightMetric,
                  '${POResolvedMetrics.formatWeight(metrics.effectivePackingListNetWeight)} kg',
                  isDark: isDark,
                ),
                _buildDetailItem(
                  l.poTotalQtyPKG,
                  PoPackingMatcher.formatPackagingSummary(
                    packingListItems: po.packingListItems,
                    totalPalletCount: metrics.totalPalletCount,
                    isArabic: isArabic,
                  ),
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        CopyableText(
          value,
          showIcon: false,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}
