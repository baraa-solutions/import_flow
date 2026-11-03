import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/lifecycle_board_model.dart';
import 'kanban_shipment_kpi_pills.dart';
import 'lifecycle_board_helpers.dart';
import 'shipment_timeline_dossier_dialog.dart';
import 'step_action_dialog.dart';

/// Shipments data table component within the Kanban view.
class KanbanShipmentsTable extends StatelessWidget {
  final List<ShipmentStageCardModel> shipments;
  final List<PhaseSummaryModel> phases;
  final List<ImportFileModel> allImportFiles;
  final Map<String, LiveLogisticsTrackingItemModel> trackingMap;

  const KanbanShipmentsTable({
    super.key,
    required this.shipments,
    required this.phases,
    required this.allImportFiles,
    required this.trackingMap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return SelectionArea(
      child: EnterpriseDataTable<ShipmentStageCardModel>(
        storageKey: 'lifecycle_board_shipments_table',
        data: shipments,
        rowHeight: 64,
        columns: [
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'shipmentName',
            title: l10n.operationalTsvHeaderShipmentName,
            width: 300,
            exportValue: (s) => DisplayNameResolver.resolveShipmentTitleByCode(
              s.importFileCode,
              shipments: allImportFiles,
              isArabic: isAr,
              includeCodeSecondary: true,
            ),
            searchValue: (s) => '${s.importFileCode} ${s.companyName} ${s.supplierName}',
            cellBuilder: (context, s, index) {
              final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
                s.importFileCode,
                shipments: allImportFiles,
                isArabic: isAr,
              );
              final isOnHold = s.status == 'On-Hold';
              final tracking = trackingMap[s.importFileCode];
              final healthPercent = tracking?.docReadinessPercent;
              final freeDays = tracking?.freeDaysRemaining;
              final overdue = tracking?.accumulatedDemurrageFx ?? 0.0;

              return Column(
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
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => CopyHelper.copy(context, s.importFileCode),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkBorder : AppTheme.charcoal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LtrText(
                                s.importFileCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.0,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.copy_rounded, size: 9, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      KanbanShipmentRowKpiPills(
                        healthPercent: healthPercent,
                        freeDaysRemaining: freeDays,
                        accumulatedOverdue: overdue,
                        isOnHold: isOnHold,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'previousStep',
            title: l10n.colPreviousStep,
            width: 140,
            exportValue: (s) => s.previousStepCode != null
                ? DisplayNameResolver.resolveStepName(s.previousStepCode!, isArabic: isAr)
                : '-',
            cellBuilder: (context, s, index) {
              final cleanPrevStep = s.previousStepCode != null
                  ? DisplayNameResolver.resolveStepName(s.previousStepCode!, isArabic: isAr)
                  : '-';
              return Text(
                cleanPrevStep,
                style: TextStyle(
                  fontSize: 11.0,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'currentStep',
            title: l10n.colCurrentStep,
            width: 180,
            exportValue: (s) => DisplayNameResolver.resolveStepName(s.stepCode, isArabic: isAr),
            cellBuilder: (context, s, index) {
              final isOnHold = s.status == 'On-Hold';
              final pendingSteps = shipments
                  .where((item) => item.importFileCode == s.importFileCode)
                  .map((item) => item.stepCode)
                  .toSet()
                  .toList();
              if (!pendingSteps.contains(s.stepCode)) {
                pendingSteps.insert(0, s.stepCode);
              }

              return Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: pendingSteps.map((stepCode) {
                  final cleanStepName = DisplayNameResolver.resolveStepName(stepCode, isArabic: isAr);
                  final isCurrent = stepCode == s.stepCode;
                  final severity = isOnHold
                      ? AppSeverity.danger
                      : (isCurrent ? AppSeverity.warning : AppSeverity.info);

                  return AppStatusBadge(
                    label: cleanStepName,
                    severity: severity,
                    size: AppStatusBadgeSize.small,
                    icon: isOnHold
                        ? Icons.pause_circle_outline
                        : (isCurrent ? Icons.pending_actions_rounded : Icons.radio_button_checked),
                  );
                }).toList(),
              );
            },
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'nextStep',
            title: l10n.colNextStep,
            width: 140,
            exportValue: (s) => s.nextStepCode != null
                ? DisplayNameResolver.resolveStepName(s.nextStepCode!, isArabic: isAr)
                : '-',
            cellBuilder: (context, s, index) {
              final cleanNextStep = s.nextStepCode != null
                  ? DisplayNameResolver.resolveStepName(s.nextStepCode!, isArabic: isAr)
                  : '-';
              return Text(
                cleanNextStep,
                style: const TextStyle(
                  fontSize: 11.0,
                  color: AppTheme.cobalt,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'importCompany',
            title: l10n.colImportCompany,
            width: 150,
            exportValue: (s) => s.companyName,
            cellBuilder: (context, s, index) => Text(
              s.companyName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11.0,
                color: isDark ? AppTheme.darkTextPrimary : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'foreignSupplier',
            title: l10n.colForeignSupplier,
            width: 150,
            exportValue: (s) => s.supplierName,
            cellBuilder: (context, s, index) => Text(
              s.supplierName,
              style: TextStyle(
                fontSize: 11.0,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'purchaseOrder',
            title: l10n.colPurchaseOrder,
            width: 130,
            exportValue: (s) => s.poNumber ?? l10n.notSpecifiedOption,
            cellBuilder: (context, s, index) => Text(
              s.poNumber ?? l10n.notSpecifiedOption,
              style: TextStyle(
                fontSize: 11.0,
                color: isDark ? AppTheme.darkTextPrimary : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'modeAndIncoterm',
            title: l10n.colModeAndIncoterm,
            width: 130,
            exportValue: (s) => '${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}',
            cellBuilder: (context, s, index) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
                ),
              ),
            ),
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'estimatedValue',
            title: l10n.colEstimatedValue,
            width: 130,
            isNumeric: true,
            exportValue: (s) => s.estimatedCost != null
                ? '${s.estimatedCost!.toStringAsFixed(0)} ${s.estimatedCostCurrency ?? ""}'.trim()
                : '—',
            cellBuilder: (context, s, index) => Text(
              s.estimatedCost != null
                  ? '${s.estimatedCost!.toStringAsFixed(0)} ${s.estimatedCostCurrency ?? ""}'.trim()
                  : '—',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: s.estimatedCost != null
                    ? AppTheme.emerald
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.textCaption),
                fontSize: 11,
              ),
            ),
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'notesAndActivities',
            title: l10n.colNotesAndActivities,
            width: 180,
            exportValue: (s) => s.localizedNotes(l10n) ?? l10n.notesUnderFollowupFallback,
            cellBuilder: (context, s, index) => Text(
              s.localizedNotes(l10n) ?? l10n.notesUnderFollowupFallback,
              style: TextStyle(
                fontSize: 11.0,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          EnterpriseColumn<ShipmentStageCardModel>(
            id: 'actionsAndAdvance',
            title: l10n.colActionsAndAdvance,
            width: 300,
            isSortable: false,
            isSearchable: false,
            cellBuilder: (context, s, index) {
              final phaseStr = kLifecycleStepPhases[s.stepCode] ?? '1';
              final phaseId = int.tryParse(phaseStr) ?? 1;
              final p = phases.firstWhere((ph) => ph.phaseId == phaseId, orElse: () => phases[0]);
              final stepColor = parseHexColor(p.colorHex);

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.timeline_rounded, size: 16, color: AppTheme.cobalt),
                    tooltip: isAr ? 'سجل المسار الزمني الشامل' : 'Master Timeline Dossier',
                    onPressed: () {
                      final matchedFile = allImportFiles
                          .where((f) => f.importFileCode == s.importFileCode)
                          .firstOrNull;
                      if (matchedFile != null) {
                        ShipmentTimelineDossierDialog.show(
                          context,
                          importFileId: matchedFile.importFileId,
                          importFileCode: s.importFileCode,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: stepColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => StepActionDialog(
                          shipment: s,
                          allPhases: phases,
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_outline, size: 13, color: Colors.white),
                    label: Text(
                      l10n.executeAndAdvanceStepBtn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.0,
                      ),
                    ),
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
