import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Button variant options for Sorour Logistics ERP.
enum AppButtonVariant {
  /// Primary action (cobalt blue) — Save, Confirm, Submit
  primary,
  /// Success action (emerald green) — Save & Confirm, Final Save
  success,
  /// Danger action (crimson red) — Delete, Cancel with warning
  danger,
  /// Warning action (orange) — Import, Caution operations
  warning,
  /// Secondary / neutral (outlined) — Cancel, Close, Reset
  secondary,
  /// Ghost / transparent (outlined subtle) — Live Refresh, Back
  ghost,
  /// Save Draft (light cobalt fill with border) — Progressive save
  saveDraft,
}

/// Button size options.
enum AppButtonSize {
  small,   // 32px height
  medium,  // 40px height (default)
  large,   // 48px height
}

/// 🎯 Unified Professional Button for Sorour Logistics ERP.
///
/// Replaces all `ElevatedButton.styleFrom(...)` and `OutlinedButton.styleFrom(...)`
/// scattered across the codebase. Single source of truth for button appearance.
///
/// Features:
/// - 6 variants covering all use cases
/// - Built-in loading spinner (isLoading)
/// - Disabled state (onPressed == null or isLoading)
/// - Optional leading/trailing icon
/// - 3 sizes (small, medium, large)
/// - Tooltip support
///
/// Usage:
/// ```dart
/// AppButton(
///   label: context.l10n.save,
///   variant: AppButtonVariant.success,
///   icon: Icons.check_circle_outline,
///   isLoading: isSaving,
///   onPressed: _onSave,
/// )
/// ```
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool trailingIcon;
  final String? tooltip;

  /// When true the label is single-line with ellipsis and shrinks to the
  /// available width, so features no longer need to wrap the button in
  /// `FittedBox` / `Flexible`. Default false keeps the previous behaviour.
  final bool fit;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.trailingIcon = false,
    this.tooltip,
    this.fit = false,
  });

  // ── Size helpers ──────────────────────────────────────────────────────────

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 5);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 9);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 22, vertical: 12);
    }
  }

  /// Minimum height per size (32 / 40 / 48) so every button row lines up.
  double get _minHeight {
    switch (size) {
      case AppButtonSize.small:
        return 32;
      case AppButtonSize.medium:
        return 40;
      case AppButtonSize.large:
        return 48;
    }
  }

  /// Gap between the icon / spinner and the label.
  static const double _iconGap = 8;

  double get _fontSize {
    switch (size) {
      case AppButtonSize.small:
        return 11;
      case AppButtonSize.medium:
        return 12.5;
      case AppButtonSize.large:
        return 14;
    }
  }

  double get _iconSize {
    switch (size) {
      case AppButtonSize.small:
        return 14;
      case AppButtonSize.medium:
        return 16;
      case AppButtonSize.large:
        return 18;
    }
  }

  double get _spinnerSize {
    switch (size) {
      case AppButtonSize.small:
        return 12;
      case AppButtonSize.medium:
        return 14;
      case AppButtonSize.large:
        return 16;
    }
  }

  // ── Color / style resolver ────────────────────────────────────────────────

  _ButtonStyle _resolve(bool dark) {
    switch (variant) {
      case AppButtonVariant.primary:
        return const _ButtonStyle(
          bg: AppTheme.wcagCobalt,
          fg: Colors.white,
          border: null,
          spinnerColor: Colors.white,
        );
      case AppButtonVariant.success:
        return const _ButtonStyle(
          bg: AppTheme.wcagEmerald,
          fg: Colors.white,
          border: null,
          spinnerColor: Colors.white,
        );
      case AppButtonVariant.danger:
        return const _ButtonStyle(
          bg: AppTheme.wcagCrimson,
          fg: Colors.white,
          border: null,
          spinnerColor: Colors.white,
        );
      case AppButtonVariant.warning:
        return const _ButtonStyle(
          bg: AppTheme.wcagOrange,
          fg: Colors.white,
          border: null,
          spinnerColor: Colors.white,
        );
      case AppButtonVariant.secondary:
        return _ButtonStyle(
          bg: dark ? AppTheme.darkSurface : AppTheme.surface,
          fg: dark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          border: BorderSide(
              color: dark ? AppTheme.darkBorderLight : AppTheme.borderStrong),
          spinnerColor: dark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
        );
      case AppButtonVariant.ghost:
        return _ButtonStyle(
          bg: Colors.transparent,
          fg: dark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          border: BorderSide(
              color: dark ? AppTheme.darkBorderLight : AppTheme.borderStrong),
          spinnerColor: AppTheme.cobalt,
        );
      case AppButtonVariant.saveDraft:
        return _ButtonStyle(
          // Opaque info tint in dark mode: the translucent cobaltMedium let
          // dialog surfaces bleed through (4.2:1 on darkElevatedSurface).
          bg: AppTheme.severityBackground(AppSeverity.info, dark: dark),
          fg: dark ? AppTheme.darkHyperlink : AppTheme.wcagCobalt,
          border: const BorderSide(color: AppTheme.cobaltBorder),
          spinnerColor: AppTheme.cobalt,
        );
    }
  }


  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = _resolve(AppTheme.isDark(context));
    final bool disabled = isLoading || onPressed == null;

    final Widget spinner = SizedBox(
      width: _spinnerSize,
      height: _spinnerSize,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: s.spinnerColor,
      ),
    );

    // Disabled look: muted slate text/icon on a neutral tint (filled) or
    // transparent surface (outlined), instead of a washed-out brand colour.
    final bool filled = s.border == null && s.bg != Colors.transparent;
    final Color disabledFg = AppTheme.isDark(context)
        ? AppTheme.darkTextMuted
        : const Color(0xFF94A3B8);
    // While loading the button keeps its colour so the spinner stays visible.
    final Color contentColor =
        (onPressed == null && !isLoading) ? disabledFg : s.fg;

    final Widget iconWidget = Icon(icon, size: _iconSize, color: contentColor);

    // With [fit] the label shrinks (single line + ellipsis) to whatever width
    // the parent offers instead of overflowing the button's Row.
    final Widget labelText = Text(
      label,
      maxLines: fit ? 1 : null,
      overflow: fit ? TextOverflow.ellipsis : null,
      softWrap: fit ? false : null,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: _fontSize,
        color: contentColor,
        letterSpacing: 0,
      ),
    );
    final Widget labelWidget = fit ? Flexible(child: labelText) : labelText;

    Widget content;
    if (icon != null) {
      final leading = isLoading ? spinner : (trailingIcon ? null : iconWidget);
      final trailing = trailingIcon ? (isLoading ? spinner : iconWidget) : null;

      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: _iconGap)],
          labelWidget,
          if (trailing != null) ...[const SizedBox(width: _iconGap), trailing],
        ],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading) ...[spinner, const SizedBox(width: _iconGap)],
          labelWidget,
        ],
      );
    }

    // Without [fit], a button squeezed narrower than its natural width (an
    // Expanded slot on a phone-width layout) scales its content down instead
    // of overflowing. Unconstrained it lays out exactly as before, and it
    // never asks for a bounded width (safe in scroll views / unbounded Rows).
    if (!fit) {
      content = FittedBox(fit: BoxFit.scaleDown, child: content);
    }

    final ButtonStyle buttonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          if (isLoading) return s.bg; // keep brand colour while busy
          if (s.bg == Colors.transparent) return Colors.transparent;
          return filled
              ? (AppTheme.isDark(context)
                  ? AppTheme.darkBorder
                  : const Color(0xFFE2E8F0))
              : s.bg.withValues(alpha: 0.6);
        }
        return s.bg;
      }),
      foregroundColor: WidgetStateProperty.all(s.fg),
      padding: WidgetStateProperty.all(_padding),
      minimumSize: WidgetStateProperty.all(Size(0, _minHeight)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shadowColor: WidgetStateProperty.all(const Color(0x401E293B)),
      surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      ),
      side: s.border != null
          ? WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return BorderSide(
                    color: s.border!.color.withValues(alpha: 0.5));
              }
              if (states.contains(WidgetState.focused)) {
                return BorderSide(color: s.border!.color, width: 1.6);
              }
              return s.border;
            })
          : null,
      elevation: WidgetStateProperty.resolveWith((states) {
        if (s.bg == Colors.transparent || s.border != null) return 0;
        if (states.contains(WidgetState.disabled)) return 0;
        if (states.contains(WidgetState.pressed)) return 0;
        if (states.contains(WidgetState.hovered)) return 2;
        return 1;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return (filled ? Colors.white : s.fg).withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered)) {
          return (filled ? Colors.white : s.fg).withValues(alpha: 0.08);
        }
        return null;
      }),
    );

    Widget btn = ElevatedButton(
      style: buttonStyle,
      onPressed: disabled ? null : onPressed,
      child: content,
    );

    if (tooltip != null) {
      btn = Tooltip(message: tooltip!, child: btn);
    }

    return btn;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal style data class
// ─────────────────────────────────────────────────────────────────────────────

class _ButtonStyle {
  final Color bg;
  final Color fg;
  final BorderSide? border;
  final Color spinnerColor;

  const _ButtonStyle({
    required this.bg,
    required this.fg,
    required this.border,
    required this.spinnerColor,
  });
}
