import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/partner_model.dart';
import '../providers/partners_provider.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/services/table_export_service.dart';
import '../../logistics_invoices/widgets/invoice_form_dialog.dart';
import '../../logistics_invoices/widgets/logistics_payment_dialog.dart';

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

  List<String> _buildHeaders(AppLocalizations l10n) {
    return [
      l10n.ledgerDateCol,
      l10n.ledgerTypeCol,
      l10n.ledgerRefCol,
      l10n.ledgerImportFileCol,
      l10n.ledgerProjectCol,
      l10n.ledgerBlCol,
      l10n.ledgerImporterCol,
      l10n.ledgerDescriptionCol,
      l10n.ledgerCurrencyCol,
      l10n.ledgerDebitCol,
      l10n.ledgerCreditCol,
      l10n.ledgerRunningBalanceCol,
      l10n.ledgerStatusCol,
    ];
  }

  List<List<dynamic>> _buildRows(dynamic soa, AppLocalizations l10n) {
    return (soa.ledgerEntries as List<PartnerLedgerEntryModel>).map((e) {
      final isInvoice = e.entryType.contains('Invoice');
      return [
        e.entryDate,
        isInvoice ? l10n.ledgerInvoiceBadge : l10n.ledgerPaymentBadge,
        e.referenceNo,
        e.importFileCode ?? '—',
        e.projectName ?? '—',
        e.blNumber ?? '—',
        e.importerName ?? '—',
        e.description,
        e.currency,
        e.debitAmount > 0 ? e.debitAmount.toStringAsFixed(2) : '—',
        e.creditAmount > 0 ? e.creditAmount.toStringAsFixed(2) : '—',
        e.runningBalance.toStringAsFixed(2),
        e.status,
      ];
    }).toList();
  }

  void _copySoaTsv(BuildContext context, dynamic soa) {
    final l10n = context.l10n;
    final headers = _buildHeaders(l10n);
    final rows = _buildRows(soa, l10n);
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.soaExportTsvSuccess);
  }

  Future<void> _exportExcel(BuildContext context, dynamic soa) async {
    final l10n = context.l10n;
    final headers = _buildHeaders(l10n);
    final rows = _buildRows(soa, l10n);

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'SOA_${partner.partnerCode}',
      importFileNameOrCode: partner.partnerCode,
      customFileName: 'SOA_${partner.partnerCode}_${partner.partnerName}',
    );
  }

  Future<void> _exportPdf(BuildContext context, dynamic soa) async {
    final l10n = context.l10n;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final headers = _buildHeaders(l10n);
    final rows = _buildRows(soa, l10n);

    final title = l10n.partnerSoaTitle(partner.partnerName);
    final subtitle = l10n.partnerSoaSubtitle(partner.partnerType, partner.taxId ?? '—');

    final meta = <String, String>{
      isRtl ? 'كود الشريك' : 'Partner Code': partner.partnerCode,
      isRtl ? 'نوع الخدمة' : 'Service Type': partner.partnerType,
      isRtl ? 'إجمالي الرصيد المكافئ' : 'Total Equiv. Balance': '${_formatNumber(soa.equivalentEgpTotal ?? 0.0)} EGP',
    };

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: title,
      importFileNameOrCode: partner.partnerCode,
      headerContext: TableExportHeaderContext(
        title: title,
        subtitle: subtitle,
        metadata: meta,
      ),
    );
  }

  Future<void> _printSoa(BuildContext context, dynamic soa) async {
    final l10n = context.l10n;
    final headers = _buildHeaders(l10n);
    final rows = _buildRows(soa, l10n);

    final title = l10n.partnerSoaTitle(partner.partnerName);
    final subtitle = l10n.partnerSoaSubtitle(partner.partnerType, partner.taxId ?? '—');

    await TableExportService.printTable(
      context: context,
      headers: headers,
      rows: rows,
      stageName: title,
      headerContext: TableExportHeaderContext(
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  Future<void> _recordInvoice(BuildContext context, WidgetRef ref) async {
    final partnerType = partner.partnerType.toLowerCase();
    final defaultType = partnerType.contains('customs') || partnerType.contains('تخليص')
        ? 'customs'
        : (partnerType.contains('freight') || partnerType.contains('نولون') ? 'freight' : 'transport');

    await showDialog(
      context: context,
      builder: (ctx) => InvoiceFormDialog(
        defaultPartnerType: defaultType,
      ),
    );

    ref.invalidate(partnerStatementOfAccountProvider(partner.providerId ?? 0));
  }

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (ctx) => LogisticsPaymentDialog(
        defaultPartnerId: partner.providerId ?? 1,
        defaultPartnerName: partner.partnerName,
      ),
    );

    ref.invalidate(partnerStatementOfAccountProvider(partner.providerId ?? 0));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soaAsync = ref.watch(partnerStatementOfAccountProvider(partner.providerId ?? 0));

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.92).clamp(950.0, 1400.0);
    final dialogHeight = (screenSize.height * 0.90).clamp(620.0, 950.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SelectionArea(
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.transparent),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 24),
                    ),
                    const SizedBox(width: 14),
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
                                    fontSize: 16,
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
                          const SizedBox(height: 3),
                          Text(
                            l10n.partnerSoaSubtitle(partner.partnerType, partner.taxId ?? '—'),
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Quick Actions: Record Invoice & Record Payment
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      icon: const Icon(Icons.note_add_outlined, size: 16),
                      label: Text(l10n.partnerSoaRecordInvoiceBtn),
                      onPressed: () => _recordInvoice(context, ref),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: Text(l10n.partnerSoaRecordPaymentBtn),
                      onPressed: () => _recordPayment(context, ref),
                    ),
                    const SizedBox(width: 12),

                    // Export & Print Actions
                    IconButton(
                      icon: const Icon(Icons.print_outlined, color: Colors.white70, size: 20),
                      tooltip: l10n.partnerSoaPrintBtn,
                      onPressed: () {
                        final soa = soaAsync.asData?.value;
                        if (soa != null && soa.ledgerEntries.isNotEmpty) {
                          _printSoa(context, soa);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white70, size: 20),
                      tooltip: l10n.partnerSoaExportPdfBtn,
                      onPressed: () {
                        final soa = soaAsync.asData?.value;
                        if (soa != null && soa.ledgerEntries.isNotEmpty) {
                          _exportPdf(context, soa);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.table_view_outlined, color: Colors.white70, size: 20),
                      tooltip: l10n.partnerSoaExportExcelBtn,
                      onPressed: () {
                        final soa = soaAsync.asData?.value;
                        if (soa != null && soa.ledgerEntries.isNotEmpty) {
                          _exportExcel(context, soa);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.table_chart_outlined, color: Colors.white70, size: 20),
                      tooltip: l10n.soaExportTsvBtn,
                      onPressed: () {
                        final soa = soaAsync.asData?.value;
                        if (soa != null && soa.ledgerEntries.isNotEmpty) {
                          _copySoaTsv(context, soa);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                      tooltip: l10n.refresh,
                      onPressed: () {
                        ref.invalidate(partnerStatementOfAccountProvider(partner.providerId ?? 0));
                      },
                    ),
                    const SizedBox(width: 4),
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Total Equivalent EGP Summary Banner
                          if (soa.equivalentEgpTotal != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.cobalt.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.currency_exchange, color: AppTheme.cobalt, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      Directionality.of(context) == TextDirection.rtl
                                          ? 'إجمالي الرصيد المكافئ بالجنيه المصري (سعر البنك التجاري بتاريخ ${soa.asOfDate ?? "اليوم"}):'
                                          : 'Total Equivalent Balance in EGP (Commercial rate as of ${soa.asOfDate ?? "today"}):',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_formatNumber(soa.equivalentEgpTotal!)} ${l10n.soaCurrencyEgp}',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.cobalt,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (soa.hasUnconvertedBalances) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      Directionality.of(context) == TextDirection.rtl
                                          ? 'تنبيه: توجد عملات أجنبية ليس لها سعر صرف مسجل بتاريخ اليوم، لم يتم تحويلها للجنيه المصري.'
                                          : 'Notice: Some foreign currencies have no exchange rate recorded as of today and are not included in the EGP total.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Currency Balances Cards
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.multiCurrencyBalancesHeader,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                              Text(
                                l10n.invoicesCountLabel(soa.totalInvoicesCount, soa.totalPaymentsCount),
                                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 105,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: soa.currencyBalances.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, idx) {
                                final cb = soa.currencyBalances[idx];
                                final isPositive = cb.balanceDue > 0;
                                return Container(
                                  width: 230,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isPositive ? AppTheme.orange.withValues(alpha: 0.4) : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            cb.currency,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.cobalt),
                                          ),
                                          Icon(
                                            Icons.monetization_on_outlined,
                                            size: 16,
                                            color: isPositive ? AppTheme.orange : AppTheme.emerald,
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(l10n.totalInvoicedLabel, style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54)),
                                          Text(_formatNumber(cb.totalInvoiced), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : Colors.black87)),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(l10n.totalPaidLabel, style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black54)),
                                          Text(_formatNumber(cb.totalPaid), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(l10n.balanceDueLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                          Text(
                                            _formatNumber(cb.balanceDue),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isPositive ? AppTheme.crimson : AppTheme.emerald,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Ledger Table Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.transactionsLedgerHeader(soa.ledgerEntries.length),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Official General Ledger DataTable
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
                                                    Text(
                                                      _formatNumber(entry.runningBalance),
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
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
