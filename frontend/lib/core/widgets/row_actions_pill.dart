import 'dart:async';
import 'package:flutter/material.dart';
import 'paged_data_table/row_action.dart';

/// Standard 4-Action Row Pill Widget for Sorour Logistics ERP data tables.
///
/// Thin adapter wrapping [RowActionsBar] with backward-compatible callbacks.
/// Automatically hides actions where the corresponding callback is null (no more grey disabled icons).
class RowActionsPill extends StatelessWidget {
  final FutureOr<void> Function()? onView;
  final FutureOr<void> Function()? onEdit;
  final FutureOr<void> Function()? onClone;
  final FutureOr<void> Function()? onPrint;
  final FutureOr<void> Function()? onDelete;

  /// Override tooltips for domain-specific labels (optional).
  final String? viewTooltip;
  final String? editTooltip;
  final String? cloneTooltip;
  final String? printTooltip;
  final String? deleteTooltip;

  final double iconSize;

  /// Whether delete action triggers the shared confirmation dialog.
  /// Defaults to false for backward compatibility with callers that display their own dialog.
  final bool confirmDelete;
  final Key? viewKey;
  final Key? editKey;
  final Key? cloneKey;
  final Key? printKey;
  final Key? deleteKey;

  const RowActionsPill({
    super.key,
    this.onView,
    this.onEdit,
    this.onClone,
    this.onPrint,
    this.onDelete,
    this.viewTooltip,
    this.editTooltip,
    this.cloneTooltip,
    this.printTooltip,
    this.deleteTooltip,
    this.iconSize = 16.0,
    this.confirmDelete = false,
    this.viewKey,
    this.editKey,
    this.cloneKey,
    this.printKey,
    this.deleteKey,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <RowAction<void>>[];

    if (onView != null) {
      actions.add(
        RowAction.view(
          key: viewKey,
          run: (_) async => await onView!(),
          label: viewTooltip != null ? (_) => viewTooltip! : null,
        ),
      );
    }

    if (onEdit != null) {
      actions.add(
        RowAction.edit(
          key: editKey,
          run: (_) async => await onEdit!(),
          label: editTooltip != null ? (_) => editTooltip! : null,
        ),
      );
    }

    if (onClone != null) {
      actions.add(
        RowAction.clone(
          key: cloneKey,
          run: (_) async => await onClone!(),
          label: cloneTooltip != null ? (_) => cloneTooltip! : null,
        ),
      );
    }

    if (onPrint != null) {
      actions.add(
        RowAction.print(
          key: printKey,
          run: (_) async => await onPrint!(),
          label: printTooltip != null ? (_) => printTooltip! : null,
        ),
      );
    }

    if (onDelete != null) {
      actions.add(
        RowAction.delete(
          key: deleteKey,
          run: (_) async => await onDelete!(),
          confirm: confirmDelete,
          showOutcomeSnackBar: false,
          label: deleteTooltip != null ? (_) => deleteTooltip! : null,
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return RowActionsBar<void>(
      row: null,
      actions: actions,
      iconSize: iconSize,
      showAsPill: true,
    );
  }
}
