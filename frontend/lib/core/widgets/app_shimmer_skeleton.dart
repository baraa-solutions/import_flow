import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Data passed down the widget tree by [AppShimmerEffect] to synchronize animations.
class _ShimmerScopeData extends InheritedWidget {
  final double animationValue;
  final bool isDark;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerScopeData({
    required this.animationValue,
    required this.isDark,
    required this.baseColor,
    required this.highlightColor,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ShimmerScopeData oldWidget) =>
      animationValue != oldWidget.animationValue ||
      isDark != oldWidget.isDark ||
      baseColor != oldWidget.baseColor ||
      highlightColor != oldWidget.highlightColor;
}

/// Orchestrates an animated shimmer gradient for all descendant [ShimmerBox]es.
/// Synchronizes a smooth 1400ms easeInOutSine pulse across complex layouts.
class AppShimmerEffect extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const AppShimmerEffect({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<AppShimmerEffect> createState() => _AppShimmerEffectState();
}

class _AppShimmerEffectState extends State<AppShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final defaultBase = isDark
        ? AppTheme.darkSurface // 0xFF242E3D
        : const Color(0xFFE2E8F0);
    final defaultHighlight = isDark
        ? AppTheme.darkBorderLight // 0xFF3E4E63
        : const Color(0xFFF8FAFC);

    final effectiveBase = widget.baseColor ?? defaultBase;
    final effectiveHighlight = widget.highlightColor ?? defaultHighlight;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return _ShimmerScopeData(
          animationValue: _animation.value,
          isDark: isDark,
          baseColor: effectiveBase,
          highlightColor: effectiveHighlight,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

/// A theme-adaptive animated placeholder container.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;
  final Color? baseColor;
  final Color? highlightColor;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 6.0,
    this.shape = BoxShape.rectangle,
    this.baseColor,
    this.highlightColor,
    this.margin,
  });

  const ShimmerBox.circle({
    super.key,
    required double size,
    this.baseColor,
    this.highlightColor,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShimmerScopeData>();
    final isDark = scope?.isDark ?? AppTheme.isDark(context);

    final base = baseColor ?? scope?.baseColor ?? (isDark ? AppTheme.darkSurface : const Color(0xFFE2E8F0));
    final highlight = highlightColor ?? scope?.highlightColor ?? (isDark ? AppTheme.darkBorderLight : const Color(0xFFF8FAFC));
    final animVal = scope?.animationValue ?? 0.5;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          stops: [
            (animVal - 0.3).clamp(0.0, 1.0),
            animVal.clamp(0.0, 1.0),
            (animVal + 0.3).clamp(0.0, 1.0),
          ],
          colors: [
            base,
            highlight,
            base,
          ],
        ),
      ),
    );
  }
}

/// Skeleton shimmer representation of the Executive KPI Cards row on the Dashboard.
class DashboardKpiShimmerSkeleton extends StatelessWidget {
  final int cardCount;

