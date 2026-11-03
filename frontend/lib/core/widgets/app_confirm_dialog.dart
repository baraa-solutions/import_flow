import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'buttons/app_button.dart';

/// 🗑️ Centralised Confirmation Dialog — ImportFlow ERP
///
/// Replaces the 280+ inline `showDialog<bool>(... AlertDialog ...)` patterns
/// across 118 files.
///
/// Usage:
/// ```dart
/// // Delete confirmation
/// final ok = await AppConfirmDialog.showDelete(
///   context,
///   entityName: supplier.name,
/// );
/// if (ok) await _deleteSupplier();
///
/// // Deactivate / Activate toggle
/// final ok = await AppConfirmDialog.showToggleActive(
///   context,
///   entityName: project.name,
///   isCurrentlyActive: project.isActive,
/// );
///
/// // Generic confirmation
/// final ok = await AppConfirmDialog.show(
///   context,
///   title: l10n.confirmActionTitle,
///   message: '...',
/// );
/// ```
abstract final class AppConfirmDialog {
  /// Shows a delete confirmation dialog.
  /// Returns `true` when the user confirmed, `false` / `null` otherwise.
  static Future<bool> showDelete(
    BuildContext context, {
    String? entityName,
    String? title,
    String? message,
  }) async {
    final l = context.l10n;
    final entitySuffix = entityName != null && entityName.isNotEmpty ? ' ($entityName)' : '';
    final defaultMessage = '${l.confirmSoftDelete}$entitySuffix؟';

    return _show(
      context,
      title: title ?? l.confirmSoftDelete,
      message: message ?? defaultMessage,
      confirmLabel: l.delete,
      confirmVariant: AppButtonVariant.danger,
      icon: Icons.delete_outline_rounded,
    );
  }

  /// Shows a deactivate/activate toggle confirmation dialog.
  static Future<bool> showToggleActive(
    BuildContext context, {
    required bool isCurrentlyActive,
    String? entityName,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
  }) async {
    final l = context.l10n;
    final entitySuffix = entityName != null && entityName.isNotEmpty ? ' ($entityName)' : '';

    if (isCurrentlyActive) {
      return _show(
        context,
        title: l.confirmActionTitle,
        message: message ?? '${l.deactivateBtn}$entitySuffix؟',
        confirmLabel: confirmLabel ?? l.deactivateBtn,
        cancelLabel: cancelLabel,
        confirmVariant: AppButtonVariant.warning,
        icon: Icons.block_outlined,
      );
    } else {
      return _show(
        context,
        title: l.confirmActionTitle,
        message: message ?? '${l.activateBtn}$entitySuffix؟',
        confirmLabel: confirmLabel ?? l.activateBtn,
        cancelLabel: cancelLabel,
        confirmVariant: AppButtonVariant.success,
        icon: Icons.check_circle_outline,
      );
    }
  }

  /// Shows a generic confirmation dialog.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    AppButtonVariant confirmVariant = AppButtonVariant.primary,
    IconData? icon,
  }) async {
    return _show(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmVariant: confirmVariant,
      icon: icon,
    );
  }

  // ─── Internal builder ────────────────────────────────────────────────────

  static Future<bool> _show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    AppButtonVariant confirmVariant = AppButtonVariant.danger,
    IconData? icon,
  }) async {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final iconColor = switch (confirmVariant) {
          AppButtonVariant.danger   => AppTheme.crimson,
          AppButtonVariant.warning  => AppTheme.orange,
          AppButtonVariant.success  => AppTheme.emerald,
          _                         => AppTheme.cobalt,
        };

        return Dialog(
          backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SelectionArea(
              child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: iconColor, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryOf(ctx),
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Message ────────────────────────────────────────────
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.textSecondaryOf(ctx),
                      height: 1.5,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Actions ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(
                        label: cancelLabel ?? l.cancel,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      const SizedBox(width: 10),
                      AppButton(
                        label: confirmLabel ?? l.confirm,
                        variant: confirmVariant,
                        size: AppButtonSize.small,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
    return result ?? false;
  }
}
