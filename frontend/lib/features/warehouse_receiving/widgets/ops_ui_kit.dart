import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';

/// Small presentation kit shared by the warehouse-receiving, inland-transport
/// and file-closure screens (phase 8-10). Only theme tokens are used: no raw
/// colours, direction-aware paddings, dark-mode aware.

/// A consistent coloured status chip (tinted background, strong foreground).
class OpsStatusChip extends StatelessWidget {
  const OpsStatusChip({
    super.key,
    required this.label,
    required this.severity,
    this.icon,
    this.dense = false,
  });

  final String label;
  final AppSeverity severity;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    return Container(
      padding: EdgeInsetsDirectional.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
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
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A neutral (non-severity) chip used for codes and secondary tags.
class OpsTagChip extends StatelessWidget {
  const OpsTagChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.textSecondaryOf(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled card that groups related content (section header + body).
class OpsSectionCard extends StatelessWidget {
  const OpsSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsetsDirectional.all(16),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          OpsSectionHeader(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor, trailing: trailing),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Section title row: tinted icon tile, title (+ optional subtitle), trailing widget.
class OpsSectionHeader extends StatelessWidget {
  const OpsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppTheme.cobalt;
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsetsDirectional.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Label above value pair, used in aligned detail grids.
class OpsLabeledValue extends StatelessWidget {
  const OpsLabeledValue({super.key, required this.label, required this.value, this.valueWidget});

  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        valueWidget ??
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context)),
            ),
      ],
    );
  }
}

/// A prominent info / warning banner with an optional action area.
class OpsInfoBanner extends StatelessWidget {
  const OpsInfoBanner({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.info_outline,
    this.severity = AppSeverity.info,
    this.actions,
  });

  final String title;
  final String? message;
  final IconData icon;
  final AppSeverity severity;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          final text = Row(
            children: [
              Icon(icon, color: fg, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryOf(context))),
                    if (message != null) ...[
                      const SizedBox(height: 2),
                      Text(message!, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context))),
                    ],
                  ],
                ),
              ),
            ],
          );
          if (actions == null) return text;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 10), actions!],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 16),
              Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: actions)),
            ],
          );
        },
      ),
    );
  }
}

/// Empty / error / loading state: icon, message and an optional action.
class OpsStateView extends StatelessWidget {
  const OpsStateView({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.severity = AppSeverity.info,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  });

  /// Empty-result state (soft cobalt icon).
  const OpsStateView.empty({
    Key? key,
    required String message,
    String? title,
    IconData icon = Icons.inbox_outlined,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
    bool compact = false,
  }) : this(
          key: key,
          icon: icon,
          message: message,
          title: title,
          severity: AppSeverity.info,
          actionLabel: actionLabel,
          actionIcon: actionIcon,
          onAction: onAction,
          compact: compact,
        );

  /// Error state (danger icon, retry action).
  const OpsStateView.error({
    Key? key,
    required String message,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    bool compact = false,
  }) : this(
          key: key,
          icon: Icons.error_outline,
          message: message,
          title: title,
          severity: AppSeverity.danger,
          actionLabel: actionLabel,
          actionIcon: Icons.refresh,
          onAction: onAction,
          compact: compact,
        );

  final IconData icon;
  final String? title;
  final String message;
  final AppSeverity severity;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(compact ? 16 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 44 : 60,
                height: compact ? 44 : 60,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: fg, size: compact ? 22 : 30),
              ),
              const SizedBox(height: 12),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context)),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryOf(context)),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                AppButton(
                  label: actionLabel!,
                  icon: actionIcon,
                  size: AppButtonSize.small,
                  variant: severity == AppSeverity.danger ? AppButtonVariant.secondary : AppButtonVariant.primary,
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

/// Centered progress indicator with an optional caption.
class OpsLoadingView extends StatelessWidget {
  const OpsLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context))),
          ],
        ],
      ),
    );
  }
}

/// Shared table styling: heading colour, row heights and number alignment.
class OpsTableStyle {
  const OpsTableStyle._();

  static WidgetStateProperty<Color?> headingColor(BuildContext context) =>
      WidgetStateProperty.all(AppTheme.surfaceAltOf(context));

  static TextStyle headingStyle(BuildContext context) => TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimaryOf(context),
      );

  static const double rowMinHeight = 44;
  static const double rowMaxHeight = 56;
  static const double headingHeight = 42;

  /// Heading cell for a data column.
  static Widget heading(BuildContext context, String text) =>
      Text(text, style: headingStyle(context));
}

/// Scales a button down instead of overflowing when its label is wider than the
/// space the parent offers (narrow windows, long Arabic labels).
class OpsFit extends StatelessWidget {
  const OpsFit({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity),
        child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: child),
      ),
    );
  }
}

/// A [Wrap] for action buttons: every child is wrapped in [OpsFit] so a long
/// label never overflows, with the standard 8px gap.
class OpsActionWrap extends StatelessWidget {
  const OpsActionWrap({
    super.key,
    required this.children,
    this.alignment = WrapAlignment.start,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final List<Widget> children;
  final WrapAlignment alignment;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final c in children) OpsFit(child: c)],
    );
  }
}
