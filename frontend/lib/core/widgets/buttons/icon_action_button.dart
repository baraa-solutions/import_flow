import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 🎯 Unified Icon Action Button for Sorour Logistics ERP data tables.
///
/// Replaces the private `_actionBtn()` method in `RowActionsPill` and any
/// similar inline icon buttons scattered in table rows.
///
/// Features:
/// - Consistent 32px touch target
/// - Hover highlight
/// - Tooltip
/// - Disabled state (null onTap)
///
/// Usage:
/// ```dart
/// IconActionButton(
///   icon: Icons.visibility,
///   color: AppTheme.cobalt,
///   tooltip: context.l10n.viewDetailsTooltip,
///   onTap: () => _openDetails(),
/// )
/// ```
class IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final String tooltip;
  final VoidCallback? onTap;
  final double iconSize;

  const IconActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
    this.backgroundColor,
    this.iconSize = 16.0,
  });

  Color _resolveBgColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;
    return color.withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: color.withValues(alpha: 0.12),
          splashColor: color.withValues(alpha: 0.16),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: onTap != null ? _resolveBgColor(context) : AppTheme.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: onTap != null ? color : AppTheme.textMutedOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-configured factory constructors for common table actions
// ─────────────────────────────────────────────────────────────────────────────

class ViewActionButton extends IconActionButton {
  const ViewActionButton({
    super.key,
    required super.tooltip,
    required super.onTap,
    super.iconSize = 16,
  }) : super(
          icon: Icons.visibility,
          color: AppTheme.cobalt,
          backgroundColor: AppTheme.cobaltLight,
        );
}

class EditActionButton extends IconActionButton {
  const EditActionButton({
    super.key,
    required super.tooltip,
    required super.onTap,
    super.iconSize = 16,
  }) : super(
          icon: Icons.edit,
          color: AppTheme.orange,
          backgroundColor: AppTheme.orangeLight,
        );
}

class PrintActionButton extends IconActionButton {
  const PrintActionButton({
    super.key,
    required super.tooltip,
    super.onTap,
    super.iconSize = 16,
  }) : super(
          icon: Icons.print,
          color: AppTheme.charcoal,
          backgroundColor: AppTheme.charcoalSurface,
        );
}

class DeleteActionButton extends IconActionButton {
  const DeleteActionButton({
    super.key,
    required super.tooltip,
    required super.onTap,
    super.iconSize = 16,
  }) : super(
          icon: Icons.delete_outline,
          color: AppTheme.crimson,
          backgroundColor: AppTheme.crimsonLight,
        );
}

class CloneActionButton extends IconActionButton {
  const CloneActionButton({
    super.key,
    required super.tooltip,
    required super.onTap,
    super.iconSize = 16,
  }) : super(
          icon: Icons.copy_rounded,
          color: AppTheme.cobalt,
          backgroundColor: AppTheme.cobaltLight,
        );
}

