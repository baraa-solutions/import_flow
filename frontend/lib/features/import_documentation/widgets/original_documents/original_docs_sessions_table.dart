import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/original_documents_collection_model.dart';
import '../../providers/original_documents_collection_provider.dart';
import '../../services/original_docs_export_service.dart';
import '../idoc_ui.dart';
import 'original_docs_localizer.dart';

/// Sessions registry table displaying saved document collection sessions.
/// Wrapped in [SelectionArea] with sanitized clipboard operations.
class OriginalDocsSessionsTable extends ConsumerStatefulWidget {
  final AsyncValue<List<OriginalDocumentsCollectionSessionModel>> sessionsAsync;
  final ValueChanged<int> onLoadFile;

  const OriginalDocsSessionsTable({
    super.key,
    required this.sessionsAsync,
    required this.onLoadFile,
  });

  @override
  ConsumerState<OriginalDocsSessionsTable> createState() => _OriginalDocsSessionsTableState();
}

class _OriginalDocsSessionsTableState extends ConsumerState<OriginalDocsSessionsTable> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';

  static const List<String> _statusOptions = [
    'All',
    'DRAFT',
    'PARTIALLY_RECEIVED',
    'FULLY_RECEIVED',
    'FULLY_VERIFIED',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerFetch() {
    ref.read(originalDocumentsSessionsProvider.notifier).fetchSessions(
          search: _searchController.text.trim(),
          status: _statusFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sessions = widget.sessionsAsync.asData?.value ?? [];
    final hasSessions = sessions.isNotEmpty;
    final allImportFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_edu_outlined, color: AppTheme.cobalt, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      l.collectionRegistryHeader,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l.searchRegistryHint,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchController.text.trim().isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.copy, size: 15),
                                  tooltip: l.copyTooltip,
                                  onPressed: () => CopyHelper.copy(
                                    context,
                                    _searchController.text.trim(),
                                    customMessage: l.copiedToClipboard(_searchController.text.trim()),
                                  ),
                                )
                              : null,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => _triggerFetch(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 170,
                      child: SearchableDropdownField<String>(
                        value: _statusFilter,
                        labelText: l.colDocStatus,
                        items: _statusOptions
                            .map((s) => SearchableDropdownItem<String>(
                                  value: s,
                                  label: OriginalDocsLocalizer.getRegistryStatusFilterLabel(context, s),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _statusFilter = val);
                            _triggerFetch();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    IdocUi.fit(
                      AppButton(
                        label: l.originalDocsExportTsvBtn,
                        icon: Icons.table_view_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: !hasSessions
                            ? null
                            : () => OriginalDocsExportService.exportRegistryTsv(
                                  context: context,
                                  sessions: sessions,
                                  shipments: allImportFiles,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IdocUi.fit(
                      AppButton(
                        label: l.originalDocsExportExcelBtn,
                        icon: Icons.file_download_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: !hasSessions
                            ? null
                            : () => OriginalDocsExportService.exportRegistryExcel(
                                  context: context,
                                  sessions: sessions,
                                  shipments: allImportFiles,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IdocUi.fit(
                      AppButton(
                        label: l.originalDocsPrintPdfBtn,
                        icon: Icons.print_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: !hasSessions
                            ? null
                            : () => OriginalDocsExportService.printRegistryPdf(
                                  context: context,
                                  sessions: sessions,
                                  shipments: allImportFiles,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IdocUi.fit(
                      AppButton(
                        label: l.originalDocsCopyDossierBtn,
                        icon: Icons.copy_all_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: !hasSessions
                            ? null
                            : () => OriginalDocsExportService.copyRegistryDossier(
                                  context: context,
                                  sessions: sessions,
                                  shipments: allImportFiles,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          widget.sessionsAsync.when(
            data: (sessionsList) {
              if (sessionsList.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    l.noRegisteredSessionsFound,
                    style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAlt),
                  headingTextStyle: const TextStyle(
                    color: AppTheme.charcoal,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  columns: [
                    DataColumn(label: Text(l.colAction)),
                    DataColumn(label: Text(l.colSessionCode)),
                    DataColumn(label: Text(l.colImportFile)),
                    DataColumn(label: Text(l.colAcidNumber)),
                    DataColumn(label: Text(l.colSupplierName)),
                    DataColumn(label: Text(l.colTotalDocs)),
                    DataColumn(label: Text(l.colReceivedDocs)),
                    DataColumn(label: Text(l.colVerifiedDocs)),
                    DataColumn(label: Text(l.colCompletionPercentage)),
                    DataColumn(label: Text(l.colDocStatus)),
                    DataColumn(label: Text(l.colUpdatedAt)),
                  ],
                  rows: sessionsList.map((s) {
                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                    final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
                      s.importFileCode,
                      shipments: allImportFiles,
                      isArabic: isAr,
                    );
                    final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
                      s.importFileCode,
                      shipments: allImportFiles,
                      isArabic: isAr,
                    );
                    final statusStr = OriginalDocsLocalizer.getRegistryStatusFilterLabel(context, s.status);
                    final updatedStr = OriginalDocsLocalizer.formatDateTime(s.updatedAt);
                    final sessionSummary =
                        '${s.collectionCode} | $shipmentTitle | ${s.acidNumber ?? "—"} | ${s.supplierName ?? "—"} | ${s.totalDocumentsCount} | ${s.receivedDocumentsCount} | ${s.verifiedDocumentsCount} | ${s.completionPercentage}% | $statusStr | $updatedStr';

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                                tooltip: l.copyRow,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  sessionSummary,
                                  customMessage: l.originalDocsCopyRowSuccess,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.folder_open_outlined, size: 16, color: AppTheme.charcoal),
                                tooltip: l.originalDocsLoadSessionTooltip,
                                onPressed: () => widget.onLoadFile(s.importFileId),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: s.collectionCode,
                            rowSummary: sessionSummary,
                            child: InkWell(
                              onTap: () => CopyHelper.copy(
                                context,
                                s.collectionCode,
                                customMessage: l.copiedToClipboard(s.collectionCode),
                              ),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      s.collectionCode,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy, size: 12, color: AppTheme.cobalt),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: shipmentName,
                            rowSummary: sessionSummary,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (shipmentName != s.importFileCode) ...[
                                  Text(
                                    shipmentName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                InkWell(
                                  onTap: () => CopyHelper.copy(
                                    context,
                                    s.importFileCode,
                                    customMessage: l.copiedToClipboard(s.importFileCode),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          s.importFileCode,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy, size: 10, color: AppTheme.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: s.acidNumber ?? '—',
                            rowSummary: sessionSummary,
                            child: s.acidNumber != null && s.acidNumber!.isNotEmpty
                                ? InkWell(
                                    onTap: () => CopyHelper.copy(
                                      context,
                                      s.acidNumber!,
                                      customMessage: l.copiedToClipboard(s.acidNumber!),
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            s.acidNumber!,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.orange,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.copy, size: 12, color: AppTheme.orange),
                                        ],
                                      ),
                                    ),
                                  )
                                : const Text('—'),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: s.supplierName ?? '—',
                            rowSummary: sessionSummary,
                            child: Text(s.supplierName ?? '—'),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: '${s.totalDocumentsCount}',
                            rowSummary: sessionSummary,
                            child: Text('${s.totalDocumentsCount}'),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: '${s.receivedDocumentsCount}',
                            rowSummary: sessionSummary,
                            child: Text('${s.receivedDocumentsCount}'),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: '${s.verifiedDocumentsCount}',
                            rowSummary: sessionSummary,
                            child: Text('${s.verifiedDocumentsCount}'),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: '${s.completionPercentage}%',
                            rowSummary: sessionSummary,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: s.completionPercentage == 100
                                    ? AppTheme.severityBackgroundOf(context, AppSeverity.success)
                                    : AppTheme.severityBackgroundOf(context, AppSeverity.warning),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${s.completionPercentage}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: s.completionPercentage == 100
                                      ? AppTheme.severityForegroundOf(context, AppSeverity.success)
                                      : AppTheme.severityForegroundOf(context, AppSeverity.warning),
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: statusStr,
                            rowSummary: sessionSummary,
                            child: OriginalDocsLocalizer.buildStatusBadge(context, s.status),
                          ),
                        ),
                        DataCell(
                          CopyableTableCell(
                            value: updatedStr,
                            rowSummary: sessionSummary,
                            child: Text(updatedStr),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(l.errorFetchingRegistry(e), style: const TextStyle(color: AppTheme.crimson)),
          ),
        ],
      ),
    );
  }
}
