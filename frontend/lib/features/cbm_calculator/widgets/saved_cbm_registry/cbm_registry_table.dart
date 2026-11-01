import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/cbm_calculator_model.dart';

/// Desktop & tablet data table for CBM registry records.
class CbmRegistryTable extends StatelessWidget {
  final List<CBMCalculationModel> calculations;
  final List<ImportFileModel> importFiles;
  final void Function(CBMCalculationModel calc) onView;
  final void Function(CBMCalculationModel calc) onEdit;
  final void Function(CBMCalculationModel calc) onClone;
  final void Function(CBMCalculationModel calc) onPrint;
  final void Function(CBMCalculationModel calc) onDelete;

  const CbmRegistryTable({
    super.key,
    required this.calculations,
    required this.importFiles,
    required this.onView,
    required this.onEdit,
    required this.onClone,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
        child: Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 48,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
              horizontalMargin: 16,
              columnSpacing: 18,
              dividerThickness: 0.5,
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
              ),
              headingTextStyle: const TextStyle(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: 168,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: AppTheme.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.actionsCol,
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataColumn(label: Text(l.calcCodeCol)),
                DataColumn(label: Text(l.importFileIdLabel)),
                DataColumn(label: Text(l.calculationSessionTitle)),
                DataColumn(label: Text(l.totalCbmVolumeMetric)),
                DataColumn(label: Text(l.volumetricWeight)),
                DataColumn(label: Text(l.grossWeightMetric)),
                DataColumn(label: Text(l.stackingCol)),
                DataColumn(label: Text(l.shippingStrategyCol)),
                DataColumn(label: Text(l.recommendedContainerCol)),
                DataColumn(label: Text(l.linkPoProjectCol)),
              ],
              rows: calculations.asMap().entries.map((entry) {
                final idx = entry.key;
                final calc = entry.value;
                final isEven = idx.isEven;
                final rowColor = !calc.isActive
                    ? (isDark
                        ? AppTheme.crimson.withValues(alpha: 0.3)
                        : AppTheme.crimsonLight)
                    : isEven
                        ? (isDark
                            ? AppTheme.darkCardBackground
                            : AppTheme.white)
                        : (isDark
                            ? AppTheme.darkElevatedSurface
                            : AppTheme.charcoalSurface);

                return DataRow(
                  color: WidgetStateProperty.all(rowColor),
                  onSelectChanged: (_) => onView(calc),
                  cells: [
                    // 1. Actions Pill
                    DataCell(
                      RowActionsPill(
                        onView: () => onView(calc),
                        onEdit: () => onEdit(calc),
                        onClone: () => onClone(calc),
                        cloneTooltip: l.cloneRowTooltip,
                        onPrint: () => onPrint(calc),
                        onDelete: () => onDelete(calc),
                        viewTooltip: l.viewDetails,
                        editTooltip: l.edit,
                        printTooltip: l.exportPdf,
                        deleteTooltip: calc.isActive ? l.delete : l.restore,
                      ),
                    ),

                    // 2. Calc Code
                    DataCell(
                      CopyableTableCell(
                        value: calc.calcCode,
                        rowSummary:
                            '${calc.calcCode} | ${calc.importFileCode ?? "—"} | ${calc.title ?? ""} | ${calc.totalCbm.toStringAsFixed(3)} m³ | ${calc.airChargeableWeightKg.toStringAsFixed(1)} kg | ${calc.totalGrossWeightKg.toStringAsFixed(1)} kg',
                        child: InkWell(
                          onTap: () => onView(calc),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.cobalt.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!calc.isActive)
                                  const Padding(
                                    padding: EdgeInsetsDirectional.only(end: 4),
                                    child: Icon(
                                      Icons.block,
                                      size: 12,
                                      color: AppTheme.crimson,
                                    ),
                                  ),
                                Text(
                                  calc.calcCode,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: calc.isActive
                                        ? AppTheme.cobalt
                                        : AppTheme.crimson,
                                    fontSize: 12,
                                    decoration: calc.isActive
                                        ? TextDecoration.none
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. Import File
                    () {
                      final rawFileCode = calc.importFileCode ??
                          (calc.importFileId != null
                              ? 'IMP-${calc.importFileId}'
                              : null);
                      final resolvedShipmentTitle = rawFileCode != null
                          ? DisplayNameResolver.resolveShipmentTitleByCode(
                              rawFileCode,
                              shipments: importFiles,
                              isArabic: isAr,
                            )
                          : null;
                      return DataCell(
                        CopyableTableCell(
                          value: resolvedShipmentTitle != null
                              ? '$resolvedShipmentTitle ($rawFileCode)'
                              : (rawFileCode ?? '—'),
                          rowSummary: calc.calcCode,
                          child: rawFileCode == null
                              ? const Text(
                                  '—',
                                  style: TextStyle(color: AppTheme.textMuted),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (resolvedShipmentTitle != null &&
                                        resolvedShipmentTitle != rawFileCode)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Text(
                                          resolvedShipmentTitle,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                            color: isDark
                                                ? AppTheme.darkTextPrimary
                                                : AppTheme.charcoal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            rawFileCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.cobalt,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => CopyHelper.copy(
                                            context,
                                            rawFileCode,
                                            customMessage:
                                                '${l.importFile}: $rawFileCode',
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: const Padding(
                                            padding: EdgeInsets.all(2.0),
                                            child: Icon(
                                              Icons.copy_rounded,
                                              size: 10,
                                              color: AppTheme.cobalt,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      );
                    }(),

                    // 4. Title
                    DataCell(
                      CopyableTableCell(
                        value: calc.title ?? l.calculationSessionTitle,
                        rowSummary: calc.calcCode,
                        child: SizedBox(
                          width: 180,
                          child: Text(
                            calc.title ?? l.calculationSessionTitle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 5. Volume CBM
                    DataCell(
                      CopyableTableCell(
                        value: '${calc.totalCbm.toStringAsFixed(3)} m³',
                        rowSummary: calc.calcCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.orangeLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.orange),
                          ),
                          child: Text(
                            '${calc.totalCbm.toStringAsFixed(3)} m³',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.wcagOrange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 6. Air Chargeable Weight
                    DataCell(
                      CopyableTableCell(
                        value:
                            '${calc.airChargeableWeightKg.toStringAsFixed(1)} kg',
                        rowSummary: calc.calcCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cobaltLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${calc.airChargeableWeightKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.wcagCobalt,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 7. Gross Weight
                    DataCell(
                      CopyableTableCell(
                        value:
                            '${calc.totalGrossWeightKg.toStringAsFixed(1)} kg',
                        rowSummary: calc.calcCode,
                        child: Text(
                          '${calc.totalGrossWeightKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    // 8. Stacking
                    DataCell(
                      CopyableTableCell(
                        value: calc.isStackable
                            ? l.cbmStackingAccepts
                            : l.cbmStackingRejects,
                        rowSummary: calc.calcCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: calc.isStackable
                                ? AppTheme.emeraldLight
                                : AppTheme.crimsonLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: calc.isStackable
                                  ? AppTheme.emeraldBorder
                                  : AppTheme.crimsonBorder,
                            ),
                          ),
                          child: Text(
                            calc.isStackable
                                ? l.cbmStackingAccepts
                                : l.cbmStackingRejects,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: calc.isStackable
                                  ? AppTheme.wcagEmerald
                                  : AppTheme.crimson,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 9. Shipping Recommendation
                    DataCell(
                      CopyableTableCell(
                        value: calc.shippingMethodLabel(l),
                        rowSummary: calc.calcCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cobaltLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            calc.shippingMethodLabel(l),
                            style: const TextStyle(
                              color: AppTheme.cobalt,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 10. Container Suggestion
                    DataCell(
                      CopyableTableCell(
                        value: calc.containerTypeLabel(l),
                        rowSummary: calc.calcCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.orangeLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            calc.containerTypeLabel(l),
                            style: const TextStyle(
                              color: AppTheme.wcagOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 11. Linked PO / Project
                    DataCell(
                      CopyableTableCell(
                        value: calc.poNumber != null
                            ? l.cbmSessionLinkedPo(calc.poNumber!)
                            : calc.projectName != null
                                ? calc.projectName!
                                : l.cbmNotLinked,
                        rowSummary: calc.calcCode,
                        child: Text(
                          calc.poNumber != null
                              ? l.cbmSessionLinkedPo(calc.poNumber!)
                              : calc.projectName != null
                                  ? calc.projectName!
                                  : l.cbmNotLinked,
                          style: TextStyle(
                            color: calc.poNumber != null
                                ? AppTheme.emerald
                                : AppTheme.textMuted,
                            fontWeight: calc.poNumber != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
