import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/import_files/models/import_file_model.dart';
import '../../features/import_files/providers/import_files_provider.dart';
import '../../features/lifecycle_board/widgets/skip_step_dialog_helper.dart';
import '../../features/smart_tasks/models/smart_task_model.dart';
import '../../features/smart_tasks/providers/smart_tasks_provider.dart';
import '../localization/app_localizations.dart';
import '../models/active_shipment_context.dart';
import '../providers/ai_assistant_provider.dart';
import '../theme/app_theme.dart';
import 'copyable_data_helper.dart';
import '../utils/shipment_task_formatter.dart';

/// Interactive Lifecycle Navigator widget exposed as Surface 2 of the AI Assistant.
/// Displays shipment selector, 10-block completion rate, visual 10-phase stage map
/// with semantic color coding, and contextual quick actions.
///
/// Complies with Section 2.3 & 2.3.1:
/// - Orientation rule: Vertical stacked list, one step per row, full width in chat panel.
/// - Progressive disclosure: Defaults to collapsed showing ONLY current step + overdue steps.
/// - Fallback: Shows single next actionable step if zero current/overdue steps exist.
/// - Expand toggle: 'عرض كل المراحل (+N)' expands to all 10 steps.
class ShipmentLifecycleNavigator extends ConsumerStatefulWidget {
  final void Function(String prompt)? onSendMessage;
  final bool forceVertical;

  const ShipmentLifecycleNavigator({
    super.key,
    this.onSendMessage,
    this.forceVertical = true,
  });

  static const List<Map<String, String>> kLifecycleSteps = [
    {
      'id': '1',
      'nameAr': 'الجدوى والنولون',
      'nameEn': 'Feasibility & Freight',
      'screen': 'شاشة عروض الأسعار والجدوى',
    },
    {
      'id': '2',
      'nameAr': 'الموافقة المالية',
      'nameEn': 'Financial Approval',
      'screen': 'شاشة أوامر الشراء والاعتماد',
    },
    {
      'id': '3',
      'nameAr': 'المستندات ونافذة',
      'nameEn': 'Documents & ACID',
      'screen': 'شاشة متابعة منظومة نافذة والإفراج',
    },
    {
      'id': '4',
      'nameAr': 'حجز الشحن',
      'nameEn': 'Freight Booking',
      'screen': 'شاشة حجز الشحن والناقل',
    },
    {
      'id': '5',
      'nameAr': 'تخصيص الحاويات',
      'nameEn': 'Container Allocation',
      'screen': 'شاشة شحن وتجهيز البضاعة (المرحلة 5)',
    },
    {
      'id': '6',
      'nameAr': 'إقرار 46 جمرك',
      'nameEn': 'Customs Dec. 46',
      'screen': 'شاشة التخليص الجمركي وإقرار 46',
    },
    {
      'id': '7',
      'nameAr': 'التخليص والسداد',
      'nameEn': 'Clearance & Duty',
      'screen': 'شاشة سداد الرسوم والضرائب الجمركية',
    },
    {
      'id': '8',
      'nameAr': 'استلام المخازن',
      'nameEn': 'Warehouse Delivery',
      'screen': 'شاشة فحص البضاعة واستلام المخزن',
    },
    {
      'id': '9',
      'nameAr': 'التسوية الشاملة',
      'nameEn': 'Reconciliation',
      'screen': 'شاشة تكلفة الوصول والتسوية المالية',
    },
    {
      'id': '10',
      'nameAr': 'إغلاق والأرشفة',
      'nameEn': 'Archive & Closure',
      'screen': 'شاشة إغلاق ملف الشحنة والأرشفة',
    },
  ];

  @override
  ConsumerState<ShipmentLifecycleNavigator> createState() =>
      _ShipmentLifecycleNavigatorState();
}