  const DashboardKpiShimmerSkeleton({
    super.key,
    this.cardCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return AppShimmerEffect(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(cardCount, (index) {
          return SizedBox(
            width: 220,
            child: Card(
              elevation: 2,
              color: isDark ? AppTheme.darkCardBackground : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 110, height: 12),
                        ShimmerBox(width: 30, height: 30, borderRadius: 6),
                      ],
                    ),
                    SizedBox(height: 12),
                    ShimmerBox(width: 80, height: 20),
                    SizedBox(height: 8),
                    ShimmerBox(width: 140, height: 10),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Skeleton shimmer representation of a single shipment card.
class ShipmentCardShimmerSkeleton extends StatelessWidget {
  const ShipmentCardShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? AppTheme.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Shipment Name, Code Badge, Route, Priority, Copy
            const Row(
              children: [
                ShimmerBox(width: 130, height: 16),
                SizedBox(width: 8),
                ShimmerBox(width: 80, height: 18, borderRadius: 6),
                SizedBox(width: 10),
                ShimmerBox(width: 120, height: 14),
                SizedBox(width: 8),
                ShimmerBox(width: 100, height: 14),
                Spacer(),
                ShimmerBox(width: 65, height: 20, borderRadius: 10),
                SizedBox(width: 8),
                ShimmerBox(width: 22, height: 22, borderRadius: 4),
              ],
            ),
            Divider(
              height: 20,
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
            ),
            // Middle Row: Phase / Stage, Broker / PO, ETA
            const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 150, height: 12),
                      SizedBox(height: 6),
                      ShimmerBox(width: 110, height: 10),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 12),
                      SizedBox(height: 6),
                      ShimmerBox(width: 100, height: 10),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShimmerBox(width: 80, height: 12),
                    SizedBox(height: 6),
                    ShimmerBox(width: 60, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Progress Bar & Tracker skeleton
            const ShimmerBox(width: double.infinity, height: 8, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton list of shipment cards.
class ShipmentListShimmerSkeleton extends StatelessWidget {
  final int count;

  const ShipmentListShimmerSkeleton({
    super.key,
    this.count = 3,
  });

  /// Convenient helper for sliver lists
  static Widget sliver({int count = 3}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ShipmentListShimmerSkeleton(count: count),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShimmerEffect(
      child: Column(
        children: List.generate(count, (_) => const ShipmentCardShimmerSkeleton()),
      ),
    );
  }
}

/// Skeleton shimmer representation of the 6-Phase Lifecycle Operations Summary.
class LifecycleSummaryShimmerSkeleton extends StatelessWidget {
  const LifecycleSummaryShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return AppShimmerEffect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1000;
          final cardWidth = isWide
              ? (constraints.maxWidth - 36) / 3
              : (constraints.maxWidth - 16) / 2;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(6, (phaseIndex) {
              return Container(
                width: cardWidth.clamp(280.0, 480.0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBackground : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Phase title + count badge
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 160, height: 14),
                        ShimmerBox(width: 32, height: 18, borderRadius: 9),
                      ],
                    ),
                    Divider(
                      height: 16,
                      color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                    ),
                    // 3 Step Pills
                    ...List.generate(3, (stepIdx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ShimmerBox(
                              width: 120 + ((stepIdx * 25) % 50).toDouble(),
                              height: 12,
                            ),
                            const ShimmerBox(width: 24, height: 14, borderRadius: 4),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Skeleton shimmer representation of the 6-Phase Kanban Board in [LifecycleBoardScreen].
class KanbanBoardShimmerSkeleton extends StatelessWidget {
  const KanbanBoardShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return AppShimmerEffect(
      child: Column(
        children: [
          // Upper 6 Phase Overview Cards Row
          Container(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(6, (index) {
                  return Container(
                    width: 185,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ShimmerBox(width: 100, height: 12),
                            ShimmerBox(width: 24, height: 16, borderRadius: 8),
                          ],
                        ),
                        SizedBox(height: 8),
                        ShimmerBox(width: 140, height: 10),
                        SizedBox(height: 6),
                        ShimmerBox(width: double.infinity, height: 4, borderRadius: 2),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? AppTheme.darkBorder : Colors.black12),
          // Lower: Table Skeleton
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBackground : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  ),
                ),
                child: const ShimmerTablePlaceholder(
                  columnCount: 7,
                  rowCount: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton shimmer representation of the Live Logistics Radar View in [LifecycleBoardScreen].
class RadarTableShimmerSkeleton extends StatelessWidget {
  const RadarTableShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return AppShimmerEffect(
      child: Column(
        children: [
          // Upper 5 Strategic KPI Cards Row
          Container(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(5, (index) {
                  return Container(
                    width: 170,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                      ),
                    ),
                    child: const Row(
                      children: [
                        ShimmerBox(width: 28, height: 28, borderRadius: 6),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 70, height: 10),
                            SizedBox(height: 4),
                            ShimmerBox(width: 40, height: 14),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? AppTheme.darkBorder : Colors.black12),
          // Middle Search & Filter Bar
          Container(
            color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: const Row(
              children: [
                ShimmerBox(width: 260, height: 36, borderRadius: 6),
                SizedBox(width: 12),
                ShimmerBox(width: 60, height: 28, borderRadius: 14),
                SizedBox(width: 6),
                ShimmerBox(width: 70, height: 28, borderRadius: 14),
                SizedBox(width: 6),
                ShimmerBox(width: 70, height: 28, borderRadius: 14),
              ],
            ),
          ),
          // Lower: Radar Data Table Skeleton
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBackground : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  ),
                ),
                child: const ShimmerTablePlaceholder(
                  columnCount: 7,
                  rowCount: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic theme-adaptive table placeholder for skeleton loading.
class ShimmerTablePlaceholder extends StatelessWidget {
  final int columnCount;
  final int rowCount;

  const ShimmerTablePlaceholder({
    super.key,
    this.columnCount = 6,
    this.rowCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Column(
      children: [
        // Header
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.charcoal.withValues(alpha: 0.04),
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(8),
              topEnd: Radius.circular(8),
            ),
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
              ),
            ),
          ),
          child: Row(
            children: List.generate(columnCount, (index) {
              return const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: ShimmerBox(height: 14),
                ),
              );
            }),
          ),
        ),
        // Rows
        ...List.generate(rowCount, (rowIndex) {
          final isEven = rowIndex.isEven;
          return Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? (isEven ? AppTheme.darkSurface : AppTheme.darkCardBackground)
                  : (isEven ? Colors.grey.shade50 : Colors.white),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade100,
                ),
              ),
            ),
            child: Row(
              children: List.generate(columnCount, (colIndex) {
                final factor = 0.5 + ((rowIndex + colIndex) % 4) * 0.15;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ShimmerBox(
                        height: 12,
                        width: 130 * factor,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }
}

/// Shimmer skeleton for the [ImportFilesScreen] DataGrid.
class ImportFilesTableShimmerSkeleton extends StatelessWidget {
  final int rowCount;

  const ImportFilesTableShimmerSkeleton({
    super.key,
    this.rowCount = 7,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return AppShimmerEffect(
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
        child: SingleChildScrollView(
          child: ShimmerTablePlaceholder(
            columnCount: 13,
            rowCount: rowCount,
          ),
        ),
      ),
    );
  }
}
