import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/directional_icon.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/widgets/shipment_milestone_tracker.dart';
import '../../smart_tasks/models/smart_task_model.dart';
import 'operational_format_helper.dart';
import 'operational_next_step_card.dart';

/// Badge widget representing shipment or task priority.
class OperationalPriorityBadge extends StatelessWidget {
  final String priority;
  final AppLocalizations? l;

  const OperationalPriorityBadge({
    super.key,
    required this.priority,
    this.l,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final loc = l ?? context.l10n;

    Color bg = isDark ? AppTheme.darkSurface : Colors.grey.shade200;
    Color fg = isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800;
    if (priority == 'High') {
      bg = isDark ? Colors.orange.shade900.withValues(alpha: 0.35) : Colors.orange.shade100;
      fg = isDark ? Colors.orange.shade300 : Colors.orange.shade900;
    } else if (priority == 'Critical') {
      bg = isDark ? Colors.red.shade900.withValues(alpha: 0.35) : Colors.red.shade100;
      fg = isDark ? Colors.red.shade300 : Colors.red.shade900;
    } else if (priority == 'Medium') {
      bg = isDark ? Colors.blue.shade900.withValues(alpha: 0.35) : Colors.blue.shade100;
      fg = isDark ? Colors.lightBlueAccent : Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        OperationalFormatHelper.getPriorityLabel(priority, loc),
        style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 11),
      ),
    );
  }
}

/// Linked Smart Tasks TO-DO List for a specific shipment card.
class OperationalLinkedTasksSection extends StatelessWidget {
  final ImportFileModel shipment;
  final List<SmartTaskModel> linkedTasks;
  final void Function(SmartTaskModel task, bool isCompleted)? onTaskStatusChanged;
  final VoidCallback? onManageAllTasks;

  const OperationalLinkedTasksSection({
    super.key,
    required this.shipment,
    required this.linkedTasks,
    this.onTaskStatusChanged,
    this.onManageAllTasks,
  });

