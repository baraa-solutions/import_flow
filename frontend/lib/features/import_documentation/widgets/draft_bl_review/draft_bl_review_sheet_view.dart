import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../../services/draft_bl_export_service.dart';
import '../visual_draft_bl_sheet.dart';
import 'draft_bl_actions_bar.dart';
import 'draft_bl_cargo_description_card.dart';
import 'draft_bl_checklist_table.dart';
import 'draft_bl_container_seal_table.dart';
import 'draft_bl_controllers.dart';
import 'draft_bl_extractor_card.dart';
import 'draft_bl_freight_terms_card.dart';
import 'draft_bl_header_bar.dart';

/// Stage 0 Unified Review Sheet View:
/// Coordinates file selection, B/L transport header bar, workflow actions,
/// smart document extractor, visual maritime sheet vs grid view, and comparison checklist table.
class DraftBlReviewSheetView extends StatefulWidget {
  final int? selectedImportFileId;
  final List<dynamic> importFiles;
  final ValueChanged<int?> onSelectImportFile;
  final VoidCallback onRefresh;
  final DraftBlControllers controllers;
  final DraftBLComparisonResultModel? comparisonResult;
  final DraftBLReviewModel? activeSession;
  final bool isLoading;
  final bool isUploadingFile;
  final bool isSavingDraft;
  final bool isCertifying;
  final String? uploadedFileName;
  final int? uploadedFileSize;
  final String? extractionStatus;
  final List<dynamic> missingCriticalFields;
  final String? safetyWarning;
  final VoidCallback onSearchAndClone;
  final VoidCallback onSaveDraft;
  final VoidCallback onCertify;
  final VoidCallback onRequestAmendment;
  final VoidCallback onPickAndExtractFile;
  final VoidCallback onExtractFromText;
  final void Function(
    int idx, {
    dynamic draftValue,
    String? status,
    String? correction,
    String? reason,
    String? respParty,
  }) onUpdateChecklistRow;

  const DraftBlReviewSheetView({
    super.key,
    required this.selectedImportFileId,
    required this.importFiles,
    required this.onSelectImportFile,
    required this.onRefresh,
    required this.controllers,
    this.comparisonResult,
    this.activeSession,
    this.isLoading = false,
    this.isUploadingFile = false,
    this.isSavingDraft = false,
    this.isCertifying = false,
    this.uploadedFileName,
    this.uploadedFileSize,
    this.extractionStatus,
    this.missingCriticalFields = const [],
    this.safetyWarning,
    required this.onSearchAndClone,
    required this.onSaveDraft,
    required this.onCertify,
    required this.onRequestAmendment,
    required this.onPickAndExtractFile,
    required this.onExtractFromText,
    required this.onUpdateChecklistRow,
  });

  @override
  State<DraftBlReviewSheetView> createState() => _DraftBlReviewSheetViewState();
}

class _DraftBlReviewSheetViewState extends State<DraftBlReviewSheetView> {
  bool _showReferenceAsVisualBL = true;

