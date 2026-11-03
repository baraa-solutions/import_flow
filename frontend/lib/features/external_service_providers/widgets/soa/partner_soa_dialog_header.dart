import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../logistics_invoices/widgets/invoice_form_dialog.dart';
import '../../../logistics_invoices/widgets/logistics_payment_dialog.dart';
import '../../models/partner_model.dart';
import '../../providers/partners_provider.dart';

class PartnerSoaDialogHeader extends ConsumerWidget {
  final PartnerModel partner;
  final AsyncValue<dynamic> soaAsync;

  const PartnerSoaDialogHeader({
    super.key,
    required this.partner,
    required this.soaAsync,
  });

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
    final entries = soa.ledgerEntries as List<PartnerLedgerEntryModel>;
    if (entries.isEmpty) {
      return [
        [
          soa.asOfDate ?? DateTime.now().toString().split(' ')[0],
          '—',
          '—',
          '—',
          '—',
          '—',
          '—',
          l10n.noLedgerEntriesFound,
          partner.supportedCurrencies ?? 'EGP',
          '0.00',
          '0.00',
          '0.00',
          l10n.statusActive,
        ]
      ];
    }
    return entries.map((e) {
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
    final defaultType = partnerType.contains('customs') || partnerType.contains('تخليص') || partnerType.contains('broker')
        ? 'clearance'
        : (partnerType.contains('freight') || partnerType.contains('shipping') || partnerType.contains('carrier') || partnerType.contains('نولون') || partnerType.contains('شحن')
            ? 'freight'
            : (partnerType.contains('inspection') || partnerType.contains('فحص')
                ? 'inspection'
                : (partnerType.contains('insurance') || partnerType.contains('تأمين')
                    ? 'insurance'
                    : 'transport')));

    await showDialog(
      context: context,
      builder: (ctx) => InvoiceFormDialog(
        defaultPartnerType: defaultType,
        initialPartnerId: partner.providerId,
        initialPartnerName: partner.partnerName,
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

    return Container(
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
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white70, size: 20),
            tooltip: l10n.partnerSoaPrintBtn,
            onPressed: () {
              final soa = soaAsync.asData?.value;
              if (soa != null) {
                _printSoa(context, soa);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(soaAsync.isLoading ? l10n.calculatingSoaMsg : l10n.noSoaDataAvailable),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white70, size: 20),
            tooltip: l10n.partnerSoaExportPdfBtn,
            onPressed: () {
              final soa = soaAsync.asData?.value;
              if (soa != null) {
                _exportPdf(context, soa);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(soaAsync.isLoading ? l10n.calculatingSoaMsg : l10n.noSoaDataAvailable),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_view_outlined, color: Colors.white70, size: 20),
            tooltip: l10n.partnerSoaExportExcelBtn,
            onPressed: () {
              final soa = soaAsync.asData?.value;
              if (soa != null) {
                _exportExcel(context, soa);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(soaAsync.isLoading ? l10n.calculatingSoaMsg : l10n.noSoaDataAvailable),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Colors.white70, size: 20),
            tooltip: l10n.soaExportTsvBtn,
            onPressed: () {
              final soa = soaAsync.asData?.value;
              if (soa != null) {
                _copySoaTsv(context, soa);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(soaAsync.isLoading ? l10n.calculatingSoaMsg : l10n.noSoaDataAvailable),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            tooltip: l10n.refresh,
            onPressed: () {
              ref.invalidate(partnerStatementOfAccountProvider(partner.providerId ?? 0));
              final _ = ref.refresh(partnerStatementOfAccountProvider(partner.providerId ?? 0));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      Directionality.of(context) == TextDirection.rtl
                          ? 'تم تحديث كشف الحساب بنجاح'
                          : 'Statement of account refreshed successfully',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
