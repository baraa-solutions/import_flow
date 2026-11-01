import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../models/cargox_model.dart';

/// Pallets data list and add dialog for dual extraction
class PalletsManagementPanel extends StatelessWidget {
  final List<PalletInputModel> pallets;
  final ValueChanged<PalletInputModel> onPalletAdded;
  final ValueChanged<int> onPalletRemoved;

  const PalletsManagementPanel({
    super.key,
    required this.pallets,
    required this.onPalletAdded,
    required this.onPalletRemoved,
  });

  void _showAddPalletDialog(BuildContext context, AppLocalizations l, bool isAr) {
    final palletNumCtrl = TextEditingController(text: 'PLT-${(pallets.length + 1).toString().padLeft(3, "0")}');
    final dimsCtrl = TextEditingController();
    final grossCtrl = TextEditingController();
    final netCtrl = TextEditingController();
    String palletType = 'EURO';

    final palletTypeOptions = isAr
        ? [
            ('EURO', 'بالتة أوروبية'),
            ('CHEP', 'بالتة شيب زرقاء'),
            ('CUSTOM', 'بالتة مقاس خاص'),
            ('WOODEN', 'بالتة خشبية قياسية'),
          ]
        : [
            ('EURO', 'EURO Standard'),
            ('CHEP', 'CHEP Blue Pallet'),
            ('CUSTOM', 'Custom Dimensions'),
            ('WOODEN', 'Standard Wooden'),
          ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => SelectionArea(
          child: AlertDialog(
            title: Text(l.dualExtractionAddPalletBtn, style: const TextStyle(fontSize: 14)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: palletNumCtrl,
                    decoration: InputDecoration(
                      labelText: isAr ? 'رقم البالتة' : 'Pallet Number',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SearchableDropdownField<String>(
                    value: palletType,
                    labelText: isAr ? 'نوع البالتة' : 'Pallet Type',
                    items: palletTypeOptions
                        .map((t) => SearchableDropdownItem<String>(value: t.$1, label: t.$2))
                        .toList(),
                    onChanged: (v) => setInnerState(() => palletType = v ?? 'EURO'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: dimsCtrl,
                    decoration: InputDecoration(
                      labelText: isAr ? 'الأبعاد سم — مثال: 120×80×150' : 'Dimensions cm (e.g. 120x80x150)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: grossCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isAr ? 'الوزن القائم كجم' : 'Gross Weight (kg)',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: netCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isAr ? 'الوزن الصافي كجم' : 'Net Weight (kg)',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isAr ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final pallet = PalletInputModel(
                    palletNumber: palletNumCtrl.text.trim(),
                    palletType: palletType,
                    dimensionsCm: dimsCtrl.text.trim().isEmpty ? null : dimsCtrl.text.trim(),
                    grossWeightKg: double.tryParse(grossCtrl.text) ?? 0.0,
                    netWeightKg: double.tryParse(netCtrl.text) ?? 0.0,
                  );
                  onPalletAdded(pallet);
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
                child: Text(isAr ? 'إضافة' : 'Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPalletTile(BuildContext context, int index, PalletInputModel pallet, AppLocalizations l, bool isAr) {
    final weightGrossLabel = isAr ? 'الوزن القائم:' : 'Gross:';
    final weightNetLabel = isAr ? 'الصافي:' : 'Net:';
    final kgLabel = isAr ? 'كجم' : 'kg';
    final itemsLabel = isAr ? 'بند' : 'items';
    final cmLabel = isAr ? 'سم' : 'cm';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_rows_outlined, size: 18, color: AppTheme.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pallet.palletNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(
                  '${pallet.palletType}  ·  ${pallet.items.length} $itemsLabel  ·  '
                  '$weightGrossLabel ${pallet.grossWeightKg} $kgLabel  ·  $weightNetLabel ${pallet.netWeightKg} $kgLabel'
                  '${pallet.dimensionsCm != null ? "  ·  ${pallet.dimensionsCm} $cmLabel" : ""}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.grey, size: 16),
            onPressed: () => CopyHelper.copy(
              context,
              '${pallet.palletNumber}: ${pallet.palletType}, ${pallet.grossWeightKg} $kgLabel',
              customMessage: l.copyTooltip,
            ),
            tooltip: l.copyTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: () => onPalletRemoved(index),
            tooltip: isAr ? 'حذف البالتة' : 'Remove Pallet',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF1FBF5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_module_outlined, color: AppTheme.emerald, size: 18),
              const SizedBox(width: 8),
              Text(l.dualExtractionPalletDataTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showAddPalletDialog(context, l, isAr),
                icon: const Icon(Icons.add, size: 14),
                label: Text(l.dualExtractionAddPalletBtn, style: const TextStyle(fontSize: 11)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          if (pallets.isEmpty) ...[
            const SizedBox(height: 12),
            Center(child: Text(l.dualExtractionNoPallets, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          ] else ...[
            const SizedBox(height: 10),
            ...pallets.asMap().entries.map((e) => _buildPalletTile(context, e.key, e.value, l, isAr)),
          ],
        ],
      ),
    );
  }
}
