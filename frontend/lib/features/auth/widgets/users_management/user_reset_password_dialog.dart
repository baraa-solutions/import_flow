import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/users_provider.dart';

/// Modal dialog for administrative password reset of a given [user].
class UserResetPasswordDialog extends ConsumerStatefulWidget {
  final UserDetail user;

  const UserResetPasswordDialog({
    super.key,
    required this.user,
  });

  static Future<void> show(BuildContext context, {required UserDetail user}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserResetPasswordDialog(user: user),
    );
  }

  @override
  ConsumerState<UserResetPasswordDialog> createState() => _UserResetPasswordDialogState();
}

class _UserResetPasswordDialogState extends ConsumerState<UserResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final messenger = ScaffoldMessenger.of(context);

    final error = await ref.read(usersProvider.notifier).updateUser(
          userId: widget.user.userId,
          password: _passwordCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, error, severity: AppSeverity.danger),
      );
    } else {
      Navigator.of(context).pop();
      final successMsg = isAr
          ? 'تم تغيير كلمة المرور بنجاح للمستخدم @${widget.user.username}'
          : 'Password updated successfully for @${widget.user.username}';
      messenger.showSnackBar(
        AppTheme.snackBar(context, successMsg, severity: AppSeverity.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final dialogTitle = isAr ? 'إعادة تعيين كلمة المرور' : 'Reset Password';

    return SelectionArea(
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppTheme.charcoal,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${widget.user.username} — ${widget.user.fullName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // ── New Password ──────────────────────────────────────────
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l.usersMgmtFieldPasswordNew,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.usersMgmtFieldPasswordRequired;
                    }
                    if (v.trim().length < 6) {
                      return l.usersMgmtFieldPasswordMinLength;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Confirm Password ──────────────────────────────────────
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: l.forcePwdConfirmLabel,
                    prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.forcePwdConfirmRequired;
                    }
                    if (v.trim() != _passwordCtrl.text.trim()) {
                      return l.forcePwdMismatch;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text(l.usersMgmtBtnCancel),
          ),
          AppButton(
            label: l.usersMgmtBtnSave,
            variant: AppButtonVariant.primary,
            icon: Icons.save_rounded,
            isLoading: _isSaving,
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }
}
