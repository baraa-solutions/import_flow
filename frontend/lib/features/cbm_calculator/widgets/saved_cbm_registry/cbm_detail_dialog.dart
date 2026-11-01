import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/cbm_calculator_model.dart';
import 'cbm_detail/cbm_detail_header_overview.dart';
import 'cbm_detail/cbm_dual_container_matrix.dart';
import 'cbm_detail/cbm_metrics_strip.dart';
import 'cbm_detail/cbm_packages_breakdown_table.dart';

/// Detailed view dialog for a saved CBM calculation session.
class CbmDetailDialog extends StatelessWidget {
  final CBMCalculationModel calc;
  final List<ImportFileModel> importFiles;
  final void Function(CBMCalculationModel calc) onLoadSession;
  final void Function(CBMCalculationModel calc) onEditMetadata;
  final void Function(CBMCalculationModel calc) onLinkPo;
  final void Function(CBMCalculationModel calc) onPrintReport;

  const CbmDetailDialog({
    super.key,
    required this.calc,
    required this.importFiles,
    required this.onLoadSession,
    required this.onEditMetadata,
    required this.onLinkPo,
    required this.onPrintReport,
  });

  static void show(
    BuildContext context, {
    required CBMCalculationModel calc,
    required List<ImportFileModel> importFiles,
    required void Function(CBMCalculationModel calc) onLoadSession,
    required void Function(CBMCalculationModel calc) onEditMetadata,
    required void Function(CBMCalculationModel calc) onLinkPo,
    required void Function(CBMCalculationModel calc) onPrintReport,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => CbmDetailDialog(
        calc: calc,
        importFiles: importFiles,
        onLoadSession: onLoadSession,
        onEditMetadata: onEditMetadata,
        onLinkPo: onLinkPo,
        onPrintReport: onPrintReport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rawFileCode = calc.importFileCode ??
        (calc.importFileId != null ? 'IMP-${calc.importFileId}' : null);
    final resolvedShipmentTitle = rawFileCode != null
        ? DisplayNameResolver.resolveShipmentTitleByCode(
            rawFileCode,
            shipments: importFiles,
            isArabic: isArabic,
          )
        : null;
    final containerRec = ContainerRequirementEngine.calculate(
      totalCbm: calc.totalCbm,
      totalWeightKg: calc.totalGrossWeightKg,
      isStackable: calc.isStackable,
    );
    final dualRec = ContainerRequirementEngine.calculateBoth(
      totalCbm: calc.totalCbm,
      totalWeightKg: calc.totalGrossWeightKg,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : null,
        title: Row(
          children: [
            const Icon(
              Icons.view_in_ar_rounded,
              color: AppTheme.cobalt,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.cbmSessionDetailsTitle(calc.calcCode),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
            ),
            AppStatusBadge(
              label: calc.isActive
                  ? l.cbmSessionActiveBadge
                  : l.cbmSessionCancelledBadge,
              severity: calc.isActive ? AppSeverity.success : AppSeverity.danger,
              size: AppStatusBadgeSize.small,
            ),
            const SizedBox(width: 8),
            AppStatusBadge(
              label: calc.poNumber != null
                  ? l.cbmSessionLinkedPo(calc.poNumber!)
                  : (rawFileCode != null
                      ? (resolvedShipmentTitle != null &&
                              resolvedShipmentTitle != rawFileCode
                          ? '$resolvedShipmentTitle ($rawFileCode)'
                          : l.cbmSessionImportFile(rawFileCode))
                      : l.cbmSessionStandalone),
              severity: AppSeverity.info,
              size: AppStatusBadgeSize.small,
            ),
          ],
        ),
        content: SizedBox(
          width: 920,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Overview Card
                CbmDetailHeaderOverview(
                  calc: calc,
                  rawFileCode: rawFileCode,
                  resolvedShipmentTitle: resolvedShipmentTitle,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // 2. Metrics Strip Cards Row
                CbmMetricsStrip(
                  calc: calc,
                  containerRec: containerRec,
                  isArabic: isArabic,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // 3. Dual Container Matrix Comparison Box
                CbmDualContainerMatrix(
                  calc: calc,
                  dualRec: dualRec,
                  isDark: isDark,
                ),
                const Divider(height: 24),

                // 4 & 5. Package Breakdown Section Header & Table of Packages
                CbmPackagesBreakdownTable(
                  calc: calc,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: l.cbmReopenInCalcBtn,
            icon: Icons.edit_note,
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.pop(context);
              onLoadSession(calc);
            },
          ),
          AppButton(
            label: l.cbmEditMetadataBtn,
            icon: Icons.edit,
            variant: AppButtonVariant.warning,
            onPressed: () {
              Navigator.pop(context);
              onEditMetadata(calc);
            },
          ),
          AppButton(
            label: l.cbmLinkToPoProjectBtn,
            icon: Icons.link,
            variant: AppButtonVariant.primary,
            onPressed: () {
              Navigator.pop(context);
              onLinkPo(calc);
            },
          ),
          AppButton(
            label: l.cbmPrintExportReportBtn,
            icon: Icons.print,
            variant: AppButtonVariant.success,
            onPressed: () {
              Navigator.pop(context);
              onPrintReport(calc);
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
}
