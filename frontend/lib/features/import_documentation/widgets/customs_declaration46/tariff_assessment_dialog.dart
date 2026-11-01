import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/customs_declaration_assessment.dart';
import '../../services/customs_declaration46_calculator.dart';
import '../form46_figures_panel.dart';
import '../idoc_ui_b.dart';

class TariffAssessmentDialog {
  static void show(
    BuildContext context, {
    required CustomsDeclarationAssessment assessment,
    required AppLocalizations l,
    required ValueChanged<CustomsDeclarationAssessment> onCloneDeclaration,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = l.isArabic;
    final miss = l.idocBMissing;

    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: IdocBDialogShell(
            title: l.customsDeclAssessmentTitle,
            subtitle: l.customsDeclAssessmentSubtitle,
            icon: Icons.analytics_outlined,
            badge: assessment.declarationNo,
            body: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!assessment.isComplete)
                    IdocBNotice(
                      key: const Key('assessmentMissingBanner'),
                      severity: AppSeverity.danger,
                      message: Form46FiguresPanel.missingItemsText(l, assessment.missing),
                    ),

                  // 1. Shipment particulars
                  IdocBSectionCard(
                    title: l.customsDeclShipmentParticularsHeader,
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      children: [
                        _buildAssessmentRow(context, l.customsDeclColDeclarationNo, assessment.declarationNo, isDark: isDark),
                        _buildAssessmentRow(context, l.customsDeclColFileNumber, assessment.primaryNameWithCode, isDark: isDark),
                        _buildAssessmentRow(context, l.customsDeclColSupplier, assessment.supplierName, isDark: isDark),
                        _buildAssessmentRow(context, l.customsDeclAcidNumberLabel, assessment.acidNumber, isDark: isDark),
                        _buildAssessmentRow(context, l.customsDeclForm4NumberLabel, assessment.form4Number, isDark: isDark),
                        _buildAssessmentRow(context, l.customsDeclBlNumberLabel, assessment.blNumber, isDark: isDark),
                      ],
                    ),
                  ),

                  // 2. Valuation breakdown (CIF)
                  IdocBSectionCard(
                    title: l.customsDeclValuationBreakdownHeader,
                    icon: Icons.calculate_outlined,
                    child: Column(
                      children: [
                        _buildAssessmentRow(
                          context,
                          l.customsDeclFobForeignLabel,
                          '${assessment.fobForeign.fixedOrMissing(2, miss)} ${assessment.currency} (${assessment.fobEgp.egpOrMissing(miss)})',
                          isDark: isDark,
                        ),
                        _buildAssessmentRow(
                          context,
                          l.customsDeclFreightEgpLabel,
                          assessment.freightEgp.egpOrMissing(miss),
                          isDark: isDark,
                        ),
                        _buildAssessmentRow(
                          context,
                          l.customsDeclInsuranceEgpLabel,
                          assessment.insuranceEgp.egpOrMissing(miss),
                          isDark: isDark,
                        ),
                        const Divider(),
                        _buildAssessmentRow(
                          context,
                          l.customsDeclCifTotalEgpLabel,
                          assessment.cifEgp.egpOrMissing(miss),
                          isBold: true,
                          valueColor: AppTheme.cobalt,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // 3. Tariff, duties and taxes
                  IdocBSectionCard(
                    title: l.customsDeclTariffTaxesHeader,
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _buildAssessmentRow(context, l.customsDeclColHsCode, '${assessment.hsCode} (${assessment.hsDescription})', isDark: isDark),
                        _buildAssessmentRow(
                          context,
                          '${l.customsDeclImportDutyRateLabel} (${assessment.dutyRate.fixedOrMissing(1, miss)}%)',
                          assessment.importDutyEgp.egpOrMissing(miss),
                          isDark: isDark,
                        ),
                        _buildAssessmentRow(
                          context,
                          '${l.customsDeclCustomsServicesFeeLabel} (${assessment.serviceRate.fixedOrMissing(1, miss)}%)',
                          assessment.serviceFeeEgp.egpOrMissing(miss),
                          isDark: isDark,
                        ),
                        if ((assessment.devRate ?? 0) > 0)
                          _buildAssessmentRow(
                            context,
                            '${l.customsDeclDevFeeLabel} (${assessment.devRate.fixedOrMissing(1, miss)}%)',
                            assessment.devFeeEgp.egpOrMissing(miss),
                            isDark: isDark,
                          ),
                        _buildAssessmentRow(context, l.customsDeclVatBaseLabel, assessment.vatBaseEgp.egpOrMissing(miss), isDark: isDark),
                        _buildAssessmentRow(
                          context,
                          '${l.customsDeclVatRateLabel} (${assessment.vatRate.fixedOrMissing(1, miss)}%)',
                          assessment.vatEgp.egpOrMissing(miss),
                          isDark: isDark,
                        ),
                        const Divider(),
                        _buildAssessmentRow(
                          context,
                          l.customsDeclTotalDutiesLabel,
                          assessment.totalDutiesEgp.egpOrMissing(miss),
                          isBold: true,
                          valueColor: AppTheme.crimson,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // 4. Exemption status
                  IdocBSectionCard(
                    title: l.customsDeclExemptionHeader,
                    icon: assessment.hasExemption ? Icons.verified : Icons.info_outline,
                    accent: assessment.hasExemption ? AppTheme.emerald : AppTheme.cobalt,
                    child: Row(
                      children: [
                        Icon(
                          assessment.hasExemption ? Icons.verified : Icons.info,
                          color: assessment.hasExemption ? AppTheme.emerald : AppTheme.cobalt,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            assessment.exemptionTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IdocBDialogAction(
                buttonKey: const Key('dialogCloneDeclBtn'),
                label: l.cloneCustomsDeclRowTooltip,
                icon: Icons.copy_all,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onCloneDeclaration(assessment);
                },
              ),
              IdocBDialogAction(
                label: l.customsDeclCloseDialog,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildAssessmentRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 450;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: isCompact ? 130 : 200,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: CopyableText(
                  value,
                  isSelectable: false,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: valueColor ?? AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
