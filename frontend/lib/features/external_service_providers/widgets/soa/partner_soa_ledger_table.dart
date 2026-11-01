import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/partner_model.dart';

class PartnerSoaLedgerTable extends StatelessWidget {
  final dynamic soa;
  final bool isDark;
  final String Function(double) formatNumber;

  const PartnerSoaLedgerTable({
    super.key,
    required this.soa,
    required this.isDark,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = soa.ledgerEntries as List<PartnerLedgerEntryModel>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.transactionsLedgerHeader(entries.length),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 36,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.noLedgerEntriesFound,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
                          ),
                          columnSpacing: 14,
                          horizontalMargin: 12,
                          columns: [
                            DataColumn(label: Text(l10n.ledgerDateCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerRefCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerImportFileCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerProjectCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerBlCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerImporterCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerDescriptionCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerCurrencyCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerDebitCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerCreditCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerRunningBalanceCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                            DataColumn(label: Text(l10n.ledgerStatusCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                          ],
                          rows: entries.map((entry) {
                            final isInvoice = entry.entryType.contains('Invoice');
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.entryDate, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isInvoice
                                          ? AppTheme.orange.withValues(alpha: 0.15)
                                          : AppTheme.emerald.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isInvoice ? l10n.ledgerInvoiceBadge : l10n.ledgerPaymentBadge,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isInvoice ? AppTheme.orange : AppTheme.emerald,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(LtrText(entry.referenceNo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                                DataCell(LtrText(entry.importFileCode ?? '—', style: const TextStyle(fontSize: 11, color: AppTheme.cobalt))),
                                DataCell(Text(entry.projectName ?? '—', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                                DataCell(LtrText(entry.blNumber ?? '—', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                                DataCell(Text(entry.importerName ?? '—', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                                DataCell(Text(entry.description, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                                DataCell(
                                  Text(
                                    entry.currency,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    entry.debitAmount > 0 ? formatNumber(entry.debitAmount) : '—',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: entry.debitAmount > 0 ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal) : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    entry.creditAmount > 0 ? formatNumber(entry.creditAmount) : '—',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: entry.creditAmount > 0 ? AppTheme.emerald : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    formatNumber(entry.runningBalance),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry.status,
                                      style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.black87),
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
                ),
        ),
      ],
    );
  }
}
