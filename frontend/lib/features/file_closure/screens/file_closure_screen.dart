import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/reopen_shipment_dialog.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/file_closure_model.dart';
import '../providers/file_closure_provider.dart';
import '../widgets/closed_files_banner.dart';
import '../widgets/closure_record_card.dart';
import '../widgets/file_closure_form_dialog.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';
import '../widgets/search_and_clone_file_closure_dialog.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/widgets/buttons/app_button.dart';

class FileClosureScreen extends ConsumerStatefulWidget {
  const FileClosureScreen({super.key});

  @override
  ConsumerState<FileClosureScreen> createState() => _FileClosureScreenState();
}

class _FileClosureScreenState extends ConsumerState<FileClosureScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final closuresState = ref.read(fileClosureProvider);
      if (!closuresState.isLoading) {
        ref.read(fileClosureProvider.notifier).fetchClosures();
      }
      final filesState = ref.read(importFilesProvider);
      if (!filesState.isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCloseFileDialog({ImportFileClosureModel? initialRecord, bool isCloneDraft = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FileClosureFormDialog(
        initialRecord: initialRecord,
        isCloneDraft: isCloneDraft,
      ),
    );
  }

  void _openSearchAndCloneDialog(List<ImportFileClosureModel> records) {
    showDialog(
      context: context,
      builder: (c) => SearchAndCloneFileClosureDialog(
        records: records,
        onSelectRecord: (selected) => _onCloneClosure(selected),
      ),
    );
  }

  void _onCloneClosure(ImportFileClosureModel source) {
    final l = context.l10n;
    final isAr = l.isArabic;
    final newDraftCode = 'CLOSURE-DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: l.closureCloneEntityType,
            sourceCode: source.closureCode,
            suggestedNewCode: newDraftCode,
            sourceTitle: '${source.closureCode} (${source.isFullyVerified ? l.closureCloneSourceArchived : l.closureCloneSourceDraft})',
            copiedFieldsSummary: {
              l.closureCloneFieldFileId: '#${source.importFileId}',
              l.closureCloneFieldAuditor: source.auditorName,
              l.closureCloneFieldVault: source.archiveLocation,
              l.closureCloneFieldConditions: '${closureCompletedCount(source.closureChecklist)} / 5',
              if (source.archivalNotes != null && source.archivalNotes!.isNotEmpty)
                l.closureCloneFieldNotes: source.archivalNotes!,
            },
            mandatorilyResetFields: [
              l.closureCloneReset1,
              l.closureCloneReset2,
              l.closureCloneReset3,
              l.closureCloneReset4,
            ],
            allowCopyLineItems: true,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final clonedChecklist = copyLineItems
                  ? ClosureChecklistModel(
                      docsVerified: source.closureChecklist.docsVerified,
                      customsCleared: source.closureChecklist.customsCleared,
                      warehouseReceived: source.closureChecklist.warehouseReceived,
                      landedCostSettled: source.closureChecklist.landedCostSettled,
                      tasksClosed: source.closureChecklist.tasksClosed,
                    )
                  : ClosureChecklistModel(
                      docsVerified: false,
                      customsCleared: false,
                      warehouseReceived: false,
                      landedCostSettled: false,
                      tasksClosed: false,
                    );

              final cloned = ImportFileClosureModel(
                closureId: 0,
                closureCode: newCode,
                importFileId: source.importFileId,
                closureChecklist: clonedChecklist,
                auditorName: source.auditorName,
                archiveLocation: source.archiveLocation,
                archivalNotes: notes ?? source.archivalNotes,
                status: 'Draft',
                isActive: true,
                closedAt: DateTime.now().toIso8601String(),
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showCloseFileDialog(initialRecord: cloned, isCloneDraft: true);
                }
              });
            },
          ),
        ),
      ),
    );
  }

  void _copyClosureRowTsv(
    ImportFileClosureModel r,
    ImportFileModel? file,
    AppLocalizations l10n,
  ) {
    final fileTitle = file != null ? file.primaryNameWithCode : '#${r.importFileId}';
    final chk = r.closureChecklist;
    final headers = [
      l10n.fileClosureColClosureCode,
      l10n.fileClosureColImportFile,
      l10n.fileClosureColArchiveVault,
      l10n.fileClosureColAuditor,
      l10n.fileClosureColClosedDate,
      l10n.fileClosureColDocsVerified,
      l10n.fileClosureColCustomsCleared,
      l10n.fileClosureColWarehouseReceived,
      l10n.fileClosureColLandedCostSettled,
      l10n.fileClosureColTasksClosed,
      l10n.fileClosureColNotes,
    ];
    final values = [
      r.closureCode,
      fileTitle,
      r.archiveLocation,
      r.auditorName,
      r.closedAt,
      chk.docsVerified ? '100%' : '0%',
      chk.customsCleared ? '100%' : '0%',
      chk.warehouseReceived ? '100%' : '0%',
      chk.landedCostSettled ? '100%' : '0%',
      chk.tasksClosed ? '100%' : '0%',
      r.archivalNotes ?? '',
    ];

    TableCopyHelper.copyRow(
      context,
      values,
      headers: headers,
      customMessage: l10n.copyFileClosureRowSuccess,
    );
  }

  void _copyArchivedFilesTsv(List<ImportFileClosureModel> records, Map<int, ImportFileModel> filesMap) {
    final l10n = context.l10n;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fileClosureEmptyRecords), backgroundColor: AppTheme.orange),
      );
      return;
    }

    final headers = [
      l10n.fileClosureColClosureCode,
      l10n.fileClosureColImportFile,
      l10n.fileClosureColArchiveVault,
      l10n.fileClosureColAuditor,
      l10n.fileClosureColClosedDate,
      l10n.fileClosureColDocsVerified,
      l10n.fileClosureColCustomsCleared,
      l10n.fileClosureColWarehouseReceived,
      l10n.fileClosureColLandedCostSettled,
      l10n.fileClosureColTasksClosed,
      l10n.fileClosureColNotes,
    ];

    final rows = records.map((r) {
      final matchingFile = filesMap[r.importFileId];
      final fileTitle = matchingFile != null ? matchingFile.primaryNameWithCode : '#${r.importFileId}';
      final chk = r.closureChecklist;
      return [
        r.closureCode,
        fileTitle,
        r.archiveLocation,
        r.auditorName,
        r.closedAt,
        chk.docsVerified ? '100%' : '0%',
        chk.customsCleared ? '100%' : '0%',
        chk.warehouseReceived ? '100%' : '0%',
        chk.landedCostSettled ? '100%' : '0%',
        chk.tasksClosed ? '100%' : '0%',
        r.archivalNotes ?? '',
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l10n.copyFileClosureTableSuccess,
    );
  }

  Future<void> _exportClosuresExcel(
    List<ImportFileClosureModel> records,
    Map<int, ImportFileModel> filesMap,
  ) async {
    final l10n = context.l10n;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fileClosureEmptyRecords), backgroundColor: AppTheme.orange),
      );
      return;
    }

    final headers = [
      l10n.fileClosureColClosureCode,
      l10n.fileClosureColImportFile,
      l10n.fileClosureColArchiveVault,
      l10n.fileClosureColAuditor,
      l10n.fileClosureColClosedDate,
      l10n.fileClosureColDocsVerified,
      l10n.fileClosureColCustomsCleared,
      l10n.fileClosureColWarehouseReceived,
      l10n.fileClosureColLandedCostSettled,
      l10n.fileClosureColTasksClosed,
      l10n.fileClosureColNotes,
    ];

    final rows = records.map((r) {
      final matchingFile = filesMap[r.importFileId];
      final fileTitle = matchingFile != null ? matchingFile.primaryNameWithCode : '#${r.importFileId}';
      final chk = r.closureChecklist;
      return [
        r.closureCode,
        fileTitle,
        r.archiveLocation,
        r.auditorName,
        r.closedAt,
        chk.docsVerified ? '100%' : '0%',
        chk.customsCleared ? '100%' : '0%',
        chk.warehouseReceived ? '100%' : '0%',
        chk.landedCostSettled ? '100%' : '0%',
        chk.tasksClosed ? '100%' : '0%',
        r.archivalNotes ?? '',
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'File Closure & Archival',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _exportClosuresPdf(
    List<ImportFileClosureModel> records,
    Map<int, ImportFileModel> filesMap,
  ) async {
    final l10n = context.l10n;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fileClosureEmptyRecords), backgroundColor: AppTheme.orange),
      );
      return;
    }

    final headers = [
      l10n.fileClosureColClosureCode,
      l10n.fileClosureColImportFile,
      l10n.fileClosureColArchiveVault,
      l10n.fileClosureColAuditor,
      l10n.fileClosureColClosedDate,
      l10n.fileClosureColDocsVerified,
      l10n.fileClosureColCustomsCleared,
      l10n.fileClosureColWarehouseReceived,
      l10n.fileClosureColLandedCostSettled,
      l10n.fileClosureColTasksClosed,
    ];

    final rows = records.map((r) {
      final matchingFile = filesMap[r.importFileId];
      final fileTitle = matchingFile != null ? matchingFile.primaryNameWithCode : '#${r.importFileId}';
      final chk = r.closureChecklist;
      return [
        r.closureCode,
        fileTitle,
        r.archiveLocation,
        r.auditorName,
        r.closedAt,
        chk.docsVerified ? '100%' : '0%',
        chk.customsCleared ? '100%' : '0%',
        chk.warehouseReceived ? '100%' : '0%',
        chk.landedCostSettled ? '100%' : '0%',
        chk.tasksClosed ? '100%' : '0%',
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'File Closure & Archival',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  void _copySingleCertificateSummary(ImportFileClosureModel r, ImportFileModel? file) {
    final l10n = context.l10n;
    final fileTitle = file != null ? file.primaryNameWithCode : '#${r.importFileId}';
    final chk = r.closureChecklist;

    final buffer = StringBuffer();
    buffer.writeln('=== ${l10n.fileClosureCertificateDialogTitle(r.closureCode)} ===');
    buffer.writeln('${l10n.fileClosureColClosureCode}: ${r.closureCode}');
    buffer.writeln('${l10n.fileClosureColImportFile}: $fileTitle');
    buffer.writeln('${l10n.fileClosureColArchiveVault}: ${r.archiveLocation}');
    buffer.writeln('${l10n.fileClosureColAuditor}: ${r.auditorName}');
    buffer.writeln('${l10n.fileClosureColClosedDate}: ${r.closedAt}');
    buffer.writeln('--- ${l10n.fileClosureChecklistHeader} ---');
    buffer.writeln('• ${l10n.fileClosureChecklistDocsOriginals}: ${chk.docsVerified ? "100%" : "0%"}');
    buffer.writeln('• ${l10n.fileClosureChecklistCustomsCleared}: ${chk.customsCleared ? "100%" : "0%"}');
    buffer.writeln('• ${l10n.fileClosureChecklistWarehouseGrn}: ${chk.warehouseReceived ? "100%" : "0%"}');
    buffer.writeln('• ${l10n.fileClosureChecklistLandedCost}: ${chk.landedCostSettled ? "100%" : "0%"}');
    buffer.writeln('• ${l10n.fileClosureChecklistTasksClosed}: ${chk.tasksClosed ? "100%" : "0%"}');
    if (r.archivalNotes != null && r.archivalNotes!.isNotEmpty) {
      buffer.writeln('${l10n.fileClosureColNotes}: ${r.archivalNotes!}');
    }

    CopyHelper.copy(
      context,
      buffer.toString().trimRight(),
      customMessage: l10n.fileClosurePrintSuccess(r.closureCode),
    );
  }

  void _showCertificate(ImportFileClosureModel r, ImportFileModel? file) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: OpsSectionHeader(
          title: l10n.fileClosureCertificateDialogTitle(r.closureCode),
          icon: Icons.verified_outlined,
          iconColor: AppTheme.emerald,
        ),
        content: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CopyableText(l10n.fileClosureCertFileNo(r.importFileId)),
              const SizedBox(height: 4),
              CopyableText(l10n.fileClosureCertLocation(r.archiveLocation)),
              const SizedBox(height: 4),
              CopyableText(l10n.fileClosureCertAuditor(r.auditorName)),
              const SizedBox(height: 4),
              CopyableText(l10n.fileClosureCertClosedDate(r.closedAt)),
              if (r.archivalNotes != null) ...[
                const SizedBox(height: 4),
                CopyableText(l10n.fileClosureCertNotes(r.archivalNotes!)),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
        actions: [
          AppButton(
            label: l10n.fileClosureCopyCertTsvBtn,
            icon: Icons.copy,
            variant: AppButtonVariant.ghost,
            onPressed: () => _copySingleCertificateSummary(r, file),
          ),
          AppButton(label: l10n.close, variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(c)),
        ],
      ),
    );
  }

  Future<void> _deleteClosure(ImportFileClosureModel r) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.fileClosureDeleteTitle),
        content: Text(l10n.fileClosureDeleteMessage),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
        actions: [
          AppButton(label: l10n.cancel, variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(c, false)),
          AppButton(
            label: l10n.delete,
            variant: AppButtonVariant.danger,
            icon: Icons.delete_outline,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(fileClosureProvider.notifier).softDeleteClosure(r.closureId);
      } catch (e) {
        // e.g. 409: a Closed record cannot be deleted, reopen the file first.
        messenger.showSnackBar(
          SnackBar(content: Text(ApiErrorText.of(l10n, e)), backgroundColor: AppTheme.crimson),
        );
      }
    }
  }

  Widget _buildMetrics(List<ImportFileClosureModel> records, int stoppedFiles, AppLocalizations l) {
    final archived = records.where((r) => r.isFullyVerified).length;
    return MetricCardStrip(
      metrics: [
        MetricCardData(
          title: l.closureMetricRecords,
          shortTitle: l.closureMetricRecords,
          value: '${records.length}',
          icon: Icons.archive_outlined,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l.closureMetricArchived,
          shortTitle: l.closureMetricArchived,
          value: '$archived',
          icon: Icons.verified_outlined,
          color: AppTheme.emerald,
        ),
        MetricCardData(
          title: l.closureMetricDraft,
          shortTitle: l.closureMetricDraft,
          value: '${records.length - archived}',
          icon: Icons.edit_note,
          color: AppTheme.orange,
        ),
        MetricCardData(
          title: l.closureMetricStoppedFiles,
          shortTitle: l.closureMetricStoppedFiles,
          value: '$stoppedFiles',
          icon: Icons.history,
          color: AppTheme.crimson,
        ),
      ],
    );
  }

  Widget _buildToolbar(
    List<ImportFileClosureModel> records,
    Map<int, ImportFileModel> filesMap,
    AppLocalizations l,
  ) {
    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      padding: const EdgeInsetsDirectional.all(12),
      child: Row(
        children: [
          Expanded(
            child: OpsActionWrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                AppButton(
                  key: const Key('createClosureBtn'),
                  label: l.fileClosureNewCertificateBtn,
                  icon: Icons.lock_clock,
                  size: AppButtonSize.small,
                  onPressed: () => _showCloseFileDialog(),
                ),
                AppButton(
                  key: const Key('searchAndCloneClosureBtn'),
                  label: l.searchAndCloneFileClosureBtn,
                  icon: Icons.difference_outlined,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => _openSearchAndCloneDialog(records),
                ),
                AppButton(
                  key: const Key('copyClosureTableTsvBtn'),
                  label: l.fileClosureExportTsvBtn,
                  icon: Icons.table_chart_outlined,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: () => _copyArchivedFilesTsv(records, filesMap),
                ),
                IconButton(
                  key: const Key('exportClosureExcelBtn'),
                  icon: const Icon(Icons.description_outlined, color: AppTheme.emerald),
                  tooltip: l.exportFileClosureExcelTooltip,
                  onPressed: () => _exportClosuresExcel(records, filesMap),
                ),
                IconButton(
                  key: const Key('exportClosurePdfBtn'),
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                  tooltip: l.exportFileClosurePdfTooltip,
                  onPressed: () => _exportClosuresPdf(records, filesMap),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.fileClosureSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(fileClosureProvider.notifier).fetchClosures(search: '');
                      },
                    );
                  },
                ),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) {
                ref.read(fileClosureProvider.notifier).fetchClosures(search: val);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final closuresState = ref.watch(fileClosureProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importFilesMap = {for (final f in importFiles) f.importFileId: f};
    final closedFiles = importFiles.where((f) => f.status == 'Closed').toList();
    final currentRecords = closuresState.valueOrNull ?? <ImportFileClosureModel>[];
    final isArLocale = Localizations.localeOf(context).languageCode == 'ar';

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.archive_outlined,
        titleEn: l.fileClosureTabArchivedRegistry,
        titleAr: l.fileClosureTabArchivedRegistry,
      ),
      VerticalNavTabItem(
        icon: Icons.inventory_2_outlined,
        titleEn: l.fileClosureTabCloseFile,
        titleAr: l.fileClosureTabCloseFile,
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'PHASE-6: STEP_21',
      titleEn: l.fileClosureStageTitle,
      titleAr: l.fileClosureStageTitle,
      headerIcon: Icons.archive,
      headerColor: AppTheme.emerald,
      tabs: tabs,
      selectedIndex: 0,
      onTabSelected: (index) {
        if (index == 1) {
          _showCloseFileDialog();
        }
      },
      headerActions: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.7), size: density.buttonIconSize),
          tooltip: l.fileClosureRefreshTooltip,
          onPressed: () => ref.read(fileClosureProvider.notifier).fetchClosures(),
        ),
      ],
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 88),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MasterDataToolbarWidget(
                      moduleEndpoint: 'file-closure',
                      title: 'File_Closure',
                      onRefreshNeeded: () => ref.read(fileClosureProvider.notifier).fetchClosures(),
                    ),
                    const SizedBox(height: 12),
                    if (currentRecords.isNotEmpty || closedFiles.isNotEmpty) ...[
                      _buildMetrics(currentRecords, closedFiles.length, l),
                      const SizedBox(height: 12),
                    ],
                    _buildToolbar(currentRecords, importFilesMap, l),
                    const SizedBox(height: 16),
                    if (closedFiles.isNotEmpty) ...[
                      ClosedFilesBanner(
                        files: closedFiles,
                        onReopen: (cf) {
                          ReopenShipmentDialog.show(
                            context,
                            importFile: cf,
                            onSuccess: () {
                              ref.invalidate(fileClosureProvider);
                              ref.read(importFilesProvider.notifier).fetchImportFiles();
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (currentRecords.isNotEmpty) ...[
                      OpsSectionHeader(
                        title: l.closureRecordsSection,
                        icon: Icons.fact_check_outlined,
                        iconColor: AppTheme.emerald,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              closuresState.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: OpsLoadingView(),
                ),
                error: (err, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: OpsStateView.error(
                    message: '${l.fileClosureFetchError} $err',
                    actionLabel: l.retry,
                    onAction: () => ref.read(fileClosureProvider.notifier).fetchClosures(search: _searchController.text),
                  ),
                ),
                data: (records) {
                  if (records.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: OpsStateView.empty(
                        icon: Icons.archive_outlined,
                        message: l.fileClosureEmptyRecords,
                        actionLabel: l.fileClosureNewCertificateBtn,
                        actionIcon: Icons.lock_clock,
                        onAction: () => _showCloseFileDialog(),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final r = records[idx];
                        final matchingFile = importFilesMap[r.importFileId];
                        final rawCode = 'IMP-${r.importFileId}';
                        final shipName = matchingFile != null
                            ? DisplayNameResolver.resolveShipmentName(matchingFile, isArabic: isArLocale)
                            : DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: importFiles, isArabic: isArLocale);

                        return ClosureRecordCard(
                          record: r,
                          shipmentName: shipName,
                          rawFileCode: rawCode,
                          onView: () => _showCertificate(r, matchingFile),
                          onEdit: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.fileClosureEditSnack(r.closureCode)), backgroundColor: AppTheme.orange),
                            );
                          },
                          onPrint: () => _copySingleCertificateSummary(r, matchingFile),
                          onDelete: () => _deleteClosure(r),
                          onCopyRow: () => _copyClosureRowTsv(r, matchingFile, context.l10n),
                          onClone: () => _onCloneClosure(r),
                        );
                      },
                      childCount: records.length,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
