import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/rbac_models.dart';
import '../../providers/rbac_provider.dart';
import '../../providers/users_provider.dart';
import 'permission_group_card.dart';
import 'permission_row.dart';

/// Comprehensive modal dialog for managing an individual user's RBAC role and custom permissions.
class UserPermissionsDialog extends ConsumerStatefulWidget {
  final UserDetail user;
  final UserEffectivePermissions initialPerms;

  const UserPermissionsDialog({
    super.key,
    required this.user,
    required this.initialPerms,
  });

  /// Opens the permissions dialog after ensuring RBAC data & user permissions are loaded.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required UserDetail user,
  }) async {
    final l = context.l10n;
    final rbacNotifier = ref.read(rbacProvider.notifier);
    final rbacState = ref.read(rbacProvider);

    // Ensure roles and permissions are loaded.
    if (rbacState.roles.isEmpty || rbacState.permissionGroups.isEmpty) {
      await rbacNotifier.fetchRbacData();
    }

    if (!context.mounted) return;

    // Show loading dialog while fetching user's current permissions.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AppLoadingState(),
    );

    final userPerms = await rbacNotifier.fetchUserPermissions(user.userId);

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Dismiss loading

    if (userPerms == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l.usersMgmtPermLoadError, severity: AppSeverity.danger),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UserPermissionsDialog(
        user: user,
        initialPerms: userPerms,
      ),
    );
  }

  @override
  ConsumerState<UserPermissionsDialog> createState() => _UserPermissionsDialogState();
}

class _UserPermissionsDialogState extends ConsumerState<UserPermissionsDialog> {
  int? _selectedRoleId;
  late final Map<String, bool?> _permOverrides;
  late final Map<String, bool> _expandedModules;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedRoleId = widget.initialPerms.roleId;

    _permOverrides = {};
    for (final code in widget.initialPerms.customGrants) {
      _permOverrides[code] = true;
    }
    for (final code in widget.initialPerms.customRevocations) {
      _permOverrides[code] = false;
    }

    final currentRbac = ref.read(rbacProvider);
    _expandedModules = {
      for (final g in currentRbac.permissionGroups) g.moduleName: true,
    };
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final permList = _permOverrides.entries
        .map((e) => {
              'permission_code': e.key,
              'is_granted': e.value,
            })
        .toList();

    final error = await ref.read(rbacProvider.notifier).updateUserPermissions(
          userId: widget.user.userId,
          roleId: _selectedRoleId,
          permissions: permList,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, error, severity: AppSeverity.danger),
      );
    } else {
      Navigator.of(context).pop();
      // Refresh user list to reflect role_id changes
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final currentRbac = ref.watch(rbacProvider);

    final selectedRole = currentRbac.roles.firstWhere(
      (r) => r.roleId == _selectedRoleId,
      orElse: () => RoleModel(
        roleId: -1,
        roleCode: '',
        nameEn: 'No Role',
        nameAr: isAr ? 'بدون دور' : 'No Role',
        isSystemRole: false,
        isActive: true,
        permissions: const [],
      ),
    );

    return SelectionArea(
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: SizedBox(
          width: 820,
          height: MediaQuery.of(context).size.height * 0.88,
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
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '@${widget.user.username} — ${widget.user.fullName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => CopyHelper.copy(
                                  context,
                                  '${widget.user.username} (${widget.user.fullName})',
                                  customMessage: l.usersMgmtCopyBadgeSuccess(
                                    l.usersMgmtColUsername,
                                    widget.user.username,
                                  ),
                                ),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
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
                      child: SearchableDropdownField<int?>(
                        value: _selectedRoleId,
                        labelText: l.usersMgmtPermRoleLabel,
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
                          SearchableDropdownItem<int?>(
                            value: null,
                            label: l.usersMgmtPermNoRole,
                          ),
                          ...currentRbac.roles.where((r) => r.isActive).map(
                                (r) => SearchableDropdownItem<int?>(
                                  value: r.roleId,
                                  label: isAr ? r.nameAr : r.nameEn,
                                  searchValue: '${r.nameAr} ${r.nameEn} ${r.roleCode}',
                                ),
                              ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (val) => setState(() => _selectedRoleId = val),
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.cobalt,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Legend ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 4),
                child: Wrap(
                  spacing: 16,
                  children: [
                    PermLegendChip(
                      color: AppTheme.emerald,
                      icon: Icons.check_circle,
                      label: l.usersMgmtPermLegendGranted,
                    ),
                    PermLegendChip(
                      color: AppTheme.crimson,
                      icon: Icons.remove_circle,
                      label: l.usersMgmtPermLegendRevoked,
                    ),
                    PermLegendChip(
                      color: Colors.grey,
                      icon: Icons.circle_outlined,
                      label: l.usersMgmtPermLegendInherited,
                    ),
                  ],
                ),
              ),

              // ── Permission Groups ───────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                  children: currentRbac.permissionGroups.map((group) {
                    final isExpanded = _expandedModules[group.moduleName] ?? true;

                    return PermissionGroupCard(
                      group: group,
                      selectedRole: selectedRole,
                      permOverrides: _permOverrides,
                      isExpanded: isExpanded,
                      isSaving: _isSaving,
                      onToggleExpand: () => setState(
                        () => _expandedModules[group.moduleName] = !isExpanded,
                      ),
                      onToggleGrant: (permCode) => setState(() {
                        if (_permOverrides[permCode] == true) {
                          _permOverrides.remove(permCode);
                        } else {
                          _permOverrides[permCode] = true;
                        }
                      }),
                      onToggleRevoke: (permCode) => setState(() {
                        if (_permOverrides[permCode] == false) {
                          _permOverrides.remove(permCode);
                        } else {
                          _permOverrides[permCode] = false;
                        }
                      }),
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
                        _permOverrides.values.where((v) => v == true).length,
                        _permOverrides.values.where((v) => v == false).length,
                      ),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text(l.usersMgmtBtnCancel),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: l.usersMgmtPermSaveBtn,
                      variant: AppButtonVariant.primary,
                      icon: Icons.save_rounded,
                      isLoading: _isSaving,
                      onPressed: _handleSave,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
