import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class ArchiveOverviewHeaderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String readiness;
  final double score;
  final int critical;
  final int warning;

  const ArchiveOverviewHeaderCard({
    super.key,
    required this.data,
    required this.readiness,
    required this.score,
    required this.critical,
    required this.warning,
  });

  Widget _buildHeaderInfoRow(BuildContext context, String label, String value, {bool isBold = false}) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context), fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.copy_rounded, size: 11, color: AppTheme.textMutedOf(context)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isBold ? AppTheme.charcoal : AppTheme.textPrimaryOf(context),
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Color readinessColor;
    String readinessText;
    IconData readinessIcon;

    if (readiness == 'READY_FOR_RELEASE') {
      readinessColor = AppTheme.emerald;
      readinessText = l10n.readinessReadyForRelease;
      readinessIcon = Icons.check_circle;
    } else if (readiness == 'ACTION_REQUIRED') {
      readinessColor = AppTheme.crimson;
      readinessText = l10n.readinessActionRequired;
      readinessIcon = Icons.warning_amber_rounded;
    } else {
      readinessColor = AppTheme.orange;
      readinessText = l10n.readinessInReview;
      readinessIcon = Icons.pending_actions;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    InkWell(
                      onTap: () => CopyHelper.copy(context, data['import_file_code'] ?? ''),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.fileCodeLabel(data['import_file_code'] ?? ''),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                          ],
                        ),
                      ),
                    ),
                    if (data['custom_file_number'] != null && data['custom_file_number'].toString().isNotEmpty)
                      InkWell(
                        onTap: () => CopyHelper.copy(context, data['custom_file_number'].toString()),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAltOf(context),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.textMutedOf(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.customsFileNumberLabel(data['custom_file_number']),
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context), fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondaryOf(context)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                InkWell(
                  onTap: () => CopyHelper.copy(context, '$readinessText (${score.toStringAsFixed(0)}%)'),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: readinessColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: readinessColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(readinessIcon, color: readinessColor, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$readinessText (${score.toStringAsFixed(0)}%)',
                            style: TextStyle(fontWeight: FontWeight.bold, color: readinessColor, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 14, color: readinessColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final pkgsCount = data['total_packages'] ?? 0;
                final weightCount = (data['total_gross_weight_kg'] as num?)?.toStringAsFixed(2) ?? '0.00';
                final totalFormatted = '${(data['fob_or_cif_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'} ${data['currency'] ?? 'EUR'}';

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderInfoRow(context, l10n.importerCompanyLabel, data['importer_name'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(context, l10n.exporterSupplierLabel, data['supplier_name'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(context, l10n.acidNumberLabel, data['acid_number'] ?? 'N/A', isBold: true),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(context, l10n.shippingRouteLabel, '${data['port_of_loading'] ?? 'N/A'} ➔ ${data['port_of_discharge'] ?? 'Alexandria'}'),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(context, l10n.totalPackagesAndWeightLabel, l10n.packagesCountText(pkgsCount, weightCount)),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(context, l10n.totalInvoiceValueLabel, totalFormatted),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderInfoRow(context, l10n.importerCompanyLabel, data['importer_name'] ?? 'N/A'),
                          const SizedBox(height: 8),
                          _buildHeaderInfoRow(context, l10n.exporterSupplierLabel, data['supplier_name'] ?? 'N/A'),
                          const SizedBox(height: 8),
                          _buildHeaderInfoRow(context, l10n.acidNumberLabel, data['acid_number'] ?? 'N/A', isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderInfoRow(context, l10n.shippingRouteLabel, '${data['port_of_loading'] ?? 'N/A'} ➔ ${data['port_of_discharge'] ?? 'Alexandria'}'),
                          const SizedBox(height: 8),
                          _buildHeaderInfoRow(context, l10n.totalPackagesAndWeightLabel, l10n.packagesCountText(pkgsCount, weightCount)),
                          const SizedBox(height: 8),
                          _buildHeaderInfoRow(context, l10n.totalInvoiceValueLabel, totalFormatted),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
