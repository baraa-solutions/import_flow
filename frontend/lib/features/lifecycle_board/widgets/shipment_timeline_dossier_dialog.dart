import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/timeline_snapshot_model.dart';
import '../providers/lifecycle_board_provider.dart';

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
            // Header
            _buildDialogHeader(context, isAr, l),

            // Body
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
                data: (summary) => _buildTimelineBody(context, summary, isAr, l),
              ),
            ),

            // Footer
            _buildDialogFooter(context, isAr),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context, bool isAr, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.timeline_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isAr
                          ? 'سجل المسار الزمني التشغيلي (25 مرحلة)'
                          : 'Master Operational Timeline Dossier (25 Stages)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: LtrText(
                        widget.importFileCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isAr
                      ? 'متابعة حية لمطابقة الـ SLA، انحرافات المواعيد، ونقاط الاختناق التشغيلية'
                      : 'Live tracking of stage SLAs, schedule variances, and bottleneck constraints',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            label: isAr ? 'مزامنة المسار' : 'Sync Timeline',
            icon: Icons.sync,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            isLoading: _isSyncing,
            onPressed: () => _triggerSync(l),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: isAr ? 'إغلاق' : 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineBody(
    BuildContext context,
    TimelineSummaryModel summary,
    bool isAr,
    AppLocalizations l,
  ) {
    // Filter snapshots
    var filtered = summary.snapshots.where((s) {
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
          // KPI Metric Ribbon
          _buildKpiRibbon(summary, completionPercent, isAr),
          const SizedBox(height: 16),

          // Filters row
          _buildFilterChips(isAr),
          const SizedBox(height: 14),

          // Timeline Stages List
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
                return _buildStageSnapshotCard(snapshot, isAr, l);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiRibbon(
    TimelineSummaryModel summary,
    int completionPercent,
    bool isAr,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildKpiTile(
                title: isAr ? 'المراحل الإجمالية' : 'Total Stages',
                value: '${summary.totalStages}',
                color: AppTheme.charcoal,
                icon: Icons.flag_outlined,
              ),
              _buildDivider(),
              _buildKpiTile(
                title: isAr ? 'مكتملة' : 'Completed',
                value: '${summary.completedStages}',
                color: AppTheme.emerald,
                icon: Icons.check_circle_outline,
              ),
              _buildDivider(),
              _buildKpiTile(
                title: isAr ? 'جارية تشغيلياً' : 'In Progress',
                value: '${summary.inProgressStages}',
                color: AppTheme.cobalt,
                icon: Icons.play_arrow_outlined,
              ),
              _buildDivider(),
              _buildKpiTile(
                title: isAr ? 'متأخرة عن SLA' : 'Delayed',
                value: '${summary.delayedStages}',
                color: summary.delayedStages > 0 ? AppTheme.orange : AppTheme.charcoal,
                icon: Icons.timer_off_outlined,
              ),
              _buildDivider(),
              _buildKpiTile(
                title: isAr ? 'نقاط اختناق حرجة' : 'Bottlenecks',
                value: '${summary.bottlenecksCount}',
                color: summary.bottlenecksCount > 0 ? AppTheme.crimson : AppTheme.charcoal,
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: completionPercent / 100.0,
                    minHeight: 8,
                    backgroundColor: AppTheme.borderOf(context),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completionPercent%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: AppTheme.borderOf(context),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildFilterChips(bool isAr) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: Text(isAr ? 'جميع المراحل' : 'All Phases'),
          selected: _selectedPhaseNumber == null,
          onSelected: (_) => setState(() => _selectedPhaseNumber = null),
          selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
          checkmarkColor: AppTheme.cobalt,
        ),
        for (int p = 1; p <= 6; p++)
          FilterChip(
            label: Text('${isAr ? "المرحلة" : "Phase"} $p'),
            selected: _selectedPhaseNumber == p,
            onSelected: (_) => setState(() => _selectedPhaseNumber = p),
            selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
            checkmarkColor: AppTheme.cobalt,
          ),
        const SizedBox(width: 8),
        FilterChip(
          avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.crimson),
          label: Text(
            isAr ? 'نقاط الاختناق فقط' : 'Bottlenecks Only',
            style: TextStyle(color: _onlyBottlenecks ? AppTheme.crimson : null),
          ),
          selected: _onlyBottlenecks,
          onSelected: (val) => setState(() => _onlyBottlenecks = val),
          selectedColor: AppTheme.crimson.withValues(alpha: 0.15),
          checkmarkColor: AppTheme.crimson,
        ),
        FilterChip(
          avatar: const Icon(Icons.timer_off_outlined, size: 16, color: AppTheme.orange),
          label: Text(
            isAr ? 'المتأخرة عن الـ SLA' : 'Delayed Only',
            style: TextStyle(color: _onlyDelayed ? AppTheme.orange : null),
          ),
          selected: _onlyDelayed,
          onSelected: (val) => setState(() => _onlyDelayed = val),
          selectedColor: AppTheme.orange.withValues(alpha: 0.15),
          checkmarkColor: AppTheme.orange,
        ),
      ],
    );
  }

  Widget _buildStageSnapshotCard(
    TimelineSnapshotModel s,
    bool isAr,
    AppLocalizations l,
  ) {
    final isBottleneck = s.isBottleneck;
    final variance = s.varianceDays ?? 0.0;
    final varianceColor = variance > 0
        ? AppTheme.crimson
        : (s.status == 'COMPLETED' ? AppTheme.emerald : AppTheme.cobalt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isBottleneck
              ? AppTheme.crimson.withValues(alpha: 0.7)
              : (s.status == 'IN_PROGRESS'
                  ? AppTheme.cobalt.withValues(alpha: 0.4)
                  : AppTheme.borderOf(context)),
          width: isBottleneck ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.charcoal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'P${s.phaseNumber} • ${s.stageCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.stageName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isBottleneck) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        isAr ? 'اختناق تشغيلي' : 'Bottleneck',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              _buildStatusBadge(s.status, isAr),
            ],
          ),
          const SizedBox(height: 8),

          // Operational Dates & SLA row
          Row(
            children: [
              Expanded(
                child: _buildDateInfo(
                  label: isAr ? 'المخطط (Planned)' : 'Planned',
                  start: s.plannedStartDate,
                  end: s.plannedEndDate,
                  isAr: isAr,
                ),
              ),
              Expanded(
                child: _buildDateInfo(
                  label: isAr ? 'الفعلي (Actual)' : 'Actual',
                  start: s.actualStartDate,
                  end: s.actualEndDate,
                  isAr: isAr,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: varianceColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: varianceColor.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'SLA: ${s.slaDays ?? 0}d',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                    Text(
                      '${variance > 0 ? "+" : ""}${variance.toStringAsFixed(0)}d ${isAr ? "انحراف" : "var"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: varianceColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Delay reason / alert banner if present
          if (s.delayReason != null && s.delayReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.crimson.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.crimson),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.delayReason!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.crimson,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Sub-event metadata chips (if any)
          if (s.eventDetailsJson != null && s.eventDetailsJson!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: s.eventDetailsJson!.entries.map((entry) {
                final k = entry.key.replaceAll('_', ' ');
                final v = entry.value.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.charcoal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$k: ',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                      LtrText(
                        v,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateInfo({
    required String label,
    required String? start,
    required String? end,
    required bool isAr,
  }) {
    final startStr = start ?? '—';
    final endStr = end ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LtrText(
              startStr,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Text(' → ', style: TextStyle(fontSize: 11, color: Colors.grey)),
            LtrText(
              endStr,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, bool isAr) {
    return AppStatusBadge.fromStatus(status: status);
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
