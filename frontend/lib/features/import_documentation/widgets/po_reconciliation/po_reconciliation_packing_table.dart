import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../purchase_orders/utils/po_packing_matcher.dart';
import '../../models/import_documentation_model.dart';
import '../idoc_ui.dart';
import 'po_reconciliation_items_table.dart';

/// Line-by-line comparison table between PO and Packing List.
/// Displays package types, counts, weights (gross & net), and volume (CBM).
class PoReconciliationPackingTable extends StatelessWidget {
  final List<POReconciliationItemModel> packingItems;
  final DisplayDensityMode density;
  final ValueChanged<POReconciliationItemModel> onCloneItem;
  final void Function(int index, String packageType) onPackageTypeChanged;
  final void Function(int index, double finalPackages) onPackagesCountChanged;
  final void Function(int index, double finalGross) onGrossWeightChanged;
  final void Function(int index, double finalNet) onNetWeightChanged;
  final void Function(int index, double finalCbm) onCbmChanged;
  final VoidCallback onCopyTable;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;

  const PoReconciliationPackingTable({
    super.key,
    required this.packingItems,
    required this.density,
    required this.onCloneItem,
    required this.onPackageTypeChanged,
    required this.onPackagesCountChanged,
    required this.onGrossWeightChanged,
    required this.onNetWeightChanged,
    required this.onCbmChanged,
    required this.onCopyTable,
    required this.onExportExcel,
    required this.onExportPdf,
  });

