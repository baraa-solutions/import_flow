import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../currencies/models/currency_model.dart';

/// Valuation Parameters Row: Currency dropdown, Customs FX rate, and Study date picker.
class ConsultationCalcValuationParams extends StatelessWidget {
  final List<CurrencyModel> currenciesList;
  final String customsCurrency;
  final ValueChanged<String> onCustomsCurrencyChanged;
  final TextEditingController exchangeRateController;
  final VoidCallback onExchangeRateChanged;
  final DateTime studyDate;
  final ValueChanged<DateTime> onStudyDateChanged;

  const ConsultationCalcValuationParams({
    super.key,
    required this.currenciesList,
    required this.customsCurrency,
    required this.onCustomsCurrencyChanged,
    required this.exchangeRateController,
    required this.onExchangeRateChanged,
    required this.studyDate,
    required this.onStudyDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final currField = SearchableDropdownField<String>(
          value: customsCurrency,
          labelText: l.invoiceCurrencyLabel,
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
                  SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                  SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                ],
          onChanged: (v) {
            if (v != null) onCustomsCurrencyChanged(v);
          },
        );

        final fxField = TextFormField(
          controller: exchangeRateController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l.customsFxRateLabel,
            border: const OutlineInputBorder(),
            errorText: (double.tryParse(exchangeRateController.text.trim()) ??
                        0.0) <=
                    0
                ? l.customsFxRateRequired
                : null,
            prefixIcon: const Icon(Icons.currency_exchange,
                color: AppTheme.cobalt, size: 18),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: l.copyTooltip,
              onPressed: () {
                if (exchangeRateController.text.isNotEmpty) {
                  CopyHelper.copy(context, exchangeRateController.text);
                }
              },
            ),
          ),
          onChanged: (_) => onExchangeRateChanged(),
        );

        final dateField = InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: studyDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) onStudyDateChanged(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l.studyDateLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.calendar_today,
                  color: AppTheme.cobalt, size: 18),
            ),
            child: Text(
              '${studyDate.year}-${studyDate.month.toString().padLeft(2, '0')}-${studyDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            children: [
              currField,
              const SizedBox(height: 10),
              fxField,
              const SizedBox(height: 10),
              dateField,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: currField),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: fxField),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: dateField),
          ],
        );
      },
    );
  }
}
