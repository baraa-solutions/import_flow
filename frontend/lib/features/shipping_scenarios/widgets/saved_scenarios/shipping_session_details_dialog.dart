import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/shipping_scenario_model.dart';
import 'shipping_scenario_exporter.dart';

class ShippingSessionDetailsDialog {
  static void show(
    BuildContext context,
    ShippingEvaluationModel sess, [
    List<ImportFileModel>? importFiles,
  ]) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final rawFileCode = sess.importFileCode ?? (sess.importFileId != null ? 'IMP-${sess.importFileId}' : null);
    final shipmentTitle = (rawFileCode != null && rawFileCode != '—')
        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
        : null;

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AlertDialog(
          title: Text('${l.freightStudiesTitle} (${sess.sessionCode})'),
          content: SizedBox(
            width: 950,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sess.title ?? l.freightStudiesTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (shipmentTitle != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_outlined, size: 14, color: AppTheme.cobalt),
                          const SizedBox(width: 4),
                          Text(
                            '$shipmentTitle ($rawFileCode)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cobalt,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${l.crdLabel}: ${sess.cargoReadyDate} | ${l.pickupAddressLabel}: ${sess.pickUpAddress ?? "—"} | ${l.avgForm4DaysLabel}: ${sess.avgForm4Days}d | ${l.avgClearanceDaysLabel}: ${sess.avgClearanceDays}d',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const Divider(height: 20),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text('#')),
                        DataColumn(label: Text(l.shippingLineCol)),
                        DataColumn(label: Text(l.totalQuoteValue)),
                        DataColumn(label: Text(l.avgTransitMetric)),
                        DataColumn(label: Text(l.customsBrokerLabel)),
                        DataColumn(label: Text(l.vesselNameCol)),
                        DataColumn(label: Text('${l.portOfLoadingCol} ➔ ${l.portOfDischargeCol}')),
                        DataColumn(label: Text(l.sailingDateCol)),
                        DataColumn(label: Text(l.estimatedArrivalDateCol)),
                        DataColumn(label: Text(l.freeTimeDaysCol)),
                        DataColumn(label: Text(l.statusCol)),
                      ],
                      rows: sess.items.asMap().entries.map((e) {
                        final item = e.value;
                        final totalText = item.totalQuotationAmount != null
                            ? '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? ""}'
                            : '—';
                        final rowSummary = '${item.providerName} | $totalText | ${item.expectedTotalDaysToWarehouse}d | ${item.polName ?? "-"} ➔ ${item.podName ?? "-"} | ${item.vesselName}';
                        return DataRow(
                          cells: [
                            DataCell(CopyableTableCell(value: '${e.key + 1}', rowSummary: rowSummary, child: Text('${e.key + 1}'))),
                            DataCell(CopyableTableCell(value: item.providerName, rowSummary: rowSummary, child: Text(item.providerName, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(CopyableTableCell(value: totalText, rowSummary: rowSummary, child: Text(totalText, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson)))),
                            DataCell(CopyableTableCell(value: '${item.expectedTotalDaysToWarehouse} d', rowSummary: rowSummary, child: Text('${item.expectedTotalDaysToWarehouse} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                            DataCell(CopyableTableCell(value: item.customsBrokerName ?? '-', rowSummary: rowSummary, child: Text(item.customsBrokerName ?? '-'))),
                            DataCell(CopyableTableCell(value: '${item.vesselName} (${item.voyageNumber ?? "-"})', rowSummary: rowSummary, child: Text('${item.vesselName} (${item.voyageNumber ?? "-"})'))),
                            DataCell(CopyableTableCell(value: '${item.polName ?? "-"} ➔ ${item.podName ?? "-"}', rowSummary: rowSummary, child: Text('${item.polName ?? "-"} ➔ ${item.podName ?? "-"}', style: const TextStyle(fontSize: 11)))),
                            DataCell(CopyableTableCell(value: item.sailingDate, rowSummary: rowSummary, child: Text(item.sailingDate))),
                            DataCell(CopyableTableCell(value: item.estimatedArrivalDate, rowSummary: rowSummary, child: Text(item.estimatedArrivalDate))),
                            DataCell(CopyableTableCell(value: '${item.freeTimeDays} d', rowSummary: rowSummary, child: Text('${item.freeTimeDays} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                            DataCell(CopyableTableCell(value: item.isRecommended ? l.recommendedLineMetric : item.isExcludedFromAverage ? l.excludedBadge : l.normalBadge, rowSummary: rowSummary, child: Text(item.isRecommended ? '⭐ ${l.recommendedLineMetric}' : item.isExcludedFromAverage ? l.excludedBadge : l.normalBadge))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l.exportExcel,
              icon: Icons.file_download_outlined,
              variant: AppButtonVariant.success,
              onPressed: () => ShippingScenarioExporter.exportScenarioCsv(context, sess, importFiles),
            ),
            AppButton(
              label: l.close,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(dialogCtx),
            ),
          ],
        ),
      ),
    );
  }

  static void showContainerComparisonDialog(
    BuildContext context,
    ContainerDualRecommendationResult dualRec,
    double cbm,
    double weightKg,
  ) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AlertDialog(
          title: Text('🚚 ${l.compareContainersMatrix}'),
          content: SizedBox(
            width: 650,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CBM: ${cbm.toStringAsFixed(3)} m³ | ${l.weightUtilizationCol}: ${weightKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: AppTheme.cloudWhite),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.statusCol, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('📦 ${l.stackableOption}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('🚫 ${l.nonStackableOption}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange))),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.recommendedContainerCol)),
                        Padding(padding: const EdgeInsets.all(8), child: Text(dualRec.stackableResult.recommendedContainerCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(8), child: Text(dualRec.nonStackableResult.recommendedContainerCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.requiredCountCol)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${dualRec.stackableResult.requiredContainersCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${dualRec.nonStackableResult.requiredContainersCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text(l.spaceUtilizationCol)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${dualRec.stackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%')),
                        Padding(padding: const EdgeInsets.all(8), child: Text('${dualRec.nonStackableResult.spaceUtilizationPercent.toStringAsFixed(1)}%')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            AppButton(
              label: l.close,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(dialogCtx),
            ),
          ],
        ),
      ),
    );
  }
}
