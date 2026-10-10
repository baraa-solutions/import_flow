import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/current_permissions_provider.dart';
import '../../localization/app_localizations.dart';
import '../../network/api_error.dart';
import '../../theme/app_theme.dart';
import '../buttons/icon_action_button.dart';

/// Categories of actions available in a table row.
enum RowActionKind {
  view,
  edit,
  clone,
  print,
  history,
  delete,
  custom,
}

/// A declarative description of an action that can be performed on a row item [T].
///
/// Supports permission gating, confirmation dialogs, custom icons/labels, and disabled states.
class RowAction<T> {
  final RowActionKind kind;
  final FutureOr<void> Function(T row) run;
  final String? permission;
  final String? disabledReason;
  final bool enabled;
  final bool confirm;
  final String Function(AppLocalizations l)? confirmTitle;
  final String Function(AppLocalizations l, T row)? confirmMessage;
  final IconData? icon;
  final String Function(AppLocalizations l)? label;
  final Color? color;
  final Color? backgroundColor;
  final bool isDestructive;

  const RowAction({
    required this.kind,
    required this.run,
    this.permission,
    this.disabledReason,
    this.enabled = true,
    this.confirm = false,
    this.confirmTitle,
    this.confirmMessage,
    this.icon,
    this.label,
    this.color,
    this.backgroundColor,
    this.isDestructive = false,
  });

  /// 👁️ Standard View / Details action.
  factory RowAction.view({
    required FutureOr<void> Function(T row) run,
    String? permission,
    String? disabledReason,
    bool enabled = true,
    IconData? icon,
    String Function(AppLocalizations l)? label,
  }) =>
      RowAction<T>(
        kind: RowActionKind.view,
        run: run,
        permission: permission,
        disabledReason: disabledReason,
        enabled: enabled,
        icon: icon ?? Icons.visibility,
        label: label ?? ((l) => l.viewDetailsTooltip),
        color: AppTheme.cobalt,
        backgroundColor: AppTheme.cobaltLight,
      );

  /// ✏️ Standard Edit action.
  factory RowAction.edit({
    required FutureOr<void> Function(T row) run,
    String? permission,
    String? disabledReason,
    bool enabled = true,
    IconData? icon,
    String Function(AppLocalizations l)? label,
  }) =>
      RowAction<T>(
        kind: RowActionKind.edit,
        run: run,
        permission: permission,
        disabledReason: disabledReason,
        enabled: enabled,
        icon: icon ?? Icons.edit,
        label: label ?? ((l) => l.editTooltip),
        color: AppTheme.orange,
        backgroundColor: AppTheme.orangeLight,
      );

  /// 📋 Standard Clone / Duplicate action.
  factory RowAction.clone({
    required FutureOr<void> Function(T row) run,
    String? permission,
    String? disabledReason,
    bool enabled = true,
    IconData? icon,
    String Function(AppLocalizations l)? label,
  }) =>
      RowAction<T>(
        kind: RowActionKind.clone,
        run: run,
        permission: permission,
        disabledReason: disabledReason,
        enabled: enabled,
        icon: icon ?? Icons.copy_rounded,
        label: label ?? ((l) => l.cloneRowTooltip),
        color: AppTheme.cobalt,
        backgroundColor: AppTheme.cobaltLight,
      );

  /// 🖨️ Standard Print / Export action.
  factory RowAction.print({
    required FutureOr<void> Function(T row) run,
    String? permission,
    String? disabledReason,
    bool enabled = true,
    IconData? icon,
    String Function(AppLocalizations l)? label,
  }) =>
      RowAction<T>(
        kind: RowActionKind.print,
        run: run,
        permission: permission,
        disabledReason: disabledReason,
        enabled: enabled,
        icon: icon ?? Icons.print,
        label: label ?? ((l) => l.printTooltip),
        color: AppTheme.charcoal,
      );

  /// 🕒 Standard Activity / History Log action.
  factory RowAction.history({
    required FutureOr<void> Function(T row) run,
    String? permission,
    String? disabledReason,
    bool enabled = true,
    IconData? icon,
    String Function(AppLocalizations l)? label,
  }) =>
      RowAction<T>(
        kind: RowActionKind.history,
        run: run,
        permission: permission,
        disabledReason: disabledReason,
        enabled: enabled,
        icon: icon ?? Icons.history,
        label: label ?? ((l) => l.viewActivityLog),
        color: AppTheme.charcoal,
      );

