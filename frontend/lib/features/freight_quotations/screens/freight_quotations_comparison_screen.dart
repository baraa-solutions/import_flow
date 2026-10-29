import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../services/freight_quotations_export_service.dart';
import '../widgets/freight_quotations_comparison_table.dart';

class FreightQuotationsComparisonScreen extends ConsumerStatefulWidget {
  const FreightQuotationsComparisonScreen({super.key});

  @override
  ConsumerState<FreightQuotationsComparisonScreen> createState() => _FreightQuotationsComparisonScreenState();
}

class _FreightQuotationsComparisonScreenState extends ConsumerState<FreightQuotationsComparisonScreen> {
  final Color _charcoal = AppTheme.charcoal;
  final Color _cobalt = AppTheme.cobalt;
  final Color _emerald = AppTheme.emerald;

  bool _isLoading = false;
  String? _error;
  List<dynamic> _quotations = [];
  int? _selectedImportFileId;
  int? _selectedQuotationId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    });
  }

  Future<void> _fetchQuotations(int importFileId) async {
    final l10n = context.l10n;
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedImportFileId = importFileId;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('${ApiConstants.baseUrl}/freight-quotations', queryParameters: {'import_file_id': importFileId});
      
      final data = res.data;
      List<dynamic> allQuotes = [];
      if (data is List) {
        for (var rfq in data) {
          if (rfq['quotations'] is List) {
            for (var q in rfq['quotations']) {
              q['rfq_id'] = rfq['rfq_id'];
              allQuotes.add(q);
            }
          } else {
            allQuotes.add(rfq);
          }
        }
      }
      _quotations = allQuotes.take(4).toList(); // Max 4
      
      // Determine selected if any
      final selected = _quotations.where((q) => q['is_awarded'] == true).toList();
      if (selected.isNotEmpty) {
        _selectedQuotationId = selected.first['quotation_id'];
      } else {
        _selectedQuotationId = null;
      }

    } catch (e) {
      _error = l10n.freightQuotesLoadError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectQuotation(int quotationId) async {
    final l10n = context.l10n;
    final quote = _quotations.where((q) => q['quotation_id'] == quotationId).firstOrNull;
    final rfqId = quote?['rfq_id'];

    setState(() {
      _selectedQuotationId = quotationId;
    });

    if (rfqId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.freightQuoteSelectedSuccess,
            severity: AppSeverity.success,
          ),
        );
      }
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      await dio.post('${ApiConstants.baseUrl}/freight-quotations/$rfqId/award/$quotationId');
      if (_selectedImportFileId != null) {
        await _fetchQuotations(_selectedImportFileId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.freightQuoteAwardedSuccess,
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            l10n.freightQuoteAwardError(e.toString()),
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final selectedFile = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final fileCode = selectedFile?.primaryNameWithCode ?? selectedFile?.importFileCode ?? '';
    final supplierName = selectedFile?.supplierName ?? '';

    return Scaffold(
      appBar: PageHeader(
        icon: Icons.compare_arrows_rounded,
        title: l10n.freightQuotationsComparisonTitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 10),
        ],
      ),

      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImportFileSelector(importFiles),
              const SizedBox(height: 16),
              if (_quotations.isNotEmpty) ...[
                _buildExportToolbar(fileCode: fileCode, supplierName: supplierName),
                const SizedBox(height: 16),
              ],
              if (_isLoading)
                const Expanded(child: AppLoadingState())
              else if (_error != null)
                Expanded(
                  child: AppErrorState(
                    error: _error!,
                    onRetry: _selectedImportFileId != null
                        ? () => _fetchQuotations(_selectedImportFileId!)
                        : null,
                  ),
                )
              else if (_selectedImportFileId == null)
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.folder_open_outlined,
                    message: l10n.selectImportFilePrompt,
                  ),
                )
              else if (_quotations.isEmpty)
                Expanded(
                  child: AppEmptyState(
                    icon: Icons.request_quote_outlined,
                    message: l10n.noFreightQuotesForFile,
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      _buildMetricsBar(),
                      const SizedBox(height: 24),
                      Expanded(
                        child: FreightQuotationsComparisonTable(
                          quotations: _quotations,
                          selectedQuotationId: _selectedQuotationId,
                          onSelectQuotation: _selectQuotation,
                        ),
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

  Widget _buildExportToolbar({required String fileCode, required String supplierName}) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          if (fileCode.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => CopyHelper.copy(context, fileCode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.flatCobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.flatCobalt.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded, size: 14, color: AppTheme.flatCobalt),
                    const SizedBox(width: 6),
                    LtrText(
                      fileCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.flatCobalt,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.flatCobalt,
                  side: const BorderSide(color: AppTheme.flatCobalt),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.table_chart_outlined, size: 16),
                label: Text(l10n.freightQuotationsExportTsvBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => FreightQuotationsExportService.exportToTsv(
                  context: context,
                  quotations: _quotations,
                  importFileCode: fileCode,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.flatEmerald,
                  side: const BorderSide(color: AppTheme.flatEmerald),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: Text(l10n.freightQuotationsExportExcelBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => FreightQuotationsExportService.exportToExcel(
                  context: context,
                  quotations: _quotations,
                  importFileCode: fileCode,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: Text(l10n.freightQuotationsPrintPdfBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => FreightQuotationsExportService.printOrSavePdf(
                  context: context,
                  quotations: _quotations,
                  importFileCode: fileCode,
                  supplierName: supplierName,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _charcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                label: Text(l10n.freightQuotationsCopyDossierBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final text = FreightQuotationsExportService.buildDossierText(
                    context: context,
                    quotations: _quotations,
                    importFileCode: fileCode,
                    supplierName: supplierName,
                  );
                  CopyHelper.copy(context, text, customMessage: l10n.freightQuotationsCopyDossierSuccess);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImportFileSelector([List<dynamic>? preloadedFiles]) {
    final l10n = context.l10n;
    final importFiles = preloadedFiles ?? (ref.watch(importFilesProvider).value ?? []);

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
      child: SearchableDropdownField<int>(
        labelText: l10n.selectImportFileDropdownLabel,
        hintText: l10n.selectImportFileDropdownHint,
        value: _selectedImportFileId,
        items: items,
        onChanged: (fileId) {
          if (fileId != null) {
            _fetchQuotations(fileId);
          } else {
            setState(() {
              _selectedImportFileId = null;
              _quotations = [];
            });
          }
        },
      ),
    );
  }

  Widget _buildMetricsBar() {
    final l10n = context.l10n;
    if (_quotations.isEmpty) return const SizedBox.shrink();

    // Find cheapest
    var cheapest = _quotations.first;
    for (var q in _quotations) {
      if ((q['total_cost'] ?? 0) < (cheapest['total_cost'] ?? 0)) cheapest = q;
    }

    // Find fastest
    var fastest = _quotations.first;
    for (var q in _quotations) {
      if ((q['transit_days'] ?? 999) < (fastest['transit_days'] ?? 999)) fastest = q;
    }

    // Find selected
    final selected = _quotations.where((q) => q['quotation_id'] == _selectedQuotationId).toList();
    final selectedName = selected.isNotEmpty ? selected.first['provider_name'] : l10n.notSelectedYet;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _charcoal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: MetricCard(
              data: MetricCardData(
                title: l10n.metricCheapestQuote,
                value: '${cheapest['provider_name']} (${cheapest['total_cost']} ${cheapest['currency_code']})',
                icon: Icons.attach_money,
                color: _emerald,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricCard(
              data: MetricCardData(
                title: l10n.metricFastestQuote,
                value: '${fastest['provider_name']} (${l10n.transitDaysCount(fastest['transit_days'])})',
                icon: Icons.speed,
                color: _cobalt,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricCard(
              data: MetricCardData(
                title: l10n.metricCurrentlySelected,
                value: selectedName,
                icon: Icons.check_circle,
                color: _charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
