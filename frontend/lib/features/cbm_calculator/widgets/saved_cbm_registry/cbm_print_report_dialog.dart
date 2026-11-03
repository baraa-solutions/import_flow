import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_en.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/cbm_calculator_model.dart';

/// Printable report preview and CSV download dialog for a CBM calculation session.
class CbmPrintReportDialog extends StatelessWidget {
  final CBMCalculationModel calc;

  const CbmPrintReportDialog({
    super.key,
    required this.calc,
  });

  static void show(
    BuildContext context, {
    required CBMCalculationModel calc,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => CbmPrintReportDialog(calc: calc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : null,
        title: Row(
          children: [
            const Icon(Icons.print_outlined, color: AppTheme.emerald),
            const SizedBox(width: 8),
            Text(l.cbmPrintableReportTitle(calc.calcCode)),
          ],
        ),
        content: SizedBox(
          width: 780,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Official Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sorour Logistics ERP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.charcoal,
                            ),
                          ),
                          Text(
                            l.cbmCalculatorTitle,
                            style: const TextStyle(
                              color: AppTheme.cobalt,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.cbmCalculatorSubtitle,
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              calc.calcCode,
                              style: const TextStyle(
                                color: AppTheme.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.cbmCreationDate(calc.createdAt != null
                                ? calc.createdAt
                                    .toString()
                                    .substring(0, 10)
                                : DateTime.now()
                                    .toString()
                                    .substring(0, 10)),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 1.5),

                  // Session Metadata
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l.calculationSessionTitle}: ${calc.title ?? "-"}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextPrimary : null,
                          ),
                        ),
                      ),
                      if (calc.poNumber != null)
                        Text(
                          l.cbmSessionLinkedPo(calc.poNumber!),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emerald,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  if (calc.notes != null && calc.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.cbmCargoNotes(calc.notes!),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Summary Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkCardBackground
                          : AppTheme.charcoalSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.cloudWhite,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildReportStat(
                          l.totalCbmVolumeMetric,
                          '${calc.totalCbm.toStringAsFixed(4)} m³',
                          AppTheme.orange,
                          isDark,
                        ),
                        _buildReportStat(
                          l.airChargeableWtMetric,
                          '${calc.airChargeableWeightKg.toStringAsFixed(1)} kg',
                          AppTheme.cobalt,
                          isDark,
                        ),
                        _buildReportStat(
                          l.totalGrossWeightRegistryMetric,
                          '${calc.totalGrossWeightKg.toStringAsFixed(1)} kg',
                          AppTheme.cobalt,
                          isDark,
                        ),
                        _buildReportStat(
                          l.cargoStackingInstructions,
                          calc.isStackable
                              ? l.stackableOption
                              : l.nonStackableOption,
                          AppTheme.emerald,
                          isDark,
                        ),
                        _buildReportStat(
                          l.shippingStrategyCol,
                          calc.shippingMethodLabel(l),
                          AppTheme.cobalt,
                          isDark,
                        ),
                        _buildReportStat(
                          l.recommendedContainerCol,
                          calc.containerTypeLabel(l),
                          AppTheme.wcagOrange,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Package Details Table
                  Text(
                    l.packageMeasurementsTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextPrimary : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.textMuted,
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkCardBackground
                              : AppTheme.cloudWhite,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              '#',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              l.packageTypeCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              l.qtyCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              l.cbmPackageDimensionsCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              l.grossWtPerUnitCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              l.stackingCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              l.totalGrossWeightRegistryMetric,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              l.cbmVolumeMetric,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextPrimary : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...calc.items.asMap().entries.map(
                        (entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final lineGross =
                              item.quantity * item.grossWeightPerUnitKg;
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  item.packageType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '${item.quantity}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '${item.lengthCm}x${item.widthCm}x${item.heightCm}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '${item.grossWeightPerUnitKg} kg',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  item.isStackable
                                      ? l.stackableOption
                                      : l.nonStackableOption,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.isStackable
                                        ? AppTheme.wcagEmerald
                                        : AppTheme.crimson,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '${lineGross.toStringAsFixed(1)} kg',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppTheme.darkTextPrimary
                                        : null,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '${item.totalCbm.toStringAsFixed(4)} m³',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.orange,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l.cbmPrintDownloadCsvBtn,
            icon: Icons.download,
            variant: AppButtonVariant.success,
            onPressed: () {
              _downloadCalcCSV(context, calc);
            },
          ),
          AppButton(
            label: l.cbmPrintReportBtn,
            icon: Icons.print,
            variant: AppButtonVariant.primary,
            onPressed: () {
              _triggerReportPrint(context, calc);
            },
          ),
          AppButton(
            label: l.close,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildReportStat(
    String label,
    String val,
    Color color, [
    bool isDark = false,
  ]) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _downloadCalcCSV(
    BuildContext context,
    CBMCalculationModel calc,
  ) async {
    final l = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln(
      'Sorour Logistics ERP - Cargo Volume & Weight Measurement Report',
    );
    buffer.writeln('Calc Code,${calc.calcCode}');
    buffer.writeln('Title,${calc.title ?? ""}');
    buffer.writeln('Notes,${calc.notes ?? ""}');
    buffer.writeln('Total CBM,${calc.totalCbm}');
    buffer.writeln(
      'Air Chargeable Weight (kg),${calc.airChargeableWeightKg}',
    );
    buffer.writeln('Total Gross Weight (kg),${calc.totalGrossWeightKg}');
    buffer.writeln(
      'Shipment Mode,${calc.shipmentModeLabel(const AppLocalizationsEn())}',
    );
    buffer.writeln(
      'Shipping Recommendation,${calc.shippingMethodLabel(const AppLocalizationsEn())}',
    );
    buffer.writeln(
      'Cargo Stacking,${calc.isStackable ? "Stackable" : "Non-Stackable"}',
    );
    buffer.writeln('');
    buffer.writeln(
      'Pkg #,Package Type,Qty,Length (cm),Width (cm),Height (cm),Gross Wt/Unit (kg),Stacking,Line CBM (m3),Total Gross Wt (kg)',
    );

    for (int i = 0; i < calc.items.length; i++) {
      final item = calc.items[i];
      final lineGross = item.quantity * item.grossWeightPerUnitKg;
      buffer.writeln(
        '${i + 1},${item.packageType},${item.quantity},${item.lengthCm},${item.widthCm},${item.heightCm},${item.grossWeightPerUnitKg},${item.isStackable ? "Stackable" : "Non-Stackable"},${item.totalCbm},$lineGross',
      );
    }

    final filename =
        'Phase1_CBM_Measurement_Report_${calc.calcCode}_${DateTime.now().millisecondsSinceEpoch}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l.cbmDownloadCsvTitle,
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  void _triggerReportPrint(BuildContext context, CBMCalculationModel calc) {
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        l.cbmSendingReportToScreen(calc.calcCode),
        severity: AppSeverity.info,
      ),
    );
  }
}
