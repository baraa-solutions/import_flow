import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/lifecycle_board_model.dart';
import '../../providers/lifecycle_board_provider.dart';

class StepActionDialogHandlers {
  static Future<void> handleSkipStep({
    required BuildContext context,
    required WidgetRef ref,
    required ShipmentStageCardModel shipment,
    required List<String> selectedNextSteps,
    required void Function(bool) setSaving,
  }) async {
    final l10n = context.l10n;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return SelectionArea(
          child: AlertDialog(
            backgroundColor: AppTheme.surfaceOf(ctx),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            title: Row(
              children: [
                const Icon(Icons.fast_forward_rounded, color: AppTheme.orange),
                const SizedBox(width: 8),
                Text(
                  l10n.skipStepDialogTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryOf(ctx)),
                ),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.skipStepConfirmText(l10n.lifecycleStepName(shipment.stepCode), shipment.importFileCode),
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(ctx)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: l10n.skipReasonLabel,
                        hintText: l10n.skipReasonHint,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: l10n.copyValue,
                          onPressed: () => CopyHelper.copy(ctx, reasonController.text),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? l10n.skipReasonRequired : null,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.orange),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                icon: const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
                label: Text(l10n.confirmSkipAndAdvanceBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      setSaving(true);
      final notifier = ref.read(lifecycleBoardActionProvider.notifier);
      final success = await notifier.skipStep(
        importFileCode: shipment.importFileCode,
        currentStepCode: shipment.stepCode,
        skipReason: reasonController.text.trim(),
        nextStepCodes: selectedNextSteps,
      );
      if (context.mounted) {
        setSaving(false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.orange,
              content: Text(
                l10n.stepSkippedSuccessSnack(selectedNextSteps.join(', '), shipment.importFileCode),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        } else {
          final errorMsg = notifier.lastErrorMessage ?? l10n.stepAdvanceErrorSnack;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.crimson,
              duration: const Duration(seconds: 6),
              content: Text(
                errorMsg,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    }
  }

  static Future<void> handleHoldOrResume({
    required BuildContext context,
    required WidgetRef ref,
    required ShipmentStageCardModel shipment,
    required void Function(bool) setSaving,
  }) async {
    final l10n = context.l10n;
    final isOnHold = shipment.status == 'On-Hold';
    if (isOnHold) {
      setSaving(true);
      final notifier = ref.read(lifecycleBoardActionProvider.notifier);
      final success = await notifier.setMultiActiveStages(
        importFileCode: shipment.importFileCode,
        activeStepCodes: [shipment.stepCode],
        notes: 'Resumed workflow from active stage',
      );
      if (context.mounted) {
        setSaving(false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.emerald,
              content: Text(l10n.shipmentResumedSuccessSnack),
            ),
          );
        }
      }
    } else {
      final reasonController = TextEditingController();
      final formKey = GlobalKey<FormState>();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return SelectionArea(
            child: AlertDialog(
              backgroundColor: AppTheme.surfaceOf(ctx),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              title: Row(
                children: [
                  const Icon(Icons.pause_circle_outline_rounded, color: AppTheme.crimson),
                  const SizedBox(width: 8),
                  Text(l10n.holdDialogTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimaryOf(ctx))),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.holdConfirmText(shipment.importFileCode, l10n.lifecycleStepName(shipment.stepCode)),
                        style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(ctx)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: l10n.holdReasonLabel,
                          hintText: l10n.holdReasonHint,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: l10n.copyValue,
                            onPressed: () => CopyHelper.copy(ctx, reasonController.text),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.holdReasonRequired : null,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 18),
                  label: Text(l10n.confirmHoldBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      );

      if (confirmed == true && context.mounted) {
        setSaving(true);
        final notifier = ref.read(lifecycleBoardActionProvider.notifier);
        final success = await notifier.advanceStep(
          importFileCode: shipment.importFileCode,
          currentStepCode: shipment.stepCode,
          nextStepCodes: [shipment.stepCode],
          notes: 'On-Hold: ${reasonController.text.trim()}',
        );
        if (context.mounted) {
          setSaving(false);
          if (success) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.crimson,
                content: Text(l10n.shipmentHeldSuccessSnack),
              ),
            );
          }
        }
      }
    }
  }
}
