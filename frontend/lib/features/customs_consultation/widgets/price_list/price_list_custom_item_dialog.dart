import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/customs_consultation_provider.dart';
import 'price_list_match_helper.dart';

/// Modal dialog for adding custom expense items or linking them as aliases to the catalog.
class PriceListCustomItemDialog extends StatefulWidget {
  final WidgetRef ref;
  final String? initialName;
  final String? initialCategory;
  final double? initialPrice;
  final Map<String, dynamic>? targetItem;
  final void Function(Map<String, dynamic> itemData) onItemSaved;

  const PriceListCustomItemDialog({
    super.key,
    required this.ref,
    this.initialName,
    this.initialCategory,
    this.initialPrice,
    this.targetItem,
    required this.onItemSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    String? initialName,
    String? initialCategory,
    double? initialPrice,
    Map<String, dynamic>? targetItem,
    required void Function(Map<String, dynamic> itemData) onItemSaved,
  }) async {
    await showDialog(
      context: context,
      builder: (c) => PriceListCustomItemDialog(
        ref: ref,
        initialName: initialName,
        initialCategory: initialCategory,
        initialPrice: initialPrice,
        targetItem: targetItem,
        onItemSaved: onItemSaved,
      ),
    );
  }

  @override
  State<PriceListCustomItemDialog> createState() => _PriceListCustomItemDialogState();
}

class _PriceListCustomItemDialogState extends State<PriceListCustomItemDialog> {
  final _formKey = GlobalKey<FormState>();
  int _activeMode = 0; // 0 = Map as alias, 1 = Register new code
  bool _isSubmitting = false;

  late final TextEditingController _aliasPatternCtrl;
  late final TextEditingController _customPriceCtrl;
  late final TextEditingController _customNotesCtrl;
  late final TextEditingController _customCodeCtrl;
  late final TextEditingController _newNameArCtrl;
  late final TextEditingController _newNameEnCtrl;

  String? _selectedCanonicalCode;
  String _selectedReferenceCode = 'OTHER-CLIENT-PAID';
  String _newCategory = 'Other Fees';
  String _newUnit = 'fixed';
  String _customCurrency = 'EGP';

  @override
  void initState() {
    super.initState();
    _aliasPatternCtrl = TextEditingController(text: widget.initialName ?? '');
    _customPriceCtrl = TextEditingController(
      text: widget.initialPrice != null && widget.initialPrice! > 0
          ? widget.initialPrice!.toStringAsFixed(0)
          : '',
    );
    _customNotesCtrl = TextEditingController();
    _customCodeCtrl = TextEditingController();
    _newNameArCtrl = TextEditingController(text: widget.initialName ?? '');
    _newNameEnCtrl = TextEditingController();

    _newCategory = widget.initialCategory ?? 'Other Fees';

    final initialLower = (widget.initialName ?? '').toLowerCase();
    if (initialLower.contains('نقل') || initialLower.contains('شاحن') || initialLower.contains('سيارة') || initialLower.contains('تريلا')) {
      _selectedReferenceCode = 'INL-CUSTOM-TRK';
      _newCategory = 'Inland Transport';
      _newUnit = 'per_truck';
    } else if (initialLower.contains('أتعاب') || initialLower.contains('اتعاب') || initialLower.contains('تخليص')) {
      _selectedReferenceCode = 'CLR-CUSTOM-FEE';
      _newCategory = 'Clearance Fees';
      _newUnit = 'per_shipment';
    } else if (initialLower.contains('أرضيات') || initialLower.contains('ارضيات') || initialLower.contains('حراسة') || initialLower.contains('غرامات') || initialLower.contains('تأخير')) {
      _selectedReferenceCode = 'OTHER-STORAGE';
      _newCategory = 'Other Fees';
      _newUnit = 'per_day';
    } else if (initialLower.contains('عمال') || initialLower.contains('كلارك') || initialLower.contains('تعتيق')) {
      _selectedReferenceCode = 'OTHER-LABOR';
      _newCategory = 'Port & Handling';
      _newUnit = 'fixed';
    } else if (initialLower.contains('موانئ') || initialLower.contains('ابوقير') || initialLower.contains('محطة') || initialLower.contains('تفريغ') || initialLower.contains('ساحة')) {
      _selectedReferenceCode = 'PORT-CUSTOM-EXP';
      _newCategory = 'Port & Handling';
      _newUnit = 'per_container';
    } else if (initialLower.contains('موافقة') || initialLower.contains('إجراء') || initialLower.contains('فحص') || initialLower.contains('زراعة') || initialLower.contains('واردات')) {
      _selectedReferenceCode = 'PROC-CUSTOM-DOC';
      _newCategory = 'Procedures & Approvals';
      _newUnit = 'fixed';
    } else if (initialLower.contains('عمول') || initialLower.contains('نثريات') || initialLower.contains('إكرام')) {
      _selectedReferenceCode = 'OTHER-COMMISSION';
      _newCategory = 'Other Fees';
      _newUnit = 'fixed';
    }

    final catalogItems = widget.ref.read(expenseCatalogProvider).valueOrNull ?? [];
    if (catalogItems.isNotEmpty) {
      _selectedCanonicalCode = catalogItems.first.code;
    }
  }

