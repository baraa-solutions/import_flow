import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../vendor_quality_provider.dart';

class VendorScorecardRadarChart extends StatelessWidget {
  final VendorQualityModel assessment;

  const VendorScorecardRadarChart({super.key, required this.assessment});

  Widget _buildPillarBar(BuildContext context, String title, double score, double weight, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text('${score.toStringAsFixed(1)}% (وزن ${(weight * 100).toInt()}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grade = assessment.ratingGrade;
    final rating = assessment.overallVendorRating;

    Color gradeColor;
    switch (grade) {
      case 'A':
        gradeColor = AppTheme.emerald;
        break;
      case 'B':
        gradeColor = AppTheme.cobalt;
        break;
      case 'C':
        gradeColor = AppTheme.orange;
        break;
      default:
        gradeColor = AppTheme.crimson;
    }

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(assessment.vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => CopyHelper.copy(context, assessment.assessmentCode),
                        child: Text(
                          'تقييم: ${assessment.assessmentCode}',
                          style: const TextStyle(color: AppTheme.cobalt, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'الفئة $grade',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: gradeColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${rating.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: gradeColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildPillarBar(context, 'جودة البضاعة والمطابقة الفنية', assessment.qualityScore, 0.40, AppTheme.emerald),
            _buildPillarBar(context, 'الالتزام بمواعيد الشحن والتسليم', assessment.deliveryTimelinessScore, 0.25, AppTheme.cobalt),
            _buildPillarBar(context, 'دقة واكتمال المستندات التجارية', assessment.documentationAccuracyScore, 0.20, AppTheme.orange),
            _buildPillarBar(context, 'الامتثال للشروط واللوائح الجمركية', assessment.complianceScore, 0.15, AppTheme.charcoal),
            if (assessment.correctiveActionRequired) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.report_problem_rounded, color: AppTheme.crimson, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assessment.correctiveActionPlan ?? 'تنبيه: يتطلب المورد خطة عمل تصحيحية فورية بسبب تدني التقييم أو وجود عيوب حرجة.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.crimson, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const AppStatusBadge(label: 'إجراء تصحيحي مطلوب', severity: AppSeverity.danger),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
