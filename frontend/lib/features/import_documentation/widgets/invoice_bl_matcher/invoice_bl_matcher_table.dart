import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/services/table_export_service.dart';
import '../idoc_ui.dart';

/// Item-by-item comparison matrix table for Screen 22: Invoice vs B/L Matcher.
///
/// Compares Commercial Invoice, Packing List, and Bill of Lading fields,
/// highlighting matching status, tolerances, and disagreeing sources.
class InvoiceBlMatcherTable extends StatelessWidget {
  final List<dynamic> matrix;
  final int? activeFileId;

  const InvoiceBlMatcherTable({
    super.key,
    required this.matrix,
    this.activeFileId,
  });

  bool _isArabic(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl ||
      (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = _isArabic(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                final titleWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_chart_outlined, size: 18, color: AppTheme.textPrimaryOf(context)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.invoiceBlMatcherMatrixTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );

                final buttonsWidget = Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IdocUi.fit(AppButton(
                      key: const Key('copyComparisonMatrixTsvBtn'),
                      label: context.l10n.idocACopyAsTSV,
                      icon: Icons.copy_all,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: matrix.isEmpty ? null : () => _copyComparisonMatrixTsv(context),
                    )),
                    IdocUi.fit(AppButton(
                      key: const Key('exportComparisonMatrixExcelBtn'),
                      label: context.l10n.exportExcel,
                      icon: Icons.table_view,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: matrix.isEmpty ? null : () => _exportComparisonMatrixExcel(context),
                    )),
                    IdocUi.fit(AppButton(
                      key: const Key('exportComparisonMatrixPdfBtn'),
                      label: context.l10n.idocAPrintPDF,
                      icon: Icons.picture_as_pdf,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: matrix.isEmpty ? null : () => _exportComparisonMatrixPdf(context),
                    )),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 8),
                      buttonsWidget,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 8),
                    buttonsWidget,
                  ],
                );
              },
            ),
          ),

          // Comparison Data Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: [
                DataColumn(
                  label: Text(
                    l.invoiceBlMatcherColCheckItem,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    context.l10n.idocASystemValue,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.invoiceBlMatcherColInvoiceValue,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    context.l10n.idocAPackingList,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.invoiceBlMatcherColBlValue,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.invoiceBlMatcherColMatchStatus,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    l.invoiceBlMatcherColActionRequired,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
                DataColumn(
                  label: Text(
                    context.l10n.idocARowActions,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryOf(context)),
                  ),
                ),
              ],
              rows: matrix.map((rawItem) {
                final item = CodedItemText.localizeRow(rawItem as Map, l);
                final status = item['match_status'] ?? 'MATCH';
                final isMatch = status == 'MATCH';
                final isMinor = status == 'MISMATCH_MINOR';
                final isExtFailed = status == 'EXTRACTION_FAILED';

                final Color statusCol;
                final String statusTxt;
                if (isMatch) {
                  statusCol = AppTheme.emerald;
                  statusTxt = l.invoiceBlMatcherStatusMatch;
                } else if (isExtFailed) {
                  statusCol = AppTheme.textSecondaryOf(context);
                  statusTxt = context.l10n.idocAExtractionFailed;
                } else if (isMinor) {
                  statusCol = AppTheme.orange;
                  statusTxt = l.invoiceBlMatcherStatusMinor;
                } else {
                  statusCol = AppTheme.crimson;
                  statusTxt = l.invoiceBlMatcherStatusMismatch;
                }

                final checkItemName = isArabic
                    ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
                    : (item['field_name_en'] ?? item['field_name_ar'] ?? '');

                final systemVal = '${item['system_value'] ?? '—'}';
                final invoiceVal = '${item['invoice_value'] ?? '—'}';
                final plVal = '${item['packing_list_value'] ?? '—'}';
                final blVal = '${item['bl_value'] ?? '—'}';
                final detailsTxt = '${item['details'] ?? item['action_required'] ?? ''}';
                final List<dynamic> disagreeingSources = item['disagreeing_sources'] as List<dynamic>? ?? [];

                final rowSummary = '$checkItemName\t$systemVal\t$invoiceVal\t$plVal\t$blVal\t$statusTxt\t$detailsTxt';

                return DataRow(
                  cells: [
                    DataCell(
                      CopyableTableCell(
                        value: checkItemName,
                        rowSummary: rowSummary,
                        child: Text(
                          checkItemName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: systemVal,
                        rowSummary: rowSummary,
                        child: Text(
                          systemVal,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: invoiceVal,
                        rowSummary: rowSummary,
                        child: Text(
                          invoiceVal,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.cobalt),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: plVal,
                        rowSummary: rowSummary,
                        child: Text(
                          plVal,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.wcagCobalt),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: blVal,
                        rowSummary: rowSummary,
                        child: Text(
                          blVal,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: statusTxt,
                        rowSummary: rowSummary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusCol.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusCol),
                              ),
                              child: Text(
                                statusTxt,
                                style: TextStyle(color: statusCol, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            if (disagreeingSources.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 3,
                                runSpacing: 2,
                                children: disagreeingSources.map((s) {
                                  String label = s.toString();
                                  if (isArabic) {
                                    label = label
                                        .replaceAll('INVOICE vs BL', context.l10n.idocADiffInvoiceBl)
                                        .replaceAll('SYSTEM vs INVOICE', context.l10n.idocADiffSystemInvoice)
                                        .replaceAll('SYSTEM vs BL', context.l10n.idocADiffSystemBl)
                                        .replaceAll('PACKING_LIST vs BL', context.l10n.idocADiffPackingBl)
                                        .replaceAll('INVOICE vs PACKING_LIST', context.l10n.idocADiffInvoicePacking)
                                        .replaceAll('SYSTEM vs PACKING_LIST', context.l10n.idocADiffSystemPacking);
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.crimson.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: AppTheme.crimson,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: detailsTxt,
                        rowSummary: rowSummary,
                        child: Text(
                          detailsTxt,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMatch ? AppTheme.textPrimaryOf(context) : statusCol,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                        tooltip: context.l10n.idocACopyRowDataAsTSV,
                        onPressed: () {
                          CopyHelper.copy(
                            context,
                            rowSummary,
                            customMessage: context.l10n.idocARowCopiedTsv(checkItemName),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _copyComparisonMatrixTsv(BuildContext context) {
    final isArabic = _isArabic(context);
    final headers = [
      context.l10n.idocACheckItem,
      context.l10n.idocAInvoiceValue,
      context.l10n.idocABLValue,
      context.l10n.idocAMatchStatus,
      context.l10n.idocADetailsAndAction,
    ];
    final rows = CodedItemText.localizeRows(matrix, context.l10n, forExport: true).map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? context.l10n.idocAMatched
          : (status == 'MISMATCH_MINOR' ? context.l10n.idocAMinorVariance : context.l10n.idocANotMatched);
      final detailsTxt = '${item['details'] ?? ''}';
      return [checkItemName, invoiceVal, blVal, statusTxt, detailsTxt];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: context.l10n.idocAMatchingMatrixCopiedToTheClipboard,
    );
  }

  Future<void> _exportComparisonMatrixExcel(BuildContext context) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      context.l10n.idocACheckItem,
      context.l10n.idocAInvoiceValue,
      context.l10n.idocABLValue,
      context.l10n.idocAMatchStatus,
      context.l10n.idocADetailsAndRequiredAction,
    ];
    final rows = CodedItemText.localizeRows(matrix, context.l10n, forExport: true).map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? context.l10n.idocAMatched
          : (status == 'MISMATCH_MINOR' ? context.l10n.idocAMinorVariance : context.l10n.idocANotMatched);
      final detailsTxt = '${item['details'] ?? ''}';
      return [checkItemName, invoiceVal, blVal, statusTxt, detailsTxt];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Invoice BL Comparison Matrix',
      importFileNameOrCode: activeFileId != null ? 'IMP-$activeFileId' : 'All-Files',
    );
  }

  Future<void> _exportComparisonMatrixPdf(BuildContext context) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      context.l10n.idocACheckItem,
      context.l10n.idocAInvoiceValue,
      context.l10n.idocABLValue,
      context.l10n.idocAMatchStatus,
      context.l10n.idocADetailsAndRequiredAction,
    ];
    final rows = CodedItemText.localizeRows(matrix, context.l10n, forExport: true).map((item) {
      final checkItemName = isArabic
          ? (item['field_name_ar'] ?? item['field_name_en'] ?? '')
          : (item['field_name_en'] ?? item['field_name_ar'] ?? '');
      final invoiceVal = '${item['invoice_value'] ?? '—'}';
      final blVal = '${item['bl_value'] ?? '—'}';
      final status = item['match_status'] ?? 'MATCH';
      final statusTxt = status == 'MATCH'
          ? context.l10n.idocAMatched
          : (status == 'MISMATCH_MINOR' ? context.l10n.idocAMinorVariance : context.l10n.idocANotMatched);
      final detailsTxt = '${item['details'] ?? ''}';
      return [checkItemName, invoiceVal, blVal, statusTxt, detailsTxt];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocACommercialInvoiceAndBillOfLadingAlt,
      importFileNameOrCode: activeFileId != null ? 'IMP-$activeFileId' : 'All-Files',
      headerContext: TableExportHeaderContext(
        title: context.l10n.idocACommercialInvoiceAndBillOfLadingAlt,
        subtitle: context.l10n.idocAFooterInspectionBrand,
      ),
    );
  }
}
