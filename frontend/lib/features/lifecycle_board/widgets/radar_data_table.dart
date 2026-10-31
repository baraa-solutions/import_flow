import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../demurrage_detention/screens/demurrage_detention_screen.dart';
import '../../import_documentation/screens/central_docs_archive_screen.dart';
import '../../import_documentation/screens/customs_declaration46_screen.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/screens/import_files_screen.dart';
import '../../import_requirements/screens/import_requirements_screen.dart';
import '../models/lifecycle_board_model.dart';
import 'shipment_timeline_dossier_dialog.dart';

/// Enterprise data table displaying live tracking items for the Live Logistics Radar.
class RadarDataTable extends StatelessWidget {
  final List<LiveLogisticsTrackingItemModel> items;
  final List<ImportFileModel> allImportFiles;

  const RadarDataTable({
    super.key,
    required this.items,
    required this.allImportFiles,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return SelectionArea(
      child: EnterpriseDataTable<LiveLogisticsTrackingItemModel>(
        storageKey: 'lifecycle_board_radar_table',
        data: items,
        rowHeight: 64,
        onRowTap: (item) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImportFilesScreen(
                initialSearchQuery: item.importFileCode,
                highlightedFileId: item.importFileId,
              ),
            ),
          );
        },
        columns: [
          EnterpriseColumn<LiveLogisticsTrackingItemModel>(
            id: 'shipmentName',
            title: l10n.operationalTsvHeaderShipmentName,
            width: 250,
            exportValue: (item) => DisplayNameResolver.resolveShipmentTitleByCode(
              item.importFileCode,
              shipments: allImportFiles,
              isArabic: isAr,
              includeCodeSecondary: true,
            ),
            searchValue: (item) => '${item.importFileCode} ${item.companyName} ${item.supplierName}',
            cellBuilder: (context, item, index) {
              final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
                item.importFileCode,
                shipments: allImportFiles,
                isArabic: isAr,
              );
              final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
                item.importFileCode,
                shipments: allImportFiles,
                isArabic: isAr,
                includeCodeSecondary: true,
              );
              final demurrageSummary = item.accumulatedDemurrageFx > 0
                  ? l10n.demurrageFeesFormatted(
                      item.accumulatedDemurrageFx.toStringAsFixed(0),
                      item.accumulatedDemurrageEgp.toStringAsFixed(0),
                    )
                  : (item.freeDaysTotal != null
                      ? l10n.freeDaysConsumed(item.usedFreeDays, item.freeDaysTotal)
                      : '-');
              final rowSummary =
                  '$shipmentTitle | ${item.companyName} -> ${item.supplierName} | ${item.carrierName ?? l10n.colCarrierUnderPrep} (${item.vesselName ?? "-"}) | ${l10n.colBillOfLadingPrefix}: ${item.blNumber ?? l10n.colCarrierUnderPrep} | ${l10n.colEtaPrefix}: ${item.eta ?? "-"} | $demurrageSummary | ${item.sampleTestStatus} | ${item.docReadinessPercent.toStringAsFixed(0)}%';

              return CopyableTableCell(
                value: shipmentTitle,
                rowSummary: rowSummary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      shipmentName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => CopyHelper.copy(context, item.importFileCode),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkBorder : AppTheme.charcoal,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LtrText(
                                  item.importFileCode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.0,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.copy_rounded, size: 9, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new, size: 11, color: AppTheme.cobalt),
                        const SizedBox(width: 4),
                        Text(
                          '${item.shipmentMode} | ${item.incotermCode}',
                          style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.companyName} → ${item.supplierName}',
                      style: TextStyle(
                        fontSize: 11.0,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
          EnterpriseColumn<LiveLogisticsTrackingItemModel>(
            id: 'vesselAndBl',
            title: l10n.colVesselAndBl,
            width: 200,
            exportValue: (item) =>
                '${item.carrierName ?? l10n.colCarrierUnderPrep} (${item.vesselName ?? "-"}) - ${item.blNumber ?? l10n.colCarrierUnderPrep}',
            searchValue: (item) => '${item.carrierName} ${item.vesselName} ${item.blNumber}',
            cellBuilder: (context, item, index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_boat_outlined, size: 12, color: AppTheme.cobalt),
                      const SizedBox(width: 4),
                      Text(
                        '${item.carrierName ?? l10n.colCarrierUnderPrep} (${item.vesselName ?? "-"})',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.colBillOfLadingPrefix}: ${item.blNumber ?? l10n.colCarrierUnderPrep} | ${item.polName ?? "-"} → ${item.podName ?? "-"}',
                    style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                  ),
                ],
              );
            },
          ),
          EnterpriseColumn<LiveLogisticsTrackingItemModel>(
            id: 'etaCountdown',
            title: l10n.colEtaCountdown,
            width: 160,
            exportValue: (item) => '${l10n.colEtaPrefix}: ${item.eta ?? "-"} (${item.arrivalStatus})',
            cellBuilder: (context, item, index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.etaCountdownDays != null && item.etaCountdownDays! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sailing, size: 11, color: AppTheme.cobalt),
                          const SizedBox(width: 4),
                          Text(
                            l10n.daysRemainingToEta(item.etaCountdownDays),
                            style: const TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cobalt,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (item.etaCountdownDays != null && item.etaCountdownDays! <= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF8E44AD).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.anchor, size: 11, color: Color(0xFF8E44AD)),
                          const SizedBox(width: 4),
                          Text(
                            l10n.daysInPort(item.etaCountdownDays!.abs()),
                            style: const TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8E44AD),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(item.arrivalStatus, style: TextStyle(fontSize: 11.0, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.colEtaPrefix}: ${item.eta ?? "-"}',
                    style: TextStyle(fontSize: 11.0, color: Colors.grey.shade500),
                  ),
                ],
              );
            },
          ),
          EnterpriseColumn<LiveLogisticsTrackingItemModel>(
            id: 'demurrageRisk',
            title: l10n.colDemurrageRisk,
            width: 170,
            exportValue: (item) => item.accumulatedDemurrageFx > 0
                ? l10n.demurrageFeesFormatted(
                    item.accumulatedDemurrageFx.toStringAsFixed(0),
                    item.accumulatedDemurrageEgp.toStringAsFixed(0),
                  )
                : (item.freeDaysTotal != null ? l10n.freeDaysConsumed(item.usedFreeDays, item.freeDaysTotal) : '-'),
            cellBuilder: (context, item, index) {
              Color riskColor = AppTheme.emerald;
              if (item.demurrageRiskLevel == 'Critical') {
                riskColor = AppTheme.crimson;
              } else if (item.demurrageRiskLevel == 'High' || item.demurrageRiskLevel == 'Medium') {
                riskColor = AppTheme.orange;
              } else if (item.demurrageRiskLevel == 'Unknown') {
                riskColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textCaption;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          item.accumulatedDemurrageFx > 0
                              ? l10n.demurrageIncurredBadge
                              : (item.freeDaysRemaining != null
                                  ? l10n.freeDaysRemainingBadge(item.freeDaysRemaining)
                                  : '-'),
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        item.demurrageRiskLevel == 'Critical'
                            ? Icons.error
                            : (item.demurrageRiskLevel == 'Low'
                                ? Icons.check_circle
                                : (item.demurrageRiskLevel == 'Unknown' ? Icons.help_outline : Icons.warning_amber)),
                        size: 13,
                        color: riskColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.accumulatedDemurrageFx > 0
                        ? l10n.demurrageFeesFormatted(
                            item.accumulatedDemurrageFx.toStringAsFixed(0),
                            item.accumulatedDemurrageEgp.toStringAsFixed(0),
                          )
                        : (item.freeDaysTotal != null
                            ? l10n.freeDaysConsumed(item.usedFreeDays, item.freeDaysTotal)
                            : '-'),
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: item.accumulatedDemurrageFx > 0 ? FontWeight.bold : FontWeight.normal,
                      color: item.accumulatedDemurrageFx > 0 ? AppTheme.crimson : Colors.grey.shade600,
                    ),
                  ),
                ],
              );
            },
          ),
          EnterpriseColumn<LiveLogisticsTrackingItemModel>(
            id: 'sampleTesting',
            title: l10n.colSampleTesting,
            width: 150,
            exportValue: (item) => item.sampleTestStatus,
            cellBuilder: (context, item, index) {
              Color sampleColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textCaption;
              if (item.sampleTestStatus == 'Under Testing') {
                sampleColor = AppTheme.orange;
              } else if (item.sampleTestStatus == 'Approved') {
                sampleColor = AppTheme.emerald;
              } else if (item.sampleTestStatus == 'Rejected') {
                sampleColor = AppTheme.crimson;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sampleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: sampleColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.biotech, size: 11, color: sampleColor),
                        const SizedBox(width: 3),
                        Text(
                          item.sampleTestStatus,
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: sampleColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.labReceiptNumber != null
                        ? '${item.regulatoryAgency ?? "GOEIC"} | ${item.labReceiptNumber}'
                        : (item.regulatoryAgency ?? "-"),
                    style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
            },
          ),
          EnterpriseColumn<LiveLogisticsTrackingItemModel>(
            id: 'docReadiness',
            title: l10n.colDocReadiness,
            width: 140,
            exportValue: (item) => '${item.docReadinessPercent.toStringAsFixed(0)}%',
            cellBuilder: (context, item, index) {
              Color docColor = AppTheme.emerald;
              if (item.docReadinessPercent < 50.0) {
                docColor = AppTheme.crimson;
              } else if (item.docReadinessPercent < 80.0) {
                docColor = AppTheme.orange;
              }

              return Tooltip(
                message: item.missingDocuments.isEmpty
                    ? l10n.allDocsCompleted
                    : '${l10n.missingDocsTooltip}${item.missingDocuments.join(", ")}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${item.docReadinessPercent.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: docColor),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          item.docReadinessPercent >= 100.0 ? Icons.task_alt : Icons.hourglass_top,
                          size: 11,
                          color: docColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 80,
                      height: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: item.docReadinessPercent / 100.0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(docColor),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          EnterpriseColumn<LiveLogisticsTrackingItemModel>(
            id: 'quickActions',
            title: l10n.colQuickActions,
            width: 180,
            isSortable: false,
            isSearchable: false,
            cellBuilder: (context, item, index) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.timer_outlined, size: 16, color: AppTheme.cobalt),
                    tooltip: l10n.btnDemurrageSimulator,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const DemurrageDetentionScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.science_outlined, size: 16, color: AppTheme.orange),
                    tooltip: l10n.btnRegulatorySamples,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const ImportRequirementsScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.fact_check_outlined, size: 16, color: Color(0xFF8E44AD)),
                    tooltip: l10n.btnCustoms46,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const CustomsDeclaration46Screen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_shared_outlined, size: 16, color: AppTheme.charcoal),
                    tooltip: l10n.btnCentralArchive,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const CentralDocsArchiveScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.timeline_rounded, size: 16, color: AppTheme.cobalt),
                    tooltip: isAr ? 'سجل المسار الزمني الشامل' : 'Master Timeline Dossier',
                    onPressed: () {
                      ShipmentTimelineDossierDialog.show(
                        context,
                        importFileId: item.importFileId,
                        importFileCode: item.importFileCode,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
