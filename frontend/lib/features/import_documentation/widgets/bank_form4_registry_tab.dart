import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/import_documentation_model.dart';
import '../providers/import_documentation_provider.dart';
import 'idoc_ui_b.dart';
import 'receive_bank_doc_dialog.dart';

/// Tab 1: Bank Form 4 Registry.
/// Encapsulates search controller and table rendering.
/// Opens banking actions as Lazy Modals and cleans up controllers on unmount.
class BankForm4RegistryTab extends ConsumerStatefulWidget {
  final VoidCallback onNewDoc;
  final VoidCallback onOpenSearchAndClone;
  final void Function(BankingDocumentModel doc) onEditDoc;
  final void Function(BankingDocumentModel doc) onCloneDoc;
  final VoidCallback onRefresh;

  const BankForm4RegistryTab({
    super.key,
    required this.onNewDoc,
    required this.onOpenSearchAndClone,
    required this.onEditDoc,
    required this.onCloneDoc,
    required this.onRefresh,
  });

  @override
  ConsumerState<BankForm4RegistryTab> createState() => _BankForm4RegistryTabState();
}

class _BankForm4RegistryTabState extends ConsumerState<BankForm4RegistryTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyBankForm4AsTsv(List<dynamic> list, List<ImportFileModel> importFiles) {
    if (list.isEmpty) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      context.l10n.documentCodeCol,
      context.l10n.idocBBankColDocType,
      context.l10n.idocBBankColReference,
      context.l10n.importFile,
      context.l10n.certifiedBankCol,
      context.l10n.amountAndCurrencyCol,
      context.l10n.requestDateCol,
      context.l10n.endorsementStatusCol,
    ];

    final rows = list.map((item) {
      final d = item as BankingDocumentModel;
      final rawCode = d.importFileCode ?? (d.importFileId != null ? 'IMP-${d.importFileId}' : '');
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
      final formattedDate = d.requestDate ?? d.issueDate.substring(0, min(10, d.issueDate.length));
      final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';
      final statusLabel = d.status == 'Received' ? context.l10n.endorsedStatusBadge : context.l10n.bankProcessingStatusBadge;

      return [
        d.bankDocCode,
        d.docType,
        d.docReferenceNumber,
        shipTitle,
        d.bankName,
        formattedAmount,
        formattedDate,
        statusLabel,
      ];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  Future<void> _exportBankForm4ToExcel(List<dynamic> list, List<ImportFileModel> importFiles) async {
    final headers = [
      context.l10n.documentCodeCol,
      context.l10n.idocBBankColDocType,
      context.l10n.idocBBankColReference,
      context.l10n.importFile,
      context.l10n.certifiedBankCol,
      context.l10n.amountAndCurrencyCol,
      context.l10n.requestDateCol,
      context.l10n.endorsementStatusCol,
    ];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final rows = list.map((item) {
      final d = item as BankingDocumentModel;
      final rawCode = d.importFileCode ?? (d.importFileId != null ? 'IMP-${d.importFileId}' : '');
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
      final formattedDate = d.requestDate ?? d.issueDate.substring(0, min(10, d.issueDate.length));
      final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';
      final statusLabel = d.status == 'Received' ? context.l10n.endorsedStatusBadge : context.l10n.bankProcessingStatusBadge;

      return [
        d.bankDocCode,
        d.docType,
        d.docReferenceNumber,
        shipTitle,
        d.bankName,
        formattedAmount,
        formattedDate,
        statusLabel,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Bank Form 4 Registry',
      importFileNameOrCode: 'All',
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _exportBankForm4ToPdf(List<dynamic> list, List<ImportFileModel> importFiles) async {
    final headers = [
      context.l10n.documentCodeCol,
      context.l10n.idocBBankColDocType,
      context.l10n.idocBBankColReference,
      context.l10n.importFile,
      context.l10n.certifiedBankCol,
      context.l10n.amountAndCurrencyCol,
      context.l10n.requestDateCol,
      context.l10n.endorsementStatusCol,
    ];
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final rows = list.map((item) {
      final d = item as BankingDocumentModel;
      final rawCode = d.importFileCode ?? (d.importFileId != null ? 'IMP-${d.importFileId}' : '');
      final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
      final formattedDate = d.requestDate ?? d.issueDate.substring(0, min(10, d.issueDate.length));
      final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';
      final statusLabel = d.status == 'Received' ? context.l10n.endorsedStatusBadge : context.l10n.bankProcessingStatusBadge;

      return [
        d.bankDocCode,
        d.docType,
        d.docReferenceNumber,
        shipTitle,
        d.bankName,
        formattedAmount,
        formattedDate,
        statusLabel,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Bank Form 4 Registry',
      importFileNameOrCode: 'All',
      headers: headers,
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bankingDocs = ref.watch(bankingDocumentsProvider).valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final query = _searchController.text.trim().toLowerCase();

    final filtered = bankingDocs.where((d) {
      final matchesSearch = query.isEmpty ||
          d.bankDocCode.toLowerCase().contains(query) ||
          d.bankName.toLowerCase().contains(query) ||
          (d.importFileCode != null && d.importFileCode!.toLowerCase().contains(query));
      return matchesSearch;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                TextField(
                  key: const Key('bankRegistrySearchInput'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchBankRegistryHint,
                    hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                    prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IdocBUi.fit(AppButton(
                      key: const Key('subtab1NewForm4Btn'),
                      label: context.l10n.newForm4RequestButton,
                      onPressed: widget.onNewDoc,
                      icon: Icons.add,
                    )),
                    IdocBUi.fit(AppButton(
                      key: const Key('subtab1SearchAndCloneBtn'),
                      label: context.l10n.searchAndCloneBankForm4Btn,
                      onPressed: widget.onOpenSearchAndClone,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.copy_all,
                    )),
                    IdocBUi.fit(AppButton(
                      key: const Key('bankRegistryCopyBtn'),
                      label: context.l10n.idocBCopyTable,
                      onPressed: () => _copyBankForm4AsTsv(filtered, importFiles),
                      variant: AppButtonVariant.secondary,
                      icon: Icons.copy,
                    )),
                    IdocBUi.fit(AppButton(
                      key: const Key('bankRegistryExcelBtn'),
                      label: context.l10n.idocBExportExcel,
                      onPressed: () => _exportBankForm4ToExcel(filtered, importFiles),
                      variant: AppButtonVariant.secondary,
                      icon: Icons.table_chart,
                    )),
                    IdocBUi.fit(AppButton(
                      key: const Key('bankRegistryPdfBtn'),
                      label: context.l10n.idocBExportPdf,
                      onPressed: () => _exportBankForm4ToPdf(filtered, importFiles),
                      variant: AppButtonVariant.secondary,
                      icon: Icons.picture_as_pdf,
                    )),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('bankRegistrySearchInput'),
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: context.l10n.searchBankRegistryHint,
                          hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                          prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                          ),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 8,
                          children: [
                            IdocBUi.fit(AppButton(
                              key: const Key('bankRegistryCopyBtn'),
                              label: context.l10n.idocBCopyTable,
                              onPressed: () => _copyBankForm4AsTsv(filtered, importFiles),
                              variant: AppButtonVariant.secondary,
                              icon: Icons.copy,
                            )),
                            const SizedBox(width: 8),
                            IdocBUi.fit(AppButton(
                              key: const Key('bankRegistryExcelBtn'),
                              label: context.l10n.idocBExportExcel,
                              onPressed: () => _exportBankForm4ToExcel(filtered, importFiles),
                              variant: AppButtonVariant.secondary,
                              icon: Icons.table_chart,
                            )),
                            const SizedBox(width: 8),
                            IdocBUi.fit(AppButton(
                              key: const Key('bankRegistryPdfBtn'),
                              label: context.l10n.idocBExportPdf,
                              onPressed: () => _exportBankForm4ToPdf(filtered, importFiles),
                              variant: AppButtonVariant.secondary,
                              icon: Icons.picture_as_pdf,
                            )),
                            const SizedBox(width: 8),
                            IdocBUi.fit(AppButton(
                              key: const Key('subtab1SearchAndCloneBtn'),
                              label: context.l10n.searchAndCloneBankForm4Btn,
                              onPressed: widget.onOpenSearchAndClone,
                              variant: AppButtonVariant.secondary,
                              icon: Icons.copy_all,
                            )),
                            const SizedBox(width: 10),
                            IdocBUi.fit(AppButton(
                              key: const Key('subtab1NewForm4Btn'),
                              label: context.l10n.newForm4RequestButton,
                              onPressed: widget.onNewDoc,
                              icon: Icons.add,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                decoration: AppTheme.cardDecorationOf(context),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: isDark ? AppTheme.darkTextSecondary : AppTheme.borderStrong),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.noBankForm4Found,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 750),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt),
                            columns: [
                              DataColumn(label: Text(context.l10n.actionCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                              DataColumn(label: Text(context.l10n.documentCodeCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                              DataColumn(label: Text(context.l10n.idocBBankColDocType, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                              DataColumn(label: Text(context.l10n.idocBBankColReference, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                              DataColumn(label: Text(context.l10n.importFile, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                              DataColumn(label: Text(context.l10n.certifiedBankCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                              DataColumn(label: Text(context.l10n.amountAndCurrencyCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                              DataColumn(label: Text(context.l10n.requestDateCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                              DataColumn(label: Text(context.l10n.endorsementStatusCol, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                            ],
                            rows: filtered.map((d) {
                              final rawCode = d.importFileCode ?? (d.importFileId != null ? 'IMP-${d.importFileId}' : '');
                              final shipName = DisplayNameResolver.resolveShipmentNameByCode(rawCode, shipments: importFiles, isArabic: isAr);
                              final shipTitle = DisplayNameResolver.resolveShipmentTitleByCode(rawCode, shipments: importFiles, isArabic: isAr);
                              final statusLabel = d.status == 'Received' ? context.l10n.endorsedStatusBadge : context.l10n.bankProcessingStatusBadge;
                              final formattedDate = d.requestDate ?? d.issueDate.substring(0, min(10, d.issueDate.length));
                              final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';
                              final rowSummary = '${d.bankDocCode}\t${d.docType}\t${d.docReferenceNumber}\t$shipTitle\t${d.bankName}\t$formattedAmount\t$formattedDate\t$statusLabel';

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          key: Key('receiveBankDocBtn_${d.bankDocId}'),
                                          icon: const Icon(Icons.verified, color: AppTheme.wcagEmerald, size: 18),
                                          tooltip: context.l10n.idocBBankEndorseTooltip,
                                          onPressed: () => ReceiveBankDocDialog.show(
                                            context,
                                            doc: d,
                                            onSubmitted: widget.onRefresh,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: AppTheme.wcagCobalt, size: 18),
                                          tooltip: context.l10n.edit,
                                          onPressed: () => widget.onEditDoc(d),
                                        ),
                                        IconButton(
                                          key: Key('cloneBankForm4RowBtn_${d.bankDocId}'),
                                          icon: const Icon(Icons.copy_all, color: AppTheme.wcagCobalt, size: 18),
                                          tooltip: context.l10n.cloneBankForm4RecordTooltip,
                                          onPressed: () => widget.onCloneDoc(d),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    CopyableTableCell(
                                      value: d.bankDocCode,
                                      rowSummary: rowSummary,
                                      child: Text(d.bankDocCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagCobalt)),
                                    ),
                                  ),
                                  DataCell(
                                    CopyableTableCell(
                                      value: d.docType,
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.wcagCobalt.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(d.docType, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    CopyableTableCell(
                                      value: d.docReferenceNumber,
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: d.docReferenceNumber != 'PENDING'
                                              ? AppTheme.wcagEmerald.withValues(alpha: 0.12)
                                              : AppTheme.textMuted.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          d.docReferenceNumber,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: d.docReferenceNumber != 'PENDING'
                                                ? AppTheme.wcagEmerald
                                                : (isDark ? AppTheme.borderStrong : AppTheme.textStrong),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    CopyableTableCell(
                                      value: shipTitle,
                                      rowSummary: rowSummary,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            shipName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                            ),
                                          ),
                                          if (d.importFileCode != null)
                                            Text(
                                              d.importFileCode!,
                                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    CopyableTableCell(
                                      value: d.bankName,
                                      rowSummary: rowSummary,
                                      child: Text(d.bankName),
                                    ),
                                  ),
                                  DataCell(
                                    CopyableTableCell(
                                      value: formattedAmount,
                                      rowSummary: rowSummary,
                                      child: Text(formattedAmount, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  DataCell(
                                    CopyableTableCell(
                                      value: formattedDate,
                                      rowSummary: rowSummary,
                                      child: Text(formattedDate),
                                    ),
                                  ),
                                  DataCell(
                                    CopyableTableCell(
                                      value: statusLabel,
                                      rowSummary: rowSummary,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (d.status == 'Received' ? AppTheme.wcagEmerald : AppTheme.orange).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: (d.status == 'Received' ? AppTheme.wcagEmerald : AppTheme.orange).withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: d.status == 'Received' ? AppTheme.wcagEmerald : AppTheme.orange,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
