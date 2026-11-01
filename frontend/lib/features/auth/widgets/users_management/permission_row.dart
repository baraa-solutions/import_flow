import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/rbac_models.dart';

/// Legend chip describing permission status in the RBAC permissions matrix.
class PermLegendChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const PermLegendChip({
    super.key,
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
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// A single row representing a permission item with explicit grant / revoke controls.
class PermissionRow extends StatelessWidget {
  final PermissionModel perm;
  final bool roleHas;
  final bool? permOverride; // null = inherited, true = explicitly granted, false = explicitly revoked
  final bool effective;
  final bool isSaving;
  final VoidCallback onToggleGrant;
  final VoidCallback onToggleRevoke;

  const PermissionRow({
    super.key,
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
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final hasExplicitGrant = permOverride == true;
    final hasExplicitRevoke = permOverride == false;
    final isInherited = permOverride == null;

    // Effective state color
    final Color effectiveColor;
    if (hasExplicitRevoke) {
      effectiveColor = AppTheme.crimson;
    } else if (hasExplicitGrant) {
      effectiveColor = AppTheme.emerald;
    } else if (roleHas) {
      effectiveColor = AppTheme.cobalt.withValues(alpha: 0.7);
    } else {
      effectiveColor = Colors.grey.shade400;
    }

    final permName = isAr ? perm.nameAr : (perm.nameEn.isNotEmpty ? perm.nameEn : perm.nameAr);

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
                  permName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasExplicitGrant || hasExplicitRevoke ? FontWeight.bold : FontWeight.normal,
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
