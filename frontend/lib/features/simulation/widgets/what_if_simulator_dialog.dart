import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import 'what_if/what_if_exposure_radar_tab.dart';
import 'what_if/what_if_simulation_output_view.dart';
import 'what_if/what_if_simulator_inputs_card.dart';

class WhatIfSimulatorDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const WhatIfSimulatorDialog({
    super.key,
    this.initialImportFileId,
  });

  @override
  ConsumerState<WhatIfSimulatorDialog> createState() => _WhatIfSimulatorDialogState();
}

class _WhatIfSimulatorDialogState extends ConsumerState<WhatIfSimulatorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Dio _dio = ref.read(dioProvider);

  // Controls state
  int? _selectedImportFileId;
  final TextEditingController _invoiceAmountCtrl = TextEditingController();
  final TextEditingController _freightCtrl = TextEditingController();
  String _selectedCurrency = 'USD';
  double _fxRateChangePct = 0.0;
  double _baseRate = 1.0;
  String _shippingRoute = 'RED_SEA';
  int _portDelayDays = 0;
  int _containerCount = 1;
  final double _dutyRatePct = 5.0;

  bool _isSimulating = false;
  Map<String, dynamic>? _simulationResult;

  // FX Exposure state
  bool _isLoadingExposure = false;
  Map<String, dynamic>? _exposureData;

  double _getCurrencyRate(String code) {
    final curAsync = ref.read(currenciesProvider);
    return curAsync.maybeWhen(
      data: (list) {
        final found = list.where((c) => c.currencyCode.toUpperCase() == code.toUpperCase()).toList();
        if (found.isNotEmpty) {
          final rate = found.first.latestCustomsRate ?? found.first.latestCommercialRate;
          if (rate != null && rate > 0) return rate;
        }
        return 1.0;
      },
      orElse: () => 1.0,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedImportFileId = widget.initialImportFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final rate = _getCurrencyRate(_selectedCurrency);
        if (rate > 0) setState(() => _baseRate = rate);
      }
    });
    _fetchExposure();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoiceAmountCtrl.dispose();
    _freightCtrl.dispose();
    super.dispose();
  }

  void _onImportFileSelected(int? fileId) {
    setState(() => _selectedImportFileId = fileId);
    if (fileId == null) return;

    final filesAsync = ref.read(importFilesProvider);
    filesAsync.whenData((files) {
      final matches = files.where((f) => f.importFileId == fileId).toList();
      if (matches.isNotEmpty) {
        final match = matches.first;
        setState(() {
          if (match.estimatedCost > 0) {
            _invoiceAmountCtrl.text = match.estimatedCost.toStringAsFixed(0);
          }
          if (match.estimatedCostCurrency.isNotEmpty) {
            _selectedCurrency = match.estimatedCostCurrency.toUpperCase();
            final rate = _getCurrencyRate(_selectedCurrency);
            if (rate > 0) _baseRate = rate;
          }
        });
      }
    });
  }

  Future<void> _runSimulation() async {
    setState(() => _isSimulating = true);
    try {
      final invAmount = double.tryParse(_invoiceAmountCtrl.text.trim()) ?? 0.0;
      final freight = double.tryParse(_freightCtrl.text.trim()) ?? 0.0;

      final payload = {
        'import_file_id': _selectedImportFileId,
        'invoice_amount': invAmount,
        'currency': _selectedCurrency,
        'base_exchange_rate': _baseRate,
        'exchange_rate_change_pct': _fxRateChangePct,
        'freight_fcy': freight,
        'insurance_fcy': 150.0,
        'shipping_route': _shippingRoute,
        'port_storage_delay_days': _portDelayDays,
        'container_count': _containerCount,
        'duty_rate_pct': _dutyRatePct,
        'vat_rate_pct': 14.0,
        'acid_issuance_date': DateTime.now().subtract(const Duration(days: 90)).toIso8601String().substring(0, 10),
        'current_eta': DateTime.now().add(const Duration(days: 20)).toIso8601String().substring(0, 10),
      };

      final res = await _dio.post(
        '${ApiConstants.simulation}/what-if',
        data: payload,
      );

      if (res.statusCode == 200) {
        setState(() => _simulationResult = res.data as Map<String, dynamic>);
      }
    } catch (e) {
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'فشل تشغيل المحاكاة: $e' : 'Simulation failed: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  Future<void> _fetchExposure() async {
    setState(() => _isLoadingExposure = true);
    try {
      final res = await _dio.get('${ApiConstants.simulation}/fx-exposure');
      if (res.statusCode == 200) {
        setState(() => _exposureData = res.data as Map<String, dynamic>);
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      if (mounted) setState(() => _isLoadingExposure = false);
    }
  }

  Future<void> _saveCurrentScenario() async {
    if (_simulationResult == null) return;
    try {
      final isAr = mounted ? (Localizations.localeOf(context).languageCode == 'ar') : true;
      final invAmount = double.tryParse(_invoiceAmountCtrl.text.trim()) ?? 0.0;
      final routeName = _shippingRoute == "CAPE_OF_GOOD_HOPE"
          ? (isAr ? "رأس الرجاء الصالح" : "Cape of Good Hope")
          : (isAr ? "البحر الأحمر" : "Red Sea");
      final scenarioTitle = isAr ? 'سيناريو محاكاة' : 'Simulation Scenario';
      final payload = {
        'scenario_name': '$scenarioTitle $_selectedCurrency (+${_fxRateChangePct.toStringAsFixed(0)}%) - $routeName',
        'import_file_id': _selectedImportFileId,
        'simulation_request': {
          'invoice_amount': invAmount,
          'currency': _selectedCurrency,
          'base_exchange_rate': _baseRate,
          'exchange_rate_change_pct': _fxRateChangePct,
          'shipping_route': _shippingRoute,
          'port_storage_delay_days': _portDelayDays,
          'container_count': _containerCount,
        },
        'simulation_result': _simulationResult,
      };

      final res = await _dio.post(
        '${ApiConstants.simulation}/saved-scenarios',
        data: payload,
      );

      if (res.statusCode == 201 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr
                  ? '✅ تم حفظ سيناريو المحاكاة بنجاح في سجل القرارات الاستراتيجية.'
                  : '✅ Simulation scenario saved successfully in strategic decisions log.',
            ),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr ? 'خطأ في حفظ السيناريو: $e' : 'Error saving scenario: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
  }

  void _copyScenarioSummary() {
    if (_simulationResult == null) return;
    final l10n = context.l10n;
    final base = _simulationResult!['baseline_summary'] as Map<String, dynamic>;
    final sim = _simulationResult!['simulated_summary'] as Map<String, dynamic>;
    final varMap = _simulationResult!['variances'] as Map<String, dynamic>;
    final dem = _simulationResult!['demurrage_and_storage'] as Map<String, dynamic>;
    final riskLevel = _simulationResult!['risk_level'] as String? ?? 'LOW';

    final buffer = StringBuffer();
    buffer.writeln('${l10n.whatIfDialogTitle} - ${l10n.whatIfRiskLevel} $riskLevel');
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('${l10n.whatIfInvoiceValue}: ${_invoiceAmountCtrl.text} $_selectedCurrency');
    buffer.writeln('${l10n.whatIfBaseRate} ${_baseRate.toStringAsFixed(2)} ${l10n.egpCurrency}');
    buffer.writeln(
        '${l10n.whatIfSimulatedRate} ${(_baseRate * (1 + _fxRateChangePct / 100)).toStringAsFixed(2)} ${l10n.egpCurrency} (${_fxRateChangePct > 0 ? "+" : ""}${_fxRateChangePct.toStringAsFixed(0)}%)');
    buffer.writeln(
        '${l10n.whatIfBaselineLandedCost} ${(base['total_landed_cost_egp'] as num).toStringAsFixed(2)} ${l10n.egpCurrency}');
    buffer.writeln(
        '${l10n.whatIfSimulatedLandedCost} ${(sim['total_landed_cost_egp'] as num).toStringAsFixed(2)} ${l10n.egpCurrency} (+${(varMap['landed_cost_variance_pct'] as num).toStringAsFixed(1)}%)');
    buffer.writeln(
        '${l10n.whatIfCustomsTaxVariance} +${((varMap['customs_duty_variance_egp'] as num) + (varMap['vat_variance_egp'] as num)).toStringAsFixed(2)} ${l10n.egpCurrency}');
    buffer.writeln('${l10n.whatIfShippingDemurrage} \$${(dem['demurrage_cost_usd'] as num).toStringAsFixed(0)}');
    buffer.writeln(
        '${l10n.whatIfPortStorage} ${(dem['port_storage_cost_egp'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}');

    CopyHelper.copy(context, buffer.toString(), customMessage: l10n.whatIfScenarioCopied);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SelectionArea(
        child: Container(
          width: 1160,
          height: 780,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTabBar(),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WhatIfSimulatorInputsCard(
                          selectedImportFileId: _selectedImportFileId,
                          onImportFileSelected: _onImportFileSelected,
                          invoiceAmountCtrl: _invoiceAmountCtrl,
                          freightCtrl: _freightCtrl,
                          selectedCurrency: _selectedCurrency,
                          onCurrencyChanged: (val) {
                            setState(() {
                              _selectedCurrency = val;
                              final rate = _getCurrencyRate(val);
                              if (rate > 0) _baseRate = rate;
                            });
                          },
                          baseRate: _baseRate,
                          fxRateChangePct: _fxRateChangePct,
                          onFxRateChanged: (val) => setState(() => _fxRateChangePct = val),
                          shippingRoute: _shippingRoute,
                          onRouteChanged: (val) => setState(() => _shippingRoute = val),
                          portDelayDays: _portDelayDays,
                          onPortDelayChanged: (val) => setState(() => _portDelayDays = val),
                          containerCount: _containerCount,
                          onContainerCountChanged: (val) => setState(() => _containerCount = val),
                          isSimulating: _isSimulating,
                          onRunSimulation: _runSimulation,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: WhatIfSimulationOutputView(
                            simulationResult: _simulationResult,
                            onCopySummary: _copyScenarioSummary,
                            onSaveScenario: _saveCurrentScenario,
                          ),
                        ),
                      ],
                    ),
                    WhatIfExposureRadarTab(
                      exposureData: _exposureData,
                      isLoadingExposure: _isLoadingExposure,
                      onFetchExposure: _fetchExposure,
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

  Widget _buildHeader() {
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.cobaltLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.analytics_outlined, color: AppTheme.cobalt, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.whatIfDialogTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                l10n.whatIfDialogSubtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l10n.close,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.charcoal,
        indicator: BoxDecoration(
          color: AppTheme.cobalt,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: [
          Tab(
            icon: const Icon(Icons.tune),
            text: l10n.whatIfSimulatorTab,
          ),
          Tab(
            icon: const Icon(Icons.radar),
            text: l10n.whatIfExposureTab,
          ),
        ],
      ),
    );
  }
}
