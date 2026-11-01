import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Informational card illustrating role capabilities and access permissions.
class RoleDescriptionCard extends StatelessWidget {
  final String role;
  const RoleDescriptionCard({super.key, required this.role});

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
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
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
