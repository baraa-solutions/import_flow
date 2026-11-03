import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/import_documentation_model.dart';
import '../../providers/import_documentation_provider.dart';
import 'nafeza_acid_service.dart';

class AcidSessionsRegistryTab extends ConsumerStatefulWidget {
  final ValueChanged<AcidRegistrationModel> onLoadSessionForEdit;
  final ValueChanged<AcidRegistrationModel> onCloneAcidSelected;
  final VoidCallback onNewRequest;

  const AcidSessionsRegistryTab({
    super.key,
    required this.onLoadSessionForEdit,
    required this.onCloneAcidSelected,
    required this.onNewRequest,
  });

  @override
  ConsumerState<AcidSessionsRegistryTab> createState() => _AcidSessionsRegistryTabState();
}

class _AcidSessionsRegistryTabState extends ConsumerState<AcidSessionsRegistryTab> {
  String _acidSearchQuery = '';

  void _confirmDeleteAcidSession(AcidRegistrationModel session) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 24),
            const SizedBox(width: 8),
            Text(l.confirmSoftDelete, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CopyableText('ACID (${session.acidCode}) — (${session.acidNumber})'),
            const SizedBox(height: 10),
            Text(l.confirmSoftDelete, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          AppButton(
            label: l.cancel,
            onPressed: () => Navigator.pop(ctx),
            variant: AppButtonVariant.secondary,
          ),
          AppButton(
            label: l.delete,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(acidSessionsProvider.notifier).softDeleteAcidSession(session.acidId);
                await ref.read(importFilesProvider.notifier).fetchImportFiles();
                await ref.read(acidTrackerProvider.notifier).fetchAcidTracker();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    AppTheme.snackBar(context, l.acidSessionDeletedSuccess(session.acidCode)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  showErrorDetailsDialog(context, title: l.errorDeletingAcid, error: e);
                }
              }
            },
            variant: AppButtonVariant.danger,
            icon: Icons.delete_forever,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acidSessions = ref.watch(acidSessionsProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

    final filtered = acidSessions.where((s) {
      if (_acidSearchQuery.isEmpty) return true;
      final q = _acidSearchQuery.toLowerCase();
      return s.acidNumber.toLowerCase().contains(q) ||
          (s.importFileCode != null && s.importFileCode!.toLowerCase().contains(q)) ||
          s.exporterName.toLowerCase().contains(q);
    }).toList();

    final searchField = TextField(
      key: const Key('acidRegistrySearchField'),
      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
      decoration: InputDecoration(
        hintText: l.searchAcidRegistryHint,
        hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
        prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      ),
      onChanged: (val) => setState(() => _acidSearchQuery = val),
    );

    final actionButtons = [
      AppButton(
        key: const Key('acidRegistryNewRequestBtn'),
        label: l.newAcidRequestButton,
        onPressed: widget.onNewRequest,
        icon: Icons.add,
      ),
      AppButton(
        key: const Key('acidRegistryCopyBtn'),
        label: l.copyTable,
        onPressed: () => NafezaAcidService.copyAcidRegistryAsTsv(context, filtered, importFiles),
        variant: AppButtonVariant.secondary,
        icon: Icons.copy,
      ),
      AppButton(
        key: const Key('acidRegistryExcelBtn'),
        label: l.exportExcel,
        onPressed: () => NafezaAcidService.exportAcidRegistryToExcel(context, filtered, importFiles),
        variant: AppButtonVariant.secondary,
        icon: Icons.table_chart,
      ),
      AppButton(
        key: const Key('acidRegistryPdfBtn'),
        label: l.exportPdf,
        onPressed: () => NafezaAcidService.exportAcidRegistryToPdf(context, filtered, importFiles),
        variant: AppButtonVariant.secondary,
        icon: Icons.picture_as_pdf,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actionButtons,
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 8),
                  ...actionButtons.map((btn) => Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: btn,
                      )),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (filtered.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: AppTheme.cardDecorationOf(context),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.borderStrong),
                    const SizedBox(height: 12),
                    Text(
                      l.noAcidsFound,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              EnterpriseDataTable<AcidRegistrationModel>(
                data: filtered,
                storageKey: 'nafeza_acid_registry_table',
                columns: [
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'actions',
                    title: l.actionCol,
                    width: 155,
                    isSortable: false,
                    isSearchable: false,
                    cellBuilder: (context, s, index) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.edit_note, color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt, size: 20),
                            tooltip: l.edit,
                            onPressed: () => widget.onLoadSessionForEdit(s),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            key: Key('cloneRowBtn_${s.acidId}'),
                            icon: Icon(Icons.copy_all, color: isDark ? AppTheme.wcagEmerald : AppTheme.emerald, size: 20),
                            tooltip: l.cloneAcidRecordTooltip,
                            onPressed: () => widget.onCloneAcidSelected(s),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 20),
                            tooltip: l.delete,
                            onPressed: () => _confirmDeleteAcidSession(s),
                          ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'acid_number',
                    title: l.acidNumberCol,
                    width: 170,
                    isSortable: true,
                    searchValue: (s) => s.acidNumber,
                    exportValue: (s) => s.acidNumber,
                    cellBuilder: (context, s, index) {
                      return InkWell(
                        onTap: () => CopyHelper.copy(context, s.acidNumber),
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          s.acidNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                          ),
                        ),
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'import_file',
                    title: l.importFile,
                    width: 180,
                    isSortable: true,
                    searchValue: (s) {
                      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
                      return matchedFile?.displayName ?? s.importFileCode ?? '-';
                    },
                    exportValue: (s) {
                      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
                      return matchedFile?.displayName ?? s.importFileCode ?? '-';
                    },
                    cellBuilder: (context, s, index) {
                      final matchedFile = importFiles.where((f) => f.importFileId == s.importFileId).firstOrNull;
                      final fileLabel = matchedFile?.displayName ?? s.importFileCode ?? '-';
                      final poLabel = (s.poNumber != null && s.poNumber!.trim().isNotEmpty)
                          ? s.poNumber!.trim()
                          : (matchedFile?.poNumber ?? s.proformaInvoiceNo);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
                            ),
                          ),
                          if (poLabel.isNotEmpty && poLabel != '-')
                            Text(
                              '${l.poLabelPrefix}: $poLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                            ),
                        ],
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'exporter',
                    title: l.foreignExporterCol,
                    width: 160,
                    isSortable: true,
                    searchValue: (s) => s.exporterName,
                    exportValue: (s) => s.exporterName,
                    cellBuilder: (context, s, index) => Text(
                      s.exporterName,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'importer',
                    title: l.importerCompanyCol,
                    width: 160,
                    isSortable: true,
                    searchValue: (s) => s.importerName,
                    exportValue: (s) => s.importerName,
                    cellBuilder: (context, s, index) => Text(
                      s.importerName,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'issue_date',
                    title: l.issueDateCol,
                    width: 120,
                    isSortable: true,
                    searchValue: (s) => s.generatedDate ?? s.requestedDate ?? '',
                    exportValue: (s) => (s.generatedDate ?? s.requestedDate ?? '').substring(0, min(10, (s.generatedDate ?? s.requestedDate ?? '').length)),
                    cellBuilder: (context, s, index) {
                      final dateStr = s.generatedDate ?? s.requestedDate ?? '';
                      return Text(
                        dateStr.isNotEmpty ? dateStr.substring(0, min(10, dateStr.length)) : '-',
                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'expiry_date',
                    title: l.expiryDateCol,
                    width: 120,
                    isSortable: true,
                    searchValue: (s) => s.expiryDate ?? '',
                    exportValue: (s) => (s.expiryDate ?? '').substring(0, min(10, (s.expiryDate ?? '').length)),
                    cellBuilder: (context, s, index) {
                      final expStr = s.expiryDate ?? '';
                      return Text(
                        expStr.isNotEmpty ? expStr.substring(0, min(10, expStr.length)) : '-',
                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                      );
                    },
                  ),
                  EnterpriseColumn<AcidRegistrationModel>(
                    id: 'validity_status',
                    title: l.validityStatusCol,
                    width: 130,
                    isSortable: true,
                    searchValue: (s) {
                      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
                      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
                      return isIssued ? l.issuedAndValidStatus : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
                    },
                    exportValue: (s) {
                      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
                      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
                      return isIssued ? l.issuedAndValidStatus : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
                    },
                    cellBuilder: (context, s, index) {
                      final isIssued = s.status == 'Issued' || s.status == 'ISSUED';
                      final isDraft = s.status == 'DRAFT' || s.status == 'Draft';
                      final statusLabel = isIssued
                          ? l.issuedAndValidStatus
                          : (isDraft ? l.tempDraftStatus : l.underReviewStatus);
                      final severity = isIssued
                          ? AppSeverity.success
                          : (isDraft ? AppSeverity.warning : AppSeverity.info);
                      return AppStatusBadge(
                        label: statusLabel,
                        severity: severity,
                        size: AppStatusBadgeSize.small,
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
