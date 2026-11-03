import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../po_form_dialog.dart';
import '../po_form_load_planner_dialog.dart';

/// Header section with action buttons for packing list entries.
class PackingEntriesHeader extends StatelessWidget {
  final POFormDialogState dialog;
  final AppLocalizations l;
  final VoidCallback onAutoFill;
  final VoidCallback onAddEntry;

  const PackingEntriesHeader({
    super.key,
    required this.dialog,
    required this.l,
    required this.onAutoFill,
    required this.onAddEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          l.packingListEntriesSection,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: l.autoFillFromInvoice,
              icon: Icons.auto_fix_high,
              variant: AppButtonVariant.primary,
              fit: true,
              onPressed: onAutoFill,
            ),
            AppButton(
              label: l.simulateAndPack3d,
              icon: Icons.view_in_ar_rounded,
              variant: AppButtonVariant.secondary,
              fit: true,
              onPressed: () => PoFormLoadPlannerDialog.show(
                context,
                packingItems: dialog.dialogPackingItems,
                palletPlanItems: dialog.dialogPalletItems,
                isDirectVolumeMode: dialog.isDirectVolumeMode,
                poNumber: dialog.poReferenceCtrl.text.trim(),
              ),
            ),
            AppButton(
              label: l.addPackingEntryBtn,
              icon: Icons.playlist_add,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              fit: true,
              onPressed: onAddEntry,
            ),
          ],
        ),
      ],
    );
  }
}
