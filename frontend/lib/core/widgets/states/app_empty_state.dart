import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';

/// 📭 Empty State Widget — ImportFlow ERP
///
/// Replaces 116+ manual empty state `Column(children: [Icon, Text])` patterns
/// across 62 files.
///
/// Usage:
/// ```dart
/// // In AsyncValue.when()
/// data: (items) => items.isEmpty
///     ? AppEmptyState(message: l10n.noResultsFound)
///     : _buildList(items),
///
/// // With action button
/// AppEmptyState(
///   icon: Icons.folder_open_outlined,
///   message: l10n.noDailyUpdates,
///   actionLabel: l10n.addDailyUpdate,
///   onAction: _createNewFile,
/// )
///
/// // After search with no results
/// AppEmptyState.noSearchResults(context, query: _query)
/// ```
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// Convenience factory for "no search results" pattern.
  factory AppEmptyState.noSearchResults(
    BuildContext context, {
    Key? key,
    String? query,
  }) {
    final l = context.l10n;
    return AppEmptyState(
      key: key,
      icon: Icons.search_off_rounded,
      message: l.noResultsFound,
      subtitle: query != null && query.isNotEmpty
          ? '${l.noResultsFound}: $query'
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryOf(context),
                letterSpacing: 0,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textMutedOf(context),
                  letterSpacing: 0,
                ),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, letterSpacing: 0),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
