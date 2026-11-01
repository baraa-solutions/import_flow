import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/import_files/models/import_file_model.dart';
import '../../features/import_files/providers/import_files_provider.dart';
import '../../features/smart_tasks/providers/smart_tasks_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/ai_assistant_provider.dart';
import '../theme/app_theme.dart';
import '../utils/shipment_task_formatter.dart';
import 'lifecycle_navigator/lifecycle_completion_bar.dart';
import 'lifecycle_navigator/lifecycle_constants.dart';
import 'lifecycle_navigator/lifecycle_header_row.dart';
import 'lifecycle_navigator/lifecycle_horizontal_stage_map.dart';
import 'lifecycle_navigator/lifecycle_quick_actions_bar.dart';
import 'lifecycle_navigator/lifecycle_vertical_step_row.dart';

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

  static const List<Map<String, String>> kLifecycleSteps =
      LifecycleConstants.kLifecycleSteps;

  @override
  ConsumerState<ShipmentLifecycleNavigator> createState() =>
      _ShipmentLifecycleNavigatorState();
}

class _ShipmentLifecycleNavigatorState
    extends ConsumerState<ShipmentLifecycleNavigator> {
  bool _isExpanded = false;
  int? _lastShipmentId;

  Widget _buildEmptyState(
      BuildContext context, bool isAr, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 36, color: Colors.grey.shade400),
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
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
                isAr ? l.aiLifecycleStartNewShipment : 'Start New Shipment'),
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

  Widget _buildVerticalStageMap({
    required BuildContext context,
    required ImportFileModel file,
    required AiAssistantState state,
    required bool isAr,
    required int currentStepIndex,
    required Set<int> overdueStepIds,
    required AppLocalizations l,
  }) {
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

      if (visibleSteps.isEmpty) {
        final fallbackNum = currentStepIndex.clamp(
            1, ShipmentLifecycleNavigator.kLifecycleSteps.length);
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
        ...visibleSteps.map((step) {
          final stepNum = int.tryParse(step['id']!) ?? 1;
          final isSelectedInContext = state.activeContext != null &&
              state.activeContext!.shipmentId == file.importFileId &&
              state.activeContext!.stepId == stepNum;

          return LifecycleVerticalStepRow(
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
        if (hiddenCount > 0 || _isExpanded)
          _buildToggleButton(hiddenCount: hiddenCount, isAr: isAr, l: l),
      ],
    );
  }

  Widget _buildStageMap(
    BuildContext context,
    ImportFileModel file,
    AiAssistantState state,
    bool isAr,
    AppLocalizations l,
  ) {
    final currentStepIndex = (file.progressPercent / 10).round().clamp(1, 10);

    final tasks = ref.watch(smartTasksProvider).tasks;
    final now = DateTime.now();
    final overdueFileTasks = tasks.where((t) {
      if (t.importFileId != file.importFileId) return false;
      if (t.status == 'Completed' || t.status == 'Cancelled') return false;
      final overdueDays =
          ShipmentTaskFormatter.calculateOverdueDays(t.dueDate, now);
      return overdueDays != null && overdueDays > 0;
    }).toList();

    final overdueStepIds = <int>{};
    for (final t in overdueFileTasks) {
      final sId = LifecycleConstants.detectStepForTask(t);
      if (sId != null) {
        overdueStepIds.add(sId);
      }
    }
    if (overdueFileTasks.isNotEmpty && overdueStepIds.isEmpty) {
      overdueStepIds.add(currentStepIndex);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!widget.forceVertical && constraints.maxWidth > 550) {
          return LifecycleHorizontalStageMap(
            file: file,
            state: state,
            isAr: isAr,
            currentStepIndex: currentStepIndex,
            overdueStepIds: overdueStepIds,
          );
        }

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
                  isAr
                      ? 'تعذر تحميل بيانات الشحنات'
                      : 'Failed to load shipments',
                  style: const TextStyle(color: AppTheme.crimson, fontSize: 11),
                ),
              ),
            ),
            data: (files) {
              if (files.isEmpty) {
                return _buildEmptyState(context, isAr, l);
              }

              final selectedId = state.selectedShipmentId ??
                  state.activeContext?.shipmentId ??
                  files.first.importFileId;

              final currentFile = files.firstWhere(
                (f) => f.importFileId == selectedId,
                orElse: () => files.first,
              );

              if (_lastShipmentId != currentFile.importFileId) {
                _lastShipmentId = currentFile.importFileId;
                _isExpanded = false;
              }

              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LifecycleHeaderRow(
                      currentFile: currentFile,
                      files: files,
                      isAr: isAr,
                      l: l,
                    ),
                    const SizedBox(height: 8),
                    LifecycleCompletionBar(
                      file: currentFile,
                      isAr: isAr,
                      l: l,
                    ),
                    const SizedBox(height: 8),
                    _buildStageMap(context, currentFile, state, isAr, l),
                    if (state.hasActiveContext &&
                        state.activeContext!.shipmentId ==
                            currentFile.importFileId) ...[
                      const SizedBox(height: 8),
                      LifecycleQuickActionsBar(
                        ctx: state.activeContext!,
                        isAr: isAr,
                        l: l,
                        onSendMessage: widget.onSendMessage,
                      ),
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
}
