import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/density_provider.dart';

/// Standard, reusable Page Header for ImportFlow ERP screens (Type B List/Index & Master screens).
///
/// Features:
/// - Replaces ad-hoc local AppBars and custom gradient containers.
/// - Uses uniform solid dark charcoal [AppTheme.charcoal] (or dark mode [Color(0xFF141A22)]).
/// - Automatically scales font sizes, paddings, and heights with [displayDensityProvider].
/// - Implements [PreferredSizeWidget] so it can be passed directly to `Scaffold.appBar`
///   or placed as the first widget in a `Column`.
class PageHeader extends ConsumerWidget implements PreferredSizeWidget {
  /// Minimum width reserved for the title block when actions are wide.
  static const double _minTitleWidth = 240.0;

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;
  final double elevation;

  const PageHeader({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.elevation = 0.0,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null && subtitle!.isNotEmpty ? 66.0 : 54.0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDark ? const Color(0xFF141A22) : AppTheme.charcoal);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.black12,
            width: 1.0,
          ),
        ),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: density.headerPadding.left,
        vertical: hasSubtitle ? 2.5 : 3.5,
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, headerConstraints) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 8),
                  ],
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: iconColor ?? AppTheme.cobalt,
                      size: density.headerIconSize,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: density.headerTitleFontSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                            height: 1.1,
                          ),
                          softWrap: true,
                          maxLines: 2,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: density.headerSubtitleFontSize,
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(width: 8),
              // PageHeader is used as Scaffold.appBar with a fixed preferredSize, so actions
              // cannot wrap to a second row. When they exceed the cap (title keeps at least
              // [_minTitleWidth]) they scroll horizontally with an always-visible scrollbar.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: headerConstraints.maxWidth.isFinite
                      ? (headerConstraints.maxWidth - _minTitleWidth).clamp(0.0, double.infinity)
                      : double.infinity,
                ),
                child: _HeaderActionsStrip(actions: actions!),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

/// Horizontal actions strip for [PageHeader]; shows a visible scrollbar when the actions
/// are wider than the space available, so no action is silently hidden.
class _HeaderActionsStrip extends StatefulWidget {
  const _HeaderActionsStrip({required this.actions});

  final List<Widget> actions;

  @override
  State<_HeaderActionsStrip> createState() => _HeaderActionsStripState();
}

class _HeaderActionsStripState extends State<_HeaderActionsStrip> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      thickness: 3,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: widget.actions,
        ),
      ),
    );
  }
}
