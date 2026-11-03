// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../models/import_file_model.dart';
import 'shipment_acid_status_badge.dart';
import 'courier_tracking_action_button.dart';

/// 📌 ACID & Form 4 Expiry Tracking Card for Overview Tab
class OverviewAcidStatusCard extends StatelessWidget {
  final ImportFileModel file;
  final bool isDark;
  final bool isAr;

  const OverviewAcidStatusCard({
    super.key,
    required this.file,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: file.isCustomsReleased
              ? (isDark ? AppTheme.emerald.withValues(alpha: 0.2) : AppTheme.emerald.withValues(alpha: 0.08))
              : (file.acidNumber != null
                  ? (isDark ? AppTheme.cobalt.withValues(alpha: 0.2) : AppTheme.cobalt.withValues(alpha: 0.08))
                  : (isDark ? AppTheme.darkSurface : AppTheme.cloudWhite)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: file.isCustomsReleased
                ? AppTheme.emerald
                : (file.acidNumber != null ? AppTheme.cobalt : (isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: file.isCustomsReleased
                  ? AppTheme.emerald.withValues(alpha: 0.15)
                  : (file.acidNumber != null ? AppTheme.cobalt.withValues(alpha: 0.15) : Colors.grey.shade200),
              child: Icon(
                file.isCustomsReleased
                    ? Icons.verified_user
                    : (file.acidNumber != null ? Icons.hourglass_top : Icons.pending_actions),
                color: file.isCustomsReleased
                    ? AppTheme.emerald
                    : (file.acidNumber != null ? AppTheme.cobalt : Colors.grey),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📌 ${l.acidStatusTitle}:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: file.isCustomsReleased
                              ? AppTheme.emerald
                              : (file.acidNumber != null
                                  ? (isDark ? Colors.lightBlueAccent : AppTheme.cobalt)
                                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                        ),
                      ),
                      if (file.isCustomsReleased)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '✅ ${l.customsReleasedBadge}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      else if (file.acidNumber != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⏳ ${l.underClearanceBadge}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (file.acidNumber != null && file.acidNumber!.isNotEmpty) ...[
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('ACID: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                            SelectableText(
                              file.acidNumber!,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.lightBlueAccent : AppTheme.charcoal),
                            ),
                          ],
                        ),
                        if (file.acidRequestDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${l.date}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                              Text(file.acidRequestDate!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                            ],
                          ),
                        if (file.acidIssueDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${l.date}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                              Text(file.acidIssueDate!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                            ],
                          ),
                        if (file.acidExpiryDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${l.targetEta}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                              Text(
                                file.acidExpiryDate!,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade300 : AppTheme.crimson),
                              ),
                            ],
                          ),
                        if (file.acidExecutionDays != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: isDark ? 0.3 : 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.emerald, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, size: 12, color: isDark ? Colors.green.shade300 : AppTheme.emerald),
                                const SizedBox(width: 4),
                                Text(
                                  isAr ? '${file.acidExecutionDays} يوم' : '${file.acidExecutionDays} d',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : AppTheme.emerald),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ShipmentAcidStatusBadge.fromImportFile(file),
                          CourierTrackingActionButton.fromImportFile(file),
                        ],
                      ),
                    ),
                  ],
                  if (file.form4No != null && file.form4No!.isNotEmpty) ...[
                    Divider(height: 16, color: isDark ? AppTheme.darkBorder : null),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${isAr ? "نموذج 4" : "Form 4"}: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                            SelectableText(file.form4No!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt)),
                          ],
                        ),
                        if (file.form4RequestDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${l.date}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                              Text(file.form4RequestDate!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                            ],
                          ),
                        if (file.form4ReceivedDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${l.date}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                              Text(file.form4ReceivedDate!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.green.shade300 : AppTheme.emerald)),
                            ],
                          ),
                        if (file.form4ExecutionDays != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: isDark ? 0.3 : 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.cobalt, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speed, size: 12, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                                const SizedBox(width: 4),
                                Text(
                                  isAr ? '${file.form4ExecutionDays} يوم' : '${file.form4ExecutionDays} d',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
