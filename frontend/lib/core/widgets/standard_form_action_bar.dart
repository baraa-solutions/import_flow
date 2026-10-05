import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'buttons/app_button.dart';

/// Reusable Standard Form Action Bar across all screens in Sorour Logistics ERP.
///
/// Uses [AppButton] for consistent styling — no inline ElevatedButton.styleFrom().
///
/// Buttons (shown only when the corresponding callback is provided):
/// 1. 🔄 Live Refresh     — [onRefresh]
/// 2. ✕  Close / Cancel   — [onClose]   (always shown unless showCloseButton=false)
/// 3. 🧹 Reset Form       — [onResetForm]
/// 4. 💾 Save Draft       — [onSaveDraft]
/// 5. ✅ Save & Confirm   — [onSubmit]
class StandardFormActionBar extends StatelessWidget {
  final VoidCallback? onSaveDraft;
  final VoidCallback? onResetForm;
  final VoidCallback? onRefresh;
  final VoidCallback? onSubmit;
  final VoidCallback? onClose;

  // Optional label overrides (falls back to l10n strings)
  final String? submitLabel;
  final String? saveDraftLabel;
  final String? resetFormLabel;
  final String? refreshLabel;
  final String? closeLabel;

  final bool isSaving;
  final bool isSubmitting;
  final bool isEditing;
  final bool showCloseButton;
  final Widget? leadingWidget;
  final List<Widget>? extraActions;

  const StandardFormActionBar({
    super.key,
    this.onSaveDraft,
    this.onResetForm,
    this.onRefresh,
    this.onSubmit,
    this.onClose,
    this.submitLabel,
    this.saveDraftLabel,
    this.resetFormLabel,
    this.refreshLabel,
    this.closeLabel,
    this.isSaving = false,
    this.isSubmitting = false,
    this.isEditing = false,
    this.showCloseButton = true,
    this.leadingWidget,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
      decoration: AppTheme.cardDecorationOf(context),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // ── Left section: leading widget + extra actions + live refresh ───
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingWidget != null) ...[
                leadingWidget!,
                const SizedBox(width: 8),
              ],
              if (extraActions != null) ...[
                ...extraActions!,
                const SizedBox(width: 8),
              ],
              if (onRefresh != null)
                AppButton(
                  label: refreshLabel ?? l.liveRefresh,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  icon: Icons.refresh,
                  onPressed: onRefresh,
                ),
            ],
          ),

          // ── Right section: action buttons ─────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close / Cancel
              if (showCloseButton || onClose != null) ...[
                AppButton(
                  label: closeLabel ?? l.close,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                  icon: Icons.close,
                  onPressed: onClose ??
                      () {
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      },
                ),
                const SizedBox(width: 8),
              ],

              // Reset Form
              if (onResetForm != null) ...[
                AppButton(
                  label: resetFormLabel ?? l.resetForm,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  icon: Icons.cleaning_services_outlined,
                  onPressed: onResetForm,
                ),
                const SizedBox(width: 8),
              ],

              // Save Draft
              if (onSaveDraft != null) ...[
                AppButton(
                  label: saveDraftLabel ?? l.saveDraft,
                  variant: AppButtonVariant.saveDraft,
                  size: AppButtonSize.small,
                  icon: Icons.save_outlined,
                  isLoading: isSaving,
                  onPressed: onSaveDraft,
                ),
                const SizedBox(width: 8),
              ],

              // Submit / Final Save
              if (onSubmit != null)
                AppButton(
                  label: isEditing
                      ? (submitLabel ?? l.updateRecord)
                      : (submitLabel ?? l.saveAndConfirm),
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.medium,
                  icon: Icons.check_circle_outline,
                  isLoading: isSaving || isSubmitting,
                  onPressed: onSubmit,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
