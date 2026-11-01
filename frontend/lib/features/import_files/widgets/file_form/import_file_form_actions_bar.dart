import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// 🚢 Modular Actions Bar for [ImportFileFormDialog].
///
/// Canonical action toolbar supporting live reload, form reset, draft saving,
/// cancellation (with unsaved changes check), and final validation & submission.
class ImportFileFormActionsBar extends StatelessWidget {
  final bool isEdit;
  final bool isSaving;
  final VoidCallback onReload;
  final VoidCallback onReset;
  final VoidCallback onSaveDraft;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const ImportFileFormActionsBar({
    super.key,
    required this.isEdit,
    required this.isSaving,
    required this.onReload,
    required this.onReset,
    required this.onSaveDraft,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(
          label: l.liveReload,
          icon: Icons.refresh,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          onPressed: onReload,
        ),
        AppButton(
          label: l.clearAndReset,
          icon: Icons.cleaning_services_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onReset,
        ),
        AppButton(
          label: l.saveDraft,
          icon: Icons.save_outlined,
          variant: AppButtonVariant.saveDraft,
          size: AppButtonSize.small,
          isLoading: isSaving,
          onPressed: isSaving ? null : onSaveDraft,
        ),
        AppButton(
          label: l.cancel,
          icon: Icons.close,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onCancel,
        ),
        AppButton(
          label: l.save,
          icon: Icons.check,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.medium,
          isLoading: isSaving,
          onPressed: isSaving ? null : onSubmit,
        ),
      ],
    );
  }
}
