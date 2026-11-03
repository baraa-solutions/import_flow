import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class AdvancePaymentCalculationSection extends StatelessWidget {
  final double basePoAmount;
  final String currency;
  final TextEditingController amountController;
  final TextEditingController exchangeRateController;
  final double selectedPercentage;
  final bool isCustomPercentage;
  final List<double> standardPercentages;
  final bool isDark;
  final ValueChanged<double> onSelectPercentage;
  final VoidCallback onEnableCustomPercentage;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onExchangeRateChanged;

  const AdvancePaymentCalculationSection({
    super.key,
    required this.basePoAmount,
    required this.currency,
    required this.amountController,
    required this.exchangeRateController,
    required this.selectedPercentage,
    required this.isCustomPercentage,
    required this.standardPercentages,
    required this.isDark,
    required this.onSelectPercentage,
    required this.onEnableCustomPercentage,
    required this.onAmountChanged,
    required this.onExchangeRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
    final currentRate = double.tryParse(exchangeRateController.text.trim()) ?? 0.0;
    final totalEgp = currentAmount * currentRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Metric Card: PO Total FOB & Exchange Rate
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.faPoFobTotal,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${basePoAmount.toStringAsFixed(2)} $currency',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.orange : AppTheme.wcagOrange,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 36,
                width: 1,
                color: AppTheme.cloudWhite,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.faApprovedExchangeRate,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1 $currency = ${exchangeRateController.text} EGP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Advance Percentage Chips Selector
        Text(
          context.l10n.faAdvancePercentageLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...standardPercentages.map((pct) {
              final isSelected = !isCustomPercentage && selectedPercentage == pct;
              final isRecommended = pct == 30.0;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppTheme.white
                            : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                      ),
                    ),
                    if (isRecommended) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.white.withValues(alpha: 0.25)
                              : AppTheme.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.l10n.faCommon,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.white : AppTheme.wcagOrange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                selectedColor: AppTheme.wcagOrange,
                backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
                onSelected: (_) => onSelectPercentage(pct),
              );
            }),
            ChoiceChip(
              label: Text(
                context.l10n.faCustomPercent(selectedPercentage.toStringAsFixed(1)),
                style: TextStyle(
                  fontWeight: isCustomPercentage ? FontWeight.bold : FontWeight.normal,
                  color: isCustomPercentage
                      ? AppTheme.white
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                ),
              ),
              selected: isCustomPercentage,
              selectedColor: AppTheme.cobalt,
              backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
              onSelected: (selected) {
                if (selected) onEnableCustomPercentage();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Row: Foreign Amount & EGP Total Display
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.l10n.faAdvanceAmountLabel(currency),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: currency,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return context.l10n.faEnterPaymentAmount;
                  }
                  final parsed = double.tryParse(v);
                  if (parsed == null || parsed <= 0) {
                    return context.l10n.faAmountGreaterThanZero;
                  }
                  return null;
                },
                onChanged: onAmountChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                key: const ValueKey('advanceExchangeRateField'),
                controller: exchangeRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.l10n.faExchangeRateEgpLabel,
                  border: const OutlineInputBorder(),
                  suffixText: 'EGP',
                ),
                validator: (v) {
                  final r = double.tryParse((v ?? '').trim());
                  return (r == null || r <= 0)
                      ? context.l10n.faExchangeRateInvalid
                      : null;
                },
                onChanged: (_) => onExchangeRateChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // EGP Live Conversion Result Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.emerald.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.emerald.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.currency_exchange,
                size: 18,
                color: AppTheme.emerald,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.faEquivalentInEgp,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${totalEgp.toStringAsFixed(2)} ${context.l10n.faCurrencyEgpShort}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
