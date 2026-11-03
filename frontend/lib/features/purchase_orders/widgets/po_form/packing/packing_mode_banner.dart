import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../models/purchase_order_model.dart';
import '../../po_form_dialog.dart';

/// Choice banner for switching between Explicit Dimensions and Direct Volume modes.
class PackingModeBanner extends StatelessWidget {
  final POFormDialogState dialog;
  final bool isArabic;

  const PackingModeBanner({
    super.key,
    required this.dialog,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cloudWhite),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.tune_rounded, color: AppTheme.charcoal, size: 20),
          Text(
            isArabic ? 'مسار معالجة الشحنة:' : 'Cargo Input Mode:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
          ),
          ChoiceChip(
            label: Text(isArabic ? 'مسار الأبعاد الصريحة' : 'Explicit Dimensions Mode'),
            selected: !dialog.isDirectVolumeMode,
            onSelected: (val) {
              if (val) dialog.updateState(() => dialog.isDirectVolumeMode = false);
            },
            selectedColor: AppTheme.cobalt.withValues(alpha: 0.18),
          ),
          ChoiceChip(
            label: Text(isArabic ? 'مسار الحجم المباشر ومخطط البالتات' : 'Direct Volume & Pallet Plan'),
            selected: dialog.isDirectVolumeMode,
            onSelected: (val) {
              if (val) {
                dialog.updateState(() {
                  dialog.isDirectVolumeMode = true;
                  if (dialog.dialogPalletItems.isEmpty) {
                    dialog.dialogPalletItems.add(PalletPlanItemModel(
                      palletType: 'Euro Pallet (120x80)',
                      palletCount: 1,
                      lengthCm: 120,
                      widthCm: 80,
                      heightCm: 150,
                    ));
                  }
                });
              }
            },
            selectedColor: AppTheme.emerald.withValues(alpha: 0.18),
          ),
        ],
      ),
    );
  }
}
