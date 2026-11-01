import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/buttons/app_button.dart';

class ShippingScenariosFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final bool showInactive;
  final int totalCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onToggleShowInactive;
  final VoidCallback onOpenSearchAndClone;

  const ShippingScenariosFilterBar({
    super.key,
    required this.searchController,
    required this.showInactive,
    required this.totalCount,
    required this.onSearchChanged,
    required this.onToggleShowInactive,
    required this.onOpenSearchAndClone,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : AppTheme.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 750;
          final searchField = AppSearchField(
            controller: searchController,
            hint: l.searchStudiesHint,
            onChanged: (v) => onSearchChanged(v.trim()),
          );

          final actionWidgets = <Widget>[
            FilterChip(
              avatar: Icon(
                showInactive ? Icons.visibility_off : Icons.visibility,
                size: 16,
                color: showInactive ? AppTheme.crimson : AppTheme.textMuted,
              ),
              label: Text(
                showInactive ? l.showDeleted : l.hideDeleted,
                style: TextStyle(
                  fontSize: 12,
                  color: showInactive
                      ? AppTheme.crimson
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong),
                  fontWeight: showInactive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: showInactive,
              selectedColor: AppTheme.crimson.withValues(alpha: 0.12),
              checkmarkColor: AppTheme.crimson,
              onSelected: onToggleShowInactive,
            ),
            AppButton(
              key: const ValueKey('registrySearchAndCloneStudyBtn'),
              label: l.searchAndCloneStudyBtn,
              icon: Icons.control_point_duplicate_rounded,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: onOpenSearchAndClone,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cobalt,
                ),
              ),
            ),
          ];

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actionWidgets,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              ...actionWidgets.map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: w,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