  /// 🗑️ Standard Delete action (defaults to requiring confirmation).
  factory RowAction.delete({
    required FutureOr<void> Function(T row) run,
    String? permission,
    String? disabledReason,
    bool enabled = true,
    bool confirm = true,
    String Function(AppLocalizations l)? confirmTitle,
    String Function(AppLocalizations l, T row)? confirmMessage,
    IconData? icon,
    String Function(AppLocalizations l)? label,
  }) =>
      RowAction<T>(
        kind: RowActionKind.delete,
        run: run,
        permission: permission,
        disabledReason: disabledReason,
        enabled: enabled,
        confirm: confirm,
        confirmTitle: confirmTitle,
        confirmMessage: confirmMessage,
        icon: icon ?? Icons.delete_outline,
        label: label ?? ((l) => l.deleteTooltip),
        color: AppTheme.crimson,
        backgroundColor: AppTheme.crimsonLight,
        isDestructive: true,
      );

  /// ⚙️ Custom action.
  factory RowAction.custom({
    required FutureOr<void> Function(T row) run,
    required IconData icon,
    required String Function(AppLocalizations l) label,
    String? permission,
    String? disabledReason,
    bool enabled = true,
    bool confirm = false,
    String Function(AppLocalizations l)? confirmTitle,
    String Function(AppLocalizations l, T row)? confirmMessage,
    Color? color,
    Color? backgroundColor,
    bool isDestructive = false,
  }) =>
      RowAction<T>(
        kind: RowActionKind.custom,
        run: run,
        permission: permission,
        disabledReason: disabledReason,
        enabled: enabled,
        confirm: confirm,
        confirmTitle: confirmTitle,
        confirmMessage: confirmMessage,
        icon: icon,
        label: label,
        color: color,
        backgroundColor: backgroundColor,
        isDestructive: isDestructive,
      );

  IconData resolveIcon() {
    if (icon != null) return icon!;
    switch (kind) {
      case RowActionKind.view:
        return Icons.visibility;
      case RowActionKind.edit:
        return Icons.edit;
      case RowActionKind.clone:
        return Icons.copy_rounded;
      case RowActionKind.print:
        return Icons.print;
      case RowActionKind.history:
        return Icons.history;
      case RowActionKind.delete:
        return Icons.delete_outline;
      case RowActionKind.custom:
        return Icons.extension;
    }
  }

  String resolveLabel(AppLocalizations l) {
    if (label != null) return label!(l);
    switch (kind) {
      case RowActionKind.view:
        return l.viewDetailsTooltip;
      case RowActionKind.edit:
        return l.editTooltip;
      case RowActionKind.clone:
        return l.cloneRowTooltip;
      case RowActionKind.print:
        return l.printTooltip;
      case RowActionKind.history:
        return l.viewActivityLog;
      case RowActionKind.delete:
        return l.deleteTooltip;
      case RowActionKind.custom:
        return '';
    }
  }

  Color resolveColor(BuildContext context) {
    if (color != null) return color!;
    switch (kind) {
      case RowActionKind.view:
        return AppTheme.cobalt;
      case RowActionKind.edit:
        return AppTheme.orange;
      case RowActionKind.clone:
        return AppTheme.cobalt;
      case RowActionKind.print:
      case RowActionKind.history:
        return AppTheme.charcoal;
      case RowActionKind.delete:
        return AppTheme.crimson;
      case RowActionKind.custom:
        return AppTheme.cobalt;
    }
  }

  Color? resolveBackgroundColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor;
    switch (kind) {
      case RowActionKind.view:
      case RowActionKind.clone:
        return AppTheme.cobaltLight;
      case RowActionKind.edit:
        return AppTheme.orangeLight;
      case RowActionKind.delete:
        return AppTheme.crimsonLight;
      default:
        return null;
    }
  }
}

