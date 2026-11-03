import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_consultation_model.dart';

class AddCustomBrokerExpenseRowDialog extends StatefulWidget {
  const AddCustomBrokerExpenseRowDialog({super.key});

  @override
  State<AddCustomBrokerExpenseRowDialog> createState() =>
      _AddCustomBrokerExpenseRowDialogState();
}

class _AddCustomBrokerExpenseRowDialogState
    extends State<AddCustomBrokerExpenseRowDialog> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  String selectedCategory = 'Other Fees';
  String selectedUnit = 'Fixed';
  String selectedCurrency = 'EGP';

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SelectionArea(
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_circle, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Text(l.addCustomExpenseRow,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: l.expenseItemNameCol,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              SearchableDropdownField<String>(
                value: selectedCategory,
                labelText: l.categoryCol,
                items: const [
                  SearchableDropdownItem(
                      value: 'Clearance Fees', label: 'Clearance Fees'),
                  SearchableDropdownItem(
                      value: 'Procedures & Approvals',
                      label: 'Procedures & Approvals'),
                  SearchableDropdownItem(
                      value: 'Inland Transport', label: 'Inland Transport'),
                  SearchableDropdownItem(
                      value: 'Port & Handling', label: 'Port & Handling'),
                  SearchableDropdownItem(
                      value: 'Other Fees', label: 'Other Fees'),
                ],
                onChanged: (v) =>
                    setState(() => selectedCategory = v ?? selectedCategory),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                          labelText: l.itemPriceCol,
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SearchableDropdownField<String>(
                      value: selectedCurrency,
                      labelText: l.currency,
                      items: const [
                        SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                        SearchableDropdownItem(value: 'USD', label: 'USD'),
                        SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                      ],
                      onChanged: (v) =>
                          setState(() => selectedCurrency = v ?? 'EGP'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                          labelText: l.quoteItemQuantity,
                          border: const OutlineInputBorder()),
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
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
              final newItem = CustomsBrokerQuoteItemModel(
                expenseName: name,
                category: selectedCategory,
                unitType: selectedUnit,
                unitPrice: price,
                currency: selectedCurrency,
                qty: qty,
                isApplicable: true,
                totalAmount: price * qty,
              );
              Navigator.pop(context, newItem);
            },
          ),
        ],
      ),
    );
  }
}
