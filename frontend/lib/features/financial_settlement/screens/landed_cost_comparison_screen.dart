import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../services/landed_cost_comparison_export_service.dart';
import '../widgets/settlement_ui.dart';
import '../../../core/localization/domain_enum_labels.dart';

class LandedCostComparisonScreen extends ConsumerStatefulWidget {
  final int? importFileId;
  final String? importFileCode;
  final bool isEmbedded;

  const LandedCostComparisonScreen({
    super.key,
    this.importFileId,
    this.importFileCode,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<LandedCostComparisonScreen> createState() => _LandedCostComparisonScreenState();
}

class _LandedCostComparisonScreenState extends ConsumerState<LandedCostComparisonScreen> {
  bool _isLoading = false;
  String? _error;

  int? _selectedImportFileId;
  String _selectedImportFileCode = '';
  double _estimatedCost = 0.0;
  Map<String, dynamic>? _settlementRecord;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.importFileId;
    _selectedImportFileCode = widget.importFileCode ?? '';
    Future.microtask(() {
      if (!ref.read(importFilesProvider).isLoading) {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      }
      if (_selectedImportFileId != null && _selectedImportFileId! > 0) {
        _fetchData(_selectedImportFileId!);
      }
    });
  }

  @override
  void dispose() {
    _cancelToken?.cancel('LandedCostComparisonScreen disposed');
    super.dispose();
  }

  String _selectedIncoterm = 'FOB';

  Future<void> _fetchData(int fileId) async {
    _cancelToken?.cancel('New file fetch requested');
    _cancelToken = CancelToken();

    setState(() {
      _isLoading = true;
      _error = null;
      _selectedImportFileId = fileId;
    });

    try {
      final dio = ref.read(dioProvider);

      // Fetch import file for estimated cost and Incoterm
      try {
        final importFileRes = await dio.get(
          '${ApiConstants.baseUrl}/import-files/$fileId',
          cancelToken: _cancelToken,
        );
        if (importFileRes.data != null) {
          _estimatedCost = (importFileRes.data['estimated_cost'] ?? 0.0).toDouble();
          if (importFileRes.data['import_file_code'] != null) {
            _selectedImportFileCode = importFileRes.data['import_file_code'].toString();
          }
          if (importFileRes.data['incoterm_code'] != null) {
            _selectedIncoterm = importFileRes.data['incoterm_code'].toString().toUpperCase();
          }
        }
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) return;
        _estimatedCost = 0.0;
        _selectedIncoterm = 'FOB';
      }

      // Fetch settlement record safely
      try {
        final settlementRes = await dio.get(
          '${ApiConstants.baseUrl}/financial-settlement',
          queryParameters: {'import_file_id': fileId},
          cancelToken: _cancelToken,
        );

        final settlements = settlementRes.data;
        if (settlements != null && settlements is List && settlements.isNotEmpty) {
          _settlementRecord = settlements.first;
          if (_settlementRecord?['incoterm_code'] != null) {
            _selectedIncoterm = _settlementRecord!['incoterm_code'].toString().toUpperCase();
          }
        } else if (settlements != null && settlements is Map<String, dynamic> && settlements.containsKey('settlement_id')) {
          _settlementRecord = settlements;
          if (_settlementRecord?['incoterm_code'] != null) {
            _selectedIncoterm = _settlementRecord!['incoterm_code'].toString().toUpperCase();
          }
        } else {
          _settlementRecord = null;
        }
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) return;
        // No settlement registered yet for this file
        _settlementRecord = null;
      }

    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      _settlementRecord = null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'freight':
        return AppTheme.cobalt;
      case 'customs':
        return AppTheme.orange;
      case 'clearance':
        return AppTheme.wcagEmerald;
      case 'transport':
        return AppTheme.charcoal;
      case 'storage':
        return AppTheme.wcagOrange;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _money(num v) => formatSettlementMoney(v);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fileDisplayCode = _selectedImportFileCode.isNotEmpty ? _selectedImportFileCode : (_selectedImportFileId != null ? 'IMP-#$_selectedImportFileId' : '');

    final bodyContent = SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 0),
            child: _buildImportFileSelector(),
          ),
          Expanded(
            child: _isLoading
                ? SettlementStateView.loading(message: l10n.settlementRegistryLoading)
                : _error != null
                    ? SettlementStateView.error(message: _error!)
                    : _buildContent(),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              fileDisplayCode.isNotEmpty ? l10n.landedCostComparisonTitle(fileDisplayCode) : l10n.landedCostComparison,
              style: const TextStyle(color: AppTheme.white),
            ),
            if (fileDisplayCode.isNotEmpty) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => CopyHelper.copy(context, fileDisplayCode, customMessage: l10n.settlementCmpCopiedFileCode),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy, size: 13, color: AppTheme.white),
                      const SizedBox(width: 4),
                      Text(l10n.copy, style: const TextStyle(color: AppTheme.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppTheme.charcoal,
        iconTheme: const IconThemeData(color: AppTheme.white),
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 10),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildImportFileSelector() {
    final l10n = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final items = importFiles.map((file) {
      final supplier = file.supplierName.isNotEmpty ? file.supplierName : l10n.unknownSupplierFallback;
      final company = file.companyName.isNotEmpty ? file.companyName : '';
      final label = '${file.primaryNameWithCode} — $supplier ${company.isNotEmpty ? "($company)" : ""}';
      return SearchableDropdownItem<int>(
        value: file.importFileId,
        label: label,
      );
    }).toList();

    return SettlementPanel(
      child: Row(
        children: [
          Expanded(
            child: SearchableDropdownField<int>(
              labelText: l10n.settlementCmpFileLabel,
              searchHintText: l10n.selectImportFileDropdownHint,
              value: _selectedImportFileId,
              items: items,
              onChanged: (fileId) {
                if (fileId != null) {
                  final found = importFiles.where((f) => f.importFileId == fileId).firstOrNull;
                  if (found != null) {
                    _selectedImportFileCode = found.importFileCode;
                  }
                  _fetchData(fileId);
                } else {
                  setState(() {
                    _selectedImportFileId = null;
                    _selectedImportFileCode = '';
                    _settlementRecord = null;
                  });
                }
              },
            ),
          ),
          if (_selectedImportFileCode.isNotEmpty) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () => CopyHelper.copy(context, _selectedImportFileCode, customMessage: l10n.settlementCmpCopiedFileCode),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                    const SizedBox(width: 6),
                    LtrText(
                      _selectedImportFileCode,
                      style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    final l10n = context.l10n;
    if (_selectedImportFileId == null) {
      return SettlementStateView.empty(
        message: l10n.settlementCmpSelectFilePrompt,
        icon: Icons.analytics_outlined,
      );
    }

    if (_settlementRecord == null) {
      return SettlementStateView.empty(
        message: l10n.noLandedCostDataRegistered,
        icon: Icons.info_outline,
      );
    }

    final totalFobEgp = (_settlementRecord!['total_fob_egp'] ?? 0.0).toDouble();
    final totalExpensesEgp = (_settlementRecord!['total_expenses_egp'] ?? 0.0).toDouble();
    final totalLandedCostEgp = (_settlementRecord!['total_landed_cost_egp'] ?? 0.0).toDouble();

    final double? fobVariance = _estimatedCost > 0 ? ((totalFobEgp - _estimatedCost) / _estimatedCost) * 100 : null;
    final double? landedVariance = _estimatedCost > 0 ? ((totalLandedCostEgp - _estimatedCost) / _estimatedCost) * 100 : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricStrip(totalFobEgp, totalExpensesEgp, totalLandedCostEgp, landedVariance),
          const SizedBox(height: 16),
          _buildExportToolbar(),
          const SizedBox(height: 16),
          _buildIncotermRuleCard(),
          const SizedBox(height: 16),
          _buildSummaryCards(totalFobEgp, totalExpensesEgp, totalLandedCostEgp, fobVariance, landedVariance),
          const SizedBox(height: 24),
          SettlementSectionHeader(
            title: l10n.expenseBreakdownHeader,
            icon: Icons.receipt_long_outlined,
            color: AppTheme.cobalt,
          ),
          const SizedBox(height: 12),
          _buildExpenseTable(),
          const SizedBox(height: 24),
          SettlementSectionHeader(
            title: l10n.itemLandedCostHeader,
            icon: Icons.inventory_2_outlined,
            color: AppTheme.emerald,
          ),
          const SizedBox(height: 12),
          _buildItemLandedCostTable(),
          const SizedBox(height: 24),
          _buildSummaryBanner(landedVariance),
        ],
      ),
    );
  }

  Widget _buildMetricStrip(double totalFob, double totalExpenses, double totalLanded, double? landedVariance) {
    final l10n = context.l10n;
    final egp = l10n.financialSettlementCurrencyEgp;
    final varianceColor = landedVariance == null
        ? AppTheme.textSecondary
        : landedVariance > 0
            ? AppTheme.crimson
            : AppTheme.emerald;
    return MetricCardStrip(
      padding: EdgeInsets.zero,
      metrics: [
        MetricCardData(
          title: l10n.estimatedCostHeader,
          value: _estimatedCost > 0 ? '${_money(_estimatedCost)} $egp' : '-',
          icon: Icons.request_quote_outlined,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l10n.totalExpensesCardTitle,
          value: '${_money(totalExpenses)} $egp',
          icon: Icons.receipt_long_outlined,
          color: AppTheme.orange,
        ),
        MetricCardData(
          title: l10n.totalLandedCostCardTitle,
          value: '${_money(totalLanded)} $egp',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.emerald,
        ),
        MetricCardData(
          title: l10n.settlementCmpVarianceLabel,
          value: landedVariance != null ? formatSettlementPercent(landedVariance, digits: 2) : '-',
          icon: landedVariance == null
              ? Icons.remove
              : landedVariance > 0
                  ? Icons.trending_up
                  : Icons.trending_down,
          color: varianceColor,
        ),
      ],
    );
  }

  Widget _buildExportToolbar() {
    final l10n = context.l10n;
    final exportService = LandedCostComparisonExportService(
      context: context,
      fileCode: _selectedImportFileCode.isNotEmpty ? _selectedImportFileCode : (_selectedImportFileId != null ? 'IMP-#$_selectedImportFileId' : 'SHIPMENT'),
      incoterm: _selectedIncoterm,
      estimatedCost: _estimatedCost,
      settlementRecord: _settlementRecord,
    );

    return SettlementPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SettlementFit(child: AppButton(
            label: l10n.landedCostExportTsvBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => exportService.exportToTsv(),
          )),
          SettlementFit(child: AppButton(
            label: l10n.landedCostExportExcelBtn,
            icon: Icons.file_present_outlined,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: () => exportService.exportToExcel(),
          )),
          SettlementFit(child: AppButton(
            label: l10n.landedCostPrintPdfBtn,
            icon: Icons.picture_as_pdf_outlined,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () => exportService.printOrSavePdf(),
          )),
          SettlementFit(child: AppButton(
            label: l10n.landedCostCopyDossierBtn,
            icon: Icons.copy_all,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () => exportService.copyDossierToClipboard(),
          )),
        ],
      ),
    );
  }

  Widget _buildIncotermRuleCard() {
    final l10n = context.l10n;
    final inco = _selectedIncoterm.toUpperCase();

    String ruleTitle;
    String ruleDesc;
    String exporterCovers;
    String importerCovers;

    switch (inco) {
      case 'CIF':
      case 'CIP':
        ruleTitle = l10n.incoCifRuleTitle;
        ruleDesc = l10n.incoCifRuleDesc;
        exporterCovers = l10n.incoCifExporterCovers;
        importerCovers = l10n.incoCifImporterCovers;
        break;
      case 'CFR':
      case 'CPT':
        ruleTitle = l10n.incoCfrRuleTitle;
        ruleDesc = l10n.incoCfrRuleDesc;
        exporterCovers = l10n.incoCfrExporterCovers;
        importerCovers = l10n.incoCfrImporterCovers;
        break;
      case 'EXW':
        ruleTitle = l10n.incoExwRuleTitle;
        ruleDesc = l10n.incoExwRuleDesc;
        exporterCovers = l10n.incoExwExporterCovers;
        importerCovers = l10n.incoExwImporterCovers;
        break;
      case 'DDP':
        ruleTitle = l10n.incoDdpRuleTitle;
        ruleDesc = l10n.incoDdpRuleDesc;
        exporterCovers = l10n.incoDdpExporterCovers;
        importerCovers = l10n.incoDdpImporterCovers;
        break;
      case 'FOB':
      case 'FCA':
      case 'FAS':
      default:
        ruleTitle = l10n.incoFobRuleTitle;
        ruleDesc = l10n.incoFobRuleDesc;
        exporterCovers = l10n.incoFobExporterCovers;
        importerCovers = l10n.incoFobImporterCovers;
        break;
    }

    Widget coverBox(String label, String text, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.charcoal)),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => CopyHelper.copy(context, inco, customMessage: l10n.settlementCmpCopiedIncoterm(inco)),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LtrText(
                        inco,
                        style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy, size: 12, color: AppTheme.white.withOpacity(0.7)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ruleTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ruleDesc,
            style: const TextStyle(fontSize: 12, color: AppTheme.textStrong, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              coverBox(l10n.incoRuleExporterCoversLabel, exporterCovers, AppTheme.wcagEmerald),
              const SizedBox(width: 12),
              coverBox(l10n.incoRuleImporterCoversLabel, importerCovers, AppTheme.cobalt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double totalFob, double totalExpenses, double totalLanded, double? fobVariance, double? landedVariance) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildCard(l10n.fobValueCardTitle, _estimatedCost, totalFob, fobVariance)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard(l10n.totalExpensesCardTitle, 0, totalExpenses, null)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard(l10n.totalLandedCostCardTitle, _estimatedCost, totalLanded, landedVariance, highlight: true)),
      ],
    );
  }

  Widget _buildCard(String title, double est, double act, double? variance, {bool highlight = false}) {
    final l10n = context.l10n;
    final varColor = variance == null ? null : (variance > 0 ? AppTheme.crimson : AppTheme.emerald);

    final summary = '$title: ${l10n.estAbbreviation} ${est.toStringAsFixed(2)} | ${l10n.actAbbreviation} ${act.toStringAsFixed(2)}${variance != null ? " (${variance > 0 ? '+' : ''}${variance.toStringAsFixed(2)}%)" : ""}';

    return Card(
      elevation: highlight ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        side: highlight
            ? const BorderSide(color: AppTheme.charcoal, width: 1.5)
            : BorderSide(color: SettlementTokens.border),
      ),
      child: InkWell(
        onTap: () => CopyHelper.copy(context, summary, customMessage: title),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.estAbbreviation, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      LtrText(_money(est), style: const TextStyle(fontSize: 15, color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(l10n.actAbbreviation, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      LtrText(_money(act), style: const TextStyle(fontSize: 15, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              if (variance != null) ...[
                const SizedBox(height: 8),
                SettlementStatusChip(
                  label: formatSettlementPercent(variance, digits: 2),
                  color: varColor!,
                  icon: variance > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  dense: true,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableFrame(Widget table) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: SettlementTokens.border),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      ),
    );
  }

  Widget _buildExpenseTable() {
    final l10n = context.l10n;
    final expenses = _settlementRecord?['expense_invoices'] as List? ?? [];
    return _tableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columns: [
          DataColumn(label: settlementHeadCell(l10n.colExpenseCategory)),
          DataColumn(label: settlementHeadCell(l10n.colExpenseProvider)),
          DataColumn(label: settlementHeadCell(l10n.colExpenseCurrency)),
          DataColumn(label: settlementHeadCell(l10n.colExpenseAmountFx), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.colExpenseExchangeRate), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.colExpenseAmountEgp), numeric: true),
        ],
        rows: expenses.map((e) {
          final categoryRaw = e['category']?.toString() ?? 'other';
          final categoryLocalized = (DomainEnums.labelIfKnown(l10n, DomainEnumType.clearanceExpenseCategory, categoryRaw) ?? l10n.expenseCategoryName(categoryRaw));
          final provider = e['provider_name']?.toString() ?? '-';
          final cur = e['currency']?.toString() ?? 'EGP';
          final fx = (e['amount_fx'] ?? 0).toString();
          final rate = (e['exchange_rate'] ?? 1).toString();
          final egp = (e['amount_egp'] ?? 0).toString();

          final rowSummary = '$categoryLocalized | $provider | $fx $cur @ $rate = $egp EGP';

          return DataRow(
            cells: [
              DataCell(CopyableTableCell(
                value: categoryLocalized,
                rowSummary: rowSummary,
                child: SettlementStatusChip(
                  label: categoryLocalized,
                  color: _getCategoryColor(categoryRaw),
                  dense: true,
                ),
              )),
              DataCell(CopyableTableCell(
                value: provider,
                rowSummary: rowSummary,
                child: Text(provider),
              )),
              DataCell(CopyableTableCell(
                value: cur,
                rowSummary: rowSummary,
                child: Text(cur),
              )),
              DataCell(CopyableTableCell(
                value: fx,
                rowSummary: rowSummary,
                child: SettlementMoneyText(fx),
              )),
              DataCell(CopyableTableCell(
                value: rate,
                rowSummary: rowSummary,
                child: SettlementMoneyText(rate),
              )),
              DataCell(CopyableTableCell(
                value: egp,
                rowSummary: rowSummary,
                child: SettlementMoneyText(egp, style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemLandedCostTable() {
    final l10n = context.l10n;
    final items = _settlementRecord?['item_landed_costs'] as List? ?? [];
    return _tableFrame(
      DataTable(
        headingRowColor: WidgetStateProperty.all(SettlementTokens.tableHeadFill),
        columns: [
          DataColumn(label: settlementHeadCell(l10n.colItemCode)),
          DataColumn(label: settlementHeadCell(l10n.colItemName)),
          DataColumn(label: settlementHeadCell(l10n.colItemQty), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.colFobUnitPrice), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.colLandedUnitPrice), numeric: true),
          DataColumn(label: settlementHeadCell(l10n.colCostMarkupFactor), numeric: true),
        ],
        rows: items.map((e) {
          final markup = (e['markup_factor'] ?? 1.0).toDouble();
          final itemCode = e['item_code']?.toString() ?? '-';
          final itemName = e['item_name']?.toString() ?? '-';
          final qty = (e['qty'] ?? 0).toString();
          final fobUnit = ((e['fob_unit_egp'] ?? 0) as num).toStringAsFixed(2);
          final landedUnit = ((e['unit_landed_cost_egp'] ?? 0) as num).toStringAsFixed(2);
          final markupText = '${markup.toStringAsFixed(2)}x';

          final rowSummary = '[$itemCode] $itemName | Qty: $qty | FOB: $fobUnit EGP | Landed: $landedUnit EGP | Markup: $markupText';

          return DataRow(
            cells: [
              DataCell(CopyableTableCell(
                value: itemCode,
                rowSummary: rowSummary,
                child: LtrText(itemCode, style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
              DataCell(CopyableTableCell(
                value: itemName,
                rowSummary: rowSummary,
                child: Text(itemName),
              )),
              DataCell(CopyableTableCell(
                value: qty,
                rowSummary: rowSummary,
                child: SettlementMoneyText(qty),
              )),
              DataCell(CopyableTableCell(
                value: fobUnit,
                rowSummary: rowSummary,
                child: SettlementMoneyText(_money(double.parse(fobUnit))),
              )),
              DataCell(CopyableTableCell(
                value: landedUnit,
                rowSummary: rowSummary,
                child: SettlementMoneyText(
                  _money(double.parse(landedUnit)),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald),
                ),
              )),
              DataCell(CopyableTableCell(
                value: markupText,
                rowSummary: rowSummary,
                child: SettlementStatusChip(label: markupText, color: AppTheme.charcoal, dense: true),
              )),
            ]
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryBanner(double? landedVariance) {
    if (landedVariance == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    if (landedVariance > 10) {
      return _banner(
        color: AppTheme.crimson,
        icon: Icons.warning,
        text: l10n.landedCostOverBudgetBanner(landedVariance.toStringAsFixed(2)),
      );
    } else if (landedVariance < 0) {
      return _banner(
        color: AppTheme.emerald,
        icon: Icons.check_circle,
        text: l10n.landedCostUnderBudgetBanner(landedVariance.abs().toStringAsFixed(2)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _banner({required Color color, required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
