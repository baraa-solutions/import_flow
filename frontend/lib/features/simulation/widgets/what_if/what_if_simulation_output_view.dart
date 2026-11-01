import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class WhatIfSimulationOutputView extends StatelessWidget {
  final Map<String, dynamic>? simulationResult;
  final VoidCallback onCopySummary;
  final VoidCallback onSaveScenario;

  const WhatIfSimulationOutputView({
    super.key,
    required this.simulationResult,
    required this.onCopySummary,
    required this.onSaveScenario,
  });

  @override
  Widget build(BuildContext context) {
    if (simulationResult == null) {
      return _buildPlaceholderGuide(context);
    }
    return _buildSimulationOutput(context);
  }

  Widget _buildPlaceholderGuide(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Card(
        elevation: 0,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.query_stats, size: 56, color: AppTheme.cobalt.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text(
                l10n.whatIfPlaceholderTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 480,
                child: Text(
                  l10n.whatIfPlaceholderDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationOutput(BuildContext context) {
    final l10n = context.l10n;
    final res = simulationResult!;
    final base = res['baseline_summary'] as Map<String, dynamic>;
    final sim = res['simulated_summary'] as Map<String, dynamic>;
    final varMap = res['variances'] as Map<String, dynamic>;
    final acid = res['acid_risk_analysis'] as Map<String, dynamic>;
    final dem = res['demurrage_and_storage'] as Map<String, dynamic>;
    final recommendations = (res['hedging_recommendations'] as List<dynamic>?) ?? [];
    final riskLevel = res['risk_level'] as String? ?? 'LOW';

    Color riskColor = AppTheme.emerald;
    if (riskLevel == 'CRITICAL') riskColor = AppTheme.crimson;
    if (riskLevel == 'HIGH') riskColor = AppTheme.orange;
    if (riskLevel == 'MEDIUM') riskColor = Colors.amber.shade700;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar: Risk Level & Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: riskColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: riskColor, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.whatIfRiskLevel} $riskLevel',
                      style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onCopySummary,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.whatIfCopyScenarioSummary),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onSaveScenario,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.whatIfSaveScenario),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Primary Metric: Landed Cost Variance
          Card(
            elevation: 0,
            color: AppTheme.cobaltLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.cobaltBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfBaselineLandedCost, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        CopyableText(
                          '${(base['total_landed_cost_egp'] as num).toStringAsFixed(2)} ${l10n.egpCurrency}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfSimulatedLandedCost, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        CopyableText(
                          '${(sim['total_landed_cost_egp'] as num).toStringAsFixed(2)} ${l10n.egpCurrency}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: riskColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        CopyableText(
                          '+${(varMap['landed_cost_variance_pct'] as num).toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        CopyableText(
                          '+${(varMap['landed_cost_variance_egp'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary Metrics: Taxes & Demurrage
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfCustomsTaxVariance, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        CopyableText(
                          '+${((varMap['customs_duty_variance_egp'] as num) + (varMap['vat_variance_egp'] as num)).toStringAsFixed(2)} ${l10n.egpCurrency}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfShippingDemurrage, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        CopyableText(
                          '\$${(dem['demurrage_cost_usd'] as num).toStringAsFixed(0)} (${(dem['extra_demurrage_days'] as num)} ${l10n.whatIfDaysUnit})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.crimson),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfPortStorage, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        CopyableText(
                          '${(dem['port_storage_cost_egp'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.orange),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ACID Regulatory Expiry Card
          if (acid['status'] != 'NOT_APPLICABLE') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: acid['status'] == 'EXPIRED_RISK'
                    ? AppTheme.crimsonLight
                    : (acid['status'] == 'CRITICAL_WINDOW' ? AppTheme.orangeLight : Colors.green.shade50),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: acid['status'] == 'EXPIRED_RISK'
                      ? AppTheme.crimson
                      : (acid['status'] == 'CRITICAL_WINDOW' ? AppTheme.orange : AppTheme.emerald),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    acid['status'] == 'EXPIRED_RISK'
                        ? Icons.dangerous
                        : (acid['status'] == 'CRITICAL_WINDOW' ? Icons.alarm : Icons.verified),
                    color: acid['status'] == 'EXPIRED_RISK'
                        ? AppTheme.crimson
                        : (acid['status'] == 'CRITICAL_WINDOW' ? AppTheme.orange : AppTheme.emerald),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.whatIfAcidExpiryCheck,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: acid['status'] == 'EXPIRED_RISK' ? AppTheme.crimson : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (Localizations.localeOf(context).languageCode == 'en'
                                  ? acid['message_en']
                                  : acid['message_ar']) as String? ??
                              (acid['message_ar'] as String? ?? ''),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Strategic Advice & Hedging Actions
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.cobalt),
                      const SizedBox(width: 8),
                      Text(
                        l10n.whatIfStrategicRecommendations,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...recommendations.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 16)),
                          Expanded(
                              child: Text(rec.toString(),
                                  style: const TextStyle(fontSize: 12, height: 1.4))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
