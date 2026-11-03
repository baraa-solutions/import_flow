import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../../currencies/models/currency_model.dart';

class CarrierCostBreakdownRow extends StatelessWidget {
  final String rowKey;
  final String title;
  final bool applicable;
  final double price;
  final String? currency;
  final double qty;
  final ValueChanged<bool> onApplicableChanged;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<double>? onQtyChanged;
  final bool showQty;
  final bool qtyReadOnly;
  final bool isIntegerQty;
  final List<CurrencyModel> currenciesList;
  final int? editingSessionId;
  final int editFormVersion;

  const CarrierCostBreakdownRow({
    super.key,
    required this.rowKey,
    required this.title,
    required this.applicable,
    required this.price,
    required this.currency,
    this.qty = 1.0,
    required this.onApplicableChanged,
    required this.onPriceChanged,
    required this.onCurrencyChanged,
    this.onQtyChanged,
    this.showQty = false,
    this.qtyReadOnly = false,
    this.isIntegerQty = true,
    required this.currenciesList,
    required this.editingSessionId,
    required this.editFormVersion,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, costConstraints) {
        final isNarrow = costConstraints.maxWidth < 650;

        final priceField = TextFormField(
          key: ValueKey('price_${rowKey}_${editingSessionId ?? "new"}_$editFormVersion'),
          initialValue: price == 0.0 ? '' : price.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.itemPriceCol, isDense: true),
          onChanged: (v) {
            final p = double.tryParse(v) ?? 0.0;
            onPriceChanged(p);
          },
        );

        final currencyField = SearchableDropdownField<String>(
          value: currenciesList.any((c) => c.currencyCode == currency) ? currency : null,
          labelText: l.currency,
          items: currenciesList.map((c) => SearchableDropdownItem(
                value: c.currencyCode,
                label: '${c.currencyCode} (${c.currencySymbol})',
              )).toList(),
          onChanged: (v) {
            if (v != null) {
              onCurrencyChanged(v);
            }
          },
        );

        final qtyField = showQty
            ? TextFormField(
                key: qtyReadOnly
                    ? ValueKey('readonly_qty_${rowKey}_$qty')
                    : ValueKey('qty_${rowKey}_${editingSessionId ?? "new"}_$editFormVersion'),
                readOnly: qtyReadOnly,
                initialValue: qty == 0.0 ? '' : (isIntegerQty ? qty.toInt().toString() : qty.toString()),
                keyboardType: TextInputType.numberWithOptions(decimal: !isIntegerQty),
                decoration: InputDecoration(labelText: l.quantity, isDense: true),
                onChanged: qtyReadOnly
                    ? null
                    : (v) {
                        final q = double.tryParse(v) ?? 0.0;
                        if (onQtyChanged != null) {
                          onQtyChanged!(q);
                        }
                      },
              )
            : null;

        final switchWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: applicable,
              activeThumbColor: AppTheme.cobalt,
              onChanged: onApplicableChanged,
            ),
            Text(
              applicable ? l.applicable : l.notApplicable,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: applicable ? AppTheme.emerald : AppTheme.crimson,
              ),
            ),
          ],
        );

        final totalDisplay = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: applicable ? AppTheme.emeraldLight : AppTheme.crimsonLight,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: applicable
                  ? (isDark ? AppTheme.emerald : AppTheme.emeraldBorder)
                  : (isDark ? AppTheme.crimson : AppTheme.crimsonBorder),
            ),
          ),
          child: Text(
            applicable
                ? '${(price * qty).toStringAsFixed(0)} ${currency ?? ''}'.trim()
                : '0.0 ${currency ?? ''}'.trim(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: applicable ? AppTheme.emerald : AppTheme.crimson,
            ),
            textAlign: TextAlign.center,
          ),
        );

        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    switchWidget,
                    const SizedBox(width: 8),
                    totalDisplay,
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(flex: 2, child: priceField),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: currencyField),
                    if (showQty && qtyField != null) ...[
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: qtyField),
                    ],
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: priceField),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: currencyField),
              if (showQty && qtyField != null) ...[
                const SizedBox(width: 8),
                Expanded(flex: 2, child: qtyField),
              ],
              const SizedBox(width: 12),
              switchWidget,
              const SizedBox(width: 12),
              Expanded(flex: 2, child: totalDisplay),
            ],
          ),
        );
      },
    );
  }
}
