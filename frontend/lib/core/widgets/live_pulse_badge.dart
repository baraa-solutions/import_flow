import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Style variants for [LivePulseBadge].
enum PulseBadgeStyle {
  /// Filled background with high contrast text.
  filled,

  /// Translucent background with colored border and text (Standard enterprise look).
  soft,

  /// Clean outlined border with transparent background.
  outlined,
}

/// Sizing options for [LivePulseBadge].
enum PulseBadgeSize {
  /// Compact height and small font for dense data tables.
  compact,

  /// Standard size for list tiles and general UI.
  regular,

  /// Larger size with prominent text for header summaries and KPI cards.
  large,
}

/// High-visibility animated badge featuring a rhythmic breathing pulse effect
/// for critical alerts, Egyptian customs ACID validity warnings, and Demurrage countdowns.
class LivePulseBadge extends StatefulWidget {
  /// Test hook to disable repeating animation controller in unit/widget tests.
  static bool enableAnimation = true;
  final String label;
  final IconData? icon;
  final Color color;
  final Color? pulseColor;
  final bool isPulsing;
  final PulseBadgeStyle style;
  final PulseBadgeSize size;
  final String? tooltip;
  final VoidCallback? onTap;
  final Widget? trailing;

  const LivePulseBadge({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.pulseColor,
    this.isPulsing = false,
    this.style = PulseBadgeStyle.soft,
    this.size = PulseBadgeSize.regular,
    this.tooltip,
    this.onTap,
    this.trailing,
  });

  /// Factory constructor for Egyptian Customs ACID validity tracking according to BP-014.
  ///
  /// - If [isCustomsReleased] is true: Neutral green released badge (suppressed alert).
  /// - If [daysRemaining] <= 0: Critical crimson pulsing red badge ("منتهي الصلاحية").
  /// - If [daysRemaining] <= 14: Vibrant crimson pulsing red badge ("يوشك على الانتهاء").
  /// - If [daysRemaining] > 14: Stable green badge ("ساري").
  factory LivePulseBadge.acid({
    Key? key,
    required int daysRemaining,
    bool isCustomsReleased = false,
    String? customLabel,
    PulseBadgeSize size = PulseBadgeSize.compact,
    VoidCallback? onTap,
  }) {
    if (isCustomsReleased) {
      return LivePulseBadge(
        key: key,
        label: customLabel ?? 'مُفرج جمركياً',
        icon: Icons.verified_outlined,
        color: AppTheme.emerald,
        isPulsing: false,
        size: size,
        onTap: onTap,
        tooltip: 'تم الإفراج الجمركي الفعلي عن البضاعة',
      );
    }

    if (daysRemaining <= 0) {
      return LivePulseBadge(
        key: key,
        label: customLabel ?? 'منتهي الصلاحية',
        icon: Icons.cancel_outlined,
        color: AppTheme.crimson,
        pulseColor: AppTheme.crimson,
        isPulsing: true,
        size: size,
        onTap: onTap,
        tooltip: 'انتهت صلاحية رقم القيد الجمركي المبدئي (ACID) ويجب تجديده فوراً',
      );
    }

    if (daysRemaining <= 14) {
      return LivePulseBadge(
        key: key,
        label: customLabel ?? 'يوشك على الانتهاء ($daysRemaining يوم)',
        icon: Icons.warning_amber_rounded,
        color: AppTheme.crimson,
        pulseColor: AppTheme.crimson,
        isPulsing: true,
        size: size,
        onTap: onTap,
        tooltip: 'تنبيه مهلة الـ 14 يوماً: متبقي $daysRemaining يوم قبل انتهاء صلاحية ACID',
      );
    }

    return LivePulseBadge(
      key: key,
      label: customLabel ?? 'ساري ($daysRemaining يوم)',
      icon: Icons.check_circle_outline_rounded,
      color: AppTheme.emerald,
      isPulsing: false,
      size: size,
      onTap: onTap,
      tooltip: 'رقم القيد الجمركي المبدئي ساري ومتبقي $daysRemaining يوم',
    );
  }

