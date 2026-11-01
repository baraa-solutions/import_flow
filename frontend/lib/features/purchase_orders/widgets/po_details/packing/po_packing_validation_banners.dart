import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/purchase_order_model.dart';
import '../po_resolved_metrics.dart';

class PoPackingValidationBanners extends StatelessWidget {
  final PurchaseOrderModel po;
  final POResolvedMetrics metrics;
  final VoidCallback? onOpen3dPlanner;

  const PoPackingValidationBanners({
    super.key,
    required this.po,
    required this.metrics,
    this.onOpen3dPlanner,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (po.packingListItems.isNotEmpty) ...[
          if (metrics.reconciliation.hasDiscrepancy)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.orangeLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        l.poInvoicePackingReconciliationDiscrepanciesFound,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...(isArabic
                          ? metrics.reconciliation.discrepancySummaryList
                          : (metrics.reconciliation.discrepancySummaryListEn.isNotEmpty
                              ? metrics.reconciliation.discrepancySummaryListEn
                              : metrics.reconciliation.discrepancySummaryList))
                      .map(
                    (d) => Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2, start: 24),
                      child: Text(
                        '• $d',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.orangeLight : AppTheme.wcagOrange,
                        ),
                      ),
                    ),
                  ),
                  if (po.notes != null && po.notes!.contains('[مبررات اختلاف الفاتورة والباكينج]')) ...[
                    const Divider(height: 14),
                    Text(
                      '${l.poApprovedJustification} ${po.notes!.split('[مبررات اختلاف الفاتورة والباكينج]:').last.trim()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.emeraldLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppTheme.wcagEmerald : AppTheme.emeraldBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: AppTheme.emerald, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.poPerfectMatchAllProformaInvoiceLine,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (metrics.validationErrors.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.crimsonLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppTheme.crimson : AppTheme.crimsonBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.crimson, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      l.poPackingListValidationErrors,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.redAccent : AppTheme.crimson,
                      ),
                    ),
                  ],
                ),
                ...metrics.validationErrors.map(
                  (e) => Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4, start: 24),
                    child: Text(
                      '• $e',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.crimsonBorder : AppTheme.crimson,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.emeraldLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppTheme.wcagEmerald : AppTheme.emeraldBorder,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 18),
                const SizedBox(width: 6),
                Text(
                  l.poPackingListValidationPassedAllWeights,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald,
                  ),
                ),
              ],
            ),
          ),
        if (metrics.validationWarnings.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.orangeLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppTheme.wcagOrange : AppTheme.orange,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: metrics.validationWarnings
                  .map(
                    (w) => Text(
                      '⚠️ $w',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (po.packingListItems.isNotEmpty && po.palletPlanItems.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.view_in_ar_rounded, color: AppTheme.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.po3DContainerLoadSimulationAvailableFor(
                      po.packingListItems.length,
                      po.packingListItems.fold<int>(
                        0,
                        (s, p) => s + (p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1),
                      ),
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                ),
                AppButton(
                  label: l.containerLoadPlan3dTitle,
                  icon: Icons.view_in_ar_rounded,
                  variant: AppButtonVariant.warning,
                  size: AppButtonSize.small,
                  onPressed: () => onOpen3dPlanner?.call(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
