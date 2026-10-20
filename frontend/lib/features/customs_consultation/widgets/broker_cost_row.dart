import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../models/customs_consultation_model.dart';
import '../../currencies/models/currency_model.dart';

Widget buildBrokerCostRow({
  required BuildContext context,
  required Function(int, CustomsBrokerQuoteItemModel) onUpdate,
  required int index,
  required CustomsBrokerQuoteItemModel item,
  required List<CurrencyModel> currenciesList,
}) {
  final l = context.l10n;
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: item.isApplicable ? AppTheme.emerald.withValues(alpha: 0.04) : AppTheme.charcoalSurface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: item.isApplicable ? AppTheme.emerald.withValues(alpha: 0.3) : AppTheme.cloudWhite),
    ),
    child: Row(
      children: [
        // Title & Category
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => CopyHelper.copy(
                  context,
                  item.expenseName,
                  customMessage: context.l10n.ccExpenseItemNameCopied,
                ),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        item.expenseName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy_outlined, size: 12, color: AppTheme.charcoal),
                  ],
                ),
              ),
              Text(
                '${item.category.split('(').first.trim()} | ${item.unitType}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Price field
        Expanded(
          flex: 2,
          child: TextFormField(
            key: ValueKey('broker_price_${item.expenseTypeId ?? item.expenseName}'),
            initialValue: item.unitPrice == 0.0 ? '' : item.unitPrice.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.quoteItemPrice,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (v) {
              final p = double.tryParse(v) ?? 0.0;
              onUpdate(index, item.copyWith(unitPrice: p));
            },
          ),
        ),
        const SizedBox(width: 8),
        // Currency dropdown
        Expanded(
          flex: 2,
          child: SearchableDropdownField<String>(
            value: currenciesList.any((c) => c.currencyCode == item.currency)
                ? item.currency
                : (currenciesList.isNotEmpty ? currenciesList.first.currencyCode : 'EGP'),
            labelText: l.quoteItemCurrency,
            items: currenciesList
                .map((c) => SearchableDropdownItem(
                      value: c.currencyCode,
                      label: '${c.currencyCode} (${c.currencySymbol})',
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                onUpdate(index, item.copyWith(currency: v));
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Qty field
        Expanded(
          flex: 1,
          child: TextFormField(
            key: ValueKey('broker_qty_${item.expenseTypeId ?? item.expenseName}'),
            initialValue: item.qty == 0.0 ? '1' : (item.qty == item.qty.roundToDouble() ? item.qty.toInt().toString() : item.qty.toString()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.quoteItemQuantity,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (v) {
              final q = double.tryParse(v) ?? 1.0;
              onUpdate(index, item.copyWith(qty: q));
            },
          ),
        ),
        const SizedBox(width: 10),
        // Applicable switch
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: item.isApplicable,
              activeThumbColor: AppTheme.emerald,
              onChanged: (v) => onUpdate(index, item.copyWith(isApplicable: v)),
            ),
            Text(
              item.isApplicable ? l.quoteItemApplicable : l.quoteItemNotApplicable,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: item.isApplicable ? AppTheme.emerald : AppTheme.crimson,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        // Line total display
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: item.isApplicable ? AppTheme.emerald.withValues(alpha: 0.12) : AppTheme.cloudWhite,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.isApplicable
                  ? '${(item.unitPrice * item.qty).toStringAsFixed(2)} ${item.currency}'
                  : '0.00 ${item.currency}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: item.isApplicable ? AppTheme.emerald : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
}
