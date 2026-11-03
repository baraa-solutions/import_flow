import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';

/// Thin feature-local composition over core tokens for the import-documentation
/// screens (same idea as `CcUi` / `FinancialUi`): status chips, section cards,
/// facts, banners, empty / error / loading panels and a dialog frame.
/// Colours come only from [AppTheme]; no behaviour lives here.
class IdocUi {
  IdocUi._();

  /// Lets a (non-flexible) AppButton shrink instead of overflowing.
  static Widget fit(Widget button) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.center,
        child: button,
      );

  /// Shared [MetricCardStrip] on wide layouts; a wrapped grid of
  /// [MetricCard]s when the width is too small for one row. Keep values short.
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

  /// Section / sub-section heading text style.
  static TextStyle sectionTitle(BuildContext context) => TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryOf(context),
      );

  /// Small caption (labels, hints).
  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 11.5,
        color: AppTheme.textSecondaryOf(context),
      );

  /// Matching / review state of a session or a line -> chip style. Accepts the
  /// backend codes in any case (`FULLY_MATCHED`, `Match`, `Draft`, `Final`,
  /// `Approved`, `Pending`, `Rejected`, `Mismatch` ...). Unknown values keep
  /// their raw text with a neutral (info) look.
  static ({AppSeverity severity, IconData icon}) severityOfStatus(
      String status) {
    final s = status.trim().toLowerCase().replaceAll('_', ' ');
    if (s.contains('mismatch') ||
        s.contains('not matched') ||
        s.contains('reject') ||
        s.contains('fail') ||
        s.contains('missing') ||
        s.contains('critical')) {
      return (severity: AppSeverity.danger, icon: Icons.cancel_outlined);
    }
    if (s.contains('partial') ||
        s.contains('warning') ||
        s.contains('pending') ||
        s.contains('review') ||
        s.contains('minor')) {
      return (severity: AppSeverity.warning, icon: Icons.error_outline);
    }
    if (s.contains('match') ||
        s.contains('approved') ||
        s.contains('final') ||
        s.contains('complete') ||
        s.contains('certified') ||
        s.contains('received') ||
        s.contains('ok')) {
      return (
        severity: AppSeverity.success,
        icon: Icons.check_circle_outline
      );
    }
    return (severity: AppSeverity.info, icon: Icons.info_outline);
  }
}

/// Coloured pill: draft / approved / matched / mismatch ... One look everywhere.
class IdocStatusChip extends StatelessWidget {
  const IdocStatusChip({
    super.key,
    required this.label,
    required this.severity,
    this.icon,
  });

  /// Derives severity and icon from a raw backend status string.
  factory IdocStatusChip.fromStatus(String status, {Key? key, String? label}) {
    final style = IdocUi.severityOfStatus(status);
    return IdocStatusChip(
      key: key,
      label: label ?? status,
      severity: style.severity,
      icon: style.icon,
    );
  }

  final String label;
  final AppSeverity severity;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
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
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titled card used to group related fields / facts (consistent spacing,
/// border and radius from [AppTheme]).
class IdocSectionCard extends StatelessWidget {
  const IdocSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.accent,
    this.margin = const EdgeInsetsDirectional.only(bottom: 12),
    this.padding = const EdgeInsetsDirectional.all(14),
  });

  final String title;
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
      margin: margin,
      padding: padding,
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
                  style: IdocUi.sectionTitle(context),
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

/// A labelled fact (small caption above a value) for dense detail blocks.
class IdocFact extends StatelessWidget {
  const IdocFact({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
  });

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
          style: IdocUi.caption(context),
        ),
        const SizedBox(height: 2),
        mono
            ? LtrText(value,
                style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Text(value,
                style: valueStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Inline severity banner (icon + message + optional trailing action) used for
/// warnings such as unmatched results, missing data, locked sessions.
class IdocBanner extends StatelessWidget {
  const IdocBanner({
    super.key,
    required this.message,
    this.severity = AppSeverity.info,
    this.icon,
    this.title,
    this.trailing,
    this.margin = const EdgeInsetsDirectional.only(bottom: 12),
  });

  final String message;
  final String? title;
  final AppSeverity severity;
  final IconData? icon;
  final Widget? trailing;
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
      margin: margin,
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(fontSize: 12, color: fg, height: 1.4),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Empty / error / loading panel: icon + message + optional action.
class IdocStateView extends StatelessWidget {
  const IdocStateView.empty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.hint,
    this.actionLabel,
    this.onAction,
  })  : _loading = false,
        _error = false;

  const IdocStateView.error({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  })  : icon = Icons.error_outline,
        hint = null,
        _loading = false,
        _error = true;

  const IdocStateView.loading({super.key})
      : message = '',
        icon = Icons.hourglass_empty,
        hint = null,
        actionLabel = null,
        onAction = null,
        _loading = true,
        _error = false;

  final String message;
  final String? hint;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool _loading;
  final bool _error;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final color = _error ? AppTheme.crimson : AppTheme.textMutedOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsetsDirectional.all(18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 14),
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
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: IdocUi.caption(context),
              ),
            ],
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

/// Header chip (icon + label) shown in the dark header of [IdocDialogShell].
class IdocHeaderChip {
  const IdocHeaderChip(this.icon, this.label, {this.ltr = false});

