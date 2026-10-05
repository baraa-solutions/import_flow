import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/customs_consultation_model.dart';
import 'consultation_metric_badge.dart';
import 'consultation_status_badges.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/buttons/app_button.dart';

class PostSaveStatusDialog extends StatelessWidget {
  final CustomsConsultationModel saved;

  const PostSaveStatusDialog({super.key, required this.saved});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final approved =
        saved.checklistItems.where((i) => i.status == 'Approved').toList();
    final pending =
        saved.checklistItems.where((i) => i.status == 'Pending').toList();
    final blocking = saved.checklistItems
        .where((i) => i.isBlockingShipment && i.status != 'Approved')
        .toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            blocking.isNotEmpty
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            color: blocking.isNotEmpty ? AppTheme.orange : AppTheme.emerald,
            size: 26,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.customsDutyReviewTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                CopyableText(
                  saved.consultationCode,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.cobalt,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Metrics
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ConsultationMetricBadge(
                      title: l.clearanceReadyStatus, value: '${approved.length}', color: AppTheme.emerald),
                  ConsultationMetricBadge(
                      title: l.statusPending,
                      value: '${pending.length}',
                      color: AppTheme.orange),
                  ConsultationMetricBadge(
                      title: l.openBlockingIssues,
                      value: '${blocking.length}',
                      color: blocking.isNotEmpty ? AppTheme.crimson : AppTheme.emerald),
                  ConsultationMetricBadge(
                      title: l.avgReadinessMetric,
                      value: '${saved.readinessPercentage.toStringAsFixed(0)}%',
                      color: AppTheme.cobalt),
                ],
              ),
              const SizedBox(height: 16),

              if (blocking.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.crimsonLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.crimsonBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.blockingIssuesTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: AppTheme.crimson),
                      ),
                      const SizedBox(height: 8),
                      ...blocking.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.block,
                                  color: AppTheme.crimson, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    CopyableText(
                                      item.documentType,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                    if (item.hsCode != null &&
                                        item.hsCode!.isNotEmpty)
                                      CopyableText(
                                        item.hsCode!,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.cobalt),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConsultationDocStatusBadge(status: item.status),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (pending.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.statusPending,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.orange),
                      ),
                      const SizedBox(height: 8),
                      ...pending.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_empty,
                                  color: AppTheme.wcagOrange, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    CopyableText(
                                      item.documentType,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                    if (item.hsCode != null &&
                                        item.hsCode!.isNotEmpty)
                                      CopyableText(
                                        item.hsCode!,
                                        style: const TextStyle(
                                            fontSize: 10, color: AppTheme.cobalt),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConsultationDocStatusBadge(status: item.status),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (blocking.isEmpty && pending.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: AppTheme.emerald, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.clearanceReadyStatus,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.emerald,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l.close,
          icon: Icons.close,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

