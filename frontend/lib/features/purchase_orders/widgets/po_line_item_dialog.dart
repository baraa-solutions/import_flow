import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../currencies/models/currency_model.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../master_items/models/master_item_model.dart';
import '../../master_items/widgets/master_item_autocomplete_field.dart';
import '../models/purchase_order_model.dart';
import 'po_decimal_field.dart';

/// Standard Country Options for PO Line Items
const List<Map<String, String>> _kCountryOptions = [
  {'code': 'CN', 'name': 'CN - الصين (China)'},
  {'code': 'DE', 'name': 'DE - ألمانيا (Germany)'},
  {'code': 'IT', 'name': 'IT - إيطاليا (Italy)'},
  {'code': 'LT', 'name': 'LT - ليتوانيا (Lithuania)'},
  {'code': 'TW', 'name': 'TW - تايوان (Taiwan)'},
  {'code': 'TR', 'name': 'TR - تركيا (Turkey)'},
  {'code': 'FR', 'name': 'FR - فرنسا (France)'},
  {'code': 'ES', 'name': 'ES - إسبانيا (Spain)'},
  {'code': 'GB', 'name': 'GB - المملكة المتحدة (United Kingdom)'},
  {'code': 'US', 'name': 'US - الولايات المتحدة الأمريكية (USA)'},
  {'code': 'BR', 'name': 'BR - البرازيل (Brazil)'},
  {'code': 'AR', 'name': 'AR - الأرجنتين (Argentina)'},
  {'code': 'IN', 'name': 'IN - الهند (India)'},
  {'code': 'JP', 'name': 'JP - اليابان (Japan)'},
  {'code': 'KR', 'name': 'KR - كوريا الجنوبية (South Korea)'},
  {'code': 'SA', 'name': 'SA - المملكة العربية السعودية (Saudi Arabia)'},
  {'code': 'AE', 'name': 'AE - الإمارات العربية المتحدة (UAE)'},
  {'code': 'JO', 'name': 'JO - الأردن (Jordan)'},
  {'code': 'MA', 'name': 'MA - المغرب (Morocco)'},
  {'code': 'TN', 'name': 'TN - تونس (Tunisia)'},
  {'code': 'LB', 'name': 'LB - لبنان (Lebanon)'},
  {'code': 'NL', 'name': 'NL - هولندا (Netherlands)'},
  {'code': 'BE', 'name': 'BE - بلجيكا (Belgium)'},
  {'code': 'AT', 'name': 'AT - النمسا (Austria)'},
  {'code': 'PL', 'name': 'PL - بولندا (Poland)'},
  {'code': 'SE', 'name': 'SE - السويد (Sweden)'},
  {'code': 'CH', 'name': 'CH - سويسرا (Switzerland)'},
  {'code': 'RU', 'name': 'RU - روسيا (Russia)'},
  {'code': 'VN', 'name': 'VN - فيتنام (Vietnam)'},
  {'code': 'TH', 'name': 'TH - تايلاند (Thailand)'},
  {'code': 'MY', 'name': 'MY - ماليزيا (Malaysia)'},
  {'code': 'ID', 'name': 'ID - إندونيسيا (Indonesia)'},
  {'code': 'EG', 'name': 'EG - مصر (Egypt)'},
];

/// Modal Dialog for Adding / Editing a PO Line Item with Master Items Catalog
/// Integration and Auto-fill capabilities (MD-ITEM-001 / Task 14).
///
/// Cuts line item entry time from 3 minutes to under 30 seconds by automatically
/// populating item code, descriptions, HS Code, UOM, dimensions, and weights
/// upon selecting an item from the master catalog.
class POLineItemDialog extends ConsumerStatefulWidget {
  final POLineItemModel? initialItem;
  final List<CustomsTariffModel> tariffs;
  final List<CurrencyModel> currencies;
  final int? defaultCurrencyId;
  final String? defaultCountryOfOrigin;

  const POLineItemDialog({
    super.key,
    this.initialItem,
    this.tariffs = const [],
    this.currencies = const [],
    this.defaultCurrencyId,
    this.defaultCountryOfOrigin,
  });

