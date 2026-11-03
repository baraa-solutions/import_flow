import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/file_closure_model.dart';
import '../providers/file_closure_provider.dart';
import '../widgets/closed_files_banner.dart';
import '../widgets/closure_record_card.dart';
import '../widgets/file_closure_form_dialog.dart';
import '../widgets/screen/closure_certificate_dialog.dart';
import '../widgets/screen/closure_export_helper.dart';
import '../widgets/screen/closure_screen_metrics.dart';
import '../widgets/screen/closure_screen_toolbar.dart';
import '../widgets/search_and_clone_file_closure_dialog.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';

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

  Future<void> _deleteClosure(ImportFileClosureModel r) async {
    final l10n = context.l10n;
    final confirm = await AppConfirmDialog.showDelete(
      context,
      title: l10n.fileClosureDeleteTitle,
      message: l10n.fileClosureDeleteMessage,
    );
    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(fileClosureProvider.notifier).softDeleteClosure(r.closureId);
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            AppTheme.snackBar(context, ApiErrorText.of(l10n, e), severity: AppSeverity.danger),
          );
        }
      }
    }
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
                      ClosureScreenMetrics(
                        records: currentRecords,
                        stoppedFiles: closedFiles.length,
                      ),
                      const SizedBox(height: 12),
                    ],
                    ClosureScreenToolbar(
                      records: currentRecords,
                      filesMap: importFilesMap,
                      searchController: _searchController,
                      onNewCertificate: () => _showCloseFileDialog(),
                      onSearchAndClone: () => _openSearchAndCloneDialog(currentRecords),
                      onCopyTsv: () => ClosureExportHelper.copyArchivedFilesTsv(context, currentRecords, importFilesMap),
                      onExportExcel: () => ClosureExportHelper.exportClosuresExcel(context, currentRecords, importFilesMap),
                      onExportPdf: () => ClosureExportHelper.exportClosuresPdf(context, currentRecords, importFilesMap),
                      onSearchChanged: (val) => ref.read(fileClosureProvider.notifier).fetchClosures(search: val),
                      onSearchCleared: () {
                        _searchController.clear();
                        ref.read(fileClosureProvider.notifier).fetchClosures(search: '');
                      },
                    ),
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
                          onView: () => ClosureCertificateDialog.show(
                            context,
                            record: r,
                            file: matchingFile,
                            onCopySummary: () => ClosureExportHelper.copySingleCertificateSummary(context, r, matchingFile),
                          ),
                          onEdit: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              AppTheme.snackBar(context, context.l10n.fileClosureEditSnack(r.closureCode), severity: AppSeverity.warning),
                            );
                          },
                          onPrint: () => ClosureExportHelper.copySingleCertificateSummary(context, r, matchingFile),
                          onDelete: () => _deleteClosure(r),
                          onCopyRow: () => ClosureExportHelper.copyClosureRowTsv(context, r, matchingFile, context.l10n),
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
