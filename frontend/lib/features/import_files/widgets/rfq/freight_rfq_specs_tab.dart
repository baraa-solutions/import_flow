import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/import_file_model.dart';

/// Shipment specs and packaging breakdown tab for FreightRfqDialog
class FreightRfqSpecsTab extends StatelessWidget {
  final FreightRfqDataModel rfq;

  const FreightRfqSpecsTab({
    super.key,
    required this.rfq,
  });

  static Widget _buildSpecCard(BuildContext context, String label, String value, Color color) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.copy, size: 12, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grid of Metrics
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSpecCard(context, '📦 ${l.commodityTitle}', rfq.commodity, AppTheme.cobalt),
                _buildSpecCard(context, '🌐 ${l.incotermsRules}', rfq.incotermCode, AppTheme.orange),
                _buildSpecCard(context, '🚢 ${l.containerSpecType}', rfq.recommendedContainers, AppTheme.charcoal),
                _buildSpecCard(context, '📐 ${l.cbmVolumeMetric}', '${rfq.totalCbm.toStringAsFixed(2)} m³', AppTheme.emerald),
                _buildSpecCard(context, '⚖️ ${l.grossWeightMetric}', '${rfq.grossWeightKg.toStringAsFixed(1)} kg', AppTheme.cobalt),
                _buildSpecCard(context, '⚖️ ${l.netWeightMetric}', '${rfq.netWeightKg.toStringAsFixed(1)} kg', Colors.purple),
                _buildSpecCard(context, '📍 ${l.portOfLoadingLabel}', rfq.portOfLoading, AppTheme.charcoal),
                _buildSpecCard(context, '🏁 ${l.portOfDischargeLabel}', rfq.portOfDischarge, AppTheme.crimson),
                _buildSpecCard(context, '📅 ${l.cargoReadyDateLabel}', rfq.cargoReadyDate, AppTheme.cobalt),
                _buildSpecCard(context, '⏳ ${l.targetFreeDaysLabel}', '${rfq.targetFreeDays} d', AppTheme.emerald),
              ],
            ),
            const SizedBox(height: 16),

            // Pickup Address Card
            if (rfq.incotermCode.toUpperCase() == 'EXW') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l.freightRfqPickupLocation,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${l.freightRfqSupplierLabel} ${rfq.supplierName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(rfq.pickupAddress, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Packaging Breakdown Card
            if (rfq.packagesBreakdown.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.format_list_bulleted, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 8),
                        Text(l.freightRfqPackagesBreakdownTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(rfq.packagesBreakdown, style: const TextStyle(fontSize: 12, height: 1.5)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
