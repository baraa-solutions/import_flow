import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/row_actions_pill.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/shipping_scenario_model.dart';

class ShippingScenariosDataTable extends StatelessWidget {
  final List<ShippingEvaluationModel> sessions;
  final List<ImportFileModel> importFiles;
  final void Function(ShippingEvaluationModel sess) onView;
  final void Function(ShippingEvaluationModel sess) onEdit;
  final void Function(ShippingEvaluationModel sess) onClone;
  final void Function(ShippingEvaluationModel sess) onPrint;
  final void Function(ShippingEvaluationModel sess) onDeleteOrRestore;

  const ShippingScenariosDataTable({
    super.key,
    required this.sessions,
    required this.importFiles,
    required this.onView,
    required this.onEdit,
    required this.onClone,
    required this.onPrint,
    required this.onDeleteOrRestore,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
      child: Card(
        elevation: 2,
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 60,
            horizontalMargin: 16,
            columnSpacing: 20,
            dividerThickness: 0.5,
            headingRowColor: WidgetStateProperty.all(
              isDark ? AppTheme.darkScaffoldBackground : AppTheme.charcoal,
            ),
            headingTextStyle: const TextStyle(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
            columns: [
              DataColumn(
                label: SizedBox(
                  width: 168,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.orange),
                      const SizedBox(width: 4),
                      Text(
                        l.actionsCol,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataColumn(label: Text('📋 ${l.studyCodeCol}')),
              DataColumn(label: Text('📁 ${l.linkImportFile}')),
              DataColumn(label: Text('📝 ${l.titleField}')),
              DataColumn(label: Text('⏱️ ${l.avgTransitMetric}')),
              DataColumn(label: Text('🏭 ${l.avgWarehouseArrivalMetric}')),
              DataColumn(label: Text('⭐ ${l.recommendedLineMetric}')),
              DataColumn(label: Text('🔢 ${l.optionsCountCol}')),
              DataColumn(label: Text('🔗 ${l.linkPurchaseOrder}')),
              DataColumn(label: Text('📅 ${l.crdLabel}')),
              DataColumn(label: Text('📍 ${l.pickupAddressLabel}')),
            ],
            rows: sessions.asMap().entries.map((entry) {
              final idx = entry.key;
              final sess = entry.value;
              final isEven = idx.isEven;
              final rowColor = !sess.isActive
                  ? (AppTheme.crimsonLight)
                  : isEven
                      ? (isDark ? AppTheme.darkCardBackground : AppTheme.white)
                      : (isDark ? AppTheme.darkInputBackground : AppTheme.charcoalSurface);

              final isArabic = Localizations.localeOf(context).languageCode == 'ar';
              final rawFileCode =
                  sess.importFileCode ?? (sess.importFileId != null ? 'IMP-${sess.importFileId}' : '—');
              final shipmentTitle = (rawFileCode != '—')
                  ? DisplayNameResolver.resolveShipmentTitleByCode(
                      rawFileCode,
                      shipments: importFiles,
                      isArabic: isArabic,
                    )
                  : '—';

              final rowSummary =
                  '${sess.sessionCode} | ${sess.title ?? ""} | $shipmentTitle | ${sess.avgExpectedTransitDays.toStringAsFixed(1)}d | WH: ${sess.avgExpectedWarehouseArrivalDate ?? "-"} | ${sess.recommendedScenarioProvider ?? "-"}';

              return DataRow(
                color: WidgetStateProperty.all(rowColor),
                onSelectChanged: (_) => onView(sess),
                cells: [
                  // 1. ACTIONS
                  DataCell(
                    RowActionsPill(
                      onView: () => onView(sess),
                      onEdit: () => onEdit(sess),
                      onClone: () => onClone(sess),
                      onPrint: () => onPrint(sess),
                      onDelete: () => onDeleteOrRestore(sess),
                    ),
                  ),

                  // 2. Study Code
                  DataCell(
                    CopyableTableCell(
                      value: sess.sessionCode,
                      rowSummary: rowSummary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (sess.isActive ? AppTheme.cobalt : AppTheme.crimson).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (sess.isActive ? AppTheme.cobalt : AppTheme.crimson).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sess.isActive ? Icons.analytics_outlined : Icons.delete_outline,
                              size: 13,
                              color: sess.isActive ? AppTheme.cobalt : AppTheme.crimson,
                            ),
                            const SizedBox(width: 5),
                            CopyableText(
                              sess.sessionCode,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sess.isActive ? AppTheme.cobalt : AppTheme.crimson,
                                fontSize: 12,
                                decoration: sess.isActive ? TextDecoration.none : TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Import File
                  DataCell(
                    CopyableTableCell(
                      value: rawFileCode != '—' ? '$shipmentTitle ($rawFileCode)' : '—',
                      rowSummary: rowSummary,
                      child: rawFileCode == '—'
                          ? const Text('—', style: TextStyle(color: AppTheme.textMuted))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  shipmentTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: AppTheme.charcoal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2), width: 0.8),
                                  ),
                                  child: Text(
                                    rawFileCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.cobalt,
                                      fontSize: 10,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // 4. Title
                  DataCell(
                    CopyableTableCell(
                      value: sess.title ?? l.freightStudiesTitle,
                      rowSummary: rowSummary,
                      child: SizedBox(
                        width: 180,
                        child: Text(
                          sess.title ?? l.freightStudiesTitle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),

                  // 5. Avg Transit
                  DataCell(
                    CopyableTableCell(
                      value: l.avgTransitDays(sess.avgExpectedTransitDays.toStringAsFixed(1)),
                      rowSummary: rowSummary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cobaltLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l.avgTransitDays(sess.avgExpectedTransitDays.toStringAsFixed(1)),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.wcagCobalt,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. Avg WH Arrival
                  DataCell(
                    CopyableTableCell(
                      value: sess.avgExpectedWarehouseArrivalDate ?? '—',
                      rowSummary: rowSummary,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warehouse_rounded, size: 14, color: AppTheme.emerald.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            sess.avgExpectedWarehouseArrivalDate ?? '—',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emerald,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 7. Recommended Carrier
                  DataCell(
                    CopyableTableCell(
                      value: sess.recommendedScenarioProvider ?? '—',
                      rowSummary: rowSummary,
                      child: sess.recommendedScenarioProvider != null && sess.recommendedScenarioProvider!.isNotEmpty
                          ? Container(
                              constraints: const BoxConstraints(maxWidth: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.cobalt, AppTheme.cobalt],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: AppTheme.orange),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      sess.recommendedScenarioProvider!,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const Text('—', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),

                  // 8. Options Count
                  DataCell(
                    CopyableTableCell(
                      value: l.optionsCount(sess.items.length),
                      rowSummary: rowSummary,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l.optionsCount(sess.items.length),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.charcoal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 9. Linked PO / Project
                  DataCell(
                    CopyableTableCell(
                      value: sess.poNumber != null
                          ? 'PO: ${sess.poNumber}'
                          : (sess.projectName != null ? 'PRJ: ${sess.projectName}' : l.independentStudy),
                      rowSummary: rowSummary,
                      child: sess.poNumber != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.receipt_long_rounded, size: 13, color: AppTheme.emerald),
                                const SizedBox(width: 4),
                                Text('PO: ${sess.poNumber}', style: const TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            )
                          : sess.projectName != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.folder_special_rounded, size: 13, color: AppTheme.orange),
                                    const SizedBox(width: 4),
                                    Text('PRJ: ${sess.projectName}', style: const TextStyle(color: AppTheme.wcagOrange, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                )
                              : Text(l.independentStudy, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ),
                  ),

                  // 10. CRD Date
                  DataCell(
                    CopyableTableCell(
                      value: sess.cargoReadyDate,
                      rowSummary: rowSummary,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_rounded, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(sess.cargoReadyDate, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),

                  // 11. Pick-up Address
                  DataCell(
                    CopyableTableCell(
                      value: sess.pickUpAddress ?? '—',
                      rowSummary: rowSummary,
                      child: SizedBox(
                        width: 140,
                        child: Text(
                          sess.pickUpAddress ?? '—',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
