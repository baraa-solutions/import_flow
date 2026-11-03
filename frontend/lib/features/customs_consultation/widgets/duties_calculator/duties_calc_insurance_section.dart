import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Marine insurance valuation parameters container.
class DutiesCalcInsuranceSection extends StatelessWidget {
  final String insuranceOption;
  final ValueChanged<String> onInsuranceOptionChanged;
  final TextEditingController insuranceEgpController;

  const DutiesCalcInsuranceSection({
    super.key,
    required this.insuranceOption,
    required this.onInsuranceOptionChanged,
    required this.insuranceEgpController,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final egpLabel = l.financialSettlementCurrencyEgp;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.orange.withValues(alpha: 0.12)
            : AppTheme.orangeLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.orange.withValues(alpha: 0.3) : AppTheme.orange,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.security,
                color: AppTheme.orange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.estimatedCustomsInsuranceRateLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: '0.5%',
                    label: Text(l.standardCustomsInsuranceRate),
                  ),
                  const ButtonSegment(value: '1.0%', label: Text('1.0%')),
                  ButtonSegment(
                    value: 'Custom',
                    label: Text(l.customInsuranceRate),
                  ),
                ],
                selected: {insuranceOption},
                onSelectionChanged: (set) {
                  onInsuranceOptionChanged(set.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              SizedBox(
                width: 320,
                child: TextFormField(
                  controller: insuranceEgpController,
                  readOnly: insuranceOption != 'Custom',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${l.insuranceEgpLabel} ($egpLabel)',
                    border: const OutlineInputBorder(),
                    filled: insuranceOption != 'Custom',
                    fillColor: insuranceOption != 'Custom'
                        ? (isDark
                            ? AppTheme.darkElevatedSurface
                            : AppTheme.charcoalSurface)
                        : null,
                    helperText: insuranceOption != 'Custom'
                        ? l.autoCalculatedCandFInsuranceHelper(
                            insuranceOption,
                          )
                        : null,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: l.copyTooltip,
                      onPressed: () {
                        if (insuranceEgpController.text.isNotEmpty) {
                          CopyHelper.copy(
                            context,
                            insuranceEgpController.text,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
