import '../../../core/localization/api_error_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../customs_clearance/widgets/customs_ui.dart';

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
  // No fallback rate: taken from Currencies (latest USD commercial rate) or typed by the user.
  final TextEditingController _fxController = TextEditingController();
  bool _fxFromCurrencies = false;
  bool _fxTouched = false;
  bool _isCalculating = false;
  Map<String, dynamic>? _calculationResult;
  String? _calcError;

  // Port Tariffs Registry State
  bool _isLoadingTariffs = false;
  List<dynamic> _portTariffs = [];

  final List<String> _carriers = ['msc', 'maersk', 'cma_cgm', 'hapag_lloyd', 'cosco'];
  final List<String> _ports = ['Alexandria', 'Damietta', 'Sokhna', 'Port Said'];
  final List<String> _containerTypes = ['40HC', '20GP', '40ft', '20ft'];

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

  /// Pre-fills the FX field from the latest USD commercial rate (never overrides user input).
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

  void _copyCompleteStatusDossier() {
    final l10n = context.l10n;
    if (_statusData == null) return;
    final sb = StringBuffer();
    sb.writeln("=== ${l10n.freightDataConnectorDialogTitle} ===");
    sb.writeln("${l10n.freightDataShaqFreightSection}: ${_statusData!['shaq_freight_status']}");
    sb.writeln("${l10n.freightDataLastSyncDate}: ${_statusData!['last_sfx_sync'] ?? l10n.freightDataNeverSynced}");
    sb.writeln("${l10n.freightDataTrackedRoutesCount}: ${_statusData!['total_sfx_routes_tracked']}");
    sb.writeln("---------------------------------------------");
    sb.writeln("${l10n.freightDataShippingRatesSection}: ${_statusData!['shippingrates_status']}");
    sb.writeln("${l10n.freightDataMonthlyQuota}: ${_statusData!['monthly_quota_limit']}");
    sb.writeln("${l10n.freightDataQuotaUsed}: ${_statusData!['monthly_quota_used']}");
    sb.writeln("${l10n.freightDataQuotaRemaining}: ${_statusData!['monthly_quota_remaining']}");
    sb.writeln("${l10n.freightDataTrackedLinesCount}: ${_statusData!['active_shipping_lines_tracked']}");
    sb.writeln("---------------------------------------------");
    sb.writeln("${l10n.freightDataPortDecreesSection}: ${_statusData!['active_port_decrees_count']}");
    sb.writeln("${l10n.freightDataSimPortAuthority}: ${(_statusData!['active_port_authorities'] as List?)?.join(', ') ?? ''}");

    CopyHelper.copy(context, sb.toString());
  }

  void _copyCalculationDossier() {
    final l10n = context.l10n;
    if (_calculationResult == null) return;
    final notice = _calculationResult!['advisory_notice_ar'] ?? '';
    final det = _calculationResult!['detention'] ?? {};
    final port = _calculationResult!['port_storage'] ?? {};

    final sb = StringBuffer();
    sb.writeln("=== ${l10n.freightDataTabSimulator} ===");
    sb.writeln("${l10n.freightDataSimShippingLine}: ${_selectedCarrier.toUpperCase()}");
    sb.writeln("${l10n.freightDataSimPortAuthority}: $_selectedPort");
    sb.writeln("${l10n.freightDataSimContainerType}: $_selectedContainerType");
    sb.writeln("${l10n.freightDataSimDaysInPort}: ${_calculationResult!['days_in_port']} ${l10n.freightDataDayUnit}");
    sb.writeln("---------------------------------------------");
    sb.writeln("${l10n.freightDataCarrierDetentionTitle}: ${det['total_detention_usd']} USD (${det['chargeable_days']} ${l10n.freightDataDayUnit})");
    sb.writeln("${l10n.freightDataPortStorageTitle}: ${port['total_storage_egp']} EGP (${port['tariff_version_applied']})");
    sb.writeln("${l10n.freightDataConsolidatedEgp}: ${_calculationResult!['consolidated_total_egp']} EGP");
    sb.writeln("${l10n.freightDataConsolidatedUsd}: ${_calculationResult!['consolidated_total_usd']} USD");
    sb.writeln("${l10n.freightDataSimFxRate}: ${_calculationResult!['exchange_rate_applied']} (${_calculationResult!['exchange_rate_source']})");
    sb.writeln("---------------------------------------------");
    sb.writeln(notice);

    CopyHelper.copy(context, sb.toString(), customMessage: l10n.freightDataSimulationDossierCopied);
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
                    _buildOverviewTab(l10n),
                    _buildSimulatorTab(l10n),
                    _buildPortTariffsTab(l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: OVERVIEW & QUOTA MONITOR
  // ===========================================================================
  Widget _buildOverviewTab(AppLocalizations l10n) {
    if (_isLoadingStatus) {
      return const CcStateView.loading();
    }
    if (_statusError != null) {
      return CcStateView.error(
        message: _statusError!,
        actionLabel: l10n.freightDataRefreshStatus,
        onAction: _fetchStatus,
      );
    }

    final data = _statusData ?? {};
    final used = (data['monthly_quota_used'] as int?) ?? 0;
    final limit = (data['monthly_quota_limit'] as int?) ?? 25;
    final remaining = (data['monthly_quota_remaining'] as int?) ?? 25;
    final authorities = (data['active_port_authorities'] as List?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                onPressed: _copyCompleteStatusDossier,
                icon: Icons.copy_all_rounded,
                label: l10n.freightDataCopyStatusSummary,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton(
                    onPressed: _fetchStatus,
                    icon: Icons.refresh_rounded,
                    label: l10n.freightDataRefreshStatus,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                  ),
                  AppButton(
                    onPressed: _isSyncingSfx ? null : _syncSfxNow,
                    isLoading: _isSyncingSfx,
                    icon: Icons.sync_rounded,
                    label: l10n.freightDataSyncSfxNow,
                    size: AppButtonSize.small,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Shaq-Freight Card
          _buildCard(
            title: l10n.freightDataShaqFreightSection,
            subtitle: l10n.freightDataShaqFreightDesc,
            accentColor: AppTheme.cobalt,
            icon: Icons.alt_route_rounded,
            child: Row(
              children: [
                _buildMetricBox(
                  label: l10n.freightDataStatusActive,
                  value: data['shaq_freight_status'] ?? '',
                  color: AppTheme.emerald,
                  context: context,
                ),
                const SizedBox(width: 12),
                _buildMetricBox(
                  label: l10n.freightDataTrackedRoutesCount,
                  value: "${data['total_sfx_routes_tracked'] ?? 0}",
                  color: AppTheme.cobalt,
                  context: context,
                ),
                const SizedBox(width: 12),
                _buildMetricBox(
                  label: l10n.freightDataLastSyncDate,
                  value: data['last_sfx_sync'] != null
                      ? data['last_sfx_sync'].toString().split('T').first
                      : l10n.freightDataNeverSynced,
                  color: AppTheme.charcoal,
                  context: context,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. ShippingRates.org Card
          _buildCard(
            title: l10n.freightDataShippingRatesSection,
            subtitle: l10n.freightDataShippingRatesDesc,
            accentColor: AppTheme.emerald,
            icon: Icons.security_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildMetricBox(
                      label: l10n.freightDataMonthlyQuota,
                      value: "$limit",
                      color: AppTheme.charcoal,
                      context: context,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricBox(
                      label: l10n.freightDataQuotaUsed,
                      value: "$used",
                      color: used > 10 ? AppTheme.orange : AppTheme.cobalt,
                      context: context,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricBox(
                      label: l10n.freightDataQuotaRemaining,
                      value: "$remaining",
                      color: AppTheme.emerald,
                      context: context,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricBox(
                      label: l10n.freightDataTrackedLinesCount,
                      value: "${data['active_shipping_lines_tracked'] ?? 0}",
                      color: AppTheme.charcoal,
                      context: context,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.emerald, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.freightDataQuotaGuardAlert,
                          style: const TextStyle(color: AppTheme.emerald, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Port Decrees Card
          _buildCard(
            title: l10n.freightDataPortDecreesSection,
            subtitle: l10n.freightDataPortDecreesDesc,
            accentColor: AppTheme.orange,
            icon: Icons.account_balance_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildMetricBox(
                      label: l10n.freightDataActiveDecreesCount,
                      value: "${data['active_port_decrees_count'] ?? 0}",
                      color: AppTheme.orange,
                      context: context,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: authorities.map((a) {
                          return Chip(
                            label: Text(a, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppTheme.surfaceAltOf(context),
                            side: BorderSide(color: AppTheme.borderOf(context)),
                            avatar: Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textPrimaryOf(context)),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: INSTANT DUAL DEMURRAGE SIMULATOR (< 50ms)
  // ===========================================================================
  Widget _buildSimulatorTab(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Controls (Left / 360px)
          SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchableDropdownField<String>(
                    labelText: l10n.freightDataSimShippingLine,
                    value: _selectedCarrier,
                    items: _carriers.map((c) => SearchableDropdownItem(value: c, label: c.toUpperCase())).toList(),
                    onChanged: (val) => setState(() => _selectedCarrier = val ?? 'msc'),
                  ),
                  const SizedBox(height: 10),
                  SearchableDropdownField<String>(
                    labelText: l10n.freightDataSimPortAuthority,
                    value: _selectedPort,
                    items: _ports.map((p) => SearchableDropdownItem(value: p, label: p)).toList(),
                    onChanged: (val) => setState(() => _selectedPort = val ?? 'Alexandria'),
                  ),
                  const SizedBox(height: 10),
                  SearchableDropdownField<String>(
                    labelText: l10n.freightDataSimContainerType,
                    value: _selectedContainerType,
                    items: _containerTypes.map((t) => SearchableDropdownItem(value: t, label: t)).toList(),
                    onChanged: (val) => setState(() => _selectedContainerType = val ?? '40HC'),
                  ),
                  const SizedBox(height: 10),

                  // Discharge Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dischargeDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _dischargeDate = picked;
                          _daysInPort = DateTime.now().difference(picked).inDays + 1;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.freightDataSimDischargeDate,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: LtrText(
                        CcFormat.date(_dischargeDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Days In Port
                  TextFormField(
                    initialValue: "$_daysInPort",
                    decoration: InputDecoration(
                      labelText: l10n.freightDataSimDaysInPort,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixText: l10n.freightDataDayUnit,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed > 0) {
                        setState(() => _daysInPort = parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Exchange Rate USD/EGP
                  TextFormField(
                    key: const Key('freightDataFxRateField'),
                    controller: _fxController,
                    decoration: InputDecoration(
                      labelText: l10n.freightDataSimFxRate,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      helperText: _fxFromCurrencies ? l10n.demFxRateFromCurrencies : l10n.demFxRateMissingHint,
                      helperMaxLines: 2,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => parsedFxRate(v) == null ? l10n.demFxRateRequired : null,
                    onChanged: (_) => setState(() {
                      _fxTouched = true;
                      _fxFromCurrencies = false;
                    }),
                  ),
                  const SizedBox(height: 14),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AppButton(
                        onPressed: _isCalculating ? null : _runInstantCalculation,
                        isLoading: _isCalculating,
                        icon: Icons.flash_on_rounded,
                        label: l10n.freightDataSimCalculateBtn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Calculation Output Display (Right / Expanded)
          Expanded(
            child: _buildCalculationOutputView(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationOutputView(AppLocalizations l10n) {
    if (_isCalculating) {
      return const CcStateView.loading();
    }
    if (_calcError != null) {
      return CcStateView.error(message: _calcError!);
    }
    if (_calculationResult == null) {
      return CcStateView.empty(
        message: l10n.freightDataSimCalculateBtn,
        icon: Icons.calculate_outlined,
      );
    }

    final res = _calculationResult!;
    final det = res['detention'] as Map<String, dynamic>? ?? {};
    final port = res['port_storage'] as Map<String, dynamic>? ?? {};
    final detSlabs = (det['slab_details'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final portSlabs = (port['slab_details'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with 1-click dossier export
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.freightDataConsolidatedSummary,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryOf(context)),
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AppButton(
                    onPressed: _copyCalculationDossier,
                    icon: Icons.copy_all_rounded,
                    label: l10n.freightDataCopySimulationDossier,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Consolidated Total Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.charcoal,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildConsolidatedCol(
                  label: l10n.freightDataConsolidatedEgp,
                  value: "${res['consolidated_total_egp']} ${l10n.egpCurrency}",
                  color: AppTheme.emerald,
                  context: context,
                ),
                Container(width: 1, height: 40, color: AppTheme.white.withValues(alpha: 0.24)),
                _buildConsolidatedCol(
                  label: l10n.freightDataConsolidatedUsd,
                  value: "${res['consolidated_total_usd']} USD",
                  color: AppTheme.cobalt,
                  context: context,
                ),
                Container(width: 1, height: 40, color: AppTheme.white.withValues(alpha: 0.24)),
                _buildConsolidatedCol(
                  label: l10n.freightDataSimFxRate,
                  value: "${res['exchange_rate_applied']} ${l10n.egpCurrency}",
                  color: AppTheme.white,
                  context: context,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Two Breakdowns Side by Side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carrier Detention (USD)
              Expanded(
                child: _buildBreakdownBox(
                  title: l10n.freightDataCarrierDetentionTitle,
                  totalText: "${det['total_detention_usd']} USD",
                  freeDays: "${det['free_days']} ${l10n.freightDataDayUnit}",
                  chargeableDays: "${det['chargeable_days']} ${l10n.freightDataDayUnit}",
                  appliedRule: det['shipping_line']?.toString().toUpperCase() ?? '',
                  slabs: detSlabs,
                  color: AppTheme.cobalt,
                  l10n: l10n,
                ),
              ),
              const SizedBox(width: 12),

              // Egyptian Port Storage (EGP)
              Expanded(
                child: _buildBreakdownBox(
                  title: l10n.freightDataPortStorageTitle,
                  totalText: "${port['total_storage_egp']} ${l10n.egpCurrency}",
                  freeDays: "${port['free_days']} ${l10n.freightDataDayUnit}",
                  chargeableDays: "${port['chargeable_days']} ${l10n.freightDataDayUnit}",
                  appliedRule: port['tariff_version_applied'] ?? '',
                  slabs: portSlabs,
                  color: AppTheme.orange,
                  l10n: l10n,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownBox({
    required String title,
    required String totalText,
    required String freeDays,
    required String chargeableDays,
    required String appliedRule,
    required List<Map<String, dynamic>> slabs,
    required Color color,
    required AppLocalizations l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14),
                tooltip: l10n.freightDataCopySlabRateTooltip,
                onPressed: () => CopyHelper.copy(context, "$title: $totalText ($appliedRule)"),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 12),
          _kvRow(l10n.freightDataFreeDaysLabel, freeDays, const TextStyle(fontSize: 12),
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          _kvRow(l10n.freightDataChargeableDaysLabel, chargeableDays, const TextStyle(fontSize: 12),
              TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          const SizedBox(height: 4),
          _kvRow(l10n.freightDataAppliedDecree, appliedRule, const TextStyle(fontSize: 12),
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
          const SizedBox(height: 8),
          Text(l10n.freightDataRateSlabsSummary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          ...slabs.map((s) {
            final toDay = s['to_day'] != null ? "${s['to_day']}" : "∞";
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${s['from_day']}-$toDay: ${s['rate']} ${s['currency']}/${l10n.freightDataPerDayUnit} (${s['days_applied']} ${l10n.freightDataDayUnit})",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        "${s['cost']} ${s['currency']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => CopyHelper.copy(context, "${s['cost']} ${s['currency']}"),
                        child: Icon(Icons.copy_rounded, size: 12, color: AppTheme.textMutedOf(context)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 12),
          _kvRow(l10n.freightDataTotalLabel, totalText, const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  Widget _buildConsolidatedCol({
    required String label,
    required String value,
    required Color color,
    required BuildContext context,
  }) {
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            Text(label, style: TextStyle(color: AppTheme.white.withValues(alpha: 0.7), fontSize: 11)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LtrText(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => CopyHelper.copy(context, value),
                  child: Icon(Icons.copy_rounded, color: AppTheme.white.withValues(alpha: 0.55), size: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Label on the start edge, value on the end edge; the label shrinks instead of overflowing.
  Widget _kvRow(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle, maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Flexible(child: Text(value, style: valueStyle, textAlign: TextAlign.end)),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: EGYPTIAN PORT STORAGE TARIFFS REGISTRY
  // ===========================================================================
  Widget _buildPortTariffsTab(AppLocalizations l10n) {
    if (_isLoadingTariffs) {
      return const CcStateView.loading();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${l10n.freightDataTabPortTariffs} (${_portTariffs.length})",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimaryOf(context)),
            ),
            AppButton(
              onPressed: _fetchPortTariffs,
              icon: Icons.refresh_rounded,
              label: l10n.freightDataRefreshStatus,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
            ),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: _portTariffs.isEmpty
              ? CcStateView.empty(message: l10n.freightDataNoDecreesFound, icon: Icons.gavel_rounded)
              : ListView.separated(
                  itemCount: _portTariffs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final t = _portTariffs[idx];
                    final effFrom = t['effective_from'] ?? '';
                    final effTo = t['effective_to'] ?? l10n.freightDataActiveOngoing;
                    final slabs = (t['rate_slabs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: AppTheme.cardDecorationOf(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.gavel_rounded, color: AppTheme.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${t['tariff_version']} — ${t['port_authority']} (${t['container_type']})",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                tooltip: l10n.freightDataCopySlabRateTooltip,
                                onPressed: () => CopyHelper.copy(
                                  context,
                                  "${t['tariff_version']} | ${t['port_authority']} | ${t['container_type']} | $effFrom - $effTo",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${l10n.freightDataEffectiveFromCol}: $effFrom  |  ${l10n.freightDataEffectiveToCol}: $effTo  |  ${l10n.freightDataFreeDaysLabel}: ${t['free_days']} ${l10n.freightDataDayUnit}",
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                          ),
                          if (t['source_document'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              "${l10n.freightDataSourceDocCol}: ${t['source_document']}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.cobalt),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: slabs.map((s) {
                              final toDay = s['to_day'] != null ? "${s['to_day']}" : "∞";
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceAltOf(context),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  border: Border.all(color: AppTheme.borderOf(context)),
                                ),
                                child: LtrText(
                                  "${s['from_day']}-$toDay: ${s['rate_per_day']} ${l10n.egpCurrency}",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // COMMON HELPERS
  // ===========================================================================
  Widget _buildCard({
    required String title,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryOf(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required Color color,
    required BuildContext context,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: LtrText(
                    value,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => CopyHelper.copy(context, value),
                  child: Icon(Icons.copy_rounded, size: 13, color: AppTheme.textMutedOf(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
