import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/master_item_model.dart';
import '../providers/master_items_provider.dart';

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

/// Dialog for managing Overseas Supplier Linkages and Part Numbers for a Master Item
class ItemSupplierMappingDialog extends ConsumerStatefulWidget {
  final MasterItemModel item;

  const ItemSupplierMappingDialog({
    super.key,
    required this.item,
  });

  /// Static helper to open the dialog
  static Future<void> show(
    BuildContext context, {
    required MasterItemModel item,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ItemSupplierMappingDialog(item: item),
    );
  }

  @override
  ConsumerState<ItemSupplierMappingDialog> createState() => _ItemSupplierMappingDialogState();
}

class _ItemSupplierMappingDialogState extends ConsumerState<ItemSupplierMappingDialog> {
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
  bool _showAddForm = false;

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

  void _resetForm() {
    setState(() {
      _selectedSupplierId = null;
      _partCodeCtrl.clear();
      _supplierDescCtrl.clear();
      _priceCtrl.clear();
      _moqCtrl.clear();
      _leadTimeCtrl.clear();
      _notesCtrl.clear();
      _selectedCurrency = 'USD';
      _selectedIncoterm = 'FOB';
      _isPreferred = false;
      _showAddForm = false;
    });
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
      'item_id': widget.item.itemId,
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
        _resetForm();
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
    final linkedSuppliersAsync = ref.watch(itemSuppliersProvider(widget.item.itemId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 880,
            maxHeight: 740,
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
                            child: const Icon(
                              Icons.link_rounded,
                              color: AppTheme.cobalt,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'ربط أكواد الموردين وكتالوج الأسعار: ${widget.item.itemCode}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobalt,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        widget.item.defaultUom,
                                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  widget.item.descriptionAr,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Body ─────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Linked Suppliers List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.business_outlined, size: 18, color: AppTheme.cobalt),
                              const SizedBox(width: 6),
                              const Text(
                                'الموردون المرتبطون بهذا الصنف',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              linkedSuppliersAsync.maybeWhen(
                                data: (list) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${list.length} مورد',
                                    style: const TextStyle(
                                      color: AppTheme.cobalt,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          if (!_showAddForm)
                            AppButton(
                              label: 'ربط مورد جديد',
                              icon: Icons.add_link_rounded,
                              variant: AppButtonVariant.primary,
                              size: AppButtonSize.small,
                              onPressed: () => setState(() => _showAddForm = true),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Linked Suppliers Table or Empty State
                      linkedSuppliersAsync.when(
                        loading: () => const AppLoadingState.section(),
                        error: (err, _) => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.crimson.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'خطأ أثناء تحميل الموردين المرتبطين: $err',
                            style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                          ),
                        ),
                        data: (catalogs) {
                          if (catalogs.isEmpty) {
                            return const AppEmptyState(
                              message: 'لا يوجد موردون مسجلون لهذا الصنف حالياً',
                              subtitle: 'قم بالنقر على "ربط مورد جديد" لإضافة كود المورد وعرض السعر المعتمد.',
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCardBackground : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.6),
                                1: FlexColumnWidth(2.2),
                                2: FlexColumnWidth(2.0),
                                3: FlexColumnWidth(1.4),
                                4: FlexColumnWidth(1.4),
                                5: FlexColumnWidth(1.8),
                              },
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                  width: 0.8,
                                ),
                              ),
                              children: [
                                // Table Header
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  ),
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Text(
                                        'المورد الأجنبي',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Text(
                                        'كود الصنف عند المورد (Part #)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Text(
                                        'آخر سعر شراء معتمد',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Text(
                                        'شرط الشحن (Incoterm)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Text(
                                        'مدة التوريد (أيام)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Text(
                                        'المورد المفضل',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                // Rows
                                ...catalogs.map((cat) {
                                  return TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          cat.supplierName ?? 'مورد #${cat.supplierId}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          cat.supplierItemCode ?? '—',
                                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          cat.lastConfirmedPrice != null
                                              ? '${cat.lastConfirmedPrice!.toStringAsFixed(2)} ${cat.lastConfirmedCurrency}'
                                              : '—',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.emerald,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          cat.preferredIncoterm ?? '—',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          cat.leadTimeDays != null ? '${cat.leadTimeDays} يوم' : '—',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: cat.isPreferredSupplier
                                            ? const FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: AlignmentDirectional.centerStart,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                                    SizedBox(width: 4),
                                                    Text('المفضل', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                                                  ],
                                                ),
                                              )
                                            : const Text('—', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Section 2: Form to Link New Supplier (Toggled)
                      if (_showAddForm) ...[
                        Container(
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
                                      onPressed: () => setState(() => _showAddForm = false),
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
                                      onPressed: () => setState(() => _showAddForm = false),
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
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Footer ───────────────────────────────────────────
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
                      label: 'إغلاق',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: () => Navigator.of(context).pop(),
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
}
