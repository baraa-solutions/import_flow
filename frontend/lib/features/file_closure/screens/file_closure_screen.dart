import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/reopen_shipment_dialog.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/vertical_stage_scaffold.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/file_closure_model.dart';
import '../providers/file_closure_provider.dart';
import '../widgets/search_and_clone_file_closure_dialog.dart';

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
      builder: (context) => _FileClosureFormDialog(
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
            entityType: isAr ? 'شهادة إغلاق وأرشفة ملف استيراد' : 'Import File Closure Certificate',
            sourceCode: source.closureCode,
            suggestedNewCode: newDraftCode,
            sourceTitle: '${source.closureCode} (${source.isFullyVerified ? (isAr ? "مغلق ومؤرشف" : "Archived") : (isAr ? "مسودة" : "Draft")})',
            copiedFieldsSummary: {
              isAr ? 'رقم ملف الاستيراد' : 'Import File ID': '#${source.importFileId}',
              isAr ? 'المحاسب / المراجع' : 'Auditor / Reviewer': source.auditorName,
              isAr ? 'مستودع الأرشيف الرقمي' : 'Archive Vault': source.archiveLocation,
              isAr ? 'حالة الشروط المستوفاة' : 'Conditions Verified':
                  '${(source.closureChecklist.docsVerified ? 1 : 0) + (source.closureChecklist.customsCleared ? 1 : 0) + (source.closureChecklist.warehouseReceived ? 1 : 0) + (source.closureChecklist.landedCostSettled ? 1 : 0) + (source.closureChecklist.tasksClosed ? 1 : 0)} / 5',
              if (source.archivalNotes != null && source.archivalNotes!.isNotEmpty)
                isAr ? 'ملاحظات الأرشفة' : 'Archival Notes': source.archivalNotes!,
            },
            mandatorilyResetFields: isAr
                ? const [
                    'معرف الإغلاق (Closure ID): يتم تصفيره لإنشاء سجل أرشفة جديد في قاعدة البيانات',
                    'كود الشهادة: يتم تعيينه تلقائياً كمسودة (CLOSURE-DRAFT-XXXX)',
                    'حالة الإغلاق: يعاد ضبطها إلى مسودة قيد الاستيفاء (Draft / Incomplete)',
                    'تاريخ الإغلاق والاعتماد: يعاد ضبطه على اللحظة الحالية والمراجع الحالي',
                  ]
                : const [
                    'Closure ID: Cleared to 0 for new database record generation',
                    'Closure Code: Re-assigned as new DRAFT (CLOSURE-DRAFT-XXXX)',
                    'Closure Status: Reset to Draft / Incomplete',
                    'Closed Date & Auditor: Reset to current instant & operator',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final density = ref.watch(displayDensityProvider);
    final closuresState = ref.watch(fileClosureProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importFilesMap = {for (final f in importFiles) f.importFileId: f};
    final closedFiles = importFiles.where((f) => f.status == 'Closed').toList();

    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.archive_outlined,
        titleEn: 'Archived Files Registry',
        titleAr: 'سجل الملفات المغلقة والمؤرشفة',
      ),
      const VerticalNavTabItem(
        icon: Icons.inventory_2_outlined,
        titleEn: 'Close Import File',
        titleAr: 'إغلاق وأرشفة ملف شحنة',
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'PHASE-6: STEP_21',
      titleEn: 'Import File Final Closure & Archival',
      titleAr: 'إغلاق الملف والأرشفة التاريخية',
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
          icon: Icon(Icons.refresh, color: Colors.white70, size: density.buttonIconSize),
          tooltip: context.l10n.fileClosureRefreshTooltip,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data Actions Toolbar
                    MasterDataToolbarWidget(
                      moduleEndpoint: 'file-closure',
                      title: 'File_Closure',
                      onRefreshNeeded: () => ref.read(fileClosureProvider.notifier).fetchClosures(),
                    ),
                    const SizedBox(height: 12),

                    // Top Toolbar
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  key: const Key('createClosureBtn'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.cobalt,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onPressed: () => _showCloseFileDialog(),
                                  icon: const Icon(Icons.lock_clock, color: Colors.white, size: 18),
                                  label: Text(context.l10n.fileClosureNewCertificateBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                OutlinedButton.icon(
                                  key: const Key('searchAndCloneClosureBtn'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.cobalt,
                                    side: const BorderSide(color: AppTheme.cobalt),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onPressed: () => _openSearchAndCloneDialog(closuresState.valueOrNull ?? []),
                                  icon: const Icon(Icons.difference_outlined, size: 18),
                                  label: Text(context.l10n.searchAndCloneFileClosureBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                OutlinedButton.icon(
                                  key: const Key('copyClosureTableTsvBtn'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.cobalt,
                                    side: const BorderSide(color: AppTheme.cobalt),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                                  label: Text(context.l10n.fileClosureExportTsvBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () => _copyArchivedFilesTsv(closuresState.valueOrNull ?? [], importFilesMap),
                                ),
                                IconButton(
                                  key: const Key('exportClosureExcelBtn'),
                                  icon: const Icon(Icons.description_outlined, color: AppTheme.emerald),
                                  tooltip: context.l10n.exportFileClosureExcelTooltip,
                                  onPressed: () => _exportClosuresExcel(closuresState.valueOrNull ?? [], importFilesMap),
                                ),
                                IconButton(
                                  key: const Key('exportClosurePdfBtn'),
                                  icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
                                  tooltip: context.l10n.exportFileClosurePdfTooltip,
                                  onPressed: () => _exportClosuresPdf(closuresState.valueOrNull ?? [], importFilesMap),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 280,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: context.l10n.fileClosureSearchHint,
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
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (val) {
                                  ref.read(fileClosureProvider.notifier).fetchClosures(search: val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Closed Shipments Reopening Banner
                    if (closedFiles.isNotEmpty) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 2,
                            color: isDark ? const Color(0xFF2E1A05) : Colors.amber.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isDark ? const Color(0xFF78350F) : Colors.amber.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.history, color: AppTheme.orange, size: 22),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          context.l10n.fileClosureClosedFilesBannerTitle(closedFiles.length),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark ? const Color(0xFFFEF3C7) : AppTheme.charcoal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 10,
                                    children: closedFiles.map((cf) {
                                      final isArLocale = Localizations.localeOf(context).languageCode == 'ar';
                                      final shipName = DisplayNameResolver.resolveShipmentName(cf, isArabic: isArLocale);
                                      final phaseName = cf.closedAtPhase != null
                                          ? DisplayNameResolver.resolvePhaseName(cf.closedAtPhase!, isArabic: isArLocale)
                                          : context.l10n.fileClosureClosedBadge;

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                CopyableText(
                                                  shipName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : AppTheme.charcoal,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF7F1D1D) : Colors.red.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    phaseName,
                                                    style: TextStyle(
                                                      fontSize: DisplayDensityMode.clampFontSize(11.0),
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? const Color(0xFFFECACA) : AppTheme.crimson,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppTheme.cobalt.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: CopyableText(
                                                cf.importFileCode,
                                                style: TextStyle(
                                                  fontSize: DisplayDensityMode.clampFontSize(11.0),
                                                  color: isDark ? const Color(0xFF93C5FD) : Colors.grey.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (cf.closureReason != null && cf.closureReason!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                context.l10n.fileClosureStopReason(cf.closureReason!),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                  color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.emerald,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              ),
                                              onPressed: () {
                                                ReopenShipmentDialog.show(
                                                  context,
                                                  importFile: cf,
                                                  onSuccess: () => ref.read(importFilesProvider.notifier).fetchImportFiles(),
                                                );
                                              },
                                              icon: const Icon(Icons.restart_alt, size: 14),
                                              label: Text(context.l10n.fileClosureReopenBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Closure Records Grid/List as Sliver
              closuresState.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('${context.l10n.fileClosureFetchError} $err', style: const TextStyle(color: AppTheme.crimson))),
                ),
                data: (records) {
                  if (records.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text(context.l10n.fileClosureEmptyRecords)),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final r = records[idx];
                        final chk = r.closureChecklist;
                        final matchingFile = importFilesMap[r.importFileId];
                        final isArLocale = Localizations.localeOf(context).languageCode == 'ar';
                        final rawCode = 'IMP-${r.importFileId}';
                        final shipName = matchingFile != null
                            ? DisplayNameResolver.resolveShipmentName(matchingFile, isArabic: isArLocale)
                            : DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: importFiles, isArabic: isArLocale);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.emerald.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.emerald),
                                          ),
                                          child: CopyableText(r.closureCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                        ),
                                        CopyableText(
                                          shipName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : AppTheme.charcoal,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF334155) : AppTheme.charcoal.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: CopyableText(
                                            rawCode,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        CopyableText(
                                          context.l10n.fileClosureVaultLabel(r.archiveLocation),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        r.isFullyVerified
                                            ? context.l10n.fileClosureStatusBadgeClosed
                                            : (isAr ? 'مسودة قيد الاستيفاء' : 'Draft / Incomplete'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),

                                // Checklist Verified Badges
                                Text(context.l10n.fileClosureChecklistHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildChecklistChip(context.l10n.fileClosureChecklistDocsOriginals, chk.docsVerified, isDark),
                                    _buildChecklistChip(context.l10n.fileClosureChecklistCustomsCleared, chk.customsCleared, isDark),
                                    _buildChecklistChip(context.l10n.fileClosureChecklistWarehouseGrn, chk.warehouseReceived, isDark),
                                    _buildChecklistChip(context.l10n.fileClosureChecklistLandedCost, chk.landedCostSettled, isDark),
                                    _buildChecklistChip(context.l10n.fileClosureChecklistTasksClosed, chk.tasksClosed, isDark),
                                  ],
                                ),

                                if (r.archivalNotes != null && r.archivalNotes!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.note, size: 16, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            context.l10n.fileClosureArchivalNotes(r.archivalNotes!),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: isDark ? const Color(0xFFCBD5E1) : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        RowActionsPill(
                                          onView: () {
                                            showDialog(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: Text(context.l10n.fileClosureCertificateDialogTitle(r.closureCode)),
                                                content: SelectionArea(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      CopyableText(context.l10n.fileClosureCertFileNo(r.importFileId)),
                                                      const SizedBox(height: 4),
                                                      CopyableText(context.l10n.fileClosureCertLocation(r.archiveLocation)),
                                                      const SizedBox(height: 4),
                                                      CopyableText(context.l10n.fileClosureCertAuditor(r.auditorName)),
                                                      const SizedBox(height: 4),
                                                      CopyableText(context.l10n.fileClosureCertClosedDate(r.closedAt)),
                                                      if (r.archivalNotes != null) ...[
                                                        const SizedBox(height: 4),
                                                        CopyableText(context.l10n.fileClosureCertNotes(r.archivalNotes!)),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  OutlinedButton.icon(
                                                    icon: const Icon(Icons.copy, size: 16),
                                                    label: Text(context.l10n.fileClosureCopyCertTsvBtn),
                                                    onPressed: () => _copySingleCertificateSummary(r, matchingFile),
                                                  ),
                                                  TextButton(onPressed: () => Navigator.pop(c), child: Text(context.l10n.close)),
                                                ],
                                              ),
                                            );
                                          },
                                          onEdit: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(context.l10n.fileClosureEditSnack(r.closureCode)), backgroundColor: AppTheme.orange),
                                            );
                                          },
                                          onPrint: () => _copySingleCertificateSummary(r, matchingFile),
                                          onDelete: () async {
                                            final l10n = context.l10n;
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (c) => AlertDialog(
                                                title: Text(l10n.fileClosureDeleteTitle),
                                                content: Text(l10n.fileClosureDeleteMessage),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
                                                  TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.delete, style: const TextStyle(color: AppTheme.crimson))),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              ref.read(fileClosureProvider.notifier).softDeleteClosure(r.closureId);
                                            }
                                          },
                                          viewTooltip: context.l10n.fileClosureViewTooltip,
                                          editTooltip: context.l10n.fileClosureEditTooltip,
                                          printTooltip: context.l10n.fileClosurePrintTooltip,
                                          deleteTooltip: context.l10n.fileClosureDeleteTooltip,
                                        ),
                                        OutlinedButton.icon(
                                          key: Key('copyClosureRowBtn_${r.closureCode}'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.cobalt,
                                            side: BorderSide(color: Colors.blue.shade300),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.copy_outlined, size: 14),
                                          label: Text(context.l10n.fileClosureCopyCertTsvBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: () => _copyClosureRowTsv(r, matchingFile, context.l10n),
                                        ),
                                        IconButton(
                                          key: Key('cloneClosureBtn_${r.closureCode}'),
                                          icon: const Icon(Icons.difference_outlined, color: AppTheme.emerald, size: 18),
                                          tooltip: context.l10n.cloneFileClosureTooltip,
                                          onPressed: () => _onCloneClosure(r),
                                        ),
                                      ],
                                    ),
                                    CopyableText(
                                      context.l10n.fileClosureAuditorLabel(r.auditorName),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildChecklistChip(String label, bool isOk, bool isDark) {
    return Chip(
      avatar: Icon(isOk ? Icons.check_circle : Icons.cancel, color: isOk ? AppTheme.emerald : AppTheme.crimson, size: 16),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isOk ? (isDark ? Colors.white : Colors.black87) : AppTheme.crimson,
        ),
      ),
      backgroundColor: isOk
          ? AppTheme.emerald.withOpacity(isDark ? 0.2 : 0.1)
          : AppTheme.crimson.withOpacity(isDark ? 0.2 : 0.1),
    );
  }
}

// -----------------------------------------------------------------------------
// FORM DIALOG
// -----------------------------------------------------------------------------

class _FileClosureFormDialog extends ConsumerStatefulWidget {
  final ImportFileClosureModel? initialRecord;
  final bool isCloneDraft;

  const _FileClosureFormDialog({
    this.initialRecord,
    this.isCloneDraft = false,
  });

  @override
  ConsumerState<_FileClosureFormDialog> createState() => _FileClosureFormDialogState();
}

class _FileClosureFormDialogState extends ConsumerState<_FileClosureFormDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedImportFileId;

  late bool _docsVerified;
  late bool _customsCleared;
  late bool _warehouseReceived;
  late bool _landedCostSettled;
  late bool _tasksClosed;

  late final TextEditingController _auditorCtrl;
  late final TextEditingController _vaultCtrl;
  late final TextEditingController _notesCtrl;

  bool _isLoading = false;
  bool _isDraftSaving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialRecord;
    if (init != null) {
      _selectedImportFileId = init.importFileId;
      _docsVerified = init.closureChecklist.docsVerified;
      _customsCleared = init.closureChecklist.customsCleared;
      _warehouseReceived = init.closureChecklist.warehouseReceived;
      _landedCostSettled = init.closureChecklist.landedCostSettled;
      _tasksClosed = init.closureChecklist.tasksClosed;
      _auditorCtrl = TextEditingController(text: init.auditorName);
      _vaultCtrl = TextEditingController(text: init.archiveLocation);
      _notesCtrl = TextEditingController(text: init.archivalNotes ?? '');
    } else {
      _docsVerified = true;
      _customsCleared = true;
      _warehouseReceived = true;
      _landedCostSettled = true;
      _tasksClosed = true;
      _auditorCtrl = TextEditingController(text: 'Adel Hassan (Senior Auditor)');
      _vaultCtrl = TextEditingController(text: 'Digital Vault Archive 2026 - Main Server');
      _notesCtrl = TextEditingController(text: 'تم استيفاء جميع المستندات والإفراج الجمركي وحساب تكلفة الوصول بنجاح.');
    }
  }

  @override
  void dispose() {
    _auditorCtrl.dispose();
    _vaultCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onFileSelected(int? fileId) {
    setState(() => _selectedImportFileId = fileId);
    if (fileId == null) return;

    final existingClosures = ref.read(fileClosureProvider).valueOrNull ?? [];
    final match = existingClosures.where((c) => c.importFileId == fileId).firstOrNull;
    if (match != null) {
      setState(() {
        _docsVerified = match.closureChecklist.docsVerified;
        _customsCleared = match.closureChecklist.customsCleared;
        _warehouseReceived = match.closureChecklist.warehouseReceived;
        _landedCostSettled = match.closureChecklist.landedCostSettled;
        _tasksClosed = match.closureChecklist.tasksClosed;
        if (match.auditorName.isNotEmpty) _auditorCtrl.text = match.auditorName;
        if (match.archiveLocation.isNotEmpty) _vaultCtrl.text = match.archiveLocation;
        if (match.archivalNotes != null) _notesCtrl.text = match.archivalNotes!;
      });
    }
  }

  Future<void> _submitClosure({required bool isDraft}) async {
    final l10n = context.l10n;

    if (!_formKey.currentState!.validate()) return;

    if (!isDraft) {
      if (!_docsVerified || !_customsCleared || !_warehouseReceived || !_landedCostSettled || !_tasksClosed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.fileClosureChecklistIncompleteWarning),
          backgroundColor: AppTheme.crimson,
        ));
        return;
      }
    }

    setState(() {
      if (isDraft) {
        _isDraftSaving = true;
      } else {
        _isLoading = true;
      }
    });

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payload = {
        'import_file_id': _selectedImportFileId,
        'closure_checklist': {
          'docs_verified': _docsVerified,
          'customs_cleared': _customsCleared,
          'warehouse_received': _warehouseReceived,
          'landed_cost_settled': _landedCostSettled,
          'tasks_closed': _tasksClosed,
        },
        'auditor_name': _auditorCtrl.text.trim(),
        'archive_location': _vaultCtrl.text.trim(),
        'archival_notes': _notesCtrl.text.trim(),
        'is_draft': isDraft,
      };

      await ref.read(fileClosureProvider.notifier).closeImportFile(payload);
      await ref.read(importFilesProvider.notifier).fetchImportFiles();

      final int completedCount = (_docsVerified ? 1 : 0) +
          (_customsCleared ? 1 : 0) +
          (_warehouseReceived ? 1 : 0) +
          (_landedCostSettled ? 1 : 0) +
          (_tasksClosed ? 1 : 0);
      final double progressPct = (completedCount / 5.0) * 100.0;

      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isDraft
                ? l10n.fileClosureDraftSavedSuccess(progressPct.toStringAsFixed(0), completedCount)
                : l10n.fileClosureCertifiedSuccess,
          ),
          backgroundColor: isDraft ? AppTheme.cobalt : AppTheme.emerald,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.fileClosureSaveError('$e')), backgroundColor: AppTheme.crimson));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDraftSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth - 32).clamp(320.0, 700.0);
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final int completedCount = (_docsVerified ? 1 : 0) +
        (_customsCleared ? 1 : 0) +
        (_warehouseReceived ? 1 : 0) +
        (_landedCostSettled ? 1 : 0) +
        (_tasksClosed ? 1 : 0);
    final double progressPct = (completedCount / 5.0) * 100.0;
    final bool isFullyComplete = completedCount == 5;
    final Color progressColor = isFullyComplete
        ? AppTheme.emerald
        : (completedCount >= 3 ? AppTheme.cobalt : (completedCount >= 1 ? Colors.orange.shade800 : Colors.grey.shade600));

    final titleText = widget.isCloneDraft
        ? '${context.l10n.fileClosureDialogTitle} (${isAr ? "مسودة مستنسخة" : "Cloned Draft"})'
        : context.l10n.fileClosureDialogTitle;

    return AlertDialog(
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.down,
      title: Row(
        children: [
          Icon(widget.isCloneDraft ? Icons.difference_outlined : Icons.inventory_2_outlined, color: AppTheme.cobalt, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SelectionArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchableDropdownField<int?>(
                    value: _selectedImportFileId,
                    labelText: context.l10n.fileClosureSelectImportFile,
                    searchHintText: context.l10n.fileClosureSelectImportFileHint,
                    items: importFiles
                        .map((f) => SearchableDropdownItem<int?>(
                              value: f.importFileId,
                              label: '${f.primaryNameWithCode} - ${f.companyName}',
                              subtitle: f.companyName,
                            ))
                        .toList(),
                    onChanged: _onFileSelected,
                    validator: (v) => v == null ? context.l10n.fileClosureSelectImportFileValidator : null,
                  ),
                  const SizedBox(height: 14),

                  // ─── Dynamic Overall Completion Progress Card ─────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: progressColor.withOpacity(0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isFullyComplete ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                  color: progressColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.l10n.fileClosureChecklistCompletionLabel,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${progressPct.toStringAsFixed(0)}% ($completedCount/5)',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: completedCount / 5.0,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                            minHeight: 7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.fileClosureSaveDraftTip,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(context.l10n.fileClosureMandatoryChecklistHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    title: Text(context.l10n.fileClosureCheck1Docs, style: TextStyle(fontWeight: _docsVerified ? FontWeight.bold : FontWeight.normal)),
                    secondary: Icon(_docsVerified ? Icons.check_box : Icons.check_box_outline_blank, color: _docsVerified ? AppTheme.emerald : Colors.grey),
                    value: _docsVerified,
                    onChanged: (v) => setState(() => _docsVerified = v ?? false),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: Text(context.l10n.fileClosureCheck2Customs, style: TextStyle(fontWeight: _customsCleared ? FontWeight.bold : FontWeight.normal)),
                    secondary: Icon(_customsCleared ? Icons.check_box : Icons.check_box_outline_blank, color: _customsCleared ? AppTheme.emerald : Colors.grey),
                    value: _customsCleared,
                    onChanged: (v) => setState(() => _customsCleared = v ?? false),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: Text(context.l10n.fileClosureCheck3Warehouse, style: TextStyle(fontWeight: _warehouseReceived ? FontWeight.bold : FontWeight.normal)),
                    secondary: Icon(_warehouseReceived ? Icons.check_box : Icons.check_box_outline_blank, color: _warehouseReceived ? AppTheme.emerald : Colors.grey),
                    value: _warehouseReceived,
                    onChanged: (v) => setState(() => _warehouseReceived = v ?? false),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: Text(context.l10n.fileClosureCheck4LandedCost, style: TextStyle(fontWeight: _landedCostSettled ? FontWeight.bold : FontWeight.normal)),
                    secondary: Icon(_landedCostSettled ? Icons.check_box : Icons.check_box_outline_blank, color: _landedCostSettled ? AppTheme.emerald : Colors.grey),
                    value: _landedCostSettled,
                    onChanged: (v) => setState(() => _landedCostSettled = v ?? false),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: Text(context.l10n.fileClosureCheck5Tasks, style: TextStyle(fontWeight: _tasksClosed ? FontWeight.bold : FontWeight.normal)),
                    secondary: Icon(_tasksClosed ? Icons.check_box : Icons.check_box_outline_blank, color: _tasksClosed ? AppTheme.emerald : Colors.grey),
                    value: _tasksClosed,
                    onChanged: (v) => setState(() => _tasksClosed = v ?? false),
                    dense: true,
                  ),

                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _auditorCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.fileClosureAuditorNameLabel,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: context.l10n.fileClosureCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(context, _auditorCtrl.text),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? context.l10n.fileClosureAuditorNameValidator : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _vaultCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.fileClosureVaultLocationLabel,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: context.l10n.fileClosureCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(context, _vaultCtrl.text),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: context.l10n.fileClosureArchivalNotesLabel,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: context.l10n.fileClosureCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(context, _notesCtrl.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.charcoal, side: BorderSide(color: Colors.grey.shade400)),
          onPressed: () => ref.read(fileClosureProvider.notifier).fetchClosures(),
          icon: const Icon(Icons.refresh, size: 16, color: AppTheme.cobalt),
          label: Text(context.l10n.fileClosureLiveReloadBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 4),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade800, side: BorderSide(color: Colors.grey.shade400)),
          onPressed: () {
            setState(() {
              _notesCtrl.clear();
              _auditorCtrl.clear();
              _vaultCtrl.text = 'Main Archive Vault #1';
              _docsVerified = false;
              _customsCleared = false;
              _warehouseReceived = false;
              _landedCostSettled = false;
              _tasksClosed = false;
            });
          },
          icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: Colors.blueGrey),
          label: Text(context.l10n.fileClosureResetFormBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 4),

        // ─── 💾 Save Draft / حفظ كمسودة مؤقتة ────────────────────────────────
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: AppTheme.cobalt,
            elevation: 0,
            side: const BorderSide(color: AppTheme.cobalt),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: _isDraftSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppTheme.cobalt, strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 16, color: AppTheme.cobalt),
          label: Text(
            context.l10n.fileClosureSaveDraftBtn,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: (_isLoading || _isDraftSaving) ? null : () => _submitClosure(isDraft: true),
        ),
        const SizedBox(width: 4),

        TextButton(onPressed: (_isLoading || _isDraftSaving) ? null : () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        const SizedBox(width: 4),

        // ─── ✅ Certify Final Closure & Archival ──────────────────────────────
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emerald,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: _isLoading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.archive_outlined, color: Colors.white, size: 16),
          label: Text(context.l10n.fileClosureCertifySubmitBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          onPressed: (_isLoading || _isDraftSaving) ? null : () => _submitClosure(isDraft: false),
        ),
      ],
    );
  }
}
