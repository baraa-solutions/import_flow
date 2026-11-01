import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/users_provider.dart';
import 'role_description_card.dart';

/// Modal dialog for adding a new user or editing an existing user.
class UserFormDialog extends ConsumerStatefulWidget {
  final UserDetail? editUser;

  const UserFormDialog({
    super.key,
    this.editUser,
  });

  static Future<void> show(BuildContext context, {UserDetail? editUser}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserFormDialog(editUser: editUser),
    );
  }

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late String _selectedRole;
  bool _obscurePassword = true;
  bool _isSaving = false;

  bool get _isEdit => widget.editUser != null;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(text: widget.editUser?.fullName ?? '');
    _usernameCtrl = TextEditingController(text: widget.editUser?.username ?? '');
    _emailCtrl = TextEditingController(text: widget.editUser?.email ?? '');
    _passwordCtrl = TextEditingController();
    _selectedRole = widget.editUser?.role.toUpperCase() ?? 'OPERATOR';
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    String? error;
    if (_isEdit) {
      error = await ref.read(usersProvider.notifier).updateUser(
            userId: widget.editUser!.userId,
            fullName: _fullNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            role: _selectedRole,
            password: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
          );
    } else {
      error = await ref.read(usersProvider.notifier).createUser(
            username: _usernameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            fullName: _fullNameCtrl.text.trim(),
            role: _selectedRole,
            password: _passwordCtrl.text,
          );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, error, severity: AppSeverity.danger),
      );
    } else {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        AppTheme.snackBar(
          context,
          _isEdit ? l.usersMgmtSuccessUpdated : l.usersMgmtSuccessCreated,
          severity: AppSeverity.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: AlertDialog(
        titlePadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                child: Icon(
                  _isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isEdit ? l.usersMgmtDialogEditTitle : l.usersMgmtDialogNewTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // ── Full Name ──────────────────────────────────────────────
                  TextFormField(
                    controller: _fullNameCtrl,
                    decoration: InputDecoration(
                      labelText: l.usersMgmtFieldFullName,
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      hintText: l.usersMgmtFieldFullNameHint,
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _fullNameCtrl,
                        builder: (context, val, _) => val.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                tooltip: l.usersMgmtCopyFieldTooltip(l.usersMgmtFieldFullName),
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  val.text,
                                  customMessage: l.usersMgmtCopyBadgeSuccess(l.usersMgmtFieldFullName, val.text),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.usersMgmtFieldFullNameRequired : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Username (disable on edit) ─────────────────────────────
                  TextFormField(
                    controller: _usernameCtrl,
                    textDirection: TextDirection.ltr,
                    enabled: !_isEdit,
                    decoration: InputDecoration(
                      labelText: l.usersMgmtFieldUsername,
                      prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                      hintText: l.usersMgmtFieldUsernameHint,
                      helperText: _isEdit ? l.usersMgmtFieldUsernameHelper : null,
                      filled: _isEdit,
                      fillColor: _isEdit ? Colors.grey.shade100 : null,
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _usernameCtrl,
                        builder: (context, val, _) => val.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                tooltip: l.usersMgmtCopyFieldTooltip(l.usersMgmtFieldUsername),
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  val.text,
                                  customMessage: l.usersMgmtCopyBadgeSuccess(l.usersMgmtFieldUsername, val.text),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    validator: (v) {
                      if (_isEdit) return null;
                      if (v == null || v.trim().isEmpty) return l.usersMgmtFieldUsernameRequired;
                      if (v.trim().length < 3) return l.usersMgmtFieldUsernameMinLength;
                      if (v.contains(' ')) return l.usersMgmtFieldUsernameNoSpaces;
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Email ──────────────────────────────────────────────────
                  TextFormField(
                    controller: _emailCtrl,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.usersMgmtFieldEmail,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      hintText: l.usersMgmtFieldEmailHint,
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _emailCtrl,
                        builder: (context, val, _) => val.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                tooltip: l.usersMgmtCopyFieldTooltip(l.usersMgmtFieldEmail),
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  val.text,
                                  customMessage: l.usersMgmtCopyBadgeSuccess(l.usersMgmtFieldEmail, val.text),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l.usersMgmtFieldEmailRequired;
                      if (!v.contains('@') || !v.contains('.')) return l.usersMgmtFieldEmailInvalid;
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Role Dropdown ──────────────────────────────────────────
                  SearchableDropdownField<String>(
                    value: _selectedRole,
                    labelText: l.usersMgmtFieldRole,
                    decoration: InputDecoration(
                      labelText: l.usersMgmtFieldRole,
                      prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                    ),
                    items: [
                      SearchableDropdownItem<String>(
                        value: 'ADMIN',
                        label: l.usersMgmtRoleAdminOption,
                        icon: Icons.admin_panel_settings_rounded,
                      ),
                      SearchableDropdownItem<String>(
                        value: 'MANAGER',
                        label: l.usersMgmtRoleManagerOption,
                        icon: Icons.manage_accounts_rounded,
                      ),
                      SearchableDropdownItem<String>(
                        value: 'OPERATOR',
                        label: l.usersMgmtRoleOperatorOption,
                        icon: Icons.badge_rounded,
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedRole = v ?? 'OPERATOR'),
                    validator: (v) => v == null ? l.usersMgmtFieldRoleRequired : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Password ───────────────────────────────────────────────
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: _isEdit ? l.usersMgmtFieldPasswordNew : l.usersMgmtFieldPassword,
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
                      if (!_isEdit && (v == null || v.trim().isEmpty)) return l.usersMgmtFieldPasswordRequired;
                      if (v != null && v.isNotEmpty && v.length < 6) return l.usersMgmtFieldPasswordMinLength;
                      return null;
                    },
                  ),

                  // ── Role Description Card ──────────────────────────────────
                  const SizedBox(height: 16),
                  RoleDescriptionCard(role: _selectedRole),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text(l.usersMgmtBtnCancel),
          ),
          AppButton(
            label: _isEdit ? l.usersMgmtBtnSave : l.usersMgmtBtnCreate,
            variant: _isEdit ? AppButtonVariant.primary : AppButtonVariant.success,
            icon: _isEdit ? Icons.save_outlined : Icons.person_add_outlined,
            isLoading: _isSaving,
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }
}
