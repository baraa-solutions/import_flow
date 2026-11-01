import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class WhatIfExposureRadarTab extends StatelessWidget {
  final Map<String, dynamic>? exposureData;
  final bool isLoadingExposure;
  final VoidCallback onFetchExposure;

  const WhatIfExposureRadarTab({
    super.key,
    required this.exposureData,
    required this.isLoadingExposure,
    required this.onFetchExposure,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (isLoadingExposure) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exposureData == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: onFetchExposure,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.whatIfRefreshExposure),
        ),
      );
    }

    final data = exposureData!;
    final items = (data['items'] as List<dynamic>?) ?? [];
    final advice = (data['strategic_advice'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exposure Metric Cards
          Row(
            children: [
              _buildMetricCard(
                title: l10n.whatIfTotalUsdObligations,
                value: '\$${(data['total_open_usd'] as num).toStringAsFixed(2)}',
                color: AppTheme.cobalt,
                icon: Icons.attach_money,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: l10n.whatIfTotalEurObligations,
                value: '€${(data['total_open_eur'] as num).toStringAsFixed(2)}',
                color: AppTheme.orange,
                icon: Icons.euro,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: l10n.whatIfCurrentEgpValue,
                value: '${(data['total_open_egp_baseline'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}',
                color: AppTheme.charcoal,
                icon: Icons.account_balance,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: l10n.whatIfValueAtRisk10,
                value: '+${(data['var_at_risk_10_pct'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}',
                color: AppTheme.crimson,
                icon: Icons.trending_up,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Strategic advice
          Card(
            elevation: 0,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.amber.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.whatIfTreasuryGuidance,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...advice.map((adv) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $adv', style: const TextStyle(fontSize: 12)),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Table of open files
          Text(
            l10n.whatIfOpenShipmentsExposed,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columns: [
                DataColumn(label: Text(l10n.whatIfColShipmentCode)),
                DataColumn(label: Text(l10n.whatIfColSupplier)),
                DataColumn(label: Text(l10n.whatIfColCurrency)),
                DataColumn(label: Text(l10n.whatIfColPendingAmount)),
                DataColumn(label: Text(l10n.whatIfColCurrentEgp)),
                DataColumn(label: Text(l10n.whatIfColScenarioPlus10)),
                DataColumn(label: Text(l10n.whatIfColScenarioPlus25)),
              ],
              rows: items.map((item) {
                final rowTsv = [
                  item['import_file_code'] ?? '',
                  item['supplier_name'] ?? '',
                  item['currency'] ?? '',
                  (item['open_exposure_fcy'] as num).toStringAsFixed(2),
                  (item['open_exposure_egp'] as num).toStringAsFixed(0),
                  (item['simulated_exposure_egp_at_plus_10_pct'] as num).toStringAsFixed(0),
                  (item['simulated_exposure_egp_at_plus_25_pct'] as num).toStringAsFixed(0),
                ].join('\t');

                return DataRow(cells: [
                  DataCell(CopyableTableCell(
                    value: item['import_file_code'] ?? '',
                    rowSummary: rowTsv,
                    child: Text(
                      item['import_file_code'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: item['supplier_name'] ?? '',
                    rowSummary: rowTsv,
                    child: Text(item['supplier_name'] ?? '', style: const TextStyle(fontSize: 12)),
                  )),
                  DataCell(CopyableTableCell(
                    value: item['currency'] ?? '',
                    rowSummary: rowTsv,
                    child: Text(item['currency'] ?? '', style: const TextStyle(fontSize: 12)),
                  )),
                  DataCell(CopyableTableCell(
                    value: (item['open_exposure_fcy'] as num).toStringAsFixed(2),
                    rowSummary: rowTsv,
                    child: Text(
                      (item['open_exposure_fcy'] as num).toStringAsFixed(2),
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: (item['open_exposure_egp'] as num).toStringAsFixed(0),
                    rowSummary: rowTsv,
                    child: Text(
                      (item['open_exposure_egp'] as num).toStringAsFixed(0),
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: (item['simulated_exposure_egp_at_plus_10_pct'] as num).toStringAsFixed(0),
                    rowSummary: rowTsv,
                    child: Text(
                      (item['simulated_exposure_egp_at_plus_10_pct'] as num).toStringAsFixed(0),
                      style: const TextStyle(
                        color: AppTheme.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: (item['simulated_exposure_egp_at_plus_25_pct'] as num).toStringAsFixed(0),
                    rowSummary: rowTsv,
                    child: Text(
                      (item['simulated_exposure_egp_at_plus_25_pct'] as num).toStringAsFixed(0),
                      style: const TextStyle(
                        color: AppTheme.crimson,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Icon(icon, size: 20, color: color),
                ],
              ),
              const SizedBox(height: 8),
              CopyableText(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
