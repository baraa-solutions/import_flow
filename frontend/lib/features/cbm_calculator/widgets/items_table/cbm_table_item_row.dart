import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../models/cbm_calculator_model.dart';

/// Single interactive row in CbmItemsTable
class CbmTableItemRow extends StatelessWidget {
  final int index;
  final int? activeSessionId;
  final CBMItemModel item;
  final String shipmentMode;
  final int totalItemsCount;
  final void Function(CBMItemModel updatedItem) onItemUpdated;
  final VoidCallback onClone;
  final VoidCallback onDelete;

  const CbmTableItemRow({
    super.key,
    required this.index,
    required this.activeSessionId,
    required this.item,
    required this.shipmentMode,
    required this.totalItemsCount,
    required this.onItemUpdated,
    required this.onClone,
    required this.onDelete,
  });

  void _onPackageTypeSelected(String? v) {
    if (v == null) return;
    double newLen = item.length;
    double newWid = item.width;
    String newUnit = item.unit;
    if (v == 'Euro Pallet (120x80)') {
      newLen = kEuroPalletLengthCm;
      newWid = kEuroPalletWidthCm;
      newUnit = 'cm';
    } else if (v == 'Standard Pallet (120x100)') {
      newLen = kStandardPalletLengthCm;
      newWid = kStandardPalletWidthCm;
      newUnit = 'cm';
    }
    onItemUpdated(
      CBMItemModel(
        itemId: item.itemId,
        calcId: item.calcId,
        packageType: v,
        quantity: item.quantity,
        length: newLen,
        width: newWid,
        height: item.height,
        unit: newUnit,
        grossWeightPerUnitKg: item.grossWeightPerUnitKg,
        isStackable: item.isStackable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lM = item.lengthM;
    final wM = item.widthM;
    final hM = item.heightM;
    final itemCbm = item.quantity * lM * wM * hM;
    final itemVolWt = item.quantity * lM * wM * hM * kAirVolumetricKgPerCbm;
    final itemGross = item.quantity * item.grossWeightPerUnitKg;

    return Row(
      key: ValueKey('row_${index}_${activeSessionId}_${item.itemId}'),
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '#${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
          ),
        ),
        const SizedBox(width: 8),
        // Package Type Dropdown
        SizedBox(
          width: 160,
          child: SearchableDropdownField<String>(
            key: ValueKey('cbm_type_${index}_$activeSessionId'),
            value: item.packageType,
            labelText: l.packageTypeCol,
            searchHintText: l.packageTypeCol,
            items: const [
              'Carton',
              'Euro Pallet (120x80)',
              'Standard Pallet (120x100)',
              'Custom Pallet',
              'Wooden Crate',
              'Drum',
              'Bag',
              'Loose Box',
            ].map((t) => SearchableDropdownItem<String>(value: t, label: t)).toList(),
            onChanged: _onPackageTypeSelected,
          ),
        ),
        const SizedBox(width: 8),
        // Dimension Unit Selector
        SizedBox(
          width: 95,
          child: SearchableDropdownField<String>(
            key: ValueKey('cbm_unit_${index}_$activeSessionId'),
            value: item.unit,
            labelText: l.unitCol,
            searchHintText: l.unitCol,
            items: const [
              SearchableDropdownItem<String>(value: 'mm', label: 'mm'),
              SearchableDropdownItem<String>(value: 'cm', label: 'cm'),
              SearchableDropdownItem<String>(value: 'm', label: 'm'),
            ],
            onChanged: (u) {
              if (u != null) {
                onItemUpdated(
                  CBMItemModel(
                    itemId: item.itemId,
                    calcId: item.calcId,
                    packageType: item.packageType,
                    quantity: item.quantity,
                    length: item.length,
                    width: item.width,
                    height: item.height,
                    unit: u,
                    grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                    isStackable: item.isStackable,
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Quantity
        SizedBox(
          width: 80,
          child: TextFormField(
            key: ValueKey('cbm_qty_${index}_$activeSessionId'),
            initialValue: item.quantity.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.qtyCol,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              final q = int.tryParse(v) ?? 1;
              onItemUpdated(
                CBMItemModel(
                  itemId: item.itemId,
                  calcId: item.calcId,
                  packageType: item.packageType,
                  quantity: q,
                  length: item.length,
                  width: item.width,
                  height: item.height,
                  unit: item.unit,
                  grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                  isStackable: item.isStackable,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Length
        SizedBox(
          width: 100,
          child: TextFormField(
            key: ValueKey('cbm_len_${index}_$activeSessionId'),
            initialValue: item.length.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${l.lengthCol} (${item.unit})',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              final len = double.tryParse(v) ?? 0.0;
              onItemUpdated(
                CBMItemModel(
                  itemId: item.itemId,
                  calcId: item.calcId,
                  packageType: item.packageType,
                  quantity: item.quantity,
                  length: len,
                  width: item.width,
                  height: item.height,
                  unit: item.unit,
                  grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                  isStackable: item.isStackable,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Width
        SizedBox(
          width: 100,
          child: TextFormField(
            key: ValueKey('cbm_wid_${index}_$activeSessionId'),
            initialValue: item.width.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${l.widthCol} (${item.unit})',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              final w = double.tryParse(v) ?? 0.0;
              onItemUpdated(
                CBMItemModel(
                  itemId: item.itemId,
                  calcId: item.calcId,
                  packageType: item.packageType,
                  quantity: item.quantity,
                  length: item.length,
                  width: w,
                  height: item.height,
                  unit: item.unit,
                  grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                  isStackable: item.isStackable,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Height
        SizedBox(
          width: 100,
          child: TextFormField(
            key: ValueKey('cbm_hei_${index}_$activeSessionId'),
            initialValue: item.height.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${l.heightCol} (${item.unit})',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              final h = double.tryParse(v) ?? 0.0;
              onItemUpdated(
                CBMItemModel(
                  itemId: item.itemId,
                  calcId: item.calcId,
                  packageType: item.packageType,
                  quantity: item.quantity,
                  length: item.length,
                  width: item.width,
                  height: h,
                  unit: item.unit,
                  grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                  isStackable: item.isStackable,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Stacking Type
        SizedBox(
          width: 145,
          child: SearchableDropdownField<bool>(
            key: ValueKey('cbm_stack_${index}_$activeSessionId'),
            value: item.isStackable,
            labelText: l.stackingCol,
            searchHintText: l.stackingCol,
            items: [
              SearchableDropdownItem<bool>(value: true, label: l.stackableOption),
              SearchableDropdownItem<bool>(value: false, label: l.nonStackableOption),
            ],
            onChanged: (st) {
              if (st != null) {
                onItemUpdated(
                  CBMItemModel(
                    itemId: item.itemId,
                    calcId: item.calcId,
                    packageType: item.packageType,
                    quantity: item.quantity,
                    length: item.length,
                    width: item.width,
                    height: item.height,
                    unit: item.unit,
                    grossWeightPerUnitKg: item.grossWeightPerUnitKg,
                    isStackable: st,
                  ),
                );
              }
            },
          ),
        ),
        if (shipmentMode == 'air') ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextFormField(
              key: ValueKey('cbm_wt_${index}_$activeSessionId'),
              initialValue: item.grossWeightPerUnitKg.toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.grossWtPerUnitCol,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                final gw = double.tryParse(v) ?? 0.0;
                onItemUpdated(
                  CBMItemModel(
                    itemId: item.itemId,
                    calcId: item.calcId,
                    packageType: item.packageType,
                    quantity: item.quantity,
                    length: item.length,
                    width: item.width,
                    height: item.height,
                    unit: item.unit,
                    grossWeightPerUnitKg: gw,
                    isStackable: item.isStackable,
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(width: 14),

        // Computed outputs badge
        SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CopyableText(
                '${l.cbmRowLineCbm}: ${itemCbm.toStringAsFixed(4)} m³',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange, fontSize: 12),
              ),
              if (shipmentMode == 'air') ...[
                CopyableText(
                  '${l.cbmRowLineGross}: ${itemGross.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                CopyableText(
                  '${l.cbmRowLineAirVol}: ${itemVolWt.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                ),
              ],
            ],
          ),
        ),
        // Clone row button
        IconButton(
          icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt),
          tooltip: l.cloneQuickItemTooltip,
          onPressed: onClone,
        ),
        if (totalItemsCount > 1)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
            tooltip: l.deleteRowTooltip,
            onPressed: onDelete,
          ),
      ],
    );
  }
}
