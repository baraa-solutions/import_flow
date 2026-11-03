import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/purchase_order_model.dart';
import '../../po_form_dialog.dart';
import '../po_form_load_planner_dialog.dart';
import 'pallet_card.dart';

/// Board containing master palletization plan cards and action buttons.
class PalletPlanBoard extends StatelessWidget {
  final POFormDialogState dialog;
  final bool isArabic;
  final AppLocalizations l;

  const PalletPlanBoard({
    super.key,
    required this.dialog,
    required this.isArabic,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pallet, color: AppTheme.cobalt, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l.masterPalletizationPlanTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      l.totalPalletsPill(dialog.dialogPalletItems.fold<int>(0, (sum, p) => sum + p.palletCount)),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      l.palletsVolumePill(dialog.dialogPalletItems.fold<double>(0.0, (sum, p) => sum + p.calculatedCbm).toStringAsFixed(3)),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                    ),
                  ),
                  AppButton(
                    label: l.addPalletRowBtn,
                    icon: Icons.add_circle_outline,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => dialog.updateState(() {
                      dialog.dialogPalletItems.add(PalletPlanItemModel(
                        palletType: 'Euro Pallet (120x80)',
                        palletCount: 1,
                        lengthCm: 120,
                        widthCm: 80,
                        heightCm: 150,
                      ));
                    }),
                  ),
                  AppButton(
                    label: l.simulateAndPackPallets3dBtn(dialog.dialogPalletItems.fold<int>(0, (sum, p) => sum + p.palletCount)),
                    icon: Icons.view_in_ar_rounded,
                    variant: AppButtonVariant.warning,
                    size: AppButtonSize.small,
                    onPressed: () => PoFormLoadPlannerDialog.show(
                      context,
                      packingItems: dialog.dialogPackingItems,
                      palletPlanItems: dialog.dialogPalletItems,
                      isDirectVolumeMode: dialog.isDirectVolumeMode,
                      poNumber: dialog.poReferenceCtrl.text.trim(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.cloudWhite),
          const SizedBox(height: 10),

          if (dialog.dialogPalletItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AppButton(
                  label: l.clickToAddPalletsPrompt,
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => dialog.updateState(() {
                    dialog.dialogPalletItems.add(PalletPlanItemModel(
                      palletType: 'Euro Pallet (120x80)',
                      palletCount: 1,
                      lengthCm: 120,
                      widthCm: 80,
                      heightCm: 150,
                    ));
                  }),
                ),
              ),
            )
          else
            ...dialog.dialogPalletItems.asMap().entries.map((entry) {
              return PalletCard(
                dialog: dialog,
                pIdx: entry.key,
                pLine: entry.value,
                isArabic: isArabic,
                l: l,
              );
            }),
        ],
      ),
    );
  }
}
