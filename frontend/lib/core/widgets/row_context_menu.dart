import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/providers/current_permissions_provider.dart';
import '../localization/app_localizations.dart';
import '../network/api_error.dart';
import '../theme/app_theme.dart';
import 'paged_data_table/row_action.dart';

/// Helper to render right-click / long-press context menus for table rows.
class RowContextMenuHelper {
  /// Builds and displays a context menu driven by declarative [RowAction] items.
  static void showActionsMenu<T>({
    required BuildContext context,
    required Offset globalPosition,
    required T row,
    required List<RowAction<T>> actions,
    String? codeToCopy,
    PermissionSet? permissions,
  }) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l = context.l10n;

    // Filter permitted and enabled actions
    final filtered = actions.where((a) {
      if (!a.enabled) return false;
      if (permissions != null && a.permission != null && a.permission!.isNotEmpty) {
        return permissions.can(a.permission!);
      }
      return true;
    }).toList();

    // Sort: standard actions in canonical order (view first, edit, clone, etc.), followed by custom
    final standardMap = <RowActionKind, RowAction<T>>{};
    final customActions = <RowAction<T>>[];
    for (final action in filtered) {
      if (action.kind == RowActionKind.custom) {
        customActions.add(action);
      } else {
        standardMap[action.kind] = action;
      }
    }

    final sortedActions = <RowAction<T>>[];
    for (final kind in canonicalActionOrder) {
      final action = standardMap[kind];
      if (action != null) sortedActions.add(action);
    }
    sortedActions.addAll(customActions);

    final menuItems = <PopupMenuEntry<dynamic>>[];

    for (int i = 0; i < sortedActions.length; i++) {
      final action = sortedActions[i];
      menuItems.add(
        PopupMenuItem<RowAction<T>>(
          value: action,
          child: Row(
            children: [
              Icon(
                action.resolveIcon(),
                size: 18,
                color: action.resolveColor(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.resolveLabel(l),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: action.isDestructive ? AppTheme.crimson : AppTheme.charcoal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (codeToCopy != null && codeToCopy.isNotEmpty) {
      if (menuItems.isNotEmpty) {
        menuItems.add(const PopupMenuDivider());
      }
      menuItems.add(
        PopupMenuItem<String>(
          value: '__copy_code__',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 18, color: AppTheme.charcoal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.copyCode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (menuItems.isEmpty) return;

    showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: menuItems,
    ).then((value) async {
      if (value == null) return;
      if (value == '__copy_code__') {
        Clipboard.setData(ClipboardData(text: codeToCopy!));
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l.copiedToClipboard(codeToCopy)),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (value is RowAction<T>) {
        if (!context.mounted) return;
        if (value.confirm) {
          final title = value.confirmTitle?.call(l) ?? l.confirmDeleteTitle;
          final msg = value.confirmMessage?.call(l, row) ?? l.confirmDeleteMessage('');
          final confirmed = await showConfirmDialog(
            context,
            title: title,
            message: msg,
            isDestructive: value.isDestructive,
          );
          if (!confirmed) return;
        }

        try {
          await value.run(row);
          if (context.mounted && value.isDestructive) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(l.deletedSuccessfully),
                backgroundColor: AppTheme.emerald,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(ApiError.message(e, fallback: l.genericErrorMessage)),
                backgroundColor: AppTheme.crimson,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    });
  }

  /// Backward-compatible legacy context menu method.
  static void showContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required String codeToCopy,
    required VoidCallback onEdit,
    required VoidCallback onHistory,
    required bool isActive,
    required VoidCallback onToggleActive,
  }) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l = context.l10n;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, size: 18, color: AppTheme.cobalt),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.editRecord,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'history',
          child: Row(
            children: [
              const Icon(Icons.history, size: 18, color: AppTheme.charcoal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.viewActivityLog,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 18, color: AppTheme.charcoal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.copyCode,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                isActive ? Icons.block : Icons.restore,
                size: 18,
                color: isActive ? AppTheme.crimson : AppTheme.emerald,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isActive ? l.deactivateRecord : l.restoreRecord,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppTheme.crimson : AppTheme.emerald,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'edit':
          onEdit();
          break;
        case 'history':
          onHistory();
          break;
        case 'copy':
          Clipboard.setData(ClipboardData(text: codeToCopy));
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(l.copiedToClipboard(codeToCopy)),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
        case 'toggle':
          onToggleActive();
          break;
      }
    });
  }
}
