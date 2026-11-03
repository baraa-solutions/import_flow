import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../idoc_ui_b.dart';
import 'bank_form4_localizer.dart';

/// Embedded table displaying historical Form 4 requests for the selected shipment.
class BankForm4HistoryTable extends StatelessWidget {
  final bool isDark;
  final bool isMobile;
  final int? selectedImportFileId;
  final List<BankingDocumentModel> historyDocs;
  final void Function(BankingDocumentModel doc) onEditDoc;

  const BankForm4HistoryTable({
    super.key,
    required this.isDark,
    required this.isMobile,
    required this.selectedImportFileId,
    required this.historyDocs,
    required this.onEditDoc,
  });

  List<String> _headers(BuildContext context) => [
        context.l10n.documentCodeCol,
        context.l10n.idocBBankColDocType,
        context.l10n.idocBBankColReference,
        context.l10n.certifiedBankCol,
        context.l10n.amountAndCurrencyCol,
        context.l10n.requestDateCol,
        context.l10n.endorsementStatusCol,
      ];

  List<List<dynamic>> _rows(BuildContext context) {
    return historyDocs.map((d) {
      final formattedDate =
          d.requestDate ?? d.issueDate.substring(0, min(10, d.issueDate.length));
      final formattedAmount = '${d.amount.toStringAsFixed(2)} ${d.currencyCode}';
      final statusLabel = d.status == 'Received'
          ? context.l10n.endorsedStatusBadge
          : context.l10n.bankProcessingStatusBadge;

      return [
        d.bankDocCode,
        d.docType,
        d.docReferenceNumber,
        d.bankName,
        formattedAmount,
        formattedDate,
        statusLabel,
      ];
    }).toList();
  }

  void _copyTsv(BuildContext context) {
    if (historyDocs.isEmpty) return;
    TableCopyHelper.copyTable(context, _headers(context), _rows(context));
  }

  Future<void> _exportExcel(BuildContext context) async {
    if (historyDocs.isEmpty) return;
    await TableExportService.exportTableToExcel(
      context: context,
      headers: _headers(context),
      rows: _rows(context),
      stageName: 'Bank_Form4_History',
      importFileNameOrCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : 'All',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedImportFileId == null) {
      return const SizedBox.shrink();
    }

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.cardDecorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      BankForm4Localizer.historyTitle(context),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${historyDocs.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.wcagCobalt,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    IdocBUi.fit(AppButton(
                      label: BankForm4Localizer.copyTsv(context),
                      icon: Icons.copy_all,
                      variant: AppButtonVariant.secondary,
                      onPressed: historyDocs.isNotEmpty ? () => _copyTsv(context) : null,
                    )),
                    IdocBUi.fit(AppButton(
                      label: BankForm4Localizer.exportExcel(context),
                      icon: Icons.file_download_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: historyDocs.isNotEmpty ? () => _exportExcel(context) : null,
                    )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.border),
            const SizedBox(height: 14),

            if (historyDocs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    BankForm4Localizer.noHistoryFound(context),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                    ),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
                  ),
                  columns: [
                    DataColumn(label: Text(context.l10n.documentCodeCol)),
                    DataColumn(label: Text(context.l10n.idocBBankColDocType)),
                    DataColumn(label: Text(context.l10n.idocBBankColReference)),
                    DataColumn(label: Text(context.l10n.certifiedBankCol)),
                    DataColumn(label: Text(context.l10n.amountAndCurrencyCol)),
                    DataColumn(label: Text(context.l10n.requestDateCol)),
                    DataColumn(label: Text(context.l10n.endorsementStatusCol)),
                    DataColumn(label: Text(context.l10n.actions)),
                  ],
                  rows: historyDocs.map((doc) {
                    final isEndorsed = doc.status == 'Received';
                    final date = doc.requestDate ?? doc.issueDate.substring(0, min(10, doc.issueDate.length));
                    return DataRow(
                      cells: [
                        DataCell(
                          InkWell(
                            onTap: () => CopyHelper.copy(context, doc.bankDocCode),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  doc.bankDocCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.wcagCobalt,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy, size: 12, color: AppTheme.wcagCobalt),
                              ],
                            ),
                          ),
                        ),
                        DataCell(Text(doc.docType)),
                        DataCell(Text(doc.docReferenceNumber)),
                        DataCell(Text(doc.bankName)),
                        DataCell(Text('${doc.amount.toStringAsFixed(2)} ${doc.currencyCode}')),
                        DataCell(Text(date)),
                        DataCell(
                          AppStatusBadge.fromStatus(
                            status: doc.status,
                            label: isEndorsed
                                ? context.l10n.endorsedStatusBadge
                                : context.l10n.bankProcessingStatusBadge,
                          ),
                        ),
                        DataCell(
                          IdocBUi.fit(AppButton(
                            label: context.l10n.edit,
                            icon: Icons.edit_note,
                            variant: AppButtonVariant.ghost,
                            onPressed: () => onEditDoc(doc),
                          )),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
