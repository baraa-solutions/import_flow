import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/clearance_followup_log_model.dart';

/// Card showing a single customs clearance follow-up record
class ClearanceFollowupCard extends StatelessWidget {
  final ClearanceFollowupLogModel item;
  final ValueChanged<int> onComplete;

  const ClearanceFollowupCard({
    super.key,
    required this.item,
    required this.onComplete,
  });

  static String authorityLabel(String a, bool isArabic) {
    if (!isArabic) return a;
    switch (a) {
      case 'Customs Inspection Yard / ساحة الكشف والمعاينة':
        return 'ساحة الكشف والمعاينة';
      case 'Customs Valuation Committee / لجنة التثمين الجمركي':
        return 'لجنة التثمين الجمركي';
      case 'GOEIC Inspection / هيئة الصادرات والواردات':
        return 'الهيئة العامة للرقابة على الصادرات والواردات';
      case 'Food Safety Authority / هيئة سلامة الغذاء (NFSA)':
        return 'الهيئة القومية لسلامة الغذاء';
      case 'Quarantine / الحجر الزراعي والبيطري':
        return 'الحجر الزراعي والبيطري';
      case 'Chemistry Administration / مصلحة الكيمياء والفحص المعملي':
        return 'مصلحة الكيمياء والفحص المعملي';
      case 'NTRA Telecomm / الجهاز القومي لتنظيم الاتصالات':
        return 'الجهاز القومي لتنظيم الاتصالات';
      case 'Customs Tariff & Classification / لجنة التعريفة والتصنيف':
        return 'لجنة التعريفة والتصنيف';
      default:
        return a.contains(' / ') ? a.split(' / ').last : a;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDone = item.isCompleted;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.severityBackgroundOf(context, AppSeverity.success).withValues(alpha: 0.3)
            : AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDone
              ? AppTheme.severityForegroundOf(context, AppSeverity.success).withValues(alpha: 0.4)
              : AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone ? AppTheme.emerald : AppTheme.cobalt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${item.followupSeq}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  authorityLabel(item.authorityType, l.isArabic),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                item.followupDate.length >= 10 ? item.followupDate.substring(0, 10) : item.followupDate,
                style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryOf(context)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (item.officialContact != null && item.officialContact!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${l.isArabic ? "المسؤول:" : "Officer:"} ${item.officialContact!}',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
              ),
            ),
          Text(
            item.statusSummary,
            style: const TextStyle(fontSize: 11.5),
          ),
          if (item.actionRequired != null && item.actionRequired!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.severityBackgroundOf(context, AppSeverity.warning).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${l.isArabic ? "مطلوب:" : "Action:"} ${item.actionRequired!}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (item.nextVisitDate != null)
                Text(
                  '${l.isArabic ? "الموعد القادم:" : "Next:"} ${item.nextVisitDate!.substring(0, 10)}',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondaryOf(context)),
                ),
              const Spacer(),
              if (isDone)
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.emerald),
                    const SizedBox(width: 4),
                    Text(
                      l.isArabic ? 'مكتملة' : 'Completed',
                      style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                )
              else
                AppButton(
                  label: l.isArabic ? 'تأكيد الإنجاز' : 'Mark Done',
                  icon: Icons.check,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => onComplete(item.logId),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
