import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../models/purchase_order_model.dart';
import '../../po_form_dialog.dart';

/// Single editable pallet plan card.
class PalletCard extends StatelessWidget {
  final POFormDialogState dialog;
  final int pIdx;
  final PalletPlanItemModel pLine;
  final bool isArabic;
  final AppLocalizations l;

  const PalletCard({
    super.key,
    required this.dialog,
    required this.pIdx,
    required this.pLine,
    required this.isArabic,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.cloudWhite),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l.palletRowHeader(pIdx + 1),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: pLine.isStackable ? AppTheme.emeraldLight : AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pLine.isStackable ? AppTheme.emeraldBorder : AppTheme.orange),
                  ),
                  child: Text(
                    pLine.isStackable ? l.palletStackableBadge : l.palletFloorOnlyBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: pLine.isStackable ? AppTheme.wcagEmerald : AppTheme.wcagOrange,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  l.palletRowSummary(pLine.calculatedCbm.toStringAsFixed(3), pLine.totalWeightKg.toStringAsFixed(1)),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppTheme.crimson, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: l.deletePalletRowTooltip,
                  onPressed: () => dialog.updateState(() => dialog.dialogPalletItems.removeAt(pIdx)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<String>(
                    value: pLine.palletType,
                    labelText: l.palletTypeAndSizeLabel,
                    items: [
                      SearchableDropdownItem(
                        value: 'Euro Pallet (120x80)',
                        label: isArabic ? 'بالتة يورو (120 × 80 سم)' : 'Euro Pallet (120 × 80 cm)',
                      ),
                      SearchableDropdownItem(
                        value: 'Standard Pallet (120x100)',
                        label: isArabic ? 'بالتة قياسية (120 × 100 سم)' : 'Standard Pallet (120 × 100 cm)',
                      ),
                      SearchableDropdownItem(value: 'Custom Pallet', label: l.customPalletOption),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        double newL = pLine.lengthCm;
                        double newW = pLine.widthCm;
                        if (v.contains('120x80')) {
                          newL = 120.0;
                          newW = 80.0;
                        } else if (v.contains('120x100')) {
                          newL = 120.0;
                          newW = 100.0;
                        }
                        dialog.updateState(() {
                          dialog.dialogPalletItems[pIdx] = pLine.copyWith(
                            palletType: v,
                            lengthCm: newL,
                            widthCm: newW,
                          );
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: pLine.palletCount.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l.palletCountFieldLabel, isDense: true),
                    onChanged: (v) {
                      final count = int.tryParse(v) ?? 1;
                      dialog.updateState(() {
                        dialog.dialogPalletItems[pIdx] = pLine.copyWith(palletCount: count > 0 ? count : 1);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: SearchableDropdownField<bool>(
                    value: pLine.isStackable,
                    labelText: l.palletStackingInstructionsLabel,
                    items: [
                      SearchableDropdownItem(value: false, label: l.simulationModeFloorOnly),
                      SearchableDropdownItem(value: true, label: l.simulationModeStackable),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        dialog.updateState(() {
                          dialog.dialogPalletItems[pIdx] = pLine.copyWith(isStackable: v);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: pLine.lengthCm.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: isArabic ? 'الطول (سم)' : 'Length (cm)', isDense: true),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 120.0;
                      dialog.updateState(() {
                        dialog.dialogPalletItems[pIdx] = pLine.copyWith(lengthCm: val);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    initialValue: pLine.widthCm.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: isArabic ? 'العرض (سم)' : 'Width (cm)', isDense: true),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 80.0;
                      dialog.updateState(() {
                        dialog.dialogPalletItems[pIdx] = pLine.copyWith(widthCm: val);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    initialValue: pLine.heightCm.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: isArabic ? 'الارتفاع (سم)' : 'Height (cm)', isDense: true),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 150.0;
                      dialog.updateState(() {
                        dialog.dialogPalletItems[pIdx] = pLine.copyWith(heightCm: val);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    initialValue: pLine.grossWeightPerPalletKg.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'الوزن القائم للبالتة' : 'Gross Weight (kg)',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 500.0;
                      dialog.updateState(() {
                        dialog.dialogPalletItems[pIdx] = pLine.copyWith(grossWeightPerPalletKg: val);
                      });
                    },
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
