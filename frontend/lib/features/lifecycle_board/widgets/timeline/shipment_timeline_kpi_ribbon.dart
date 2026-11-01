import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/timeline_snapshot_model.dart';

class ShipmentTimelineKpiRibbon extends StatelessWidget {
  final TimelineSummaryModel summary;
  final int completionPercent;
  final bool isAr;

  const ShipmentTimelineKpiRibbon({
    super.key,
    required this.summary,
    required this.completionPercent,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildKpiTile(
                context,
                title: isAr ? 'المراحل الإجمالية' : 'Total Stages',
                value: '${summary.totalStages}',
                color: AppTheme.charcoal,
                icon: Icons.flag_outlined,
              ),
              _buildDivider(context),
              _buildKpiTile(
                context,
                title: isAr ? 'مكتملة' : 'Completed',
                value: '${summary.completedStages}',
                color: AppTheme.emerald,
                icon: Icons.check_circle_outline,
              ),
              _buildDivider(context),
              _buildKpiTile(
                context,
                title: isAr ? 'جارية تشغيلياً' : 'In Progress',
                value: '${summary.inProgressStages}',
                color: AppTheme.cobalt,
                icon: Icons.play_arrow_outlined,
              ),
              _buildDivider(context),
              _buildKpiTile(
                context,
                title: isAr ? 'متأخرة عن SLA' : 'Delayed',
                value: '${summary.delayedStages}',
                color: summary.delayedStages > 0 ? AppTheme.orange : AppTheme.charcoal,
                icon: Icons.timer_off_outlined,
              ),
              _buildDivider(context),
              _buildKpiTile(
                context,
                title: isAr ? 'نقاط اختناق حرجة' : 'Bottlenecks',
                value: '${summary.bottlenecksCount}',
                color: summary.bottlenecksCount > 0 ? AppTheme.crimson : AppTheme.charcoal,
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: completionPercent / 100.0,
                    minHeight: 8,
                    backgroundColor: AppTheme.borderOf(context),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completionPercent%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: AppTheme.borderOf(context),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
