import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../helpers/table_copy_helper.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

/// Central clipboard helper utility and reusable widgets for copying data
/// across all screens in Sorour Logistics ERP.
class CopyHelper {
  /// Copies the specified [text] to the system clipboard and displays a
  /// styled, floating confirmation SnackBar.
  static Future<void> copy(
    BuildContext context,
    String text, {
    String? customMessage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: trimmed));
    if (!context.mounted) return;

    final l10n = context.l10n;
    final message = customMessage ?? l10n.copiedToClipboardGeneric;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 320,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppTheme.flatCharcoal,
        duration: const Duration(milliseconds: 1500),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.flatEmerald, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A text widget that can be copied via right-click (secondary tap), double-tap,
/// or via an optional static icon button. Lightened for high performance in large data tables.
class CopyableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool showIcon;
  final bool isSelectable;
  final String? tooltip;
  final String? copyMessage;

  /// Direction of [text]. Pass [TextDirection.ltr] for codes and numbers
  /// (LTR island inside Arabic); null follows the ambient [Directionality].
  final TextDirection? textDirection;

  const CopyableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.showIcon = false,
    this.isSelectable = false,
    this.tooltip,
    this.copyMessage,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    final Widget textWidget = isSelectable
        ? SelectableText(
            text,
            style: style,
            textAlign: textAlign,
            textDirection: textDirection,
            maxLines: maxLines,
          )
        : Text(
            text,
            style: style,
            textAlign: textAlign,
            textDirection: textDirection,
            overflow: overflow ?? TextOverflow.ellipsis,
            maxLines: maxLines,
          );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: textWidget),
        if (showIcon) ...[
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => CopyHelper.copy(
              context,
              text,
              customMessage: copyMessage,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.copy_rounded,
                size: (style?.fontSize ?? 14) * 0.95,
                color: AppTheme.flatCobalt.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ],
    );

    return GestureDetector(
      onSecondaryTap: () => CopyHelper.copy(
        context,
        text,
        customMessage: copyMessage,
      ),
      onDoubleTap: () => CopyHelper.copy(
        context,
        text,
        customMessage: copyMessage,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: content,
      ),
    );
  }
}

/// A cell wrapper for data tables or key-value summary rows that enables:
/// 1. Lightweight text rendering without DOM bloat.
/// 2. Right-click context menu to copy either cell value or full row formatted as Excel-ready TSV.
class CopyableTableCell extends StatelessWidget {
  final Widget child;
  final String value;
  final String? rowSummary;
  final List<dynamic>? rowValues;
  final List<String>? rowHeaders;
  final String? customMessage;

  const CopyableTableCell({
    super.key,
    required this.child,
    required this.value,
    this.rowSummary,
    this.rowValues,
    this.rowHeaders,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GestureDetector(
      onSecondaryTapUp: (details) async {
        final hasRowData = (rowValues != null && rowValues!.isNotEmpty) ||
            (rowSummary != null && rowSummary!.isNotEmpty);

        final selected = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx + 1,
            details.globalPosition.dy + 1,
          ),
          items: [
            PopupMenuItem<String>(
              value: 'cell',
              child: Row(
                children: [
                  const Icon(Icons.copy_rounded, size: 16, color: AppTheme.flatCobalt),
                  const SizedBox(width: 8),
                  Text(l10n.copyValue, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            if (hasRowData)
              PopupMenuItem<String>(
                value: 'row',
                child: Row(
                  children: [
                    const Icon(Icons.table_rows_rounded, size: 16, color: AppTheme.flatEmerald),
                    const SizedBox(width: 8),
                    Text(l10n.copyRow, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
          ],
        );

        if (!context.mounted) return;
        if (selected == 'cell') {
          CopyHelper.copy(context, value, customMessage: customMessage);
        } else if (selected == 'row') {
          if (rowValues != null && rowValues!.isNotEmpty) {
            TableCopyHelper.copyRow(context, rowValues!, headers: rowHeaders);
          } else if (rowSummary != null) {
            CopyHelper.copy(context, rowSummary!, customMessage: l10n.copiedToClipboardGeneric);
          }
        }
      },
      child: child,
    );
  }
}
