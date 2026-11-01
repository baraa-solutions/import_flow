import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../currencies/models/currency_model.dart';
import '../po_decimal_field.dart';

class POLineItemPricingSection extends StatelessWidget {
  final TextEditingController qtyController;
  final TextEditingController unitPriceController;
  final String unitOfMeasure;
  final List<SearchableDropdownItem<String>> uomItems;
  final ValueChanged<String?> onUomChanged;
  final CurrencyModel currency;
  final double calculatedTotal;
  final VoidCallback onValuesChanged;
  final bool isArabic;

  const POLineItemPricingSection({
    super.key,
    required this.qtyController,
    required this.unitPriceController,
    required this.unitOfMeasure,
    required this.uomItems,
    required this.onUomChanged,
    required this.currency,
    required this.calculatedTotal,
    required this.onValuesChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [PoDecimalField.decimalFormatter(2)],
            decoration: InputDecoration(
              labelText: isArabic ? 'الكمية *' : 'Quantity *',
              isDense: true,
            ),
            onChanged: (_) => onValuesChanged(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SearchableDropdownField<String>(
            value: unitOfMeasure,
            labelText: isArabic ? 'الوحدة' : 'Unit',
            items: uomItems,
            onChanged: onUomChanged,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: unitPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [PoDecimalField.decimalFormatter(4)],
            decoration: InputDecoration(
              labelText: isArabic
                  ? 'سعر الوحدة (${currency.currencyCode}) *'
                  : 'Unit Price (${currency.currencyCode}) *',
              isDense: true,
            ),
            onChanged: (_) => onValuesChanged(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.emeraldLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.emeraldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'إجمالي السطر' : 'Line Total',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                Text(
                  '${currency.currencyCode} ${calculatedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
