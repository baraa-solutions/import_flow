import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../core/helpers/table_copy_helper.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/invoice_bl_match_session_model.dart';
import '../../idoc_ui.dart';

class InvoiceBlSessionDetailsDialog {
  const InvoiceBlSessionDetailsDialog._();

  static void show({
    required BuildContext context,
    required InvoiceBLMatchSessionModel session,
    required ValueChanged<InvoiceBLMatchSessionModel> onCloneSession,
    required ValueChanged<InvoiceBLMatchSessionModel> onLoadSession,
  }) {
    final matrix = session.comparisonMatrix ?? [];
    final invData = session.invoiceData ?? {};
    final blData = session.blData ?? {};
    final isDraft = session.isDraft;

    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDraft ? AppTheme.orange : AppTheme.emerald).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDraft ? Icons.bookmark_added_rounded : Icons.verified_rounded,
                  color: isDraft ? AppTheme.orange : AppTheme.emerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.idocASessionDetailsTitle(session.sessionCode),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.idocAImportFileCreated(
                        (session.importFileCode ?? "IMP-${session.importFileId}"),
                        session.createdAt,
                      ),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IdocStatusChip(
                label: isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
                severity: isDraft ? AppSeverity.warning : AppSeverity.success,
                icon: isDraft ? Icons.edit_document : Icons.check_circle,
              ),
            ],
          ),
          content: SizedBox(
            width: 900,
            height: 520,
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: AppTheme.cobalt,
                    unselectedLabelColor: AppTheme.textMutedOf(ctx),
                    indicatorColor: AppTheme.cobalt,
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.compare_arrows, size: 16),
                        text: context.l10n.idocAMatchingAndVerificationMatrix,
                      ),
                      Tab(
                        icon: const Icon(Icons.data_object, size: 16),
                        text: context.l10n.idocAExtractedDataInvoiceBL,
                      ),
                      Tab(
                        icon: const Icon(Icons.notes, size: 16),
                        text: ctx.l10n.idocASessionNotesTab,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Comparison Matrix Table
                        matrix.isEmpty
                            ? Center(child: Text(context.l10n.idocANoSavedMatchingMatrixForThis))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.borderOf(ctx)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                                        headingTextStyle: const TextStyle(
                                          color: AppTheme.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        columns: [
                                          DataColumn(label: Text(context.l10n.idocAStandardItem)),
                                          DataColumn(label: Text(context.l10n.idocASystemData)),
                                          DataColumn(label: Text(context.l10n.idocAInvoiceData)),
                                          DataColumn(label: Text(context.l10n.idocAPackingListAlt)),
                                          DataColumn(label: Text(context.l10n.idocABLData)),
                                          DataColumn(label: Text(context.l10n.idocAMatchStatus)),
                                          DataColumn(label: Text(context.l10n.idocADetailsAndSourcesOfDisagreement)),
                                        ],
                                        rows: matrix.map((item) {
                                          final row = item is Map ? CodedItemText.localizeRow(item, context.l10n) : {};
                                          final status = row['match_status']?.toString() ?? 'UNKNOWN';
                                          final isMatch = status == 'MATCH';
                                          final isExtFailed = status == 'EXTRACTION_FAILED';
                                          final isMinor = status == 'MISMATCH_MINOR';

                                          Color statusCol;
                                          String statusTxt;
                                          if (isMatch) {
                                            statusCol = AppTheme.emerald;
                                            statusTxt = context.l10n.idocAMatched;
                                          } else if (isExtFailed) {
                                            statusCol = AppTheme.textSecondaryOf(ctx);
                                            statusTxt = context.l10n.idocAExtractionFailed3;
                                          } else if (isMinor) {
                                            statusCol = AppTheme.orange;
                                            statusTxt = context.l10n.idocAMinorVariance;
                                          } else {
                                            statusCol = AppTheme.crimson;
                                            statusTxt = context.l10n.idocAMaterialVariance;
                                          }

                                          final disagreeingSources = (row['disagreeing_sources'] as List<dynamic>?)
                                                  ?.map((e) => e.toString())
                                                  .toList() ??
                                              [];

                                          return DataRow(
                                            cells: [
                                              DataCell(Text(
                                                row['field_name_ar'] ?? row['field_name_en'] ?? '—',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                              )),
                                              DataCell(Text(
                                                row['system_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11),
                                              )),
                                              DataCell(Text(
                                                row['invoice_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                                              )),
                                              DataCell(Text(
                                                row['packing_list_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.wcagCobalt),
                                              )),
                                              DataCell(Text(
                                                row['bl_value']?.toString() ?? '—',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.emerald),
                                              )),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: statusCol.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    statusTxt,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: statusCol,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    row['details']?.toString() ?? '—',
                                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                  ),
                                                  if (disagreeingSources.isNotEmpty)
                                                    Text(
                                                      context.l10n.idocADisagreementBetween((disagreeingSources.join(", "))),
                                                      style: const TextStyle(
                                                        fontSize: 9.5,
                                                        color: AppTheme.crimson,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                ],
                                              )),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        // Tab 2: Extracted Data
                        SingleChildScrollView(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceAltOf(ctx),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.borderOf(ctx)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.receipt_long, size: 16, color: AppTheme.cobalt),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.l10n.idocACommercialInvoiceExtracts,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.cobalt,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      SelectableText(
                                        const JsonEncoder.withIndent('  ').convert(invData),
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceAltOf(ctx),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.borderOf(ctx)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.directions_boat, size: 16, color: AppTheme.emerald),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.l10n.idocABillOfLadingExtracts,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.emerald,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      SelectableText(
                                        const JsonEncoder.withIndent('  ').convert(blData),
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tab 3: Raw Texts & Notes
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (session.sessionNotes != null && session.sessionNotes!.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cloudWhite,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.borderOf(ctx)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.idocASessionNotes,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(session.sessionNotes!),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_all, color: AppTheme.cobalt),
              tooltip: context.l10n.idocACopySessionMatrixTSV,
              onPressed: matrix.isEmpty ? null : () => _copySessionMatrixTsv(ctx, matrix),
            ),
            IdocUi.fit(AppButton(
              key: const Key('dialogCloneSessionBtn'),
              label: context.l10n.idocACloneAsANewDraft,
              icon: Icons.copy_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.pop(ctx);
                onCloneSession(session);
              },
            )),
            IdocUi.fit(AppButton(
              label: context.l10n.idocARestoreAndLoadInTheInspection,
              icon: Icons.play_circle_outline,
              variant: AppButtonVariant.ghost,
              onPressed: () {
                Navigator.pop(ctx);
                onLoadSession(session);
              },
            )),
            IdocUi.fit(AppButton(
              label: context.l10n.close,
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx),
            )),
          ],
        ),
      ),
    );
  }

  static void _copySessionMatrixTsv(BuildContext context, List<dynamic> matrix) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
}
