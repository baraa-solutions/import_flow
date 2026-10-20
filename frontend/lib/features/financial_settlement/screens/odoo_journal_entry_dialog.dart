import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../widgets/settlement_ui.dart';
import '../models/financial_settlement_model.dart';
import '../providers/financial_settlement_provider.dart';

class OdooJournalEntryDialog extends ConsumerStatefulWidget {
  final int settlementId;
  final String settlementCode;

  const OdooJournalEntryDialog({
    super.key,
    required this.settlementId,
    required this.settlementCode,
  });

  @override
  ConsumerState<OdooJournalEntryDialog> createState() => _OdooJournalEntryDialogState();
}

class _OdooJournalEntryDialogState extends ConsumerState<OdooJournalEntryDialog> {
  OdooJournalEntryModel? _journalEntry;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final entry = await ref
          .read(financialSettlementProvider.notifier)
          .fetchOdooJournalEntry(widget.settlementId);
      if (mounted) {
        setState(() {
          _journalEntry = entry;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ApiErrorText.of(context.l10n, e);
          _isLoading = false;
        });
      }
    }
  }

  bool _isExporting = false;

  String get _fileCode {
    final code = _journalEntry?.importFileCode ?? '';
    return code.isNotEmpty ? code : widget.settlementCode;
  }

  Future<void> _downloadOdooCsv(int settlementId) async {
    if (_isExporting) return;
    final l10n = context.l10n;
    setState(() => _isExporting = true);
    try {
      final notifier = ref.read(financialSettlementProvider.notifier);
      final csvData = await notifier.downloadOdooCsv(settlementId);
      if (!mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        // UTF-8 BOM so Excel opens Arabic text correctly.
        bytes: [0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)],
        stageName: l10n.settlementStageOdooCsv,
        importFileNameOrCode: _fileCode,
        extension: 'csv',
        customDialogTitle: l10n.odooJournalSaveCsvDialogTitle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorText.of(l10n, e, fallback: l10n.settlementExportFailed)), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadOdooExcel(int settlementId) async {
    if (_isExporting) return;
    final l10n = context.l10n;
    setState(() => _isExporting = true);
    try {
      final notifier = ref.read(financialSettlementProvider.notifier);
      final bytes = await notifier.downloadOdooExcel(settlementId);
      if (!mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: bytes,
        stageName: l10n.settlementStageOdooExcel,
        importFileNameOrCode: _fileCode,
        extension: 'xlsx',
        customDialogTitle: l10n.odooJournalSaveExcelDialogTitle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorText.of(l10n, e, fallback: l10n.settlementExportFailed)), backgroundColor: AppTheme.crimson),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = (screenWidth - 32).clamp(320.0, 1100.0);
    final dialogHeight = (screenHeight * 0.85).clamp(420.0, 750.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: _isLoading
              ? SettlementStateView.loading(message: l10n.odooJournalLoading)
              : _errorMessage != null
                  ? SettlementStateView.error(
                      message: l10n.odooJournalFetchError(_errorMessage!),
                      actionLabel: l10n.retry,
                      onAction: _loadJournal,
                    )
                  : _buildContent(),
        ),
      ),
    );
  }

  void _copyJournalEntryTSV(BuildContext context, OdooJournalEntryModel entry) {
    final l10n = context.l10n;
    final egp = l10n.financialSettlementCurrencyEgp;
    final buffer = StringBuffer();
    buffer.writeln(l10n.settlementOdooTsvTitle(entry.settlementCode));
    buffer.writeln('${l10n.settlementOdooLblImporter}:	${entry.companyName}	${l10n.settlementOdooLblSupplier}:	${entry.supplierName}');
    buffer.writeln('${l10n.settlementOdooLblImportFile}:	${entry.importFileCode}	${l10n.settlementOdooLblDate}:	${entry.entryDate}');
    buffer.writeln('${l10n.settlementOdooLblTotalDebitCredit}:	${entry.totalDebit.toStringAsFixed(2)} $egp');
    buffer.writeln('');
    buffer.writeln([
      l10n.odooJournalColAccountCode,
      l10n.odooJournalColAccountName,
      l10n.odooJournalColPartner,
      l10n.odooJournalColLabel,
      l10n.odooJournalColDebit,
      l10n.odooJournalColCredit,
      l10n.odooJournalColForeignCurrency,
      l10n.odooJournalColCostCategory,
    ].join('	'));

    for (final l in entry.lines) {
      final code = l.accountCode;
      final name = l.accountName;
      final partner = l.partnerName;
      final label = l.label;
      final debit = l.debit > 0 ? l.debit.toStringAsFixed(2) : '0.00';
      final credit = l.credit > 0 ? l.credit.toStringAsFixed(2) : '0.00';
      final fc = l.amountCurrency != null ? '${l.amountCurrency!.toStringAsFixed(2)} ${l.currency}' : '';
      final cat = _getCategoryLabel(context, l.costCategory);
      buffer.writeln('$code	$name	$partner	$label	$debit	$credit	$fc	$cat');
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.odooJournalCopyTsvSuccess,
    );
  }

  Widget _buildContent() {
    final l10n = context.l10n;
    final entry = _journalEntry!;
    final egp = l10n.financialSettlementCurrencyEgp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettlementDialogHeader(
          icon: Icons.receipt_long,
          title: l10n.odooJournalTitle(entry.settlementCode),
          subtitle: l10n.odooJournalSubtitle(entry.importFileCode, entry.reference),
          trailing: SettlementStatusChip(
            label: entry.isBalanced
                ? l10n.odooJournalBalanced
                : l10n.odooJournalUnbalanced(entry.difference.toStringAsFixed(2)),
            color: entry.isBalanced ? AppTheme.emerald : AppTheme.crimson,
            icon: entry.isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
          ),
          onClose: () => Navigator.pop(context),
          closeTooltip: l10n.settlementClose,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata header strip
                SettlementPanel(
                  filled: true,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildMetaItem(l10n.odooJournalMetaImporter, entry.companyName, Icons.business),
                      _buildMetaDivider(),
                      _buildMetaItem(l10n.odooJournalMetaSupplier, entry.supplierName, Icons.flight_takeoff),
                      _buildMetaDivider(),
                      _buildMetaItem(l10n.odooJournalMetaProject, entry.projectName ?? l10n.settlementNotAvailable, Icons.account_tree),
                      _buildMetaDivider(),
                      _buildMetaItem(l10n.odooJournalMetaDate, entry.entryDate, Icons.calendar_today),
                      _buildMetaDivider(),
                      _buildMetaItem(
                        l10n.odooJournalMetaTotalDebitCredit,
                        '${formatSettlementMoney(entry.totalDebit)} $egp',
                        Icons.account_balance_wallet,
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SettlementTokens.sectionGap),
                SettlementSectionHeader(
                  title: l10n.odooJournalLinesSectionHeader,
                  icon: Icons.menu_book_outlined,
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildLinesTable(entry, l10n, egp)),
              ],
            ),
          ),
        ),
        SettlementDialogFooter(
          leading: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              SettlementFit(child: AppButton(
                label: l10n.odooJournalExportCsvBtn,
                icon: Icons.file_download,
                variant: AppButtonVariant.primary,
                isLoading: _isExporting,
                onPressed: _isExporting ? null : () => _downloadOdooCsv(entry.settlementId),
              )),
              SettlementFit(child: AppButton(
                label: l10n.odooJournalExportExcelBtn,
                icon: Icons.table_view,
                variant: AppButtonVariant.success,
                isLoading: _isExporting,
                onPressed: _isExporting ? null : () => _downloadOdooExcel(entry.settlementId),
              )),
              SettlementFit(child: AppButton(
                label: l10n.odooJournalCopyTsvBtn,
                icon: Icons.copy_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () => _copyJournalEntryTSV(context, entry),
              )),
            ],
          ),
          actions: [
            SettlementFit(child: AppButton(
              label: l10n.close,
              icon: Icons.close,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildLinesTable(OdooJournalEntryModel entry, AppLocalizations l10n, String egp) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: SettlementTokens.border),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
              columns: [
                DataColumn(label: settlementHeadCell(l10n.odooJournalColAccountCode)),
                DataColumn(label: settlementHeadCell(l10n.odooJournalColAccountName)),
                DataColumn(label: settlementHeadCell(l10n.odooJournalColPartner)),
                DataColumn(label: settlementHeadCell(l10n.odooJournalColLabel)),
                DataColumn(label: settlementHeadCell(l10n.odooJournalColDebit), numeric: true),
                DataColumn(label: settlementHeadCell(l10n.odooJournalColCredit), numeric: true),
                DataColumn(label: settlementHeadCell(l10n.odooJournalColForeignCurrency), numeric: true),
                DataColumn(label: settlementHeadCell(l10n.odooJournalColCostCategory)),
              ],
              rows: entry.lines.map((l) {
                final isDebit = l.debit > 0;
                final debitStr = l.debit > 0 ? '${l.debit.toStringAsFixed(2)} $egp' : '-';
                final creditStr = l.credit > 0 ? '${l.credit.toStringAsFixed(2)} $egp' : '-';
                final fcStr = l.amountCurrency != null ? '${l.amountCurrency!.toStringAsFixed(2)} ${l.currency}' : '-';
                final catStr = _getCategoryLabel(context, l.costCategory);
                final rowSummary = '${l.accountCode}\t${l.accountName}\t${l.partnerName}\t${l.label}\t$debitStr\t$creditStr\t$fcStr\t$catStr';

                return DataRow(
                  color: WidgetStateProperty.all(
                    isDebit ? AppTheme.emerald.withValues(alpha: 0.04) : Colors.transparent,
                  ),
                  cells: [
                    DataCell(
                      CopyableTableCell(
                        value: l.accountCode,
                        rowSummary: rowSummary,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDebit ? AppTheme.emerald.withValues(alpha: 0.1) : SettlementTokens.tableHeadFill,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: LtrText(l.accountCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: l.accountName,
                        rowSummary: rowSummary,
                        child: Text(l.accountName, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: l.partnerName,
                        rowSummary: rowSummary,
                        child: Text(l.partnerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: l.label,
                        rowSummary: rowSummary,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(l.label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: debitStr,
                        rowSummary: rowSummary,
                        child: SettlementMoneyText(
                          debitStr,
                          style: TextStyle(
                            fontWeight: isDebit ? FontWeight.bold : FontWeight.normal,
                            color: isDebit ? AppTheme.emerald : AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: creditStr,
                        rowSummary: rowSummary,
                        child: SettlementMoneyText(
                          creditStr,
                          style: TextStyle(
                            fontWeight: !isDebit ? FontWeight.bold : FontWeight.normal,
                            color: !isDebit ? AppTheme.charcoal : AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: fcStr,
                        rowSummary: rowSummary,
                        child: SettlementMoneyText(
                          fcStr,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textStrong),
                        ),
                      ),
                    ),
                    DataCell(
                      CopyableTableCell(
                        value: catStr,
                        rowSummary: rowSummary,
                        child: _buildCategoryBadge(context, l.costCategory),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem(String title, String value, IconData icon, {bool isHighlight = false}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: isHighlight ? AppTheme.emerald : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: DisplayDensityMode.clampFontSize(11.0))),
                CopyableText(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isHighlight ? 12.5 : 11.5,
                    color: isHighlight ? AppTheme.emerald : AppTheme.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaDivider() {
    return Container(
      height: 24,
      width: 1,
      color: SettlementTokens.border,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  String _getCategoryLabel(BuildContext context, String category) {
    switch (category) {
      case 'Goods':
        return context.l10n.odooJournalCatGoods;
      case 'Freight':
        return context.l10n.odooJournalCatFreight;
      case 'Customs':
        return context.l10n.odooJournalCatCustoms;
      case 'Clearance':
        return context.l10n.odooJournalCatClearance;
      case 'Transport':
        return context.l10n.odooJournalCatTransport;
      case 'Demurrage':
        return context.l10n.odooJournalCatDemurrage;
      case 'Price_Adjustment':
        return context.l10n.odooJournalCatPriceAdjustment;
      default:
        return category;
    }
  }

  Widget _buildCategoryBadge(BuildContext context, String category) {
    Color color;
    switch (category) {
      case 'Goods':
        color = AppTheme.emerald;
        break;
      case 'Freight':
        color = AppTheme.cobalt;
        break;
      case 'Customs':
        color = AppTheme.wcagCobalt;
        break;
      case 'Clearance':
        color = AppTheme.wcagEmerald;
        break;
      case 'Transport':
        color = AppTheme.orange;
        break;
      case 'Demurrage':
        color = AppTheme.crimson;
        break;
      case 'Price_Adjustment':
        color = AppTheme.wcagOrange;
        break;
      default:
        color = AppTheme.textStrong;
    }

    final label = _getCategoryLabel(context, category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: DisplayDensityMode.clampFontSize(11.0)),
      ),
    );
  }
}
