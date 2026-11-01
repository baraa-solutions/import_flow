import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import 'freight_data_monitor/freight_monitor_overview_tab.dart';
import 'freight_data_monitor/freight_monitor_port_tariffs_tab.dart';
import 'freight_data_monitor/freight_monitor_simulator_tab.dart';

/// Latest commercial USD rate recorded in Currencies, or null (the caller must ask the user).
double? usdCommercialRate(List<CurrencyModel> currencies) {
  for (final c in currencies) {
    if (c.currencyCode.toUpperCase() == 'USD') {
      final r = c.latestCommercialRate;
      return (r != null && r > 0) ? r : null;
    }
  }
  return null;
}

/// Positive rate typed by the user, or null when empty / invalid / non-positive.
double? parsedFxRate(String? text) {
  final v = double.tryParse((text ?? '').trim());
  return (v != null && v > 0) ? v : null;
}

void showFreightDataMonitorDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const FreightDataMonitorDialog(),
  );
}

class FreightDataMonitorDialog extends ConsumerStatefulWidget {
  const FreightDataMonitorDialog({super.key});

  @override
  ConsumerState<FreightDataMonitorDialog> createState() => _FreightDataMonitorDialogState();
}

class _FreightDataMonitorDialogState extends ConsumerState<FreightDataMonitorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Status & Quota State
  bool _isLoadingStatus = true;
  String? _statusError;
  Map<String, dynamic>? _statusData;
  bool _isSyncingSfx = false;

  // Simulator State
  final _formKey = GlobalKey<FormState>();
  String _selectedCarrier = 'msc';
  String _selectedPort = 'Alexandria';
  String _selectedContainerType = '40HC';
  DateTime _dischargeDate = DateTime.now().subtract(const Duration(days: 18));
  int _daysInPort = 18;
  final TextEditingController _fxController = TextEditingController();
  bool _fxFromCurrencies = false;
  bool _fxTouched = false;
  bool _isCalculating = false;
  Map<String, dynamic>? _calculationResult;
  String? _calcError;

  // Port Tariffs Registry State
  bool _isLoadingTariffs = false;
  List<dynamic> _portTariffs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStatus();
    _fetchPortTariffs();
    ref.listenManual<AsyncValue<List<CurrencyModel>>>(
      currenciesProvider,
      (_, next) => _applyCurrencyRate(next.asData?.value),
      fireImmediately: true,
    );
  }

  void _applyCurrencyRate(List<CurrencyModel>? currencies) {
    if (_fxTouched || currencies == null) return;
    final rate = usdCommercialRate(currencies);
    if (rate == null) return;
    setState(() {
      _fxController.text = rate.toString();
      _fxFromCurrencies = true;
    });
  }

  @override
  void dispose() {
    _fxController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoadingStatus = true;
      _statusError = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/freight-data/status');
      if (mounted) {
        setState(() {
          _statusData = res.data is Map<String, dynamic> ? res.data : null;
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusError = ApiErrorText.of(context.l10n, e);
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _syncSfxNow() async {
    final l10n = context.l10n;
    setState(() => _isSyncingSfx = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/freight-data/sync-shaq-freight');
      await _fetchStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l10n.freightDataSyncSfxSuccess, severity: AppSeverity.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, ApiErrorText.of(l10n, e), severity: AppSeverity.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingSfx = false);
    }
  }

  Future<void> _fetchPortTariffs() async {
    setState(() => _isLoadingTariffs = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/freight-data/port-tariffs');
      if (mounted) {
        setState(() {
          _portTariffs = res.data is List ? res.data : [];
          _isLoadingTariffs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTariffs = false);
    }
  }

  Future<void> _runInstantCalculation() async {
    if (!_formKey.currentState!.validate()) return;
    if (parsedFxRate(_fxController.text) == null) return;
    setState(() {
      _isCalculating = true;
      _calcError = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final dischargeStr = "${_dischargeDate.year.toString().padLeft(4, '0')}-${_dischargeDate.month.toString().padLeft(2, '0')}-${_dischargeDate.day.toString().padLeft(2, '0')}";
      final payload = {
        'shipping_line': _selectedCarrier,
        'port_authority': _selectedPort,
        'container_type': _selectedContainerType,
        'discharge_date': dischargeStr,
        'days_in_port': _daysInPort,
        'exchange_rate_usd_egp': parsedFxRate(_fxController.text),
      };
      final res = await dio.post('/freight-data/calculate-dual-demurrage', data: payload);
      if (mounted) {
        setState(() {
          _calculationResult = res.data is Map<String, dynamic> ? res.data : null;
          _isCalculating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _calcError = ApiErrorText.of(context.l10n, e);
          _isCalculating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screen = MediaQuery.of(context).size;

    return SelectionArea(
      child: Dialog(
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: screen.width > 1000 ? 960 : screen.width * 0.95,
          height: screen.height > 760 ? 700 : screen.height * 0.9,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobaltLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: AppTheme.cobalt, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.freightDataConnectorDialogTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.freightDataConnectorDialogSubtitle,
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // TabBar Navigation
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAltOf(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppTheme.surfaceOf(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: AppTheme.textPrimaryOf(context),
                  unselectedLabelColor: AppTheme.textSecondaryOf(context),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.speed_rounded, size: 18),
                      text: l10n.freightDataTabOverview,
                    ),
                    Tab(
                      icon: const Icon(Icons.calculate_outlined, size: 18),
                      text: l10n.freightDataTabSimulator,
                    ),
                    Tab(
                      icon: const Icon(Icons.account_balance_outlined, size: 18),
                      text: l10n.freightDataTabPortTariffs,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    FreightMonitorOverviewTab(
                      statusData: _statusData,
                      isLoading: _isLoadingStatus,
                      error: _statusError,
                      isSyncingSfx: _isSyncingSfx,
                      onFetchStatus: _fetchStatus,
                      onSyncSfxNow: _syncSfxNow,
                    ),
                    FreightMonitorSimulatorTab(
                      formKey: _formKey,
                      selectedCarrier: _selectedCarrier,
                      onCarrierChanged: (v) => setState(() => _selectedCarrier = v ?? 'msc'),
                      selectedPort: _selectedPort,
                      onPortChanged: (v) => setState(() => _selectedPort = v ?? 'Alexandria'),
                      selectedContainerType: _selectedContainerType,
                      onContainerTypeChanged: (v) => setState(() => _selectedContainerType = v ?? '40HC'),
                      dischargeDate: _dischargeDate,
                      onDischargeDateChanged: (picked) {
                        setState(() {
                          _dischargeDate = picked;
                          _daysInPort = DateTime.now().difference(picked).inDays + 1;
                        });
                      },
                      daysInPort: _daysInPort,
                      onDaysInPortChanged: (v) => setState(() => _daysInPort = v),
                      fxController: _fxController,
                      fxFromCurrencies: _fxFromCurrencies,
                      onFxChanged: (_) {
                        setState(() {
                          _fxTouched = true;
                          _fxFromCurrencies = false;
                        });
                      },
                      parsedFxRate: parsedFxRate,
                      isCalculating: _isCalculating,
                      onCalculate: _runInstantCalculation,
                      calculationResult: _calculationResult,
                      calcError: _calcError,
                    ),
                    FreightMonitorPortTariffsTab(
                      portTariffs: _portTariffs,
                      isLoadingTariffs: _isLoadingTariffs,
                      onFetchPortTariffs: _fetchPortTariffs,
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
