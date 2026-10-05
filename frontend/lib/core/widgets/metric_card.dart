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

/// Builds [builder] with the current [displayDensityProvider] value when a
/// ProviderScope is present, otherwise with the provider's initial value
/// ([DisplayDensityMode.comfortable]). Lets the metric widgets render in plain
/// widget trees (feature widget tests, dialogs pumped without a scope).
Widget _withDensity(
  BuildContext context,
  Widget Function(BuildContext context, DisplayDensityMode density) builder,
) {
  final hasScope = context
          .getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>() !=
      null;
  if (!hasScope) return builder(context, DisplayDensityMode.comfortable);
  return Consumer(
    builder: (context, ref, _) =>
        builder(context, ref.watch(displayDensityProvider)),
  );
}

/// Reusable Metric Item displaying [icon] label: value horizontally inline.
/// Automatically scales padding, icon sizes, and font sizes with [displayDensityProvider].
/// Preserves full numeric value without truncation, switching only label to short form.
class MetricCard extends StatelessWidget {
  final MetricCardData data;
  final bool forceShort;

  const MetricCard({
    super.key,
    required this.data,
    this.forceShort = false,
  });

  /// Gap between the icon chip and the title.
  static const double _iconGap = 8.0;

  @override
  Widget build(BuildContext context) => _withDensity(context, _build);

  Widget _build(BuildContext context, DisplayDensityMode density) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = data.effectiveTitle(density, forceShort: forceShort);
    final chipPadding = density.isUltraCompact ? 2.0 : 3.5;
    // Full horizontal footprint of the icon chip + the gap that follows it.
    final leadingWidth = density.metricIconSize + chipPadding * 2 + _iconGap;

    final content = InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      hoverColor: data.onTap != null ? data.color.withValues(alpha: 0.06) : Colors.transparent,
      child: Padding(
        padding: density.metricCardPadding,
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon chip: tinted rounded square keyed to the metric colour.
              Container(
                padding: EdgeInsets.all(chipPadding),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: density.metricIconSize,
                ),
              ),
              const SizedBox(width: _iconGap),
              Flexible(
                child: Text(
                  displayTitle,
                  style: TextStyle(
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: density.metricTitleFontSize,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
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
                      ? (constraints.maxWidth - leadingWidth).clamp(0.0, double.infinity)
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
                          color: AppTheme.textSecondaryOf(context),
                          fontSize: density.metricTitleFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      CopyableText(
                        data.value,
                        showIcon: false,
                        style: TextStyle(
                          fontSize: density.metricValueFontSize,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryOf(context),
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
class MetricCardStrip extends StatelessWidget {
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
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Container(
      height: density.metricCardHeight,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                    color: Color(0x081E293B), blurRadius: 6, offset: Offset(0, 2)),
              ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: density == DisplayDensityMode.ultraCompact ? 5 : 8,
                endIndent: density == DisplayDensityMode.ultraCompact ? 5 : 8,
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
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return _withDensity(context, _build);
  }

  Widget _build(BuildContext context, DisplayDensityMode density) {
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
