import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../cc_dialog_shell.dart';
import '../customs_ui.dart';

class ClearanceAddInvoiceForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController providerNameController;
  final TextEditingController invoiceNumberController;
  final TextEditingController amountEgpController;
  final TextEditingController vatAmountController;
  final TextEditingController whtAmountController;
  final TextEditingController notesController;
  final String expenseCategory;
  final ValueChanged<String> onExpenseCategoryChanged;
  final List<String> expenseCategories;
  final DateTime invoiceDate;
  final ValueChanged<DateTime> onInvoiceDateChanged;
  final String allocationRule;
  final ValueChanged<String> onAllocationRuleChanged;
  final bool vatIncluded;
  final ValueChanged<bool> onVatIncludedChanged;
  final bool whtDeducted;
  final ValueChanged<bool> onWhtDeductedChanged;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const ClearanceAddInvoiceForm({
    super.key,
    required this.formKey,
    required this.providerNameController,
    required this.invoiceNumberController,
    required this.amountEgpController,
    required this.vatAmountController,
    required this.whtAmountController,
    required this.notesController,
    required this.expenseCategory,
    required this.onExpenseCategoryChanged,
    required this.expenseCategories,
    required this.invoiceDate,
    required this.onInvoiceDateChanged,
    required this.allocationRule,
    required this.onAllocationRuleChanged,
    required this.vatIncluded,
    required this.onVatIncludedChanged,
    required this.whtDeducted,
    required this.onWhtDeductedChanged,
    required this.isSubmitting,
    required this.onCancel,
    required this.onSubmit,
  });

  InputDecoration _dec(BuildContext context, String label, {String? hint, IconData? icon}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final allocationRules = <String, String>{
      'Equal': l.ccExpAllocEqual,
      'Value-Based': l.ccExpAllocValue,
      'Weight-Based': l.ccExpAllocWeight,
      'Volume-Based': l.ccExpAllocVolume,
    };

    return Form(
      key: formKey,
      child: CcFormSection(
        title: l.ccExpFormTitle,
        icon: Icons.note_add,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.ccExpFormNote,
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondaryOf(context),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),

            // Row 1: provider name, invoice number, date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceProviderNameField'),
                    controller: providerNameController,
                    decoration: _dec(context, l.ccExpProviderLabel, hint: l.ccExpProviderHint, icon: Icons.business_outlined),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l.ccExpProviderRequired;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceNumberField'),
                    controller: invoiceNumberController,
                    textDirection: TextDirection.ltr,
                    decoration: _dec(context, l.ccExpNumberLabel, hint: l.ccExpNumberHint, icon: Icons.tag),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l.ccExpNumberRequired;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: invoiceDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) onInvoiceDateChanged(picked);
                    },
                    child: InputDecorator(
                      decoration: _dec(context, l.ccExpDateLabel, icon: Icons.calendar_today),
                      child: LtrText(CcFormat.date(invoiceDate),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 2: category & allocation rule
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    key: const Key('invoiceCategoryDropdown'),
                    value: expenseCategory,
                    isDense: false,
                    isRequired: true,
                    labelText: l.ccExpCategoryLabel,
                    decoration: _dec(context, l.ccExpCategoryLabel, icon: Icons.category_outlined),
                    items: expenseCategories
                        .map((cat) => SearchableDropdownItem<String>(
                              value: cat,
                              label: DomainEnums.label(l, DomainEnumType.clearanceExpenseCategory, cat),
                            ))
                        .toList(),
                    validator: (v) => (v == null || v.isEmpty) ? l.requiredField : null,
                    onChanged: (val) {
                      if (val != null) onExpenseCategoryChanged(val);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    key: const Key('invoiceAllocationRuleDropdown'),
                    value: allocationRule,
                    isDense: false,
                    isRequired: true,
                    labelText: l.ccExpAllocationLabel,
                    decoration: _dec(context, l.ccExpAllocationLabel, icon: Icons.pie_chart_outline),
                    items: allocationRules.entries
                        .map((rule) => SearchableDropdownItem<String>(value: rule.key, label: rule.value))
                        .toList(),
                    validator: (v) => (v == null || v.isEmpty) ? l.requiredField : null,
                    onChanged: (val) {
                      if (val != null) onAllocationRuleChanged(val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 3: amount, VAT, WHT
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('invoiceAmountField'),
                    controller: amountEgpController,
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec(context, l.ccExpAmountLabel, hint: '0.00', icon: Icons.attach_money),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return l.ccExpAmountRequired;
                      final numVal = double.tryParse(val.trim());
                      if (numVal == null || numVal <= 0) return l.ccExpAmountPositive;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Material(
                        type: MaterialType.transparency,
                        child: CheckboxListTile(
                          title: Text(l.ccVatCheckboxLabel, overflow: TextOverflow.ellipsis),
                          value: vatIncluded,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) => onVatIncludedChanged(val ?? false),
                        ),
                      ),
                      if (vatIncluded)
                        TextFormField(
                          key: const Key('invoiceVatAmountField'),
                          controller: vatAmountController,
                          textDirection: TextDirection.ltr,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec(context, l.ccVatAmountLabel, icon: Icons.percent),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Material(
                        type: MaterialType.transparency,
                        child: CheckboxListTile(
                          title: Text(l.ccExpWhtCheckbox, overflow: TextOverflow.ellipsis),
                          value: whtDeducted,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) => onWhtDeductedChanged(val ?? false),
                        ),
                      ),
                      if (whtDeducted)
                        TextFormField(
                          key: const Key('invoiceWhtAmountField'),
                          controller: whtAmountController,
                          textDirection: TextDirection.ltr,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec(context, l.ccWhtAmountLabel, icon: Icons.remove_circle_outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              key: const Key('invoiceNotesField'),
              controller: notesController,
              decoration: _dec(context, l.ccExpNotesLabel, hint: l.ccExpNotesHint, icon: Icons.notes),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: l.cancel,
                  variant: AppButtonVariant.secondary,
                  onPressed: isSubmitting ? null : onCancel,
                ),
                const SizedBox(width: 12),
                AppButton(
                  key: const Key('saveClearanceInvoiceBtn'),
                  label: isSubmitting ? l.ccExpSaving : l.ccExpSave,
                  icon: Icons.check,
                  variant: AppButtonVariant.success,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : onSubmit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
