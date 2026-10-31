import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/cbm_calculator_model.dart';

class CbmItemsTable extends StatelessWidget {
  final List<CBMItemModel> items;
  final String shipmentMode;
  final int? activeSessionId;
  final ValueChanged<String> onShipmentModeChanged;
  final VoidCallback onAddPackageLine;
  final VoidCallback onSaveCalculation;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyPackagesTsv;
  final VoidCallback onCopyStudyReport;
  final void Function(int index, CBMItemModel updatedItem) onItemUpdated;
  final void Function(int index) onCloneItem;
  final void Function(int index) onDeleteItem;

  const CbmItemsTable({
    super.key,
    required this.items,
    required this.shipmentMode,
    required this.activeSessionId,
    required this.onShipmentModeChanged,
    required this.onAddPackageLine,
    required this.onSaveCalculation,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onCopyPackagesTsv,
    required this.onCopyStudyReport,
    required this.onItemUpdated,
    required this.onCloneItem,
    required this.onDeleteItem,
  });

  void _onPackageTypeSelected(int idx, String? v) {
    if (v == null || idx < 0 || idx >= items.length) return;
    final item = items[idx];
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
      idx,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Items Table Header & Action Card
        Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.format_list_bulleted, color: AppTheme.cobalt),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.packageMeasurementsTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Shipment Mode Selector (Air vs Sea vs Road)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: Text(l.airFreightMode),
                            selected: shipmentMode == 'air',
                            selectedColor: AppTheme.cobalt,
                            labelStyle: TextStyle(
                              color: shipmentMode == 'air' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => onShipmentModeChanged('air'),
                          ),
                          ChoiceChip(
                            label: Text(l.seaFreightMode),
                            selected: shipmentMode == 'sea',
                            selectedColor: AppTheme.emerald,
                            labelStyle: TextStyle(
                              color: shipmentMode == 'sea' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => onShipmentModeChanged('sea'),
                          ),
                          ChoiceChip(
                            label: Text(isArabic ? 'شحن بري (Road/LDM)' : 'Road Freight (LDM)'),
                            selected: shipmentMode == 'road',
                            selectedColor: AppTheme.wcagOrange,
                            labelStyle: TextStyle(
                              color: shipmentMode == 'road' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => onShipmentModeChanged('road'),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      label: l.addPackageLine,
                      icon: Icons.add,
                      variant: AppButtonVariant.primary,
                      onPressed: onAddPackageLine,
                    ),
                    AppButton(
                      label: activeSessionId != null ? l.saveChanges : l.saveCalculationSession,
                      icon: Icons.save_outlined,
                      variant: AppButtonVariant.success,
                      onPressed: onSaveCalculation,
                    ),
                    AppButton(
                      label: isArabic ? 'تصدير إكسيل' : 'Export Excel',
                      icon: Icons.table_chart,
                      variant: AppButtonVariant.success,
                      onPressed: onExportExcel,
                    ),
                    AppButton(
                      label: isArabic ? 'تصدير PDF' : 'Export PDF',
                      icon: Icons.picture_as_pdf,
                      variant: AppButtonVariant.danger,
                      onPressed: onExportPdf,
                    ),
                    AppButton(
                      label: isArabic ? 'نسخ الطرود' : 'Copy Packages',
                      icon: Icons.content_copy,
                      variant: AppButtonVariant.secondary,
                      onPressed: onCopyPackagesTsv,
                    ),
                    AppButton(
                      label: isArabic ? 'نسخ التقرير الفني' : 'Copy Study Report',
                      icon: Icons.assignment_outlined,
                      variant: AppButtonVariant.primary,
                      onPressed: onCopyStudyReport,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Dynamic Line Items List Table
        Card(
          elevation: 1,
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: shipmentMode == 'air' ? 1380 : 1260,
              ),
              child: SizedBox(
                width: math.max(
                  shipmentMode == 'air' ? 1380.0 : 1260.0,
                  MediaQuery.of(context).size.width - 64,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table Header Bar
                    Container(
                      color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '#',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 160,
                            child: Text(
                              l.packageTypeCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 95,
                            child: Text(
                              l.unitCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              l.qtyCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: Text(
                              l.lengthCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: Text(
                              l.widthCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: Text(
                              l.heightCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 145,
                            child: Text(
                              l.stackingCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          if (shipmentMode == 'air') ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              child: Text(
                                l.grossWtPerUnitCol,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 140,
                            child: Text(
                              l.calculatedOutputsCol,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 96),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, idx) {
                        final item = items[idx];
                        final lM = item.lengthM;
                        final wM = item.widthM;
                        final hM = item.heightM;
                        final itemCbm = item.quantity * lM * wM * hM;
                        final itemVolWt = item.quantity * lM * wM * hM * kAirVolumetricKgPerCbm;
                        final itemGross = item.quantity * item.grossWeightPerUnitKg;

                        return Row(
                          key: ValueKey('row_${idx}_${activeSessionId}_${item.itemId}'),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${idx + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Package Type Dropdown
                            SizedBox(
                              width: 160,
                              child: SearchableDropdownField<String>(
                                key: ValueKey('cbm_type_${idx}_$activeSessionId'),
                                value: item.packageType,
                                labelText: l.packageTypeCol,
                                searchHintText: l.packageTypeCol,
                                items: [
                                  'Carton',
                                  'Euro Pallet (120x80)',
                                  'Standard Pallet (120x100)',
                                  'Custom Pallet',
                                  'Wooden Crate',
                                  'Drum',
                                  'Bag',
                                  'Loose Box'
                                ].map((t) => SearchableDropdownItem<String>(value: t, label: t)).toList(),
                                onChanged: (v) => _onPackageTypeSelected(idx, v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Dimension Unit Selector
                            SizedBox(
                              width: 95,
                              child: SearchableDropdownField<String>(
                                key: ValueKey('cbm_unit_${idx}_$activeSessionId'),
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
                                      idx,
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
                                key: ValueKey('cbm_qty_${idx}_$activeSessionId'),
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
                                    idx,
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
                                key: ValueKey('cbm_len_${idx}_$activeSessionId'),
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
                                    idx,
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
                                key: ValueKey('cbm_wid_${idx}_$activeSessionId'),
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
                                    idx,
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
                                key: ValueKey('cbm_hei_${idx}_$activeSessionId'),
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
                                    idx,
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
                                key: ValueKey('cbm_stack_${idx}_$activeSessionId'),
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
                                      idx,
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
                                  key: ValueKey('cbm_wt_${idx}_$activeSessionId'),
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
                                      idx,
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
                              onPressed: () => onCloneItem(idx),
                            ),
                            if (items.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.crimson),
                                tooltip: l.deleteRowTooltip,
                                onPressed: () => onDeleteItem(idx),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
