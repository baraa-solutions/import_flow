import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/adaptive_tab_scaffold.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';
import '../widgets/demurrage_form_dialogs.dart';
import '../widgets/demurrage_simulation_panel.dart';
import '../widgets/demurrage_tracking_card.dart';
import '../widgets/dual_clock_radar_dialog.dart';
import '../widgets/empty_container_return_dialog.dart';
import '../widgets/free_days_agreement_dialog.dart';
import '../widgets/freight_data_monitor_dialog.dart';

class DemurrageDetentionScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const DemurrageDetentionScreen({super.key, this.initialImportFileId});

  @override
  ConsumerState<DemurrageDetentionScreen> createState() => _DemurrageDetentionScreenState();
}

class _DemurrageDetentionScreenState extends ConsumerState<DemurrageDetentionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';

  // Simulator Controllers
  final _simFormKey = GlobalKey<FormState>();
  String _simCarrier = 'MSC';
  String _simContainerType = '40ft High Cube';
  int _simContainersCount = 1;
  // null = not set by the user: omitted so the backend's configured defaults apply.
  int? _simDemFreeDays;
  int? _simDetFreeDays;
  // No default FX: the user must enter the rate (no hard-coded 50).
  double? _simExchangeRate;
  DateTime _simDischargeDate = DateTime.now().subtract(const Duration(days: 16));
  DateTime? _simGateOutDate;
  DateTime? _simEmptyReturnDate;
  bool _isSimulating = false;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(demurrageProvider).isLoading) {
        if (widget.initialImportFileId != null) {
          ref.read(demurrageProvider.notifier).fetchTrackings(importFileId: widget.initialImportFileId);
          ref.read(demurrageProvider.notifier).fetchFreeDaysAgreement(widget.initialImportFileId!);
        } else {
          ref.read(demurrageProvider.notifier).loadInitialData();
        }
      }
      _runQuickSimulation();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    ref.invalidate(demurrageProvider);
    ref.read(demurrageProvider.notifier).loadInitialData();
  }

  void _runQuickSimulation() {
    final fx = _simExchangeRate;
    if (fx == null || fx <= 0) {
      if (_isSimulating) setState(() => _isSimulating = false);
      return;
    }
    setState(() => _isSimulating = true);
    final payload = {
      'carrier_name': _simCarrier,
      'container_type': _simContainerType,
      'containers_count': _simContainersCount,
      if (_simDemFreeDays != null) 'demurrage_free_days': _simDemFreeDays,
      if (_simDetFreeDays != null) 'detention_free_days': _simDetFreeDays,
      'discharge_date': _formatDate(_simDischargeDate),
      if (_simGateOutDate != null) 'gate_out_date': _formatDate(_simGateOutDate!),
      if (_simEmptyReturnDate != null) 'empty_return_date': _formatDate(_simEmptyReturnDate!),
      'calculation_date': _formatDate(DateTime.now()),
      'currency': 'USD',
      'exchange_rate': fx,
    };

    ref.read(demurrageProvider.notifier).simulateCalculation(payload).then((_) {
      if (mounted) setState(() => _isSimulating = false);
    }).catchError((_) {
      if (mounted) setState(() => _isSimulating = false);
    });
  }

  String _formatDate(DateTime dt) => dt.toIso8601String().split('T').first;

  void _copyTrackingsTsv(List<DemurrageTrackingModel> trackings) {
    final l10n = context.l10n;
    final headers = [
      l10n.demurrageTsvHeaderTrackingCode,
      l10n.demurrageTsvHeaderBlNumber,
      l10n.demurrageTsvHeaderCarrier,
      l10n.demurrageTsvHeaderPort,
      l10n.demurrageTsvHeaderDischargeDate,
      l10n.demurrageTsvHeaderGateOutDate,
      l10n.demurrageTsvHeaderEmptyReturnDate,
      l10n.demurrageTsvHeaderContainersCount,
      l10n.demurrageTsvHeaderTotalDemurrageFx,
      l10n.demurrageTsvHeaderTotalDetentionFx,
      l10n.demurrageTsvHeaderTotalStorageEgp,
      l10n.demurrageTsvHeaderCurrency,
      l10n.demurrageTsvHeaderExchangeRate,
      l10n.demurrageTsvHeaderTotalCostEgp,
      l10n.demurrageTsvHeaderStatus,
      l10n.demurrageTsvHeaderPushedSettlement,
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));
    for (final t in trackings) {
      final row = [
        t.trackingCode,
        t.billOfLadingNo,
        t.carrierName,
        t.portName,
        t.dischargeDate,
        t.gateOutDate ?? l10n.notGatedOutYet,
        t.emptyReturnDate ?? l10n.notReturnedYet,
        t.containers.length.toString(),
        t.totalDemurrageFx.toStringAsFixed(2),
        t.totalDetentionFx.toStringAsFixed(2),
        t.totalStorageEgp.toStringAsFixed(2),
        t.currency,
        t.exchangeRate?.toStringAsFixed(2) ?? '-',
        t.totalCostEgp.toStringAsFixed(2),
        t.status,
        t.isPushedToSettlement ? l10n.lgxYes : l10n.lgxNo,
      ];
      buffer.writeln(row.join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.demurrageExportTsvSuccess,
    );
  }

  void _copySimulationBreakdownTsv(DemurrageSimulationResultModel res) {
    final l10n = context.l10n;
    final headers = [
      l10n.colCategory,
      l10n.colConsumedDays,
      l10n.colFreeDays,
      l10n.colOverdueDays,
      l10n.colFeeAmount,
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));
    for (final b in res.breakdownDetails) {
      final cat = l10n.demurrageCategoryLabel(b['category']);
      final feeStr = b['currency'] == 'EGP'
          ? l10n.egpCurrencyAmount((b['fee_egp'] ?? 0).toString())
          : '${b['fee_fx']} ${b['currency']}';
      final row = [
        cat,
        l10n.daysCountFormatted(b['days_consumed'] ?? 0),
        l10n.daysCountFormatted(b['free_days'] ?? 0),
        l10n.daysCountFormatted(b['days_overdue'] ?? 0),
        feeStr,
      ];
      buffer.writeln(row.join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.simBreakdownCopyTsvSuccess,
    );
  }

  void _copyPoliciesTsv(List<DemurragePolicyModel> policies) {
    final l10n = context.l10n;
    final headers = [
      l10n.policiesTsvHeaderCarrier,
      l10n.policiesTsvHeaderContainerType,
      l10n.policiesTsvHeaderDemurrageFreeDays,
      l10n.policiesTsvHeaderDetentionFreeDays,
      l10n.policiesTsvHeaderPortStorageFreeDays,
      l10n.policiesTsvHeaderDailyStorageRateEgp,
      l10n.policiesTsvHeaderCurrency,
    ];

    final buffer = StringBuffer();
    buffer.writeln(headers.join('\t'));
    for (final p in policies) {
      final row = [
        p.carrierName,
        p.containerType,
        p.demurrageFreeDays.toString(),
        p.detentionFreeDays.toString(),
        p.portStorageFreeDays.toString(),
        p.portStorageDailyRateEgp.toStringAsFixed(2),
        p.currency,
      ];
      buffer.writeln(row.join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.policiesExportTsvSuccess,
    );
  }

  void _copyPolicySummary(DemurragePolicyModel p) {
    final l10n = context.l10n;
    final buffer = StringBuffer()
      ..writeln('${l10n.policiesTsvHeaderCarrier}:\t${p.carrierName}')
      ..writeln('${l10n.policiesTsvHeaderContainerType}:\t${p.containerType}')
      ..writeln('${l10n.policiesTsvHeaderDemurrageFreeDays}:\t${l10n.daysCountFormatted(p.demurrageFreeDays)}')
      ..writeln('${l10n.policiesTsvHeaderDetentionFreeDays}:\t${l10n.daysCountFormatted(p.detentionFreeDays)}')
      ..writeln('${l10n.policiesTsvHeaderPortStorageFreeDays}:\t${l10n.daysCountFormatted(p.portStorageFreeDays)}')
      ..writeln('${l10n.policiesTsvHeaderDailyStorageRateEgp}:\t${p.portStorageDailyRateEgp}')
      ..writeln('${l10n.policiesTsvHeaderCurrency}:\t${p.currency}');
    CopyHelper.copy(context, buffer.toString(), customMessage: l10n.policyCopySummarySuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final state = ref.watch(demurrageProvider);
    final stageBadge = DisplayNameResolver.resolveStageBadge(
      'STEP_18',
      isArabic: Directionality.of(context) == TextDirection.rtl,
    );

    return Scaffold(
      backgroundColor: AppTheme.surfaceAltOf(context),
      appBar: PageHeader(
        icon: Icons.timer_outlined,
        iconColor: AppTheme.orange,
        title: l10n.demurrageScreenTitle,
        subtitle: stageBadge.isEmpty ? null : stageBadge,
        actions: [
          AppButton(
            label: l10n.demHeaderFreeDaysBtn,
            icon: Icons.verified_user_outlined,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: () {
              FreeDaysAgreementDialog.show(
                context,
                initialImportFileId: widget.initialImportFileId,
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.freightDataLaunchConnectorTooltip,
            icon: Icon(Icons.cloud_sync_outlined, color: AppTheme.white, size: density.buttonIconSize),
            onPressed: () => showFreightDataMonitorDialog(context, ref),
          ),
          IconButton(
            tooltip: l10n.refresh,
            icon: Icon(Icons.refresh, color: AppTheme.white, size: density.buttonIconSize),
            onPressed: _reload,
          ),
          const BackToDashboardButton(),
          const SizedBox(width: 12),
        ],
      ),
      body: SelectionArea(
        child: state.isLoading && state.trackings.isEmpty
            ? const CcStateView.loading()
            : AdaptiveTabScaffold(
                controller: _tabController,
                tabs: [
                  AdaptiveTabItem(
                    icon: Icons.list_alt_rounded,
                    label: l10n.containerTrackingsTab,
                    content: _buildTrackingsTab(state),
                  ),
                  AdaptiveTabItem(
                    icon: Icons.calculate_outlined,
                    label: l10n.simulatorAndTierCalcTab,
                    content: _buildSimulatorTab(state),
                  ),
                  AdaptiveTabItem(
                    icon: Icons.policy_outlined,
                    label: l10n.carrierTariffPoliciesTab,
                    content: _buildPoliciesTab(state),
                  ),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: ACTIVE CONTAINER TRACKINGS
  // ===========================================================================
  Widget _buildTrackingsTab(DemurrageState state) {
    final l10n = context.l10n;
    final filteredTrackings = state.trackings.where((t) {
      final matchesSearch = t.trackingCode.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          t.billOfLadingNo.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          t.carrierName.toLowerCase().contains(_searchController.text.toLowerCase());
      if (_selectedStatusFilter == 'All') return matchesSearch;
      return matchesSearch && t.status == _selectedStatusFilter;
    }).toList();

    final totalDemurrageEgp = state.trackings.fold<double>(0.0, (sum, t) => sum + t.totalCostEgp);
    final incurredCount = state.trackings.where((t) => t.status.contains('Incurred')).length;
    final activeCount = state.trackings.length;

    return RefreshIndicator(
      onRefresh: () async {
        if (!ref.read(demurrageProvider).isLoading) {
          await ref.read(demurrageProvider.notifier).loadInitialData();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KPI strip: short numeric values only
            CcUi.metrics([
              MetricCardData(
                title: l10n.totalActiveTrackingsMetric,
                value: '$activeCount',
                icon: Icons.all_inbox_rounded,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: l10n.incurredDemurrageShipmentsMetric,
                value: '$incurredCount',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.crimson,
              ),
              MetricCardData(
                title: l10n.totalCalculatedDemurrageMetric,
                value: l10n.egpCurrencyAmount(CcFormat.money(totalDemurrageEgp)),
                icon: Icons.attach_money_rounded,
                color: AppTheme.orange,
              ),
            ]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildToolbar(filteredTrackings),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: filteredTrackings.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: state.error != null && state.trackings.isEmpty
                          ? CcStateView.error(
                              message: ApiErrorText.of(l10n, state.errorObject ?? state.error, fallback: l10n.genericErrorSnack),
                              actionLabel: l10n.retry,
                              onAction: _reload,
                            )
                          : CcStateView.empty(
                        message: l10n.noTrackingsFound,
                        actionLabel: l10n.startNewTrackingBtn,
                        onAction: () => AddTrackingDialog.show(context),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTrackings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildTrackingCard(filteredTrackings[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(List<DemurrageTrackingModel> filteredTrackings) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, val, _) {
                return TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.searchDemurrageHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: val.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 200,
            child: SearchableDropdownField<String>(
              labelText: l10n.statusFilterLabel,
              value: _selectedStatusFilter,
              items: [
                SearchableDropdownItem(value: 'All', label: l10n.allStatusesOption),
                SearchableDropdownItem(value: 'Free Time Active', label: l10n.statusFreeTimeActive),
                SearchableDropdownItem(value: 'Demurrage Incurred', label: l10n.statusDemurrageIncurred),
                SearchableDropdownItem(value: 'Detention Incurred', label: l10n.statusDetentionIncurred),
                SearchableDropdownItem(value: 'Pushed to Settlement', label: l10n.statusPushedToSettlement),
              ],
              onChanged: (v) => setState(() => _selectedStatusFilter = v ?? 'All'),
            ),
          ),
          CcUi.fit(AppButton(
            label: l10n.demurrageExportTsvBtn,
            icon: Icons.copy_all_rounded,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: filteredTrackings.isEmpty ? null : () => _copyTrackingsTsv(filteredTrackings),
          )),
          CcUi.fit(AppButton(
            label: l10n.demurrageExportExcelBtn,
            icon: Icons.table_chart,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: filteredTrackings.isEmpty
                ? null
                : () => MasterDataExportService.exportDemurrageTrackingsToExcel(
                      context,
                      filteredTrackings,
                      isAr: _isAr,
                    ),
          )),
          CcUi.fit(AppButton(
            label: l10n.demurrageExportPdfBtn,
            icon: Icons.picture_as_pdf,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: filteredTrackings.isEmpty
                ? null
                : () => MasterDataExportService.printOrSaveDemurrageTrackingsListPdf(
                      context,
                      filteredTrackings,
                      isAr: _isAr,
                    ),
          )),
          CcUi.fit(AppButton(
            label: l10n.startNewTrackingBtn,
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => AddTrackingDialog.show(context),
          )),
          CcUi.fit(AppButton(
            key: const Key('globalEmptyContainerReturnBtn'),
            label: l10n.demReturnContainersBtn,
            icon: Icons.assignment_turned_in_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => EmptyContainerReturnDialog.show(
              context,
              initialImportFileId: widget.initialImportFileId,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTrackingCard(DemurrageTrackingModel item) {
    final l10n = context.l10n;
    return DemurrageTrackingCard(
      item: item,
      onCopySummary: () {
        final summary = MasterDataExportService.generateDemurrageTrackingWhatsAppText(item, isAr: _isAr);
        CopyHelper.copy(context, summary, customMessage: l10n.demurrageCopySummarySuccess);
      },
      onPrintSlip: () => MasterDataExportService.printOrSaveDemurrageTrackingSlipPdf(context, item, isAr: _isAr),
      onOpenRadar: () => showDualClockRadarDialog(
        context,
        ref,
        trackingId: item.trackingId,
        billOfLadingNo: item.billOfLadingNo,
        carrierName: item.carrierName,
      ),
      onUpdateDates: () => UpdateTrackingDatesDialog.show(context, item),
      onReturnContainers: () {
        final firstContainer = item.containers.isNotEmpty
            ? (item.containers.first is Map
                ? item.containers.first['container_number']?.toString()
                : item.containers.first.toString())
            : null;
        EmptyContainerReturnDialog.show(
          context,
          initialImportFileId: item.importFileId,
          initialContainerNumber: firstContainer,
        );
      },
      onPushToSettlement: () => _handlePushToSettlement(item),
    );
  }

  // ===========================================================================
  // TAB 2: INTERACTIVE SIMULATOR & TIER CALCULATOR
  // ===========================================================================
  Widget _buildSimulatorTab(DemurrageState state) {
    final l10n = context.l10n;
    final res = state.simulationResult;
    final fxMissing = _simExchangeRate == null || _simExchangeRate! <= 0;

    final inputPanel = _buildSimulatorInputs(l10n);
    final Widget resultPanel = res == null
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: CcStateView.empty(
              message: fxMissing ? l10n.demEnterFxHint : l10n.initializingSimulationResults,
              icon: Icons.calculate_outlined,
            ),
          )
        : DemurrageSimulationPanel(
            result: res,
            onCopyBreakdown: () => _copySimulationBreakdownTsv(res),
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [inputPanel, const SizedBox(height: 16), resultPanel],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: inputPanel),
              const SizedBox(width: 16),
              Expanded(flex: 6, child: resultPanel),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _copyDecoration(AppLocalizations l10n, String label, String Function() copyValue) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      suffixIcon: IconButton(
        icon: const Icon(Icons.copy, size: 16),
        tooltip: l10n.demurrageCopyFieldTooltip,
        onPressed: () => CopyHelper.copy(context, copyValue()),
      ),
    );
  }

  Widget _buildSimulatorInputs(AppLocalizations l10n) {
    return CcSectionCard(
      title: l10n.calculationSettingsTitle,
      icon: Icons.tune_rounded,
      margin: EdgeInsets.zero,
      child: Form(
        key: _simFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            SearchableDropdownField<String>(
              labelText: l10n.shippingLineFieldLabel,
              value: _simCarrier,
              items: DemurrageLookups.carriers.map((c) => SearchableDropdownItem(value: c, label: c)).toList(),
              onChanged: (c) {
                if (c != null) {
                  setState(() => _simCarrier = c);
                  _runQuickSimulation();
                }
              },
            ),
            const SizedBox(height: 12),
            SearchableDropdownField<String>(
              labelText: l10n.containerTypeFieldLabel,
              value: _simContainerType,
              items: DemurrageLookups.containerTypes.map((t) => SearchableDropdownItem(value: t, label: t)).toList(),
              onChanged: (t) {
                if (t != null) {
                  setState(() => _simContainerType = t);
                  _runQuickSimulation();
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _simContainersCount.toString(),
                    decoration: _copyDecoration(l10n, l10n.containersCountFieldLabel, () => _simContainersCount.toString()),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? l10n.requiredFieldValidation : null,
                    onChanged: (v) {
                      _simContainersCount = int.tryParse(v) ?? 1;
                      _runQuickSimulation();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _simExchangeRate?.toString() ?? '',
                    decoration: _copyDecoration(l10n, l10n.exchangeRateFieldLabel, () => _simExchangeRate?.toString() ?? ''),
                    keyboardType: TextInputType.number,
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? l10n.requiredFieldValidation : null,
                    onChanged: (v) {
                      _simExchangeRate = double.tryParse(v);
                      _runQuickSimulation();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _subHeader(l10n.grantedFreeDaysHeader),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _simDemFreeDays?.toString() ?? '',
                    decoration: _copyDecoration(l10n, l10n.portDemurrageFreeDaysLabel, () => _simDemFreeDays?.toString() ?? ''),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      _simDemFreeDays = int.tryParse(v);
                      _runQuickSimulation();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _simDetFreeDays?.toString() ?? '',
                    decoration: _copyDecoration(l10n, l10n.emptyReturnFreeDaysLabel, () => _simDetFreeDays?.toString() ?? ''),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      _simDetFreeDays = int.tryParse(v);
                      _runQuickSimulation();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _subHeader(l10n.operationalMilestonesHeader),
            const SizedBox(height: 8),
            _milestoneTile(
              icon: Icons.date_range,
              color: AppTheme.cobalt,
              title: l10n.vesselDischargeDateMilestone,
              value: _formatDate(_simDischargeDate),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _simDischargeDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _simDischargeDate = picked);
                  _runQuickSimulation();
                }
              },
            ),
            const SizedBox(height: 8),
            _milestoneTile(
              icon: Icons.output_rounded,
              color: AppTheme.orange,
              title: l10n.portGateOutDateMilestone,
              value: _simGateOutDate != null ? _formatDate(_simGateOutDate!) : null,
              placeholder: l10n.notGatedOutCalculatedToday,
              onClear: _simGateOutDate == null
                  ? null
                  : () {
                      setState(() => _simGateOutDate = null);
                      _runQuickSimulation();
                    },
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _simGateOutDate ?? _simDischargeDate,
                  firstDate: _simDischargeDate,
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _simGateOutDate = picked);
                  _runQuickSimulation();
                }
              },
            ),
            const SizedBox(height: 8),
            _milestoneTile(
              icon: Icons.keyboard_return_rounded,
              color: AppTheme.emerald,
              title: l10n.emptyReturnToDepotMilestone,
              value: _simEmptyReturnDate != null ? _formatDate(_simEmptyReturnDate!) : null,
              placeholder: l10n.notReturnedYet,
              onClear: _simEmptyReturnDate == null
                  ? null
                  : () {
                      setState(() => _simEmptyReturnDate = null);
                      _runQuickSimulation();
                    },
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _simEmptyReturnDate ?? (_simGateOutDate ?? _simDischargeDate),
                  firstDate: _simGateOutDate ?? _simDischargeDate,
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _simEmptyReturnDate = picked);
                  _runQuickSimulation();
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: l10n.recalculateDemurrageNowBtn,
                icon: Icons.refresh,
                isLoading: _isSimulating,
                onPressed: _isSimulating ? null : _runQuickSimulation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subHeader(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryOf(context),
        ),
      );

  Widget _milestoneTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
    String? value,
    String? placeholder,
    VoidCallback? onClear,
  }) {
    return Material(
      color: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 13)),
        subtitle: value != null
            ? Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
            : Text(placeholder ?? '', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
        trailing: onClear != null
            ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear)
            : const Icon(Icons.edit, size: 18),
        onTap: onTap,
      ),
    );
  }

  // ===========================================================================
  // TAB 3: CARRIER TARIFF POLICIES
  // ===========================================================================
  Widget _buildPoliciesTab(DemurrageState state) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.carrierTariffPoliciesTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.carrierTariffPoliciesSubtitle,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CcUi.fit(AppButton(
                    label: l10n.policiesExportTsvBtn,
                    icon: Icons.copy_all_rounded,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                    onPressed: state.policies.isEmpty ? null : () => _copyPoliciesTsv(state.policies),
                  )),
                  CcUi.fit(AppButton(
                    label: l10n.demurrageExportExcelBtn,
                    icon: Icons.table_chart,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: state.policies.isEmpty
                        ? null
                        : () => MasterDataExportService.exportDemurragePoliciesToExcel(
                              context,
                              state.policies,
                              isAr: _isAr,
                            ),
                  )),
                  CcUi.fit(AppButton(
                    label: l10n.addCarrierPolicyBtn,
                    icon: Icons.add,
                    size: AppButtonSize.small,
                    onPressed: () => AddPolicyDialog.show(context),
                  )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.policies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: CcStateView.empty(
                message: l10n.noCarrierPoliciesFound,
                icon: Icons.policy_outlined,
                actionLabel: l10n.addCarrierPolicyBtn,
                onAction: () => AddPolicyDialog.show(context),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.policies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final p = state.policies[i];
                return DemurragePolicyCard(policy: p, onCopy: () => _copyPolicySummary(p));
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ACTIONS
  // ===========================================================================
  void _handlePushToSettlement(DemurrageTrackingModel item) async {
    final l10n = context.l10n;
    final res = await ref.read(demurrageProvider.notifier).pushToSettlement(
          item.trackingId,
          importFileId: item.importFileId ?? 1,
        );
    if (!mounted) return;
    if (res != null && res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.pushedToSettlementSuccessSnack, severity: AppSeverity.success),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          ApiErrorText.of(l10n, ref.read(demurrageProvider).errorObject, fallback: l10n.pushToSettlementErrorSnack),
          severity: AppSeverity.danger,
        ),
      );
    }
  }
}
