import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/cargo_insurance_model.dart';
import 'insurance_form_controllers.dart';

class InsuranceCalculationColumn extends StatelessWidget {
  final InsuranceFormControllers controllers;
  final InsuranceCalculationResultModel? calculationPreview;
  final String? calcError;

  const InsuranceCalculationColumn({
    super.key,
    required this.controllers,
    this.calculationPreview,
    this.calcError,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final currency = controllers.currency;

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.insuranceSecBreakdownTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 12),

          if (calcError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(calcError!, style: const TextStyle(color: AppTheme.crimson, fontSize: 12)),
            ),
          if (calculationPreview != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderOf(context)),
                boxShadow: [
                  BoxShadow(color: AppTheme.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  _buildBreakdownRow(
                    l.insuranceBreakdownCifBase,
                    '${calculationPreview!.cifValue.toStringAsFixed(2)} $currency',
                    isBold: false,
                  ),
                  const Divider(height: 10),
                  _buildBreakdownRow(
                    l.insuranceBreakdownInsuredValue,
                    '${calculationPreview!.insuredValue.toStringAsFixed(2)} $currency',
                    isBold: true,
                    valueColor: AppTheme.cobalt,
                  ),
                  const Divider(height: 10),
                  _buildBreakdownRow(
                    l.insuranceBreakdownBasePremium((calculationPreview!.baseRate * 100).toStringAsFixed(2)),
                    '${calculationPreview!.basePremium.toStringAsFixed(2)} $currency',
                    isBold: false,
                  ),
                  if (controllers.includeWarAndStrikes) ...[
                    const SizedBox(height: 4),
                    _buildBreakdownRow(
                      l.insuranceBreakdownWarStrikes,
                      '+ ${calculationPreview!.warStrikesPremium.toStringAsFixed(2)} $currency',
                      isBold: false,
                      valueColor: AppTheme.orange,
                    ),
                  ],
                  const Divider(height: 10),
                  _buildBreakdownRow(
                    l.insuranceBreakdownNetPremium,
                    '${calculationPreview!.netPremium.toStringAsFixed(2)} $currency',
                    isBold: false,
                  ),
                  const SizedBox(height: 4),
                  _buildBreakdownRow(
                    l.insuranceBreakdownIssuanceFee,
                    '+ ${calculationPreview!.issuanceFee.toStringAsFixed(2)} $currency',
                    isBold: false,
                  ),
                  const SizedBox(height: 4),
                  _buildBreakdownRow(
                    l.insuranceBreakdownTaxes,
                    '+ ${calculationPreview!.taxAmount.toStringAsFixed(2)} $currency',
                    isBold: false,
                  ),
                  const Divider(height: 14, thickness: 1.5),
                  _buildBreakdownRow(
                    l.insuranceBreakdownTotalPayable,
                    '${calculationPreview!.totalPayablePremium.toStringAsFixed(2)} $currency',
                    isBold: true,
                    valueColor: AppTheme.emerald,
                    fontSize: 14,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Cargo Specifications
          Text(
            l.insuranceSecCargoSpecs,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controllers.goodsDescCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.insuranceFieldGoodsDesc,
              hintText: l.insuranceFieldGoodsDescHint,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers.packageCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.insuranceFieldPackagesCount,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controllers.grossWeightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l.insuranceFieldGrossWeight,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? valueColor, double fontSize = 12}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: AppTheme.charcoal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}
