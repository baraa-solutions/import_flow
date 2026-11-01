import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../core/widgets/states/app_loading_state.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../providers/master_items_provider.dart';

const List<String> kStandardCurrencies = [
  'USD',
  'EUR',
  'CNY',
  'GBP',
  'EGP',
  'JPY',
  'TRY',
  'SAR',
  'AED',
];

const List<String> kStandardIncoterms = [
  'FOB',
  'CIF',
  'CFR',
  'EXW',
  'FCA',
  'CPT',
  'CIP',
  'DAP',
  'DDP',
];

/// Form for linking a new overseas supplier to a master item
class AddSupplierMappingForm extends ConsumerStatefulWidget {
  final int itemId;
  final VoidCallback onCancel;
  final VoidCallback onSuccess;

  const AddSupplierMappingForm({
    super.key,
    required this.itemId,
    required this.onCancel,
    required this.onSuccess,
  });

  @override
  ConsumerState<AddSupplierMappingForm> createState() => _AddSupplierMappingFormState();
}

class _AddSupplierMappingFormState extends ConsumerState<AddSupplierMappingForm> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedSupplierId;
  final TextEditingController _partCodeCtrl = TextEditingController();
  final TextEditingController _supplierDescCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _moqCtrl = TextEditingController();
  final TextEditingController _leadTimeCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  String _selectedCurrency = 'USD';
  String? _selectedIncoterm = 'FOB';
  bool _isPreferred = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _partCodeCtrl.dispose();
    _supplierDescCtrl.dispose();
    _priceCtrl.dispose();
    _moqCtrl.dispose();
    _leadTimeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitMapping() async {
    if (_selectedSupplierId == null) {
      AppTheme.snackBar(
        context,
        'يرجى اختيار المورد من القائمة أولاً',
        severity: AppSeverity.warning,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'item_id': widget.itemId,
      'supplier_id': _selectedSupplierId,
      'supplier_item_code': _partCodeCtrl.text.trim().isEmpty ? null : _partCodeCtrl.text.trim(),
      'supplier_description': _supplierDescCtrl.text.trim().isEmpty ? null : _supplierDescCtrl.text.trim(),
      'last_confirmed_price': double.tryParse(_priceCtrl.text),
      'last_confirmed_currency': _selectedCurrency,
      'last_confirmed_date': DateTime.now().toIso8601String().split('T')[0],
      'min_order_qty': double.tryParse(_moqCtrl.text),
      'lead_time_days': int.tryParse(_leadTimeCtrl.text),
      'preferred_incoterm': _selectedIncoterm,
      'is_preferred_supplier': _isPreferred,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      await ref.read(masterItemsProvider.notifier).linkSupplier(payload);
      if (mounted) {
        AppTheme.snackBar(
          context,
          'تم ربط الصنف بالمورد بنجاح وتحديث كتالوج الأسعار',
          severity: AppSeverity.success,
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        AppTheme.snackBar(
          context,
          'تعذر ربط المورد بالصنف: ${e.toString()}',
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
    final suppliersAsync = ref.watch(suppliersProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cobaltBorder),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 16, color: AppTheme.cobalt),
                    SizedBox(width: 6),
                    Text(
                      'ربط مورد جديد وتثبيت كود الصنف وسعر العرض',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'إلغاء النموذج',
                  onPressed: widget.onCancel,
                ),
              ],
            ),
            const Divider(height: 16),

            // Supplier selection
            suppliersAsync.when(
              loading: () => const AppLoadingState.section(),
              error: (e, _) => Text('خطأ تحميل الموردين: $e', style: const TextStyle(color: AppTheme.crimson)),
              data: (suppliers) {
                final supplierItems = suppliers.map((s) {
                  return SearchableDropdownItem<int>(
                    value: s.supplierId ?? 0,
                    label: '${s.supplierCode} — ${s.companyName}',
                    subtitle: '${s.foreignExporterCountry} (${s.foreignExporterCountryCode})',
                  );
                }).toList();

                return SearchableDropdownField<int>(
                  value: _selectedSupplierId,
                  labelText: 'المورد الأجنبي (Foreign Supplier)',
                  hintText: 'اختر المورد من الدليل...',
                  searchHintText: 'ابحث باسم أو كود المورد...',
                  isRequired: true,
                  items: supplierItems,
                  onChanged: (val) => setState(() => _selectedSupplierId = val),
                );
              },
            ),
            const SizedBox(height: 12),

            // Part Code & Supplier Description
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: CustomTextField(
                    controller: _partCodeCtrl,
                    label: 'كود الصنف لدى المورد (Supplier Part #)',
                    hint: 'مثال: MFG-PT-998',
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: CustomTextField(
                    controller: _supplierDescCtrl,
                    label: 'توصيف الصنف في فاتورة المورد (Supplier Description)',
                    hint: 'الوصف كما يرد في الفاتورة المبدئية والكتالوج',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 1: Price, Currency, Incoterm
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: CustomTextField(
                    controller: _priceCtrl,
                    label: 'آخر سعر معتمد للوحدة',
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: _selectedCurrency,
                    labelText: 'العملة',
                    items: kStandardCurrencies.map((c) => SearchableDropdownItem(value: c, label: c)).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCurrency = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: _selectedIncoterm,
                    labelText: 'شرط الشحن',
                    items: kStandardIncoterms.map((i) => SearchableDropdownItem(value: i, label: i)).toList(),
                    onChanged: (val) => setState(() => _selectedIncoterm = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: MOQ & Lead Time
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _moqCtrl,
                    label: 'الحد الأدنى للطلب (MOQ)',
                    hint: 'مثال: 100',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    controller: _leadTimeCtrl,
                    label: 'مدة التوريد (أيام)',
                    hint: 'مثال: 30',
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preferred Supplier Switch & Notes
            Row(
              children: [
                Switch(
                  value: _isPreferred,
                  activeThumbColor: AppTheme.cobalt,
                  onChanged: (val) => setState(() => _isPreferred = val),
                ),
                const SizedBox(width: 6),
                const Text('تعيين كمورد مفضل (Preferred Supplier) لهذا الصنف', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),

            CustomTextField(
              controller: _notesCtrl,
              label: 'ملاحظات تسعير أو خصومات كميات',
              hint: 'مثال: خصم 5% عند طلب أكثر من حاوية 40 قدم',
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'إلغاء',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: widget.onCancel,
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'تثبيت ربط المورد',
                  icon: Icons.save_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _submitMapping,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
