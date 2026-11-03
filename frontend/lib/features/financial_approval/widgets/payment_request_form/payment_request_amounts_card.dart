import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../currencies/providers/currencies_provider.dart';
import '../../models/financial_approval_model.dart';

class PaymentRequestAmountsCard extends ConsumerWidget {
  final BudgetPrefillModel? payPrefillData;
  final double? selectedPercentage;
  final void Function(double pct)? onSelectPercentage;
  final String currencyCode;
  final ValueChanged<String> onCurrencyChanged;
  final TextEditingController amountController;
  final TextEditingController exchangeRateController;
  final DateTime requestDate;
  final ValueChanged<DateTime> onRequestDateChanged;
  final DateTime dueDate;
  final ValueChanged<DateTime> onDueDateChanged;
  final double maxWidth;

  const PaymentRequestAmountsCard({
    super.key,
    this.payPrefillData,
    this.selectedPercentage,
    this.onSelectPercentage,
    required this.currencyCode,
    required this.onCurrencyChanged,
    required this.amountController,
    required this.exchangeRateController,
    required this.requestDate,
    required this.onRequestDateChanged,
    required this.dueDate,
    required this.onDueDateChanged,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Percentage chips from PO invoice
        if (payPrefillData != null &&
            payPrefillData!.totalInvoiceAmount > 0 &&
            onSelectPercentage != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l.faPercentFromPo(
                  payPrefillData!.totalInvoiceAmount.toStringAsFixed(2),
                  currencyCode,
                ),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                ),
              ),
              ...[10.0, 20.0, 30.0, 50.0, 100.0].map((pct) {
                final isSel = selectedPercentage == pct;
                return ChoiceChip(
                  label: Text('${pct.toStringAsFixed(0)}%'),
                  selected: isSel,
                  selectedColor: AppTheme.wcagOrange,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: isSel
                        ? AppTheme.white
                        : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onSelectPercentage!(pct),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Row 3: Amount, Currency, Rate, Request Date, Due Date (Responsive)
        if (maxWidth >= 1100)
          Row(
            children: [
              Expanded(child: _buildAmountField(l)),
              const SizedBox(width: 12),
              Expanded(child: _buildCurrencyDropdown(ref, l)),
              const SizedBox(width: 12),
              Expanded(child: _buildExchangeRateField(l)),
              const SizedBox(width: 12),
              Expanded(child: _buildRequestDateField(context, l)),
              const SizedBox(width: 12),
              Expanded(child: _buildDueDateField(context, l)),
            ],
          )
        else if (maxWidth >= 700)
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildAmountField(l)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCurrencyDropdown(ref, l)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildExchangeRateField(l)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildRequestDateField(context, l)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDueDateField(context, l)),
                ],
              ),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildAmountField(l)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCurrencyDropdown(ref, l)),
                ],
              ),
              const SizedBox(height: 12),
              _buildExchangeRateField(l),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildRequestDateField(context, l)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDueDateField(context, l)),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAmountField(AppLocalizations l) {
    return TextFormField(
      controller: amountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '${l.requestedAmountLabel} *',
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          (v == null || double.tryParse(v) == null || double.parse(v) <= 0)
              ? l.requiredField
              : null,
    );
  }

  Widget _buildCurrencyDropdown(WidgetRef ref, AppLocalizations l) {
    return SearchableDropdownField<String>(
      value: currencyCode,
      labelText: '${l.currencyCol} *',
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
        if (!list.any((i) => i.value == currencyCode)) {
          list.add(SearchableDropdownItem(
              value: currencyCode, label: currencyCode));
        }
        return list;
      }(),
      onChanged: (val) {
        if (val != null) onCurrencyChanged(val);
      },
    );
  }

  Widget _buildExchangeRateField(AppLocalizations l) {
    return TextFormField(
      controller: exchangeRateController,
      keyboardType: TextInputType.number,
      validator: (v) {
        final r = double.tryParse((v ?? '').trim());
        if (r == null || r <= 0) return l.faExchangeRateInvalid;
        return null;
      },
      decoration: InputDecoration(
        labelText: '${l.exchangeRateCol} (EGP) *',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildRequestDateField(BuildContext context, AppLocalizations l) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: requestDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onRequestDateChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '${l.requestDateLabel} *',
          border: const OutlineInputBorder(),
        ),
        child: Text(requestDate.toString().substring(0, 10)),
      ),
    );
  }

  Widget _buildDueDateField(BuildContext context, AppLocalizations l) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: dueDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onDueDateChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '${l.dueDateLabel} *',
          border: const OutlineInputBorder(),
        ),
        child: Text(dueDate.toString().substring(0, 10)),
      ),
    );
  }
}
