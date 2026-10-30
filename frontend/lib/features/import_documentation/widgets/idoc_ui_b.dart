import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';

/// Presentation-only number formatting for the import-documentation package-B
/// screens (ACID, Form 46, COO, inspection). No business math lives here.
class IdocBFormat {
  IdocBFormat._();

  /// `1,234,567.50` (two decimals, thousands grouping, always Latin digits).
  static String money(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${negative ? '-' : ''}$buf.${parts[1]}';
  }
}

/// Feature-local composition over the core tokens: section cards, status
/// chips, notices, empty / error / loading panels, a dialog frame and the
/// itemised money table used by Form 46.
class IdocBUi {
  IdocBUi._();

  /// [MetricCardStrip] on wide layouts; a wrapped grid of cards when narrow.
  static Widget metrics(List<MetricCardData> data) => LayoutBuilder(
        builder: (context, c) {
          // Long Arabic labels need ~300px per card before a single row fits.
          if (c.maxWidth >= 300.0 * data.length) return MetricCardStrip(metrics: data);
          final w = c.maxWidth >= 520 ? (c.maxWidth - 8) / 2 : c.maxWidth;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in data)
                SizedBox(width: w, child: MetricCard(data: m, forceShort: false)),
            ],
          );
        },
      );

  /// Lets a (non-flexible) AppButton shrink instead of overflowing.
  static Widget fit(Widget button) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.center,
        child: button,
      );
}

/// Titled card that groups related fields / facts: tinted icon tile, title,
/// optional trailing widget (actions, chip) and the standard card chrome.
class IdocBSectionCard extends StatelessWidget {
  const IdocBSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.accent,
    this.subtitle,
    this.margin = const EdgeInsetsDirectional.only(bottom: 16),
    this.padding = const EdgeInsetsDirectional.all(18),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final Color? accent;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.cobalt;
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsetsDirectional.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          Divider(height: 22, color: AppTheme.borderOf(context)),
          child,
        ],
      ),
    );
  }
}

/// Coloured pill: status, channel, approval ... one look everywhere.
class IdocBStatusChip extends StatelessWidget {
  const IdocBStatusChip({
    super.key,
    required this.label,
    required this.severity,
    this.icon,
  });

  final String label;
  final AppSeverity severity;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline notice (info / warning / error / success) with icon and message.
class IdocBNotice extends StatelessWidget {
  const IdocBNotice({
    super.key,
    required this.message,
    this.severity = AppSeverity.info,
    this.icon,
    this.margin = const EdgeInsetsDirectional.only(bottom: 12),
  });

  final String message;
  final AppSeverity severity;
  final IconData? icon;
  final EdgeInsetsGeometry margin;

  static IconData _defaultIcon(AppSeverity s) {
    switch (s) {
      case AppSeverity.success:
        return Icons.check_circle_outline;
      case AppSeverity.warning:
        return Icons.warning_amber_rounded;
      case AppSeverity.danger:
        return Icons.error_outline;
      case AppSeverity.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon(severity), size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty / error / loading panel: icon + message + optional action.
class IdocBStateView extends StatelessWidget {
  const IdocBStateView.empty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  })  : _loading = false,
        _error = false;

  const IdocBStateView.error({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  })  : icon = Icons.error_outline,
        _loading = false,
        _error = true;

  const IdocBStateView.loading({super.key})
      : message = '',
        icon = Icons.hourglass_empty,
        actionLabel = null,
        onAction = null,
        _loading = true,
        _error = false;

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool _loading;
  final bool _error;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsetsDirectional.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final color = _error ? AppTheme.crimson : AppTheme.textMutedOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _error ? AppTheme.crimson : AppTheme.textSecondaryOf(context),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              AppButton(
                label: actionLabel!,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: _error ? Icons.refresh : Icons.add_circle_outline,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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

/// One action of an [IdocBDialogShell] footer.
class IdocBDialogAction {
  const IdocBDialogAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.secondary,
    this.buttonKey,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final Key? buttonKey;
  final bool isLoading;
}

/// Frame of the package-B dialogs: charcoal header (icon, title, optional
/// chip, close), scrollable body and a footer with the standard buttons.
class IdocBDialogShell extends StatelessWidget {
  const IdocBDialogShell({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    required this.actions,
    this.subtitle,
    this.badge,
    this.accent = AppTheme.cobalt,
    this.maxWidth = 760,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget body;
  final List<IdocBDialogAction> actions;

  /// Header chip (declaration / certificate number): rendered LTR.
  final String? badge;
  final Color accent;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screen = MediaQuery.of(context).size;
    final width = screen.width > maxWidth + 40 ? maxWidth : screen.width * 0.95;
    final onDark = AppTheme.white.withValues(alpha: 0.78);
    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SelectionArea(
        child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: screen.height * 0.9),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(AppTheme.radiusXl),
                  topEnd: Radius.circular(AppTheme.radiusXl),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 2),
                            child: Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: onDark),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (badge != null && badge!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: LtrText(
                        badge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: onDark),
                      ),
                    ),
                  ],
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: onDark),
                    tooltip: l.close,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(20),
                child: body,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltOf(context),
                borderRadius: const BorderRadiusDirectional.only(
                  bottomStart: Radius.circular(AppTheme.radiusXl),
                  bottomEnd: Radius.circular(AppTheme.radiusXl),
                ),
                border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final a in actions)
                    AppButton(
                      key: a.buttonKey,
                      label: a.label,
                      icon: a.icon,
                      variant: a.variant,
                      size: AppButtonSize.small,
                      isLoading: a.isLoading,
                      onPressed: a.onPressed,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Footer bar of a form screen: neutral actions on the start edge, the
/// primary (save) action on the end edge, in the standard card chrome.
class IdocBActionBar extends StatelessWidget {
  const IdocBActionBar({
    super.key,
    required this.primary,
    this.secondary = const [],
  });

  final List<Widget> primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecorationOf(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: secondary),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: primary),
        ],
      ),
    );
  }
}