  @override
  Widget build(BuildContext context) {
    final sys = widget.comparisonResult?.systemData ?? {};
    final l = context.l10n;
    final c = widget.controllers;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. File Selector & Refresh Bar
          Card(
            elevation: 2,
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppTheme.borderOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SearchableDropdownField<int>(
                      value: widget.selectedImportFileId,
                      labelText: l.draftBlSelectImportFileLabel,
                      searchHintText: l.searchFileOrShipmentHint,
                      items: widget.importFiles
                          .map((f) => SearchableDropdownItem<int>(
                                value: f.importFileId,
                                label: '${f.primaryNameWithCode} - ${f.companyName}',
                              ))
                          .toList(),
                      onChanged: widget.onSelectImportFile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: l.draftBlRefreshAndCompare,
                    icon: Icons.sync,
                    variant: AppButtonVariant.primary,
                    isLoading: widget.isLoading,
                    onPressed: widget.isLoading ? null : widget.onRefresh,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Transport Header Bar
          DraftBlHeaderBar(
            blNumber: c.draftBlNumber.text.isNotEmpty
                ? c.draftBlNumber.text
                : (widget.comparisonResult?.draftData['draft_bl_number']?.toString() ?? ''),
            shippingLine: c.shippingLine.text.isNotEmpty ? c.shippingLine.text : sys['shipping_line']?.toString(),
            vesselName: c.vesselName.text.isNotEmpty ? c.vesselName.text : sys['vessel_name']?.toString(),
            voyageNumber: c.voyage.text.isNotEmpty ? c.voyage.text : sys['voyage_number']?.toString(),
            pol: c.pol.text.isNotEmpty ? c.pol.text : sys['pol']?.toString(),
            pod: c.pod.text.isNotEmpty ? c.pod.text : sys['pod']?.toString(),
            hasBlockingMismatch: widget.comparisonResult?.hasBlockingMismatch ?? false,
            openDiscrepanciesCount: widget.comparisonResult?.openDiscrepanciesCount ?? 0,
            isCertified: widget.activeSession?.isDraft == false,
            onSearchAndClone: widget.onSearchAndClone,
          ),
          const SizedBox(height: 12),

          // 3. Actions Bar
          DraftBlActionsBar(
            isApproving: widget.isCertifying,
            isSavingDraft: widget.isSavingDraft,
            isExtracting: widget.isUploadingFile,
            isLoading: widget.isLoading,
            hasBlockingMismatch: widget.comparisonResult?.hasBlockingMismatch ?? false,
            onApproveBl: widget.comparisonResult != null ? widget.onCertify : null,
            onSaveTempDraft: widget.comparisonResult != null ? widget.onSaveDraft : null,
            onRequestAmendment: widget.onRequestAmendment,
            onOcrReExtract: widget.onPickAndExtractFile,
            onExportPdf: widget.comparisonResult != null
                ? () => DraftBLExportService.exportDraftBLToPdf(
                      context: context,
                      systemData: widget.comparisonResult!.systemData,
                      draftData: widget.comparisonResult!.draftData,
                      draftBlNumber: c.draftBlNumber.text,
                      bookingNumber: c.bookingNo.text,
                    )
                : null,
            onExportExcel: widget.comparisonResult != null
                ? () => DraftBLExportService.exportDraftBLToExcel(
                      systemData: widget.comparisonResult!.systemData,
                      draftData: widget.comparisonResult!.draftData,
                      draftBlNumber: c.draftBlNumber.text,
                      bookingNumber: c.bookingNo.text,
                    )
                : null,
            onPrintBl: widget.comparisonResult != null
                ? () => DraftBLExportService.printDraftBL(
                      systemData: widget.comparisonResult!.systemData,
                      draftData: widget.comparisonResult!.draftData,
                      draftBlNumber: c.draftBlNumber.text,
                      bookingNumber: c.bookingNo.text,
                    )
                : null,
          ),
          const SizedBox(height: 14),

          // 4. Smart Extractor Upload Card
          DraftBlExtractorCard(
            isUploadingFile: widget.isUploadingFile,
            uploadedFileName: widget.uploadedFileName,
            uploadedFileSize: widget.uploadedFileSize,
            extractionStatus: widget.extractionStatus,
            missingCriticalFields: widget.missingCriticalFields,
            safetyWarning: widget.safetyWarning,
            blNumber: c.draftBlNumber.text,
            rawTextController: c.rawText,
            onPickAndExtractFile: widget.onPickAndExtractFile,
            onExtractFromText: widget.onExtractFromText,
            onBlNumberChanged: (newBl) => setState(() => c.draftBlNumber.text = newBl),
          ),
          const SizedBox(height: 14),

          // 5. Visual vs Grid Details Toggle
          if (_showReferenceAsVisualBL) ...[
            VisualDraftBLSheet(
              systemData: sys,
              draftData: sys,
              isReferenceOnly: true,
              title: l.draftBlReferenceVisualSheetTitle,
              subtitle: l.draftBlReferenceVisualSheetSub,
              onRefresh: widget.onRefresh,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: AppButton(
                label: l.draftBlSwitchToGridView,
                icon: Icons.grid_view,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: () => setState(() => _showReferenceAsVisualBL = false),
              ),
            ),
          ] else ...[
            DraftBlCargoDescriptionCard(
              shipper: sys['shipper']?.toString(),
              consignee: sys['consignee']?.toString(),
              notifyParty: sys['notify_party']?.toString(),
              goodsDescription: sys['goods_description']?.toString(),
              packagesCount: sys['qty_pkg'] as int?,
              grossWeight: (sys['total_gross_weight_kg'] as num?)?.toDouble(),
              netWeight: (sys['total_net_weight_kg'] as num?)?.toDouble(),
              cbm: (sys['cbm'] as num?)?.toDouble(),
              acidNumber: sys['acid_number']?.toString(),
              importerTaxId: sys['importer_tax_id']?.toString(),
              shipperRegId: sys['shipper_reg_id']?.toString(),
            ),
            const SizedBox(height: 12),
            DraftBlContainerSealTable(
              containerSummary: sys['container_summary']?.toString() ?? c.containerNo.text,
              containers: sys['containers'] as List<dynamic>?,
              totalGrossWeight: (sys['total_gross_weight_kg'] as num?)?.toDouble(),
              totalNetWeight: (sys['total_net_weight_kg'] as num?)?.toDouble(),
            ),
            const SizedBox(height: 12),
            DraftBlFreightTermsCard(
              freightTerms: sys['freight_terms']?.toString() ?? c.freightTerms.text,
              bookingNumber: sys['booking_no']?.toString() ?? c.bookingNo.text,
              placeOfDelivery: sys['place_of_delivery']?.toString() ?? c.placeOfDelivery.text,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: l.draftBlSwitchToVisualBl,
              icon: Icons.description,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              onPressed: () => setState(() => _showReferenceAsVisualBL = true),
            ),
            const SizedBox(height: 12),
          ],

          // 6. 20-Field Comparison Checklist Table Card
          Card(
            elevation: 2,
            color: AppTheme.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppTheme.borderOf(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rtl, color: AppTheme.cobalt, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        l.draftBlChecklistSectionTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.draftBlChecklistSectionSub,
                    style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 12),
                  ),
                  const Divider(height: 20),
                  DraftBlChecklistTable(
                    checklist: widget.comparisonResult?.checklist ?? [],
                    onUpdateRow: widget.onUpdateChecklistRow,
                  ),
                ],
              ),
            ),
          ),

          // 7. Extracted Visual Sheet preview
          if (widget.comparisonResult != null) ...[
            const SizedBox(height: 16),
            VisualDraftBLSheet(
              systemData: sys,
              draftData: widget.comparisonResult!.draftData,
              draftBlNumber: c.draftBlNumber.text.isNotEmpty ? c.draftBlNumber.text : null,
              bookingNumber: c.bookingNo.text.isNotEmpty ? c.bookingNo.text : null,
              title: l.draftBlExtractedVisualSheetTitle,
              subtitle: l.draftBlExtractedVisualSheetSub,
            ),
          ],
        ],
      ),
    );
  }
}
