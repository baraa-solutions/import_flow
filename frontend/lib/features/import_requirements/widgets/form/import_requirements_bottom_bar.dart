import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// 🔘 Bottom Action Bar for Import Requirements Form — ImportFlow ERP
class ImportRequirementsBottomBar extends StatelessWidget {
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onAutoComplete;
  final VoidCallback onRefresh;
  final VoidCallback onReset;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;

  const ImportRequirementsBottomBar({
    super.key,
    required this.isEditing,
    required this.isSaving,
    required this.onAutoComplete,
    required this.onRefresh,
    required this.onReset,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cloudWhite),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            AppButton(
              label: l10n.completeAllPillarsBtn,
              icon: Icons.bolt,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: onAutoComplete,
            ),
            const SizedBox(width: 8),
            AppButton(
              label: l10n.refresh,
              icon: Icons.refresh,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: onRefresh,
            ),
            const SizedBox(width: 8),
            AppButton(
              label: l10n.cancelEditingAndStartNewBtn,
              icon: Icons.cleaning_services_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: onReset,
            ),
            const SizedBox(width: 8),
            AppButton(
              label: l10n.saveRequirementDraftBtn,
              icon: Icons.save_outlined,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: isSaving ? null : onSaveDraft,
            ),
            const SizedBox(width: 16),
            AppButton(
              label: isEditing ? l10n.updateRequirementSubmitBtn : l10n.saveRequirementSubmitBtn,
              icon: Icons.check_circle_outline,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              isLoading: isSaving,
              onPressed: isSaving ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
