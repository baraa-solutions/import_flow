import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/users_provider.dart';
import '../../services/users_management_export_service.dart';
import 'user_management_actions.dart';

/// Data table display for Screen 66: Users Management.
class UsersManagementTable extends StatelessWidget {
  final List<UserDetail> users;
  final bool isAdmin;
  final int currentUserId;

  const UsersManagementTable({
    super.key,
    required this.users,
    required this.isAdmin,
    required this.currentUserId,
  });

  static Color roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return AppTheme.crimson;
      case 'MANAGER':
        return AppTheme.cobalt;
      default:
        return AppTheme.emerald;
    }
  }

  static IconData roleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'MANAGER':
        return Icons.manage_accounts_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  static String formatDate(String? isoDate) {
    if (isoDate == null) return '—';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Table Header Row ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Row(
              children: [
                SizedBox(width: 170, child: _TableHeader(l.usersMgmtColActions)),
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

          // ── Table Body ─────────────────────────────────────────────────
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
              itemBuilder: (context, i) => _UserRow(
                user: users[i],
                isAdmin: isAdmin,
                currentUserId: currentUserId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserDetail user;
  final bool isAdmin;
  final int currentUserId;

  const _UserRow({
    required this.user,
    required this.isAdmin,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isSelf = user.userId == currentUserId;
    final createdDate = UsersManagementTable.formatDate(user.createdAt);
    final rowSummary = UsersManagementExportService.toRowSummary(user, l);
    final rColor = UsersManagementTable.roleColor(user.role);
    final rIcon = UsersManagementTable.roleIcon(user.role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: !user.isActive ? Colors.grey.shade50 : null,
      child: Row(
        children: [
          // Actions
          UserRowActions(
            user: user,
            isAdmin: isAdmin,
            isSelf: isSelf,
            rowSummary: rowSummary,
          ),

          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: rColor.withValues(alpha: 0.15),
            child: Icon(rIcon, color: rColor, size: 16),
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
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.cobalt,
                        fontWeight: FontWeight.bold,
                      ),
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
              child: RoleBadge(role: user.role),
            ),
          ),

          // Status Badge
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
}

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

/// Status badge for rendering user roles.
class RoleBadge extends StatelessWidget {
  final String role;
  const RoleBadge({super.key, required this.role});

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
      icon: UsersManagementTable.roleIcon(role),
    );
  }
}
