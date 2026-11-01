import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/clearance_followup_log_model.dart';

/// 5-Stage Stepper widget for customs clearance follow-ups
class ClearanceFollowupStepper extends StatelessWidget {
  final List<ClearanceFollowupLogModel> logs;
  final bool isArabic;

  const ClearanceFollowupStepper({
    super.key,
    required this.logs,
    required this.isArabic,
  });

  static String stageLabel(int seq, bool isArabic) {
    switch (seq) {
      case 1:
        return isArabic ? 'المعاينة' : 'Inspection';
      case 2:
        return isArabic ? 'التثمين' : 'Valuation';
      case 3:
        return isArabic ? 'الرقابة' : 'GOEIC';
      case 4:
        return isArabic ? 'الجهات' : 'Agencies';
      case 5:
        return isArabic ? 'الإفراج' : 'Release';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.charcoalSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(5, (idx) {
          final seq = idx + 1;
          final matchingLog = logs.where((x) => x.followupSeq == seq).firstOrNull;
          final isDone = matchingLog?.isCompleted ?? false;
          final isLogged = matchingLog != null;

          Color badgeColor = AppTheme.borderOf(context);
          Color textColor = AppTheme.textSecondaryOf(context);
          IconData badgeIcon = Icons.hourglass_empty_rounded;

          if (isDone) {
            badgeColor = AppTheme.emerald;
            textColor = Colors.white;
            badgeIcon = Icons.check_circle_rounded;
          } else if (isLogged) {
            badgeColor = AppTheme.orange;
            textColor = Colors.white;
            badgeIcon = Icons.schedule_rounded;
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLogged ? badgeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: badgeColor),
                ),
                child: Row(
                  children: [
                    Icon(badgeIcon, size: 14, color: isLogged ? textColor : badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      '#$seq ${stageLabel(seq, isArabic)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isLogged ? FontWeight.bold : FontWeight.normal,
                        color: isLogged ? textColor : AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (seq < 5) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
              ],
            ],
          );
        }),
      ),
    );
  }
}
