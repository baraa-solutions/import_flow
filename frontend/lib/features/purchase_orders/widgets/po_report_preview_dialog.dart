import 'package:frontend/core/utils/container_requirement_engine.dart';
import 'package:frontend/core/widgets/container_load_plan_painter.dart';
import 'package:frontend/core/services/container_load_plan_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/display_name_resolver.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import '../utils/po_packing_matcher.dart';

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

    final double totalAmount = widget.items.fold(
      0.0,
      (sum, i) => sum + (i.totalPrice > 0 ? i.totalPrice : (i.quantity * i.unitPrice)),
    );

    final double totalGrossWeight = widget.packingItems.fold(
      0.0,
      (sum, p) => sum + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.grossWeightUnitKg * p.qtyPkg)),
    );

    final double totalNetWeight = widget.packingItems.fold(
      0.0,
      (sum, p) => sum + (p.totalNetWeightKg > 0 ? p.totalNetWeightKg : (p.netWeightUnitKg * p.qtyPkg)),
    );

    final double totalPackages = widget.packingItems.fold(0.0, (sum, p) => sum + p.qtyPkg);
    final double totalPcs = widget.packingItems.fold(0.0, (sum, p) => sum + p.qtyPcs);
    final double totalCbm = widget.packingItems.fold(0.0, (sum, p) => sum + p.calculatedCbm);

    final int totalPallets = widget.palletItems.fold(0, (sum, p) => sum + p.palletCount);
    final double totalPalletCbm = widget.palletItems.fold(0.0, (sum, p) => sum + p.calculatedCbm);
    final double totalPalletWeight = widget.palletItems.fold(0.0, (sum, p) => sum + p.totalWeightKg);

    final bool hasActivePallets = totalPallets > 0 && totalPalletCbm > 0;
    final double effectiveCbm = hasActivePallets ? totalPalletCbm : totalCbm;
    final double effectiveGrossWeight = (hasActivePallets && totalPalletWeight > 0) ? totalPalletWeight : totalGrossWeight;

    // Compute container recommendation
    String recommendedContainer = '20ft Standard (20GP)';
    if (totalPallets > 11 || effectiveCbm > 28.0 || effectiveGrossWeight > 21500) {
      recommendedContainer = '40ft High Cube (40HC)';
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppLocalizationsProvider(
      locale: currentLocale,
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: isDark ? AppTheme.darkSurface : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Container(
            width: screenWidth > 1150 ? 1080 : (screenWidth * 0.95),
            constraints: const BoxConstraints(maxHeight: 820),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A22) : AppTheme.charcoal,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.poReportPreviewTitle,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l.poReportPreviewSubtitle,
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Language Switcher Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.cobalt),
                          backgroundColor: Colors.white.withOpacity(0.15),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.language_rounded, size: 15, color: Colors.white),
                        label: Text(
                          l.poReportSwitchLanguageBtn,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: () {
                          setState(() {
                            _overrideLocale = isArabic ? const Locale('en') : const Locale('ar');
                          });
                        },
                      ),
                      const SizedBox(width: 8),

                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.cobalt),
                          backgroundColor: AppTheme.cobalt.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.view_in_ar_rounded, size: 16, color: Colors.white),
                        label: Text(l.poReport3dSimulation, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () => _showPoVisualLoadPlannerDialog(context, l),
                      ),
                      const SizedBox(width: 8),

                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: Text(l.poReportCopyText, style: const TextStyle(fontSize: 11.5)),
                        onPressed: () => _copyReportTextToClipboard(context, l, isArabic, totalAmount, totalGrossWeight, totalNetWeight, totalPackages, totalCbm, totalPallets, totalPalletCbm, totalPalletWeight, effectiveCbm, effectiveGrossWeight),
                      ),
                      const SizedBox(width: 6),

                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: l.poReportClosePreview,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content (Report Body)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Document Header Box
                        _buildReportHeaderCard(l, isArabic, totalAmount, isDark),
                        const SizedBox(height: 14),

                        // Metrics Badges
                        _buildMetricsSummaryBar(
                          l: l,
                          totalAmount: totalAmount,
                          totalPackages: totalPackages,
                          totalPcs: totalPcs,
                          totalGrossWeight: totalGrossWeight,
                          totalNetWeight: totalNetWeight,
                          totalCbm: totalCbm,
                          totalPallets: totalPallets,
                          totalPalletCbm: totalPalletCbm,
                          totalPalletWeight: totalPalletWeight,
                          recommendedContainer: recommendedContainer,
                          isArabic: isArabic,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),

                        // Section 1: Commercial Invoice Line Items Table
                        _buildSectionTitle(l.poReportSec1InvoiceItems, Icons.receipt_long_rounded, isDark),
                        const SizedBox(height: 8),
                        _buildInvoiceItemsTable(l, isArabic, isDark),
                        const SizedBox(height: 18),

                        // Section 2: Detailed Packing List Table
                        _buildSectionTitle(l.poReportSec2PackingList, Icons.inventory_2_outlined, isDark),
                        const SizedBox(height: 8),
                        _buildPackingListTable(l, isDark),
                        const SizedBox(height: 18),

                        // Section 2.5: Package Type Summary Table
                        () {
                          final packageTypeSummaryMap = PoPackingMatcher.buildPackingTypeSummaryMap(widget.packingItems);
                          if (packageTypeSummaryMap.isNotEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(isArabic ? 'ملخص نوع التغليف (Summary By Package Type)' : 'Summary By Package Type', Icons.category_outlined, isDark),
                                const SizedBox(height: 8),
                                _buildPackageTypeSummaryTable(packageTypeSummaryMap, isArabic, isDark),
                                const SizedBox(height: 18),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        }(),

                        // Section 3: Master Pallet Plan Table
                        if (widget.palletItems.isNotEmpty && widget.palletItems.any((p) => p.palletCount > 0)) ...[
                          _buildSectionTitle(l.poReportSec3PalletPlan, Icons.layers_outlined, isDark),
                          const SizedBox(height: 8),
                          _buildPalletPlanTable(l, isDark),
                          const SizedBox(height: 18),
                        ],

                        // Notes Section
                        if (widget.notes != null && widget.notes!.trim().isNotEmpty) ...[
                          _buildSectionTitle(l.poReportSec4Notes, Icons.note_alt_outlined, isDark),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCardBackground : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                            ),
                            child: Text(
                              widget.notes!,
                              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBackground : Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 4, offset: const Offset(0, -2)),
                    ],
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${l.poReportReadyForApproval}: ${l.poReportItemsCountUnit(widget.items.length)} | ${l.poReportPackagesCountUnit(widget.packingItems.length)} ${totalPallets > 0 ? " | ${l.poReportPalletsCountUnit(totalPallets)}" : ""}',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l.poReportCloseAndEdit, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : null)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cobalt,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: Text(l.poReportSaveAndApprove, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onConfirmSave?.call();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.cobalt),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
          ),
        ),
      ],
    );
  }

  Widget _buildReportHeaderCard(AppLocalizations l, bool isArabic, double totalAmount, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 4, offset: const Offset(0, 2)),
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
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? const Color(0xFF60A5FA) : Colors.blue.shade900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l.poReportPoNumber}: ${widget.poNumber} ${widget.piNumber != null && widget.piNumber!.isNotEmpty ? " | ${l.poReportPiNumber}: ${widget.piNumber}" : ""}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                    if (widget.acidNumber != null && widget.acidNumber!.isNotEmpty)
                      Text(
                        '${l.poReportAcidNumber}: ${widget.acidNumber}',
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
                    '${l.poReportOrderDate}: ${widget.orderDate.toIso8601String().substring(0, 10)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l.currency}: ${widget.currency} (${l.poReportExchangeRate}: ${widget.exchangeRate.toStringAsFixed(4)} EGP)',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.black54),
                  ),
                  Text(
                    '${l.poReportIncoterms}: ${widget.incoterm} | ${l.poReportOrigin}: ${widget.countryOfOrigin ?? "N/A"}',
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏢 ${l.poReportBuyer}:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54)),
                      const SizedBox(height: 2),
                      Text(widget.companyName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                      if (widget.companyTaxId != null && widget.companyTaxId!.isNotEmpty)
                        Text('${l.poReportTaxId}: ${widget.companyTaxId}', style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54)),
                      if (widget.importFileCode != null && widget.importFileCode!.isNotEmpty)
                        Text('${l.poReportImportFile}: ${DisplayNameResolver.resolveShipmentTitleByCode(widget.importFileCode, isArabic: Localizations.localeOf(context).languageCode == "ar")}', style: const TextStyle(fontSize: 10.5, color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🚢 ${l.poReportSeller}:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54)),
                      const SizedBox(height: 2),
                      Text(widget.supplierName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                      Text('${l.poReportSupplierCountry}: ${widget.supplierCountry ?? widget.countryOfOrigin ?? "N/A"}', style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54)),
                      if (widget.paymentTerms != null && widget.paymentTerms!.isNotEmpty)
                        Text('${l.poReportPaymentTerms}: ${widget.paymentTerms}', style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatWeight(double val) => PoPackingMatcher.formatWeight(val);

  Widget _buildMetricsSummaryBar({
    required AppLocalizations l,
    required double totalAmount,
    required double totalPackages,
    required double totalPcs,
    required double totalGrossWeight,
    required double totalNetWeight,
    required double totalCbm,
    required int totalPallets,
    required double totalPalletCbm,
    required double totalPalletWeight,
    required String recommendedContainer,
    bool isArabic = false,
    bool isDark = false,
  }) {
    final packagingSummaryText = PoPackingMatcher.formatPackagingSummary(
      packingListItems: widget.packingItems,
      totalPalletCount: totalPallets,
      isArabic: isArabic,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.cobalt.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cobalt.withOpacity(0.25)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          _buildMetricBadge(l.poReportTotalInvoice, '${totalAmount.toStringAsFixed(2)} ${widget.currency}', Icons.monetization_on_outlined, AppTheme.emerald, isDark: isDark),
          _buildMetricBadge(l.poReportTotalPkgsAndPcs, packagingSummaryText, Icons.inventory_2_outlined, AppTheme.cobalt, isDark: isDark),
          _buildMetricBadge(l.poReportGrossWeight, '${_formatWeight(totalGrossWeight)} kg', Icons.scale_outlined, AppTheme.orange, isDark: isDark),
          _buildMetricBadge(l.poReportVolumeCbm, '${totalCbm.toStringAsFixed(3)} m³', Icons.view_in_ar_outlined, Colors.purple, isDark: isDark),
          if (totalPallets > 0)
            _buildMetricBadge(l.poReportPalletPlan, '$totalPallets ${l.poReportPalletsCountUnit(totalPallets)} (${totalPalletCbm.toStringAsFixed(3)} m³)', Icons.layers_outlined, Colors.indigo, isDark: isDark),
          _buildMetricBadge(l.poReportRecommendedContainer, recommendedContainer, Icons.directions_boat_outlined, isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, isDark: isDark),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String label, String value, IconData icon, Color color, {bool isDark = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54)),
            Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  Widget _buildInvoiceItemsTable(AppLocalizations l, bool isArabic, bool isDark) {
    final double totalInvoiceQty = widget.items.fold(0.0, (s, i) => s + i.quantity);
    final double totalInvoicePrice = widget.items.fold(
      0.0,
      (s, i) => s + (i.totalPrice > 0 ? i.totalPrice : (i.quantity * i.unitPrice)),
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 850),
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(horizontalInside: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200, width: 1)),
              columnWidths: const {
                0: FixedColumnWidth(36),
                1: FixedColumnWidth(100),
                2: FixedColumnWidth(160),
                3: FixedColumnWidth(220),
                4: FixedColumnWidth(110),
                5: FixedColumnWidth(90),
                6: FixedColumnWidth(100),
                7: FixedColumnWidth(115),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.grey.shade100),
                  children: [
                    const _HeaderCell('#'),
                    _HeaderCell(l.poReportColItemCode),
                    _HeaderCell(l.mainDescription),
                    _HeaderCell(l.poReportColDescription),
                    _HeaderCell(l.poReportColHsCode),
                    _HeaderCell(l.poReportColQtyUnit),
                    _HeaderCell(l.poReportColUnitPrice),
                    _HeaderCell(l.poReportColTotalAmount),
                  ],
                ),
                ...widget.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final itm = entry.value;
                  String hs = itm.hsCode ?? '';
                  if (hs.isEmpty && itm.tariffId != null) {
                    final match = widget.tariffs.where((t) => t.tariffId == itm.tariffId).firstOrNull;
                    if (match != null) hs = match.hsCode;
                  }
                  final itemTotal = (itm.totalPrice > 0) ? itm.totalPrice : (itm.quantity * itm.unitPrice);
                  final desc = isArabic
                      ? (itm.descriptionAr.isNotEmpty ? itm.descriptionAr : (itm.descriptionEn ?? '-'))
                      : (itm.descriptionEn?.isNotEmpty == true ? itm.descriptionEn! : itm.descriptionAr);
                  final mainDesc = itm.mainDescription?.isNotEmpty == true ? itm.mainDescription! : '-';

                  return TableRow(
                    decoration: BoxDecoration(color: idx % 2 == 1 ? (isDark ? const Color(0xFF1B232D) : const Color(0xFFFDFDFD)) : (isDark ? AppTheme.darkCardBackground : Colors.white)),
                    children: [
                      _DataCell('${idx + 1}', align: TextAlign.center),
                      _DataCell(itm.itemCode ?? '-', isBold: true, color: AppTheme.cobalt),
                      _DataCell(mainDesc, isBold: itm.mainDescription?.isNotEmpty == true, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      _DataCell(desc),
                      _DataCell(hs.isNotEmpty ? hs : (isArabic ? '⚠️ غير مسجل' : '⚠️ Unregistered'), color: hs.isNotEmpty ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal) : Colors.red),
                      _DataCell('${itm.quantity.toStringAsFixed(0)} ${itm.unitOfMeasure}'),
                      _DataCell('${itm.unitPrice.toStringAsFixed(2)} ${widget.currency}'),
                      _DataCell('${itemTotal.toStringAsFixed(2)} ${widget.currency}', isBold: true),
                    ],
                  );
                }),
                TableRow(
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50.withOpacity(0.5)),
                  children: [
                    const _DataCell(''),
                    _DataCell(l.poReportGrandTotal, isBold: true, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    const _DataCell(''),
                    _DataCell(l.poReportItemsCountUnit(widget.items.length), isBold: true),
                    const _DataCell(''),
                    _DataCell('${totalInvoiceQty.toStringAsFixed(0)} pcs', isBold: true),
                    const _DataCell(''),
                    _DataCell('${totalInvoicePrice.toStringAsFixed(2)} ${widget.currency}', isBold: true, color: AppTheme.emerald),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackingListTable(AppLocalizations l, bool isDark) {
    final double totalPkgSum = widget.packingItems.fold<double>(0.0, (s, p) => s + p.qtyPkg);
    final double totalPcsSum = widget.packingItems.fold<double>(0.0, (s, p) => s + p.qtyPcs);
    final double totalGrossSum = widget.packingItems.fold<double>(0.0, (s, p) => s + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.grossWeightUnitKg * p.qtyPkg)));
    final double totalCbmSum = widget.packingItems.fold<double>(0.0, (s, p) => s + p.calculatedCbm);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 950),
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(horizontalInside: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200, width: 1)),
              columnWidths: const {
                0: FixedColumnWidth(36),
                1: FixedColumnWidth(100),
                2: FixedColumnWidth(140),
                3: FixedColumnWidth(180),
                4: FixedColumnWidth(80),
                5: FixedColumnWidth(90),
                6: FixedColumnWidth(100),
                7: FixedColumnWidth(90),
                8: FixedColumnWidth(85),
                9: FixedColumnWidth(80),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.grey.shade100),
                  children: [
                    const _HeaderCell('#'),
                    _HeaderCell(l.poReportColItemCode),
                    _HeaderCell(l.mainDescription),
                    _HeaderCell(l.poReportColDescription),
                    _HeaderCell(l.poReportColPkgType),
                    _HeaderCell(l.poReportTotalPkgsAndPcs),
                    _HeaderCell(l.poReportColDimensions),
                    _HeaderCell(l.poReportGrossWeight),
                    _HeaderCell(l.poReportVolumeCbm),
                    _HeaderCell(l.poReportColStackable),
                  ],
                ),
                ...widget.packingItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final p = entry.value;
                  final grossTot = p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.grossWeightUnitKg * p.qtyPkg);
                  final dimStr = (p.lengthCm > 0 && p.widthCm > 0 && p.heightCm > 0)
                      ? '${p.lengthCm.toStringAsFixed(0)}×${p.widthCm.toStringAsFixed(0)}×${p.heightCm.toStringAsFixed(0)}'
                      : l.poReportDirectVolume;

                  String mainDesc = p.mainDescription ?? '';
                  if (mainDesc.isEmpty) {
                    final matchedItem = widget.items.where((i) => i.itemCode != null && i.itemCode == p.itemCode).firstOrNull;
                    if (matchedItem != null && matchedItem.mainDescription?.isNotEmpty == true) {
                      mainDesc = matchedItem.mainDescription!;
                    }
                  }

                  return TableRow(
                    decoration: BoxDecoration(color: idx % 2 == 1 ? (isDark ? const Color(0xFF1B232D) : const Color(0xFFFDFDFD)) : (isDark ? AppTheme.darkCardBackground : Colors.white)),
                    children: [
                      _DataCell('${idx + 1}', align: TextAlign.center),
                      _DataCell(p.itemCode, isBold: true, color: AppTheme.cobalt),
                      _DataCell(mainDesc.isNotEmpty ? mainDesc : '-', isBold: mainDesc.isNotEmpty, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      _DataCell(p.description != null && p.description!.isNotEmpty ? p.description! : '-'),
                      _DataCell(p.packageType),
                      _DataCell('${p.qtyPkg.toStringAsFixed(0)} / ${p.qtyPcs.toStringAsFixed(0)}'),
                      _DataCell(dimStr, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                      _DataCell(_formatWeight(grossTot)),
                      _DataCell(p.calculatedCbm.toStringAsFixed(3)),
                      _DataCell(p.isStackable ? l.poReportStackableYes : l.poReportStackableNo, color: p.isStackable ? (isDark ? Colors.greenAccent : Colors.green.shade800) : Colors.orange.shade800),
                    ],
                  );
                }),
                TableRow(
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50.withOpacity(0.5)),
                  children: [
                    const _DataCell(''),
                    _DataCell(l.poReportTotalPacking, isBold: true, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    const _DataCell(''),
                    _DataCell(l.poReportRowsCountUnit(widget.packingItems.length), isBold: true),
                    const _DataCell(''),
                    _DataCell(
                      '${totalPkgSum.toStringAsFixed(0)} ${l.poReportPackagesCountUnit(totalPkgSum.toInt())} / ${totalPcsSum.toStringAsFixed(0)} ${l.poReportPiecesCountUnit(totalPcsSum.toInt())}',
                      isBold: true,
                    ),
                    const _DataCell(''),
                    _DataCell(
                      '${_formatWeight(totalGrossSum)} kg',
                      isBold: true,
                      color: AppTheme.orange,
                    ),
                    _DataCell(
                      '${totalCbmSum.toStringAsFixed(3)} m³',
                      isBold: true,
                      color: Colors.purple,
                    ),
                    const _DataCell(''),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPackageTypeSummaryTable(
    Map<String, Map<String, dynamic>> packageTypeSummaryMap,
    bool isArabic,
    bool isDark,
  ) {
    if (packageTypeSummaryMap.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 700),
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(2.2),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                  children: [
                    _HeaderCell(isArabic ? 'نوع التغليف' : 'Package Type'),
                    _HeaderCell(isArabic ? 'إجمالي الطرود' : 'Total Packages'),
                    _HeaderCell(isArabic ? 'الصافي (كجم)' : 'Net Wt (kg)'),
                    _HeaderCell(isArabic ? 'القائم (كجم)' : 'Gross Wt (kg)'),
                    _HeaderCell(isArabic ? 'الحجم CBM' : 'Volume CBM'),
                  ],
                ),
                ...packageTypeSummaryMap.values.map((pkgSummary) {
                  final pkgType = '${pkgSummary['package_type']}';
                  final count = pkgSummary['qty_pkg'] as int;
                  final net = pkgSummary['total_net'] as double;
                  final gross = pkgSummary['total_gross'] as double;
                  final cbm = pkgSummary['total_cbm'] as double;

                  return TableRow(
                    children: [
                      _DataCell(pkgType, isBold: true, color: AppTheme.cobalt),
                      _DataCell('$count', isBold: true),
                      _DataCell('${_formatWeight(net)} kg'),
                      _DataCell('${_formatWeight(gross)} kg', isBold: true),
                      _DataCell('${cbm.toStringAsFixed(3)} m³', color: Colors.purple, isBold: true),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPalletPlanTable(AppLocalizations l, bool isDark) {
    final int palletSum = widget.palletItems.fold<int>(0, (s, p) => s + p.palletCount);
    final double weightSum = widget.palletItems.fold<double>(0.0, (s, p) => s + p.totalWeightKg);
    final double cbmSum = widget.palletItems.fold<double>(0.0, (s, p) => s + p.calculatedCbm);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 700),
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(horizontalInside: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200, width: 1)),
              columnWidths: const {
                0: FixedColumnWidth(36),
                1: FixedColumnWidth(160),
                2: FixedColumnWidth(80),
                3: FixedColumnWidth(110),
                4: FixedColumnWidth(90),
                5: FixedColumnWidth(90),
                6: FixedColumnWidth(130),
                7: FixedColumnWidth(160),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.grey.shade100),
                  children: [
                    const _HeaderCell('#'),
                    _HeaderCell(l.palletTypeCol),
                    _HeaderCell(l.palletCountCol),
                    _HeaderCell(l.palletDimensionsCol),
                    _HeaderCell(l.palletWeightCol),
                    _HeaderCell(l.palletVolumeCol),
                    _HeaderCell(l.palletStackingInstructionsCol),
                    _HeaderCell(l.notes),
                  ],
                ),
                ...widget.palletItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final p = entry.value;
                  return TableRow(
                    decoration: BoxDecoration(color: idx % 2 == 1 ? (isDark ? const Color(0xFF1B232D) : const Color(0xFFFDFDFD)) : (isDark ? AppTheme.darkCardBackground : Colors.white)),
                    children: [
                      _DataCell('${idx + 1}', align: TextAlign.center),
                      _DataCell(p.palletType, isBold: true),
                      _DataCell('${p.palletCount} ${l.poReportPalletsCountUnit(p.palletCount)}', isBold: true, color: AppTheme.cobalt),
                      _DataCell('${p.lengthCm.toStringAsFixed(0)}×${p.widthCm.toStringAsFixed(0)}×${p.heightCm.toStringAsFixed(0)}'),
                      _DataCell(_formatWeight(p.totalWeightKg)),
                      _DataCell(p.calculatedCbm.toStringAsFixed(3)),
                      _DataCell(p.isStackable ? l.poReportStackableYes : l.poReportStackableNo, color: p.isStackable ? (isDark ? Colors.greenAccent : Colors.green.shade800) : Colors.orange.shade800),
                      _DataCell(p.notes != null && p.notes!.isNotEmpty ? p.notes! : '-'),
                    ],
                  );
                }),
                TableRow(
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50.withOpacity(0.5)),
                  children: [
                    const _DataCell(''),
                    _DataCell(l.poReportTotalPallets, isBold: true, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    _DataCell('$palletSum ${l.poReportPalletsCountUnit(palletSum)}', isBold: true, color: AppTheme.cobalt),
                    const _DataCell(''),
                    _DataCell('${_formatWeight(weightSum)} kg', isBold: true),
                    _DataCell('${cbmSum.toStringAsFixed(3)} m³', isBold: true, color: Colors.purple),
                    const _DataCell(''),
                    const _DataCell(''),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyReportTextToClipboard(
    BuildContext context,
    AppLocalizations l,
    bool isArabic,
    double totalAmount,
    double totalGrossWeight,
    double totalNetWeight,
    double totalPackages,
    double totalCbm,
    int totalPallets,
    double totalPalletCbm,
    double totalPalletWeight,
    double effectiveCbm,
    double effectiveGrossWeight,
  ) {
    final sb = StringBuffer();
    sb.writeln('================================================================');
    sb.writeln('Sorour Logistics ERP — ${l.poReportHeaderDocumentTitle}');
    sb.writeln('================================================================');
    sb.writeln('${l.poReportPoNumber}: ${widget.poNumber}');
    if (widget.piNumber != null) sb.writeln('${l.poReportPiNumber}: ${widget.piNumber}');
    if (widget.acidNumber != null) sb.writeln('${l.poReportAcidNumber}: ${widget.acidNumber}');
    sb.writeln('${l.poReportOrderDate}: ${widget.orderDate.toIso8601String().substring(0, 10)}');
    sb.writeln('${l.poReportBuyer}: ${widget.companyName} (${l.poReportTaxId}: ${widget.companyTaxId ?? "N/A"})');
    sb.writeln('${l.poReportSeller}: ${widget.supplierName} (${l.poReportSupplierCountry}: ${widget.supplierCountry ?? widget.countryOfOrigin ?? "N/A"})');
    sb.writeln('${l.poReportIncoterms}: ${widget.incoterm} | ${l.currency}: ${widget.currency} | ${l.poReportExchangeRate}: ${widget.exchangeRate} EGP');
    if (widget.projectName != null) sb.writeln('Project: ${widget.projectName}');
    if (widget.importFileCode != null) sb.writeln('${l.poReportImportFile}: ${DisplayNameResolver.resolveShipmentTitleByCode(widget.importFileCode, isArabic: Localizations.localeOf(context).languageCode == "ar")}');
    sb.writeln('----------------------------------------------------------------');
    sb.writeln('${l.poReportTotalInvoice}: ${totalAmount.toStringAsFixed(2)} ${widget.currency} (${(totalAmount * widget.exchangeRate).toStringAsFixed(2)} EGP)');
    sb.writeln('${l.poReportTotalPkgsAndPcs}: ${totalPackages.toStringAsFixed(0)} | ${l.poReportGrossWeight}: ${_formatWeight(effectiveGrossWeight)} kg | ${l.poReportNetWeight}: ${_formatWeight(totalNetWeight)} kg');
    sb.writeln('${l.poReportVolumeCbm}: ${effectiveCbm.toStringAsFixed(3)} m³ | ${l.poReportPalletPlan}: ${totalPallets > 0 ? "$totalPallets ${l.poReportPalletsCountUnit(totalPallets)}" : "None"}');
    sb.writeln('================================================================\n');

    sb.writeln('--- ${l.poReportSec1InvoiceItems} ---');
    sb.writeln('# | ${l.poReportColItemCode} | ${l.mainDescription} | ${l.poReportColDescription} | ${l.poReportColHsCode} | ${l.poReportColQtyUnit} | ${l.poReportColUnitPrice} | ${l.poReportColTotalAmount}');
    for (int i = 0; i < widget.items.length; i++) {
      final it = widget.items[i];
      final itemTot = it.totalPrice > 0 ? it.totalPrice : (it.quantity * it.unitPrice);
      final desc = isArabic ? it.descriptionAr : (it.descriptionEn?.isNotEmpty == true ? it.descriptionEn! : it.descriptionAr);
      final mainDesc = it.mainDescription?.isNotEmpty == true ? it.mainDescription! : "-";
      sb.writeln('${i + 1} | ${it.itemCode ?? "-"} | $mainDesc | $desc | ${it.hsCode ?? "-"} | ${it.quantity} ${it.unitOfMeasure} | ${it.unitPrice.toStringAsFixed(2)} ${widget.currency} | ${itemTot.toStringAsFixed(2)} ${widget.currency}');
    }

    sb.writeln('\n--- ${l.poReportSec2PackingList} ---');
    sb.writeln('# | ${l.poReportColItemCode} | ${l.mainDescription} | ${l.poReportColDescription} | ${l.poReportColPkgType} | ${l.poReportTotalPkgsAndPcs} | ${l.poReportColDimensions} | ${l.poReportGrossWeight} | ${l.poReportVolumeCbm}');
    for (int i = 0; i < widget.packingItems.length; i++) {
      final p = widget.packingItems[i];
      final dim = (p.lengthCm > 0 && p.widthCm > 0 && p.heightCm > 0) ? '${p.lengthCm}x${p.widthCm}x${p.heightCm}' : l.poReportDirectVolume;
      final grs = p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : p.grossWeightUnitKg * p.qtyPkg;
      String mainDesc = p.mainDescription ?? '';
      if (mainDesc.isEmpty) {
        final matchedItem = widget.items.where((it) => it.itemCode != null && it.itemCode == p.itemCode).firstOrNull;
        if (matchedItem != null && matchedItem.mainDescription?.isNotEmpty == true) {
          mainDesc = matchedItem.mainDescription!;
        }
      }
      sb.writeln('${i + 1} | ${p.itemCode} | ${mainDesc.isNotEmpty ? mainDesc : "-"} | ${p.description ?? "-"} | ${p.packageType} | ${p.qtyPkg}/${p.qtyPcs} | $dim | ${_formatWeight(grs)} kg | ${p.calculatedCbm.toStringAsFixed(3)} m³');
    }

    if (widget.palletItems.isNotEmpty) {
      sb.writeln('\n--- ${l.poReportSec3PalletPlan} ---');
      sb.writeln('# | ${l.palletTypeCol} | ${l.palletCountCol} | ${l.palletDimensionsCol} | ${l.palletWeightCol} | ${l.palletVolumeCol} | ${l.palletStackingInstructionsCol}');
      for (int i = 0; i < widget.palletItems.length; i++) {
        final pal = widget.palletItems[i];
        sb.writeln('${i + 1} | ${pal.palletType} | ${pal.palletCount} | ${pal.lengthCm}x${pal.widthCm}x${pal.heightCm} | ${pal.totalWeightKg} kg | ${pal.calculatedCbm.toStringAsFixed(3)} m³ | ${pal.isStackable ? l.poReportStackableYes : l.poReportStackableNo}');
      }
    }

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.poReportCopiedToClipboard),
        backgroundColor: AppTheme.cobalt,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPoVisualLoadPlannerDialog(BuildContext context, AppLocalizations l) {
    if (widget.packingItems.isEmpty && widget.palletItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.enterPackingOrPalletsNotice)),
      );
      return;
    }

    final hasPallets = widget.palletItems.isNotEmpty && widget.palletItems.any((p) => p.palletCount > 0);
    List<CargoItem> cargoItems = [];

    if (widget.isDirectVolumeMode || hasPallets) {
      final double totalGross = widget.packingItems.fold<double>(
        0.0,
        (sum, p) => sum + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.qtyPkg * p.grossWeightUnitKg)),
      );
      final int totalPallets = widget.palletItems.fold<int>(0, (sum, p) => sum + p.palletCount);
      final double defaultPalletWeight = totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

      int globalIdx = 1;
      for (final pLine in widget.palletItems) {
        final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
        final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
        final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
        final pWt = pLine.grossWeightPerPalletKg > 0 ? pLine.grossWeightPerPalletKg : defaultPalletWeight;

        for (int i = 0; i < pLine.palletCount; i++) {
          cargoItems.add(CargoItem(
            itemId: 'PLT-$globalIdx',
            length: pL,
            width: pW,
            height: pH,
            weight: pWt,
            isStackable: pLine.isStackable,
            rotate: true,
            packageType: pLine.palletType,
            description: 'بالتة #$globalIdx (${pLine.palletType})${pLine.isStackable ? "" : " [Floor Only]"}',
          ));
          globalIdx++;
        }
      }
    } else {
      int globalIdx = 1;
      for (final p in widget.packingItems) {
        final lCm = p.unit == 'mm' ? p.lengthCm / 10.0 : (p.unit == 'm' ? p.lengthCm * 100.0 : p.lengthCm);
        final wCm = p.unit == 'mm' ? p.widthCm / 10.0 : (p.unit == 'm' ? p.widthCm * 100.0 : p.widthCm);
        final hCm = p.unit == 'mm' ? p.heightCm / 10.0 : (p.unit == 'm' ? p.heightCm * 100.0 : p.heightCm);
        final int count = p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1;
        final double unitGrossWt = p.grossWeightUnitKg > 0
            ? p.grossWeightUnitKg
            : (p.totalGrossWeightKg > 0 ? (p.totalGrossWeightKg / count) : 10.0);

        for (int i = 0; i < count; i++) {
          cargoItems.add(CargoItem(
            itemId: '$globalIdx',
            length: lCm > 0 ? lCm : 100.0,
            width: wCm > 0 ? wCm : 80.0,
            height: hCm > 0 ? hCm : 60.0,
            weight: unitGrossWt,
            isStackable: p.isStackable,
            rotate: true,
            packageType: p.packageType,
            description: count > 1 ? '${p.itemCode} (طرد ${i + 1}/$count)' : p.itemCode,
          ));
          globalIdx++;
        }
      }
    }

    if (cargoItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.enterPackingOrPalletsNotice)),
      );
      return;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final GlobalKey previewPlannerRepaintKey = GlobalKey();
    final displayName = 'PO ${widget.poNumber}';
    bool isTopView = true;
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final plan = ContainerRequirementEngine.planShipment(
              cargoItems,
              forceStackable: activeStackingMode,
              forceOrientation: activeOrientationMode,
            );

            final totalPkgs = cargoItems.length;
            final stackableInActive = activeStackingMode == true
                ? totalPkgs
                : (activeStackingMode == false ? 0 : cargoItems.where((c) => c.isStackable).length);
            final nonStackableInActive = totalPkgs - stackableInActive;
            final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
            final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

            final Map<String, int> containerCounts = {};
            for (final p in plan) {
              if (p.containerCode != 'FAILED') {
                containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
              }
            }

            final fleetSummary = containerCounts.isEmpty
                ? 'لا توجد حاويات مناسبة'
                : containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: 1180,
                height: 780,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.view_in_ar_rounded, color: AppTheme.cobalt, size: 26),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.containerLoadPlan3dTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                                ),
                                Text(
                                  l.containerLoadPlan3dSubtitle,
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image_outlined, color: AppTheme.cobalt),
                              tooltip: isArabic ? 'تنزيل صور المحاكاة (PNG)' : 'Download Simulation Image (PNG)',
                              onPressed: () async {
                                await ContainerLoadPlanExportService.exportSimulationImage(
                                  context: dialogCtx,
                                  repaintKey: previewPlannerRepaintKey,
                                  displayName: '$displayName - 3D Simulation',
                                  isArabic: isArabic,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                              tooltip: isArabic ? 'تنزيل مخطط التحميل (PDF)' : 'Download Loading Plan (PDF)',
                              onPressed: () async {
                                await ContainerLoadPlanExportService.exportLoadingPlanPdf(
                                  context: dialogCtx,
                                  repaintKey: previewPlannerRepaintKey,
                                  displayName: displayName,
                                  poNumber: widget.poNumber,
                                  companyName: widget.companyName,
                                  supplierName: widget.supplierName,
                                  plan: plan,
                                  fleetSummary: fleetSummary,
                                  totalPlanWeight: totalPlanWeight,
                                  totalPlanVolume: totalPlanVolume,
                                  totalPkgs: totalPkgs,
                                  isArabic: isArabic,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(l.stackingSimulationModeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal)),
                            const SizedBox(width: 10),
                            SegmentedButton<int>(
                              segments: [
                                ButtonSegment(value: 0, label: Text(l.smartHybridOption)),
                                ButtonSegment(value: 1, label: Text(l.flatOnlyOption)),
                                ButtonSegment(value: 2, label: Text(l.simulationModeFloorOnly)),
                                ButtonSegment(value: 3, label: Text(l.simulationModeActualMixed)),
                              ],
                              selected: {
                                activeStackingMode == false ? 2 : (activeStackingMode == null ? 3 : (activeOrientationMode == CargoOrientationPreference.smartHybrid ? 0 : 1))
                              },
                              onSelectionChanged: (val) {
                                setDialogState(() {
                                  final sel = val.first;
                                  if (sel == 0) {
                                    activeOrientationMode = CargoOrientationPreference.smartHybrid;
                                    activeStackingMode = true;
                                  } else if (sel == 1) {
                                    activeOrientationMode = CargoOrientationPreference.flatOnly;
                                    activeStackingMode = true;
                                  } else if (sel == 2) {
                                    activeStackingMode = false;
                                  } else if (sel == 3) {
                                    activeStackingMode = null;
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 20),
                            Text(l.projectionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal)),
                            const SizedBox(width: 8),
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(value: true, label: Text(l.topViewProjection)),
                                ButtonSegment(value: false, label: Text(l.sideViewProjection)),
                              ],
                              selected: {isTopView},
                              onSelectionChanged: (val) {
                                setDialogState(() => isTopView = val.first);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoal.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.charcoal.withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
                              const SizedBox(width: 6),
                              Text(l.requiredContainersSummary(fleetSummary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, color: AppTheme.charcoal, size: 18),
                              const SizedBox(width: 6),
                              Text(l.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
                              const SizedBox(width: 6),
                              Text(l.totalWeightSummary(_formatWeight(totalPlanWeight)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
                              const SizedBox(width: 6),
                              Text(l.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: RepaintBoundary(
                        key: previewPlannerRepaintKey,
                        child: ListView.builder(
                        itemCount: plan.length,
                        itemBuilder: (ctx, pIdx) {
                          final res = plan[pIdx];
                          if (res.containerCode == 'FAILED') {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      res.failureReason ?? l.packingFailureTitle,
                                      style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final spacePct = (res.totalVolume / res.spec.internalVolumeCbm * 100);
                          final weightPct = (res.totalWeight / res.spec.maxPayloadKg * 100);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          context.l10n.containerCardHeader(pIdx + 1, res.spec.code, res.placedItems.length, spacePct.toStringAsFixed(1), weightPct.toStringAsFixed(1)),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.cobalt),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cobalt.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          context.l10n.internalDimensionsLabel(res.spec.internalLength.toStringAsFixed(0), res.spec.internalWidth.toStringAsFixed(0), res.spec.internalHeight.toStringAsFixed(0)),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 380,
                                    child: CustomPaint(
                                      size: const Size(double.infinity, 380),
                                      painter: ContainerLoadPlanPainter(
                                        plan: res,
                                        isTopView: isTopView,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: Text(
                                        context.l10n.placedPackagesTableTitle(res.placedItems.length),
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                      ),
                                      children: [
                                        Table(
                                          border: TableBorder.all(color: Colors.grey.shade300),
                                          columnWidths: const {
                                            0: FlexColumnWidth(0.8),
                                            1: FlexColumnWidth(2.2),
                                            2: FlexColumnWidth(1.8),
                                            3: FlexColumnWidth(1.2),
                                            4: FlexColumnWidth(2.0),
                                            5: FlexColumnWidth(1.2),
                                          },
                                          children: [
                                            TableRow(
                                              decoration: BoxDecoration(color: Colors.grey.shade200),
                                              children: [
                                                const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thPackageCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thDimensions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thCoordinates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thStacking, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                              ],
                                            ),
                                            ...res.placedItems.asMap().entries.map((entry) {
                                              final idx = entry.key + 1;
                                              final item = entry.value;
                                              return TableRow(
                                                children: [
                                                  Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(item.item.description ?? item.item.itemId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text('${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(_formatWeight(item.item.weight), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text('X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'), textAlign: TextAlign.center)),
                                                  Padding(padding: const EdgeInsets.all(6), child: Text(item.item.isStackable ? context.l10n.stackableOption : context.l10n.nonStackableOption, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                                ],
                                              );
                                            }),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                     ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

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

class _DataCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final Color? color;
  final TextAlign align;

  const _DataCell(this.text, {this.isBold = false, this.color, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color? cellColor = color;
    if (isDark) {
      if (cellColor == null || cellColor == AppTheme.charcoal || cellColor == Colors.black87) {
        cellColor = AppTheme.darkTextPrimary;
      } else if (cellColor == Colors.black54) {
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
          color: cellColor ?? Colors.black87,
        ),
      ),
    );
  }
}

