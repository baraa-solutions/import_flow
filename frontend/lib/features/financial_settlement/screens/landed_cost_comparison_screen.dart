import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../widgets/landed_cost/landed_cost_breakdown_tables.dart';
import '../widgets/landed_cost/landed_cost_export_toolbar.dart';
import '../widgets/landed_cost/landed_cost_file_selector.dart';
import '../widgets/landed_cost/landed_cost_incoterm_rule_card.dart';
import '../widgets/landed_cost/landed_cost_metric_cards.dart';
import '../widgets/settlement_ui.dart';

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
  double? _estimatedLandedCostEgp;
  double? _backendLandedVariancePct;
  Map<String, dynamic>? _settlementRecord;
  CancelToken? _cancelToken;
  String _selectedIncoterm = 'FOB';

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
          _backendLandedVariancePct = (importFileRes.data['actual_landed_cost_variance_pct'] as num?)?.toDouble();
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
        _estimatedLandedCostEgp = null;
        _backendLandedVariancePct = null;
        _selectedIncoterm = 'FOB';
      }

      // Fetch live calculation if available
      try {
        final calcRes = await dio.post(
          '${ApiConstants.baseUrl}/financial-settlement/calculate-actual-landed-cost/$fileId',
          cancelToken: _cancelToken,
        );
        if (calcRes.data != null) {
          if (calcRes.data['landed_variance_pct'] != null) {
            _backendLandedVariancePct = (calcRes.data['landed_variance_pct'] as num?)?.toDouble();
          }
          if (calcRes.data['estimated_landed_cost_egp'] != null) {
            _estimatedLandedCostEgp = (calcRes.data['estimated_landed_cost_egp'] as num?)?.toDouble();
          }
        }
      } catch (_) {
        // Safe to ignore if settlement calculation fails
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

    final double? fobVariance = (_settlementRecord?['fob_variance_percent'] as num?)?.toDouble();
    final double? landedVariance = _backendLandedVariancePct ?? (_settlementRecord?['variance_percent'] as num?)?.toDouble();
    final estDisplay = _estimatedLandedCostEgp ?? (_estimatedCost > 0 ? _estimatedCost : null);

    final expenses = (_settlementRecord?['expense_invoices'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final items = (_settlementRecord?['item_landed_costs'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LandedCostMetricStrip(
            totalExpenses: totalExpensesEgp,
            totalLanded: totalLandedCostEgp,
            landedVariance: landedVariance,
            estimatedCostDisplay: estDisplay,
          ),
          const SizedBox(height: 16),
          LandedCostExportToolbar(
            fileCode: _selectedImportFileCode.isNotEmpty
                ? _selectedImportFileCode
                : (_selectedImportFileId != null ? 'IMP-#$_selectedImportFileId' : 'SHIPMENT'),
            incoterm: _selectedIncoterm,
            estimatedCost: _estimatedCost,
            settlementRecord: _settlementRecord,
            landedVariance: landedVariance,
            estimatedLandedCostEgp: _estimatedLandedCostEgp,
          ),
          const SizedBox(height: 16),
          LandedCostIncotermRuleCard(incoterm: _selectedIncoterm),
          const SizedBox(height: 16),
          LandedCostSummaryCards(
            totalFob: totalFobEgp,
            totalExpenses: totalExpensesEgp,
            totalLanded: totalLandedCostEgp,
            fobVariance: fobVariance,
            landedVariance: landedVariance,
            estimatedCostDisplay: estDisplay,
          ),
          const SizedBox(height: 24),
          SettlementSectionHeader(
            title: l10n.expenseBreakdownHeader,
            icon: Icons.receipt_long_outlined,
            color: AppTheme.cobalt,
          ),
          const SizedBox(height: 12),
          LandedCostExpenseTable(expenses: expenses),
          const SizedBox(height: 24),
          SettlementSectionHeader(
            title: l10n.itemLandedCostHeader,
            icon: Icons.inventory_2_outlined,
            color: AppTheme.emerald,
          ),
          const SizedBox(height: 12),
          LandedCostItemTable(items: items),
          const SizedBox(height: 24),
          LandedCostSummaryBanner(landedVariance: landedVariance),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fileDisplayCode = _selectedImportFileCode.isNotEmpty
        ? _selectedImportFileCode
        : (_selectedImportFileId != null ? 'IMP-#$_selectedImportFileId' : '');

    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final bodyContent = SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 0),
            child: LandedCostFileSelector(
              importFiles: importFiles,
              selectedImportFileId: _selectedImportFileId,
              selectedImportFileCode: _selectedImportFileCode,
              onFileSelected: (fileId) {
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
      appBar: PageHeader(
        icon: Icons.analytics_outlined,
        title: fileDisplayCode.isNotEmpty ? l10n.landedCostComparisonTitle(fileDisplayCode) : l10n.landedCostComparison,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 10),
        ],
      ),
      body: bodyContent,
    );
  }
}