/// Shared confirmation dialog for row actions.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = true,
}) async {
  final l = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel ?? l.cancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppTheme.crimson : AppTheme.cobalt,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? l.confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Canonical order for standard row action kinds.
const List<RowActionKind> canonicalActionOrder = [
  RowActionKind.view,
  RowActionKind.edit,
  RowActionKind.clone,
  RowActionKind.print,
  RowActionKind.history,
  RowActionKind.delete,
];

/// A unified row action toolbar for table rows.
///
/// Renders standard actions in fixed order (view, edit, clone, print, history, delete),
/// and displays custom or overflow actions in a `⋮` popup menu.
/// Automatically hides actions where the current user lacks the required permission.
class RowActionsBar<T> extends ConsumerWidget {
  final T row;
  final List<RowAction<T>> actions;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final bool showAsPill;
  final BoxDecoration? decoration;

  const RowActionsBar({
    super.key,
    required this.row,
    required this.actions,
    this.iconSize = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    this.showAsPill = true,
    this.decoration,
  });

  bool _isPermitted(RowAction<T> action, WidgetRef ref) {
    if (action.permission == null || action.permission!.isEmpty) return true;
    final permState = ref.watch(currentPermissionsProvider);
    return permState.when(
      data: (permSet) => permSet.can(action.permission!),
      loading: () => action.permission!.endsWith('.view'),
      error: (_, __) => action.permission!.endsWith('.view'),
    );
  }

  static Future<void> executeAction<T>(
    BuildContext context,
    RowAction<T> action,
    T row, {
    WidgetRef? ref,
    PermissionSet? permissions,
  }) async {
    final l = context.l10n;
    if (!action.enabled || action.disabledReason != null) {
      return;
    }

    if (action.permission != null && action.permission!.isNotEmpty) {
      bool isPermitted = true;
      if (permissions != null) {
        isPermitted = permissions.can(action.permission!);
      } else {
        AsyncValue<PermissionSet>? permState;
        if (ref != null) {
          permState = ref.read(currentPermissionsProvider);
        } else {
          try {
            final container = ProviderScope.containerOf(context, listen: false);
            permState = container.read(currentPermissionsProvider);
          } catch (_) {}
        }
        if (permState != null) {
          isPermitted = permState.when(
            data: (permSet) => permSet.can(action.permission!),
            loading: () => action.permission!.endsWith('.view'),
            error: (_, __) => action.permission!.endsWith('.view'),
          );
        }
      }
      if (!isPermitted) return;
    }

    if (action.confirm) {
      final title = action.confirmTitle?.call(l) ?? l.confirmDeleteTitle;
      final msg = action.confirmMessage?.call(l, row) ?? l.confirmDeleteMessage('');
      final confirmed = await showConfirmDialog(
        context,
        title: title,
        message: msg,
        isDestructive: action.isDestructive || action.kind == RowActionKind.delete,
      );
      if (!confirmed) return;
    }

    try {
      await action.run(row);
      if (context.mounted && action.isDestructive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.deletedSuccessfully),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiError.message(e, fallback: l.operationFailed)),
            backgroundColor: AppTheme.crimson,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleActionTap(
    BuildContext context,
    RowAction<T> action,
  ) async {
    await executeAction(context, action, row);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    // Filter permitted actions
    final permittedActions = actions.where((a) => _isPermitted(a, ref)).toList();
    if (permittedActions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Partition into standard actions and custom actions
    final standardMap = <RowActionKind, RowAction<T>>{};
    final customActions = <RowAction<T>>[];

    for (final action in permittedActions) {
      if (action.kind == RowActionKind.custom) {
        customActions.add(action);
      } else {
        standardMap[action.kind] = action;
      }
    }

    // Build standard actions in canonical order
    final primaryWidgets = <Widget>[];
    for (final kind in canonicalActionOrder) {
      final action = standardMap[kind];
      if (action == null) continue;

      final isActionEnabled = action.enabled && action.disabledReason == null;
      final tooltip = action.disabledReason ?? action.resolveLabel(l);

      if (primaryWidgets.isNotEmpty) {
        primaryWidgets.add(const SizedBox(width: 4));
      }

      primaryWidgets.add(
        IconActionButton(
          icon: action.resolveIcon(),
          color: action.resolveColor(context),
          backgroundColor: action.resolveBackgroundColor(context),
          tooltip: tooltip,
          iconSize: iconSize,
          onTap: isActionEnabled ? () => _handleActionTap(context, action) : null,
        ),
      );
    }

    // Add overflow button if there are custom actions
    if (customActions.isNotEmpty) {
      if (primaryWidgets.isNotEmpty) {
        primaryWidgets.add(const SizedBox(width: 4));
      }

      primaryWidgets.add(
        PopupMenuButton<RowAction<T>>(
          tooltip: l.moreActionsTooltip,
          icon: Icon(Icons.more_vert, size: iconSize, color: AppTheme.charcoal),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          itemBuilder: (ctx) => customActions.map((action) {
            final isEnabled = action.enabled && action.disabledReason == null;
            return PopupMenuItem<RowAction<T>>(
              value: action,
              enabled: isEnabled,
              child: Row(
                children: [
                  Icon(
                    action.resolveIcon(),
                    size: 16,
                    color: isEnabled
                        ? (action.color ?? AppTheme.cobalt)
                        : AppTheme.textMutedOf(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action.resolveLabel(l),
                      style: TextStyle(
                        fontSize: 13,
                        color: isEnabled
                            ? (action.isDestructive ? AppTheme.crimson : AppTheme.charcoal)
                            : AppTheme.textMutedOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onSelected: (action) => _handleActionTap(context, action),
        ),
      );
    }

    final effectiveDecoration = showAsPill
        ? (decoration ?? AppTheme.pillDecorationOf(context))
        : decoration;

    return Container(
      padding: padding,
      decoration: effectiveDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: primaryWidgets,
      ),
    );
  }
}
