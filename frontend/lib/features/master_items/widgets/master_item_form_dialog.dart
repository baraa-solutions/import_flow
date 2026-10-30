import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../models/master_item_model.dart';
import '../providers/master_items_provider.dart';

/// Standard UOM items for Master Items catalog
const List<Map<String, String>> kStandardUoms = [
  {'code': 'PCS', 'nameAr': 'قطعة', 'nameEn': 'Piece (PCS)'},
  {'code': 'KG', 'nameAr': 'كيلوجرام', 'nameEn': 'Kilogram (KG)'},
  {'code': 'TON', 'nameAr': 'طن', 'nameEn': 'Ton (TON)'},
  {'code': 'MTR', 'nameAr': 'متر طولي', 'nameEn': 'Meter (MTR)'},
  {'code': 'M2', 'nameAr': 'متر مربع', 'nameEn': 'Square Meter (M2)'},
  {'code': 'M3', 'nameAr': 'متر مكعب', 'nameEn': 'Cubic Meter (M3)'},
  {'code': 'SET', 'nameAr': 'طقم', 'nameEn': 'Set (SET)'},
  {'code': 'ROLL', 'nameAr': 'رول', 'nameEn': 'Roll (ROLL)'},
  {'code': 'BOX', 'nameAr': 'صندوق', 'nameEn': 'Box (BOX)'},
  {'code': 'CARTON', 'nameAr': 'كرتونة', 'nameEn': 'Carton (CTN)'},
  {'code': 'PALLET', 'nameAr': 'بالتة', 'nameEn': 'Pallet (PLT)'},
  {'code': 'LTR', 'nameAr': 'لتر', 'nameEn': 'Liter (LTR)'},
];

/// Standard Packaging Types
const List<Map<String, String>> kStandardPkgTypes = [
  {'code': 'Carton', 'nameAr': 'كرتونة', 'nameEn': 'Carton'},
  {'code': 'Pallet', 'nameAr': 'بالتة', 'nameEn': 'Pallet'},
  {'code': 'Wooden Box', 'nameAr': 'صندوق خشب', 'nameEn': 'Wooden Box'},
  {'code': 'Bag', 'nameAr': 'شيكارة', 'nameEn': 'Bag'},
  {'code': 'Drum', 'nameAr': 'برميل', 'nameEn': 'Drum'},
  {'code': 'Bundle', 'nameAr': 'حزمة', 'nameEn': 'Bundle'},
  {'code': 'Steel Cage', 'nameAr': 'قفص حديدي', 'nameEn': 'Steel Cage'},
  {'code': 'Bulk', 'nameAr': 'شحنة صب', 'nameEn': 'Bulk'},
];

/// Standard Product Categories
const List<String> kStandardCategories = [
  'Raw Materials',
  'Spare Parts',
  'Finished Goods',
  'Machinery & Equipment',
  'Chemicals',
  'Electronics',
  'Packaging',
  'General Cargo',
];

/// Form Dialog for Adding and Editing Master Items
class MasterItemFormDialog extends ConsumerStatefulWidget {
  final MasterItemModel? itemToEdit;

  const MasterItemFormDialog({
    super.key,
    this.itemToEdit,
  });

  /// Static helper to show dialog
  static Future<bool?> show(
    BuildContext context, {
    MasterItemModel? itemToEdit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MasterItemFormDialog(itemToEdit: itemToEdit),
    );
  }

  @override
  ConsumerState<MasterItemFormDialog> createState() => _MasterItemFormDialogState();
}

