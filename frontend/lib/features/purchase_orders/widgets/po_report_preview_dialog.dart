import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/utils/po_packing_matcher.dart';
import 'report_preview/po_report_preview_actions.dart';
import 'report_preview/po_report_preview_header.dart';
import 'report_preview/po_report_preview_helpers.dart';
import 'report_preview/po_report_preview_table.dart';

/// Modal dialog providing a complete, high-fidelity preview of a Purchase Order report,
/// including invoice items, packing list, package breakdown, and master pallet plan.
class POReportPreviewDialog extends StatefulWidget {
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
  final String? projectName;
  final String? importFileCode;
  final List<POLineItemModel> items;
  final List<PackingListItemModel> packingItems;
  final List<PalletPlanItemModel> palletItems;
  final List<CustomsTariffModel> tariffs;
  final bool isDirectVolumeMode;
  final String? notes;
  final VoidCallback? onConfirmSave;
  final Locale? initialLocale;

  const POReportPreviewDialog({
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
    this.projectName,
    this.importFileCode,
    required this.items,
    required this.packingItems,
    required this.palletItems,
    this.tariffs = const [],
    this.isDirectVolumeMode = false,
    this.notes,
    this.onConfirmSave,
    this.initialLocale,
  });

  static Future<void> show({
    required BuildContext context,
    required String poNumber,
    String? piNumber,
    String? acidNumber,
    required DateTime orderDate,
    required String companyName,
    String? companyTaxId,
    required String supplierName,
    String? supplierCountry,
    required String incoterm,
    required String currency,
    required double exchangeRate,
    String? countryOfOrigin,
    String? paymentTerms,
    String? projectName,
    String? importFileCode,
    required List<POLineItemModel> items,
    required List<PackingListItemModel> packingItems,
    required List<PalletPlanItemModel> palletItems,
    List<CustomsTariffModel> tariffs = const [],
    bool isDirectVolumeMode = false,
    String? notes,
    VoidCallback? onConfirmSave,
    Locale? initialLocale,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => POReportPreviewDialog(
        poNumber: poNumber,
        piNumber: piNumber,
        acidNumber: acidNumber,
        orderDate: orderDate,
        companyName: companyName,
        companyTaxId: companyTaxId,
        supplierName: supplierName,
        supplierCountry: supplierCountry,
        incoterm: incoterm,
        currency: currency,
        exchangeRate: exchangeRate,
        countryOfOrigin: countryOfOrigin,
        paymentTerms: paymentTerms,
        projectName: projectName,
        importFileCode: importFileCode,
        items: items,
        packingItems: packingItems,
        palletItems: palletItems,
        tariffs: tariffs,
        isDirectVolumeMode: isDirectVolumeMode,
        notes: notes,
        onConfirmSave: onConfirmSave,
        initialLocale: initialLocale,
      ),
    );
  }

  @override
  State<POReportPreviewDialog> createState() => _POReportPreviewDialogState();
}

class _POReportPreviewDialogState extends State<POReportPreviewDialog> {
  Locale? _overrideLocale;