  static String _formatWeight(double val) => PoPackingMatcher.formatWeight(val);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

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
                    const Icon(Icons.inventory, color: AppTheme.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.poRecPackingSectionTitle,
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
                      key: const Key('copyPackingItemsBtn'),
                      label: l.copyPoReconBtn,
                      icon: Icons.copy,
                      variant: AppButtonVariant.secondary,
                      onPressed: packingItems.isEmpty ? null : onCopyTable,
                    )),
                    IdocUi.fit(AppButton(
                      key: const Key('exportPackingItemsExcelBtn'),
                      label: l.exportPoReconExcelBtn,
                      icon: Icons.table_view_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: packingItems.isEmpty ? null : onExportExcel,
                    )),
                    IdocUi.fit(AppButton(
                      key: const Key('exportPackingItemsPdfBtn'),
                      label: l.exportPoReconPdfBtn,
                      icon: Icons.picture_as_pdf_outlined,
                      variant: AppButtonVariant.danger,
                      onPressed: packingItems.isEmpty ? null : onExportPdf,
                    )),
                  ],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 10),
                    actionsWidget,
                  ],
                );
              },
            ),
            const Divider(height: 20),
            if (packingItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    l.poRecSelectFileToViewPackingItems,
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
                    DataColumn(label: Text(l.poRecColPackageType)),
                    DataColumn(label: Text(l.poRecColPoPackagesCount)),
                    DataColumn(label: Text(l.poRecColFinalPackagesCount)),
                    DataColumn(label: Text(l.poRecColPkgVariance)),
                    DataColumn(label: Text(l.poRecColGrossWeight)),
                    DataColumn(label: Text(l.poRecColNetWeight)),
                    DataColumn(label: Text(l.poRecColCbm)),
                  ],
                  rows: [
                    ...packingItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final itm = entry.value;
                      final double initPkgs = itm.initialPackagesCount;
                      final double finPkgs = itm.finalPackagesCount;
                      final double pkgVarPct =
                          initPkgs > 0 ? ((finPkgs - initPkgs) / initPkgs) * 100.0 : 0.0;
                      final rowSummary = [
                        itm.itemCode,
                        itm.packageType,
                        '${initPkgs.toInt() == initPkgs ? initPkgs.toInt() : initPkgs}',
                        '${finPkgs.toInt() == finPkgs ? finPkgs.toInt() : finPkgs}',
                        '${pkgVarPct.toStringAsFixed(1)}%',
                        '${itm.finalGrossWeightKg}',
                        '${itm.finalNetWeightKg}',
                        '${itm.finalCbm}',
                      ].join('\t');

                      return DataRow(cells: [
                        DataCell(
                          IconButton(
                            key: Key('clonePackingItemRowBtn_${itm.itemCode}'),
                            icon: const Icon(Icons.copy, size: 16, color: AppTheme.orange),
                            tooltip: l.clonePoReconRecordTooltip,
                            onPressed: () => onCloneItem(itm),
                          ),
                        ),
                        DataCell(CopyableTableCell(
                          value: itm.itemCode,
                          rowSummary: rowSummary,
                          child: Text(itm.itemCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                        )),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              key: ValueKey('pl_pkg_type_${idx}_${itm.itemCode}'),
                              initialValue: itm.packageType,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                              onChanged: (val) => onPackageTypeChanged(idx, val),
                            ),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: '${initPkgs.toInt() == initPkgs ? initPkgs.toInt() : initPkgs}',
                            rowSummary: rowSummary,
                            child: Text(
                              '${initPkgs.toInt() == initPkgs ? initPkgs.toInt() : initPkgs}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.textPrimaryOf(context),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 85,
                            child: TextFormField(
                              key: ValueKey('pl_pkg_count_${idx}_${itm.itemCode}'),
                              initialValue: '${finPkgs.toInt() == finPkgs ? finPkgs.toInt() : finPkgs}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) onPackagesCountChanged(idx, parsed);
                              },
                            ),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: '${pkgVarPct.toStringAsFixed(1)}%',
                            rowSummary: rowSummary,
                            child: PoReconciliationItemsTable.buildVarianceBadge(pkgVarPct),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              key: ValueKey('pl_gross_wt_${idx}_${itm.itemCode}'),
                              initialValue: '${itm.finalGrossWeightKg}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) onGrossWeightChanged(idx, parsed);
                              },
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              key: ValueKey('pl_net_wt_${idx}_${itm.itemCode}'),
                              initialValue: '${itm.finalNetWeightKg}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) onNetWeightChanged(idx, parsed);
                              },
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 85,
                            child: TextFormField(
                              key: ValueKey('pl_cbm_${idx}_${itm.itemCode}'),
                              initialValue: '${itm.finalCbm}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6)),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null) onCbmChanged(idx, parsed);
                              },
                            ),
                          ),
                        ),
                      ]);
                    }),
                    if (packingItems.isNotEmpty) ...[
                      () {
                        final totalPoPkgs = packingItems.fold(0.0, (s, i) => s + i.initialPackagesCount);
                        final totalPkgs = packingItems.fold(0.0, (s, i) => s + i.finalPackagesCount);
                        final totalGross = packingItems.fold(0.0, (s, i) => s + i.finalGrossWeightKg);
                        final totalNet = packingItems.fold(0.0, (s, i) => s + i.finalNetWeightKg);
                        final totalCbmVal = packingItems.fold(0.0, (s, i) => s + i.finalCbm);
                        final overallPkgVar =
                            totalPoPkgs > 0 ? ((totalPkgs - totalPoPkgs) / totalPoPkgs) * 100.0 : 0.0;

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
                              context.l10n.idocAItemsCount(packingItems.length),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            )),
                            DataCell(Text(
                              '${totalPoPkgs.toStringAsFixed(0)} ${l.poRecPackagesUnit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryOf(context),
                                fontSize: 13,
                              ),
                            )),
                            DataCell(Text(
                              '${totalPkgs.toStringAsFixed(0)} ${l.poRecPackagesUnit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13),
                            )),
                            DataCell(PoReconciliationItemsTable.buildVarianceBadge(overallPkgVar)),
                            DataCell(Text(
                              '${_formatWeight(totalGross)} ${l.poRecKgUnit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 13),
                            )),
                            DataCell(Text(
                              '${_formatWeight(totalNet)} ${l.poRecKgUnit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13),
                            )),
                            DataCell(Text(
                              '${totalCbmVal.toStringAsFixed(3)} ${l.poRecCbmUnit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange, fontSize: 13),
                            )),
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
