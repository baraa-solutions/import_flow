import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../settlement_ui.dart';

/// Overrides & Recalculate Panel for Estimated Landed Cost simulation
class EstLandedCostOverridesPanel extends StatelessWidget {
  final TextEditingController fxRateController;
  final TextEditingController freightController;
  final TextEditingController insuranceController;
  final TextEditingController clearanceController;
  final TextEditingController portController;
  final TextEditingController transportController;
  final TextEditingController bankFeesController;
  final TextEditingController otherFeesController;
  final String selectedAllocation;
  final ValueChanged<String> onAllocationChanged;
  final VoidCallback onReset;
  final VoidCallback onRecalculate;

  const EstLandedCostOverridesPanel({
    super.key,
    required this.fxRateController,
    required this.freightController,
    required this.insuranceController,
    required this.clearanceController,
    required this.portController,
    required this.transportController,
    required this.bankFeesController,
    required this.otherFeesController,
    required this.selectedAllocation,
    required this.onAllocationChanged,
    required this.onReset,
    required this.onRecalculate,
  });

  static Widget _buildOverrideField(
    String label,
    TextEditingController ctrl,
    String hint,
  ) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ExpansionTile(
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.all(12),
      backgroundColor: SettlementTokens.panelFill,
      collapsedBackgroundColor: SettlementTokens.panelFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        side: BorderSide(color: SettlementTokens.border),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        side: BorderSide(color: SettlementTokens.border),
      ),
      leading: const Icon(Icons.tune, color: AppTheme.cobalt, size: 20),
      title: Text(
        l10n.settlementEstOverridesTitle,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        l10n.settlementEstOverridesSubtitle,
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildOverrideField(l10n.settlementEstFxLabel, fxRateController, l10n.settlementEstFxHint),
            _buildOverrideField(l10n.settlementEstFreightLabel, freightController, l10n.settlementEstFreightHint),
            _buildOverrideField(l10n.settlementEstInsuranceLabel, insuranceController, l10n.settlementEstInsuranceHint),
            _buildOverrideField(l10n.settlementEstClearanceLabel, clearanceController, '4500'),
            _buildOverrideField(l10n.settlementEstPortLabel, portController, '5000'),
            _buildOverrideField(l10n.settlementEstTransportLabel, transportController, '7500'),
            _buildOverrideField(l10n.settlementEstBankLabel, bankFeesController, '2500'),
            _buildOverrideField(l10n.settlementEstOtherLabel, otherFeesController, '2000'),
            SizedBox(
              width: 220,
              child: SearchableDropdownField<String>(
                key: const Key('estimatedLandedCostAllocationDropdown'),
                value: selectedAllocation,
                labelText: l10n.financialSettlementAllocationRuleLabel,
                searchHintText: l10n.financialSettlementAllocationRuleSearchHint,
                items: [
                  SearchableDropdownItem(value: 'Value-Based', label: l10n.financialSettlementRuleValueBased),
                  SearchableDropdownItem(value: 'Weight-Based', label: l10n.financialSettlementRuleWeightBased),
                  SearchableDropdownItem(value: 'Volume-Based', label: l10n.financialSettlementRuleVolumeBased),
                ],
                onChanged: (val) {
                  if (val != null) onAllocationChanged(val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            SettlementFit(
              child: AppButton(
                label: l10n.settlementEstResetDefaults,
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: onReset,
              ),
            ),
            SettlementFit(
              child: AppButton(
                label: l10n.settlementEstRecalculate,
                icon: Icons.play_arrow,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: onRecalculate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
