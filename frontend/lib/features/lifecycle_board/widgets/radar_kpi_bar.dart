import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/lifecycle_board_model.dart';
import 'lifecycle_board_kpi_card.dart';

/// Horizontal KPI metrics bar for the Live Logistics Tracking Radar.
class RadarKpiBar extends StatelessWidget {
  final LiveLogisticsSummaryModel radarData;
  final ScrollController? controller;

  const RadarKpiBar({
    super.key,
    required this.radarData,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SelectionArea(
      child: Container(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              LifecycleBoardKpiCard(
                title: l10n.kpiInTransit,
                value: '${radarData.inTransitCount}',
                icon: Icons.sailing,
                color: AppTheme.cobalt,
              ),
              const SizedBox(width: 8),
              LifecycleBoardKpiCard(
                title: l10n.kpiInPort,
                value: '${radarData.inPortCount}',
                icon: Icons.anchor,
                color: const Color(0xFF8E44AD),
              ),
              const SizedBox(width: 8),
              LifecycleBoardKpiCard(
                title: l10n.kpiHighDemurrageRisk,
                value: '${radarData.highRiskDemurrageCount}',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.crimson,
                isAlert: radarData.highRiskDemurrageCount > 0,
              ),
              const SizedBox(width: 8),
              LifecycleBoardKpiCard(
                title: l10n.kpiUnderTesting,
                value: '${radarData.underSampleTestingCount}',
                icon: Icons.biotech,
                color: AppTheme.orange,
              ),
              const SizedBox(width: 8),
              LifecycleBoardKpiCard(
                title: l10n.kpiIncompleteDocs,
                value: '${radarData.incompleteDocumentsCount}',
                icon: Icons.folder_delete_outlined,
                color: Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
