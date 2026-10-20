import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/shipment_inquiry_provider.dart';

/// Smart Insight Bar (شريط الملخص الذكي ومؤشرات الشحن — UX-SEARCH-013 Section 3.1)
/// Displays 5 aggregated analytical KPI metrics calculated in real-time from matching shipments:
/// 1. Usual Route (Mode of POL -> POD)
/// 2. Usual Shipping Method (Mode of FCL/LCL/Air/Land)
/// 3. Latest Freight Rate (From most recent shipment by date, not average)
/// 4. Average Final Landed Cost (Landed cost / Total cost)
/// 5. Matching Shipments Count
class SmartInsightBar extends ConsumerWidget {
  const SmartInsightBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final insights = ref.watch(shipmentInquiryInsightsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bar Header Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.auto_graph_rounded, color: AppTheme.cobalt, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                l.inqInsightBarTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5 Insight Metric Cards
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              // 1. Matching Shipments Count
              _buildInsightCard(
                icon: Icons.inventory_2_outlined,
                color: AppTheme.cobalt,
                label: l.inqInsightMatchingCount,
                value: '${insights.totalCount}',
                subtitle: null,
              ),

              // 2. Usual Route (Mode POL -> POD)
              _buildInsightCard(
                icon: Icons.alt_route_rounded,
                color: Colors.teal.shade700,
                label: l.inqInsightModeRoute,
                value: insights.modeRoute,
                subtitle: null,
              ),

              // 3. Usual Shipping Method (Mode FCL/LCL/Air/Land)
              _buildInsightCard(
                icon: Icons.directions_boat_outlined,
                color: Colors.indigo.shade700,
                label: l.inqInsightModeShippingMode,
                value: insights.modeShippingMode,
                subtitle: null,
              ),

              // 4. Latest Freight Rate (Most recent shipment, NOT average)
              _buildInsightCard(
                icon: Icons.payments_outlined,
                color: AppTheme.orange,
                label: l.inqInsightLatestFreight,
                value: insights.latestFreightCost != null
                    ? '${insights.latestFreightCost!.toStringAsFixed(0)} ${insights.latestFreightCurrency}'
                    : '-',
                subtitle: l.inqInsightLatestFreightNote,
              ),

              // 5. Average Final Landed Cost
              _buildInsightCard(
                icon: Icons.account_balance_wallet_outlined,
                color: AppTheme.emerald,
                label: l.inqInsightAvgLandedCost,
                value: insights.avgLandedCost > 0
                    ? '${insights.avgLandedCost.toStringAsFixed(0)} ${insights.avgLandedCurrency}'
                    : '-',
                subtitle: null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 165),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