  @override
  Widget build(BuildContext context) {
    if (linkedTasks.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);
    final l = context.l10n;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, size: 16),
              const SizedBox(width: 6),
              Text(
                '${l.openShipmentTasks} (${linkedTasks.length} ${l.tasksCountUnit}):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
              const Spacer(),
              if (onManageAllTasks != null)
                TextButton.icon(
                  onPressed: onManageAllTasks,
                  icon: const Icon(Icons.open_in_new, size: 12),
                  label: Text(l.manageAllTasks, style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...linkedTasks.map((t) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: t.status == 'Completed',
                    visualDensity: VisualDensity.compact,
                    activeColor: AppTheme.emerald,
                    checkColor: Colors.white,
                    side: BorderSide(color: isDark ? AppTheme.darkBorderLight : Colors.grey.shade500),
                    onChanged: (val) {
                      if (val != null) {
                        onTaskStatusChanged?.call(t, val);
                      }
                    },
                  ),
                  Expanded(
                    child: CopyableText(
                      t.displayTitle(context.l10n),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade900),
                    ),
                  ),
                  if (t.priority == 'Critical')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.red.shade900.withValues(alpha: 0.4) : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        OperationalFormatHelper.getPriorityLabel(t.priority, l),
                        style: TextStyle(color: isDark ? Colors.red.shade200 : Colors.red, fontSize: 11.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (t.dueDate != null && t.dueDate!.trim().isNotEmpty)
                    CopyableText(
                      t.dueDate!,
                      style: TextStyle(fontSize: 11.0, color: isDark ? AppTheme.darkTextMuted : Colors.grey.shade600),
                      showIcon: false,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Standalone Shipment Operational Card displayed in the dashboard list.
class OperationalShipmentCard extends StatelessWidget {
  final ImportFileModel shipment;
  final bool isArabic;
  final List<SmartTaskModel> linkedTasks;
  final VoidCallback? onRecordDailyUpdate;
  final VoidCallback? onSkipStep;
  final VoidCallback? onCloseShipment;
  final void Function(SmartTaskModel task, bool isCompleted)? onTaskStatusChanged;
  final ValueChanged<int>? onNavigate;
  final VoidCallback? onManageAllTasks;

  const OperationalShipmentCard({
    super.key,
    required this.shipment,
    this.isArabic = true,
    this.linkedTasks = const [],
    this.onRecordDailyUpdate,
    this.onSkipStep,
    this.onCloseShipment,
    this.onTaskStatusChanged,
    this.onNavigate,
    this.onManageAllTasks,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l = context.l10n;
    final s = shipment;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    CopyableText(
                      DisplayNameResolver.resolveShipmentName(s, isArabic: isArabic),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                    if (s.customFileNumber != null && s.customFileNumber!.trim().isNotEmpty && s.customFileNumber!.trim() != s.importFileCode)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.wcagCobalt.withValues(alpha: isDark ? 0.25 : 0.1), borderRadius: BorderRadius.circular(6)),
                        child: CopyableText(
                          s.importFileCode,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt),
                        ),
                      ),
                    CopyableText(
                      s.companyName,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade800),
                    ),
                    CopyableText(
                      '${DirectionalArrow.symbolForArabic(isArabic)} ${s.supplierName}',
                      style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OperationalPriorityBadge(priority: s.priority, l: l),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.wcagCobalt),
                      tooltip: l.copyTooltip,
                      onPressed: () {
                        final shipmentTitle = DisplayNameResolver.resolveShipmentTitle(s, isArabic: isArabic, includeCodeSecondary: true);
                        final arrow = DirectionalArrow.symbolForArabic(isArabic);
                        final text = '$shipmentTitle | ${s.companyName} $arrow ${s.supplierName} | ${OperationalFormatHelper.formatStageName(s.displayStepKey, isArabic: isArabic)}';
                        CopyHelper.copy(context, text);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            LayoutBuilder(
              builder: (context, cardConstraints) {
                final isNarrow = cardConstraints.maxWidth < 520;
                final phaseColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CopyableText(
                      '${l.currentPhase}: ${OperationalFormatHelper.formatStageName(s.displayStepKey, isArabic: isArabic)}',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null),
                    ),
                    CopyableText(
                      '${l.operationalStep}: ${s.displayStage(l, (t) => OperationalFormatHelper.formatStageName(t, isArabic: isArabic))}',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                    ),
                  ],
                );
                final brokerColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CopyableText(
                      '${l.customsBrokerLabel} ${s.brokerName ?? l.unassigned}',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null),
                    ),
                    CopyableText(
                      '${l.purchaseOrder} ${s.poNumber ?? l.unassigned}',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                    ),
                  ],
                );
                final progressColumn = Column(
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    CopyableText('${s.progressPercent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagEmerald, fontSize: 14)),
                    SizedBox(
                      width: 80,
                      child: LinearProgressIndicator(
                        value: s.progressPercent / 100.0,
                        backgroundColor: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade200,
                        color: AppTheme.wcagEmerald,
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: phaseColumn),
                          progressColumn,
                        ],
                      ),
                      const SizedBox(height: 8),
                      brokerColumn,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: phaseColumn),
                    Expanded(child: brokerColumn),
                    progressColumn,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // 3-Way Stage Pathway: Previous -> Current -> Next (Responsive & RTL mirrored)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
              child: LayoutBuilder(
                builder: (context, pathwayConstraints) {
                  final isCompactPathway = pathwayConstraints.maxWidth < 900;

                  final prevStepWidget = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 12, color: AppTheme.wcagEmerald),
                        const SizedBox(width: 4),
                        CopyableText(
                          s.currentModule.contains('STEP_02') || s.currentModule.contains('Customs') || s.currentModule.contains('جمرك')
                              ? l.pathwayPrevFreightStudies
                              : l.pathwayPrevFilePlanning,
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  );

                  final currentStepWidget = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.wcagCobalt.withValues(alpha: 0.25) : AppTheme.wcagCobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, size: 13, color: AppTheme.wcagCobalt),
                        const SizedBox(width: 4),
                        CopyableText(
                          '${l.pathwayCurrent}: ${OperationalFormatHelper.formatStageName(s.displayStepKey, isArabic: isArabic)}',
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.wcagCobalt),
                        ),
                      ],
                    ),
                  );

                  final nextStepWidget = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade700.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isArabic ? Icons.arrow_circle_left_outlined : Icons.arrow_circle_right_outlined, size: 13, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                        const SizedBox(width: 4),
                        Flexible(
                          child: CopyableText(
                            '${l.pathwayNext}: ${s.renderedNextAction(l) ?? (s.nextAction.isNotEmpty ? OperationalFormatHelper.formatActionName(s.nextAction, s.currentModule, isArabic: isArabic) : l.pathwayNextImportReqs)}',
                            style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isCompactPathway) {
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        prevStepWidget,
                        const DirectionalIcon(Icons.arrow_forward, size: 14, color: AppTheme.wcagCobalt),
                        currentStepWidget,
                        const DirectionalIcon(Icons.arrow_forward, size: 14, color: AppTheme.wcagOrange),
                        nextStepWidget,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      prevStepWidget,
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: DirectionalIcon(Icons.arrow_forward, size: 14, color: AppTheme.wcagCobalt),
                      ),
                      currentStepWidget,
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: DirectionalIcon(Icons.arrow_forward, size: 14, color: AppTheme.wcagOrange),
                      ),
                      Expanded(child: nextStepWidget),
                    ],
                  );
                },
              ),
            ),

            // Milestone Progress Tracker (Feature 2.6)
            ShipmentMilestoneTracker(importFile: s),

            // 🎯 Next Step & Target Action Card
            OperationalNextStepCard(
              shipment: s,
              isArabic: isArabic,
              onNavigate: onNavigate,
            ),

            // 📋 Linked Smart Tasks TO-DO List
            OperationalLinkedTasksSection(
              shipment: s,
              linkedTasks: linkedTasks,
              onTaskStatusChanged: onTaskStatusChanged,
              onManageAllTasks: onManageAllTasks,
            ),

            if (s.status == 'Closed' || s.closureReason != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.crimson.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: AppTheme.crimson, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CopyableText(
                        '🚫 ${l.closedShipment} [${OperationalFormatHelper.formatStageName(s.closedAtPhase ?? s.displayStepKey, isArabic: isArabic)}] — ${s.closureReason ?? s.displayStage(l, (t) => OperationalFormatHelper.formatStageName(t, isArabic: isArabic))}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (onRecordDailyUpdate != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                      side: BorderSide(color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.post_add_rounded, size: 14),
                    label: Text(l.recordDailyUpdate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: onRecordDailyUpdate,
                  ),
                if (s.status != 'Closed' && onSkipStep != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppTheme.wcagOrange : AppTheme.orange,
                      side: BorderSide(color: isDark ? AppTheme.wcagOrange : AppTheme.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.fast_forward_rounded, size: 14),
                    label: Text(l.skipStepBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: onSkipStep,
                  ),
                if (s.status != 'Closed' && onCloseShipment != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.wcagCrimson : AppTheme.crimson,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.white),
                    label: Text(l.closeStopShipment, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: onCloseShipment,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
