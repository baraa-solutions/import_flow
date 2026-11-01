import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../currencies/providers/currencies_provider.dart';

class EstimatedBudgetCategoryCard extends ConsumerWidget {
  final bool isMobile;
  final String invoiceCurrency;
  final String freightCurrency;
  final TextEditingController invoiceForeignController;
  final TextEditingController invoiceEgpController;
  final TextEditingController exchangeRateController;
  final TextEditingController freightForeignController;
  final TextEditingController freightEgpController;
  final TextEditingController freightRateController;
  final TextEditingController customsEgpController;
  final TextEditingController clearanceEgpController;
  final TextEditingController notesController;
  final ValueChanged<String?> onInvoiceCurrencyChanged;
  final ValueChanged<String?> onFreightCurrencyChanged;
  final VoidCallback onValuesChanged;
  final FormFieldValidator<String>? validateExchangeRate;
  final FormFieldValidator<String>? validateFreightExchangeRate;

  const EstimatedBudgetCategoryCard({
    super.key,
    required this.isMobile,
    required this.invoiceCurrency,
    required this.freightCurrency,
    required this.invoiceForeignController,
    required this.invoiceEgpController,
    required this.exchangeRateController,
    required this.freightForeignController,
    required this.freightEgpController,
    required this.freightRateController,
    required this.customsEgpController,
    required this.clearanceEgpController,
    required this.notesController,
    required this.onInvoiceCurrencyChanged,
    required this.onFreightCurrencyChanged,
    required this.onValuesChanged,
    this.validateExchangeRate,
    this.validateFreightExchangeRate,
  });

  Widget _buildInvoiceCurrencyDropdown(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    return SearchableDropdownField<String>(
      value: invoiceCurrency,
      labelText: '${l.invoiceCurrencyLabel} *',
      searchHintText: l.search,
      items: () {
        final curList = ref.watch(currenciesProvider).valueOrNull ?? [];
        final list = curList.isNotEmpty
            ? curList
                .map((c) => SearchableDropdownItem<String>(
                      value: c.currencyCode,
                      label: '${c.currencyCode} - ${c.currencyName}',
                    ))
                .toList()
            : [
                const SearchableDropdownItem(value: 'USD', label: 'USD'),
                const SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                const SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                const SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                const SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                const SearchableDropdownItem(value: 'SAR', label: 'SAR'),
                const SearchableDropdownItem(value: 'AED', label: 'AED'),
              ];
        if (!list.any((i) => i.value == invoiceCurrency)) {
          list.add(SearchableDropdownItem(
              value: invoiceCurrency, label: invoiceCurrency));
        }
        return list;
      }(),
      onChanged: onInvoiceCurrencyChanged,
    );
  }

