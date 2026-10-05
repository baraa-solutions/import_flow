import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Animated skeleton shimmer placeholder for [EnterpriseDataTable] while loading.
class EnterpriseTableShimmerSkeleton extends StatefulWidget {
  final int rowCount;
  final int columnCount;

  const EnterpriseTableShimmerSkeleton({
    super.key,
    this.rowCount = 6,
    this.columnCount = 6,
  });

  @override
  State<EnterpriseTableShimmerSkeleton> createState() =>
      _EnterpriseTableShimmerSkeletonState();
}

class _EnterpriseTableShimmerSkeletonState
    extends State<EnterpriseTableShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
    final baseColor = isDark ? AppTheme.darkSurface : Colors.grey.shade200;
    final highlightColor = isDark ? AppTheme.darkBorderLight : Colors.grey.shade50;
    final headerBaseColor = isDark ? AppTheme.darkBorder : Colors.grey.shade300;
    final headerHighlightColor = isDark ? AppTheme.darkBorderLight : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              // Header Skeleton
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.charcoal.withOpacity(0.04),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                    ),
                  ),
                ),
                child: Row(
                  children: List.generate(widget.columnCount, (index) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildShimmerBox(
                          height: 16,
                          width: double.infinity,
                          baseColor: headerBaseColor,
                          highlightColor: headerHighlightColor,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Rows Skeleton
              ...List.generate(widget.rowCount, (rowIndex) {
                final isEven = rowIndex.isEven;
                return Container(
                  height: 46,
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
                    children: List.generate(widget.columnCount, (colIndex) {
                      // Vary box widths slightly to look natural
                      final factor = 0.6 + ((rowIndex + colIndex) % 4) * 0.1;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _buildShimmerBox(
                              height: 13,
                              width: 120 * factor,
                              baseColor: baseColor,
                              highlightColor: highlightColor,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({
    required double height,
    required double width,
    required Color baseColor,
    required Color highlightColor,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          stops: [
            (_animation.value - 0.3).clamp(0.0, 1.0),
            _animation.value.clamp(0.0, 1.0),
            (_animation.value + 0.3).clamp(0.0, 1.0),
          ],
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
        ),
      ),
    );
  }
}
