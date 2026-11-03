import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import 'idoc_b_format.dart';

/// How a [IdocBMoneyLine] is emphasised in the table.
enum IdocBMoneyKind { normal, subtotal, total }

/// One row of the itemised money table: label (+ optional rate caption) on
/// the start edge and the amount on the end edge. Pass [amount] (formatted by
/// the table, `null` shows the missing marker) or a custom [field] widget
/// (editable figures). Amounts are LTR digits, right-aligned, tabular.
class IdocBMoneyLine extends StatelessWidget {
  const IdocBMoneyLine({
    super.key,
    required this.label,
    this.caption,
    this.amount,
    this.currency,
    this.field,
    this.kind = IdocBMoneyKind.normal,
    this.missingLabel = '',
    this.amountKey,
  });

  final String label;

  /// Muted second line (rate, formula, note).
  final String? caption;
  final double? amount;
  final String? currency;

  /// Replaces the read-only amount (e.g. an editable [TextFormField]).
  final Widget? field;
  final IdocBMoneyKind kind;
  final String missingLabel;
  final Key? amountKey;

  @override
  Widget build(BuildContext context) {
    final total = kind == IdocBMoneyKind.total;
    final sub = kind == IdocBMoneyKind.subtotal;
    final labelStyle = TextStyle(
      fontSize: total ? 13.5 : 12.5,
      fontWeight: (total || sub) ? FontWeight.bold : FontWeight.w500,
      color: total ? AppTheme.crimson : AppTheme.textPrimaryOf(context),
    );
    final captionStyle = TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context));

    final labelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        if (caption != null && caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Text(caption!, style: captionStyle),
          ),
      ],
    );

    final Widget value;
    if (field != null) {
      value = field!;
    } else if (amount == null) {
      value = IdocBMissingMark(label: missingLabel, key: amountKey);
    } else {
      final cur = currency ?? context.l10n.egpCurrency;
      value = LtrText(
        '${IdocBFormat.money(amount!)} $cur',
        key: amountKey,
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: total ? 15 : 13,
          fontWeight: (total || sub) ? FontWeight.bold : FontWeight.w600,
          color: total ? AppTheme.crimson : AppTheme.textPrimaryOf(context),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: total
            ? AppTheme.crimsonLight
            : (sub ? AppTheme.surfaceAltOf(context) : null),
        border: sub || total
            ? Border(top: BorderSide(color: AppTheme.borderOf(context)))
            : null,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = field != null && c.maxWidth < 440;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelColumn, const SizedBox(height: 8), value],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: labelColumn),
              const SizedBox(width: 12),
              if (field != null)
                SizedBox(width: 230, child: value)
              else
                Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: value)),
            ],
          );
        },
      ),
    );
  }
}

/// Muted red "missing" marker shown instead of a fabricated figure.
class IdocBMissingMark extends StatelessWidget {
  const IdocBMissingMark({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.crimsonLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.crimsonBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.crimson,
        ),
      ),
    );
  }
}

/// Bordered container that stacks [IdocBMoneyLine]s with hairline dividers
/// under an optional "Item / Amount" header.
class IdocBMoneyTable extends StatelessWidget {
  const IdocBMoneyTable({
    super.key,
    required this.lines,
    this.itemHeader,
    this.amountHeader,
  });

  final List<Widget> lines;
  final String? itemHeader;
  final String? amountHeader;

  @override
  Widget build(BuildContext context) {
    final border = AppTheme.borderOf(context);
    final headStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: AppTheme.textSecondaryOf(context),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (itemHeader != null || amountHeader != null)
            Container(
              color: AppTheme.surfaceAltOf(context),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(itemHeader ?? '', style: headStyle)),
                  Text(amountHeader ?? '', style: headStyle),
                ],
              ),
            ),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0 || itemHeader != null || amountHeader != null)
              Divider(height: 1, thickness: 1, color: border),
            lines[i],
          ],
        ],
      ),
    );
  }
}
