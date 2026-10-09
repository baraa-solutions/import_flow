import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/partner_model.dart';
import '../providers/partners_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class PartnerStatementOfAccountDialog extends ConsumerWidget {
  final PartnerModel partner;

  const PartnerStatementOfAccountDialog({super.key, required this.partner});

  static void show(BuildContext context, PartnerModel partner) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PartnerStatementOfAccountDialog(partner: partner),
    );
  }

  String _formatNumber(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final intPart = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '$intPart.${parts[1]}';
  }

  void _copySoaTsv(BuildContext context, dynamic soa) {
    final l10n = context.l10n;
    final headers = [
      l10n.ledgerDateCol,
      l10n.ledgerTypeCol,
      l10n.ledgerRefCol,
      l10n.ledgerImportFileCol,
      l10n.ledgerDescriptionCol,
      l10n.ledgerCurrencyCol,
      l10n.ledgerDebitCol,
      l10n.ledgerCreditCol,
      l10n.ledgerStatusCol,
    ];
    final rows = soa.ledgerEntries.map((e) => [
      e.entryDate,
      e.entryType.contains('Invoice') ? l10n.ledgerInvoiceBadge : l10n.ledgerPaymentBadge,
      e.referenceNo,
      e.importFileCode ?? '',
      e.description,
      e.currency,
      e.debitAmount.toStringAsFixed(2),
      e.creditAmount.toStringAsFixed(2),
      e.status,
    ]);
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.soaExportTsvSuccess);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soaAsync = ref.watch(partnerStatementOfAccountProvider(partner.providerId ?? 0));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SelectionArea(
        child: Container(
          width: 1000,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.transparent),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                l10n.partnerSoaTitle(partner.partnerName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                partner.partnerCode,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.partnerSoaSubtitle(partner.partnerType, partner.taxId ?? "—"),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.table_chart_outlined, color: Colors.white70),
                    tooltip: l10n.soaExportTsvBtn,
                    onPressed: () {
                      final soa = soaAsync.asData?.value;
                      if (soa != null && soa.ledgerEntries.isNotEmpty) {
                        _copySoaTsv(context, soa);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: l10n.refresh,
                    onPressed: () {
                      ref.invalidate(partnerStatementOfAccountProvider(partner.providerId ?? 0));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: soaAsync.when(
                loading: () => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.cobalt),
                      const SizedBox(height: 16),
                      Text(l10n.calculatingSoaMsg, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    ],
                  ),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.crimson, size: 48),
                        const SizedBox(height: 12),
                        Text(l10n.soaFetchError(err.toString()), style: const TextStyle(color: AppTheme.crimson)),
                      ],
                    ),
                  ),
                ),
                data: (soa) {
                  if (soa == null) {
                    return Center(child: Text(l10n.noSoaDataAvailable));
                  }

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Total Equivalent EGP Summary Banner
                        if (soa.equivalentEgpTotal != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cobalt.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.currency_exchange, color: AppTheme.cobalt, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    Directionality.of(context) == TextDirection.rtl
                                        ? 'إجمالي الرصيد المكافئ بالجنيه المصري (وفق أسعار الصرف الرسمية):'
                                        : 'Total Equivalent Balance in EGP (Official Exchange Rates):',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_formatNumber(soa.equivalentEgpTotal!)} ${l10n.soaCurrencyEgp}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.cobalt,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Currency Balances Cards
                        Text(
                          l10n.multiCurrencyBalancesHeader,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: soa.currencyBalances.map((cb) {
                            final isPositive = cb.balanceDue > 0;
                            return Container(
                              width: 250,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isPositive ? AppTheme.orange.withOpacity(0.4) : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        cb.currency,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.cobalt,
                                        ),
                                      ),
                                      Icon(
                                        Icons.monetization_on_outlined,
                                        size: 18,
                                        color: isPositive ? AppTheme.orange : AppTheme.emerald,
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.totalInvoicedLabel,
                                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.black54),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_formatNumber(cb.totalInvoiced), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : Colors.black87)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.totalPaidLabel,
                                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.black54),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_formatNumber(cb.totalPaid), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.balanceDueLabel,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatNumber(cb.balanceDue),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isPositive ? AppTheme.crimson : AppTheme.emerald,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (cb.currency != 'EGP' && cb.equivalentEgp != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            Directionality.of(context) == TextDirection.rtl
                                                ? 'المعادل بالجنيه:'
                                                : 'Equiv. (EGP):',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? AppTheme.darkTextSecondary : Colors.black45,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_formatNumber(cb.equivalentEgp!)} EGP (1=${cb.exchangeRateUsed ?? 1})',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? AppTheme.darkTextSecondary : Colors.black54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // Ledger Table
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.transactionsLedgerHeader(soa.ledgerEntries.length),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            ),
                            Row(
                              children: [
                                Text(
                                  l10n.invoicesCountLabel(soa.totalInvoicesCount, soa.totalPaymentsCount),
                                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.black54, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Expanded(
                          child: soa.ledgerEntries.isEmpty
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
                                        Icon(Icons.receipt_long_outlined, size: 36, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.noLedgerEntriesFound,
                                          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
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
                                        headingRowColor: WidgetStateProperty.all(isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100),
                                        columnSpacing: 18,
                                        horizontalMargin: 12,
                                        columns: [
                                          DataColumn(label: Text(l10n.ledgerDateCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                          DataColumn(label: Text(l10n.ledgerTypeCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                          DataColumn(label: Text(l10n.ledgerRefCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                          DataColumn(label: Text(l10n.ledgerImportFileCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                          DataColumn(label: Text(l10n.ledgerDescriptionCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                          DataColumn(label: Text(l10n.ledgerCurrencyCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                          DataColumn(label: Text(l10n.ledgerDebitCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                          DataColumn(label: Text(l10n.ledgerCreditCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                          DataColumn(label: Text(l10n.ledgerStatusCol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal))),
                                        ],
                                        rows: soa.ledgerEntries.map((entry) {
                                          final isInvoice = entry.entryType.contains('Invoice');
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(entry.entryDate, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isInvoice
                                                        ? AppTheme.orange.withOpacity(0.15)
                                                        : AppTheme.emerald.withOpacity(0.15),
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
                                              DataCell(Text(entry.description, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : Colors.black87))),
                                              DataCell(
                                                Text(
                                                  entry.currency,
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  entry.debitAmount > 0 ? _formatNumber(entry.debitAmount) : '—',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: entry.debitAmount > 0 ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal) : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  entry.creditAmount > 0 ? _formatNumber(entry.creditAmount) : '—',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: entry.creditAmount > 0 ? AppTheme.emerald : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
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
                    ),
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.soaFooterText,
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.darkBorder : AppTheme.charcoal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text(l10n.closeBtn),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