class _MasterItemFormDialogState extends ConsumerState<MasterItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _itemCodeCtrl;
  late final TextEditingController _descArCtrl;
  late final TextEditingController _descEnCtrl;
  late final TextEditingController _cbmCtrl;
  late final TextEditingController _grossWeightCtrl;
  late final TextEditingController _netWeightCtrl;
  late final TextEditingController _subCategoryCtrl;
  late final TextEditingController _notesCtrl;

  int? _selectedTariffId;
  String _selectedUom = 'PCS';
  String _selectedPkgType = 'Carton';
  String? _selectedCategory;
  bool _isActive = true;
  bool _isSaving = false;

  bool get isEditMode => widget.itemToEdit != null;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _itemCodeCtrl = TextEditingController(text: item?.itemCode ?? '');
    _descArCtrl = TextEditingController(text: item?.descriptionAr ?? '');
    _descEnCtrl = TextEditingController(text: item?.descriptionEn ?? '');
    _cbmCtrl = TextEditingController(text: item != null ? item.cbmPerUnit.toString() : '0.0');
    _grossWeightCtrl = TextEditingController(text: item != null ? item.grossWeightKg.toString() : '0.0');
    _netWeightCtrl = TextEditingController(text: item != null ? item.netWeightKg.toString() : '0.0');
    _subCategoryCtrl = TextEditingController(text: item?.productSubcategory ?? '');
    _notesCtrl = TextEditingController(text: item?.notes ?? '');

    _selectedTariffId = item?.tariffId;
    _selectedUom = item?.defaultUom ?? 'PCS';
    _selectedPkgType = item?.defaultPkgType ?? 'Carton';
    _selectedCategory = item?.productCategory;
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _itemCodeCtrl.dispose();
    _descArCtrl.dispose();
    _descEnCtrl.dispose();
    _cbmCtrl.dispose();
    _grossWeightCtrl.dispose();
    _netWeightCtrl.dispose();
    _subCategoryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'item_code': _itemCodeCtrl.text.trim(),
      'description_ar': _descArCtrl.text.trim(),
      'description_en': _descEnCtrl.text.trim().isEmpty ? null : _descEnCtrl.text.trim(),
      'tariff_id': _selectedTariffId,
      'default_uom': _selectedUom,
      'default_pkg_type': _selectedPkgType,
      'cbm_per_unit': double.tryParse(_cbmCtrl.text) ?? 0.0,
      'gross_weight_kg': double.tryParse(_grossWeightCtrl.text) ?? 0.0,
      'net_weight_kg': double.tryParse(_netWeightCtrl.text) ?? 0.0,
      'product_category': _selectedCategory,
      'product_subcategory': _subCategoryCtrl.text.trim().isEmpty ? null : _subCategoryCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'is_active': _isActive,
    };

    try {
      if (isEditMode) {
        await ref.read(masterItemsProvider.notifier).updateItem(
              widget.itemToEdit!.itemId,
              payload,
            );
        if (mounted) {
          AppTheme.snackBar(
            context,
            'تم تحديث الصنف "${_itemCodeCtrl.text}" بنجاح',
            severity: AppSeverity.success,
          );
          Navigator.of(context).pop(true);
        }
      } else {
        await ref.read(masterItemsProvider.notifier).createItem(payload);
        if (mounted) {
          AppTheme.snackBar(
            context,
            'تم إضافة الصنف "${_itemCodeCtrl.text}" إلى الكتالوج بنجاح',
            severity: AppSeverity.success,
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppTheme.snackBar(
          context,
          'فشل حفظ بيانات الصنف: ${e.toString()}',
          severity: AppSeverity.danger,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final tariffsAsync = ref.watch(customsTariffProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 780,
            maxHeight: 700,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141A22) : AppTheme.charcoal,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppTheme.darkBorder : AppTheme.cobaltBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isEditMode ? Icons.edit_note_rounded : Icons.add_box_outlined,
                              color: AppTheme.cobalt,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditMode
                                      ? 'تعديل بيانات الصنف: ${widget.itemToEdit!.itemCode}'
                                      : 'إضافة صنف مرجعي جديد للكتالوج',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const Text(
                                  'توحيد توصيف البضائع، التعريفة الجمركية، ومعايير الشحن والتعبئة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      tooltip: 'إغلاق',
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),

              // ── Form Body ─────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Row 1: Item Code & Category
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: CustomTextField(
                                controller: _itemCodeCtrl,
                                label: isArabic ? 'كود الصنف الداخلي' : 'Internal Item SKU',
                                hint: 'مثال: PET-RAW-001',
                                isRequired: true,
                                textDirection: TextDirection.ltr,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'كود الصنف إلزامي';
                                  }
                                  if (v.trim().length < 2) {
                                    return 'كود الصنف يجب أن يتكون من حرفين على الأقل';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 5,
                              child: SearchableDropdownField<String>(
                                value: _selectedCategory,
                                labelText: isArabic ? 'فئة الصنف' : 'Product Category',
                                hintText: isArabic ? 'اختر الفئة الرئيسية...' : 'Select main category...',
                                items: kStandardCategories.map((cat) {
                                  return SearchableDropdownItem(
                                    value: cat,
                                    label: isArabic ? _getCategoryAr(cat) : cat,
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedCategory = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row 2: Arabic Description
                        CustomTextField(
                          controller: _descArCtrl,
                          label: isArabic ? 'الوصف العربي المعتمد' : 'Approved Arabic Description',
                          hint: isArabic ? 'اسم وتوصيف البضاعة بالعربية للمستندات الجمركية ونموذج 46' : 'Arabic goods description for customs and Form 46',
                          isRequired: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return isArabic ? 'الوصف العربي إلزامي للجمارك والتخليص' : 'Arabic description is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Row 3: English Description
                        CustomTextField(
                          controller: _descEnCtrl,
                          label: isArabic ? 'الوصف الإنجليزي' : 'English Description',
                          hint: 'Commercial invoice English description for overseas suppliers',
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(height: 14),

                        // Row 4: Customs Tariff Dropdown (Searchable)
                        tariffsAsync.when(
                          loading: () => const AppLoadingState.section(),
                          error: (e, _) => Text(
                            'تعذر تحميل قائمة التعريفة الجمركية: $e',
                            style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                          ),
                          data: (tariffs) {
                            final tariffItems = tariffs.map((t) {
                              return SearchableDropdownItem<int>(
                                value: t.tariffId,
                                label: '${t.hsCode} — ${t.hsDescription}',
                                subtitle: 'ضريبة جمركية: ${t.customsDutyRate}% | ق.م: ${t.vatRate}% | ض.جدول: ${t.scheduleTaxRate}%',
                              );
                            }).toList();

                            // Find selected tariff to show preview card
                            CustomsTariffModel? selectedTariff;
                            if (_selectedTariffId != null) {
                              try {
                                selectedTariff = tariffs.firstWhere((t) => t.tariffId == _selectedTariffId);
                              } catch (_) {}
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SearchableDropdownField<int>(
                                  value: _selectedTariffId,
                                  labelText: isArabic ? 'بند التعريفة الجمركية' : 'Customs Tariff (HS Code)',
                                  hintText: isArabic ? 'ابحث برقم البند أو الوصف الجمركي...' : 'Search by HS code or description...',
                                  searchHintText: isArabic ? 'ابحث برقم البند الجمركي أو الاسم...' : 'Search by HS code or name...',
                                  items: tariffItems,
                                  onChanged: (val) {
                                    setState(() => _selectedTariffId = val);
                                  },
                                ),
                                if (selectedTariff != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.cobaltBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.verified_outlined, size: 16, color: AppTheme.cobalt),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'البند المختار: ${selectedTariff.hsCode} | جمارك: ${selectedTariff.customsDutyRate}% | ق.م: ${selectedTariff.vatRate}% | رسوم تنمية: ${selectedTariff.developmentFeeRate}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.cobalt,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Row 5: UOM & Packaging Type
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _selectedUom,
                                labelText: isArabic ? 'وحدة القياس القياسية' : 'Standard UOM',
                                items: kStandardUoms.map((u) {
                                  return SearchableDropdownItem(
                                    value: u['code']!,
                                    label: isArabic ? u['nameAr']! : u['nameEn']!,
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedUom = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: SearchableDropdownField<String>(
                                value: _selectedPkgType,
                                labelText: isArabic ? 'نوع التعبئة القياسي' : 'Standard Packaging Type',
                                items: kStandardPkgTypes.map((p) {
                                  return SearchableDropdownItem(
                                    value: p['code']!,
                                    label: isArabic ? p['nameAr']! : p['nameEn']!,
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedPkgType = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row 6: Dimensions & Weights (CBM, Gross Weight, Net Weight)
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _cbmCtrl,
                                label: isArabic ? 'الحجم للوحدة (م³)' : 'Unit Volume (CBM)',
                                hint: '0.000',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _grossWeightCtrl,
                                label: isArabic ? 'الوزن القائم للوحدة (كجم)' : 'Unit Gross Weight (kg)',
                                hint: '0.00',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: _netWeightCtrl,
                                label: isArabic ? 'الوزن الصافي للوحدة (كجم)' : 'Unit Net Weight (kg)',
                                hint: '0.00',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textDirection: TextDirection.ltr,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row 7: Subcategory & Notes
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: CustomTextField(
                                controller: _subCategoryCtrl,
                                label: isArabic ? 'الفئة الفرعية' : 'Subcategory',
                                hint: 'مثال: قطع ميكانيكية، حبيبات بوليمر',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 6,
                              child: CustomTextField(
                                controller: _notesCtrl,
                                label: 'ملاحظات تشغيلية ومواصفات',
                                hint: 'أي اشتراطات فحص مسبق أو متطلبات خاصة بالصنف',
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Status switch in edit mode
                        if (isEditMode) ...[
                          Row(
                            children: [
                              Switch(
                                value: _isActive,
                                activeThumbColor: AppTheme.cobalt,
                                onChanged: (val) => setState(() => _isActive = val),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isActive ? 'الصنف مفعّل ونشط في الكتالوج' : 'الصنف معطل ومؤرشف مؤقتاً',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isActive ? AppTheme.emerald : AppTheme.crimson,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── Action Buttons Footer ─────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: 'إلغاء',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: isEditMode ? 'حفظ التعديلات' : 'إضافة الصنف للكتالوج',
                      icon: isEditMode ? Icons.check_circle_outline : Icons.add,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submitForm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryAr(String cat) {
    switch (cat) {
      case 'Raw Materials':
        return 'مواد خام';
      case 'Spare Parts':
        return 'قطع غيار';
      case 'Finished Goods':
        return 'بضائع تامة الصنع';
      case 'Machinery & Equipment':
        return 'آلات ومعدات';
      case 'Chemicals':
        return 'كيماويات';
      case 'Electronics':
        return 'إلكترونيات';
      case 'Packaging':
        return 'مواد تغليف';
      case 'General Cargo':
        return 'بضائع عامة';
      default:
        return cat;
    }
  }
}
