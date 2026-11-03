import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../smart_checklists/providers/smart_checklists_provider.dart';
import '../../smart_checklists/widgets/smart_checklist_dialog.dart';
import 'report_card_container.dart';
import 'report_header_banner_card.dart';

/// 10-Phase Pipeline Stepper card with Smart Checklist readiness bar for the Comprehensive Report.
class ReportPhasePipeline extends StatelessWidget {
  final ImportFileModel file;
  final ShipmentUpdatesState updatesState;
  final SmartChecklistState checklistState;

  const ReportPhasePipeline({
    super.key,
    required this.file,
    required this.updatesState,
    required this.checklistState,
  });

  static List<Map<String, dynamic>> getPhases(BuildContext context) {
    final l = context.l10n;
    return [
      {'code': 'Phase 1', 'name': l.compReportPhase1Name, 'icon': Icons.analytics_outlined, 'bp': 'BP-001 → BP-011'},
      {'code': 'Phase 2', 'name': l.compReportPhase2Name, 'icon': Icons.account_balance_outlined, 'bp': 'BP-012 → BP-013'},
      {'code': 'Phase 3', 'name': l.compReportPhase3Name, 'icon': Icons.description_outlined, 'bp': 'BP-014 → BP-016'},
      {'code': 'Phase 4', 'name': l.compReportPhase4Name, 'icon': Icons.directions_boat_outlined, 'bp': 'BP-017 → BP-019'},
      {'code': 'Phase 5', 'name': l.compReportPhase5Name, 'icon': Icons.local_shipping_outlined, 'bp': 'BP-020 → BP-025'},
      {'code': 'Phase 6', 'name': l.compReportPhase6Name, 'icon': Icons.account_balance_wallet_outlined, 'bp': 'BP-026 → BP-028'},
      {'code': 'Phase 7', 'name': l.compReportPhase7Name, 'icon': Icons.receipt_long_outlined, 'bp': 'BP-029 → BP-032'},
      {'code': 'Phase 8', 'name': l.compReportPhase8Name, 'icon': Icons.warehouse_outlined, 'bp': 'BP-033 → BP-035'},
      {'code': 'Phase 9', 'name': l.compReportPhase9Name, 'icon': Icons.calculate_outlined, 'bp': 'BP-036 → BP-039'},
      {'code': 'Phase 10', 'name': l.compReportPhase10Name, 'icon': Icons.archive_outlined, 'bp': 'BP-040'},
    ];
  }

