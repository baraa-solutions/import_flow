import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/users_provider.dart';

/// Filter, stats, and search bar for Screen 66: Users Management.
class UsersManagementFilterBar extends StatelessWidget {
  final UsersState state;
  final TextEditingController searchController;
  final String filterRole;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleChanged;

  const UsersManagementFilterBar({
    super.key,
    required this.state,
    required this.searchController,
    required this.filterRole,
    required this.onSearchChanged,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          // ── Stats chips & Search row ─────────────────────────────────────
          Row(
            children: [
              StatChip(
                label: l.usersMgmtStatAll,
                count: state.users.length,
                color: AppTheme.charcoal,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: l.usersMgmtStatActive,
                count: active,
                color: AppTheme.emerald,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: l.usersMgmtStatAdmin,
                count: admins,
                color: AppTheme.crimson,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: l.usersMgmtStatManager,
                count: managers,
                color: AppTheme.cobalt,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: l.usersMgmtStatOperator,
                count: operators,
                color: AppTheme.emerald,
              ),
              const Spacer(),
              // Search Field
              SizedBox(
                width: 280,
                height: 36,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: l.usersMgmtSearchHint,
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
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
                                searchController.clear();
                                onSearchChanged('');
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

          // ── Role Filter Tabs ─────────────────────────────────────────────
          Row(
            children: [
              FilterTab(
                label: l.usersMgmtStatAll,
                value: 'ALL',
                selected: filterRole == 'ALL',
                onTap: () => onRoleChanged('ALL'),
              ),
              const SizedBox(width: 6),
              FilterTab(
                label: l.usersMgmtRoleAdminLabel,
                value: 'ADMIN',
                selected: filterRole == 'ADMIN',
                color: AppTheme.crimson,
                onTap: () => onRoleChanged('ADMIN'),
              ),
              const SizedBox(width: 6),
              FilterTab(
                label: l.usersMgmtRoleManagerLabel,
                value: 'MANAGER',
                selected: filterRole == 'MANAGER',
                color: AppTheme.cobalt,
                onTap: () => onRoleChanged('MANAGER'),
              ),
              const SizedBox(width: 6),
              FilterTab(
                label: l.usersMgmtRoleOperatorLabel,
                value: 'OPERATOR',
                selected: filterRole == 'OPERATOR',
                color: AppTheme.emerald,
                onTap: () => onRoleChanged('OPERATOR'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status and metric chip for user counts.
class StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData? icon;

  const StatChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    this.icon,
  });

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
        mainAxisSize: MainAxisSize.min,
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

/// Filter tab selector for user roles.
class FilterTab extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const FilterTab({
    super.key,
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
