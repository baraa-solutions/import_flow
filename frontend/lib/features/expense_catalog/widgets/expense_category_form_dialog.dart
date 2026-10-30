import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../models/expense_catalog_model.dart';
import '../providers/expense_catalog_provider.dart';

/// Form dialogs for creating/editing expense catalog items and adding recognition patterns.
class ExpenseCategoryFormDialog {
  static const List<String> defaultCategories = [
    'Clearance Fees',
    'Procedures & Approvals',
    'Inland Transport',
    'Port & Handling',
    'Other Fees',
  ];

  static const List<String> defaultUnitTypes = [
    'fixed',
    'per_ton',
    'per_container',
    'per_vehicle',
    'per_night',
    'per_invoice',
    'per_shipment',
    'range',
  ];

  /// Shows the add or edit expense catalog item dialog.
  static Future<void> showAddEdit(
    BuildContext context,
    WidgetRef ref, {
    ExpenseCatalogModel? item,
    List<String> categories = defaultCategories,
    List<String> unitTypes = defaultUnitTypes,
  }) async {
    final isEdit = item != null;
    final codeController = TextEditingController(text: item?.code ?? '');
    final nameArController = TextEditingController(text: item?.canonicalNameAr ?? '');
    final nameEnController = TextEditingController(text: item?.canonicalNameEn ?? '');
    String selectedCategory = item?.category ?? categories.first;
    String selectedUnit = item?.unitType ?? unitTypes.first;
    bool allowComposite = item?.allowComposite ?? false;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final isArabic = context.l10n.isArabic;
          final isDark = AppTheme.isDark(context);
          return SelectionArea(
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_note_rounded : Icons.post_add_rounded,
                    color: AppTheme.cobalt,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit
                        ? (isArabic ? 'تعديل بند المصروف' : 'Edit Expense Item')
                        : (isArabic ? 'إضافة كود مصروف قياسي جديد' : 'New Expense Code'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'كود البند القياسي' : 'Catalog Code',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: codeController,
                          enabled: !isEdit,
                          decoration: InputDecoration(
                            hintText: 'e.g. CLR-LCL-INV',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            fillColor: isEdit ? (isDark ? Colors.grey.shade900 : Colors.grey.shade200) : null,
                            filled: isEdit,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (isArabic ? 'الكود إلزامي' : 'Code is required')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isArabic ? 'الاسم القياسي بالعربية' : 'Arabic Name',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: nameArController,
                          decoration: InputDecoration(
                            hintText: isArabic ? 'مثال: أتعاب تخليص جمركي' : 'e.g. أتعاب تخليص جمركي',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (isArabic ? 'الاسم العربي إلزامي' : 'Arabic name is required')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isArabic ? 'الاسم القياسي بالإنجليزية' : 'English Name',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: nameEnController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Customs Clearance Agency Fee',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'التصنيف' : 'Category',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  SearchableDropdownField<String>(
                                    value: selectedCategory,
                                    labelText: isArabic ? 'التصنيف' : 'Category',
                                    items: categories
                                        .map((c) => SearchableDropdownItem<String>(value: c, label: c))
                                        .toList(),
                                    onChanged: (v) => setDlgState(() => selectedCategory = v ?? selectedCategory),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'وحدة الحساب' : 'Unit Type',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  SearchableDropdownField<String>(
                                    value: selectedUnit,
                                    labelText: isArabic ? 'وحدة الحساب' : 'Unit Type',
                                    items: unitTypes
                                        .map((u) => SearchableDropdownItem<String>(value: u, label: u))
                                        .toList(),
                                    onChanged: (v) => setDlgState(() => selectedUnit = v ?? selectedUnit),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            isArabic ? 'يسمح بالقيمة المجمعة أو المتعددة' : 'Allow Composite / Multi-item',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          value: allowComposite,
                          onChanged: (v) => setDlgState(() => allowComposite = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final payload = {
                      'code': codeController.text.trim().toUpperCase(),
                      'canonical_name_ar': nameArController.text.trim(),
                      'canonical_name_en': nameEnController.text.trim().isEmpty ? null : nameEnController.text.trim(),
                      'category': selectedCategory,
                      'unit_type': selectedUnit,
                      'allow_composite': allowComposite,
                    };

                    bool success;
                    if (isEdit) {
                      success = await ref.read(expenseCatalogProvider.notifier).updateItem(item.code, payload);
                    } else {
                      success = await ref.read(expenseCatalogProvider.notifier).createItem(payload);
                    }

                    if (context.mounted && success) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        AppTheme.snackBar(context, isArabic ? 'تم حفظ بند المصروف بنجاح' : 'Expense item saved successfully', severity: AppSeverity.success),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(isArabic ? 'حفظ' : 'Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Shows the add smart recognition pattern dialog.
  static Future<void> showAddPattern(
    BuildContext context,
    WidgetRef ref,
    ExpenseCatalogModel item,
  ) async {
    final patternController = TextEditingController();
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => SelectionArea(
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'إضافة نمط ذكي للتعرف' : 'Add Recognition Pattern',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isArabic ? 'كود البند:' : 'Item Code:'} ${item.code} — ${isArabic ? item.canonicalNameAr : (item.canonicalNameEn ?? item.canonicalNameAr)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: patternController,
                    decoration: InputDecoration(
                      hintText: isArabic ? 'مثال: أتعاب المخلص، مصاريف إجراءات' : 'e.g. clearance fee, agent fees',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isArabic ? 'إلغاء' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final pattern = patternController.text.trim();
                  if (pattern.isEmpty) return;
                  final success = await ref.read(expenseCatalogProvider.notifier).addPattern(item.code, pattern);
                  if (ctx.mounted && success) {
                    Navigator.of(ctx).pop();
                  }
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(context, isArabic ? 'تم إضافة نمط التعرف بنجاح' : 'Pattern added successfully', severity: AppSeverity.success),
                    );
                  }
                },
                child: Text(isArabic ? 'إضافة النمط' : 'Add Pattern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
