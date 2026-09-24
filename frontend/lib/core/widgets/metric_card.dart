import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/density_provider.dart';
import 'copyable_data_helper.dart';

/// Data model for a single metric / stat card.
class MetricCardData {
  final String title;
  final String? shortTitle;
  final String value;
  final IconData icon;
  final Color color;
  final String? tooltip;
  final VoidCallback? onTap;

  const MetricCardData({
    required this.title,
    this.shortTitle,
    required this.value,
    required this.icon,
    required this.color,
    this.tooltip,
    this.onTap,
  });

  /// Default short label mapping per Design System addition:
  /// | Full label | Short label |
  /// | Total POs | POs |
  /// | Total PI/PO Amount | PI/PO Amt |
  /// | Total Cargo CBM | CBM |
  /// | Total Gross Weight | Gross Wt |
  static String defaultShortLabel(String fullLabel) {
    final t = fullLabel.trim();
    if (t == 'Total POs' || t == 'أوامر الشراء' || t.contains('أوامر الشراء')) return 'POs';
    if (t == 'Total PI/PO Amount' || t == 'إجمالي القيمة' || t.contains('إجمالي القيمة') || t.contains('إجمالي المبلغ')) return 'PI/PO Amt';
    if (t == 'Total Cargo CBM' || t.contains('CBM') || t.contains('الحجم الإجمالي')) return 'CBM';
    if (t == 'Total Gross Weight' || t.contains('Gross Weight') || t.contains('الوزن الإجمالي')) return 'Gross Wt';
    if (t == 'Total Shipments' || t.contains('إجمالي الشحنات')) return 'Shipments';
    if (t == 'Total FOB Value' || t.contains('قيمة FOB الإجمالية')) return 'FOB Val';
    return t;
  }

  /// Computes the effective title depending on density or forced short mode.
  String effectiveTitle(DisplayDensityMode density, {bool forceShort = false}) {
    if (forceShort || density == DisplayDensityMode.compact || density == DisplayDensityMode.ultraCompact) {
      if (shortTitle != null && shortTitle!.isNotEmpty) {
        return shortTitle!;
      }
      return defaultShortLabel(title);
    }
    return title;
  }
}

/// Reusable Metric Item displaying [icon] label: value horizontally inline.
/// Automatically scales padding, icon sizes, and font sizes with [displayDensityProvider].
/// Preserves full numeric value without truncation, switching only label to short form.
class MetricCard extends ConsumerWidget {
  final MetricCardData data;
  final bool forceShort;

  const MetricCard({
    super.key,
    required this.data,
    this.forceShort = false,
  });

  /// Width kept free for the gap between the icon and the title.
  static const double _valueReserve = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = data.effectiveTitle(density, forceShort: forceShort);

    final content = InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: density.metricCardPadding,
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                data.icon,
                color: data.color,
                size: density.metricIconSize,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  displayTitle,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                    fontSize: density.metricTitleFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // The numeric VALUE is preserved in full and never truncated: when the card is
              // narrower than icon + value, ': value' scales down instead of overflowing.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth.isFinite
                      ? (constraints.maxWidth - density.metricIconSize - _valueReserve).clamp(0.0, double.infinity)
                      : double.infinity,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ': ',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                          fontSize: density.metricTitleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      CopyableText(
                        data.value,
                        showIcon: false,
                        style: TextStyle(
                          fontSize: density.metricValueFontSize,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (data.tooltip != null && data.tooltip!.isNotEmpty) {
      return Tooltip(message: data.tooltip!, child: content);
    }
    return content;
  }
}

/// Reusable Single-Row Compact Strip of Metrics.
///
/// Layout Rules:
/// - All metrics in ONE row, side by side, inside a single thin-bordered container with vertical dividers.
/// - Inline layout: [icon] label: value (~40-44px tall at Comfortable).
/// - Dynamically shrinks under [DisplayDensityMode.compact] (~34px) and [DisplayDensityMode.ultraCompact] (~28px).
/// - Switches to short labels (POs, PI/PO Amt, CBM, Gross Wt) under Compact/Ultra-Compact or when space is tight.
/// - The numeric VALUE is never truncated.
/// - If even the short label + value doesn't fit, wraps the strip to 2 rows (2 metrics per row) rather than cutting text.
class MetricCardStrip extends ConsumerWidget {
  final List<MetricCardData> metrics;
  final EdgeInsets? padding;

  const MetricCardStrip({
    super.key,
    required this.metrics,
    this.padding,
  });

  Widget _buildSingleStrip(
    BuildContext context,
    List<MetricCardData> items,
    DisplayDensityMode density,
    bool isDark, {
    bool forceShort = false,
  }) {
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return Container(
      height: density.metricCardHeight,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: density == DisplayDensityMode.ultraCompact ? 3 : 5,
                endIndent: density == DisplayDensityMode.ultraCompact ? 3 : 5,
                color: borderColor,
              ),
            Expanded(
              child: Center(
                child: MetricCard(data: items[i], forceShort: forceShort),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectivePadding = padding ??
        (density == DisplayDensityMode.ultraCompact
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 2)
            : density == DisplayDensityMode.compact
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 3)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 4));

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        // Each metric inline requires at least ~165px to comfortably show (icon + short label + ': ' + value + padding).
        // For 4 metrics, minimum comfortable single-row width is 4 * 165 = 660px.
        // Wrap to 2 rows (2 metrics per row) if available width < 660px, or on narrow screens (< 700px when 4 metrics)
        final minComfortableSingleRowWidth = metrics.length * 165.0;
        final shouldWrapToTwoRows = metrics.length > 2 && (w < minComfortableSingleRowWidth || w < 660.0);

        if (shouldWrapToTwoRows) {
          final mid = (metrics.length / 2).ceil();
          final row1 = metrics.sublist(0, mid);
          final row2 = metrics.sublist(mid);

          return Padding(
            padding: effectivePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSingleStrip(context, row1, density, isDark, forceShort: true),
                const SizedBox(height: 4),
                _buildSingleStrip(context, row2, density, isDark, forceShort: true),
              ],
            ),
          );
        }

        // Standard: Single-row strip. Switch to short labels if space is tight (< 210px per item) or in compact/ultraCompact.
        final isTight = w < (metrics.length * 210.0);
        return Padding(
          padding: effectivePadding,
          child: _buildSingleStrip(context, metrics, density, isDark, forceShort: isTight),
        );
      },
    );
  }
}
