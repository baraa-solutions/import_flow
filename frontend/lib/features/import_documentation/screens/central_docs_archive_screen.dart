import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/import_documentation_provider.dart';
import '../services/central_docs_archive_export_service.dart';

class CentralDocsArchiveScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final bool isEmbedded;
  const CentralDocsArchiveScreen({
    super.key,
    this.initialImportFileId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<CentralDocsArchiveScreen> createState() => _CentralDocsArchiveScreenState();
}

class _CentralDocsArchiveScreenState extends ConsumerState<CentralDocsArchiveScreen> {
  int? _selectedImportFileId;

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CentralDocsArchiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != null && widget.initialImportFileId != _selectedImportFileId) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
      });
    }
  }

  void _copyToClipboard(String text, String successMessage) {
    CopyHelper.copy(context, text, customMessage: successMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final content = SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Selection Bar
            _buildSelectionBar(importFiles),
            const SizedBox(height: 16),

            if (_selectedImportFileId == null)
              _buildEmptyPlaceholder()
            else
              _buildArchiveContent(_selectedImportFileId!),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return Container(
        color: const Color(0xFFF4F6F9),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n.centralDocsArchiveTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.charcoal,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: l10n.closeAndReturn,
            icon: Icon(Icons.close, color: Colors.white, size: density.buttonIconSize),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
    );
  }

  Widget _buildSelectionBar(List<dynamic> importFiles) {
    final l10n = context.l10n;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SearchableDropdownField<int>(
                value: _selectedImportFileId,
                labelText: l10n.selectCentralArchiveFileLabel,
                searchHintText: l10n.selectCentralArchiveFileHint,
                items: importFiles
                    .map((f) => SearchableDropdownItem<int>(
                          value: f.importFileId,
                          label: '${f.primaryNameWithCode} - ${f.companyName} (${f.supplierName})',
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedImportFileId = v);
                },
              ),
            ),
            const SizedBox(width: 16),
            if (_selectedImportFileId != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(l10n.refreshArchiveBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  ref.invalidate(centralArchiveProvider(_selectedImportFileId!));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.folder_special_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            l10n.selectShipmentFilePrompt,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.centralArchivePlaceholderDesc,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveContent(int fileId) {
    final l10n = context.l10n;
    final archiveAsync = ref.watch(centralArchiveProvider(fileId));

    return archiveAsync.when(
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(60.0),
          child: Column(
            children: [
              const CircularProgressIndicator(color: AppTheme.cobalt),
              const SizedBox(height: 16),
              Text(l10n.centralArchiveLoadingPrompt, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      error: (err, stack) => Card(
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.centralArchiveLoadError(err.toString()),
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
      data: (data) => _buildArchiveView(data),
    );
  }

  Widget _buildExportToolbar(Map<String, dynamic> data) {
    final l10n = context.l10n;
    final exportService = CentralDocsArchiveExportService(context: context, data: data);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.charcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: Text(l10n.centralDocsExportTsvBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => exportService.exportToTsv(),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: Text(l10n.centralDocsExportExcelBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => exportService.exportToExcel(),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimson,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(l10n.centralDocsPrintPdfBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => exportService.printOrSavePdf(),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cobalt,
              side: const BorderSide(color: AppTheme.cobalt),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: Text(l10n.centralDocsCopyDossierBtn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => exportService.copyDossierToClipboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveView(Map<String, dynamic> data) {
    final l10n = context.l10n;
    final readiness = data['readiness_status']?.toString() ?? 'IN_REVIEW';
    final score = (data['readiness_score'] as num?)?.toDouble() ?? 0.0;
    final totalCritical = data['total_critical_discrepancies'] as int? ?? 0;
    final totalWarning = data['total_warning_discrepancies'] as int? ?? 0;
    final checklist = data['all_rectifications_checklist'] as List<dynamic>? ?? [];

    final finalInv = data['final_invoice'] as Map<String, dynamic>? ?? {};
    final finalPkg = data['final_packing_list'] as Map<String, dynamic>? ?? {};
    final draftBl = data['draft_bl'] as Map<String, dynamic>? ?? {};
    final draftCoo = data['certificate_of_origin'] as Map<String, dynamic>? ?? {};
    final draftInsp = data['inspection_certificate'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Export Toolbar
        _buildExportToolbar(data),

        // 1. Overview & Readiness Header Card
        _buildOverviewHeaderCard(data, readiness, score, totalCritical, totalWarning),
        const SizedBox(height: 16),

        // 2. Import Requirements (BP-011) Compliance & Live Alerts Summary Card
        _buildImportRequirementsComplianceCard(data),
        const SizedBox(height: 16),

        // 3. Master Discrepancies & Rectifications Summary
        _buildMasterRectificationsCard(data, checklist, totalCritical, totalWarning),
        const SizedBox(height: 20),

        // 4. Section Title
        Row(
          children: [
            const Icon(Icons.library_books, color: AppTheme.cobalt),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.fiveCoreDocsSectionTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 5. Five Core & Conditional Document Cards
        _buildDocumentCard(
          doc: finalInv,
          icon: Icons.receipt_long,
          color: Colors.indigo,
          defaultTitle: l10n.docTitleCommercialInvoice,
          isMandatoryCore: true,
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          doc: finalPkg,
          icon: Icons.inventory_2,
          color: Colors.teal,
          defaultTitle: l10n.docTitlePackingList,
          isMandatoryCore: true,
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          doc: draftBl,
          icon: Icons.directions_boat,
          color: Colors.blue.shade800,
          defaultTitle: l10n.docTitleBillOfLading,
          isMandatoryCore: true,
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          doc: draftCoo,
          icon: Icons.public,
          color: Colors.purple.shade700,
          defaultTitle: l10n.docTitleCertificateOfOrigin,
          isMandatoryCore: false,
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          doc: draftInsp,
          icon: Icons.verified_user,
          color: Colors.orange.shade800,
          defaultTitle: l10n.docTitleInspectionCertificate,
          isMandatoryCore: false,
        ),
        const SizedBox(height: 30),

        // Footer Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.crimson,
                side: const BorderSide(color: AppTheme.crimson),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.close),
              label: Text(l10n.closeAndReturn, style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImportRequirementsComplianceCard(Map<String, dynamic> data) {
    final l10n = context.l10n;
    final reqSummary = data['import_requirements_summary'] as Map<String, dynamic>? ?? {};
    final tariffAlert = data['tariff_exemption_alert']?.toString();
    final goeicAlert = data['goeic_inspection_alert']?.toString();
    final decreeAlert = data['decree_43_alert']?.toString();

    final hsCode = reqSummary['hs_code']?.toString() ?? 'N/A';
    final commodity = reqSummary['commodity_description']?.toString() ?? '';
    final origin = reqSummary['country_of_origin']?.toString() ?? '';
    final cooRequired = reqSummary['coo_required'] as bool? ?? false;
    final cooType = reqSummary['coo_type']?.toString() ?? 'Standard COO';
    final inspRequired = reqSummary['inspection_required'] as bool? ?? false;
    final inspAgency = reqSummary['inspection_body']?.toString() ?? 'COTECNA / SGS';
    final decree43 = reqSummary['decree_43_applicable'] as bool? ?? false;
    final whiteList = reqSummary['white_list_verified'] as bool? ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.rule_folder, color: AppTheme.cobalt, size: 20),
                    ),
                    Text(
                      l10n.complianceReportHeader,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => CopyHelper.copy(
                    context,
                    l10n.complianceSummaryTag(origin.isNotEmpty ? origin : 'N/A', hsCode, commodity.isNotEmpty ? commodity : 'N/A'),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.complianceSummaryTag(origin.isNotEmpty ? origin : 'N/A', hsCode, commodity.isNotEmpty ? commodity : 'N/A'),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 13, color: Colors.teal.shade800),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Live Alert Banners
            if (tariffAlert != null && tariffAlert.isNotEmpty) ...[
              InkWell(
                onTap: () => CopyHelper.copy(context, tariffAlert),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tariffAlert,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown.shade900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_rounded, size: 15, color: Colors.brown.shade900),
                    ],
                  ),
                ),
              ),
            ],
            if (goeicAlert != null && goeicAlert.isNotEmpty) ...[
              InkWell(
                onTap: () => CopyHelper.copy(context, goeicAlert),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.blue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          goeicAlert,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_rounded, size: 15, color: Colors.blue.shade900),
                    ],
                  ),
                ),
              ),
            ],
            if (decreeAlert != null && decreeAlert.isNotEmpty) ...[
              InkWell(
                onTap: () => CopyHelper.copy(context, decreeAlert),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade300, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.domain_verification, color: Colors.purple, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          decreeAlert,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_rounded, size: 15, color: Colors.purple.shade900),
                    ],
                  ),
                ),
              ),
            ],

            // Requirements Specs Matrix
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildComplianceChip(
                  label: l10n.chipCooLabel,
                  statusText: cooRequired ? l10n.cooRequiredText(cooType) : l10n.cooNotRequiredText,
                  isRequired: cooRequired,
                  icon: Icons.public,
                ),
                _buildComplianceChip(
                  label: l10n.chipVocLabel,
                  statusText: inspRequired ? l10n.inspRequiredText(inspAgency) : l10n.inspNotRequiredText,
                  isRequired: inspRequired,
                  icon: Icons.security,
                ),
                _buildComplianceChip(
                  label: l10n.chipDecree43Label,
                  statusText: decree43 ? (whiteList ? l10n.decree43WhiteListed : l10n.decree43RegistrationRequired) : l10n.decree43NotApplicable,
                  isRequired: decree43 && !whiteList,
                  icon: Icons.factory,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceChip({
    required String label,
    required String statusText,
    required bool isRequired,
    required IconData icon,
  }) {
    final bg = isRequired ? Colors.blue.shade50 : Colors.green.shade50;
    final border = isRequired ? Colors.blue.shade300 : Colors.green.shade300;
    final fg = isRequired ? Colors.blue.shade900 : Colors.green.shade800;

    return InkWell(
      onTap: () => CopyHelper.copy(context, '$label: $statusText'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label: $statusText',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.copy_rounded, size: 12, color: fg),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewHeaderCard(Map<String, dynamic> data, String readiness, double score, int critical, int warning) {
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
                          color: AppTheme.cobalt.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.customsFileNumberLabel(data['custom_file_number']),
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.copy_rounded, size: 14, color: Colors.grey.shade700),
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
                      color: readinessColor.withOpacity(0.12),
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
                      _buildHeaderInfoRow(l10n.importerCompanyLabel, data['importer_name'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(l10n.exporterSupplierLabel, data['supplier_name'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(l10n.acidNumberLabel, data['acid_number'] ?? 'N/A', isBold: true),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(l10n.shippingRouteLabel, '${data['port_of_loading'] ?? 'N/A'} ➔ ${data['port_of_discharge'] ?? 'Alexandria'}'),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(l10n.totalPackagesAndWeightLabel, l10n.packagesCountText(pkgsCount, weightCount)),
                      const SizedBox(height: 8),
                      _buildHeaderInfoRow(l10n.totalInvoiceValueLabel, totalFormatted),
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
                          _buildHeaderInfoRow(l10n.importerCompanyLabel, data['importer_name'] ?? 'N/A'),
                          const SizedBox(height: 8),
                          _buildHeaderInfoRow(l10n.exporterSupplierLabel, data['supplier_name'] ?? 'N/A'),
                          const SizedBox(height: 8),
                          _buildHeaderInfoRow(l10n.acidNumberLabel, data['acid_number'] ?? 'N/A', isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderInfoRow(l10n.shippingRouteLabel, '${data['port_of_loading'] ?? 'N/A'} ➔ ${data['port_of_discharge'] ?? 'Alexandria'}'),
                          const SizedBox(height: 8),
                          _buildHeaderInfoRow(l10n.totalPackagesAndWeightLabel, l10n.packagesCountText(pkgsCount, weightCount)),
                          const SizedBox(height: 8),
                          _buildHeaderInfoRow(l10n.totalInvoiceValueLabel, totalFormatted),
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

  Widget _buildHeaderInfoRow(String label, String value, {bool isBold = false}) {
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
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isBold ? AppTheme.charcoal : Colors.grey.shade900,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterRectificationsCard(Map<String, dynamic> data, List<dynamic> checklist, int critical, int warning) {
    final l10n = context.l10n;
    final emailText = data['supplier_email_rectification_text']?.toString() ?? '';
    final waText = data['supplier_whatsapp_rectification_text']?.toString() ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: critical > 0 ? AppTheme.crimson.withOpacity(0.5) : (warning > 0 ? AppTheme.orange.withOpacity(0.5) : AppTheme.emerald.withOpacity(0.5)), width: 1.5),
      ),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      critical > 0 ? Icons.gavel : (warning > 0 ? Icons.warning_amber : Icons.verified),
                      color: critical > 0 ? AppTheme.crimson : (warning > 0 ? AppTheme.orange : AppTheme.emerald),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.masterRectificationsHeader,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cobalt,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.email, color: Colors.white, size: 16),
                      label: Text(l10n.copySupplierEmailBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _copyToClipboard(emailText, l10n.copySupplierEmailSuccess),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.chat, color: Colors.white, size: 16),
                      label: Text(l10n.copyWhatsAppBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _copyToClipboard(waText, l10n.copyWhatsAppSuccess),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            if (checklist.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.emerald),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.noDiscrepanciesSuccessMessage,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: checklist.map((item) {
                  final sev = item['severity']?.toString() ?? 'WARNING';
                  final isCrit = sev == 'CRITICAL';
                  final docField = '${item['document']} - [${item['field']}]';
                  final issue = item['issue'] ?? '';
                  final rect = item['rectification'] ?? '';
                  final copyContent = '$docField: $issue ➔ $rect';

                  return InkWell(
                    onTap: () => CopyHelper.copy(context, copyContent),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCrit ? Colors.red.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCrit ? Colors.red.shade300 : Colors.amber.shade400),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(isCrit ? Icons.error : Icons.warning_amber, color: isCrit ? AppTheme.crimson : AppTheme.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        docField,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isCrit ? AppTheme.crimson : Colors.brown.shade900),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCrit ? Colors.red.shade100 : Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isCrit ? l10n.severityCritical : l10n.severityWarning,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCrit ? Colors.red.shade900 : Colors.brown.shade900),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.copy_rounded, size: 14, color: isCrit ? AppTheme.crimson : AppTheme.orange),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(l10n.discrepancyIssueLabel(issue), style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                                const SizedBox(height: 4),
                                Text(l10n.discrepancyRectificationLabel(rect), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isCrit ? Colors.red.shade900 : Colors.brown.shade900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required Map<String, dynamic> doc,
    required IconData icon,
    required Color color,
    required String defaultTitle,
    bool isMandatoryCore = false,
  }) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final title = (isAr ? doc['title_ar'] : doc['title_en'])?.toString() ?? doc['title_ar']?.toString() ?? defaultTitle;
    final isAvail = doc['is_available'] as bool? ?? false;
    final isWaived = doc['is_waived'] as bool? ?? false;
    final waiveReason = doc['waive_reason']?.toString();
    final legalNote = doc['legal_requirement_note']?.toString();
    final status = doc['status']?.toString() ?? 'NOT_STARTED';
    final refNo = doc['document_reference']?.toString() ?? 'N/A';
    final details = doc['details'] as Map<String, dynamic>? ?? {};
    final discrepancies = doc['discrepancies'] as List<dynamic>? ?? [];

    Color badgeColor;
    String badgeText;
    if (isWaived || status == 'WAIVED') {
      badgeColor = Colors.teal;
      badgeText = l10n.docStatusWaived;
    } else if (status == 'APPROVED') {
      badgeColor = AppTheme.emerald;
      badgeText = l10n.docStatusApproved;
    } else if (status == 'MODIFICATIONS_REQUESTED') {
      badgeColor = AppTheme.crimson;
      badgeText = l10n.docStatusModificationsRequested;
    } else if (status == 'REVIEW_PENDING') {
      badgeColor = AppTheme.orange;
      badgeText = l10n.docStatusReviewPending;
    } else {
      badgeColor = Colors.grey;
      badgeText = l10n.docStatusNotStarted;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        initiallyExpanded: discrepancies.isNotEmpty || isAvail || isWaived,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMandatoryCore ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isMandatoryCore ? Colors.red.shade200 : Colors.blue.shade200),
                  ),
                  child: Text(
                    isMandatoryCore ? l10n.docMandatoryCore : l10n.docConditional,
                    style: TextStyle(
                      fontSize: DisplayDensityMode.clampFontSize(11.0),
                      fontWeight: FontWeight.bold,
                      color: isMandatoryCore ? Colors.red.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (refNo.isNotEmpty && refNo != 'N/A')
                  InkWell(
                    onTap: () => CopyHelper.copy(context, refNo),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.docReferenceLabel(refNo), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(width: 4),
                          Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  )
                else
                  Text(l10n.docReferenceLabel(refNo), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(badgeText, style: TextStyle(fontSize: DisplayDensityMode.clampFontSize(11.0), fontWeight: FontWeight.bold, color: badgeColor)),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Legal requirement / Waive reason Note Banner
                if (legalNote != null && legalNote.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isWaived ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isWaived ? Colors.green.shade200 : Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(isWaived ? Icons.check_circle : Icons.info_outline, size: 16, color: isWaived ? Colors.green.shade800 : Colors.blue.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            legalNote,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isWaived ? Colors.green.shade900 : Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Details Grid
                if (details.isNotEmpty) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: details.entries.map((e) {
                      final entryText = '${e.key}: ${e.value}';
                      return InkWell(
                        onTap: () => CopyHelper.copy(context, entryText, customMessage: l10n.centralDocsCopyDetailSuccess),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(entryText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade500),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Document Discrepancies
                if (discrepancies.isNotEmpty) ...[
                  Text(l10n.docModificationsRequestedTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.crimson)),
                  const SizedBox(height: 6),
                  ...discrepancies.map((d) {
                    final issueText = '${d['field']}: ${d['issue']} ➔ ${d['rectification']}';
                    return InkWell(
                      onTap: () => CopyHelper.copy(context, issueText, customMessage: l10n.centralDocsCopyDiscrepancySuccess),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_left, color: AppTheme.crimson, size: 18),
                            Expanded(
                              child: Text(
                                issueText,
                                style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_rounded, size: 13, color: AppTheme.crimson),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else if (isWaived) ...[
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.teal, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          waiveReason ?? l10n.docWaivedDefaultDesc,
                          style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ] else if (isAvail) ...[
                  Row(
                    children: [
                      const Icon(Icons.check, color: AppTheme.emerald, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.docNoDiscrepanciesDesc,
                          style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
