import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/rbac_models.dart';
import 'permission_row.dart';

/// Expandable card component displaying a single module permission group.
class PermissionGroupCard extends StatelessWidget {
  final PermissionModuleGroup group;
  final RoleModel selectedRole;
  final Map<String, bool?> permOverrides;
  final bool isExpanded;
  final bool isSaving;
  final VoidCallback onToggleExpand;
  final void Function(String permCode) onToggleGrant;
  final void Function(String permCode) onToggleRevoke;

  const PermissionGroupCard({
    super.key,
    required this.group,
    required this.selectedRole,
    required this.permOverrides,
    required this.isExpanded,
    required this.isSaving,
    required this.onToggleExpand,
    required this.onToggleGrant,
    required this.onToggleRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final groupTitle = isAr
        ? (group.moduleNameAr.isNotEmpty ? group.moduleNameAr : group.moduleName)
        : group.moduleName;

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
            onTap: onToggleExpand,
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
                      groupTitle,
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
              final bool roleHas = selectedRole.permissions.contains(perm.permissionCode);
              final bool? override = permOverrides[perm.permissionCode];
              final bool effective = override ?? roleHas;

              return PermissionRow(
                perm: perm,
                roleHas: roleHas,
                permOverride: override,
                effective: effective,
                isSaving: isSaving,
                onToggleGrant: () => onToggleGrant(perm.permissionCode),
                onToggleRevoke: () => onToggleRevoke(perm.permissionCode),
              );
            }),
        ],
      ),
    );
  }
}
