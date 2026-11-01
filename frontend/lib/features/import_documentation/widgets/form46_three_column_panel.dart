import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/smart_upload_button.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../services/customs_declaration46_calculator.dart';
import 'idoc_ui_b.dart';

/// Three-column comparison panel for Form 46:
/// - Column A: Study-Time Estimate (Read-only, calm container)
/// - Column B: Revised Estimate (Inputs for 4-5 variables with instant recalculation)
/// - Column C: Nafeza Actual (Organised actual fields with Smart Nafeza extraction)
class Form46ThreeColumnPanel extends StatelessWidget {
  const Form46ThreeColumnPanel({
    super.key,
    required this.studyFigures,
    required this.appliedTariff,
    // Column B controllers & callbacks
    required this.revisedFxRateCtrl,
    required this.approvedFreightCtrl,
    required this.actualInsuranceCtrl,
    required this.dischargeExpensesCtrl,
    required this.newCustomsFeesCtrl,
    required this.revisedCifCtrl,
    required this.revisedDutyCtrl,
    required this.revisedVatCtrl,
    required this.revisedOtherFeesCtrl,
    required this.revisedTotalDutiesCtrl,
    required this.onRevisedVariableChanged,
    // Column C controllers & callbacks
    required this.actualCifCtrl,
    required this.actualDutyCtrl,
    required this.actualVatCtrl,
    required this.actualOtherFeesCtrl,
    required this.actualTotalDutiesCtrl,
    required this.nafezaClaimNoCtrl,
    required this.nafezaClaimDateCtrl,
    required this.onActualComponentChanged,
    required this.onNafezaDataExtracted,
  });

  final Form46Figures? studyFigures;
  final CustomsTariffModel? appliedTariff;

  // Column B controllers
  final TextEditingController revisedFxRateCtrl;
  final TextEditingController approvedFreightCtrl;
  final TextEditingController actualInsuranceCtrl;
  final TextEditingController dischargeExpensesCtrl;
  final TextEditingController newCustomsFeesCtrl;
  final TextEditingController revisedCifCtrl;
  final TextEditingController revisedDutyCtrl;
  final TextEditingController revisedVatCtrl;
  final TextEditingController revisedOtherFeesCtrl;
  final TextEditingController revisedTotalDutiesCtrl;
  final VoidCallback onRevisedVariableChanged;

