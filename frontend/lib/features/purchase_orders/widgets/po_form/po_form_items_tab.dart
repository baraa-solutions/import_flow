import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../currencies/models/currency_model.dart';
import '../../../customs_tariff/models/customs_tariff_model.dart';
import '../../../customs_tariff/widgets/tariff_form_dialog.dart';
import '../../models/purchase_order_model.dart';
import '../../utils/po_row_list.dart';
import '../po_decimal_field.dart';
import '../po_line_item_dialog.dart';
import 'po_form_extractor.dart';
import 'po_hs_picker_dialog.dart';

/// Dynamic table / cards for PO line items, unit prices, HS codes, and quantities.
class POFormItemsTab extends ConsumerWidget {
  final PoRowList<POLineItemModel> items;
  final List<CustomsTariffModel> tariffs;
  final List<CurrencyModel> currencies;
  final int? selectedCurrencyId;
  final String? selectedCountryOfOrigin;
  final Set<String> mismatchedHsCodes;

  final void Function(int index, POLineItemModel item) onItemUpdated;
  final VoidCallback onItemAdded;
  final ValueChanged<int> onItemCloned;
  final ValueChanged<int> onItemRemoved;
  final VoidCallback onOpenDutyCalculator;

  const POFormItemsTab({
    super.key,
    required this.items,
    required this.tariffs,
    required this.currencies,
    required this.selectedCurrencyId,
    required this.selectedCountryOfOrigin,
    required this.mismatchedHsCodes,
    required this.onItemUpdated,
    required this.onItemAdded,
    required this.onItemCloned,
    required this.onItemRemoved,
    required this.onOpenDutyCalculator,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isArabic = l.isArabic;

    final cachedCountryItems = [
      SearchableDropdownItem<String?>(
        value: null,
        label: isArabic ? 'افتراضي' : 'Default',
      ),
      ...PoFormExtractor.countryOptions.map((c) => SearchableDropdownItem<String?>(
            value: c['name'],
            label: isArabic ? c['nameAr']! : c['nameEn']!,
          )),
    ];

    final cachedUomItems = kMasterUnitsOfMeasure.map((u) {
      final cleanAr = u['name']!.split('(').first.replaceAll(RegExp(r'^[A-Z0-9]+\s*-\s*'), '').trim();
      final cleanEn = u['name']!.split(' - ').last.split('(').first.trim();
      final label = isArabic ? '${u['code']} - $cleanAr' : '${u['code']} - $cleanEn';
      return SearchableDropdownItem<String>(value: u['code']!, label: label);
    }).toList();

    final activeCurrency = currencies.where((c) => c.currencyId == selectedCurrencyId).firstOrNull ??
        CurrencyModel(currencyId: 0, currencyCode: 'USD', currencyName: 'USD', currencySymbol: '\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header & Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isArabic ? 'بنود الفاتورة المبدئية' : 'Proforma Invoice Line Items',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (items.isNotEmpty)
                  AppButton(
                    label: isArabic ? 'حاسبة الجمارك' : 'Duty Calculator',
                    icon: Icons.calculate_outlined,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onOpenDutyCalculator,
                  ),
                AppButton(
                  label: l.poAddFromCatalog,
                  icon: Icons.auto_awesome_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () async {
                    final newItem = await POLineItemDialog.show(
                      context,
                      tariffs: tariffs,
                      currencies: currencies,
                      defaultCurrencyId: selectedCurrencyId,
                      defaultCountryOfOrigin: selectedCountryOfOrigin,
                    );
                    if (newItem != null) {
                      onItemUpdated(items.length, newItem);
                    }
                  },
                ),
                AppButton(
                  label: isArabic ? 'إضافة بند' : 'Add Item',
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onItemAdded,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Dynamic Line Items Cards
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final itemHs = item.hsCode ??
              (item.tariffId != null && tariffs.any((t) => t.tariffId == item.tariffId)
                  ? tariffs.firstWhere((t) => t.tariffId == item.tariffId).hsCode
                  : '');
          final isMismatched = itemHs.isNotEmpty && mismatchedHsCodes.contains(itemHs);

          return Card(
            key: ValueKey('po_line_item_card_${PoRowList.keyOf(item)}'),
            color: isMismatched ? AppTheme.crimsonLight.withValues(alpha: 0.4) : AppTheme.charcoalSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isMismatched ? AppTheme.crimsonBorder : AppTheme.cloudWhite,
                width: isMismatched ? 1.5 : 1.0,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Code, Descriptions, HS Tariff, Country, Action Icons
                  Row(
                    children: [
                      Text(
                        '#${idx + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: ValueKey('po_item_code_${PoRowList.keyOf(item)}'),
                          initialValue: item.itemCode,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'كود البند' : 'Item Code',
                            isDense: true,
                          ),
                          onChanged: (v) => onItemUpdated(
                            idx,
                            item.copyWith(itemCode: v.trim().isEmpty ? null : v.trim()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: ValueKey('po_item_main_desc_${PoRowList.keyOf(item)}'),
                          initialValue: item.mainDescription,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'الوصف الرئيسي' : 'Main Description',
                            isDense: true,
                          ),
                          onChanged: (v) => onItemUpdated(
                            idx,
                            item.copyWith(mainDescription: v.trim().isEmpty ? null : v.trim()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: ValueKey('po_item_desc_${PoRowList.keyOf(item)}'),
                          initialValue: item.descriptionAr,
                          decoration: InputDecoration(
                            labelText: isArabic ? 'الوصف العربي *' : 'Arabic Description *',
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
                          onChanged: (v) => onItemUpdated(
                            idx,
                            item.copyWith(descriptionAr: v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () async {
                            final picked = await PoHsPickerDialog.show(context, tariffs);
                            onItemUpdated(
                              idx,
                              item.copyWith(
                                tariffId: picked?.tariffId,
                                hsCode: picked?.hsCode,
                              ),
                            );
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: isArabic ? 'البند الجمركي' : 'Customs Tariff',
                              isDense: true,
                              suffixIcon: isMismatched
                                  ? const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 16)
                                  : null,
                            ),
                            child: Text(
                              item.tariffId != null
                                  ? (tariffs.any((t) => t.tariffId == item.tariffId)
                                      ? '${tariffs.firstWhere((t) => t.tariffId == item.tariffId).hsCode} - ${tariffs.firstWhere((t) => t.tariffId == item.tariffId).hsDescription}'
                                      : (item.hsCode ?? '#${item.tariffId}'))
                                  : (item.hsCode != null && item.hsCode!.isNotEmpty
                                      ? item.hsCode!
                                      : (isArabic ? 'عام أو غير محدد' : 'General / None')),
                              style: TextStyle(
                                fontWeight: (item.tariffId != null || (item.hsCode != null && item.hsCode!.isNotEmpty))
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isMismatched
                                    ? AppTheme.crimson
                                    : ((item.tariffId != null || (item.hsCode != null && item.hsCode!.isNotEmpty))
                                        ? AppTheme.cobalt
                                        : AppTheme.textStrong),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SearchableDropdownField<String?>(
                          value: PoFormExtractor.normalizeCountryName(item.countryOfOrigin ?? selectedCountryOfOrigin),
                          labelText: isArabic ? 'بلد المنشأ' : 'Country of Origin',
                          items: cachedCountryItems,
                          onChanged: (v) {
                            onItemUpdated(
                              idx,
                              item.copyWith(countryOfOrigin: PoFormExtractor.normalizeCountryName(v)),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: AppTheme.cobalt, size: 22),
                        tooltip: l.poEditLineItemWithCatalog,
                        onPressed: () async {
                          final updated = await POLineItemDialog.show(
                            context,
                            initialItem: item,
                            tariffs: tariffs,
                            currencies: currencies,
                            defaultCurrencyId: selectedCurrencyId,
                            defaultCountryOfOrigin: selectedCountryOfOrigin,
                          );
                          if (updated != null) {
                            onItemUpdated(idx, updated);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
                        tooltip: isArabic ? 'تكرار البند' : 'Clone Line Item',
                        onPressed: () => onItemCloned(idx),
                      ),
                      if (items.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.crimson, size: 20),
                          tooltip: isArabic ? 'حذف البند' : 'Remove Line Item',
                          onPressed: () => onItemRemoved(idx),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Row 2: Quantity, Unit, Price, Total
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PoDecimalField(
                          key: ValueKey('po_item_qty_${PoRowList.keyOf(item)}'),
                          value: item.quantity,
                          labelText: isArabic ? 'الكمية' : 'Quantity',
                          maxDecimals: 2,
                          emptyValue: 1.0,
                          onChanged: (q) {
                            onItemUpdated(
                              idx,
                              item.copyWith(quantity: q, totalPrice: q * item.unitPrice),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: SearchableDropdownField<String>(
                          value: item.unitOfMeasure,
                          labelText: isArabic ? 'الوحدة' : 'Unit',
                          items: cachedUomItems,
                          onChanged: (v) {
                            if (v != null) {
                              onItemUpdated(idx, item.copyWith(unitOfMeasure: v));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: PoDecimalField(
                          key: ValueKey('po_item_price_${PoRowList.keyOf(item)}'),
                          value: item.unitPrice,
                          labelText: isArabic ? 'سعر الوحدة' : 'Unit Price',
                          maxDecimals: 4,
                          onChanged: (p) {
                            onItemUpdated(
                              idx,
                              item.copyWith(unitPrice: p, totalPrice: item.quantity * p),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.emeraldBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              isArabic ? 'إجمالي البند' : 'Line Total',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${activeCurrency.currencyCode} ${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Unregistered HS Code Warning Banner with Smart Nafeza Trigger
                  if (item.tariffId == null || !tariffs.any((t) => t.tariffId == item.tariffId))
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.orange, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppTheme.wcagOrange, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isArabic
                                      ? 'بند التعريفة الجمركية (${item.hsCode ?? "غير مسجل"}) غير مسجل في جدول التعريفة المعتمد — يرجى تسجيله لحساب الرسوم وضريبة الوارد بدقة.'
                                      : 'Customs tariff HS code (${item.hsCode ?? "Unregistered"}) is not in the approved database — please register it for accurate duty and VAT.',
                                  style: const TextStyle(
                                    color: AppTheme.wcagOrange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              AppButton(
                                label: isArabic ? 'تسجيل البند عبر نافذة' : 'Register via Nafeza',
                                icon: Icons.auto_fix_high,
                                variant: AppButtonVariant.warning,
                                size: AppButtonSize.small,
                                onPressed: () => showTariffDialog(context, ref, initialModeIndex: 0),
                              ),
                              AppButton(
                                label: isArabic ? 'بحث واختيار من التعريفة' : 'Search Tariff',
                                icon: Icons.search,
                                variant: AppButtonVariant.secondary,
                                size: AppButtonSize.small,
                                onPressed: () async {
                                  final picked = await PoHsPickerDialog.show(context, tariffs);
                                  if (picked != null) {
                                    onItemUpdated(
                                      idx,
                                      item.copyWith(
                                        tariffId: picked.tariffId,
                                        hsCode: picked.hsCode,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
