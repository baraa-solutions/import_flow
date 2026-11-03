import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/inspection_appeal_model.dart';

class AppealCardItem extends StatelessWidget {
  final InspectionAppealModel item;
  final VoidCallback onDecision;
  final VoidCallback onProgressTier;

  const AppealCardItem({
    super.key,
    required this.item,
    required this.onDecision,
    required this.onProgressTier,
  });

  static AppSeverity tierSeverity(AppealTier tier) {
    switch (tier) {
      case AppealTier.firstAppeal:
        return AppSeverity.info;
      case AppealTier.secondAppeal:
        return AppSeverity.warning;
      case AppealTier.triplicateSample:
        return AppSeverity.danger;
    }
  }

  static AppSeverity resultSeverity(AppealResult res) {
    switch (res) {
      case AppealResult.overturnedConforming:
        return AppSeverity.success;
      case AppealResult.upheldRejected:
        return AppSeverity.danger;
      case AppealResult.pending:
        return AppSeverity.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Icon
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.biotech_rounded, color: AppTheme.cobalt, size: 28),
          ),
          const SizedBox(width: 14),

          // Main Appeal Details
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.appealCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cobalt),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(4)),
                      child: Text(item.regulatoryAuthority, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    AppStatusBadge(
                      label: item.appealTier.labelAr,
                      severity: tierSeverity(item.appealTier),
                    ),
                    const SizedBox(width: 8),
                    AppStatusBadge(
                      label: item.appealResult.labelAr,
                      severity: resultSeverity(item.appealResult),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ملف استيرادي: IMP-${item.importFileId} | رقم العينة: ${item.sampleNumber ?? "غير محدد"} | نتيجة الفحص المبدئي: ${item.initialTestResult}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (item.rejectionReason != null)
                  Text(
                    'أسباب التظلم: ${item.rejectionReason}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (item.triplicateLabAssigned != null)
                  Text(
                    'المعمل المحايد المعتمد للتحكيم: ${item.triplicateLabAssigned}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: 'قرار اللجنة',
                icon: Icons.gavel_rounded,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: onDecision,
              ),
              const SizedBox(width: 6),
              if (item.appealTier != AppealTier.triplicateSample)
                AppButton(
                  label: 'تصعيد التظلم',
                  icon: Icons.arrow_upward_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onProgressTier,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
