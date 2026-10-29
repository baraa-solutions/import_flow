import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/navigation_provider.dart';
import '../providers/workspace_tabs_provider.dart';
import 'unsaved_changes_dialog.dart';

/// Back to Dashboard button — compact icon or full labeled button.
/// Label pulled from [AppLocalizations].
/// Intercepts navigation if the active workspace tab contains unsaved changes.
class BackToDashboardButton extends ConsumerWidget {
  final bool isCompact;

  const BackToDashboardButton({
    super.key,
    this.isCompact = false,
  });

  Future<void> _handleBack(BuildContext context, WidgetRef ref) async {
    try {
      final activeTab = ref.read(workspaceTabsProvider).activeTab;
      if (activeTab != null && activeTab.isDirty) {
        final l10n = context.l10n;
        final confirmed = await UnsavedChangesDialog.show(
          context,
          customMessage: '${l10n.unsavedChangesMessage}\n(${activeTab.title})',
        );
        if (!confirmed) return;
        ref.read(workspaceTabsProvider.notifier).setTabDirty(activeTab.id, false);
      }
    } catch (_) {
      // Safe fallback if used outside ProviderScope
    }
    selectNavigationIndex(ref, 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    if (isCompact) {
      return IconButton(
        tooltip: l.backToDashboardTooltip,
        icon: const Icon(Icons.dashboard_customize_outlined, color: AppTheme.cobalt),
        onPressed: () => _handleBack(context, ref),
      );
    }

    return TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: AppTheme.cobaltMedium,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppTheme.cobaltBorder),
        ),
      ),
      onPressed: () => _handleBack(context, ref),
      icon: const Icon(Icons.dashboard_outlined, size: 16, color: AppTheme.cobalt),
      label: Text(
        l.backToDashboard,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
