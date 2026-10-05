import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/cc_dialog_shell.dart';

/// One of the 17 freight quote items: applicable switch, rate, currency and an
/// optional quantity / CBM volume. Wraps on narrow dialogs.
class FbkCostItemRow extends StatelessWidget {
  const FbkCostItemRow({
    super.key,
    required this.title,
    required this.isApplicable,
    required this.onToggle,
    required this.price,
    required this.onPriceChanged,
    required this.currency,
    required this.onCurrencyChanged,
    this.quantity,
    this.onQuantityChanged,
    this.doubleQty,
    this.onDoubleQtyChanged,
  });

  final String title;
  final bool isApplicable;
  final ValueChanged<bool> onToggle;
  final double price;
  final ValueChanged<double> onPriceChanged;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final int? quantity;
  final ValueChanged<int>? onQuantityChanged;
  final double? doubleQty;
  final ValueChanged<double>? onDoubleQtyChanged;

  static const _currencies = [
    SearchableDropdownItem(value: 'USD', label: 'USD'),
    SearchableDropdownItem(value: 'EUR', label: 'EUR'),
    SearchableDropdownItem(value: 'EGP', label: 'EGP'),
    SearchableDropdownItem(value: 'GBP', label: 'GBP'),
    SearchableDropdownItem(value: 'CNY', label: 'CNY'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final okFg = AppTheme.severityForegroundOf(context, AppSeverity.success);

    final rate = TextFormField(
      initialValue: price > 0 ? price.toStringAsFixed(0) : '',
      keyboardType: TextInputType.number,
      decoration: ccInputDecoration().copyWith(labelText: l.freightBookingItemRateLabel),
      onChanged: (v) => onPriceChanged(double.tryParse(v) ?? 0.0),
    );
    final cur = SearchableDropdownField<String>(
      value: currency,
      labelText: l.freightBookingCurrencyLabel,
      searchHintText: 'USD, EUR...',
      decoration: ccInputDecoration().copyWith(labelText: l.freightBookingCurrencyLabel),
      items: _currencies,
      onChanged: (v) {
        if (v != null) onCurrencyChanged(v);
      },
    );
    Widget? qty;
    if (quantity != null && onQuantityChanged != null) {
      qty = TextFormField(
        initialValue: quantity.toString(),
        keyboardType: TextInputType.number,
        decoration: ccInputDecoration().copyWith(labelText: l.freightBookingQuantityLabel),
        onChanged: (v) => onQuantityChanged!(int.tryParse(v) ?? 1),
      );
    } else if (doubleQty != null && onDoubleQtyChanged != null) {
      qty = TextFormField(
        initialValue: doubleQty.toString(),
        keyboardType: TextInputType.number,
        decoration: ccInputDecoration().copyWith(labelText: l.freightBookingCbmVolumeLabel),
        onChanged: (v) => onDoubleQtyChanged!(double.tryParse(v) ?? 0.0),
      );
    }

    final toggle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: isApplicable, activeThumbColor: AppTheme.emerald, onChanged: onToggle),
        Text(
          isApplicable ? l.freightBookingItemActive : l.freightBookingItemInactive,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isApplicable ? okFg : AppTheme.textMutedOf(context),
          ),
        ),
      ],
    );
    final titleText = Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: isApplicable ? FontWeight.bold : FontWeight.normal,
        color: AppTheme.textPrimaryOf(context),
      ),
    );

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isApplicable
            ? AppTheme.severityBackgroundOf(context, AppSeverity.success)
            : AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: isApplicable ? okFg.withValues(alpha: 0.5) : AppTheme.borderOf(context)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 640) {
          return Row(
            children: [
              Expanded(flex: 4, child: titleText),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: rate),
              const SizedBox(width: 8),
              SizedBox(width: 110, child: cur),
              if (qty != null) ...[const SizedBox(width: 8), SizedBox(width: 90, child: qty)],
              const SizedBox(width: 8),
              toggle,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: titleText), toggle]),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(flex: 3, child: rate),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: cur),
                if (qty != null) ...[const SizedBox(width: 8), Expanded(flex: 2, child: qty)],
              ],
            ),
          ],
        );
      }),
    );
  }
}