  Widget _buildFreightCurrencyDropdown(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    return SearchableDropdownField<String>(
      value: freightCurrency,
      labelText: '${l.freightCurrencyLabel} *',
      searchHintText: l.search,
      items: () {
        final curList = ref.watch(currenciesProvider).valueOrNull ?? [];
        final list = curList.isNotEmpty
            ? curList
                .map((c) => SearchableDropdownItem<String>(
                      value: c.currencyCode,
                      label: '${c.currencyCode} - ${c.currencyName}',
                    ))
                .toList()
            : [
                const SearchableDropdownItem(value: 'USD', label: 'USD'),
                const SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                const SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                const SearchableDropdownItem(value: 'GBP', label: 'GBP'),
                const SearchableDropdownItem(value: 'CNY', label: 'CNY'),
                const SearchableDropdownItem(value: 'SAR', label: 'SAR'),
                const SearchableDropdownItem(value: 'AED', label: 'AED'),
              ];
        if (!list.any((i) => i.value == freightCurrency)) {
          list.add(SearchableDropdownItem(
              value: freightCurrency, label: freightCurrency));
        }
        return list;
      }(),
      onChanged: onFreightCurrencyChanged,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          _buildInvoiceCurrencyDropdown(context, ref, l),
          const SizedBox(height: 12),
          TextFormField(
            controller: invoiceForeignController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${l.estimatedInvoiceValue} ($invoiceCurrency)',
              border: const OutlineInputBorder(),
              fillColor:
                  isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
              filled: isDark,
            ),
            onChanged: (v) {
              final f = double.tryParse(v) ?? 0;
              final r = double.tryParse(exchangeRateController.text) ?? 0;
              invoiceEgpController.text = (f * r).toStringAsFixed(2);
              onValuesChanged();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: exchangeRateController,
            keyboardType: TextInputType.number,
            validator: validateExchangeRate,
            decoration: InputDecoration(
              labelText: '${l.exchangeRateLabel} (EGP)',
              border: const OutlineInputBorder(),
              fillColor:
                  isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
              filled: isDark,
            ),
            onChanged: (v) {
              final r = double.tryParse(v) ?? 0;
              final inv = double.tryParse(invoiceForeignController.text) ?? 0;
              invoiceEgpController.text = (inv * r).toStringAsFixed(2);
              onValuesChanged();
            },
          ),
          const SizedBox(height: 12),
          _buildFreightCurrencyDropdown(context, ref, l),
          const SizedBox(height: 12),
          TextFormField(
            controller: freightForeignController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${l.estimatedFreightCost} ($freightCurrency)',
              border: const OutlineInputBorder(),
              fillColor:
                  isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
              filled: isDark,
            ),
            onChanged: (v) {
              final f = double.tryParse(v) ?? 0;
              final r = double.tryParse(freightRateController.text) ?? 0;
              freightEgpController.text = (f * r).toStringAsFixed(2);
              onValuesChanged();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: freightRateController,
            keyboardType: TextInputType.number,
            validator: validateFreightExchangeRate,
            decoration: InputDecoration(
              labelText: '${l.freightExchangeRateLabel} (EGP)',
              border: const OutlineInputBorder(),
              fillColor:
                  isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
              filled: isDark,
            ),
            onChanged: (v) {
              final r = double.tryParse(v) ?? 0;
              final frt = double.tryParse(freightForeignController.text) ?? 0;
              freightEgpController.text = (frt * r).toStringAsFixed(2);
              onValuesChanged();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: customsEgpController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${l.customsAndVatEstimate} (EGP)',
              border: const OutlineInputBorder(),
              fillColor:
                  isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
              filled: isDark,
            ),
            onChanged: (_) => onValuesChanged(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: clearanceEgpController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${l.clearanceAndTransportEstimate} (EGP)',
              border: const OutlineInputBorder(),
              fillColor:
                  isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
              filled: isDark,
            ),
            onChanged: (_) => onValuesChanged(),
          ),
        ] else ...[
          // Row A: Invoice Currency, Value & Exchange Rate
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInvoiceCurrencyDropdown(context, ref, l),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: invoiceForeignController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${l.estimatedInvoiceValue} ($invoiceCurrency)',
                    border: const OutlineInputBorder(),
                    fillColor:
                        isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                    filled: isDark,
                  ),
                  onChanged: (v) {
                    final f = double.tryParse(v) ?? 0;
                    final r = double.tryParse(exchangeRateController.text) ?? 0;
                    invoiceEgpController.text = (f * r).toStringAsFixed(2);
                    onValuesChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: exchangeRateController,
                  keyboardType: TextInputType.number,
                  validator: validateExchangeRate,
                  decoration: InputDecoration(
                    labelText: '${l.exchangeRateLabel} (EGP)',
                    border: const OutlineInputBorder(),
                    fillColor:
                        isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                    filled: isDark,
                  ),
                  onChanged: (v) {
                    final r = double.tryParse(v) ?? 0;
                    final inv =
                        double.tryParse(invoiceForeignController.text) ?? 0;
                    invoiceEgpController.text = (inv * r).toStringAsFixed(2);
                    onValuesChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row B: Freight Currency, Cost & Freight Rate
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildFreightCurrencyDropdown(context, ref, l),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: freightForeignController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${l.estimatedFreightCost} ($freightCurrency)',
                    border: const OutlineInputBorder(),
                    fillColor:
                        isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                    filled: isDark,
                  ),
                  onChanged: (v) {
                    final f = double.tryParse(v) ?? 0;
                    final r =
                        double.tryParse(freightRateController.text) ?? 0;
                    freightEgpController.text = (f * r).toStringAsFixed(2);
                    onValuesChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: freightRateController,
                  keyboardType: TextInputType.number,
                  validator: validateFreightExchangeRate,
                  decoration: InputDecoration(
                    labelText: '${l.freightExchangeRateLabel} (EGP)',
                    border: const OutlineInputBorder(),
                    fillColor:
                        isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                    filled: isDark,
                  ),
                  onChanged: (v) {
                    final r = double.tryParse(v) ?? 0;
                    final frt =
                        double.tryParse(freightForeignController.text) ?? 0;
                    freightEgpController.text = (frt * r).toStringAsFixed(2);
                    onValuesChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row C: Local EGP Duties & Clearance
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: customsEgpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${l.customsAndVatEstimate} (EGP)',
                    border: const OutlineInputBorder(),
                    fillColor:
                        isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                    filled: isDark,
                  ),
                  onChanged: (_) => onValuesChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: clearanceEgpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${l.clearanceAndTransportEstimate} (EGP)',
                    border: const OutlineInputBorder(),
                    fillColor:
                        isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
                    filled: isDark,
                  ),
                  onChanged: (_) => onValuesChanged(),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),

        TextFormField(
          controller: notesController,
          decoration: InputDecoration(
            labelText: l.budgetApprovalNotes,
            border: const OutlineInputBorder(),
            fillColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.white,
            filled: isDark,
          ),
        ),
      ],
    );
  }
}
