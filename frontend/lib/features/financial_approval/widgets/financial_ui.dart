import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

/// Thin feature-local composition over core tokens: maps a payment / budget
/// status to an [AppSeverity] chip and offers one empty / error / loading
/// panel. Colours come only from [AppTheme]; no behaviour lives here.
class FinancialUi {
  FinancialUi._();

  /// Lets a (non-flexible) AppButton shrink instead of overflowing when the
  /// available width is narrower than its label.
  static Widget fit(Widget button) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.center,
        child: button,
      );

  /// Shared [MetricCardStrip] on wide layouts; a 2-column grid of shared
  /// [MetricCard]s when the width is too small for a single row.
  static Widget metrics(List<MetricCardData> data) => LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 760) return MetricCardStrip(metrics: data);
          final w = c.maxWidth >= 520 ? (c.maxWidth - 8) / 2 : c.maxWidth;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in data)
                SizedBox(
                    width: w, child: MetricCard(data: m, forceShort: true)),
            ],
          );
        },
      );

  static const String advancePaymentCode = 'ADVANCE_PAYMENT';

  static const List<String> paymentTypeCodes = [
    'ADVANCE_PAYMENT',
    'AGAINST_BL',
    'LETTER_OF_CREDIT',
    'DOCUMENTARY_COLLECTION',
    'FINAL_SETTLEMENT',
  ];

  static const Map<String, String> _legacyPaymentTypes = {
    'advance payment': 'ADVANCE_PAYMENT',
    'against b/l': 'AGAINST_BL',
    'letter of credit (l/c)': 'LETTER_OF_CREDIT',
    'documentary collection (cad)': 'DOCUMENTARY_COLLECTION',
    'final settlement': 'FINAL_SETTLEMENT',
  };

  /// Maps a stored payment type (code or legacy English label) to its code;
  /// anything unknown falls back to ADVANCE_PAYMENT.
  static String normalizePaymentType(String? raw) {
    final v = (raw ?? '').trim();
    if (paymentTypeCodes.contains(v)) return v;
    return _legacyPaymentTypes[v.toLowerCase()] ?? advancePaymentCode;
  }

  static String paymentTypeLabel(AppLocalizations l, String code) {
    switch (code) {
      case 'AGAINST_BL':
        return l.faPaymentTypeAgainstBl;
      case 'LETTER_OF_CREDIT':
        return l.faPaymentTypeLetterOfCredit;
      case 'DOCUMENTARY_COLLECTION':
        return l.faPaymentTypeDocumentaryCollection;
      case 'FINAL_SETTLEMENT':
        return l.faPaymentTypeFinalSettlement;
      default:
        return l.faPaymentTypeAdvance;
    }
  }

  static List<SearchableDropdownItem<String>> paymentTypeItems(
          AppLocalizations l) =>
      [
        for (final c in paymentTypeCodes)
          SearchableDropdownItem<String>(
              value: c, label: paymentTypeLabel(l, c)),
      ];

  static ({AppSeverity severity, String label}) statusStyle(
      AppLocalizations l, String status) {
    final s = status.toLowerCase();
    if (s == 'paid') {
      return (severity: AppSeverity.success, label: l.paidStatus);
    }
    if (s == 'reconciled') {
      return (severity: AppSeverity.info, label: l.reconciledStatus);
    }
    if (s.contains('approved')) {
      return (severity: AppSeverity.success, label: l.statusApproved);
    }
    if (s.contains('pending')) {
      return (severity: AppSeverity.warning, label: l.statusPendingReview);
    }
    if (s.contains('draft')) {
      return (severity: AppSeverity.info, label: l.draftStatus);
    }
    return (severity: AppSeverity.info, label: status);
  }
}

/// Consistent coloured status chip (draft / pending / approved / paid / ...).
class FinancialStatusChip extends StatelessWidget {
  const FinancialStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = FinancialUi.statusStyle(context.l10n, status);
    final fg = AppTheme.severityForegroundOf(context, style.severity);
    final bg = AppTheme.severityBackgroundOf(context, style.severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        style.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Empty / error / loading panel: icon + message + optional action.
class FinancialStateView extends StatelessWidget {
  const FinancialStateView.empty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  })  : _loading = false,
        _error = false;

  const FinancialStateView.error({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  })  : icon = Icons.error_outline,
        _loading = false,
        _error = true;

  const FinancialStateView.loading({super.key})
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
      return const AppLoadingState();
    }
    final color = _error ? AppTheme.crimson : AppTheme.textMuted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _error
                    ? AppTheme.crimson
                    : AppTheme.textSecondaryOf(context),
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
