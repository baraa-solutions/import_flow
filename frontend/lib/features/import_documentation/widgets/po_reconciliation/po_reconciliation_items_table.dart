import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../idoc_ui.dart';

/// Line-by-line comparison table between Purchase Order and Commercial Invoice.
/// Displays item codes, descriptions, quantities, unit prices, HS codes, and variances.
class PoReconciliationItemsTable extends StatelessWidget {
  final List<POReconciliationItemModel> invoiceItems;
  final String currencyStr;
  final DisplayDensityMode density;
  final ValueChanged<POReconciliationItemModel> onCloneItem;
  final void Function(int index, double finalQty) onQuantityChanged;
  final void Function(int index, double finalPrice) onPriceChanged;
  final void Function(int index, String hsCode) onHsCodeChanged;
  final VoidCallback onCopyTable;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onResetToOriginal;

  const PoReconciliationItemsTable({
    super.key,
    required this.invoiceItems,
    required this.currencyStr,
    required this.density,
    required this.onCloneItem,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onHsCodeChanged,
    required this.onCopyTable,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onResetToOriginal,
  });

  static Widget buildVarianceBadge(double variance) {
    if (variance.abs() < 0.01) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.emerald.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '0.0%',
          style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }
    final isPos = variance > 0;
    final color = isPos ? AppTheme.orange : AppTheme.crimson;
    final text = '${isPos ? "+" : ""}${variance.toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final totalAmount = invoiceItems.fold(
      0.0,
      (s, itm) => s + (itm.finalQuantity * (itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice)),
    );

    return Card(
      elevation: 2,
      color: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final titleWidget = Row(
                  children: [
                    const Icon(Icons.receipt, color: AppTheme.cobalt),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.poRecInvoiceSectionTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ),
                  ],
                );

                final actionsWidget = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IdocUi.fit(AppButton(
                      key: const Key('copyInvoiceItemsBtn'),
                      label: l.copyPoReconBtn,
                      icon: Icons.copy,
                      variant: AppButtonVariant.secondary,
                      onPressed: invoiceItems.isEmpty ? null : onCopyTable,
                    )),
                    IdocUi.fit(AppButton(
                      key: const Key('exportInvoiceItemsExcelBtn'),
                      label: l.exportPoReconExcelBtn,
                      icon: Icons.table_view_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: invoiceItems.isEmpty ? null : onExportExcel,
                    )),
                    IdocUi.fit(AppButton(
                      key: const Key('exportInvoiceItemsPdfBtn'),
                      label: l.exportPoReconPdfBtn,
                      icon: Icons.picture_as_pdf_outlined,
                      variant: AppButtonVariant.danger,
                      onPressed: invoiceItems.isEmpty ? null : onExportPdf,
                    )),
                    IdocUi.fit(AppButton(
                      label: l.poRecResetToOriginalValuesButton,
                      icon: Icons.restart_alt,
                      variant: AppButtonVariant.secondary,
                      onPressed: onResetToOriginal,
                    )),
                  ],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    actionsWidget,
                  ],
                );
              },
            ),
            const Divider(height: 20),
            if (invoiceItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    l.poRecSelectFileToViewPoItems,
                    style: TextStyle(color: AppTheme.textMutedOf(context)),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dataRowMinHeight: density.tableRowHeight - 4,
                  dataRowMaxHeight: density.tableRowHeight + 6,
                  headingRowHeight: density.tableHeadingHeight,
                  columnSpacing: density.byDensity<double>(16, 12, 10),
                  horizontalMargin: density.byDensity<double>(16, 12, 8),
                  columns: [
                    DataColumn(label: Text(l.actions, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text(l.poRecColItemCode)),
                    DataColumn(label: Text(l.poRecColDescription)),
                    DataColumn(label: Text(l.poRecColPoQty)),
                    DataColumn(label: Text(l.poRecColFinalQty)),
                    DataColumn(label: Text(l.poRecColQtyVariance)),
                    DataColumn(label: Text(l.poRecColPoUnitPrice)),
                    DataColumn(label: Text(l.poRecColFinalUnitPrice)),
                    DataColumn(label: Text(l.poRecColPriceVariance)),
                    DataColumn(label: Text(l.poRecColFinalTotal)),
                    DataColumn(label: Text(l.poRecColHsCode)),
                  ],
                  rows: [
                    ...invoiceItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final itm = entry.value;
                      final double initQty = itm.initialQuantity;
                      final double finQty = itm.finalQuantity;
                      final double initPrice = itm.initialUnitPrice;
                      final double finPrice = itm.finalUnitPrice > 0 ? itm.finalUnitPrice : itm.unitPrice;
                      final double qtyVariancePct = initQty > 0 ? ((finQty - initQty) / initQty) * 100.0 : 0.0;
                      final double priceVariancePct =
                          initPrice > 0 ? ((finPrice - initPrice) / initPrice) * 100.0 : 0.0;
                      final double totalRow = finQty * finPrice;
                      final rowSummary = [
                        itm.itemCode,
                        itm.description,
                        '$initQty',
                        '$finQty',
                        '${qtyVariancePct.toStringAsFixed(1)}%',
                        '$initPrice',
                        '$finPrice',
                        '${priceVariancePct.toStringAsFixed(1)}%',
                        '${totalRow.toStringAsFixed(2)} $currencyStr',
                        itm.hsCode ?? '',
                      ].join('\t');

                      return DataRow(cells: [
                        DataCell(
                          IconButton(
                            key: Key('cloneInvoiceItemRowBtn_${itm.itemCode}'),
                            icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                            tooltip: l.clonePoReconRecordTooltip,
                            onPressed: () => onCloneItem(itm),
                          ),
                        ),
                        DataCell(CopyableTableCell(
                          value: itm.itemCode,
                          rowSummary: rowSummary,
                          child: Text(itm.itemCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                        )),
                        DataCell(CopyableTableCell(
                          value: itm.description,
                          rowSummary: rowSummary,
                          child: SizedBox(
                            width: 160,
                            child: Text(itm.description, overflow: TextOverflow.ellipsis),
                          ),
                        )),
                        DataCell(CopyableTableCell(
                          value: '$initQty',
                          rowSummary: rowSummary,
                          child: Text('$initQty'),
                        )),
                        DataCell(
                          SizedBox(
                            width: 85,
                            child: TextFormField(
                              key: ValueKey('inv_qty_${idx}_${itm.itemCode}'),
                              initialValue: '$finQty',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) onQuantityChanged(idx, parsed);
                              },
                            ),
                          ),
                        ),
                        DataCell(CopyableTableCell(
                          value: '${qtyVariancePct.toStringAsFixed(1)}%',
                          rowSummary: rowSummary,
                          child: buildVarianceBadge(qtyVariancePct),
                        )),
                        DataCell(CopyableTableCell(
                          value: '$initPrice',
                          rowSummary: rowSummary,
                          child: Text('$initPrice'),
                        )),
                        DataCell(
                          SizedBox(
                            width: 85,
                            child: TextFormField(
                              key: ValueKey('inv_price_${idx}_${itm.itemCode}'),
                              initialValue: '$finPrice',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) onPriceChanged(idx, parsed);
                              },
                            ),
                          ),
                        ),
                        DataCell(CopyableTableCell(
                          value: '${priceVariancePct.toStringAsFixed(1)}%',
                          rowSummary: rowSummary,
                          child: buildVarianceBadge(priceVariancePct),
                        )),
                        DataCell(CopyableTableCell(
                          value: '${totalRow.toStringAsFixed(2)} $currencyStr',
                          rowSummary: rowSummary,
                          child: Text(
                            '${totalRow.toStringAsFixed(2)} $currencyStr',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                          ),
                        )),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              key: ValueKey('inv_hs_${idx}_${itm.itemCode}'),
                              initialValue: itm.hsCode ?? '',
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                              onChanged: (val) => onHsCodeChanged(idx, val),
                            ),
                          ),
                        ),
                      ]);
                    }),
                    if (invoiceItems.isNotEmpty) ...[
                      () {
                        final totalPoQty = invoiceItems.fold(0.0, (s, i) => s + i.initialQuantity);
                        final totalFinQty = invoiceItems.fold(0.0, (s, i) => s + i.finalQuantity);
                        final totalPoAmt =
                            invoiceItems.fold(0.0, (s, i) => s + (i.initialQuantity * i.initialUnitPrice));
                        final overallQtyVarPct =
                            totalPoQty > 0 ? ((totalFinQty - totalPoQty) / totalPoQty) * 100.0 : 0.0;
                        final overallPriceVarPct =
                            totalPoAmt > 0 ? ((totalAmount - totalPoAmt) / totalPoAmt) * 100.0 : 0.0;

                        return DataRow(
                          color: WidgetStateProperty.all(
                            isDark ? AppTheme.textSecondaryOf(context).withValues(alpha: 0.2) : AppTheme.infoBackground,
                          ),
                          cells: [
                            const DataCell(SizedBox()),
                            DataCell(Text(
                              l.poRecTotalSummaryRow,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13),
                            )),
                            DataCell(Text(
                              '${invoiceItems.length} ${l.poRecPackagesUnit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            )),
                            DataCell(Text(
                              totalPoQty.toStringAsFixed(0),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            )),
                            DataCell(Text(
                              totalFinQty.toStringAsFixed(0),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13),
                            )),
                            DataCell(buildVarianceBadge(overallQtyVarPct)),
                            DataCell(Text(
                              '${totalPoAmt.toStringAsFixed(2)} $currencyStr',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            )),
                            const DataCell(Text('—', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(buildVarianceBadge(overallPriceVarPct)),
                            DataCell(Text(
                              '${totalAmount.toStringAsFixed(2)} $currencyStr',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                            )),
                            const DataCell(Text('—')),
                          ],
                        );
                      }(),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
