import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../currencies/models/currency_model.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../master_items/models/master_item_model.dart';
import '../models/purchase_order_model.dart';
import 'line_item/po_line_item_catalog_section.dart';
import 'line_item/po_line_item_constants.dart';
import 'line_item/po_line_item_header.dart';
import 'line_item/po_line_item_identification_section.dart';
import 'line_item/po_line_item_logistics_section.dart';
import 'line_item/po_line_item_pricing_section.dart';
import 'line_item/po_line_item_tariff_section.dart';
import 'po_decimal_field.dart';

/// Modal Dialog for Adding / Editing a PO Line Item with Master Items Catalog
/// Integration and Auto-fill capabilities (MD-ITEM-001 / Task 14).
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
      ...kCountryOptions.map((c) {
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
                POLineItemHeader(isEdit: _isEdit, isArabic: isArabic),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppTheme.cloudWhite),
                const SizedBox(height: 14),

                // ── Scrollable Form Body ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Catalog Fast Autocomplete
                        POLineItemCatalogSection(
                          wasAutoFilled: _wasAutoFilled,
                          isArabic: isArabic,
                          initialItemCode: _itemCodeController.text,
                          selectedMasterItem: _selectedMasterItem,
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
                        const SizedBox(height: 14),

                        // 2. Identification & Descriptions
                        POLineItemIdentificationSection(
                          itemCodeController: _itemCodeController,
                          descArController: _descArController,
                          descEnController: _descEnController,
                          selectedCountryOfOrigin: _selectedCountryOfOrigin,
                          countryItems: countryItems,
                          onCountryChanged: (v) {
                            setState(() => _selectedCountryOfOrigin = v);
                          },
                          isArabic: isArabic,
                        ),
                        const SizedBox(height: 12),

                        // 3. Customs Tariff & Taxes
                        POLineItemTariffSection(
                          tariffId: _tariffId,
                          dutyRate: _dutyRate,
                          vatRate: _vatRate,
                          tariffItems: tariffItems,
                          onTariffChanged: (pickedId) {
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
                          isArabic: isArabic,
                        ),
                        const SizedBox(height: 14),

                        // 4. Quantities & Commercial Pricing
                        POLineItemPricingSection(
                          qtyController: _qtyController,
                          unitPriceController: _unitPriceController,
                          unitOfMeasure: _unitOfMeasure,
                          uomItems: uomItems,
                          onUomChanged: (u) {
                            if (u != null) {
                              setState(() => _unitOfMeasure = u);
                            }
                          },
                          currency: currency,
                          calculatedTotal: calculatedTotal,
                          onValuesChanged: () => setState(() {}),
                          isArabic: isArabic,
                        ),
                        const SizedBox(height: 14),

                        // 5. Logistics Dimensions & Weights
                        POLineItemLogisticsSection(
                          cbmPerUnitController: _cbmPerUnitController,
                          netWeightController: _netWeightController,
                          grossWeightController: _grossWeightController,
                          calculatedTotalCbm: calculatedTotalCbm,
                          calculatedTotalGrossWeight: calculatedTotalGrossWeight,
                          onValuesChanged: () => setState(() {}),
                          isArabic: isArabic,
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
