import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../models/import_file_model.dart';
import '../sections/import_files_export_helper.dart';

/// Section 2: Merged Cargo Volumes, Financial Invoices & Linked POs Breakdown.
class MasterReportFinancialsCard extends StatelessWidget {
  final List<ImportFileModel> displayFiles;
  final List<PurchaseOrderModel> allPOs;
  final bool isDark;
  final void Function(ImportFileModel file, List<PurchaseOrderModel> linkedPOs) onSmartReference;
  final void Function(ImportFileModel file, List<PurchaseOrderModel> linkedPOs, double totalCbm, double totalWeight) onVisualLoadPlan;

  const MasterReportFinancialsCard({
    super.key,
    required this.displayFiles,
    required this.allPOs,
    required this.isDark,
    required this.onSmartReference,
    required this.onVisualLoadPlan,
  });

  Widget _buildMetricMiniCard(String title, String value, String sub, Color color) {
    return MetricCard(
      data: MetricCardData(
        title: title,
        value: value,
        tooltip: sub,
        icon: Icons.analytics_outlined,
        color: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 22),
            const SizedBox(width: 8),
            Text(
              '📦 ${l.cargoAndLinkedPosSection}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...displayFiles.map((file) {
          final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
          final metrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);
          final fileTotalCbm = metrics.cbm;
          final fileTotalWeight = metrics.weightKg;
          final totalPlCount = metrics.plCount;
          final invoiceNumbers = metrics.invoices;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBackground : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.cobalt.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Header & Summary Bar
                Row(
                  children: [
                    Text(
                      '${l.importFileIdLabel}: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    CopyableText(
                      '${DisplayNameResolver.resolveShipmentTitle(file, isArabic: isAr)} (${file.companyName})',
                      showIcon: false,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    const Spacer(),
                    AppStatusBadge.fromStatus(
                      status: file.status,
                      label: ImportFilesExportHelper.getStatusLabel(file.status, l),
                      size: AppStatusBadgeSize.small,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Summary Metric Cards
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.cobalt.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.cobalt.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricMiniCard(
                          '${l.invoicesCountAndNumbers} 📄',
                          '${invoiceNumbers.length} ${l.invoicesUnit}',
                          invoiceNumbers.isNotEmpty ? invoiceNumbers.join(', ') : '-',
                          AppTheme.cobalt,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricMiniCard(
                          '${l.totalCbmFromPackingList} 📐',
                          fileTotalCbm > 0 ? '${fileTotalCbm.toStringAsFixed(3)} m³' : '—',
                          l.cbmSumDescription,
                          AppTheme.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricMiniCard(
                          '${l.totalGrossWeightFromPl} 🏋️',
                          fileTotalWeight > 0 ? '${fileTotalWeight.toStringAsFixed(0)} kg' : '—',
                          l.grossWeightSumDescription,
                          AppTheme.emerald,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricMiniCard(
                          '${l.linkedPurchaseOrdersTitle} 🛍️',
                          '${linkedPOs.length} ${l.posUnit}',
                          '(${totalPlCount > 0 ? totalPlCount : linkedPOs.length} ${l.packingListsUnit})',
                          AppTheme.sorourNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Linked Purchase Orders Matrix
                if (linkedPOs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      l.noLinkedPosForFile,
                      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.08),
                      ),
                      headingTextStyle: TextStyle(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      columns: [
                        DataColumn(label: Text(l.purchaseOrder)),
                        DataColumn(label: Text(l.poInvoiceLabel)),
                        DataColumn(label: Text(l.foreignSupplier)),
                        DataColumn(label: Text(l.paymentTermsLabel)),
                        DataColumn(label: Text(l.totalCostMetric)),
                        DataColumn(label: Text(l.packingListItemsCol)),
                        DataColumn(label: Text(l.weightCbmCol)),
                        DataColumn(label: Text(l.status)),
                      ],
                      rows: linkedPOs.map((po) {
                        final double poPalletCbm = po.palletPlanItems.isNotEmpty
                            ? po.palletPlanItems.fold<double>(
                                0.0,
                                (s, p) =>
                                    s +
                                    (p.calculatedCbm > 0
                                        ? p.calculatedCbm
                                        : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount),
                              )
                            : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
                                ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
                                : 0.0);
                        final double poPalletGross = po.palletPlanItems.isNotEmpty
                            ? po.palletPlanItems.fold<double>(
                                0.0,
                                (s, p) => s + (p.grossWeightPerPalletKg * p.palletCount),
                              )
                            : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                        final int poPalletCount = po.palletPlanItems.isNotEmpty
                            ? po.palletPlanItems.fold<int>(0, (s, p) => s + p.palletCount)
                            : po.palletCount;

                        double poCbm = 0;
                        double poWt = 0;
                        if (poPalletCbm > 0) {
                          poCbm = poPalletCbm;
                          poWt = poPalletGross > 0 ? poPalletGross : (po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                        } else if (po.totalCbm > 0 && po.packingListItems.isEmpty) {
                          poCbm = po.totalCbm;
                          poWt = po.totalGrossWeightKg;
                        } else if (po.packingListItems.isNotEmpty) {
                          for (var pl in po.packingListItems) {
                            poCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
                            poWt += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
                          }
                        } else {
                          poCbm = po.totalCbm;
                          poWt = po.totalGrossWeightKg;
                        }

                        final String plText = poPalletCount > 0
                            ? '$poPalletCount ${l.palletsShippingPlan}'
                            : '${po.packingListItems.length} ${l.packingItemsCount}';

                        final poRowSummary =
                            '${po.poNumber}\t${po.proformaInvoiceNumber ?? "-"}\t${po.supplierName ?? file.supplierName}\t${po.paymentTerms ?? "-"}\t${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}\t$plText\t${poCbm.toStringAsFixed(3)} m³ / ${poWt.toStringAsFixed(0)} kg\t${po.status}';

                        return DataRow(
                          cells: [
                            DataCell(CopyableTableCell(
                              value: po.poNumber,
                              rowSummary: poRowSummary,
                              child: LtrText(
                                po.poNumber,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                              ),
                            )),
                            DataCell(CopyableTableCell(
                              value: po.proformaInvoiceNumber ?? '-',
                              rowSummary: poRowSummary,
                              child: Text(po.proformaInvoiceNumber ?? '-'),
                            )),
                            DataCell(CopyableTableCell(
                              value: po.supplierName ?? file.supplierName,
                              rowSummary: poRowSummary,
                              child: Text(po.supplierName ?? file.supplierName),
                            )),
                            DataCell(CopyableTableCell(
                              value: po.paymentTerms ?? '-',
                              rowSummary: poRowSummary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  po.paymentTerms ?? '-',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )),
                            DataCell(CopyableTableCell(
                              value: '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
                              rowSummary: poRowSummary,
                              child: Text(
                                '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                              ),
                            )),
                            DataCell(CopyableTableCell(
                              value: plText,
                              rowSummary: poRowSummary,
                              child: Text(plText),
                            )),
                            DataCell(CopyableTableCell(
                              value: '${poCbm.toStringAsFixed(3)} m³ / ${poWt.toStringAsFixed(0)} kg',
                              rowSummary: poRowSummary,
                              child: Text(
                                '${poCbm.toStringAsFixed(3)} m³ / ${poWt.toStringAsFixed(0)} kg',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                              ),
                            )),
                            DataCell(CopyableTableCell(
                              value: po.statusLabel(context.l10n),
                              rowSummary: poRowSummary,
                              child: AppStatusBadge.fromStatus(
                                status: po.status,
                                label: po.statusLabel(context.l10n),
                                size: AppStatusBadgeSize.small,
                              ),
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 12),

                // Card Footer Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: isAr ? 'المرجع الذكي للشحنة' : 'Smart Reference',
                      icon: Icons.auto_awesome,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: () => onSmartReference(file, linkedPOs),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: l.containerLoadPlanButton,
                      icon: Icons.view_in_ar,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      onPressed: () => onVisualLoadPlan(file, linkedPOs, fileTotalCbm, fileTotalWeight),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
