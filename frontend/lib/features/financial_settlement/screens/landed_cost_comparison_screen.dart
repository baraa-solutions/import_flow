import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../services/landed_cost_comparison_export_service.dart';
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

  // Colors based on AppTheme specifications
  final Color _charcoal = AppTheme.charcoal;
  final Color _cobalt = AppTheme.cobalt;
  final Color _emerald = AppTheme.emerald;
  final Color _crimson = AppTheme.crimson;

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
          '${ApiConstants.baseUrl}/financial-settlements',
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
      case 'freight': return Colors.blue;
      case 'customs': return Colors.orange;
      case 'clearance': return Colors.teal;
      case 'transport': return Colors.purple;
      case 'storage': return Colors.amber.shade800;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fileDisplayCode = _selectedImportFileCode.isNotEmpty ? _selectedImportFileCode : (_selectedImportFileId != null ? 'IMP-#$_selectedImportFileId' : '');

    final bodyContent = SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: _buildImportFileSelector(),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _error != null 
                    ? Center(child: Text(_error!, style: TextStyle(color: _crimson)))
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
              style: const TextStyle(color: Colors.white),
            ),
            if (fileDisplayCode.isNotEmpty) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => CopyHelper.copy(context, fileDisplayCode, customMessage: 'تم نسخ كود ملف الشحنة'),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('نسخ', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: _charcoal,
        iconTheme: const IconThemeData(color: Colors.white),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: SearchableDropdownField<int>(
              labelText: l10n.selectImportFileDropdownLabel,
              hintText: l10n.selectImportFileDropdownHint,
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
              onTap: () => CopyHelper.copy(context, _selectedImportFileCode, customMessage: 'تم نسخ كود ملف الشحنة'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: _cobalt.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _cobalt.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy, size: 16, color: AppTheme.cobalt),
                    const SizedBox(width: 6),
                    Text(
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
      return Center(
        child: Text(
          l10n.selectImportFilePrompt,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );
    }

    if (_settlementRecord == null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 64, color: _charcoal),
                const SizedBox(height: 16),
                Text(l10n.noLandedCostDataRegistered, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    final totalFobEgp = (_settlementRecord!['total_fob_egp'] ?? 0.0).toDouble();
    final totalExpensesEgp = (_settlementRecord!['total_expenses_egp'] ?? 0.0).toDouble();
    final totalLandedCostEgp = (_settlementRecord!['total_landed_cost_egp'] ?? 0.0).toDouble();
    
    final fobVariance = _estimatedCost > 0 ? ((totalFobEgp - _estimatedCost) / _estimatedCost) * 100 : 0.0;
    final landedVariance = _estimatedCost > 0 ? ((totalLandedCostEgp - _estimatedCost) / _estimatedCost) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildExportToolbar(),
          const SizedBox(height: 24),
          _buildIncotermRuleCard(),
          const SizedBox(height: 24),
          _buildSummaryCards(totalFobEgp, totalExpensesEgp, totalLandedCostEgp, fobVariance, landedVariance),
          const SizedBox(height: 32),
          Text(l10n.expenseBreakdownHeader, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildExpenseTable(),
          const SizedBox(height: 32),
          Text(l10n.itemLandedCostHeader, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildItemLandedCostTable(),
          const SizedBox(height: 32),
          _buildSummaryBanner(landedVariance),
        ],
      ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: Text(l10n.landedCostExportTsvBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: _charcoal,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => exportService.exportToTsv(),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_present_outlined, size: 18),
            label: Text(l10n.landedCostExportExcelBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade800,
              side: BorderSide(color: Colors.green.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => exportService.exportToExcel(),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(l10n.landedCostPrintPdfBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: _crimson,
              side: BorderSide(color: _crimson.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => exportService.printOrSavePdf(),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_all, size: 18),
            label: Text(l10n.landedCostCopyDossierBtn),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => exportService.copyDossierToClipboard(),
          ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => CopyHelper.copy(context, inco, customMessage: 'تم نسخ شرط الشحن الدولي: $inco'),
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
                      Text(
                        inco,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy, size: 12, color: Colors.white70),
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.incoRuleExporterCoversLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exporterCovers,
                        style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.incoRuleImporterCoversLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        importerCovers,
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _cobalt.withOpacity(0.1), border: Border(bottom: BorderSide(color: _cobalt, width: 4))),
            child: Center(child: Text(l10n.estimatedCostHeader, style: TextStyle(fontSize: 22, color: _cobalt, fontWeight: FontWeight.bold))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _emerald.withOpacity(0.1), border: Border(bottom: BorderSide(color: _emerald, width: 4))),
            child: Center(child: Text(l10n.actualCostHeader, style: TextStyle(fontSize: 22, color: _emerald, fontWeight: FontWeight.bold))),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(double totalFob, double totalExpenses, double totalLanded, double fobVariance, double landedVariance) {
    final l10n = context.l10n;
    return Row(
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
    Color? varColor;
    if (variance != null) {
      varColor = variance > 0 ? _crimson : _emerald;
    }

    final summary = '$title: ${l10n.estAbbreviation} ${est.toStringAsFixed(2)} | ${l10n.actAbbreviation} ${act.toStringAsFixed(2)}${variance != null ? " (${variance > 0 ? '+' : ''}${variance.toStringAsFixed(2)}%)" : ""}';

    return Card(
      elevation: highlight ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: highlight ? BorderSide(color: _charcoal, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => CopyHelper.copy(context, summary, customMessage: title),
        borderRadius: BorderRadius.circular(8),
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
                  const Icon(Icons.copy, size: 14, color: Colors.grey),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.estAbbreviation, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(est.toStringAsFixed(2), style: TextStyle(fontSize: 15, color: _cobalt, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(l10n.actAbbreviation, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(act.toStringAsFixed(2), style: TextStyle(fontSize: 15, color: _emerald, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              if (variance != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: varColor?.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('${variance > 0 ? '+' : ''}${variance.toStringAsFixed(2)}%', style: TextStyle(color: varColor, fontWeight: FontWeight.bold)),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseTable() {
    final l10n = context.l10n;
    final expenses = _settlementRecord?['expense_invoices'] as List? ?? [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_charcoal.withOpacity(0.05)),
        columns: [
          DataColumn(label: Text(l10n.colExpenseCategory, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colExpenseProvider, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colExpenseCurrency, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colExpenseAmountFx, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colExpenseExchangeRate, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colExpenseAmountEgp, style: const TextStyle(fontWeight: FontWeight.bold))),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getCategoryColor(categoryRaw).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(categoryLocalized, style: TextStyle(color: _getCategoryColor(categoryRaw), fontWeight: FontWeight.bold)),
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
                child: Text(fx),
              )),
              DataCell(CopyableTableCell(
                value: rate,
                rowSummary: rowSummary,
                child: Text(rate),
              )),
              DataCell(CopyableTableCell(
                value: egp,
                rowSummary: rowSummary,
                child: Text(egp, style: const TextStyle(fontWeight: FontWeight.bold)),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_charcoal.withOpacity(0.05)),
        columns: [
          DataColumn(label: Text(l10n.colItemCode, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colItemName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colItemQty, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colFobUnitPrice, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colLandedUnitPrice, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text(l10n.colCostMarkupFactor, style: const TextStyle(fontWeight: FontWeight.bold))),
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
                child: Text(itemCode, style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
              DataCell(CopyableTableCell(
                value: itemName,
                rowSummary: rowSummary,
                child: Text(itemName),
              )),
              DataCell(CopyableTableCell(
                value: qty,
                rowSummary: rowSummary,
                child: Text(qty),
              )),
              DataCell(CopyableTableCell(
                value: fobUnit,
                rowSummary: rowSummary,
                child: Text(fobUnit),
              )),
              DataCell(CopyableTableCell(
                value: landedUnit,
                rowSummary: rowSummary,
                child: Text(landedUnit, style: TextStyle(fontWeight: FontWeight.bold, color: _emerald)),
              )),
              DataCell(CopyableTableCell(
                value: markupText,
                rowSummary: rowSummary,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _charcoal, borderRadius: BorderRadius.circular(16)),
                  child: Text(markupText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )),
            ]
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryBanner(double landedVariance) {
    final l10n = context.l10n;
    if (landedVariance > 10) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _crimson.withOpacity(0.1), border: Border.all(color: _crimson), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(Icons.warning, color: _crimson),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.landedCostOverBudgetBanner(landedVariance.toStringAsFixed(2)), style: TextStyle(color: _crimson, fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    } else if (landedVariance < 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _emerald.withOpacity(0.1), border: Border.all(color: _emerald), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: _emerald),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.landedCostUnderBudgetBanner(landedVariance.abs().toStringAsFixed(2)), style: TextStyle(color: _emerald, fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
