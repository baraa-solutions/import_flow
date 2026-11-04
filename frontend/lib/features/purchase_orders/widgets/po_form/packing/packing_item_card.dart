import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../core/constants/cargo_constants.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/localization/domain_enum_labels.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../../customs_tariff/models/customs_tariff_model.dart';
import '../../../models/purchase_order_model.dart';
import '../../../utils/po_row_list.dart';
import '../../po_decimal_field.dart';
import '../../po_form_dialog.dart';
import '../po_form_extractor.dart';
import '../po_hs_picker_dialog.dart';

/// Single editable packing list item card.
class PackingItemCard extends StatelessWidget {
  final POFormDialogState dialog;
  final int idx;
  final PackingListItemModel p;
  final bool isMismatched;
  final List<CustomsTariffModel> tariffs;
  final List<SearchableDropdownItem<String>> cachedPackageTypeItems;
  final bool isArabic;
  final AppLocalizations l;

  const PackingItemCard({
    super.key,
    required this.dialog,
    required this.idx,
    required this.p,
    required this.isMismatched,
    required this.tariffs,
    required this.cachedPackageTypeItems,
    required this.isArabic,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('po_pkg_card_${PoRowList.keyOf(p)}'),
      color: isMismatched ? AppTheme.crimsonLight.withValues(alpha: 0.4) : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isMismatched ? AppTheme.crimson : AppTheme.cobaltBorder,
          width: isMismatched ? 1.5 : 1.0,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMismatched
                        ? AppTheme.crimson.withValues(alpha: 0.15)
                        : AppTheme.cobalt.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l.pkgCardNumber(idx + 1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMismatched ? AppTheme.crimson : AppTheme.cobalt,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () async {
                      final picked = await PoHsPickerDialog.show(context, tariffs);
                      if (picked != null) {
                        dialog.updateState(() {
                          dialog.dialogPackingItems[idx] = p.copyWith(hsCode: picked.hsCode);
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l.hsCodeSearchFieldLabel,
                        isDense: true,
                        suffixIcon: isMismatched
                            ? const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 16)
                            : null,
                      ),
                      child: Text(
                        p.hsCode.isNotEmpty ? p.hsCode : l.selectTariffItemHint,
                        style: TextStyle(
                          fontWeight: p.hsCode.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          color: isMismatched
                              ? AppTheme.crimson
                              : (p.hsCode.isNotEmpty ? AppTheme.cobalt : AppTheme.textSecondary),
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
                  child: TextFormField(
                    key: ValueKey('po_pkg_code_${PoRowList.keyOf(p)}'),
                    initialValue: p.itemCode,
                    decoration: InputDecoration(labelText: l.itemCodeLabel, isDense: true),
                    validator: (v) => v == null || v.trim().isEmpty ? l.fieldRequired : null,
                    onChanged: (v) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] = p.copyWith(itemCode: v.trim());
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey('po_pkg_main_desc_${PoRowList.keyOf(p)}'),
                    initialValue: p.mainDescription ?? '',
                    decoration: InputDecoration(
                      labelText: isArabic ? 'الوصف الرئيسي' : 'Main Description',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] =
                            p.copyWith(mainDescription: v.trim().isNotEmpty ? v.trim() : null);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey('po_pkg_desc_${PoRowList.keyOf(p)}'),
                    initialValue: p.description ?? '',
                    decoration: InputDecoration(
                      labelText: l.itemDescriptionLabel,
                      hintText: l.itemNameOrDescHint,
                      isDense: true,
                    ),
                    onChanged: (v) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] =
                            p.copyWith(description: v.trim().isNotEmpty ? v.trim() : null);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: p.packageType,
                    labelText: l.packageTypeFieldLabel,
                    items: cachedPackageTypeItems,
                    onChanged: (v) => dialog.updateState(() {
                      dialog.dialogPackingItems[idx] = p.copyWith(packageType: v ?? 'CT');
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt, size: 20),
                  tooltip: isArabic ? 'استنساخ الطرد' : 'Clone Package',
                  onPressed: () => dialog.clonePackingItem(idx),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppTheme.crimson, size: 20),
                  tooltip: isArabic ? 'حذف الطرد' : 'Remove Package',
                  onPressed: () => dialog.updateState(() => dialog.dialogPackingItems.removeAt(idx)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Length Unit, Qty Pcs, Qty Pkg, Length, Width, Height
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: SearchableDropdownField<String>(
                    value: p.unit,
                    labelText: l.unitFieldLabel,
                    items: const [
                      SearchableDropdownItem(value: 'cm', label: 'cm'),
                      SearchableDropdownItem(value: 'mm', label: 'mm'),
                      SearchableDropdownItem(value: 'm', label: 'm'),
                    ],
                    onChanged: (v) => dialog.updateState(() {
                      dialog.dialogPackingItems[idx] = p.copyWith(unit: v ?? 'cm');
                    }),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: PoDecimalField(
                    key: ValueKey('po_pkg_qty_pcs_${PoRowList.keyOf(p)}'),
                    value: p.qtyPcs,
                    labelText: l.qtyPcsFieldLabel,
                    maxDecimals: 2,
                    emptyValue: 1.0,
                    onChanged: (q) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] = p.copyWith(qtyPcs: q);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: PoDecimalField(
                    key: ValueKey('po_pkg_qty_pkg_${PoRowList.keyOf(p)}'),
                    value: p.qtyPkg,
                    labelText: l.qtyPkgFieldLabel,
                    maxDecimals: 2,
                    emptyValue: 1.0,
                    onChanged: (q) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] = p.copyWith(qtyPkg: q);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: PoDecimalField(
                    key: ValueKey('po_pkg_len_${PoRowList.keyOf(p)}'),
                    value: p.lengthCm,
                    labelText: l.lengthFieldLabel(p.unit),
                    maxDecimals: 2,
                    onChanged: (len) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] = p.copyWith(lengthCm: len);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: PoDecimalField(
                    key: ValueKey('po_pkg_width_${PoRowList.keyOf(p)}'),
                    value: p.widthCm,
                    labelText: l.widthFieldLabel(p.unit),
                    maxDecimals: 2,
                    onChanged: (w) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] = p.copyWith(widthCm: w);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: PoDecimalField(
                    key: ValueKey('po_pkg_height_${PoRowList.keyOf(p)}'),
                    value: p.heightCm,
                    labelText: l.heightFieldLabel(p.unit),
                    maxDecimals: 2,
                    onChanged: (h) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] = p.copyWith(heightCm: h);
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Weight Unit, Net Weight, Gross Weight, Stacking, Metrics Pill
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: p.weightUnit,
                    labelText: l.weightUnitFieldLabel,
                    items: [
                      for (final code in PackingListItemModel.weightUnits)
                        SearchableDropdownItem<String>(
                          value: code,
                          label: DomainEnums.label(l, DomainEnumType.measureUnit, code),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        dialog.updateState(() {
                          dialog.dialogPackingItems[idx] = p.copyWith(weightUnit: v);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: PoDecimalField(
                    key: ValueKey('po_pkg_net_wt_${PoRowList.keyOf(p)}'),
                    value: p.netWeightUnitKg,
                    labelText: l.netWeightFieldLabel(p.weightUnit),
                    maxDecimals: 16,
                    onChanged: (nw) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] = p.copyWith(netWeightUnitKg: nw);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: PoDecimalField(
                    key: ValueKey('po_pkg_gross_wt_${PoRowList.keyOf(p)}'),
                    value: p.grossWeightUnitKg,
                    labelText: l.grossWeightFieldLabel(p.weightUnit),
                    maxDecimals: 16,
                    onChanged: (gw) {
                      dialog.updateState(() {
                        dialog.dialogPackingItems[idx] = p.copyWith(grossWeightUnitKg: gw);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<bool>(
                    value: p.isStackable,
                    labelText: l.stackingInstructionsLabel,
                    items: [
                      SearchableDropdownItem(value: true, label: l.stackableOption),
                      SearchableDropdownItem(value: false, label: l.nonStackableOption),
                    ],
                    onChanged: (v) => dialog.updateState(() {
                      dialog.dialogPackingItems[idx] = p.copyWith(isStackable: v ?? true);
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cobaltBorder),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(l.totalVolumePill, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                              Text(
                                '${p.calculatedCbm.toStringAsFixed(4)} m³',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              Text(l.totalGrossWeightPill, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                              Text(
                                '${PoFormExtractor.formatDecimalInput(p.computedTotalGrossWeightKg)} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.cobalt,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              Text(l.airChargeablePill, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                              Text(
                                '${PoFormExtractor.formatDecimalInput(math.max(p.computedTotalGrossWeightKg, p.calculatedCbm * kAirVolumetricKgPerCbm))} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.cobalt,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
