import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../copyable_data_helper.dart';

/// A styled section card inside an entity details view.
///
/// Automatically presents its [children] in a 2-column layout when width ≥ 440px,
/// and a 1-column layout on narrower screens.
class DetailsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const DetailsSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceAltOf(context) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppTheme.borderOf(context)),
          // Section Content (Responsive 1 or 2 columns)
          Padding(
            padding: padding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth >= 440;
                if (!isTwoCol) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < children.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        children[i],
                      ],
                    ],
                  );
                }

                // Two-column layout with support for full-width fields
                final rows = <Widget>[];
                int i = 0;
                while (i < children.length) {
                  final current = children[i];
                  final isCurrentFullWidth = current is DetailsField && current.fullWidth;

                  if (isCurrentFullWidth) {
                    if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
                    rows.add(SizedBox(width: double.infinity, child: current));
                    i++;
                  } else if (i + 1 < children.length) {
                    final next = children[i + 1];
                    final isNextFullWidth = next is DetailsField && next.fullWidth;
                    if (isNextFullWidth) {
                      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
                      rows.add(Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: current),
                          const SizedBox(width: 16),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ));
                      i++;
                    } else {
                      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
                      rows.add(Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: current),
                          const SizedBox(width: 16),
                          Expanded(child: next),
                        ],
                      ));
                      i += 2;
                    }
                  } else {
                    if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
                    rows.add(Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: current),
                        const SizedBox(width: 16),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ));
                    i++;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only label/value field widget for entity details views.
///
/// - Displays `'—'` if [value] is null or empty.
/// - Provides a copy button when [copyable] is true (calls [CopyHelper.copy]).
/// - Places [value] inside an LTR island when [ltr] is true (for codes, numbers, dates).
class DetailsField extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? customValue;
  final bool copyable;
  final bool ltr;
  final bool fullWidth;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const DetailsField({
    super.key,
    required this.label,
    this.value,
    this.customValue,
    this.copyable = true,
    this.ltr = false,
    this.fullWidth = false,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isNullOrEmpty = value == null || value!.trim().isEmpty;
    final displayValue = isNullOrEmpty ? '—' : value!.trim();
    final canCopy = copyable && !isNullOrEmpty;

    Widget valueWidget;
    if (customValue != null) {
      valueWidget = customValue!;
    } else {
      final text = Text(
        displayValue,
        style: valueStyle ??
            TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isNullOrEmpty
                  ? AppTheme.textMutedOf(context)
                  : AppTheme.textPrimaryOf(context),
            ),
      );

      if (ltr) {
        valueWidget = Directionality(
          textDirection: TextDirection.ltr,
          child: text,
        );
      } else {
        valueWidget = text;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: labelStyle ??
              TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMutedOf(context),
              ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: InkWell(
                onDoubleTap: canCopy ? () => CopyHelper.copy(context, displayValue) : null,
                borderRadius: BorderRadius.circular(4),
                child: valueWidget,
              ),
            ),
            if (canCopy) ...[
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                splashRadius: 12,
                tooltip: l.copyValue,
                icon: Icon(
                  Icons.copy_rounded,
                  size: 13,
                  color: AppTheme.textMutedOf(context),
                ),
                onPressed: () => CopyHelper.copy(context, displayValue),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