  /// Factory constructor for Port Demurrage & Container Detention monitoring.
  ///
  /// - Incurred penalty / active demurrage: Vibrant pulsing orange/amber badge.
  /// - Free days remaining <= 3: Warning pulsing orange badge.
  /// - Free time active: Stable green badge.
  factory LivePulseBadge.demurrage({
    Key? key,
    required String status,
    double accruedPenaltyEgp = 0,
    int? freeDaysRemaining,
    String? customLabel,
    PulseBadgeSize size = PulseBadgeSize.regular,
    VoidCallback? onTap,
  }) {
    final hasIncurred = accruedPenaltyEgp > 0 || status.contains('Incurred');
    final isCriticalFreeTime = freeDaysRemaining != null && freeDaysRemaining <= 3 && freeDaysRemaining >= 0;

    if (hasIncurred) {
      return LivePulseBadge(
        key: key,
        label: customLabel ?? (accruedPenaltyEgp > 0 ? 'غرامات: ${accruedPenaltyEgp.toStringAsFixed(0)} ج.م' : 'غرامات متراكمة نشطة'),
        icon: Icons.alarm_on_rounded,
        color: AppTheme.orange,
        pulseColor: AppTheme.orange,
        isPulsing: true,
        size: size,
        onTap: onTap,
        tooltip: 'تم احتساب غرامات أرضيات أو تأخير حاويات على الشحنة',
      );
    }

    if (isCriticalFreeTime) {
      return LivePulseBadge(
        key: key,
        label: customLabel ?? 'مهلة سماح حرجة ($freeDaysRemaining أيام)',
        icon: Icons.hourglass_bottom_rounded,
        color: AppTheme.orange,
        pulseColor: AppTheme.orange,
        isPulsing: true,
        size: size,
        onTap: onTap,
        tooltip: 'يوشك وقت السماح المجاني على الانتهاء',
      );
    }

    return LivePulseBadge(
      key: key,
      label: customLabel ?? 'فترة سماح سارية',
      icon: Icons.timer_outlined,
      color: AppTheme.emerald,
      isPulsing: false,
      size: size,
      onTap: onTap,
      tooltip: 'فترة السماح المجانية للنولون والأرضيات سارية',
    );
  }

  @override
  State<LivePulseBadge> createState() => _LivePulseBadgeState();
}

class _LivePulseBadgeState extends State<LivePulseBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.isPulsing && LivePulseBadge.enableAnimation) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LivePulseBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing && LivePulseBadge.enableAnimation) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final themeColor = widget.color;
    final pulseColor = widget.pulseColor ?? widget.color;

    // Dimensions based on size
    final double verticalPadding;
    final double horizontalPadding;
    final double fontSize;
    final double iconSize;
    final double dotSize;

    switch (widget.size) {
      case PulseBadgeSize.compact:
        verticalPadding = 3.0;
        horizontalPadding = 8.0;
        fontSize = 11.0;
        iconSize = 13.0;
        dotSize = 6.0;
        break;
      case PulseBadgeSize.regular:
        verticalPadding = 5.0;
        horizontalPadding = 12.0;
        fontSize = 12.5;
        iconSize = 15.0;
        dotSize = 8.0;
        break;
      case PulseBadgeSize.large:
        verticalPadding = 7.0;
        horizontalPadding = 16.0;
        fontSize = 14.0;
        iconSize = 18.0;
        dotSize = 9.0;
        break;
    }

    // Colors based on style
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    switch (widget.style) {
      case PulseBadgeStyle.filled:
        backgroundColor = themeColor;
        borderColor = themeColor;
        textColor = Colors.white;
        break;
      case PulseBadgeStyle.soft:
        backgroundColor = isDark
            ? themeColor.withValues(alpha: 0.18)
            : themeColor.withValues(alpha: 0.10);
        borderColor = isDark
            ? themeColor.withValues(alpha: 0.55)
            : themeColor.withValues(alpha: 0.40);
        textColor = isDark
            ? Color.lerp(themeColor, Colors.white, 0.35)!
            : (themeColor == AppTheme.crimson
                ? Colors.red.shade900
                : (themeColor == AppTheme.orange ? Colors.orange.shade900 : themeColor));
        break;
      case PulseBadgeStyle.outlined:
        backgroundColor = Colors.transparent;
        borderColor = themeColor;
        textColor = themeColor;
        break;
    }

    Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated Pulse Dot (when isPulsing is true)
          if (widget.isPulsing) ...[
            SizedBox(
              width: dotSize * 2.2,
              height: dotSize * 2.2,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: pulseColor.withValues(alpha: _opacityAnimation.value),
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pulseColor,
                        boxShadow: [
                          BoxShadow(
                            color: pulseColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ] else if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: iconSize,
              color: textColor,
            ),
            const SizedBox(width: 5),
          ],

          Text(
            widget.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.1,
            ),
          ),

          if (widget.trailing != null) ...[
            const SizedBox(width: 6),
            widget.trailing!,
          ],
        ],
      ),
    );

    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }

    if (widget.tooltip != null) {
      content = Tooltip(
        message: widget.tooltip!,
        child: content,
      );
    }

    return content;
  }
}
