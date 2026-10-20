import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../currencies/providers/currencies_provider.dart';

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
  String _shippingRoute = 'RED_SEA'; // RED_SEA or CAPE_OF_GOOD_HOPE
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
    buffer.writeln('${l10n.whatIfSimulatedRate} ${(_baseRate * (1 + _fxRateChangePct / 100)).toStringAsFixed(2)} ${l10n.egpCurrency} (${_fxRateChangePct > 0 ? "+" : ""}${_fxRateChangePct.toStringAsFixed(0)}%)');
    buffer.writeln('${l10n.whatIfBaselineLandedCost} ${(base['total_landed_cost_egp'] as num).toStringAsFixed(2)} ${l10n.egpCurrency}');
    buffer.writeln('${l10n.whatIfSimulatedLandedCost} ${(sim['total_landed_cost_egp'] as num).toStringAsFixed(2)} ${l10n.egpCurrency} (+${(varMap['landed_cost_variance_pct'] as num).toStringAsFixed(1)}%)');
    buffer.writeln('${l10n.whatIfCustomsTaxVariance} +${((varMap['customs_duty_variance_egp'] as num) + (varMap['vat_variance_egp'] as num)).toStringAsFixed(2)} ${l10n.egpCurrency}');
    buffer.writeln('${l10n.whatIfShippingDemurrage} \$${(dem['demurrage_cost_usd'] as num).toStringAsFixed(0)}');
    buffer.writeln('${l10n.whatIfPortStorage} ${(dem['port_storage_cost_egp'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}');

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
                    _buildSimulatorTab(),
                    _buildExposureRadarTab(),
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

  Widget _buildSimulatorTab() {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Parameters
        SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.whatIfShipmentAndCurrencyInputs, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    _buildImportFileSelector(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _invoiceAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.whatIfInvoiceValue,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCurrency,
                            decoration: InputDecoration(
                              labelText: l10n.currency,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'USD', child: Text('USD')),
                              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                              DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                              DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCurrency = val;
                                  final rate = _getCurrencyRate(val);
                                  if (rate > 0) _baseRate = rate;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _freightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '${l10n.whatIfFreightCost} ($_selectedCurrency)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(l10n.whatIfFxShockSimulation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('${l10n.whatIfBaseRate} ${_baseRate.toStringAsFixed(2)} ${l10n.egpCurrency}', style: const TextStyle(fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _fxRateChangePct > 0 ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _fxRateChangePct > 0 ? AppTheme.crimson : AppTheme.emerald),
                          ),
                          child: Text(
                            '${l10n.whatIfSimulatedRate} ${(_baseRate * (1 + _fxRateChangePct / 100)).toStringAsFixed(2)} ${l10n.egpCurrency} (${_fxRateChangePct > 0 ? "+" : ""}${_fxRateChangePct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _fxRateChangePct > 0 ? AppTheme.crimson : AppTheme.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _fxRateChangePct,
                      min: -10.0,
                      max: 60.0,
                      divisions: 14,
                      activeColor: _fxRateChangePct > 0 ? AppTheme.crimson : AppTheme.cobalt,
                      label: '${_fxRateChangePct.toStringAsFixed(0)}%',
                      onChanged: (val) => setState(() => _fxRateChangePct = val),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(l10n.whatIfShippingRouteRisk, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _shippingRoute,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'RED_SEA',
                          child: Text(l10n.whatIfRouteRedSea, overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'CAPE_OF_GOOD_HOPE',
                          child: Text(l10n.whatIfRouteCape, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (val) => setState(() => _shippingRoute = val ?? 'RED_SEA'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${l10n.whatIfPortDelay} $_portDelayDays ${l10n.whatIfDaysUnit}', style: const TextStyle(fontSize: 12)),
                              Slider(
                                value: _portDelayDays.toDouble(),
                                min: 0.0,
                                max: 30.0,
                                divisions: 30,
                                label: '$_portDelayDays ${l10n.whatIfDaysUnit}',
                                onChanged: (val) => setState(() => _portDelayDays = val.toInt()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _containerCount,
                            decoration: InputDecoration(
                              labelText: l10n.whatIfContainersCount,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [1, 2, 3, 4, 5, 10].map((c) => DropdownMenuItem(value: c, child: Text('$c ${l10n.whatIfContainerUnit}'))).toList(),
                            onChanged: (val) => setState(() => _containerCount = val ?? 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSimulating ? null : _runSimulation,
                        icon: _isSimulating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.play_arrow),
                        label: Text(l10n.whatIfRunSimulationNow, style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Right Column: Output Matrix
        Expanded(
          child: _simulationResult == null
              ? _buildPlaceholderGuide()
              : _buildSimulationOutput(),
        ),
      ],
    );
  }

  Widget _buildImportFileSelector() {
    final l10n = context.l10n;
    final filesAsync = ref.watch(importFilesProvider);
    return filesAsync.when(
      data: (files) {
        return SearchableDropdownField<int>(
          labelText: l10n.whatIfSelectShipmentPlaceholder,
          hintText: l10n.whatIfSearchShipmentHint,
          items: files
              .map((f) => SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: '${f.primaryNameWithCode} - ${f.companyName} (${f.estimatedCost} ${f.estimatedCostCurrency})',
                  ))
              .toList(),
          value: _selectedImportFileId,
          onChanged: _onImportFileSelected,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPlaceholderGuide() {
    final l10n = context.l10n;
    return Center(
      child: Card(
        elevation: 0,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.query_stats, size: 56, color: AppTheme.cobalt.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text(
                l10n.whatIfPlaceholderTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 480,
                child: Text(
                  l10n.whatIfPlaceholderDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationOutput() {
    final l10n = context.l10n;
    final res = _simulationResult!;
    final base = res['baseline_summary'] as Map<String, dynamic>;
    final sim = res['simulated_summary'] as Map<String, dynamic>;
    final varMap = res['variances'] as Map<String, dynamic>;
    final acid = res['acid_risk_analysis'] as Map<String, dynamic>;
    final dem = res['demurrage_and_storage'] as Map<String, dynamic>;
    final recommendations = (res['hedging_recommendations'] as List<dynamic>?) ?? [];
    final riskLevel = res['risk_level'] as String? ?? 'LOW';

    Color riskColor = AppTheme.emerald;
    if (riskLevel == 'CRITICAL') riskColor = AppTheme.crimson;
    if (riskLevel == 'HIGH') riskColor = AppTheme.orange;
    if (riskLevel == 'MEDIUM') riskColor = Colors.amber.shade700;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar: Risk Level & Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: riskColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: riskColor, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.whatIfRiskLevel} $riskLevel',
                      style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _copyScenarioSummary,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.whatIfCopyScenarioSummary),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saveCurrentScenario,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.whatIfSaveScenario),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Primary Metric: Landed Cost Variance
          Card(
            elevation: 0,
            color: AppTheme.cobaltLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.cobaltBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfBaselineLandedCost, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        CopyableText(
                          '${(base['total_landed_cost_egp'] as num).toStringAsFixed(2)} ${l10n.egpCurrency}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfSimulatedLandedCost, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        CopyableText(
                          '${(sim['total_landed_cost_egp'] as num).toStringAsFixed(2)} ${l10n.egpCurrency}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: riskColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        CopyableText(
                          '+${(varMap['landed_cost_variance_pct'] as num).toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        CopyableText(
                          '+${(varMap['landed_cost_variance_egp'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary Metrics: Taxes & Demurrage
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfCustomsTaxVariance, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        CopyableText(
                          '+${((varMap['customs_duty_variance_egp'] as num) + (varMap['vat_variance_egp'] as num)).toStringAsFixed(2)} ${l10n.egpCurrency}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfShippingDemurrage, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        CopyableText(
                          '\$${(dem['demurrage_cost_usd'] as num).toStringAsFixed(0)} (${(dem['extra_demurrage_days'] as num)} ${l10n.whatIfDaysUnit})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.crimson),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.whatIfPortStorage, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        CopyableText(
                          '${(dem['port_storage_cost_egp'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.orange),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ACID Regulatory Expiry Card
          if (acid['status'] != 'NOT_APPLICABLE') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: acid['status'] == 'EXPIRED_RISK' ? AppTheme.crimsonLight : (acid['status'] == 'CRITICAL_WINDOW' ? AppTheme.orangeLight : Colors.green.shade50),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: acid['status'] == 'EXPIRED_RISK' ? AppTheme.crimson : (acid['status'] == 'CRITICAL_WINDOW' ? AppTheme.orange : AppTheme.emerald),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    acid['status'] == 'EXPIRED_RISK' ? Icons.dangerous : (acid['status'] == 'CRITICAL_WINDOW' ? Icons.alarm : Icons.verified),
                    color: acid['status'] == 'EXPIRED_RISK' ? AppTheme.crimson : (acid['status'] == 'CRITICAL_WINDOW' ? AppTheme.orange : AppTheme.emerald),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.whatIfAcidExpiryCheck,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: acid['status'] == 'EXPIRED_RISK' ? AppTheme.crimson : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (Localizations.localeOf(context).languageCode == 'en' ? acid['message_en'] : acid['message_ar']) as String? ?? (acid['message_ar'] as String? ?? ''),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Strategic Advice & Hedging Actions
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.cobalt),
                      const SizedBox(width: 8),
                      Text(l10n.whatIfStrategicRecommendations, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...recommendations.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 16)),
                          Expanded(child: Text(rec.toString(), style: const TextStyle(fontSize: 12, height: 1.4))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExposureRadarTab() {
    final l10n = context.l10n;
    if (_isLoadingExposure) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_exposureData == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _fetchExposure,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.whatIfRefreshExposure),
        ),
      );
    }

    final data = _exposureData!;
    final items = (data['items'] as List<dynamic>?) ?? [];
    final advice = (data['strategic_advice'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exposure Metric Cards
          Row(
            children: [
              _buildMetricCard(
                title: l10n.whatIfTotalUsdObligations,
                value: '\$${(data['total_open_usd'] as num).toStringAsFixed(2)}',
                color: AppTheme.cobalt,
                icon: Icons.attach_money,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: l10n.whatIfTotalEurObligations,
                value: '€${(data['total_open_eur'] as num).toStringAsFixed(2)}',
                color: AppTheme.orange,
                icon: Icons.euro,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: l10n.whatIfCurrentEgpValue,
                value: '${(data['total_open_egp_baseline'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}',
                color: AppTheme.charcoal,
                icon: Icons.account_balance,
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                title: l10n.whatIfValueAtRisk10,
                value: '+${(data['var_at_risk_10_pct'] as num).toStringAsFixed(0)} ${l10n.egpCurrency}',
                color: AppTheme.crimson,
                icon: Icons.trending_up,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Strategic advice
          Card(
            elevation: 0,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.amber.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.whatIfTreasuryGuidance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...advice.map((adv) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $adv', style: const TextStyle(fontSize: 12)),
                      )),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Table of open files
          Text(l10n.whatIfOpenShipmentsExposed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columns: [
                DataColumn(label: Text(l10n.whatIfColShipmentCode)),
                DataColumn(label: Text(l10n.whatIfColSupplier)),
                DataColumn(label: Text(l10n.whatIfColCurrency)),
                DataColumn(label: Text(l10n.whatIfColPendingAmount)),
                DataColumn(label: Text(l10n.whatIfColCurrentEgp)),
                DataColumn(label: Text(l10n.whatIfColScenarioPlus10)),
                DataColumn(label: Text(l10n.whatIfColScenarioPlus25)),
              ],
              rows: items.map((item) {
                final rowTsv = [
                  item['import_file_code'] ?? '',
                  item['supplier_name'] ?? '',
                  item['currency'] ?? '',
                  (item['open_exposure_fcy'] as num).toStringAsFixed(2),
                  (item['open_exposure_egp'] as num).toStringAsFixed(0),
                  (item['simulated_exposure_egp_at_plus_10_pct'] as num).toStringAsFixed(0),
                  (item['simulated_exposure_egp_at_plus_25_pct'] as num).toStringAsFixed(0),
                ].join('\t');

                return DataRow(cells: [
                  DataCell(CopyableTableCell(
                    value: item['import_file_code'] ?? '',
                    rowSummary: rowTsv,
                    child: Text(item['import_file_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  )),
                  DataCell(CopyableTableCell(
                    value: item['supplier_name'] ?? '',
                    rowSummary: rowTsv,
                    child: Text(item['supplier_name'] ?? '', style: const TextStyle(fontSize: 12)),
                  )),
                  DataCell(CopyableTableCell(
                    value: item['currency'] ?? '',
                    rowSummary: rowTsv,
                    child: Text(item['currency'] ?? '', style: const TextStyle(fontSize: 12)),
                  )),
                  DataCell(CopyableTableCell(
                    value: (item['open_exposure_fcy'] as num).toStringAsFixed(2),
                    rowSummary: rowTsv,
                    child: Text((item['open_exposure_fcy'] as num).toStringAsFixed(2), style: const TextStyle(fontSize: 12)),
                  )),
                  DataCell(CopyableTableCell(
                    value: (item['open_exposure_egp'] as num).toStringAsFixed(0),
                    rowSummary: rowTsv,
                    child: Text((item['open_exposure_egp'] as num).toStringAsFixed(0), style: const TextStyle(fontSize: 12)),
                  )),
                  DataCell(CopyableTableCell(
                    value: (item['simulated_exposure_egp_at_plus_10_pct'] as num).toStringAsFixed(0),
                    rowSummary: rowTsv,
                    child: Text(
                      (item['simulated_exposure_egp_at_plus_10_pct'] as num).toStringAsFixed(0),
                      style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )),
                  DataCell(CopyableTableCell(
                    value: (item['simulated_exposure_egp_at_plus_25_pct'] as num).toStringAsFixed(0),
                    rowSummary: rowTsv,
                    child: Text(
                      (item['simulated_exposure_egp_at_plus_25_pct'] as num).toStringAsFixed(0),
                      style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Icon(icon, size: 20, color: color),
                ],
              ),
              const SizedBox(height: 8),
              CopyableText(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
