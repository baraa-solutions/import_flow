import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/models/customs_clearance_model.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../../smart_checklists/providers/smart_checklists_provider.dart';
import '../../../smart_checklists/widgets/smart_checklist_dialog.dart';
import '../../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../../models/comprehensive_dossier_model.dart';
import '../../services/comprehensive_report_export_service.dart';
import '../comprehensive_dossier_export_dialog.dart';
import '../report_copy_badge.dart';
import '../shipment_audit_timeline_dialog.dart';

/// Top Action Toolbar & Shipment Selector Bar for Comprehensive Import File Report.
class ComprehensiveReportActionsBar extends StatelessWidget {
  final AsyncValue<List<ImportFileModel>> importFilesState;
  final int? selectedFileId;
  final ImportFileModel? selectedFile;
  final ComprehensiveShipmentDossierModel? dossier;
  final ShipmentUpdatesState updatesState;
  final SmartChecklistState checklistState;
  final CustomsClearanceModel? clearance;
  final WarehouseReceivingModel? warehouse;
  final void Function(int? val, List<ImportFileModel> files) onFileSelected;

  const ComprehensiveReportActionsBar({
    super.key,
    required this.importFilesState,
    required this.selectedFileId,
    required this.selectedFile,
    required this.dossier,
    required this.updatesState,
    required this.checklistState,
    required this.clearance,
    required this.warehouse,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Shipment Selector Bar ────────────────────────────────────
        Container(
          color: AppTheme.charcoalSurface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: importFilesState.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              '${l.errorPrefix} $e',
              style: const TextStyle(color: AppTheme.crimson),
            ),
            data: (files) => Row(
              children: [
                const Icon(Icons.folder_open, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: SearchableDropdownField<int>(
                    value: selectedFileId,
                    labelText: l.compReportSelectFileLabel,
                    items: files.map((f) {
                      final stageName = DisplayNameResolver.resolveStepName(
                        f.displayStepKey,
                        isArabic: isAr,
                      );
                      return SearchableDropdownItem<int>(
                        value: f.importFileId,
                        label: '${f.primaryNameWithCode}  |  ${f.supplierName}  |  $stageName  |  ${f.status}',
                      );
                    }).toList(),
                    onChanged: (val) => onFileSelected(val, files),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Action Toolbar Strip when file is selected ───────────────
        if (selectedFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.white,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    selectedFile!.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ReportCopyBadge(textToCopy: selectedFile!.displayName),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    icon: const Icon(Icons.copy_all, size: 15, color: AppTheme.charcoal),
                    label: Text(
                      l.compReportCopyDossierBtn,
                      style: const TextStyle(fontSize: 11, color: AppTheme.charcoal),
                    ),
                    onPressed: () {
                      final dossierText = ComprehensiveReportExportService.buildDossierText(
                        context: context,
                        file: selectedFile!,
                        dossier: dossier,
                        logs: updatesState.logs,
                        clearance: clearance,
                        warehouse: warehouse,
                      );
                      CopyHelper.copy(
                        context,
                        dossierText,
                        customMessage: l.compReportCopyDossierSuccess,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppTheme.cobaltBorder),
                    ),
                    icon: const Icon(Icons.description_outlined, size: 15, color: AppTheme.cobalt),
                    label: Text(
                      l.compReportExportTsvBtn,
                      style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                    ),
                    onPressed: () => ComprehensiveReportExportService.exportToTsv(
                      context: context,
                      file: selectedFile!,
                      dossier: dossier,
                      logs: updatesState.logs,
                      clearance: clearance,
                      warehouse: warehouse,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppTheme.emeraldBorder),
                    ),
                    icon: const Icon(Icons.table_chart_outlined, size: 15, color: AppTheme.emerald),
                    label: Text(
                      l.compReportExportExcelBtn,
                      style: const TextStyle(fontSize: 11, color: AppTheme.emerald),
                    ),
                    onPressed: () => ComprehensiveReportExportService.exportToExcel(
                      context: context,
                      file: selectedFile!,
                      dossier: dossier,
                      logs: updatesState.logs,
                      clearance: clearance,
                      warehouse: warehouse,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.charcoal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 15, color: AppTheme.white),
                    label: Text(
                      l.compReportPrintPdfBtn,
                      style: const TextStyle(fontSize: 11, color: AppTheme.white),
                    ),
                    onPressed: () => ComprehensiveReportExportService.printOrSavePdf(
                      context: context,
                      file: selectedFile!,
                      dossier: dossier,
                      logs: updatesState.logs,
                      clearance: clearance,
                      warehouse: warehouse,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: const Key('comprehensiveDossierModalBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.sorourNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined, size: 15, color: AppTheme.white),
                    label: Text(
                      isAr ? 'تصدير الملف الشامل' : 'Export Comprehensive Dossier',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => ComprehensiveDossierExportDialog.show(
                      context,
                      file: selectedFile!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: const Key('smartChecklistToolbarBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: checklistState.summary?.isGateBlocked == true
                          ? AppTheme.crimson
                          : AppTheme.emerald,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: Icon(
                      checklistState.summary?.isGateBlocked == true
                          ? Icons.warning_amber_rounded
                          : Icons.checklist_rtl_outlined,
                      size: 15,
                      color: AppTheme.white,
                    ),
                    label: Text(
                      isAr
                          ? (checklistState.summary != null
                              ? 'قائمة التحقق (${checklistState.summary!.readinessScorePct}%)'
                              : 'قائمة التحقق')
                          : (checklistState.summary != null
                              ? 'Smart Checklist (${checklistState.summary!.readinessScorePct}%)'
                              : 'Smart Checklist'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => SmartChecklistDialog.show(context, selectedFile!),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: const Key('shipmentAuditTimelineToolbarBtn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.sorourDeepBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.history_toggle_off_rounded, size: 15, color: AppTheme.white),
                    label: Text(
                      isAr ? 'رادار ومحضر التتبع الزمني' : 'Shipment Audit Timeline',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => showShipmentAuditTimelineDialog(
                      context,
                      importFileId: selectedFile!.importFileId,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
