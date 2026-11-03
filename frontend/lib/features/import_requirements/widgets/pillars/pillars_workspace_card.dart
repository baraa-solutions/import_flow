import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import 'adaptive_pillar_alert_banner.dart';

/// 🏛️ 5 Pillars Interactive Workspace Card — ImportFlow ERP
///
/// Orchestrates the 5 regulatory compliance pillars (Decree 43, COO, PSI,
/// Prior Permits, Technical Certificates & Sailing Clearance) with sub-tab
/// switching, adaptive statutory banners, and fulfillment status indicators.
class PillarsWorkspaceCard extends StatelessWidget {
  final int activePillarIndex;
  final ValueChanged<int> onPillarTabSelected;
  final bool whiteListVerified;
  final bool cooFulfilled;
  final bool inspectionFulfilled;
  final bool permitFulfilled;
  final bool techCertsFulfilled;
  final Widget pillar1Child;
  final Widget pillar2Child;
  final Widget pillar3Child;
  final Widget pillar4Child;
  final Widget pillar5Child;
  final String hsCode;
  final String commodityDescription;

  const PillarsWorkspaceCard({
    super.key,
    required this.activePillarIndex,
    required this.onPillarTabSelected,
    required this.whiteListVerified,
    required this.cooFulfilled,
    required this.inspectionFulfilled,
    required this.permitFulfilled,
    required this.techCertsFulfilled,
    required this.pillar1Child,
    required this.pillar2Child,
    required this.pillar3Child,
    required this.pillar4Child,
    required this.pillar5Child,
    required this.hsCode,
    required this.commodityDescription,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cloudWhite),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sub-tabs Selector for 5 Pillars
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                color: AppTheme.charcoalSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                border: Border(bottom: BorderSide(color: AppTheme.cloudWhite)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPillarTabButton(
                      index: 0,
                      title: l10n.pillar1Decree43Tab,
                      icon: Icons.factory_outlined,
                      isFulfilled: whiteListVerified,
                    ),
                    _buildPillarTabButton(
                      index: 1,
                      title: l10n.pillar2CooTab,
                      icon: Icons.public,
                      isFulfilled: cooFulfilled,
                    ),
                    _buildPillarTabButton(
                      index: 2,
                      title: l10n.pillar3InspectionTab,
                      icon: Icons.fact_check_outlined,
                      isFulfilled: inspectionFulfilled,
                    ),
                    _buildPillarTabButton(
                      index: 3,
                      title: l10n.pillar4PermitsTab,
                      icon: Icons.account_balance_outlined,
                      isFulfilled: permitFulfilled,
                    ),
                    _buildPillarTabButton(
                      index: 4,
                      title: l10n.pillar5TechCertsTab,
                      icon: Icons.science_outlined,
                      isFulfilled: techCertsFulfilled,
                    ),
                  ],
                ),
              ),
            ),

            // Pillar Content Area
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdaptivePillarAlertBanner(
                    activePillarIndex: activePillarIndex,
                    hsCode: hsCode,
                    commodityDescription: commodityDescription,
                  ),
                  IndexedStack(
                    index: activePillarIndex,
                    children: [
                      pillar1Child,
                      pillar2Child,
                      pillar3Child,
                      pillar4Child,
                      pillar5Child,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarTabButton({
    required int index,
    required String title,
    required IconData icon,
    required bool isFulfilled,
  }) {
    final isSelected = activePillarIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => onPillarTabSelected(index),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.cobalt : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppTheme.white : AppTheme.charcoal),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? AppTheme.white : AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 6),
              if (isFulfilled)
                const Icon(Icons.check_circle, size: 14, color: AppTheme.emerald)
              else
                Icon(Icons.circle_outlined, size: 12, color: isSelected ? Colors.white70 : AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
