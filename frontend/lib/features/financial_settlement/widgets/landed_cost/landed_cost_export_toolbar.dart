import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';
import '../../services/landed_cost_comparison_export_service.dart';
import '../settlement_ui.dart';

class LandedCostExportToolbar extends StatelessWidget {
  final String fileCode;
  final String incoterm;
  final double estimatedCost;
  final Map<String, dynamic>? settlementRecord;
  final double? landedVariance;
  final double? estimatedLandedCostEgp;

  const LandedCostExportToolbar({
    super.key,
    required this.fileCode,
    required this.incoterm,
    required this.estimatedCost,
    required this.settlementRecord,
    required this.landedVariance,
    required this.estimatedLandedCostEgp,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exportService = LandedCostComparisonExportService(
      context: context,
      fileCode: fileCode,
      incoterm: incoterm,
      estimatedCost: estimatedLandedCostEgp ?? estimatedCost,
      settlementRecord: settlementRecord,
      backendVariancePct: landedVariance,
      backendEstimatedLandedEgp: estimatedLandedCostEgp,
    );

    return SettlementPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SettlementFit(
            child: AppButton(
              label: l10n.landedCostExportTsvBtn,
              icon: Icons.table_chart_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => exportService.exportToTsv(),
            ),
          ),
          SettlementFit(
            child: AppButton(
              label: l10n.landedCostExportExcelBtn,
              icon: Icons.file_present_outlined,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: () => exportService.exportToExcel(),
            ),
          ),
          SettlementFit(
            child: AppButton(
              label: l10n.landedCostPrintPdfBtn,
              icon: Icons.picture_as_pdf_outlined,
              variant: AppButtonVariant.danger,
              size: AppButtonSize.small,
              onPressed: () => exportService.printOrSavePdf(),
            ),
          ),
          SettlementFit(
            child: AppButton(
              label: l10n.landedCostCopyDossierBtn,
              icon: Icons.copy_all,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: () => exportService.copyDossierToClipboard(),
            ),
          ),
        ],
      ),
    );
  }
}