  @override
  void dispose() {
    _aliasPatternCtrl.dispose();
    _customPriceCtrl.dispose();
    _customNotesCtrl.dispose();
    _customCodeCtrl.dispose();
    _newNameArCtrl.dispose();
    _newNameEnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final catalogItems = widget.ref.read(expenseCatalogProvider).valueOrNull ?? [];

    final referenceCodeItems = <SearchableDropdownItem<String>>[
      SearchableDropdownItem(
        value: 'OTHER-CLIENT-PAID',
        label: 'OTHER-CLIENT-PAID — ${context.l10n.ccClientPaidExpenses}',
        subtitle: '${getCategoryLabel("Other Fees", context)} | ${getUnitLabel("fixed", context)}',
        icon: Icons.person_pin_outlined,
      ),
      SearchableDropdownItem(
        value: 'OTHER-FEES',
        label: 'OTHER-FEES — ${context.l10n.ccGeneralOtherFees}',
        subtitle: '${getCategoryLabel("Other Fees", context)} | ${getUnitLabel("fixed", context)}',
        icon: Icons.attach_money_rounded,
      ),
      SearchableDropdownItem(
        value: 'OTHER-STORAGE',
        label: 'OTHER-STORAGE — ${context.l10n.ccStorageDemurrage}',
        subtitle: '${getCategoryLabel("Other Fees", context)} | ${getUnitLabel("per_day", context)}',
        icon: Icons.warehouse_rounded,
      ),
      SearchableDropdownItem(
        value: 'OTHER-LABOR',
        label: 'OTHER-LABOR — ${context.l10n.ccLaborHandling}',
        subtitle: '${getCategoryLabel("Port & Handling", context)} | ${getUnitLabel("fixed", context)}',
        icon: Icons.handyman_rounded,
      ),
      SearchableDropdownItem(
        value: 'OTHER-COMMISSION',
        label: 'OTHER-COMMISSION — ${context.l10n.ccCommissionsTips}',
        subtitle: '${getCategoryLabel("Other Fees", context)} | ${getUnitLabel("fixed", context)}',
        icon: Icons.local_activity_rounded,
      ),
      SearchableDropdownItem(
        value: 'CLR-CUSTOM-FEE',
        label: 'CLR-CUSTOM-FEE — ${context.l10n.ccExceptionalClearanceFee}',
        subtitle: '${getCategoryLabel("Clearance Fees", context)} | ${getUnitLabel("per_shipment", context)}',
        icon: Icons.receipt_long_rounded,
      ),
      SearchableDropdownItem(
        value: 'INL-CUSTOM-TRK',
        label: 'INL-CUSTOM-TRK — ${context.l10n.ccInlandTransportCustom}',
        subtitle: '${getCategoryLabel("Inland Transport", context)} | ${getUnitLabel("per_truck", context)}',
        icon: Icons.local_shipping_rounded,
      ),
      SearchableDropdownItem(
        value: 'PROC-CUSTOM-DOC',
        label: 'PROC-CUSTOM-DOC — ${context.l10n.ccAdditionalApprovals}',
        subtitle: '${getCategoryLabel("Procedures & Approvals", context)} | ${getUnitLabel("fixed", context)}',
        icon: Icons.verified_user_rounded,
      ),
      SearchableDropdownItem(
        value: 'PORT-CUSTOM-EXP',
        label: 'PORT-CUSTOM-EXP — ${context.l10n.ccPortTerminalExpenses}',
        subtitle: '${getCategoryLabel("Port & Handling", context)} | ${getUnitLabel("per_container", context)}',
        icon: Icons.anchor_rounded,
      ),
      ...catalogItems.map((ci) => SearchableDropdownItem<String>(
            value: ci.code,
            label: '${ci.code} — ${isAr ? ci.canonicalNameAr : (ci.canonicalNameEn?.isNotEmpty == true ? ci.canonicalNameEn! : ci.canonicalNameAr)}',
            subtitle: '${getCategoryLabel(ci.category, context)} | ${getUnitLabel(ci.unitType, context)}',
            icon: Icons.qr_code_rounded,
          )),
      SearchableDropdownItem(
        value: 'CUSTOM',
        label: context.l10n.ccNewCustomReferenceCode,
        subtitle: context.l10n.ccEnterCustomCodeManually,
        icon: Icons.edit_note_rounded,
      ),
    ];

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2, color: AppTheme.cobalt, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.customsExpenseCodingTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 530,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode switch
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _activeMode = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeMode == 0 ? AppTheme.cobalt : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  l.linkAsAliasTab,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _activeMode == 0 ? AppTheme.white : AppTheme.charcoal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _activeMode = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeMode == 1 ? AppTheme.cobalt : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  l.registerNewCatalogCodeTab,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _activeMode == 1 ? AppTheme.white : AppTheme.charcoal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_activeMode == 0) ...[
                    SearchableDropdownField<String?>(
                      value: _selectedCanonicalCode,
                      labelText: l.approvedCatalogItemLabel,
                      searchHintText: l.searchApprovedCatalogHint,
                      items: catalogItems
                          .map((ci) => SearchableDropdownItem<String?>(
                                value: ci.code,
                                label: '${ci.code} — ${isAr ? ci.canonicalNameAr : (ci.canonicalNameEn?.isNotEmpty == true ? ci.canonicalNameEn! : ci.canonicalNameAr)}',
                                subtitle: '${getCategoryLabel(ci.category, context)} | ${getUnitLabel(ci.unitType, context)}',
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCanonicalCode = v),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _aliasPatternCtrl,
                      validator: (v) => (v == null || v.trim().isEmpty) ? l.documentAliasLabel : null,
                      decoration: InputDecoration(
                        labelText: l.documentAliasLabel,
                        hintText: l.documentAliasHint,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    SearchableDropdownField<String>(
                      value: _selectedReferenceCode,
                      labelText: l.referenceItemCodeLabel,
                      searchHintText: l.searchReferenceCodeHint,
                      items: referenceCodeItems,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _selectedReferenceCode = v;
                          if (v == 'OTHER-CLIENT-PAID') {
                            _newCategory = 'Other Fees';
                            _newUnit = 'fixed';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'مصاريف مؤداة بمعرفة العميل';
                            if (_newNameEnCtrl.text.isEmpty) _newNameEnCtrl.text = 'Client-Paid Expenses';
                          } else if (v == 'OTHER-FEES') {
                            _newCategory = 'Other Fees';
                            _newUnit = 'fixed';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'مصاريف ورسوم إضافية';
                          } else if (v == 'OTHER-STORAGE') {
                            _newCategory = 'Other Fees';
                            _newUnit = 'per_day';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'أرضيات وحراسات وتخزين';
                          } else if (v == 'OTHER-LABOR') {
                            _newCategory = 'Port & Handling';
                            _newUnit = 'fixed';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'عمالة وتعتيق وكلارك';
                          } else if (v == 'OTHER-COMMISSION') {
                            _newCategory = 'Other Fees';
                            _newUnit = 'fixed';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'عمولات ونثريات وإكراميات';
                          } else if (v == 'CLR-CUSTOM-FEE') {
                            _newCategory = 'Clearance Fees';
                            _newUnit = 'per_shipment';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'أتعاب تخليص إضافية استثنائية';
                          } else if (v == 'INL-CUSTOM-TRK') {
                            _newCategory = 'Inland Transport';
                            _newUnit = 'per_truck';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'نقل داخلي وشاحنة إضافية';
                          } else if (v == 'PROC-CUSTOM-DOC') {
                            _newCategory = 'Procedures & Approvals';
                            _newUnit = 'fixed';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'إجراءات وموافقات رقابية إضافية';
                          } else if (v == 'PORT-CUSTOM-EXP') {
                            _newCategory = 'Port & Handling';
                            _newUnit = 'per_container';
                            if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = 'مصاريف موانئ ومحطات إضافية';
                          } else {
                            final matched = catalogItems.where((ci) => ci.code == v).firstOrNull;
                            if (matched != null) {
                              _newCategory = matched.category;
                              _newUnit = matched.unitType;
                              if (_newNameArCtrl.text.isEmpty) _newNameArCtrl.text = matched.canonicalNameAr;
                              if (_newNameEnCtrl.text.isEmpty && matched.canonicalNameEn != null) {
                                _newNameEnCtrl.text = matched.canonicalNameEn!;
                              }
                            }
                          }
                        });
                      },
                    ),
                    if (_selectedReferenceCode == 'CUSTOM') ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _customCodeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) {
                          if (_selectedReferenceCode != 'CUSTOM') return null;
                          if (v == null || v.trim().isEmpty) return l.selectReferenceCodeRequired;
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: l.referenceItemCodeLabel,
                          hintText: 'OTHER-SPECIAL-01',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SearchableDropdownField<String>(
                            value: _newCategory,
                            labelText: l.officialCategoryLabel,
                            items: [
                              SearchableDropdownItem(value: 'Clearance Fees', label: getCategoryLabel('Clearance Fees', context)),
                              SearchableDropdownItem(value: 'Procedures & Approvals', label: getCategoryLabel('Procedures & Approvals', context)),
                              SearchableDropdownItem(value: 'Inland Transport', label: getCategoryLabel('Inland Transport', context)),
                              SearchableDropdownItem(value: 'Port & Handling', label: getCategoryLabel('Port & Handling', context)),
                              SearchableDropdownItem(value: 'Other Fees', label: getCategoryLabel('Other Fees', context)),
                            ],
                            onChanged: (v) => setState(() => _newCategory = v ?? _newCategory),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: SearchableDropdownField<String>(
                            value: _newUnit,
                            labelText: l.unitTypeLabel,
                            items: [
                              SearchableDropdownItem(value: 'fixed', label: getUnitLabel('fixed', context)),
                              SearchableDropdownItem(value: 'per_container', label: getUnitLabel('per_container', context)),
                              SearchableDropdownItem(value: 'per_invoice', label: getUnitLabel('per_invoice', context)),
                              SearchableDropdownItem(value: 'per_ton', label: getUnitLabel('per_ton', context)),
                              SearchableDropdownItem(value: 'per_truck', label: getUnitLabel('per_truck', context)),
                              SearchableDropdownItem(value: 'per_day', label: getUnitLabel('per_day', context)),
                              SearchableDropdownItem(value: 'per_shipment', label: getUnitLabel('per_shipment', context)),
                              SearchableDropdownItem(value: 'per_declaration', label: getUnitLabel('per_declaration', context)),
                              SearchableDropdownItem(value: 'per_bl', label: getUnitLabel('per_bl', context)),
                            ],
                            onChanged: (v) => setState(() => _newUnit = v ?? _newUnit),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _newNameArCtrl,
                      validator: (v) => (v == null || v.trim().isEmpty) ? l.fillApprovedArabicNameRequired : null,
                      decoration: InputDecoration(
                        labelText: l.canonicalArabicNameLabel,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _newNameEnCtrl,
                      decoration: InputDecoration(
                        labelText: l.canonicalEnglishNameOptionalLabel,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return l.pleaseEnterItemPrice;
                            if (double.tryParse(v.trim()) == null) return l.invalidItemPrice;
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: l.approvedPriceLabel,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: SearchableDropdownField<String>(
                          value: _customCurrency,
                          items: const [
                            SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                            SearchableDropdownItem(value: 'USD', label: 'USD'),
                            SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                          ],
                          onChanged: (v) => setState(() => _customCurrency = v ?? 'EGP'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customNotesCtrl,
                    decoration: InputDecoration(
                      labelText: l.itemNotesAndConditionsLabel,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
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
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: _activeMode == 0 ? l.saveAndMapAliasBtn : l.registerCodeInCatalogBtn,
            icon: Icons.check,
            variant: AppButtonVariant.success,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final price = double.tryParse(_customPriceCtrl.text.trim()) ?? 0.0;
    final catalogItems = widget.ref.read(expenseCatalogProvider).valueOrNull ?? [];

    if (_activeMode == 0) {
      final code = _selectedCanonicalCode;
      final alias = _aliasPatternCtrl.text.trim();
      if (code != null && alias.isNotEmpty) {
        try {
          await widget.ref.read(expenseCatalogProvider.notifier).addPattern(code, alias);
          final matchedCatItem = catalogItems.where((it) => it.code == code).firstOrNull ??
              (catalogItems.isNotEmpty ? catalogItems.first : null);

          widget.onItemSaved({
            'code': code,
            'expense_name': alias,
            'canonical_name_ar': matchedCatItem?.canonicalNameAr ?? alias,
            'category': matchedCatItem?.category ?? 'Other Fees',
            'unit_type': matchedCatItem?.unitType ?? 'fixed',
            'standard_price': price,
            'currency': _customCurrency,
            'notes': _customNotesCtrl.text.trim(),
            'is_uncoded': false,
            'is_active': true,
          });

          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(
                context,
                l.itemCodedSuccessfullyToast(alias, code),
                severity: AppSeverity.success,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger),
            );
          }
        }
      }
    } else {
      final finalCode = _selectedReferenceCode == 'CUSTOM'
          ? _customCodeCtrl.text.trim().toUpperCase()
          : _selectedReferenceCode.trim().toUpperCase();

      if (finalCode.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.selectReferenceCodeRequired, severity: AppSeverity.danger),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      final nameAr = _newNameArCtrl.text.trim();
      final nameEn = _newNameEnCtrl.text.trim();
      final isAlreadyInCatalog = catalogItems.any((ci) => ci.code.toUpperCase() == finalCode);

      try {
        if (isAlreadyInCatalog) {
          if (nameAr.isNotEmpty) {
            await widget.ref.read(expenseCatalogProvider.notifier).addPattern(finalCode, nameAr);
          }
        } else {
          await widget.ref.read(expenseCatalogProvider.notifier).createItem({
            'code': finalCode,
            'canonical_name_ar': nameAr,
            if (nameEn.isNotEmpty) 'canonical_name_en': nameEn,
            'category': _newCategory,
            'unit_type': _newUnit,
            'allow_composite': false,
            'recognition_patterns': [nameAr],
          });
        }

        widget.onItemSaved({
          'code': finalCode,
          'expense_name': nameAr,
          'canonical_name_ar': nameAr,
          'category': _newCategory,
          'unit_type': _newUnit,
          'standard_price': price,
          'currency': _customCurrency,
          'notes': _customNotesCtrl.text.trim(),
          'is_uncoded': false,
          'is_active': true,
        });

        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.itemRegisteredInCatalogToast(finalCode),
              severity: AppSeverity.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        String errStr = e.toString();
        if (e is DioException) {
          final d = e.response?.data;
          if (d is Map && d.containsKey('detail')) {
            errStr = d['detail'].toString();
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, errStr, severity: AppSeverity.danger),
          );
        }
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }
}
