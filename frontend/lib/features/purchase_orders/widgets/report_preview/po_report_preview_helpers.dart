import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/utils/po_packing_matcher.dart';

/// Precomputed aggregate metrics for the Purchase Order preview report.
class POReportPreviewMetrics {
  final double totalAmount;
  final double totalGrossWeight;
  final double totalNetWeight;
  final double totalPackages;
  final double totalPcs;
  final double totalCbm;
  final int totalPallets;
  final double totalPalletCbm;
  final double totalPalletWeight;
  final bool hasActivePallets;
  final double effectiveCbm;
  final double effectiveGrossWeight;
  final String recommendedContainer;

  const POReportPreviewMetrics({
    required this.totalAmount,
    required this.totalGrossWeight,
    required this.totalNetWeight,
    required this.totalPackages,
    required this.totalPcs,
    required this.totalCbm,
    required this.totalPallets,
    required this.totalPalletCbm,
    required this.totalPalletWeight,
    required this.hasActivePallets,
    required this.effectiveCbm,
    required this.effectiveGrossWeight,
    required this.recommendedContainer,
  });

  /// Calculates all totals and recommended container from PO lines, packing items, and pallet items.
  factory POReportPreviewMetrics.calculate({
    required List<POLineItemModel> items,
    required List<PackingListItemModel> packingItems,
    required List<PalletPlanItemModel> palletItems,
  }) {
    final double totalAmount = items.fold(
      0.0,
      (sum, i) => sum + (i.totalPrice > 0 ? i.totalPrice : (i.quantity * i.unitPrice)),
    );

    // Recomputed from current rows (qty_pkg x unit weight); stored row totals might be stale.
    final double totalGrossWeight = packingItems.fold(0.0, (sum, p) => sum + p.computedTotalGrossWeightKg);
    final double totalNetWeight = packingItems.fold(0.0, (sum, p) => sum + p.computedTotalNetWeightKg);
    final double totalPackages = packingItems.fold(0.0, (sum, p) => sum + p.qtyPkg);
    final double totalPcs = packingItems.fold(0.0, (sum, p) => sum + p.qtyPcs);
    final double totalCbm = packingItems.fold(0.0, (sum, p) => sum + p.calculatedCbm);

    final int totalPallets = palletItems.fold(0, (sum, p) => sum + p.palletCount);
    final double totalPalletCbm = palletItems.fold(0.0, (sum, p) => sum + p.calculatedCbm);
    final double totalPalletWeight = palletItems.fold(0.0, (sum, p) => sum + p.totalWeightKg);

    final bool hasActivePallets = totalPallets > 0 && totalPalletCbm > 0;
    final double effectiveCbm = hasActivePallets ? totalPalletCbm : totalCbm;
    final double effectiveGrossWeight =
        (hasActivePallets && totalPalletWeight > 0) ? totalPalletWeight : totalGrossWeight;

    // Compute container recommendation
    String recommendedContainer = '20ft Standard (20GP)';
    if (totalPallets > 11 || effectiveCbm > 28.0 || effectiveGrossWeight > 21500) {
      recommendedContainer = '40ft High Cube (40HC)';
    }

    return POReportPreviewMetrics(
      totalAmount: totalAmount,
      totalGrossWeight: totalGrossWeight,
      totalNetWeight: totalNetWeight,
      totalPackages: totalPackages,
      totalPcs: totalPcs,
      totalCbm: totalCbm,
      totalPallets: totalPallets,
      totalPalletCbm: totalPalletCbm,
      totalPalletWeight: totalPalletWeight,
      hasActivePallets: hasActivePallets,
      effectiveCbm: effectiveCbm,
      effectiveGrossWeight: effectiveGrossWeight,
      recommendedContainer: recommendedContainer,
    );
  }
}

/// Helper for formatting weight numbers cleanly.
String formatPOWeight(double val) => PoPackingMatcher.formatWeight(val);

/// Reusable card container with border and horizontal scroll for preview tables.
class ReportTableCard extends StatelessWidget {
  final double minWidth;
  final Widget child;
  final bool isDark;

  const ReportTableCard({
    super.key,
    required this.minWidth,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Reusable section title with leading icon.
class ReportPreviewSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;

  const ReportPreviewSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.cobalt),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable metric badge used in report summaries.
class ReportPreviewMetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const ReportPreviewMetricBadge({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Header cell for report tables.
class ReportPreviewHeaderCell extends StatelessWidget {
  final String text;

  const ReportPreviewHeaderCell(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
        ),
      ),
    );
  }
}

/// Data cell for report tables with dark-mode color adaptation.
class ReportPreviewDataCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final Color? color;
  final TextAlign align;

  const ReportPreviewDataCell(
    this.text, {
    super.key,
    this.isBold = false,
    this.color,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color? cellColor = color;
    if (isDark) {
      if (cellColor == null || cellColor == AppTheme.charcoal) {
        cellColor = AppTheme.darkTextPrimary;
      } else if (cellColor == AppTheme.textSecondary) {
        cellColor = AppTheme.darkTextSecondary;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: cellColor ?? AppTheme.charcoal,
        ),
      ),
    );
  }
}
