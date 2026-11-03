import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/central_docs_archive/archive_compliance_card.dart';
import '../widgets/central_docs_archive/archive_document_card.dart';
import '../widgets/central_docs_archive/archive_export_toolbar.dart';
import '../widgets/central_docs_archive/archive_master_rectifications_card.dart';
import '../widgets/central_docs_archive/archive_overview_header_card.dart';
import '../widgets/idoc_ui.dart';

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
      final fileId = _selectedImportFileId;
      if (fileId != null) ref.invalidate(centralArchiveProvider(fileId));
    });
  }

  @override
  void didUpdateWidget(covariant CentralDocsArchiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != null && widget.initialImportFileId != _selectedImportFileId) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
      });
      ref.invalidate(centralArchiveProvider(widget.initialImportFileId!));
    }
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
        color: AppTheme.cloudWhite,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.inventory_2_outlined,
        title: l10n.centralDocsArchiveTitle,
        actions: [
          IconButton(
            tooltip: l10n.closeAndReturn,
            icon: Icon(Icons.close, color: AppTheme.white, size: density.buttonIconSize),
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
              IdocUi.fit(AppButton(
                label: l10n.refreshArchiveBtn,
                icon: Icons.refresh,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  ref.invalidate(centralArchiveProvider(_selectedImportFileId!));
                },
              )),
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
          Icon(Icons.folder_special_outlined, size: 80, color: AppTheme.textMutedOf(context)),
          const SizedBox(height: 16),
          Text(
            l10n.selectShipmentFilePrompt,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryOf(context)),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.centralArchivePlaceholderDesc,
            style: TextStyle(fontSize: 14, color: AppTheme.textMutedOf(context)),
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
        color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.error, color: AppTheme.crimson, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.centralArchiveLoadError(ApiErrorText.of(l10n, err)),
                  style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (data) => _buildArchiveView(data),
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
        ArchiveExportToolbar(data: data),
        ArchiveOverviewHeaderCard(
          data: data,
          readiness: readiness,
          score: score,
          critical: totalCritical,
          warning: totalWarning,
        ),
        const SizedBox(height: 16),
        ArchiveComplianceCard(data: data),
        const SizedBox(height: 16),
        ArchiveMasterRectificationsCard(
          data: data,
          checklist: checklist,
          critical: totalCritical,
          warning: totalWarning,
        ),
        const SizedBox(height: 20),
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
        ArchiveDocumentCard(
          doc: finalInv,
          icon: Icons.receipt_long,
          color: AppTheme.wcagCobalt,
          defaultTitle: l10n.docTitleCommercialInvoice,
          isMandatoryCore: true,
        ),
        const SizedBox(height: 12),
        ArchiveDocumentCard(
          doc: finalPkg,
          icon: Icons.inventory_2,
          color: AppTheme.emerald,
          defaultTitle: l10n.docTitlePackingList,
          isMandatoryCore: true,
        ),
        const SizedBox(height: 12),
        ArchiveDocumentCard(
          doc: draftBl,
          icon: Icons.directions_boat,
          color: AppTheme.severityForegroundOf(context, AppSeverity.info),
          defaultTitle: l10n.docTitleBillOfLading,
          isMandatoryCore: true,
        ),
        const SizedBox(height: 12),
        ArchiveDocumentCard(
          doc: draftCoo,
          icon: Icons.public,
          color: AppTheme.severityForegroundOf(context, AppSeverity.info),
          defaultTitle: l10n.docTitleCertificateOfOrigin,
          isMandatoryCore: false,
        ),
        const SizedBox(height: 12),
        ArchiveDocumentCard(
          doc: draftInsp,
          icon: Icons.verified_user,
          color: AppTheme.severityForegroundOf(context, AppSeverity.warning),
          defaultTitle: l10n.docTitleInspectionCertificate,
          isMandatoryCore: false,
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IdocUi.fit(AppButton(
              label: l10n.closeAndReturn,
              icon: Icons.close,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.of(context).maybePop(),
            )),
          ],
        ),
      ],
    );
  }
}