  @override
  void initState() {
    super.initState();
    _overrideLocale = widget.initialLocale;
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = _overrideLocale ?? Localizations.localeOf(context);
    final isArabic = currentLocale.languageCode == 'ar';
    final l = AppLocalizationsProvider.resolve(currentLocale);

    final metrics = POReportPreviewMetrics.calculate(
      items: widget.items,
      packingItems: widget.packingItems,
      palletItems: widget.palletItems,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final packageTypeSummaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(widget.packingItems);

    return AppLocalizationsProvider(
      locale: currentLocale,
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SelectionArea(
          child: Dialog(
            backgroundColor: isDark ? AppTheme.darkSurface : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Container(
              width: screenWidth > 1150 ? 1080 : (screenWidth * 0.95),
              constraints: const BoxConstraints(maxHeight: 820),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  POReportPreviewTopBar(
                    onToggleLanguage: () {
                      setState(() {
                        _overrideLocale = isArabic ? const Locale('en') : const Locale('ar');
                      });
                    },
                    onOpen3dSimulation: () {
                      showPoVisualLoadPlanner(
                        context: context,
                        poNumber: widget.poNumber,
                        companyName: widget.companyName,
                        supplierName: widget.supplierName,
                        packingItems: widget.packingItems,
                        palletItems: widget.palletItems,
                        isDirectVolumeMode: widget.isDirectVolumeMode,
                      );
                    },
                    onCopyText: () {
                      copyPOReportTextToClipboard(
                        context: context,
                        l: l,
                        isArabic: isArabic,
                        poNumber: widget.poNumber,
                        piNumber: widget.piNumber,
                        acidNumber: widget.acidNumber,
                        orderDate: widget.orderDate,
                        companyName: widget.companyName,
                        companyTaxId: widget.companyTaxId,
                        supplierName: widget.supplierName,
                        supplierCountry: widget.supplierCountry,
                        incoterm: widget.incoterm,
                        currency: widget.currency,
                        exchangeRate: widget.exchangeRate,
                        countryOfOrigin: widget.countryOfOrigin,
                        projectName: widget.projectName,
                        importFileCode: widget.importFileCode,
                        items: widget.items,
                        packingItems: widget.packingItems,
                        palletItems: widget.palletItems,
                        metrics: metrics,
                      );
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          POReportPreviewHeaderCard(
                            poNumber: widget.poNumber,
                            piNumber: widget.piNumber,
                            acidNumber: widget.acidNumber,
                            orderDate: widget.orderDate,
                            companyName: widget.companyName,
                            companyTaxId: widget.companyTaxId,
                            supplierName: widget.supplierName,
                            supplierCountry: widget.supplierCountry,
                            incoterm: widget.incoterm,
                            currency: widget.currency,
                            exchangeRate: widget.exchangeRate,
                            countryOfOrigin: widget.countryOfOrigin,
                            paymentTerms: widget.paymentTerms,
                            importFileCode: widget.importFileCode,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          POReportPreviewMetricsBar(
                            metrics: metrics,
                            packingItems: widget.packingItems,
                            currency: widget.currency,
                            isArabic: isArabic,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          ReportPreviewSectionTitle(
                            title: l.poReportSec1InvoiceItems,
                            icon: Icons.receipt_long_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          POReportInvoiceItemsTable(
                            items: widget.items,
                            tariffs: widget.tariffs,
                            currency: widget.currency,
                            isArabic: isArabic,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 18),
                          ReportPreviewSectionTitle(
                            title: l.poReportSec2PackingList,
                            icon: Icons.inventory_2_outlined,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          POReportPackingListTable(
                            packingItems: widget.packingItems,
                            items: widget.items,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 18),
                          if (packageTypeSummaryMap.isNotEmpty) ...[
                            ReportPreviewSectionTitle(
                              title: context.l10n.poSummaryByPackageType,
                              icon: Icons.category_outlined,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            POReportPackageTypeSummaryTable(
                              packageTypeSummaryMap: packageTypeSummaryMap,
                              isArabic: isArabic,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (widget.palletItems.isNotEmpty && widget.palletItems.any((p) => p.palletCount > 0)) ...[
                            ReportPreviewSectionTitle(
                              title: l.poReportSec3PalletPlan,
                              icon: Icons.layers_outlined,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            POReportPalletPlanTable(
                              palletItems: widget.palletItems,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (widget.notes != null && widget.notes!.trim().isNotEmpty) ...[
                            ReportPreviewSectionTitle(
                              title: l.poReportSec4Notes,
                              icon: Icons.note_alt_outlined,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                              ),
                              child: Text(
                                widget.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                  POReportPreviewFooter(
                    itemsCount: widget.items.length,
                    packingItemsCount: widget.packingItems.length,
                    totalPallets: metrics.totalPallets,
                    onConfirmSave: widget.onConfirmSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
