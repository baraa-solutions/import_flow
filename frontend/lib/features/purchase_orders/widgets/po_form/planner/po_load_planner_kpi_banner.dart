import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../utils/po_packing_matcher.dart';

class PoLoadPlannerKpiBanner extends StatelessWidget {
  final String fleetSummary;
  final int totalPkgs;
  final int stackableInActive;
  final int nonStackableInActive;
  final double totalPlanWeight;
  final double totalPlanVolume;

  const PoLoadPlannerKpiBanner({
    super.key,
    required this.fleetSummary,
    required this.totalPkgs,
    required this.stackableInActive,
    required this.nonStackableInActive,
    required this.totalPlanWeight,
    required this.totalPlanVolume,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.charcoal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.charcoal.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 6),
              Text(
                context.l10n.requiredContainersSummary(fleetSummary),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: AppTheme.charcoal, size: 18),
              const SizedBox(width: 6),
              Text(
                context.l10n.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
              const SizedBox(width: 6),
              Text(
                context.l10n.totalWeightSummary(PoPackingMatcher.formatWeight(totalPlanWeight)),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
              const SizedBox(width: 6),
              Text(
                context.l10n.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
