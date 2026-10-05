import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../models/actual_landed_cost_model.dart' show SettlementMessageModel;

/// Neutral tokens derived from the AppTheme palette (no raw hex in widgets).
class SettlementTokens {
  SettlementTokens._();

  /// Hairline border used by cards, tables and dividers.
  static Color get border => AppTheme.charcoal.withOpacity(0.15);

  /// Very light fill for muted panels (sign-off form, empty table, meta strip).
  static Color get panelFill => AppTheme.charcoal.withOpacity(0.04);

  /// Table heading fill.
  static Color get tableHeadFill => AppTheme.charcoal.withOpacity(0.07);

  static const double pagePadding = 16;
  static const double sectionGap = 16;
  static const double radius = 10;
}

/// Money display used across the settlement UI: 2 decimals, thousands grouped.
/// Display only; the numeric value itself is never rounded or changed.
String formatSettlementMoney(num value) {
  return value.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
}

/// Whole-number variant (no decimals) for compact KPI values.
String formatSettlementWhole(num value) {
  return value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
}

/// Signed percent text such as `+3.5%` / `-1.0%` (display only).
String formatSettlementPercent(double value, {int digits = 1}) {
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(digits)}%';
}

/// Money / number cell: always left-to-right glyph order, aligned to the end
/// edge of the column so figures line up in both LTR and RTL.
class SettlementMoneyText extends StatelessWidget {
  const SettlementMoneyText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: LtrText(
        text,
        textAlign: TextAlign.end,
        style: style,
      ),
    );
  }
}

/// Consistent coloured status chip (draft / calculated / approved / paid ...).
class SettlementStatusChip extends StatelessWidget {
  const SettlementStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: dense ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title with a leading accent bar and optional trailing widget.
class SettlementSectionHeader extends StatelessWidget {
  const SettlementSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.color = AppTheme.charcoal,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Loading / empty / error state: icon + message + optional action.
class SettlementStateView extends StatelessWidget {
  const SettlementStateView.loading({super.key, required this.message})
      : icon = null,
        color = AppTheme.cobalt,
        actionLabel = null,
        onAction = null,
        isLoading = true;

  const SettlementStateView.empty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  })  : color = AppTheme.textSecondary,
        isLoading = false;

  const SettlementStateView.error({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
    this.actionLabel,
    this.onAction,
  })  : color = AppTheme.crimson,
        isLoading = false;

  final String message;
  final IconData? icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Icon(icon, size: 48, color: color),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isLoading ? FontWeight.w600 : FontWeight.w500,
                  color: color == AppTheme.cobalt ? AppTheme.charcoal : color,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                AppButton(
                  label: actionLabel!,
                  icon: Icons.refresh,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog title bar: icon chip, title/subtitle, optional trailing + close.
class SettlementDialogHeader extends StatelessWidget {
  const SettlementDialogHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onClose,
    this.closeTooltip,
    this.closeKey,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;
  final String? closeTooltip;
  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(12),
          topEnd: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppTheme.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (onClose != null)
            IconButton(
              key: closeKey,
              icon: Icon(Icons.close, color: AppTheme.white.withOpacity(0.8)),
              tooltip: closeTooltip,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

/// Dialog action bar: optional leading widget, actions pushed to the end.
class SettlementDialogFooter extends StatelessWidget {
  const SettlementDialogFooter({
    super.key,
    required this.actions,
    this.leading,
  });

  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: SettlementTokens.panelFill,
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(12),
          bottomEnd: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: SettlementTokens.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          if (leading != null) leading! else const SizedBox.shrink(),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ),
    );
  }
}

/// Bordered card used to group fields / tables inside dialogs.
class SettlementPanel extends StatelessWidget {
  const SettlementPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.filled = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: filled ? SettlementTokens.panelFill : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        border: Border.all(color: SettlementTokens.border),
      ),
      child: child,
    );
  }
}

/// Bold, small heading cell for hand-rolled DataTables.
Widget settlementHeadCell(String text) => Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
    );

/// Settlement lifecycle status (Draft / Calculated / Approved) as a chip.
Widget settlementStatusChip(BuildContext context, String status,
    {bool dense = false}) {
  final l10n = context.l10n;
  Color color = AppTheme.cobalt;
  String label = status;
  IconData icon = Icons.info_outline;
  if (status == 'Calculated') {
    color = AppTheme.emerald;
    label = l10n.financialSettlementStatusCalculated;
    icon = Icons.calculate_outlined;
  } else if (status == 'Approved') {
    color = AppTheme.cobalt;
    label = l10n.financialSettlementStatusApproved;
    icon = Icons.verified_outlined;
  } else if (status == 'Draft') {
    color = AppTheme.orange;
    label = l10n.financialSettlementStatusDraft;
    icon = Icons.edit_note;
  }
  return SettlementStatusChip(label: label, color: color, icon: icon, dense: dense);
}

/// Cost summary metrics split over several shared [MetricCardStrip] rows so
/// long money values always fit (never truncated) inside dialogs.
class SettlementMetricStrips extends StatelessWidget {
  const SettlementMetricStrips({
    super.key,
    required this.metrics,
    this.perRow = 3,
  });

  final List<MetricCardData> metrics;
  final int perRow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Narrow dialogs: fewer cards per row so values are never cut off.
      final n = (constraints.maxWidth / 280).floor().clamp(1, perRow);
      final rows = <List<MetricCardData>>[];
      for (var i = 0; i < metrics.length; i += n) {
        rows.add(metrics.sublist(i, i + n > metrics.length ? metrics.length : i + n));
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            MetricCardStrip(padding: EdgeInsets.zero, metrics: rows[i]),
          ],
        ],
      );
    });
  }
}

/// Renders a backend `{code, params}` message with l10n; an unknown code is
/// shown as the code itself.
String settlementMessageText(AppLocalizations l10n, SettlementMessageModel m) {
  String p(String k) => '${m.params[k] ?? '-'}';
  switch (m.code) {
    case 'SETTLEMENT_LINE_NO_HS':
      return l10n.settlementMsgLineNoHs(p('item_code'), p('line_no'));
    case 'PAYMENT_STATUS_UNKNOWN':
      return l10n.settlementMsgPaymentStatusUnknown(p('invoice_no'), p('party_name'));
    case 'ESTIMATE_UNAVAILABLE':
      return l10n.settlementMsgEstimateUnavailable(p('reason'));
    case 'SETTLEMENT_UNPAID_INVOICE':
      final amount = m.params['amount'];
      return l10n.settlementMsgUnpaidInvoice(
        p('party_name'),
        amount is num ? formatSettlementMoney(amount) : p('amount'),
        p('invoice_no'),
      );
    case 'WHT_RATE_MISSING_WARNING':
      return l10n.settlementMsgWhtRateMissing(p('tax_code'), p('on_date'), p('invoice_no'));
    default:
      return m.code;
  }
}

/// Warning list: backend messages by code, else the legacy plain strings.
List<String> settlementWarningLines(
  AppLocalizations l10n,
  List<SettlementMessageModel> messages,
  List<String> legacy,
) {
  if (messages.isNotEmpty) {
    return messages.map((m) => settlementMessageText(l10n, m)).toList();
  }
  return legacy;
}

/// Scales a button down (never clips) when its label is wider than the space
/// the parent offers, e.g. long Arabic labels on narrow windows.
class SettlementFit extends StatelessWidget {
  const SettlementFit({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
  }
}