  static String mapIndexToChecklistStage(int idx) {
    if (idx < 4) return 'PRE_SHIPMENT';
    if (idx == 4) return 'IN_TRANSIT';
    if (idx == 5) return 'PORT_ARRIVAL';
    if (idx == 6) return 'CLEARANCE';
    return 'POST_CLEARANCE';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final phases = getPhases(context);
    final currentIdx = ReportHeaderBanner.currentPhaseIndex(file);
    final isClosed = file.status == 'Closed';
    final checklistSummary = checklistState.summary;

    return ReportCardContainer(
      title: l.compReportPipelineTitle,
      icon: Icons.linear_scale,
      iconColor: AppTheme.cobalt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Checklist & Gatekeeper Status Bar
          if (checklistSummary != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: checklistSummary.isGateBlocked
                    ? AppTheme.crimson.withValues(alpha: 0.08)
                    : AppTheme.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: checklistSummary.isGateBlocked
                      ? AppTheme.crimson.withValues(alpha: 0.3)
                      : AppTheme.emerald.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    checklistSummary.isGateBlocked
                        ? Icons.gpp_bad_outlined
                        : Icons.verified_user_outlined,
                    color: checklistSummary.isGateBlocked
                        ? AppTheme.crimson
                        : AppTheme.emerald,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'جاهزية قائمة التحقق (Checklist Readiness): ${checklistSummary.readinessScorePct}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: checklistSummary.isGateBlocked
                          ? AppTheme.crimson
                          : AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${checklistSummary.passedItems + checklistSummary.waivedItems}/${checklistSummary.totalItems} بنود مكتملة)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  if (checklistSummary.isGateBlocked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'حظر البوابة (${checklistSummary.mandatoryPendingItems} إلزامي معلق)',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('عرض وتدقيق القائمة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => SmartChecklistDialog.show(context, file),
                  ),
                ],
              ),
            ),
          ],

          // Phase Stepper Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(phases.length, (idx) {
                final phase = phases[idx];
                final pCode = phase['code'] as String;
                final phaseLogs = updatesState.logs.where((log) => log.targetPhase.contains(pCode)).toList();

                bool isCompleted = isClosed || idx < currentIdx;
                bool isCurrent = !isClosed && idx == currentIdx;

                final stageCode = mapIndexToChecklistStage(idx);
                final items = checklistSummary?.items ?? [];
                final stageItems = items.where((i) => i.phaseCode == stageCode).toList();
                final totalStage = stageItems.length;
                final passedStage = stageItems.where((i) => i.isPassed || i.isWaived).length;
                final mandatoryPendingStage = stageItems.where((i) => i.isMandatory && i.isPending).length;

                Color dotColor = isCompleted
                    ? AppTheme.emerald
                    : isCurrent
                        ? AppTheme.cobalt
                        : Colors.grey.shade300;

                Color borderColor = isCompleted
                    ? AppTheme.emerald
                    : isCurrent
                        ? AppTheme.cobalt
                        : Colors.grey.shade300;

                Color textColor = isCompleted
                    ? Colors.green.shade800
                    : isCurrent
                        ? AppTheme.cobalt
                        : Colors.grey.shade500;

                return Row(
                  children: [
                    Container(
                      width: 142,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.shade50
                            : isCurrent
                                ? Colors.blue.shade50
                                : Colors.grey.shade50,
                        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : isCurrent
                                        ? Icons.play_circle_fill
                                        : Icons.radio_button_unchecked,
                                size: 16,
                                color: dotColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  l.compReportPhaseLabel(idx + 1),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (phaseLogs.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${phaseLogs.length}',
                                    style: const TextStyle(fontSize: 9, color: AppTheme.orange, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phase['name'] as String,
                            style: TextStyle(fontSize: 9, color: textColor, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phaseLogs.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              phaseLogs.first.note,
                              style: TextStyle(fontSize: 8, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => SmartChecklistDialog.show(context, file, initialPhase: stageCode),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: mandatoryPendingStage > 0
                                    ? (isCurrent ? AppTheme.crimson.withValues(alpha: 0.12) : AppTheme.orange.withValues(alpha: 0.12))
                                    : (totalStage > 0 && passedStage == totalStage
                                        ? AppTheme.emerald.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: mandatoryPendingStage > 0
                                      ? (isCurrent ? AppTheme.crimson.withValues(alpha: 0.4) : AppTheme.orange.withValues(alpha: 0.4))
                                      : (totalStage > 0 && passedStage == totalStage
                                          ? AppTheme.emerald.withValues(alpha: 0.4)
                                          : Colors.grey.withValues(alpha: 0.25)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    mandatoryPendingStage > 0
                                        ? Icons.warning_amber_rounded
                                        : (totalStage > 0 && passedStage == totalStage
                                            ? Icons.check_circle_outline
                                            : Icons.checklist),
                                    size: 11,
                                    color: mandatoryPendingStage > 0
                                        ? (isCurrent ? AppTheme.crimson : AppTheme.orange)
                                        : (totalStage > 0 && passedStage == totalStage
                                            ? AppTheme.emerald
                                            : AppTheme.charcoal),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      totalStage > 0
                                          ? '$passedStage/$totalStage بنود'
                                          : 'قائمة التحقق',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: mandatoryPendingStage > 0
                                            ? (isCurrent ? AppTheme.crimson : AppTheme.orange)
                                            : (totalStage > 0 && passedStage == totalStage
                                                ? AppTheme.emerald
                                                : AppTheme.charcoal),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (idx < phases.length - 1)
                      Container(
                        width: 16,
                        height: 2,
                        color: idx < currentIdx ? AppTheme.emerald : Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                      ),
                  ],
                );
              }),
            ),
          ),

          if (isClosed && file.closedAtPhase != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outlined, color: AppTheme.crimson, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l.compReportStoppedAtPhase(file.closedAtPhase!),
                    style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (file.closureReason != null) ...[
                    const SizedBox(width: 8),
                    Text(' — ${file.closureReason}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