class _ShipmentLifecycleNavigatorState
    extends ConsumerState<ShipmentLifecycleNavigator> {
  bool _isExpanded = false;
  int? _lastShipmentId;

  int? _detectStepForTask(SmartTaskModel task) {
    final text =
        '${task.phaseName ?? ''} ${task.title} ${task.description ?? ''}'
            .toLowerCase();
    for (int i = 1; i <= 10; i++) {
      if (text.contains('phase $i') ||
          text.contains('phase$i') ||
          text.contains('مرحلة $i') ||
          text.contains('خطوة $i')) {
        return i;
      }
    }
    for (final s in ShipmentLifecycleNavigator.kLifecycleSteps) {
      final sId = int.tryParse(s['id']!) ?? 0;
      final ar = s['nameAr']!.toLowerCase();
      final en = s['nameEn']!.toLowerCase();
      if (ar.split(' ').any((w) => w.length > 3 && text.contains(w)) ||
          en.split(' ').any((w) => w.length > 3 && text.contains(w))) {
        return sId;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantProvider);
    final filesAsync = ref.watch(importFilesProvider);
    final isAr = state.isArabic;
    final l = context.l10n;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: SelectionArea(
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: _isExpanded ? 340 : 220,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: filesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Text(
                  isAr ? 'تعذر تحميل بيانات الشحنات' : 'Failed to load shipments',
                  style: const TextStyle(color: AppTheme.crimson, fontSize: 11),
                ),
              ),
            ),
            data: (files) {
              if (files.isEmpty) {
                return _buildEmptyState(context, isAr, l);
              }

              // Resolve target shipment
              final selectedId = state.selectedShipmentId ??
                  state.activeContext?.shipmentId ??
                  files.first.importFileId;

              final currentFile = files.firstWhere(
                (f) => f.importFileId == selectedId,
                orElse: () => files.first,
              );

              // Reset expanded toggle on shipment switch (Section 2.3.1 - not persisted)
              if (_lastShipmentId != currentFile.importFileId) {
                _lastShipmentId = currentFile.importFileId;
                _isExpanded = false;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderRow(context, currentFile, files, state, isAr, l),
                    const SizedBox(height: 8),
                    _buildCompletionRate(context, currentFile, isAr, l),
                    const SizedBox(height: 8),
                    _buildStageMap(context, currentFile, state, isAr, l),
                    if (state.hasActiveContext &&
                        state.activeContext!.shipmentId == currentFile.importFileId) ...[
                      const SizedBox(height: 8),
                      _buildStepQuickActions(context, state.activeContext!, isAr, l),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, bool isAr, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            isAr ? l.aiLifecycleNoShipments : 'No shipments registered yet',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(isAr ? l.aiLifecycleStartNewShipment : 'Start New Shipment'),
            onPressed: () => widget.onSendMessage?.call(
              isAr
                  ? 'كيف أبدأ إنشاء شحنة استيراد جديدة في النظام؟'
                  : 'How do I start creating a new import shipment in the system?',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header & Shipment Selector ──────────────────────────────────────────────

  Widget _buildHeaderRow(
    BuildContext context,
    ImportFileModel currentFile,
    List<ImportFileModel> files,
    AiAssistantState state,
    bool isAr,
    AppLocalizations l,
  ) {
    return Row(
      children: [
        const Icon(Icons.alt_route_rounded, size: 16, color: AppTheme.cobalt),
        const SizedBox(width: 6),
        Text(
          isAr ? l.aiLifecycleTitle : 'Lifecycle:',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.charcoal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: currentFile.importFileId,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.charcoal,
                ),
                items: files.map((file) {
                  final humanName = ShipmentTaskFormatter.formatShipmentLabel(
                    shipmentName: file.displayName,
                    clientName: file.companyName,
                    fileCode: file.importFileCode,
                  );
                  return DropdownMenuItem<int>(
                    value: file.importFileId,
                    child: Text(
                      humanName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newId) {
                  if (newId != null) {
                    ref.read(aiAssistantProvider.notifier).selectShipment(newId);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.cobalt),
          tooltip: isAr ? l.aiLifecycleCopySummaryTooltip : 'Copy lifecycle summary',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            final buffer = StringBuffer();
            buffer.writeln(isAr ? 'مسار الشحنة: ${currentFile.displayName}' : 'Shipment Lifecycle: ${currentFile.displayName}');
            buffer.writeln(isAr ? 'كود الملف: ${currentFile.importFileCode}' : 'File Code: ${currentFile.importFileCode}');
            buffer.writeln(isAr ? 'نسبة الإنجاز: ${(currentFile.progressPercent).round()}%' : 'Progress: ${(currentFile.progressPercent).round()}%');
            for (final step in ShipmentLifecycleNavigator.kLifecycleSteps) {
              final sNum = int.tryParse(step['id']!) ?? 1;
              final sName = isAr ? step['nameAr']! : step['nameEn']!;
              final sStatus = sNum < (currentFile.progressPercent / 10).round()
                  ? (isAr ? l.aiLifecycleStatusCompleted : 'Completed')
                  : (sNum == (currentFile.progressPercent / 10).round()
                      ? (isAr ? l.aiLifecycleStatusActive : 'Active')
                      : (isAr ? l.aiLifecycleStatusUpcoming : 'Upcoming'));
              buffer.writeln('$sNum. $sName — $sStatus');
            }
            CopyHelper.copy(context, buffer.toString(), customMessage: isAr ? l.aiLifecycleSummaryCopied : 'Lifecycle summary copied to clipboard');
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 16),
          tooltip: isAr ? l.aiLifecycleCloseTooltip : 'Close Navigator',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => ref.read(aiAssistantProvider.notifier).closeNavigator(),
        ),
      ],
    );
  }

  // ─── Completion Rate & 10-Block Bar ──────────────────────────────────────────

  Widget _buildCompletionRate(
    BuildContext context,
    ImportFileModel file,
    bool isAr,
    AppLocalizations l,
  ) {
    final completedSteps = (file.progressPercent / 10).round().clamp(0, 10);
    final percent = file.progressPercent.round().clamp(0, 100);

    // Tone cue colors & icons: 0-39% 🔴 | 40-74% 🟡 | 75-99% 🟢 | 100% ✅
    final Color toneColor;
    final String toneIcon;
    if (percent >= 100) {
      toneColor = AppTheme.emerald;
      toneIcon = '✅';
    } else if (percent >= 75) {
      toneColor = AppTheme.emerald;
      toneIcon = '🟢';
    } else if (percent >= 40) {
      toneColor = AppTheme.orange;
      toneIcon = '🟡';
    } else {
      toneColor = AppTheme.crimson;
      toneIcon = '🔴';
    }

    if (percent >= 100) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.emeraldLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.emeraldBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppTheme.emerald, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isAr
                    ? l.aiLifecycleAllCompleted
                    : 'All shipment stages successfully completed (100%).',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr
                    ? l.aiLifecycleCompletionRate(toneIcon, percent, completedSteps, 10)
                    : 'Completion Rate: $toneIcon $percent% ($completedSteps of 10 steps)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: toneColor,
                ),
              ),
              InkWell(
                onTap: () => CopyHelper.copy(
                  context,
                  file.importFileCode,
                  customMessage: isAr ? l.aiLifecycleFileCodeCopied : 'File code copied to clipboard',
                ),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          file.customFileNumber?.isNotEmpty == true
                              ? file.customFileNumber!
                              : file.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 10-block visual progress bar
          Row(
            children: List.generate(10, (index) {
              final isFilled = index < completedSteps;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsetsDirectional.only(end: index < 9 ? 2 : 0),
                  decoration: BoxDecoration(
                    color: isFilled ? toneColor : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Visual Stage Map (Section 2.3 & 2.3.1) ─────────────────────────────────

  Widget _buildStageMap(
    BuildContext context,
    ImportFileModel file,
    AiAssistantState state,
    bool isAr,
    AppLocalizations l,
  ) {
    final currentStepIndex = (file.progressPercent / 10).round().clamp(1, 10);

    // Identify overdue tasks for this file
    final tasks = ref.watch(smartTasksProvider).tasks;
    final now = DateTime.now();
    final overdueFileTasks = tasks.where((t) {
      if (t.importFileId != file.importFileId) return false;
      if (t.status == 'Completed' || t.status == 'Cancelled') return false;
      final overdueDays =
          ShipmentTaskFormatter.calculateOverdueDays(t.dueDate, now);
      return overdueDays != null && overdueDays > 0;
    }).toList();

    // Map overdue tasks to step IDs
    final overdueStepIds = <int>{};
    for (final t in overdueFileTasks) {
      final sId = _detectStepForTask(t);
      if (sId != null) {
        overdueStepIds.add(sId);
      }
    }
    // If overdue tasks exist on the file but didn't specify a phase, attach to current step
    if (overdueFileTasks.isNotEmpty && overdueStepIds.isEmpty) {
      overdueStepIds.add(currentStepIndex);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // If embedded in a wider surface outside the narrow chat panel, allow horizontal stepper
        if (!widget.forceVertical && constraints.maxWidth > 550) {
          return _buildHorizontalStageMap(
            context: context,
            file: file,
            state: state,
            isAr: isAr,
            currentStepIndex: currentStepIndex,
            overdueStepIds: overdueStepIds,
          );
        }

        // Section 2.3 & 2.3.1: Inside chat panel: strictly vertical stacked list with progressive disclosure
        return _buildVerticalStageMap(
          context: context,
          file: file,
          state: state,
          isAr: isAr,
          currentStepIndex: currentStepIndex,
          overdueStepIds: overdueStepIds,
          l: l,
        );
      },
    );
  }

  // ─── Section 2.3 & 2.3.1: Vertical Stacked List with Progressive Disclosure ──

  Widget _buildVerticalStageMap({
    required BuildContext context,
    required ImportFileModel file,
    required AiAssistantState state,
    required bool isAr,
    required int currentStepIndex,
    required Set<int> overdueStepIds,
    required AppLocalizations l,
  }) {
    // 2.3.1 Progressive disclosure: In collapsed view, show ONLY current + overdue steps
    List<Map<String, String>> visibleSteps;
    if (_isExpanded) {
      visibleSteps = ShipmentLifecycleNavigator.kLifecycleSteps;
    } else {
      visibleSteps = ShipmentLifecycleNavigator.kLifecycleSteps.where((step) {
        final stepNum = int.tryParse(step['id']!) ?? 1;
        final isCurrent = stepNum == currentStepIndex;
        final isOverdue = overdueStepIds.contains(stepNum);
        return isCurrent || isOverdue;
      }).toList();

      // Fallback rule: If zero current/overdue steps exist, fall back to showing
      // the single next actionable step instead of an empty collapsed state
      if (visibleSteps.isEmpty) {
        final fallbackNum =
            currentStepIndex.clamp(1, ShipmentLifecycleNavigator.kLifecycleSteps.length);
        visibleSteps = ShipmentLifecycleNavigator.kLifecycleSteps.where((step) {
          final stepNum = int.tryParse(step['id']!) ?? 1;
          return stepNum == fallbackNum;
        }).toList();
      }
    }

    final hiddenCount =
        ShipmentLifecycleNavigator.kLifecycleSteps.length - visibleSteps.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Vertical step rows
        ...visibleSteps.map((step) {
          final stepNum = int.tryParse(step['id']!) ?? 1;
          final isSelectedInContext = state.activeContext != null &&
              state.activeContext!.shipmentId == file.importFileId &&
              state.activeContext!.stepId == stepNum;

          return _buildVerticalStepRow(
            context: context,
            file: file,
            step: step,
            stepNum: stepNum,
            currentStepIndex: currentStepIndex,
            isOverdue: overdueStepIds.contains(stepNum),
            isSelectedInContext: isSelectedInContext,
            isAr: isAr,
            l: l,
          );
        }),

        // Progressive disclosure toggle button (Section 2.3.1)
        if (hiddenCount > 0 || _isExpanded)
          _buildToggleButton(hiddenCount: hiddenCount, isAr: isAr, l: l),
      ],
    );
  }

  // ─── Compact Single-Step Row (Section 2.3) ───────────────────────────────────

  Widget _buildVerticalStepRow({
    required BuildContext context,
    required ImportFileModel file,
    required Map<String, String> step,
    required int stepNum,
    required int currentStepIndex,
    required bool isOverdue,
    required bool isSelectedInContext,
    required bool isAr,
    required AppLocalizations l,
  }) {
    final isCurrent = stepNum == currentStepIndex;
    final isCompleted = stepNum < currentStepIndex && !isOverdue;

    // Status colors & icons
    final Color stepColor;
    final IconData stepIcon;
    final String statusText;
    final Widget statusSuffix;
    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeTextColor;

    if (isOverdue) {
      stepColor = AppTheme.crimson;
      stepIcon = Icons.error_rounded;
      statusText = isAr ? l.aiLifecycleStatusOverdue : 'Overdue';
      statusSuffix = const Text(' ⚠️', style: TextStyle(fontSize: 9));
      badgeBg = AppTheme.crimsonLight;
      badgeBorder = AppTheme.crimsonBorder;
      badgeTextColor = AppTheme.crimson;
    } else if (isCompleted) {
      stepColor = AppTheme.emerald;
      stepIcon = Icons.check_circle_rounded;
      statusText = isAr ? l.aiLifecycleStatusCompleted : 'Completed';
      statusSuffix = const Text(' ✓',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
      badgeBg = AppTheme.emeraldLight;
      badgeBorder = AppTheme.emeraldBorder;
      badgeTextColor = AppTheme.emerald;
    } else if (isCurrent) {
      stepColor = AppTheme.cobalt;
      stepIcon = Icons.radio_button_checked_rounded;
      statusText = isAr ? l.aiLifecycleStatusActive : 'Active';
      statusSuffix = const Text(' ●', style: TextStyle(fontSize: 8));
      badgeBg = AppTheme.cobaltLight;
      badgeBorder = AppTheme.cobaltBorder;
      badgeTextColor = AppTheme.cobalt;
    } else {
      stepColor = Colors.grey.shade400;
      stepIcon = Icons.radio_button_unchecked_rounded;
      statusText = isAr ? l.aiLifecycleStatusUpcoming : 'Upcoming';
      statusSuffix = const SizedBox.shrink();
      badgeBg = Colors.grey.shade100;
      badgeBorder = Colors.grey.shade300;
      badgeTextColor = Colors.grey.shade600;
    }

    final stepTitle = isAr ? step['nameAr']! : step['nameEn']!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          ref.read(aiAssistantProvider.notifier).setActiveStep(
                shipmentId: file.importFileId,
                shipmentName: file.displayName,
                clientName: file.companyName,
                fileCode: file.importFileCode,
                stepId: stepNum,
                screenReference: step['screen'],
              );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelectedInContext
                ? stepColor.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelectedInContext ? stepColor : Colors.grey.shade200,
              width: isSelectedInContext ? 1.5 : 1,
            ),
            boxShadow: isSelectedInContext
                ? [
                    BoxShadow(
                      color: stepColor.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Indicator icon per status
              Icon(stepIcon, size: 14, color: stepColor),
              const SizedBox(width: 6),
              // Step number and title (never truncated with ellipsis hiding the name)
              Expanded(
                child: Text(
                  '$stepNum. $stepTitle',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isCurrent || isSelectedInContext
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isSelectedInContext || isCurrent
                        ? AppTheme.charcoal
                        : Colors.grey.shade800,
                  ),
                  softWrap: true,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                    statusSuffix,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Progressive Disclosure Toggle Button ────────────────────────────────────

  Widget _buildToggleButton({
    required int hiddenCount,
    required bool isAr,
    required AppLocalizations l,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isExpanded
                    ? (isAr ? l.aiLifecycleHideStages : 'Hide other stages')
                    : (isAr
                        ? l.aiLifecycleShowAllStages(hiddenCount)
                        : 'Show all stages (+$hiddenCount)'),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cobalt,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: AppTheme.cobalt,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Wide Surface Horizontal Layout (Optional outside chat) ─────────────────

  Widget _buildHorizontalStageMap({
    required BuildContext context,
    required ImportFileModel file,
    required AiAssistantState state,
    required bool isAr,
    required int currentStepIndex,
    required Set<int> overdueStepIds,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ShipmentLifecycleNavigator.kLifecycleSteps.map((step) {
          final stepNum = int.tryParse(step['id']!) ?? 1;
          final isCompleted = stepNum < currentStepIndex;
          final isCurrent = stepNum == currentStepIndex;
          final isOverdue = overdueStepIds.contains(stepNum);

          final isSelectedInContext = state.activeContext != null &&
              state.activeContext!.shipmentId == file.importFileId &&
              state.activeContext!.stepId == stepNum;

          final Color stepColor;
          final Color stepBg;
          final IconData stepIcon;

          if (isCompleted) {
            stepColor = AppTheme.emerald;
            stepBg = AppTheme.emeraldLight;
            stepIcon = Icons.check_circle_rounded;
          } else if (isOverdue) {
            stepColor = AppTheme.crimson;
            stepBg = AppTheme.crimsonLight;
            stepIcon = Icons.warning_amber_rounded;
          } else if (isCurrent) {
            stepColor = AppTheme.cobalt;
            stepBg = AppTheme.cobaltLight;
            stepIcon = Icons.play_circle_fill_rounded;
          } else {
            stepColor = Colors.grey.shade500;
            stepBg = Colors.grey.shade100;
            stepIcon = Icons.radio_button_unchecked_rounded;
          }

          final stepTitle = isAr ? step['nameAr']! : step['nameEn']!;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                ref.read(aiAssistantProvider.notifier).setActiveStep(
                      shipmentId: file.importFileId,
                      shipmentName: file.displayName,
                      clientName: file.companyName,
                      fileCode: file.importFileCode,
                      stepId: stepNum,
                      screenReference: step['screen'],
                    );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelectedInContext ? stepBg : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelectedInContext ? stepColor : Colors.grey.shade300,
                    width: isSelectedInContext ? 1.8 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(stepIcon, size: 14, color: stepColor),
                        const SizedBox(width: 4),
                        Text(
                          '$stepNum',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: stepColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stepTitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isSelectedInContext
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelectedInContext
                            ? AppTheme.charcoal
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Step Contextual Quick Actions ──────────────────────────────────────────

  Widget _buildStepQuickActions(
    BuildContext context,
    ActiveShipmentContext ctx,
    bool isAr,
    AppLocalizations l,
  ) {
    final stepLabel = ctx.stepName(isAr ? 'ar' : 'en');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cobaltLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cobaltBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isAr ? l.aiLifecycleActionsFor(stepLabel) : 'Actions for: $stepLabel',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.cobalt,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildActionBtn(
            label: isAr ? l.aiLifecycleActionView : 'View Data',
            icon: Icons.bar_chart_rounded,
            onTap: () {
              widget.onSendMessage?.call(
                isAr
                    ? 'اعرض بيانات وموقف مرحلة ($stepLabel) لشحنة ${ctx.displayText("ar")}.'
                    : 'Show data and status of phase ($stepLabel) for shipment ${ctx.displayText("en")}.',
              );
            },
          ),
          const SizedBox(width: 4),
          _buildActionBtn(
            label: isAr ? l.aiLifecycleActionUpdate : 'Update',
            icon: Icons.edit_note_rounded,
            onTap: () {
              widget.onSendMessage?.call(
                isAr
                    ? 'أريد تحديث وتسجيل بيانات مرحلة ($stepLabel) لشحنة ${ctx.displayText("ar")}.'
                    : 'I want to update and record data for phase ($stepLabel) of shipment ${ctx.displayText("en")}.',
              );
            },
          ),
          const SizedBox(width: 4),
          _buildActionBtn(
            label: isAr ? l.aiLifecycleActionAsk : 'Ask',
            icon: Icons.help_outline_rounded,
            onTap: () {
              widget.onSendMessage?.call(
                isAr
                    ? 'ما هي المتطلبات والمستندات اللازمة لإنجاز مرحلة ($stepLabel)؟'
                    : 'What are the requirements and documents needed to complete ($stepLabel)?',
              );
            },
          ),
          const SizedBox(width: 4),
          _buildActionBtn(
            label: isAr ? l.aiLifecycleActionSkip : 'Skip',
            icon: Icons.fast_forward_rounded,
            color: AppTheme.orange,
            onTap: () {
              final stepCode = 'STEP_${ctx.stepId.toString().padLeft(2, '0')}';
              SkipStepDialogHelper.show(
                context: context,
                ref: ref,
                importFileCode: ctx.fileCode,
                currentStepCode: stepCode,
                currentStepName: stepLabel,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? AppTheme.cobalt;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: effectiveColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
