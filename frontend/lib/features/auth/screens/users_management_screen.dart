import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/models/rbac_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/rbac_provider.dart';
import '../../auth/providers/users_provider.dart';
import '../services/users_management_export_service.dart';

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterRole = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(usersProvider).isLoading) {
        ref.read(usersProvider.notifier).fetchUsers();
      }
      if (!ref.read(rbacProvider).isLoading) {
        ref.read(rbacProvider.notifier).fetchRbacData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Role Helpers ──────────────────────────────────────────────────────────

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return AppTheme.crimson;
      case 'MANAGER':
        return AppTheme.cobalt;
      default:
        return AppTheme.emerald;
    }
  }


  IconData _roleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'MANAGER':
        return Icons.manage_accounts_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  // ─── Add / Edit Dialog ─────────────────────────────────────────────────────

  void _showUserDialog({UserDetail? editUser}) {
    final l = context.l10n;
    final isEdit = editUser != null;
    final formKey = GlobalKey<FormState>();

    final usernameCtrl = TextEditingController(text: editUser?.username ?? '');
    final emailCtrl = TextEditingController(text: editUser?.email ?? '');
    final fullNameCtrl = TextEditingController(text: editUser?.fullName ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = editUser?.role.toUpperCase() ?? 'OPERATOR';
    bool obscurePassword = true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
                  color: AppTheme.cobalt,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(isEdit ? l.usersMgmtDialogEditTitle : l.usersMgmtDialogNewTitle),
            ],
          ),
          content: SelectionArea(
            child: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Full Name ──────────────────────────────────────────────
                    TextFormField(
                      controller: fullNameCtrl,
                      decoration: InputDecoration(
                        labelText: l.usersMgmtFieldFullName,
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        hintText: l.usersMgmtFieldFullNameHint,
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: fullNameCtrl,
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
                      controller: usernameCtrl,
                      textDirection: TextDirection.ltr,
                      enabled: !isEdit,
                      decoration: InputDecoration(
                        labelText: l.usersMgmtFieldUsername,
                        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                        hintText: l.usersMgmtFieldUsernameHint,
                        helperText: isEdit ? l.usersMgmtFieldUsernameHelper : null,
                        filled: isEdit,
                        fillColor: isEdit ? Colors.grey.shade100 : null,
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: usernameCtrl,
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
                        if (isEdit) return null;
                        if (v == null || v.trim().isEmpty) return l.usersMgmtFieldUsernameRequired;
                        if (v.trim().length < 3) return l.usersMgmtFieldUsernameMinLength;
                        if (v.contains(' ')) return l.usersMgmtFieldUsernameNoSpaces;
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Email ──────────────────────────────────────────────────
                    TextFormField(
                      controller: emailCtrl,
                      textDirection: TextDirection.ltr,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l.usersMgmtFieldEmail,
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        hintText: l.usersMgmtFieldEmailHint,
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: emailCtrl,
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
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: InputDecoration(
                        labelText: l.usersMgmtFieldRole,
                        prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'ADMIN',
                          child: Row(children: [
                            const Icon(Icons.admin_panel_settings_rounded, size: 16, color: AppTheme.crimson),
                            const SizedBox(width: 8),
                            Text(l.usersMgmtRoleAdminOption),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'MANAGER',
                          child: Row(children: [
                            const Icon(Icons.manage_accounts_rounded, size: 16, color: AppTheme.cobalt),
                            const SizedBox(width: 8),
                            Text(l.usersMgmtRoleManagerOption),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'OPERATOR',
                          child: Row(children: [
                            const Icon(Icons.badge_rounded, size: 16, color: AppTheme.emerald),
                            const SizedBox(width: 8),
                            Text(l.usersMgmtRoleOperatorOption),
                          ]),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => selectedRole = v ?? 'OPERATOR'),
                      validator: (v) => v == null ? l.usersMgmtFieldRoleRequired : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Password ───────────────────────────────────────────────
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: isEdit ? l.usersMgmtFieldPasswordNew : l.usersMgmtFieldPassword,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                          ),
                          onPressed: () => setLocal(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (!isEdit && (v == null || v.trim().isEmpty)) return l.usersMgmtFieldPasswordRequired;
                        if (v != null && v.isNotEmpty && v.length < 6) return l.usersMgmtFieldPasswordMinLength;
                        return null;
                      },
                    ),

                    // ── Role Description Card ──────────────────────────────────
                    const SizedBox(height: 16),
                    _RoleDescriptionCard(role: selectedRole),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text(l.usersMgmtBtnCancel),
            ),
            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() => isSaving = true);

                      // Capture messenger before async gap
                      final messenger = ScaffoldMessenger.of(context);

                      String? error;
                      if (isEdit) {
                        error = await ref.read(usersProvider.notifier).updateUser(
                              userId: editUser.userId,
                              fullName: fullNameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              role: selectedRole,
                              password: passwordCtrl.text.isEmpty ? null : passwordCtrl.text,
                            );
                      } else {
                        error = await ref.read(usersProvider.notifier).createUser(
                                username: usernameCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                fullName: fullNameCtrl.text.trim(),
                                role: selectedRole,
                                password: passwordCtrl.text,
                              );
                      }

                      setLocal(() => isSaving = false);

                      if (!ctx.mounted) return;
                      if (error != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          AppTheme.snackBar(ctx, error, severity: AppSeverity.danger),
                        );
                      } else {
                        Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            AppTheme.snackBar(
                              context,
                              isEdit ? l.usersMgmtSuccessUpdated : l.usersMgmtSuccessCreated,
                              severity: AppSeverity.success,
                            ),
                          );
                        }
                      }
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: AppLoadingState.inline(),
                    )
                  : Icon(isEdit ? Icons.save_outlined : Icons.person_add_outlined, size: 18),
              label: Text(isEdit ? l.usersMgmtBtnSave : l.usersMgmtBtnCreate),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEdit ? AppTheme.cobalt : AppTheme.emerald,
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      usernameCtrl.dispose();
      emailCtrl.dispose();
      fullNameCtrl.dispose();
      passwordCtrl.dispose();
    });
  }

  // ─── Toggle Status Confirm Dialog ──────────────────────────────────────────

  Future<void> _showToggleConfirmDialog(UserDetail user) async {
    final l = context.l10n;
    final isActivating = !user.isActive;
    final confirmed = await AppConfirmDialog.showToggleActive(
      context,
      isCurrentlyActive: user.isActive,
      entityName: '${user.fullName} (@${user.username})',
      confirmLabel: isActivating ? l.usersMgmtBtnActivate : l.usersMgmtBtnDeactivate,
      cancelLabel: l.usersMgmtBtnCancel,
    );
    if (!confirmed || !mounted) return;
    final error = await ref.read(usersProvider.notifier).toggleUserStatus(user.userId);
    if (!mounted) return;
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

  // ─── User Permissions Dialog ────────────────────────────────────────────────

  Future<void> _showUserPermissionsDialog(UserDetail user) async {
    final l = context.l10n;
    final rbacState = ref.read(rbacProvider);

    // Ensure roles and permissions are loaded.
    if (rbacState.roles.isEmpty || rbacState.permissionGroups.isEmpty) {
      await ref.read(rbacProvider.notifier).fetchRbacData();
    }

    if (!mounted) return;

    // Show a loading dialog while fetching user's current permissions.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AppLoadingState(),
    );

    final userPerms = await ref.read(rbacProvider.notifier).fetchUserPermissions(user.userId);

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading indicator

    if (userPerms == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.usersMgmtPermLoadError, severity: AppSeverity.danger),
      );
      return;
    }

    // Build local mutable permission state.
    final currentRbac = ref.read(rbacProvider);
    int? selectedRoleId = userPerms.roleId;

    // Map: permission_code → is_granted (null = inherited from role, no override)
    final Map<String, bool?> permOverrides = {};
    for (final code in userPerms.customGrants) {
      permOverrides[code] = true;
    }
    for (final code in userPerms.customRevocations) {
      permOverrides[code] = false;
    }

    // Dialog expansion state per module.
    final Map<String, bool> expandedModules = {
      for (final g in currentRbac.permissionGroups) g.moduleName: true,
    };

    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          // Get the currently selected role's base permissions.
          final selectedRole = currentRbac.roles.firstWhere(
            (r) => r.roleId == selectedRoleId,
            orElse: () => const RoleModel(
              roleId: -1,
              roleCode: '',
              nameEn: 'No Role',
              nameAr: 'بدون دور',
              isSystemRole: false,
              isActive: true,
              permissions: [],
            ),
          );

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: SelectionArea(
              child: SizedBox(
                width: 820,
                height: MediaQuery.of(ctx).size.height * 0.88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.charcoal,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.security_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.usersMgmtPermDialogTitle,
                                  style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '@${user.username} — ${user.fullName}',
                                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => CopyHelper.copy(
                                        ctx,
                                        '${user.username} (${user.fullName})',
                                        customMessage: l.usersMgmtCopyBadgeSuccess(l.usersMgmtColUsername, user.username),
                                      ),
                                      child: Icon(Icons.copy_rounded, size: 13, color: Colors.white.withValues(alpha: 0.7)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                  // ── Role Selector ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_rounded, size: 18, color: AppTheme.cobalt),
                        const SizedBox(width: 10),
                        Text(
                          l.usersMgmtPermRoleLabel,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: selectedRoleId,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(l.usersMgmtPermNoRole,
                                    style: const TextStyle(color: Colors.grey)),
                              ),
                              ...currentRbac.roles
                                  .where((r) => r.isActive)
                                  .map((r) => DropdownMenuItem<int?>(
                                        value: r.roleId,
                                        child: Text('${r.nameAr} (${r.roleCode})'),
                                      )),
                            ],
                            onChanged: isSaving
                                ? null
                                : (val) => setLocal(() => selectedRoleId = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Permissions count chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            l.usersMgmtPermRolePermCount(selectedRole.permissions.length),
                            style: const TextStyle(fontSize: 11, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Legend ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 4),
                    child: Wrap(
                      spacing: 16,
                      children: [
                        _PermLegendChip(
                          color: AppTheme.emerald,
                          icon: Icons.check_circle,
                          label: l.usersMgmtPermLegendGranted,
                        ),
                        _PermLegendChip(
                          color: AppTheme.crimson,
                          icon: Icons.remove_circle,
                          label: l.usersMgmtPermLegendRevoked,
                        ),
                        _PermLegendChip(
                          color: Colors.grey,
                          icon: Icons.circle_outlined,
                          label: l.usersMgmtPermLegendInherited,
                        ),
                      ],
                    ),
                  ),

                  // ── Permission Groups ─────────────────────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                      children: currentRbac.permissionGroups.map((group) {
                        final isExpanded = expandedModules[group.moduleName] ?? true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              // Module header
                              InkWell(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                onTap: () => setLocal(
                                  () => expandedModules[group.moduleName] = !isExpanded,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.folder_outlined,
                                        size: 15,
                                        color: AppTheme.cobalt.withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${group.moduleNameAr} (${group.moduleName})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.charcoal,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${group.permissions.length}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isExpanded ? Icons.expand_less : Icons.expand_more,
                                        size: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Permission rows
                              if (isExpanded)
                                ...group.permissions.map((perm) {
                                  final bool roleHas =
                                      selectedRole.permissions.contains(perm.permissionCode);
                                  final bool? override = permOverrides[perm.permissionCode];
                                  final bool effective = override ?? roleHas;

                                  return _PermissionRow(
                                    perm: perm,
                                    roleHas: roleHas,
                                    permOverride: override,
                                    effective: effective,
                                    isSaving: isSaving,
                                    onToggleGrant: () => setLocal(() {
                                      if (override == true) {
                                        // Was explicitly granted → remove override (revert to role)
                                        permOverrides.remove(perm.permissionCode);
                                      } else {
                                        // Add explicit grant
                                        permOverrides[perm.permissionCode] = true;
                                      }
                                    }),
                                    onToggleRevoke: () => setLocal(() {
                                      if (override == false) {
                                        // Was explicitly revoked → remove override (revert to role)
                                        permOverrides.remove(perm.permissionCode);
                                      } else {
                                        // Add explicit revocation
                                        permOverrides[perm.permissionCode] = false;
                                      }
                                    }),
                                  );
                                }),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── Footer Actions ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        // Override summary
                        Text(
                          l.usersMgmtPermOverrideSummary(
                            permOverrides.values.where((v) => v == true).length,
                            permOverrides.values.where((v) => v == false).length,
                          ),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          child: Text(l.usersMgmtBtnCancel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setLocal(() => isSaving = true);

                                  final permList = permOverrides.entries
                                      .map((e) => {
                                            'permission_code': e.key,
                                            'is_granted': e.value,
                                          })
                                      .toList();

                                  final messenger = ScaffoldMessenger.of(context);
                                  final error = await ref
                                      .read(rbacProvider.notifier)
                                      .updateUserPermissions(
                                        userId: user.userId,
                                        roleId: selectedRoleId,
                                        permissions: permList,
                                      );

                                  setLocal(() => isSaving = false);

                                  if (!ctx.mounted) return;
                                  if (error != null) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      AppTheme.snackBar(ctx, error, severity: AppSeverity.danger),
                                    );
                                  } else {
                                    Navigator.pop(ctx);
                                    if (mounted) {
                                      // Refresh user list to reflect role_id change
                                      ref.read(usersProvider.notifier).fetchUsers();
                                      messenger.showSnackBar(
                                        AppTheme.snackBar(
                                          context,
                                          l.usersMgmtPermSavedSuccess,
                                          severity: AppSeverity.success,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: AppLoadingState.inline(),
                                )
                              : const Icon(Icons.save_rounded, size: 16),
                          label: Text(l.usersMgmtPermSaveBtn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final currentUser = ref.watch(authProvider).user;
    final isAdmin = currentUser?.isAdmin ?? false;

    // Filter users
    final filtered = usersState.users.where((u) {
      final matchRole = _filterRole == 'ALL' || u.role.toUpperCase() == _filterRole;
      final matchSearch = _searchQuery.isEmpty ||
          u.fullName.toLowerCase().contains(_searchQuery) ||
          u.username.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery);
      return matchRole && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _buildHeader(isAdmin, usersState),

            // ── Export Toolbar ──────────────────────────────────────────────
            _buildExportToolbar(filtered),

            // ── Filters & Stats Row ──────────────────────────────────────────
            _buildFiltersRow(usersState),

            // ── Table Area ──────────────────────────────────────────────────
            Expanded(
              child: usersState.isLoading
                  ? const AppLoadingState()
                  : usersState.error != null
                      ? _buildErrorState(usersState.error!)
                      : filtered.isEmpty
                          ? _buildEmptyState()
                          : _buildUsersTable(filtered, isAdmin, currentUser?.userId ?? -1),
            ),
          ],
        ),
      ),
    );
  }

  // ── Export Toolbar ────────────────────────────────────────────────────────

  Widget _buildExportToolbar(List<UserDetail> filtered) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // TSV Export
          OutlinedButton.icon(
            onPressed: filtered.isEmpty
                ? null
                : () async {
                    await UsersManagementExportService.saveUsersTsvToFile(context, filtered);
                  },
            icon: const Icon(Icons.file_download_outlined, size: 15),
            label: Text(l.usersMgmtExportTsvBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.charcoal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // Excel / CSV Export
          OutlinedButton.icon(
            onPressed: filtered.isEmpty
                ? null
                : () async {
                    await UsersManagementExportService.saveUsersCsvToFile(context, filtered);
                  },
            icon: const Icon(Icons.table_chart_outlined, size: 15),
            label: Text(l.usersMgmtExportExcelBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.emerald,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // PDF Print / Save
          OutlinedButton.icon(
            onPressed: filtered.isEmpty
                ? null
                : () async {
                    await UsersManagementExportService.printOrSaveUsersPdf(context, filtered);
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
            label: Text(l.usersMgmtPrintPdfBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.crimson,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // Dossier Copy
          OutlinedButton.icon(
            onPressed: filtered.isEmpty
                ? null
                : () {
                    UsersManagementExportService.copyDossierToClipboard(context, filtered);
                  },
            icon: const Icon(Icons.content_copy_outlined, size: 15),
            label: Text(l.usersMgmtCopyDossierBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cobalt,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isAdmin, UsersState state) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.manage_accounts_rounded, color: AppTheme.cobalt, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.usersMgmtTitle,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
              ),
              Text(
                l.usersMgmtSubtitle(state.users.length),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
              ),
            ],
          ),
          const Spacer(),
          // Refresh
          IconButton(
            onPressed: () => ref.read(usersProvider.notifier).fetchUsers(),
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.cobalt),
            tooltip: l.usersMgmtRefreshTooltip,
          ),
          const SizedBox(width: 8),
          // Add User (ADMIN only)
          if (isAdmin)
            ElevatedButton.icon(
              onPressed: () => _showUserDialog(),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: Text(l.usersMgmtNewUserBtn),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 14, color: AppTheme.orange),
                  const SizedBox(width: 6),
                  Text(
                    l.usersMgmtReadOnlyNotice,
                    style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Stats & Filters ──────────────────────────────────────────────────────

  Widget _buildFiltersRow(UsersState state) {
    final l = context.l10n;
    final admins = state.users.where((u) => u.role.toUpperCase() == 'ADMIN').length;
    final managers = state.users.where((u) => u.role.toUpperCase() == 'MANAGER').length;
    final operators = state.users.where((u) => u.role.toUpperCase() == 'OPERATOR').length;
    final active = state.users.where((u) => u.isActive).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Column(
        children: [
          // Stats chips
          Row(
            children: [
              _StatChip(label: l.usersMgmtStatAll, count: state.users.length, color: AppTheme.charcoal),
              const SizedBox(width: 8),
              _StatChip(label: l.usersMgmtStatActive, count: active, color: AppTheme.emerald, icon: Icons.check_circle_outline),
              const SizedBox(width: 8),
              _StatChip(label: l.usersMgmtStatAdmin, count: admins, color: AppTheme.crimson),
              const SizedBox(width: 8),
              _StatChip(label: l.usersMgmtStatManager, count: managers, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              _StatChip(label: l.usersMgmtStatOperator, count: operators, color: AppTheme.emerald),
              const Spacer(),
              // Search
              SizedBox(
                width: 280,
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: l.usersMgmtSearchHint,
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: l.usersMgmtSearchCopied,
                              onPressed: () => CopyHelper.copy(
                                context,
                                value.text,
                                customMessage: l.usersMgmtSearchCopied,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Role filter tabs
          Row(
            children: [
              _FilterTab(label: l.usersMgmtStatAll, value: 'ALL', selected: _filterRole == 'ALL',
                  onTap: () => setState(() => _filterRole = 'ALL')),
              const SizedBox(width: 6),
              _FilterTab(label: l.usersMgmtRoleAdminLabel, value: 'ADMIN', selected: _filterRole == 'ADMIN',
                  color: AppTheme.crimson, onTap: () => setState(() => _filterRole = 'ADMIN')),
              const SizedBox(width: 6),
              _FilterTab(label: l.usersMgmtRoleManagerLabel, value: 'MANAGER', selected: _filterRole == 'MANAGER',
                  color: AppTheme.cobalt, onTap: () => setState(() => _filterRole = 'MANAGER')),
              const SizedBox(width: 6),
              _FilterTab(label: l.usersMgmtRoleOperatorLabel, value: 'OPERATOR', selected: _filterRole == 'OPERATOR',
                  color: AppTheme.emerald, onTap: () => setState(() => _filterRole = 'OPERATOR')),
            ],
          ),
        ],
      ),
    );
  }

  // ── Users Table ──────────────────────────────────────────────────────────

  Widget _buildUsersTable(List<UserDetail> users, bool isAdmin, int currentUserId) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Row(
              children: [
                SizedBox(width: 160, child: _TableHeader(l.usersMgmtColActions)),
                const SizedBox(width: 40),
                Expanded(flex: 3, child: _TableHeader(l.usersMgmtColFullName)),
                Expanded(flex: 2, child: _TableHeader(l.usersMgmtColUsername)),
                Expanded(flex: 3, child: _TableHeader(l.usersMgmtColEmail)),
                Expanded(flex: 2, child: _TableHeader(l.usersMgmtColRole)),
                SizedBox(width: 95, child: _TableHeader(l.usersMgmtColStatus)),
                SizedBox(width: 110, child: _TableHeader(l.usersMgmtColCreatedAt)),
              ],
            ),
          ),
          // Rows
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, i) => _buildUserRow(users[i], isAdmin, currentUserId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserDetail user, bool isAdmin, int currentUserId) {
    final l = context.l10n;
    final isSelf = user.userId == currentUserId;
    final createdDate = _formatDate(user.createdAt);
    final rowSummary = UsersManagementExportService.toRowSummary(user, l);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: !user.isActive ? Colors.grey.shade50 : null,
      child: Row(
        children: [
          // Actions
          SizedBox(
            width: 160,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAdmin) ...[
                  // Edit
                  Tooltip(
                    message: l.usersMgmtActionEditTooltip,
                    child: InkWell(
                      onTap: () => _showUserDialog(editUser: user),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.cobalt),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Manage Permissions
                  Tooltip(
                    message: l.usersMgmtActionPermissionsTooltip,
                    child: InkWell(
                      onTap: () => _showUserPermissionsDialog(user),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.security_rounded,
                          size: 16,
                          color: AppTheme.orange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Toggle Status (can't deactivate self)
                  if (!isSelf)
                    Tooltip(
                      message: user.isActive ? l.usersMgmtActionDeactivateTooltip : l.usersMgmtActionActivateTooltip,
                      child: InkWell(
                        onTap: () => _showToggleConfirmDialog(user),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            user.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                            size: 16,
                            color: user.isActive ? AppTheme.crimson : AppTheme.emerald,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 28),
                  const SizedBox(width: 4),
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
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
            child: Icon(_roleIcon(user.role), color: _roleColor(user.role), size: 16),
          ),
          const SizedBox(width: 8),
          // Full Name
          Expanded(
            flex: 3,
            child: CopyableTableCell(
              value: user.fullName,
              rowSummary: rowSummary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: user.isActive ? AppTheme.charcoal : Colors.grey,
                    ),
                  ),
                  if (isSelf)
                    Text(
                      l.usersMgmtSelfBadge,
                      style: const TextStyle(fontSize: 10, color: AppTheme.cobalt, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
          // Username
          Expanded(
            flex: 2,
            child: CopyableTableCell(
              value: user.username,
              rowSummary: rowSummary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '@${user.username}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: user.isActive ? Colors.grey.shade700 : Colors.grey.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => CopyHelper.copy(
                      context,
                      user.username,
                      customMessage: l.usersMgmtCopyBadgeSuccess(l.usersMgmtColUsername, user.username),
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.copy_rounded, size: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Email
          Expanded(
            flex: 3,
            child: CopyableTableCell(
              value: user.email,
              rowSummary: rowSummary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: user.isActive ? Colors.grey.shade700 : Colors.grey.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => CopyHelper.copy(
                      context,
                      user.email,
                      customMessage: l.usersMgmtCopyBadgeSuccess(l.usersMgmtColEmail, user.email),
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.copy_rounded, size: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Role Badge
          Expanded(
            flex: 2,
            child: CopyableTableCell(
              value: user.role,
              rowSummary: rowSummary,
              child: _RoleBadge(role: user.role),
            ),
          ),
          // Status
          SizedBox(
            width: 95,
            child: CopyableTableCell(
              value: user.isActive ? l.usersMgmtStatusActive : l.usersMgmtStatusInactive,
              rowSummary: rowSummary,
              child: AppStatusBadge(
                label: user.isActive ? l.usersMgmtStatusActive : l.usersMgmtStatusInactive,
                severity: user.isActive ? AppSeverity.success : AppSeverity.info,
                size: AppStatusBadgeSize.small,
              ),
            ),
          ),
          // Created At
          SizedBox(
            width: 110,
            child: CopyableTableCell(
              value: createdDate,
              rowSummary: rowSummary,
              child: Text(
                createdDate,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ── Empty / Error States ──────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final l = context.l10n;
    return AppEmptyState(
      icon: Icons.group_outlined,
      message: l.usersMgmtNoResults,
      subtitle: l.usersMgmtNoResultsHint,
    );
  }

  Widget _buildErrorState(String error) {
    return AppErrorState(
      message: error,
      onRetry: () => ref.read(usersProvider.notifier).fetchUsers(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '—';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate.substring(0, 10);
    }
  }
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.charcoal,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  IconData get _icon {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'MANAGER':
        return Icons.manage_accounts_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  String _label(BuildContext context) {
    final l = context.l10n;
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return l.usersMgmtRoleAdminLabel;
      case 'MANAGER':
        return l.usersMgmtRoleManagerLabel;
      default:
        return l.usersMgmtRoleOperatorLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = switch (role.toUpperCase()) {
      'ADMIN' => AppSeverity.danger,
      'MANAGER' => AppSeverity.info,
      _ => AppSeverity.success,
    };
    return AppStatusBadge(
      label: _label(context),
      severity: severity,
      size: AppStatusBadgeSize.small,
      icon: _icon,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData? icon;

  const _StatChip({required this.label, required this.count, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.charcoal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? activeColor.withValues(alpha: 0.5) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? activeColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _RoleDescriptionCard extends StatelessWidget {
  final String role;
  const _RoleDescriptionCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final info = _getRoleInfo(context, role);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: info.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.icon, size: 14, color: info.color),
              const SizedBox(width: 6),
              Text(
                info.title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: info.color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...info.permissions.map(
            (p) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 11, color: info.color),
                  const SizedBox(width: 5),
                  Text(p, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _RoleInfo _getRoleInfo(BuildContext context, String role) {
    final l = context.l10n;
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return _RoleInfo(
          title: l.usersMgmtRoleAdminDescTitle,
          icon: Icons.admin_panel_settings_rounded,
          color: AppTheme.crimson,
          permissions: [
            l.usersMgmtRoleAdminPerm1,
            l.usersMgmtRoleAdminPerm2,
            l.usersMgmtRoleAdminPerm3,
            l.usersMgmtRoleAdminPerm4,
            l.usersMgmtRoleAdminPerm5,
          ],
        );
      case 'MANAGER':
        return _RoleInfo(
          title: l.usersMgmtRoleManagerDescTitle,
          icon: Icons.manage_accounts_rounded,
          color: AppTheme.cobalt,
          permissions: [
            l.usersMgmtRoleManagerPerm1,
            l.usersMgmtRoleManagerPerm2,
            l.usersMgmtRoleManagerPerm3,
            l.usersMgmtRoleManagerPerm4,
            l.usersMgmtRoleManagerPerm5,
          ],
        );
      default:
        return _RoleInfo(
          title: l.usersMgmtRoleOperatorDescTitle,
          icon: Icons.badge_rounded,
          color: AppTheme.emerald,
          permissions: [
            l.usersMgmtRoleOperatorPerm1,
            l.usersMgmtRoleOperatorPerm2,
            l.usersMgmtRoleOperatorPerm3,
            l.usersMgmtRoleOperatorPerm4,
            l.usersMgmtRoleOperatorPerm5,
          ],
        );
    }
  }
}

class _RoleInfo {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> permissions;

  const _RoleInfo({
    required this.title,
    required this.icon,
    required this.color,
    required this.permissions,
  });
}

// ─── Permission Legend Chip ────────────────────────────────────────────────────

class _PermLegendChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _PermLegendChip({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Permission Row ────────────────────────────────────────────────────────────

class _PermissionRow extends StatelessWidget {
  final PermissionModel perm;
  final bool roleHas;
  final bool? permOverride; // null = inherited, true = explicitly granted, false = explicitly revoked
  final bool effective;
  final bool isSaving;
  final VoidCallback onToggleGrant;
  final VoidCallback onToggleRevoke;

  const _PermissionRow({
    required this.perm,
    required this.roleHas,
    required this.permOverride,
    required this.effective,
    required this.isSaving,
    required this.onToggleGrant,
    required this.onToggleRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasExplicitGrant = permOverride == true;
    final hasExplicitRevoke = permOverride == false;
    final isInherited = permOverride == null;

    // Effective state color
    Color effectiveColor;
    if (hasExplicitRevoke) {
      effectiveColor = AppTheme.crimson;
    } else if (hasExplicitGrant) {
      effectiveColor = AppTheme.emerald;
    } else if (roleHas) {
      effectiveColor = AppTheme.cobalt.withValues(alpha: 0.7);
    } else {
      effectiveColor = Colors.grey.shade400;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: hasExplicitGrant
            ? AppTheme.emerald.withValues(alpha: 0.04)
            : hasExplicitRevoke
                ? AppTheme.crimson.withValues(alpha: 0.04)
                : null,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          // Effective status dot
          Icon(
            effective ? Icons.circle : Icons.circle_outlined,
            size: 8,
            color: effectiveColor,
          ),
          const SizedBox(width: 10),
          // Permission info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perm.nameAr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasExplicitGrant || hasExplicitRevoke
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: hasExplicitRevoke ? Colors.grey.shade500 : AppTheme.charcoal,
                    decoration: hasExplicitRevoke ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  perm.permissionCode,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Override badges
          if (!isInherited)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: hasExplicitGrant
                    ? AppTheme.emerald.withValues(alpha: 0.12)
                    : AppTheme.crimson.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasExplicitGrant ? l.usersMgmtPermBadgeGrant : l.usersMgmtPermBadgeRevoke,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: hasExplicitGrant ? AppTheme.emerald : AppTheme.crimson,
                ),
              ),
            ),
          // Role-inherited indicator
          if (isInherited && roleHas)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l.usersMgmtPermBadgeRole,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.cobalt.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          // Grant button
          Tooltip(
            message: hasExplicitGrant ? l.usersMgmtPermTooltipRevertGrant : l.usersMgmtPermTooltipGrant,
            child: InkWell(
              onTap: isSaving ? null : onToggleGrant,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: hasExplicitGrant ? AppTheme.emerald : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Revoke button
          Tooltip(
            message: hasExplicitRevoke ? l.usersMgmtPermTooltipRevertRevoke : l.usersMgmtPermTooltipRevoke,
            child: InkWell(
              onTap: isSaving ? null : onToggleRevoke,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 16,
                  color: hasExplicitRevoke ? AppTheme.crimson : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