  /// Static helper to display the line item modal dialog
  static Future<POLineItemModel?> show(
    BuildContext context, {
    POLineItemModel? initialItem,
    List<CustomsTariffModel> tariffs = const [],
    List<CurrencyModel> currencies = const [],
    int? defaultCurrencyId,
    String? defaultCountryOfOrigin,
  }) {
    return showDialog<POLineItemModel?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => POLineItemDialog(
        initialItem: initialItem,
        tariffs: tariffs,
        currencies: currencies,
        defaultCurrencyId: defaultCurrencyId,
        defaultCountryOfOrigin: defaultCountryOfOrigin,
      ),
    );
  }

  @override
  ConsumerState<POLineItemDialog> createState() => _POLineItemDialogState();
}

class _POLineItemDialogState extends ConsumerState<POLineItemDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _itemCodeController;
  late final TextEditingController _descArController;
  late final TextEditingController _descEnController;
  late final TextEditingController _mainDescController;

  late final TextEditingController _qtyController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _cbmPerUnitController;
  late final TextEditingController _netWeightController;
  late final TextEditingController _grossWeightController;

  int? _tariffId;
  String? _hsCode;
  double? _dutyRate;
  double? _vatRate;

  String? _selectedCountryOfOrigin;
  String _unitOfMeasure = 'PCS';

  bool _wasAutoFilled = false;
  MasterItemModel? _selectedMasterItem;

  bool get _isEdit => widget.initialItem != null;

  double get _quantity => double.tryParse(_qtyController.text) ?? 1.0;
  double get _unitPrice => double.tryParse(_unitPriceController.text) ?? 0.0;
  double get _cbmPerUnit => double.tryParse(_cbmPerUnitController.text) ?? 0.0;
  double get _netWeightKg => double.tryParse(_netWeightController.text) ?? 0.0;
  double get _grossWeightKg =>
      double.tryParse(_grossWeightController.text) ?? 0.0;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;

    _itemCodeController = TextEditingController(text: item?.itemCode ?? '');
    _descArController = TextEditingController(text: item?.descriptionAr ?? '');
    _descEnController = TextEditingController(text: item?.descriptionEn ?? '');
    _mainDescController =
        TextEditingController(text: item?.mainDescription ?? '');

    _qtyController = TextEditingController(
      text: item != null
          ? PoDecimalField.formatForEditing(item.quantity, maxDecimals: 2)
          : '1',
    );
    _unitPriceController = TextEditingController(
      text: item != null
          ? PoDecimalField.formatForEditing(item.unitPrice, maxDecimals: 4)
          : '0',
    );
    _cbmPerUnitController = TextEditingController(
      text: item != null
          ? PoDecimalField.formatForEditing(item.cbmPerUnit, maxDecimals: 4)
          : '0',
    );
    _netWeightController = TextEditingController(
      text: item != null
          ? PoDecimalField.formatForEditing(item.netWeightKg, maxDecimals: 4)
          : '0',
    );
    _grossWeightController = TextEditingController(
      text: item != null
          ? PoDecimalField.formatForEditing(item.grossWeightKg, maxDecimals: 4)
          : '0',
    );

    _tariffId = item?.tariffId;
    _hsCode = item?.hsCode;
    _dutyRate = item?.dutyRate;
    _vatRate = item?.vatRate;

    _selectedCountryOfOrigin =
        item?.countryOfOrigin ?? widget.defaultCountryOfOrigin;
    _unitOfMeasure = item?.unitOfMeasure ?? 'PCS';

    // Resolve initial tariff rates if not already set
    if (_tariffId != null && widget.tariffs.isNotEmpty) {
      final match = widget.tariffs
          .where((t) => t.tariffId == _tariffId)
          .firstOrNull;
      if (match != null) {
        _hsCode ??= match.hsCode;
        _dutyRate ??= match.customsDutyRate;
        _vatRate ??= match.vatRate;
      }
    }
  }

  @override
  void dispose() {
    _itemCodeController.dispose();
    _descArController.dispose();
    _descEnController.dispose();
    _mainDescController.dispose();
    _qtyController.dispose();
    _unitPriceController.dispose();
    _cbmPerUnitController.dispose();
    _netWeightController.dispose();
    _grossWeightController.dispose();
    super.dispose();
  }

  void _onMasterItemSelected(MasterItemModel item) {
    setState(() {
      _selectedMasterItem = item;
      _wasAutoFilled = true;

      // 1. Codes & Descriptions
      _itemCodeController.text = item.itemCode;
      _descArController.text = item.descriptionAr;
      if (item.descriptionEn != null && item.descriptionEn!.isNotEmpty) {
        _descEnController.text = item.descriptionEn!;
        _mainDescController.text = item.descriptionEn!;
      } else {
        _mainDescController.text = item.descriptionAr;
      }

      // 2. Customs Tariff & Taxes
      _tariffId = item.tariffId;
      _hsCode = item.hsCode;
      _dutyRate = item.lastCustomsDutyPct;
      _vatRate = item.lastVatPct;

      if (_tariffId != null &&
          widget.tariffs.isNotEmpty &&
          (_hsCode == null || _hsCode!.isEmpty)) {
        final match = widget.tariffs
            .where((t) => t.tariffId == _tariffId)
            .firstOrNull;
        if (match != null) {
          _hsCode = match.hsCode;
          _dutyRate ??= match.customsDutyRate;
          _vatRate ??= match.vatRate;
        }
      }

      // 3. Packaging, UOM, and Dimensions
      if (item.defaultUom.isNotEmpty) {
        _unitOfMeasure = item.defaultUom;
      }
      _cbmPerUnitController.text =
          PoDecimalField.formatForEditing(item.cbmPerUnit, maxDecimals: 4);
      _grossWeightController.text =
          PoDecimalField.formatForEditing(item.grossWeightKg, maxDecimals: 4);
      _netWeightController.text =
          PoDecimalField.formatForEditing(item.netWeightKg, maxDecimals: 4);
    });
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final qty = _quantity;
    final price = _unitPrice;
    final cbm = _cbmPerUnit;
    final gross = _grossWeightKg;
    final net = _netWeightKg;

    final result = POLineItemModel(
      itemId: widget.initialItem?.itemId,
      poId: widget.initialItem?.poId,
      itemCode: _itemCodeController.text.trim().isEmpty
          ? null
          : _itemCodeController.text.trim(),
      mainDescription: _mainDescController.text.trim().isEmpty
          ? null
          : _mainDescController.text.trim(),
      descriptionAr: _descArController.text.trim(),
      descriptionEn: _descEnController.text.trim().isEmpty
          ? null
          : _descEnController.text.trim(),
      countryOfOrigin: _selectedCountryOfOrigin,
      tariffId: _tariffId,
      hsCode: _hsCode,
      quantity: qty,
      unitOfMeasure: _unitOfMeasure,
      unitPrice: price,
      totalPrice: qty * price,
      cbmPerUnit: cbm,
      totalCbm: qty * cbm,
      grossWeightKg: gross,
      netWeightKg: net,
      dutyRate: _dutyRate,
      vatRate: _vatRate,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = l.isArabic;

    // Currency representation
    final currency = widget.currencies.firstWhere(
      (c) => c.currencyId == widget.defaultCurrencyId,
      orElse: () => CurrencyModel(
        currencyId: 0,
        currencyCode: 'USD',
        currencyName: 'US Dollar',
        currencySymbol: '\$',
      ),
    );

    // Country options
    final countryItems = [
      SearchableDropdownItem<String?>(
        value: null,
        label: isArabic ? 'افتراضي حسب أمر الشراء' : 'Default from PO',
      ),
      ..._kCountryOptions.map((c) {
        final label = isArabic
            ? c['name']!
            : '${c['code']} - ${c['code'] == 'CN' ? 'China' : c['code'] == 'DE' ? 'Germany' : c['name']!.split('(').last.replaceAll(')', '')}';
        return SearchableDropdownItem<String?>(value: c['name'], label: label);
      }),
    ];

    // UOM options
    final uomItems = kMasterUnitsOfMeasure.map((u) {
      final label = isArabic
          ? u['name']!
          : '${u['code']} - ${u['name']!.split(' - ').last.split('(').first.trim()}';
      return SearchableDropdownItem<String>(value: u['code']!, label: label);
    }).toList();

    // Tariff picker options
    final tariffItems = [
      SearchableDropdownItem<int?>(
        value: null,
        label: isArabic ? 'بدون بند جمركي محدد' : 'No Specific Tariff',
      ),
      ...widget.tariffs.map((t) {
        return SearchableDropdownItem<int?>(
          value: t.tariffId,
          label: '${t.hsCode} - ${t.hsDescription}',
          subtitle:
              'Duty: ${(t.customsDutyRate * 100).toStringAsFixed(1)}% | VAT: ${(t.vatRate * 100).toStringAsFixed(1)}%',
        );
      }),
    ];

    final calculatedTotal = _quantity * _unitPrice;
    final calculatedTotalCbm = _quantity * _cbmPerUnit;
    final calculatedTotalGrossWeight = _quantity * _grossWeightKg;

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 760,
          constraints: const BoxConstraints(maxHeight: 780),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Dialog Header ──────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobaltLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isEdit
                            ? Icons.edit_note_rounded
                            : Icons.playlist_add_rounded,
                        color: AppTheme.cobalt,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit
                                ? l.poLineItemDialogTitleEdit
                                : l.poLineItemDialogTitleAdd,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.charcoal,
                            ),
                          ),
                          Text(
                            l.poLineItemCatalogAutoFillHint,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.textMuted),
                      tooltip: isArabic ? 'إغلاق' : 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppTheme.cloudWhite),
                const SizedBox(height: 14),

                // ── Scrollable Form Body ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── 1. Catalog Fast Autocomplete ────────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cloudWhite.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _wasAutoFilled
                                  ? AppTheme.emeraldBorder
                                  : AppTheme.cobalt.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: _wasAutoFilled
                                        ? AppTheme.emerald
                                        : AppTheme.cobalt,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isArabic
                                          ? 'استدعاء الصنف من الكاتالوج المركزي'
                                          : 'Fast Catalog Autocomplete & Pre-fill',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _wasAutoFilled
                                            ? AppTheme.emerald
                                            : AppTheme.charcoal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_wasAutoFilled) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emeraldLight,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: AppTheme.emeraldBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              size: 12,
                                              color: AppTheme.emerald),
                                          const SizedBox(width: 4),
                                          Text(
                                            l.masterItemAutoFilled,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.emerald,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              MasterItemAutocompleteField(
                                initialValue: _itemCodeController.text,
                                selectedItem: _selectedMasterItem,
                                onItemSelected: _onMasterItemSelected,
                                onChanged: (code) {
                                  _itemCodeController.text = code;
                                },
                                onCleared: () {
                                  setState(() {
                                    _wasAutoFilled = false;
                                    _selectedMasterItem = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── 2. Identification & Descriptions ────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _itemCodeController,
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'كود الصنف / SKU'
                                      : 'Item Code / SKU',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: SearchableDropdownField<String?>(
                                value: _selectedCountryOfOrigin,
                                labelText: isArabic
                                    ? 'بلد المنشأ للبند'
                                    : 'Country of Origin',
                                searchHintText: isArabic
                                    ? 'ابحث عن بلد المنشأ...'
                                    : 'Search country...',
                                items: countryItems,
                                onChanged: (v) {
                                  setState(() => _selectedCountryOfOrigin = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _descArController,
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'الوصف بالعربية *'
                                      : 'Arabic Description *',
                                  isDense: true,
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? l.requiredField
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _descEnController,
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'الوصف بالإنجليزية'
                                      : 'English Description',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── 3. Customs Tariff & Taxes ───────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: SearchableDropdownField<int?>(
                                value: _tariffId,
                                labelText: isArabic
                                    ? 'بند التعريفة الجمركية (HS Code)'
                                    : 'Customs Tariff (HS Code)',
                                searchHintText: isArabic
                                    ? 'ابحث برقم البند أو الوصف...'
                                    : 'Search HS code or description...',
                                items: tariffItems,
                                onChanged: (pickedId) {
                                  setState(() {
                                    _tariffId = pickedId;
                                    if (pickedId != null &&
                                        widget.tariffs.isNotEmpty) {
                                      final match = widget.tariffs
                                          .where((t) => t.tariffId == pickedId)
                                          .firstOrNull;
                                      if (match != null) {
                                        _hsCode = match.hsCode;
                                        _dutyRate = match.customsDutyRate;
                                        _vatRate = match.vatRate;
                                      }
                                    } else {
                                      _hsCode = null;
                                      _dutyRate = null;
                                      _vatRate = null;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.charcoalSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.cloudWhite),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic
                                          ? 'الرسوم المقدرة'
                                          : 'Estimated Duties',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Duty: ${_dutyRate != null ? "${(_dutyRate! * 100).toStringAsFixed(1)}%" : "--"} | VAT: ${_vatRate != null ? "${(_vatRate! * 100).toStringAsFixed(1)}%" : "--"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.cobalt,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── 4. Quantities & Commercial Pricing ──────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _qtyController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  PoDecimalField.decimalFormatter(2)
                                ],
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'الكمية *'
                                      : 'Quantity *',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: SearchableDropdownField<String>(
                                value: _unitOfMeasure,
                                labelText: isArabic ? 'الوحدة' : 'Unit',
                                items: uomItems,
                                onChanged: (u) {
                                  if (u != null) {
                                    setState(() => _unitOfMeasure = u);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _unitPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  PoDecimalField.decimalFormatter(4)
                                ],
                                decoration: InputDecoration(
                                  labelText: isArabic
                                      ? 'سعر الوحدة (${currency.currencyCode}) *'
                                      : 'Unit Price (${currency.currencyCode}) *',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.emeraldLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: AppTheme.emeraldBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isArabic
                                          ? 'إجمالي السطر'
                                          : 'Line Total',
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
                        ),
                        const SizedBox(height: 14),

                        // ── 5. Logistics Dimensions & Weights ───────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.charcoalSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.cloudWhite),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.scale_rounded,
                                      size: 16, color: AppTheme.cobalt),
                                  const SizedBox(width: 6),
                                  Text(
                                    isArabic
                                        ? 'الأوزان والأحجام اللوجستية (تعبئة تلقائية من الكاتالوج)'
                                        : 'Logistics Weights & Dimensions (Auto-filled)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cbmPerUnitController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        PoDecimalField.decimalFormatter(4)
                                      ],
                                      decoration: InputDecoration(
                                        labelText: isArabic
                                            ? 'الحجم للوحدة (CBM)'
                                            : 'CBM / Unit',
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _netWeightController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        PoDecimalField.decimalFormatter(4)
                                      ],
                                      decoration: InputDecoration(
                                        labelText: isArabic
                                            ? 'الوزن الصافي (KG)'
                                            : 'Net Wt / Unit (KG)',
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _grossWeightController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        PoDecimalField.decimalFormatter(4)
                                      ],
                                      decoration: InputDecoration(
                                        labelText: isArabic
                                            ? 'الوزن القائم (KG)'
                                            : 'Gross Wt / Unit (KG)',
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 14,
                                children: [
                                  Text(
                                    '${isArabic ? "إجمالي الحجم:" : "Total CBM:"} ${calculatedTotalCbm.toStringAsFixed(4)} m³',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${isArabic ? "إجمالي الوزن القائم:" : "Total Gross Wt:"} ${calculatedTotalGrossWeight.toStringAsFixed(2)} kg',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppTheme.cloudWhite),
                const SizedBox(height: 12),

                // ── Dialog Action Buttons ───────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      label: l.cancel,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: _isEdit
                          ? l.save
                          : (isArabic ? 'إضافة البند' : 'Add Line Item'),
                      icon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: _onSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
