import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../core/widgets/table_row_clone_helper.dart';
import '../../models/customs_consultation_model.dart';
import '../../providers/customs_consultation_provider.dart';

class ClearanceExpenseTypeDialogs {
  static List<SearchableDropdownItem<String>> brokerCategoryItems(AppLocalizations l, [String? current]) {
    final codes = DomainEnums.codesOf(DomainEnumType.brokerExpenseCategory);
    return [
      for (final code in codes)
        SearchableDropdownItem(
          value: code,
          label: DomainEnums.label(l, DomainEnumType.brokerExpenseCategory, code),
        ),
      if (current != null && current.isNotEmpty && current != 'All' && !codes.contains(current))
        SearchableDropdownItem(value: current, label: current),
    ];
  }

  static List<SearchableDropdownItem<String>> brokerUnitItems(AppLocalizations l, String current) {
    final codes = DomainEnums.codesOf(DomainEnumType.brokerUnit);
    return [
      for (final code in codes)
        SearchableDropdownItem(
          value: code,
          label: DomainEnums.label(l, DomainEnumType.brokerUnit, code),
        ),
      if (current.isNotEmpty && !codes.contains(current))
        SearchableDropdownItem(value: current, label: current),
    ];
  }

  static void showAdd(BuildContext context, WidgetRef ref, {ClearanceExpenseTypeModel? template}) {
    final l = context.l10n;
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: TableRowCloneHelper.withCodeSuffix(template?.expenseCode) ?? '');
    final nameArCtrl = TextEditingController(text: TableRowCloneHelper.withCopySuffix(template?.nameAr) ?? '');
    final nameEnCtrl = TextEditingController(text: TableRowCloneHelper.withCopySuffix(template?.nameEn) ?? '');
    String category = DomainEnums.initialCode(
      DomainEnumType.brokerExpenseCategory,
      template?.category,
      template?.category ?? 'CLEARANCE_FEES',
    );
    String defaultUnit = DomainEnums.initialCode(
      DomainEnumType.brokerUnit,
      template?.defaultUnit,
      template?.defaultUnit ?? 'PER_INVOICE',
    );
    String currency = template?.defaultCurrency ?? 'EGP';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            template != null
                ? (context.l10n.ccCloneClearanceExpenseItem)
                : l.newExpenseTypeDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseCodeField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (context.l10n.ccCodeRequired) : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameArCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseNameArField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (context.l10n.ccArabicNameRequired) : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameEnCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseNameEnField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: category,
                      labelText: l.categoryCol,
                      items: brokerCategoryItems(l, category),
                      onChanged: (v) => setDlgState(() => category = v ?? category),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: defaultUnit,
                            labelText: l.defaultCalculationUnitField,
                            items: brokerUnitItems(l, defaultUnit),
                            onChanged: (v) => setDlgState(() => defaultUnit = v ?? defaultUnit),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: currency,
                            labelText: l.defaultCurrencyCol,
                            items: const [
                              SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                              SearchableDropdownItem(value: 'USD', label: 'USD'),
                              SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                            ],
                            onChanged: (v) => setDlgState(() => currency = v ?? 'EGP'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
            ),
            AppButton(
              label: l.saveExpenseBtn,
              variant: AppButtonVariant.success,
              isLoading: isSaving,
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() => isSaving = true);
                      try {
                        await ref.read(clearanceExpenseTypesProvider.notifier).createExpenseType({
                          'expense_code': codeCtrl.text.trim(),
                          'name_ar': nameArCtrl.text.trim(),
                          'name_en': nameEnCtrl.text.trim().isNotEmpty ? nameEnCtrl.text.trim() : null,
                          'category': category,
                          'default_unit': defaultUnit,
                          'default_currency': currency,
                          'display_order': 99,
                          'is_active': true,
                        });
                        ref.invalidate(clearanceExpenseTypesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            AppTheme.snackBar(ctx, ApiErrorText.of(l, e), severity: AppSeverity.danger),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  static void showEdit(BuildContext context, WidgetRef ref, ClearanceExpenseTypeModel exp) {
    final l = context.l10n;
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: exp.expenseCode);
    final nameArCtrl = TextEditingController(text: exp.nameAr);
    final nameEnCtrl = TextEditingController(text: exp.nameEn ?? '');
    String category = DomainEnums.initialCode(DomainEnumType.brokerExpenseCategory, exp.category, exp.category);
    String defaultUnit = DomainEnums.initialCode(DomainEnumType.brokerUnit, exp.defaultUnit, exp.defaultUnit);
    String? currency = exp.defaultCurrency;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Text(l.editExpenseTypeDialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseCodeField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (context.l10n.ccCodeRequired) : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameArCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseNameArField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? (context.l10n.ccArabicNameRequired) : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameEnCtrl,
                      decoration: InputDecoration(
                        labelText: l.expenseNameEnField,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: category,
                      labelText: l.categoryCol,
                      items: brokerCategoryItems(l, category),
                      onChanged: (v) => setDlgState(() => category = v ?? category),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: defaultUnit,
                            labelText: l.defaultCalculationUnitField,
                            items: brokerUnitItems(l, defaultUnit),
                            onChanged: (v) => setDlgState(() => defaultUnit = v ?? defaultUnit),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SearchableDropdownField<String>(
                            value: currency,
                            labelText: l.defaultCurrencyCol,
                            items: const [
                              SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                              SearchableDropdownItem(value: 'USD', label: 'USD'),
                              SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                            ],
                            onChanged: (v) => setDlgState(() => currency = v ?? 'EGP'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
            ),
            AppButton(
              label: l.saveExpenseBtn,
              variant: AppButtonVariant.primary,
              isLoading: isSaving,
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final successSnack = AppTheme.snackBar(context, l.expenseTypeUpdatedToast, severity: AppSeverity.success);
                      try {
                        await ref.read(clearanceExpenseTypesProvider.notifier).updateExpenseType(
                          exp.expenseId,
                          {
                            'expense_code': codeCtrl.text.trim(),
                            'name_ar': nameArCtrl.text.trim(),
                            'name_en': nameEnCtrl.text.trim().isNotEmpty ? nameEnCtrl.text.trim() : null,
                            'category': category,
                            'default_unit': defaultUnit,
                            'default_currency': currency,
                            'display_order': exp.displayOrder,
                            'is_active': exp.isActive,
                          },
                        );
                        ref.invalidate(clearanceExpenseTypesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(successSnack);
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            AppTheme.snackBar(ctx, ApiErrorText.of(l, e), severity: AppSeverity.danger),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  static void showDeleteConfirm(BuildContext context, WidgetRef ref, ClearanceExpenseTypeModel exp) {
    final l = context.l10n;
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
              const SizedBox(width: 8),
              Text(l.confirmDeleteExpenseTypeTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            l.confirmDeleteExpenseTypeMsg(exp.nameAr, exp.expenseCode),
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
            ),
            AppButton(
              label: context.l10n.delete,
              variant: AppButtonVariant.danger,
              isLoading: isDeleting,
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDlgState(() => isDeleting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final deleteSnack = AppTheme.snackBar(context, l.expenseTypeDeletedToast, severity: AppSeverity.danger);
                      try {
                        await ref.read(clearanceExpenseTypesProvider.notifier).deleteExpenseType(exp.expenseId);
                        ref.invalidate(clearanceExpenseTypesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(deleteSnack);
                      } catch (e) {
                        setDlgState(() => isDeleting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            AppTheme.snackBar(ctx, ApiErrorText.of(l, e), severity: AppSeverity.danger),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
