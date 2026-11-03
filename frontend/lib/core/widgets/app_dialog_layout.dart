import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 🪟 AppDialogLayout — ImportFlow ERP Standard Modal & Dialog Layout
///
/// Ensures compliance with:
/// 1. [SelectionArea] wrapper preventing Windows desktop text selection lockouts.
/// 2. WCAG-compliant responsive maxWidth constraints (400px - 1000px).
/// 3. Standardized header with icon, title, subtitle, and close button.
/// 4. Proper dark / light theme elevation and surfaces.
class AppDialogLayout extends StatelessWidget {
  const AppDialogLayout({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.child,
    this.actions,
    this.maxWidth = 640.0,
    this.maxHeight,
    this.padding = const EdgeInsets.all(20.0),
    this.showCloseButton = true,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;
  final bool showCloseButton;
  final VoidCallback? onClose;

  /// Convenience runner to open the dialog with standard constraints.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    required Widget child,
    List<Widget>? actions,
    double maxWidth = 640.0,
    double? maxHeight,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AppDialogLayout(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        actions: actions,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bg = isDark ? AppTheme.darkCardBackground : AppTheme.surface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Dialog(
      backgroundColor: bg,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: iconColor ?? AppTheme.cobalt),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showCloseButton)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'إغلاق',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: onClose ?? () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),

              // ── Content ─────────────────────────────────────────────
              Flexible(
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),

              // ── Optional Actions ────────────────────────────────────
              if (actions != null && actions!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
