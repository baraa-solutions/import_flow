import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/timeline_snapshot_model.dart';
import '../providers/lifecycle_board_provider.dart';
import 'timeline/shipment_stage_snapshot_card.dart';
import 'timeline/shipment_timeline_dialog_header.dart';
import 'timeline/shipment_timeline_filter_chips.dart';
import 'timeline/shipment_timeline_kpi_ribbon.dart';

/// 25-Stage Master Timeline Dossier Modal Dialog (TASK-BE-09).
/// Displays real-time operational synchronization, SLA variance, bottleneck
/// detection, and domain sub-events across all 6 phases.
class ShipmentTimelineDossierDialog extends ConsumerStatefulWidget {
  final int importFileId;
  final String importFileCode;

  const ShipmentTimelineDossierDialog({
    super.key,
    required this.importFileId,
    required this.importFileCode,
  });

  static Future<void> show(
    BuildContext context, {
    required int importFileId,
    required String importFileCode,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ShipmentTimelineDossierDialog(
        importFileId: importFileId,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<ShipmentTimelineDossierDialog> createState() =>
      _ShipmentTimelineDossierDialogState();
}

class _ShipmentTimelineDossierDialogState
    extends ConsumerState<ShipmentTimelineDossierDialog> {
  int? _selectedPhaseNumber;
  bool _onlyBottlenecks = false;
  bool _onlyDelayed = false;
  bool _isSyncing = false;

  Future<void> _triggerSync(AppLocalizations l) async {
    setState(() => _isSyncing = true);
    try {
      final success = await ref
          .read(lifecycleBoardActionProvider.notifier)
          .syncFileTimeline(widget.importFileId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.isArabic
                  ? 'تمت مزامنة المسار الزمني التشغيلي للمراحل الـ 25 بنجاح'
                  : 'Operational timeline synchronized successfully (25 stages)',
              severity: AppSeverity.success,
            ),
          );
        } else {
          final err = ref.read(lifecycleBoardActionProvider.notifier).lastErrorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              err ?? (l.isArabic ? 'فشلت المزامنة' : 'Sync failed'),
              severity: AppSeverity.danger,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = l.isArabic;
    final screen = MediaQuery.of(context).size;
    final dialogWidth = screen.width > 960 ? 940.0 : screen.width * 0.95;

    final timelineAsync = ref.watch(timelineSnapshotsProvider(widget.importFileId));

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SelectionArea(
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: screen.height * 0.92),
          child: Column(
            children: [
              ShipmentTimelineDialogHeader(
                importFileCode: widget.importFileCode,
                isSyncing: _isSyncing,
                onTriggerSync: () => _triggerSync(l),
              ),
              Expanded(
                child: timelineAsync.when(
                  loading: () => const AppLoadingState(),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppTheme.crimson),
                          const SizedBox(height: 12),
                          Text(
                            ApiErrorText.of(l, err),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            label: isAr ? 'إعادة المحاولة والمزامنة' : 'Retry & Sync',
                            icon: Icons.sync,
                            onPressed: () => _triggerSync(l),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (summary) => _buildTimelineBody(context, summary, isAr),
                ),
              ),
              _buildDialogFooter(context, isAr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineBody(
    BuildContext context,
    TimelineSummaryModel summary,
    bool isAr,
  ) {
    final filtered = summary.snapshots.where((s) {
      if (_selectedPhaseNumber != null && s.phaseNumber != _selectedPhaseNumber) {
        return false;
      }
      if (_onlyBottlenecks && !s.isBottleneck) {
        return false;
      }
      if (_onlyDelayed && s.status != 'DELAYED') {
        return false;
      }
      return true;
    }).toList();

    final completionPercent = summary.totalStages > 0
        ? (summary.completedStages / summary.totalStages * 100).clamp(0, 100).toInt()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShipmentTimelineKpiRibbon(
            summary: summary,
            completionPercent: completionPercent,
            isAr: isAr,
          ),
          const SizedBox(height: 16),
          ShipmentTimelineFilterChips(
            selectedPhaseNumber: _selectedPhaseNumber,
            onPhaseSelected: (val) => setState(() => _selectedPhaseNumber = val),
            onlyBottlenecks: _onlyBottlenecks,
            onBottlenecksChanged: (val) => setState(() => _onlyBottlenecks = val),
            onlyDelayed: _onlyDelayed,
            onDelayedChanged: (val) => setState(() => _onlyDelayed = val),
            isAr: isAr,
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.filter_list_off, size: 40, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    isAr
                        ? 'لا توجد مراحل تطابق الفلتر المحدد'
                        : 'No stages match the selected filter',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final snapshot = filtered[index];
                return ShipmentStageSnapshotCard(
                  snapshot: snapshot,
                  isAr: isAr,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(BuildContext context, bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusXl),
        ),
        border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isAr
                ? 'مزامنة تلقائية مع أحداث الحجز الملاحي، التخليص، وإذن التسليم والمستودع.'
                : 'Auto-synchronized with freight, clearance, delivery order, and warehouse records.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          AppButton(
            label: isAr ? 'إغلاق' : 'Close',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
