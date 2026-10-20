import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_clearance_model.dart';

/// Number / date formatting shared by the customs-clearance screens.
/// Pure presentation: no business math lives here.
class CcFormat {
  CcFormat._();

  /// `1,234,567.50` (two decimals, thousands grouping, always Latin digits).
  ///
  /// A null (unknown) value renders as [unknown] (an em dash), never as 0.00.
  static String money(double? value) {
    if (value == null) return unknown;
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

  /// `+1,200.00` / `-35.00` (explicit sign for variance figures).
  static String signedMoney(double? value) => value == null
      ? unknown
      : '${value >= 0 ? '+' : ''}${money(value)}';

  /// Plain two-decimal figure (no grouping) for exports; null -> [unknown].
  static String fixed(double? value) => value?.toStringAsFixed(2) ?? unknown;

  /// `+1200.00` / `-35.00` without grouping (exports); null -> [unknown].
  static String signedFixed(double? value) => value == null
      ? unknown
      : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';

  /// `12.5%`; null -> [unknown].
  static String percent(double? value) =>
      value == null ? unknown : '$value%';

  /// Placeholder shown for an unknown (null) figure.
  static const String unknown = '—';

  /// `yyyy-MM-dd` for a picked date.
  static String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Pure status queries and operational stage guards for customs clearance.
/// Mirrors backend guards (`modules/customs_clearance/validators.py`).
class CcStatus {
  CcStatus._();

  static const Set<String> paidStatuses = {
    'Paid & Verified',
    'Paid',
    'Duties Paid',
  };

  /// Payment status is one of the recognised paid states (legacy-tolerant).
  static bool isPaid(CustomsClearanceModel r) =>
      paidStatuses.contains(r.paymentStatus);

  /// Duty has been assessed: valid claim number and positive effective duty.
  static bool isAssessed(CustomsClearanceModel r) =>
      (r.nafezaClaimNumber ?? '').isNotEmpty && (r.effectiveDutyTotal ?? 0) > 0;

  /// Goods have been released by customs authority (by status or permit number).
  static bool isReleased(CustomsClearanceModel r) =>
      r.status == 'Final Release Granted' || (r.releasePermitNo ?? '').isNotEmpty;

  /// Duty payment is allowed only after assessment, before payment, and before release.
  static bool canPay(CustomsClearanceModel r) =>
      isAssessed(r) && !isPaid(r) && !isReleased(r);

  /// Final release is allowed only after payment, with quarantine lifted, and before release.
  static bool canRelease(CustomsClearanceModel r) =>
      isPaid(r) && !r.quarantineLock && !isReleased(r);

  /// Under-bond temporary release is allowed before final release and if not already under bond.
  static bool canUnderBond(CustomsClearanceModel r) =>
      !isReleased(r) && !r.isUnderBondRelease;

  /// Recording lab results is allowed when released under bond with an active quarantine lock.
  static bool canRecordLab(CustomsClearanceModel r) =>
      r.isUnderBondRelease && r.quarantineLock;
}

/// Pure KPI calculation for Customs Duty Payment and Ledger.
class FinalDutyKpis {
  const FinalDutyKpis({
    required this.outstanding,
    required this.totalPaid,
    required this.pendingCount,
    required this.netVariance,
  });

  final double outstanding;
  final double totalPaid;
  final int pendingCount;
  final double netVariance;

  factory FinalDutyKpis.from(List<CustomsClearanceModel> records) {
    var outstanding = 0.0;
    var totalPaid = 0.0;
    var pendingCount = 0;
    var netVariance = 0.0;

    for (final r in records) {
      if (CcStatus.isPaid(r)) {
        totalPaid += r.dutyPaidAmount ?? r.effectiveDutyTotal ?? 0.0;
      } else {
        pendingCount++;
        if (CcStatus.isAssessed(r)) {
          outstanding += r.effectiveDutyTotal ?? 0.0;
        }
      }

      if ((r.estimatedDutyTotal ?? 0) > 0) {
        netVariance += r.dutyVarianceAmount ?? 0.0;
      }
    }

    return FinalDutyKpis(
      outstanding: outstanding,
      totalPaid: totalPaid,
      pendingCount: pendingCount,
      netVariance: netVariance,
    );
  }
}

/// Thin feature-local composition over core tokens (see FinancialUi): maps
/// clearance statuses to severity chips and offers shared layout pieces.
class CcUi {
  CcUi._();

  /// Variance threshold in EGP triggering a visual warning.
  static const double varianceWarnThresholdEgp = 500.0;

  /// Lets a (non-flexible) AppButton shrink instead of overflowing.
  static Widget fit(Widget button) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.center,
        child: button,
      );

  /// Shared [MetricCardStrip] on wide layouts; a wrapped grid of [MetricCard]s
  /// when the width is too small for one row.
  static Widget metrics(List<MetricCardData> data) => LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 760) return MetricCardStrip(metrics: data);
          final w = c.maxWidth >= 520 ? (c.maxWidth - 8) / 2 : c.maxWidth;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in data)
                  SizedBox(
                      width: w, child: MetricCard(data: m, forceShort: true)),
              ],
            ),
          );
        },
      );

  /// Operational status of a clearance record -> chip style.
  static ({AppSeverity severity, String label}) statusStyle(
      AppLocalizations l, String status) {
    switch (status) {
      case 'Final Release Granted':
        return (
          severity: AppSeverity.success,
          label: l.customsClearanceFilterFinalRelease,
        );
      case 'Duty Paid':
        return (
          severity: AppSeverity.info,
          label: l.customsClearanceFilterDutyPaid,
        );
      case 'Duty Paid - Ready for Final Release':
        return (
          severity: AppSeverity.info,
          label: l.customsClearanceStatusDutyPaidReady,
        );
      case 'Customs Duties Assessed - Ready for Payment':
        return (
          severity: AppSeverity.warning,
          label: l.customsClearanceStatusDutiesAssessed,
        );
      case 'Inspection & Sampling Recorded':
        return (
          severity: AppSeverity.info,
          label: l.customsClearanceStatusInspectionRecorded,
        );
      case 'Under Bond Released':
        return (
          severity: AppSeverity.warning,
          label: l.customsClearanceStatusUnderBondReleased,
        );
      case 'Lab Non-Conforming - Rejected':
        return (
          severity: AppSeverity.danger,
          label: l.customsClearanceStatusLabRejected,
        );
      case 'Invoices Logged & Verified':
        return (
          severity: AppSeverity.info,
          label: l.customsClearanceStatusInvoicesVerified,
        );
      case 'Duty Requested':
        return (
          severity: AppSeverity.warning,
          label: l.customsClearanceFilterDutyRequested,
        );
      case 'Inspection In Progress':
        return (
          severity: AppSeverity.info,
          label: l.customsClearanceFilterInspection,
        );
      default:
        return (severity: AppSeverity.info, label: status);
    }
  }

  /// Customs channel (red / green / yellow) -> chip style.
  static ({AppSeverity severity, String label, IconData icon}) channelStyle(
      AppLocalizations l, String channelType) {
    final c = channelType.toLowerCase();
    if (c.contains('green')) {
      return (
        severity: AppSeverity.success,
        label: l.customsClearanceChannelGreen,
        icon: Icons.check_circle_outline
      );
    }
    if (c.contains('yellow')) {
      return (
        severity: AppSeverity.warning,
        label: l.customsClearanceChannelYellow,
        icon: Icons.flag_rounded
      );
    }
    if (c.contains('red')) {
      return (
        severity: AppSeverity.danger,
        label: l.customsClearanceChannelRed,
        icon: Icons.flag_rounded
      );
    }
    return (
      severity: AppSeverity.info,
      label: channelType,
      icon: Icons.flag_outlined
    );
  }
}

