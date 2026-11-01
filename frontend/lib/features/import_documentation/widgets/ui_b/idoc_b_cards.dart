import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

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
