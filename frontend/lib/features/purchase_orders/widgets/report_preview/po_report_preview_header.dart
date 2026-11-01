import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/display_name_resolver.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/utils/po_packing_matcher.dart';
import 'po_report_preview_helpers.dart';

/// Top bar for PO Report Preview Dialog containing action buttons and window controls.
class POReportPreviewTopBar extends StatelessWidget {
  final VoidCallback onToggleLanguage;
  final VoidCallback onOpen3dSimulation;
  final VoidCallback onCopyText;

  const POReportPreviewTopBar({
    super.key,
    required this.onToggleLanguage,
    required this.onOpen3dSimulation,
    required this.onCopyText,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkScaffoldBackground : AppTheme.charcoal,
        borderRadius: const BorderRadiusDirectional.only(
          topStart: Radius.circular(16),
          topEnd: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.poReportPreviewTitle,
                  style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l.poReportPreviewSubtitle,
                  style: TextStyle(color: AppTheme.white.withValues(alpha: 0.8), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppButton(
            label: l.poReportSwitchLanguageBtn,
            icon: Icons.language_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onToggleLanguage,
          ),
          const SizedBox(width: 8),
          AppButton(
            label: l.poReport3dSimulation,
            icon: Icons.view_in_ar_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onOpen3dSimulation,
          ),
          const SizedBox(width: 8),
          AppButton(
            label: l.poReportCopyText,
            icon: Icons.copy_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onCopyText,
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.white.withValues(alpha: 0.7)),
            tooltip: l.poReportClosePreview,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Document header information card displaying buyer, seller, PO codes, and dates.
class POReportPreviewHeaderCard extends StatelessWidget {
  final String poNumber;
  final String? piNumber;
  final String? acidNumber;
  final DateTime orderDate;
  final String companyName;
  final String? companyTaxId;
  final String supplierName;
  final String? supplierCountry;
  final String incoterm;
  final String currency;
  final double exchangeRate;
  final String? countryOfOrigin;
  final String? paymentTerms;
  final String? importFileCode;
  final bool isDark;

  const POReportPreviewHeaderCard({
    super.key,
    required this.poNumber,
    this.piNumber,
    this.acidNumber,
    required this.orderDate,
    required this.companyName,
    this.companyTaxId,
    required this.supplierName,
    this.supplierCountry,
    required this.incoterm,
    required this.currency,
    required this.exchangeRate,
    this.countryOfOrigin,
    this.paymentTerms,
    this.importFileCode,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final hasPi = piNumber != null && piNumber!.isNotEmpty;
    final hasAcid = acidNumber != null && acidNumber!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.poReportHeaderDocumentTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isDark ? AppTheme.darkHyperlink : AppTheme.wcagCobalt,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l.poReportPoNumber}: $poNumber ${hasPi ? " | ${l.poReportPiNumber}: $piNumber" : ""}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    if (hasAcid)
                      Text(
                        '${l.poReportAcidNumber}: $acidNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.emerald),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${l.poReportOrderDate}: ${orderDate.toIso8601String().substring(0, 10)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l.currency}: $currency (${l.poReportExchangeRate}: ${exchangeRate.toStringAsFixed(4)} EGP)',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                  ),
                  Text(
                    '${l.poReportIncoterms}: $incoterm | ${l.poReportOrigin}: ${countryOfOrigin ?? "N/A"}',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PartyBox(
                isDark: isDark,
                children: [
                  Text(
                    '🏢 ${l.poReportBuyer}:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    companyName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  ),
                  if (companyTaxId != null && companyTaxId!.isNotEmpty)
                    Text(
                      '${l.poReportTaxId}: $companyTaxId',
                      style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                    ),
                  if (importFileCode != null && importFileCode!.isNotEmpty)
                    Text(
                      '${l.poReportImportFile}: ${DisplayNameResolver.resolveShipmentTitleByCode(importFileCode, isArabic: isArabic)}',
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              _PartyBox(
                isDark: isDark,
                children: [
                  Text(
                    '🚢 ${l.poReportSeller}:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    supplierName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  ),
                  Text(
                    '${l.poReportSupplierCountry}: ${supplierCountry ?? countryOfOrigin ?? "N/A"}',
                    style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                  ),
                  if (paymentTerms != null && paymentTerms!.isNotEmpty)
                    Text(
                      '${l.poReportPaymentTerms}: $paymentTerms',
                      style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartyBox extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _PartyBox({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

/// Metrics summary row displaying total invoice, packaging, weight, volume, and container recommendation.
class POReportPreviewMetricsBar extends StatelessWidget {
  final POReportPreviewMetrics metrics;
  final List<PackingListItemModel> packingItems;
  final String currency;
  final bool isArabic;
  final bool isDark;

  const POReportPreviewMetricsBar({
    super.key,
    required this.metrics,
    required this.packingItems,
    required this.currency,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final packagingSummaryText = PoPackingMatcher.formatPackagingSummary(
      packingListItems: packingItems,
      totalPalletCount: metrics.totalPallets,
      isArabic: isArabic,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.cobalt.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.cobalt.withValues(alpha: 0.25),
        ),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ReportPreviewMetricBadge(
            label: l.poReportTotalInvoice,
            value: '${metrics.totalAmount.toStringAsFixed(2)} $currency',
            icon: Icons.monetization_on_outlined,
            color: AppTheme.emerald,
            isDark: isDark,
          ),
          ReportPreviewMetricBadge(
            label: l.poReportTotalPkgsAndPcs,
            value: packagingSummaryText,
            icon: Icons.inventory_2_outlined,
            color: AppTheme.cobalt,
            isDark: isDark,
          ),
          ReportPreviewMetricBadge(
            label: l.poReportGrossWeight,
            value: '${formatPOWeight(metrics.totalGrossWeight)} kg',
            icon: Icons.scale_outlined,
            color: AppTheme.orange,
            isDark: isDark,
          ),
          ReportPreviewMetricBadge(
            label: l.poReportVolumeCbm,
            value: '${metrics.totalCbm.toStringAsFixed(3)} m³',
            icon: Icons.view_in_ar_outlined,
            color: AppTheme.cobalt,
            isDark: isDark,
          ),
          if (metrics.totalPallets > 0)
            ReportPreviewMetricBadge(
              label: l.poReportPalletPlan,
              value: '${metrics.totalPallets} ${l.poReportPalletsCountUnit(metrics.totalPallets)} (${metrics.totalPalletCbm.toStringAsFixed(3)} m³)',
              icon: Icons.layers_outlined,
              color: AppTheme.cobalt,
              isDark: isDark,
            ),
          ReportPreviewMetricBadge(
            label: l.poReportRecommendedContainer,
            value: metrics.recommendedContainer,
            icon: Icons.directions_boat_outlined,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}
