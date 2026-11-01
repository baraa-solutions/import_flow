import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/reexport_protocol_model.dart';

class ReexportMetricsStrip extends StatelessWidget {
  final DestructionAlertOverviewModel alertsOverview;

  const ReexportMetricsStrip({
    super.key,
    required this.alertsOverview,
  });

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMetricChip('إجمالي الملفات المرفوضة', '${alertsOverview.totalActiveDossiers}', Colors.blueGrey),
            const SizedBox(width: 8),
            _buildMetricChip('خطر الإعدام (مهلة منتهية) ⛔', '${alertsOverview.criticalCount}', AppTheme.crimson),
            const SizedBox(width: 8),
            _buildMetricChip('عاجل جداً (≤ 7 أيام) 🔴', '${alertsOverview.urgentCount}', const Color(0xFFD32F2F)),
            const SizedBox(width: 8),
            _buildMetricChip('إنذار (≤ 14 يوماً) 🟡', '${alertsOverview.warningCount}', AppTheme.orange),
            const SizedBox(width: 8),
            _buildMetricChip('آمن (> 14 يوماً) 🟢', '${alertsOverview.normalCount}', AppTheme.emerald),
          ],
        ),
      ),
    );
  }
}
