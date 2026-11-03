import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import 'report_card_container.dart';

/// Live operational updates, daily check-in notes, and alerts timeline card.
class ReportUpdatesTimelineCard extends StatelessWidget {
  final ImportFileModel file;
  final ShipmentUpdatesState updatesState;

  const ReportUpdatesTimelineCard({
    super.key,
    required this.file,
    required this.updatesState,
  });

  static String formatPhaseLabel(BuildContext context, String rawPhase) {
    final l = context.l10n;
    final match = RegExp(r'Phase\s*(\d+)').firstMatch(rawPhase);
    if (match != null) {
      final num = int.tryParse(match.group(1) ?? '');
      if (num != null) {
        return l.compReportPhaseLabel(num);
      }
    }
    return rawPhase;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final logs = updatesState.logs;

    return ReportCardContainer(
      title: l.compReportSecTimeline(logs.length),
      icon: Icons.history_outlined,
      iconColor: AppTheme.cobalt,
      child: logs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text(l.compReportNoTimelineLogs, style: const TextStyle(color: Colors.grey))),
            )
          : Column(
              children: logs.map((log) {
                Color catColor;
                IconData catIcon;
                String catLabel;
                switch (log.updateCategory) {
                  case 'Phase Cost Adjustment':
                    catColor = AppTheme.orange;
                    catIcon = Icons.edit_note;
                    catLabel = l.compReportCategoryCostAdjustment;
                    break;
                  case 'Future Phase Alert':
                    catColor = AppTheme.crimson;
                    catIcon = Icons.notification_important;
                    catLabel = l.compReportCategoryFutureAlert;
                    break;
                  case 'Daily Check-in':
                    catColor = AppTheme.emerald;
                    catIcon = Icons.today;
                    catLabel = l.compReportCategoryDailyCheckIn;
                    break;
                  default:
                    catColor = AppTheme.cobalt;
                    catIcon = Icons.sticky_note_2_outlined;
                    catLabel = log.updateCategory.isEmpty ? l.compReportCategoryGeneralUpdate : log.updateCategory;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline dot
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: catColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                            child: Icon(catIcon, size: 16, color: catColor),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Log Content
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(catLabel, style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.charcoal.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      formatPhaseLabel(context, log.targetPhase),
                                      style: const TextStyle(fontSize: 10, color: AppTheme.charcoal, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(log.logDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  const SizedBox(width: 8),
                                  Text(l.compReportByPrefix(log.assignedUser), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(log.note, style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black87)),
                              if (log.updateCategory == 'Phase Cost Adjustment' && log.adjustedCostItem != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.orange.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.swap_horiz, size: 14, color: AppTheme.orange),
                                      const SizedBox(width: 6),
                                      Text('${log.adjustedCostItem}: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      Text(log.previousCost.toStringAsFixed(2), style: const TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                                      const Text(' → ', style: TextStyle(fontSize: 11, color: AppTheme.orange)),
                                      Text('${log.newCost.toStringAsFixed(2)} ${l.compReportCurrencyUsd}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                                    ],
                                  ),
                                ),
                              ],
                              if (log.updateCategory == 'Future Phase Alert') ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.flag, size: 13, color: AppTheme.crimson),
                                    const SizedBox(width: 4),
                                    Text(l.compReportAlertPriorityPrefix(log.alertPriority),
                                        style: const TextStyle(fontSize: 11, color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