  final IconData icon;
  final String label;

  /// Codes / numbers keep left-to-right order inside the RTL header.
  final bool ltr;
}

/// Shared frame of the import-documentation dialogs: charcoal header (icon,
/// title, chips, close), scrollable body and the standard footer with a
/// neutral cancel plus one primary action that shows an in-button spinner.
class IdocDialogShell extends StatelessWidget {
  const IdocDialogShell({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.confirmLabel,
    this.onConfirm,
    this.isSubmitting = false,
    this.accent = AppTheme.cobalt,
    this.chips = const [],
    this.confirmIcon = Icons.check_circle_rounded,
    this.confirmVariant = AppButtonVariant.success,
    this.maxWidth = 880,
    this.headerActions = const [],
    this.footerLeading,
    this.onCancel,
    this.cancelLabel,
    this.scrollBody = true,
  });

  final String title;
  final IconData icon;
  final Widget body;

  /// When null the footer only shows the close button (read-only dialogs).
  final String? confirmLabel;
  final VoidCallback? onConfirm;
  final bool isSubmitting;
  final Color accent;
  final List<IdocHeaderChip> chips;
  final IconData confirmIcon;
  final AppButtonVariant confirmVariant;
  final double maxWidth;
  final List<Widget> headerActions;
  final Widget? footerLeading;
  final VoidCallback? onCancel;
  final String? cancelLabel;

  /// Set to false when [body] manages its own scrolling (lists, tabs).
  final bool scrollBody;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screen = MediaQuery.of(context).size;
    final dialogWidth =
        screen.width > maxWidth + 40 ? maxWidth : screen.width * 0.95;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SelectionArea(
        child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screen.height * 0.90),
        child: Column(
          children: [
            _header(context, l),
            Expanded(
              child: scrollBody
                  ? SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.all(20),
                      child: body,
                    )
                  : Padding(
                      padding: const EdgeInsetsDirectional.all(20),
                      child: body,
                    ),
            ),
            _footer(context, l),
          ],
        ),
      ),
      ),
    );
  }

  void _close(BuildContext context) {
    if (onCancel != null) {
      onCancel!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _header(BuildContext context, AppLocalizations l) {
    final onDark = AppTheme.white.withValues(alpha: 0.78);
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 14),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final c in chips)
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.icon, size: 12, color: onDark),
                              const SizedBox(width: 4),
                              c.ltr
                                  ? LtrText(c.label,
                                      style: TextStyle(
                                          fontSize: 11, color: onDark))
                                  : Text(c.label,
                                      style: TextStyle(
                                          fontSize: 11, color: onDark)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ...headerActions,
          IconButton(
            tooltip: l.close,
            icon: const Icon(Icons.close, color: AppTheme.white),
            onPressed: () => _close(context),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, AppLocalizations l) {
    return Container(
      padding:
          const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(AppTheme.radiusXl),
          bottomEnd: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Row(
        children: [
          if (footerLeading != null) Expanded(child: footerLeading!),
          if (footerLeading == null) const Spacer(),
          AppButton(
            label: cancelLabel ?? (confirmLabel == null ? l.close : l.cancel),
            variant: AppButtonVariant.secondary,
            onPressed: isSubmitting ? null : () => _close(context),
          ),
          if (confirmLabel != null) ...[
            const SizedBox(width: 10),
            AppButton(
              label: confirmLabel!,
              variant: confirmVariant,
              icon: confirmIcon,
              isLoading: isSubmitting,
              onPressed: onConfirm,
            ),
          ],
        ],
      ),
    );
  }
}
