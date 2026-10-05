import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../models/customs_consultation_model.dart';
import '../../../core/widgets/buttons/app_button.dart';

class AddCustomExpenseDialog extends StatefulWidget {
  final Function(CustomsBrokerQuoteItemModel) onExpenseAdded;

  const AddCustomExpenseDialog({
    super.key,
    required this.onExpenseAdded,
  });

  @override
  State<AddCustomExpenseDialog> createState() => _AddCustomExpenseDialogState();
}

class _AddCustomExpenseDialogState extends State<AddCustomExpenseDialog> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0.0');
  final _qtyCtrl = TextEditingController(text: '1.0');
  String _selectedCategory = 'Other Fees';
  String _selectedUnit = 'Fixed';
  String _selectedCurrency = 'EGP';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.add_circle, color: AppTheme.cobalt),
          const SizedBox(width: 8),
          Text(l.addCustomExpenseRow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l.expenseItemNameCol,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SearchableDropdownField<String>(
              value: _selectedCategory,
              labelText: l.categoryCol,
              items: const [
                SearchableDropdownItem(value: 'Clearance Fees', label: 'Clearance Fees'),
                SearchableDropdownItem(value: 'Port & Storage', label: 'Port & Storage'),
                SearchableDropdownItem(value: 'Inspection & Lab', label: 'Inspection & Lab'),
                SearchableDropdownItem(value: 'Inland Transport', label: 'Inland Transport'),
                SearchableDropdownItem(value: 'Other Fees', label: 'Other Fees'),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedCategory = v);
              },
            ),
            const SizedBox(height: 12),
            SearchableDropdownField<String>(
              value: _selectedUnit,
              labelText: l.calculationUnitCol,
              items: const [
                SearchableDropdownItem(value: 'Fixed', label: 'Fixed'),
                SearchableDropdownItem(value: 'Per Container', label: 'Per Container'),
                SearchableDropdownItem(value: 'Per Ton', label: 'Per Ton'),
                SearchableDropdownItem(value: 'Per Shipment', label: 'Per Shipment'),
                SearchableDropdownItem(value: 'Per Truck', label: 'Per Truck'),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedUnit = v);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.itemPriceCol, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SearchableDropdownField<String>(
                    value: _selectedCurrency,
                    labelText: l.currency,
                    items: const [
                      SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                      SearchableDropdownItem(value: 'USD', label: 'USD'),
                      SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCurrency = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.quantityAndUnitCol, border: const OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        AppButton(
          label: l.cancel,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: l.save,
          variant: AppButtonVariant.success,
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
            final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
            widget.onExpenseAdded(CustomsBrokerQuoteItemModel(
              expenseName: name,
              category: _selectedCategory,
              unitType: _selectedUnit,
              unitPrice: price,
              currency: _selectedCurrency,
              qty: qty,
              isApplicable: true,
              totalAmount: price * qty,
            ));
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

