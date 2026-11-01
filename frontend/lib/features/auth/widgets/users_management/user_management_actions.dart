import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/users_provider.dart';
import 'user_form_dialog.dart';
import 'user_permissions_dialog.dart';
import 'user_reset_password_dialog.dart';

/// Interactive action buttons for a single row in the Users Management table.
class UserRowActions extends ConsumerWidget {
  final UserDetail user;
  final bool isAdmin;
  final bool isSelf;
  final String rowSummary;

  const UserRowActions({
    super.key,
    required this.user,
    required this.isAdmin,
    required this.isSelf,
    required this.rowSummary,
  });

  /// Shows confirmation dialog and performs status toggle (activate / deactivate).
  static Future<void> showToggleConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    UserDetail user,
  ) async {
    final l = context.l10n;
    final isActivating = !user.isActive;

    final confirmed = await AppConfirmDialog.showToggleActive(
      context,
      isCurrentlyActive: user.isActive,
      entityName: '${user.fullName} (@${user.username})',
      confirmLabel: isActivating ? l.usersMgmtBtnActivate : l.usersMgmtBtnDeactivate,
      cancelLabel: l.usersMgmtBtnCancel,
    );

    if (!confirmed || !context.mounted) return;
    final error = await ref.read(usersProvider.notifier).toggleUserStatus(user.userId);

    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, error, severity: AppSeverity.danger),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isActivating ? l.usersMgmtSuccessActivated : l.usersMgmtSuccessDeactivated,
          severity: isActivating ? AppSeverity.success : AppSeverity.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final resetPasswordTooltip = isAr ? 'إعادة تعيين كلمة المرور' : 'Reset Password';

    return SizedBox(
      width: 170,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdmin) ...[
            // Edit User
            Tooltip(
              message: l.usersMgmtActionEditTooltip,
              child: InkWell(
                onTap: () => UserFormDialog.show(context, editUser: user),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.cobalt),
                ),
              ),
            ),
            const SizedBox(width: 2),

            // RBAC Permissions
            Tooltip(
              message: l.usersMgmtActionPermissionsTooltip,
              child: InkWell(
                onTap: () => UserPermissionsDialog.show(context, ref, user: user),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: const Icon(Icons.security_rounded, size: 16, color: AppTheme.orange),
                ),
              ),
            ),
            const SizedBox(width: 2),

            // Reset Password
            Tooltip(
              message: resetPasswordTooltip,
              child: InkWell(
                onTap: () => UserResetPasswordDialog.show(context, user: user),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: const Icon(Icons.lock_reset_rounded, size: 16, color: AppTheme.cobalt),
                ),
              ),
            ),
            const SizedBox(width: 2),

            // Toggle Active / Deactivate (cannot deactivate self)
            if (!isSelf)
              Tooltip(
                message: user.isActive ? l.usersMgmtActionDeactivateTooltip : l.usersMgmtActionActivateTooltip,
                child: InkWell(
                  onTap: () => showToggleConfirmDialog(context, ref, user),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      user.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                      size: 16,
                      color: user.isActive ? AppTheme.crimson : AppTheme.emerald,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 26),
            const SizedBox(width: 2),
          ],

          // Quick copy row summary
          Tooltip(
            message: l.usersMgmtCopyRowSummaryBtn,
            child: InkWell(
              onTap: () => CopyHelper.copy(
                context,
                rowSummary,
                customMessage: l.usersMgmtCopyRowSummarySuccess,
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(5),
                child: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.charcoal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
