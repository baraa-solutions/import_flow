import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/timeline_snapshot_model.dart';

class ShipmentStageSnapshotCard extends StatelessWidget {
  final TimelineSnapshotModel snapshot;
  final bool isAr;

  const ShipmentStageSnapshotCard({
    super.key,
    required this.snapshot,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final isBottleneck = snapshot.isBottleneck;
    final variance = snapshot.varianceDays ?? 0.0;
    final varianceColor = variance > 0
        ? AppTheme.crimson
        : (snapshot.status == 'COMPLETED' ? AppTheme.emerald : AppTheme.cobalt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isBottleneck
              ? AppTheme.crimson.withValues(alpha: 0.7)
              : (snapshot.status == 'IN_PROGRESS'
                  ? AppTheme.cobalt.withValues(alpha: 0.4)
                  : AppTheme.borderOf(context)),
          width: isBottleneck ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.charcoal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'P${snapshot.phaseNumber} • ${snapshot.stageCode}',
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
                  snapshot.stageName,
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
              AppStatusBadge.fromStatus(status: snapshot.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDateInfo(
                  context,
                  label: isAr ? 'المخطط (Planned)' : 'Planned',
                  start: snapshot.plannedStartDate,
                  end: snapshot.plannedEndDate,
                ),
              ),
              Expanded(
                child: _buildDateInfo(
                  context,
                  label: isAr ? 'الفعلي (Actual)' : 'Actual',
                  start: snapshot.actualStartDate,
                  end: snapshot.actualEndDate,
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
                      'SLA: ${snapshot.slaDays ?? 0}d',
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
          if (snapshot.delayReason != null && snapshot.delayReason!.isNotEmpty) ...[
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
                      snapshot.delayReason!,
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
          if (snapshot.eventDetailsJson != null && snapshot.eventDetailsJson!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: snapshot.eventDetailsJson!.entries.map((entry) {
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

  Widget _buildDateInfo(
    BuildContext context, {
    required String label,
    required String? start,
    required String? end,
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
}
