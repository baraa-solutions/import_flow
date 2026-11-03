import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../models/file_closure_model.dart';

/// Metrics cards strip for File Closure screen
class ClosureScreenMetrics extends StatelessWidget {
  final List<ImportFileClosureModel> records;
  final int stoppedFiles;

  const ClosureScreenMetrics({
    super.key,
    required this.records,
    required this.stoppedFiles,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final archived = records.where((r) => r.isFullyVerified).length;

    return MetricCardStrip(
      metrics: [
        MetricCardData(
          title: l.closureMetricRecords,
          shortTitle: l.closureMetricRecords,
          value: '${records.length}',
          icon: Icons.archive_outlined,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l.closureMetricArchived,
          shortTitle: l.closureMetricArchived,
          value: '$archived',
          icon: Icons.verified_outlined,
          color: AppTheme.emerald,
        ),
        MetricCardData(
          title: l.closureMetricDraft,
          shortTitle: l.closureMetricDraft,
          value: '${records.length - archived}',
          icon: Icons.edit_note,
          color: AppTheme.orange,
        ),
        MetricCardData(
          title: l.closureMetricStoppedFiles,
          shortTitle: l.closureMetricStoppedFiles,
          value: '$stoppedFiles',
          icon: Icons.history,
          color: AppTheme.crimson,
        ),
      ],
    );
  }
}