  // Column C controllers
  final TextEditingController actualCifCtrl;
  final TextEditingController actualDutyCtrl;
  final TextEditingController actualVatCtrl;
  final TextEditingController actualOtherFeesCtrl;
  final TextEditingController actualTotalDutiesCtrl;
  final TextEditingController nafezaClaimNoCtrl;
  final TextEditingController nafezaClaimDateCtrl;
  final VoidCallback onActualComponentChanged;
  final ValueChanged<Map<String, dynamic>> onNafezaDataExtracted;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panel Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined, color: AppTheme.cobalt, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.form46ThreeColumnComparisonTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.cobalt,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Panel Content: 3 responsive columns
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildColumnA(context, l)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildColumnB(context, l)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildColumnC(context, l)),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildColumnA(context, l),
                      const SizedBox(height: 20),
                      _buildColumnB(context, l),
                      const SizedBox(height: 20),
                      _buildColumnC(context, l),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Column A: Study-Time Estimate (Read-only, calm container)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildColumnA(BuildContext context, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sf = studyFigures;
    final tariff = appliedTariff;

    final dutyRateText = sf?.dutyRate != null ? '${sf!.dutyRate!.toStringAsFixed(1)}%' : (tariff != null ? '${tariff.customsDutyRate}%' : '—');
    final vatRateText = sf?.vatRate != null ? '${sf!.vatRate!.toStringAsFixed(1)}%' : (tariff != null ? '${tariff.vatRate}%' : '—');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInputBackground : AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _columnHeader(
            icon: Icons.history_edu_outlined,
            iconColor: AppTheme.charcoal,
            badgeColor: AppTheme.charcoal.withValues(alpha: 0.15),
            badgeText: 'Column A',
            title: l.form46ColStudyEstimate,
            subtitle: l.form46ColStudyEstimateSub,
          ),
          const SizedBox(height: 14),
          _readOnlyRow(context, l.customsDeclFxRateLabel, sf?.exchangeRate != null ? '${sf!.exchangeRate!.toStringAsFixed(4)} ${l.egpCurrency}' : l.idocBMissing),
          _readOnlyRow(context, l.customsDeclFobForeignLabel, sf?.fobForeign != null ? IdocBFormat.money(sf!.fobForeign!) : l.idocBMissing),
          _readOnlyRow(context, l.customsDeclCifValueLabel, sf?.cifEgp != null ? '${IdocBFormat.money(sf!.cifEgp!)} ${l.egpCurrency}' : l.idocBMissing),
          _readOnlyRow(context, '${l.customsDeclImportDutyLabel} ($dutyRateText)', sf?.importDutyEgp != null ? '${IdocBFormat.money(sf!.importDutyEgp!)} ${l.egpCurrency}' : l.idocBMissing),
          _readOnlyRow(context, '${l.customsDeclVatLabel} ($vatRateText)', sf?.vatEgp != null ? '${IdocBFormat.money(sf!.vatEgp!)} ${l.egpCurrency}' : l.idocBMissing),
          _readOnlyRow(context, l.customsDeclDevFeeLabel, sf?.otherFeesEgp != null ? '${IdocBFormat.money(sf!.otherFeesEgp!)} ${l.egpCurrency}' : '0.00 ${l.egpCurrency}'),
          const Divider(height: 20),
          _readOnlyTotalRow(
            context,
            l.customsDeclTotalDutiesLabel,
            sf?.totalDutiesEgp != null ? '${IdocBFormat.money(sf!.totalDutiesEgp!)} ${l.egpCurrency}' : l.idocBMissing,
            color: AppTheme.charcoal,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Column B: Revised Estimate (Operational inputs with instant recalculation)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildColumnB(BuildContext context, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInputBackground : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.cobalt.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _columnHeader(
            icon: Icons.calculate_outlined,
            iconColor: AppTheme.cobalt,
            badgeColor: AppTheme.cobalt.withValues(alpha: 0.12),
            badgeText: 'Column B',
            title: l.form46ColRevisedEstimate,
            subtitle: l.form46ColRevisedEstimateSub,
          ),
          const SizedBox(height: 12),
          // 4-5 Input Variables
          _inputField(
            context,
            fieldKey: const Key('form46RevisedFxRateField'),
            label: l.form46VarExchangeRate,
            controller: revisedFxRateCtrl,
            onChanged: (_) => onRevisedVariableChanged(),
            suffix: l.egpCurrency,
            icon: Icons.currency_exchange,
          ),
          const SizedBox(height: 8),
          _inputField(
            context,
            label: l.form46VarApprovedFreight,
            controller: approvedFreightCtrl,
            onChanged: (_) => onRevisedVariableChanged(),
            suffix: l.egpCurrency,
            icon: Icons.directions_boat_outlined,
          ),
          const SizedBox(height: 8),
          _inputField(
            context,
            label: l.form46VarActualInsurance,
            controller: actualInsuranceCtrl,
            onChanged: (_) => onRevisedVariableChanged(),
            suffix: l.egpCurrency,
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 8),
          _inputField(
            context,
            label: l.form46VarDischargeDemurrage,
            controller: dischargeExpensesCtrl,
            onChanged: (_) => onRevisedVariableChanged(),
            suffix: l.egpCurrency,
            icon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 8),
          _inputField(
            context,
            label: l.form46VarNewFees,
            controller: newCustomsFeesCtrl,
            onChanged: (_) => onRevisedVariableChanged(),
            suffix: l.egpCurrency,
            icon: Icons.add_circle_outline,
          ),
          const SizedBox(height: 12),
          // Derived Figures
          _readOnlyRow(context, l.customsDeclCifValueLabel, '${revisedCifCtrl.text} ${l.egpCurrency}'),
          _readOnlyRow(context, l.customsDeclImportDutyLabel, '${revisedDutyCtrl.text} ${l.egpCurrency}'),
          _readOnlyRow(context, l.customsDeclVatLabel, '${revisedVatCtrl.text} ${l.egpCurrency}'),
          _readOnlyRow(context, l.customsDeclDevFeeLabel, '${revisedOtherFeesCtrl.text} ${l.egpCurrency}'),
          const Divider(height: 20),
          _readOnlyTotalRow(
            context,
            l.customsDeclTotalDutiesLabel,
            '${revisedTotalDutiesCtrl.text} ${l.egpCurrency}',
            color: AppTheme.cobalt,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Column C: Nafeza Actual (Organised actual fields with Smart Nafeza extraction)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildColumnC(BuildContext context, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInputBackground : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.emerald.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _columnHeader(
                  icon: Icons.verified_outlined,
                  iconColor: AppTheme.emerald,
                  badgeColor: AppTheme.emerald.withValues(alpha: 0.12),
                  badgeText: 'Column C',
                  title: l.form46ColNafezaActual,
                  subtitle: l.form46ColNafezaActualSub,
                ),
              ),
              const SizedBox(width: 8),
              SmartUploadButton(
                module: SmartUploadModule.customsClearance,
                compact: true,
                label: l.form46SmartExtractNafezaBtn,
                onDataExtracted: (res) => onNafezaDataExtracted(res.extractedFields),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Claim info
          Row(
            children: [
              Expanded(
                child: _inputField(
                  context,
                  label: l.form46NafezaClaimNo,
                  controller: nafezaClaimNoCtrl,
                  icon: Icons.confirmation_number_outlined,
                  isNumeric: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _inputField(
                  context,
                  label: l.form46NafezaClaimDate,
                  controller: nafezaClaimDateCtrl,
                  icon: Icons.calendar_today_outlined,
                  isNumeric: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _inputField(
            context,
            label: l.form46ActualCif,
            controller: actualCifCtrl,
            onChanged: (_) => onActualComponentChanged(),
            suffix: l.egpCurrency,
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 8),
          _inputField(
            context,
            fieldKey: const Key('form46ActualDutyField'),
            label: l.form46ActualDuty,
            controller: actualDutyCtrl,
            onChanged: (_) => onActualComponentChanged(),
            suffix: l.egpCurrency,
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 8),
          _inputField(
            context,
            label: l.form46ActualVat,
            controller: actualVatCtrl,
            onChanged: (_) => onActualComponentChanged(),
            suffix: l.egpCurrency,
            icon: Icons.percent,
          ),
          const SizedBox(height: 8),
          _inputField(
            context,
            label: l.form46ActualOtherFees,
            controller: actualOtherFeesCtrl,
            onChanged: (_) => onActualComponentChanged(),
            suffix: l.egpCurrency,
            icon: Icons.payments_outlined,
          ),
          const Divider(height: 20),
          _readOnlyTotalRow(
            context,
            l.form46ActualTotalDuties,
            '${actualTotalDutiesCtrl.text} ${l.egpCurrency}',
            color: AppTheme.emerald,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sub-widgets & Helpers
  // ─────────────────────────────────────────────────────────────────────────
  Widget _columnHeader({
    required IconData icon,
    required Color iconColor,
    required Color badgeColor,
    required String badgeText,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _readOnlyRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedOf(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LtrText(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy, size: 13),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: context.l10n.customsDeclCopyValueTooltip,
                onPressed: () => CopyHelper.copy(context, value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _readOnlyTotalRow(BuildContext context, String label, String value, {required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LtrText(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: context.l10n.customsDeclCopyValueTooltip,
              onPressed: () => CopyHelper.copy(context, value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _inputField(
    BuildContext context, {
    Key? fieldKey,
    required String label,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
    String? suffix,
    IconData? icon,
    bool isNumeric = true,
  }) {
    final l = context.l10n;
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      textAlign: isNumeric ? TextAlign.end : TextAlign.start,
      textDirection: isNumeric ? TextDirection.ltr : null,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        prefixIcon: icon != null ? Icon(icon, size: 16) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        suffixText: suffix,
        suffixStyle: const TextStyle(fontSize: 11),
        suffixIcon: IconButton(
          icon: const Icon(Icons.copy, size: 14),
          tooltip: l.customsDeclCopyValueTooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => CopyHelper.copy(context, controller.text),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