/// Coloured pill: draft / paid / pending / channel ... One look everywhere.
class CcStatusChip extends StatelessWidget {
  const CcStatusChip({
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
    return AppStatusBadge(
      label: label,
      severity: severity,
      icon: icon,
    );
  }
}

/// Titled card used to group related fields / facts (consistent spacing,
/// border and radius from [AppTheme]).
class CcSectionCard extends StatelessWidget {
  const CcSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.accent,
    this.margin = const EdgeInsetsDirectional.only(bottom: 12),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final Color? accent;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.cobalt;
    return Container(
      margin: margin,
      padding: const EdgeInsetsDirectional.all(14),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 4),
          Divider(height: 14, color: AppTheme.borderOf(context)),
          child,
        ],
      ),
    );
  }
}

/// Amount (always LTR digits) with a muted currency suffix.
class CcMoneyText extends StatelessWidget {
  const CcMoneyText(
    this.value, {
    super.key,
    this.currency,
    this.color,
    this.fontSize = 13,
    this.signed = false,
    this.textAlign,
  });

  final double? value;
  final String? currency;
  final Color? color;
  final double fontSize;
  final bool signed;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final cur = currency ?? context.l10n.egpCurrency;
    final text = signed ? CcFormat.signedMoney(value) : CcFormat.money(value);
    // Unknown figures show a bare dash, without a currency suffix.
    return LtrText(
      value == null ? text : '$text $cur',
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color ?? AppTheme.textPrimaryOf(context),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// A labelled fact (small caption above a value) for dense detail blocks.
class CcFact extends StatelessWidget {
  const CcFact({super.key, required this.label, required this.value, this.mono = false});

  final String label;
  final String value;

  /// Codes / numbers keep left-to-right order.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimaryOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
        ),
        const SizedBox(height: 2),
        mono
            ? LtrText(value, style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Text(value, style: valueStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Empty / error / loading panel: icon + message + optional action.
class CcStateView extends StatelessWidget {
  const CcStateView.empty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  })  : _loading = false,
        _error = false;

  const CcStateView.error({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  })  : icon = Icons.error_outline,
        _loading = false,
        _error = true;

  const CcStateView.loading({super.key})
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
    if (_loading) return const AppLoadingState();
    if (_error) {
      return AppErrorState(
        message: message,
        onRetry: onAction,
      );
    }
    return AppEmptyState(
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// Read-only field that opens a date picker. Value is a plain date.
class CcDateField extends StatelessWidget {
  const CcDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return AppDatePickerField(
      label: label,
      value: value,
      onChanged: (d) {
        if (d != null) onChanged(d);
      },
      firstDate: firstDate,
      lastDate: lastDate,
      allowClear: false,
    );
  }
}

/// Read-only collapsible box displaying prior clearance notes without duplicating them.
class CcPreviousNotesBox extends StatefulWidget {
  const CcPreviousNotesBox({
    super.key,
    required this.notes,
    this.initiallyExpanded = true,
  });

  final String notes;
  final bool initiallyExpanded;

  @override
  State<CcPreviousNotesBox> createState() => _CcPreviousNotesBoxState();
}

class _CcPreviousNotesBoxState extends State<CcPreviousNotesBox> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notes.trim().isEmpty) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: AppTheme.textMutedOf(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.ccPreviousNotesLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTheme.textMutedOf(context),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                widget.notes,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

