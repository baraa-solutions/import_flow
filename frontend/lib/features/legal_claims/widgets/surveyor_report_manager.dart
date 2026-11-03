import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../legal_claims_provider.dart';

class SurveyorReportManager extends StatelessWidget {
  final LegalClaimItem claim;
  final VoidCallback onScheduleSurvey;
  final VoidCallback onSettleClaim;

  const SurveyorReportManager({
    super.key,
    required this.claim,
    required this.onScheduleSurvey,
    required this.onSettleClaim,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in_outlined, color: AppTheme.cobalt, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'محضر وتقرير المعاينة المشتركة وحصر الأضرار',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                  ),
                ),
                AppStatusBadge.fromStatus(
                  status: claim.status,
                  label: claim.status == 'SETTLED'
                      ? 'تم التعويض'
                      : claim.surveyRequested
                          ? 'معاينة مجدولة'
                          : 'بانتظار المعاينة',
                ),
                const SizedBox(width: 8),
                if (!claim.surveyRequested && claim.status != 'SETTLED')
                  AppButton(
                    label: 'جدولة معاينة مشتركة',
                    icon: Icons.calendar_today_outlined,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: onScheduleSurvey,
                  ),
                if (claim.status != 'SETTLED') ...[
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'تسوية المطالبة',
                    icon: Icons.check,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: onSettleClaim,
                  ),
                ],
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('شركة المعاينة والخبرة', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(claim.surveyorCompany ?? 'لم تحدد', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تاريخ إجراء المعاينة', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        claim.surveyDate != null ? claim.surveyDate!.toIso8601String().substring(0, 10) : 'غير محدد',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رقم محضر المعاينة الرسمي', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(claim.surveyReportRef ?? 'قيد الإعداد', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المبلغ المسوى والمستلم', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${claim.settledAmount.toStringAsFixed(2)} ${claim.claimedCurrency}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: claim.status == 'SETTLED' ? AppTheme.emerald : AppTheme.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
