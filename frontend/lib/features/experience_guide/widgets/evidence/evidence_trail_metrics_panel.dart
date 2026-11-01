import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/guide_entry_model.dart';

/// Metrics and status chips panel for autonomous evidence trail
class EvidenceTrailMetricsPanel extends StatelessWidget {
  final ProvenanceModel provenance;

  const EvidenceTrailMetricsPanel({
    super.key,
    required this.provenance,
  });

  @override
  Widget build(BuildContext context) {
    final p = provenance;
    final score = p.confidenceScore != null ? (p.confidenceScore! * 100).toInt() : 0;
    final files = p.contributingFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Status & Dimension Chips Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 14, color: AppTheme.cobalt),
                  SizedBox(width: 4),
                  Text(
                    'استنتاج آلي ذاتي (System-Inferred)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (p.isConfirmed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.emerald),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: AppTheme.emerald),
                    const SizedBox(width: 4),
                    Text(
                      'معتمد كقاعدة مؤسسية (${p.confirmedBy ?? 'إدارة'})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                    ),
                  ],
                ),
              )
            else if (p.isRejected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.crimson),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.block_rounded, size: 14, color: AppTheme.crimson),
                    const SizedBox(width: 4),
                    Text(
                      'مستبعد (${p.rejectedBy ?? 'مستخدم'})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.orange),
                ),
                child: const Text(
                  'قيد المراقبة وإعادة التقييم التلقائي',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange),
                ),
              ),
            if (p.patternCategory != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p.patternCategory!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // 2. Metrics 3-Card Dashboard
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'مستوى الثقة الإحصائية',
                value: '$score%',
                subtitle: p.confidenceLevel ?? 'MEDIUM',
                icon: Icons.analytics_outlined,
                color: score >= 80
                    ? AppTheme.emerald
                    : (score >= 65 ? AppTheme.cobalt : AppTheme.orange),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'حجم العينة المرصودة',
                value: '${p.sampleSize ?? files.length}',
                subtitle: 'شحنات استيرادية سابقة',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.cobalt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'تاريخ الاكتشاف والرصد',
                value: p.firstDetectedAt != null
                    ? p.firstDetectedAt!.split('T').first
                    : 'مستمر',
                subtitle: p.lastRecalculatedAt != null
                    ? 'آخر تحديث: ${p.lastRecalculatedAt!.split('T').first}'
                    : 'تحديث تلقائي',
                icon: Icons.update_rounded,
                color: AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
