import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../currencies/models/currency_model.dart';

/// Ocean and air freight valuation section.
class ConsultationCalcFreightSection extends StatelessWidget {
  final TextEditingController freightForeignController;
  final String freightCurrency;
  final ValueChanged<String> onFreightCurrencyChanged;
  final TextEditingController freightExchangeRateController;
  final TextEditingController freightEgpController;
  final VoidCallback onRecalculateFreightEgp;
  final int? selectedImportFileId;
  final VoidCallback? onAutoFetchFreightFromScenarios;
  final List<CurrencyModel> currenciesList;

  const ConsultationCalcFreightSection({
    super.key,
    required this.freightForeignController,
    required this.freightCurrency,
    required this.onFreightCurrencyChanged,
    required this.freightExchangeRateController,
    required this.freightEgpController,
    required this.onRecalculateFreightEgp,
    this.selectedImportFileId,
    this.onAutoFetchFreightFromScenarios,
    required this.currenciesList,
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
            ? AppTheme.cobalt.withValues(alpha: 0.12)
            : AppTheme.cobaltLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppTheme.cobalt.withValues(alpha: 0.3)
              : AppTheme.cobaltBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_boat, color: AppTheme.cobalt, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.freightDataHeader,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
              ),
              if (selectedImportFileId != null &&
                  onAutoFetchFreightFromScenarios != null)
                AppButton(
                  label: l.fetchHighestFreightFromStudy,
                  icon: Icons.download,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onAutoFetchFreightFromScenarios,
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              final fAmount = TextFormField(
                controller: freightForeignController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.foreignFreightAmountLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l.copyTooltip,
                    onPressed: () {
                      if (freightForeignController.text.isNotEmpty) {
                        CopyHelper.copy(
                            context, freightForeignController.text);
                      }
                    },
                  ),
                ),
                onChanged: (_) => onRecalculateFreightEgp(),
              );

              final fCurr = SearchableDropdownField<String>(
                value: freightCurrency,
                labelText: l.freightCurrencyLabel,
                items: currenciesList.isNotEmpty
                    ? currenciesList
                        .map((c) => SearchableDropdownItem<String>(
                              value: c.currencyCode,
                              label: '${c.currencyCode} - ${c.currencyName}',
                            ))
                        .toList()
                    : const [
                        SearchableDropdownItem(value: 'USD', label: 'USD'),
                        SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                        SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                        SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                      ],
                onChanged: (v) {
                  if (v != null) onFreightCurrencyChanged(v);
                },
              );

              final fFx = TextFormField(
                controller: freightExchangeRateController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.freightFxRateLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.currency_exchange,
                      color: AppTheme.cobalt, size: 16),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l.copyTooltip,
                    onPressed: () {
                      if (freightExchangeRateController.text.isNotEmpty) {
                        CopyHelper.copy(
                            context, freightExchangeRateController.text);
                      }
                    },
                  ),
                ),
                onChanged: (_) => onRecalculateFreightEgp(),
              );

              final fEgp = TextFormField(
                controller: freightEgpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${l.freightEgpLabel} ($egpLabel)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money,
                      color: AppTheme.emerald, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: l.copyTooltip,
                    onPressed: () {
                      if (freightEgpController.text.isNotEmpty) {
                        CopyHelper.copy(context, freightEgpController.text);
                      }
                    },
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    fAmount,
                    const SizedBox(height: 8),
                    fCurr,
                    const SizedBox(height: 8),
                    fFx,
                    const SizedBox(height: 8),
                    fEgp,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: fAmount),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: fCurr),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: fFx),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: fEgp),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
