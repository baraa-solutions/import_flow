import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../providers/auth_provider.dart';
import '../providers/password_change_provider.dart';
import '../providers/rbac_provider.dart';
import '../providers/users_provider.dart';
import '../widgets/password_input_field.dart';

/// Mandatory "change your password" screen shown instead of the app shell
/// while the signed-in account is flagged `must_change_password` (e.g. the
/// seeded admin on a new install). The only other action is logging out.
class ForceChangePasswordScreen extends ConsumerStatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  ConsumerState<ForceChangePasswordScreen> createState() => _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends ConsumerState<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The flag can also flip mid-session (403 PASSWORD_CHANGE_REQUIRED):
      // close dialogs left open by the app shell and drop queued error toasts.
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _message(PasswordFieldError? error, String requiredText) {
    final l = context.l10n;
    switch (error) {
      case null:
        return null;
      case PasswordFieldError.required:
        return requiredText;
      case PasswordFieldError.tooShort:
        return l.forcePwdTooShort;
      case PasswordFieldError.sameAsCurrent:
        return l.forcePwdSameAsCurrent;
      case PasswordFieldError.mismatch:
        return l.forcePwdMismatch;
    }
  }

  void _clearServerError(String _) {
    if (_serverError != null) setState(() => _serverError = null);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final result = await ref.read(passwordChangeRepositoryProvider).changePassword(
            currentPassword: _currentCtrl.text,
            newPassword: _newCtrl.text,
          );
      // Clearing the flag lets the shell guard route to the app.
      await ref.read(authProvider.notifier).applyUserJson(result.userJson);
      ref.invalidate(rbacProvider);
      ref.invalidate(usersProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        AppTheme.snackBar(context, l.forcePwdSuccess, severity: AppSeverity.success),
      );
    } on PasswordChangeException catch (e) {
      final msg = e.message ?? l.forcePwdFailed;
      if (mounted) {
        setState(() => _serverError = msg);
        messenger.showSnackBar(
          AppTheme.snackBar(context, msg, severity: AppSeverity.danger),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _serverError = l.forcePwdFailed);
        messenger.showSnackBar(
          AppTheme.snackBar(context, l.forcePwdFailed, severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final user = ref.watch(authProvider.select((s) => s.user));
    final muted = isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : AppTheme.charcoal,
      body: SelectionArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(color: AppTheme.orangeLight, shape: BoxShape.circle),
                        child: const Icon(Icons.lock_reset_rounded, size: 44, color: AppTheme.orange),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.forcePwdTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.cloudWhite : AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.forcePwdSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 13, height: 1.4),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${l.forcePwdAccountLabel}: ${user.username}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_serverError != null) _ErrorBanner(message: _serverError!),
                    PasswordInputField(
                      key: const ValueKey('force_pwd_current'),
                      controller: _currentCtrl,
                      label: l.forcePwdCurrentLabel,
                      enabled: !_submitting,
                      onChanged: _clearServerError,
                      validator: (v) => _message(PasswordChangeValidator.current(v), l.forcePwdCurrentRequired),
                    ),
                    const SizedBox(height: 14),
                    PasswordInputField(
                      key: const ValueKey('force_pwd_new'),
                      controller: _newCtrl,
                      label: l.forcePwdNewLabel,
                      icon: Icons.password_rounded,
                      enabled: !_submitting,
                      onChanged: _clearServerError,
                      validator: (v) => _message(
                        PasswordChangeValidator.newPassword(v, _currentCtrl.text),
                        l.forcePwdNewRequired,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PasswordInputField(
                      key: const ValueKey('force_pwd_confirm'),
                      controller: _confirmCtrl,
                      label: l.forcePwdConfirmLabel,
                      icon: Icons.password_rounded,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.done,
                      onChanged: _clearServerError,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => _message(
                        PasswordChangeValidator.confirm(v, _newCtrl.text),
                        l.forcePwdConfirmRequired,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(l.forcePwdPolicyHint, style: TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 24),
                    AppButton(
                      key: const ValueKey('force_pwd_submit'),
                      label: l.forcePwdSubmit,
                      icon: Icons.check_circle_outline,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.large,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      key: const ValueKey('force_pwd_logout'),
                      label: l.logout,
                      icon: Icons.logout_rounded,
                      variant: AppButtonVariant.ghost,
                      onPressed: _submitting ? null : () => ref.read(authProvider.notifier).logout(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.crimsonLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.crimsonBorder, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.crimson, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
