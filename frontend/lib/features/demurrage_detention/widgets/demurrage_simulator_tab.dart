import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/demurrage_model.dart';
import '../providers/demurrage_provider.dart';
import 'demurrage_form_dialogs.dart';
import 'demurrage_simulation_panel.dart';

class DemurrageSimulatorTab extends ConsumerStatefulWidget {
  const DemurrageSimulatorTab({super.key});

  @override
  ConsumerState<DemurrageSimulatorTab> createState() => _DemurrageSimulatorTabState();
}

class _DemurrageSimulatorTabState extends ConsumerState<DemurrageSimulatorTab> {
  final _simFormKey = GlobalKey<FormState>();
  String _simCarrier = 'MSC';
  String _simPort = 'Alexandria Port';
  String? _simTerminal = 'Alexandria Container Terminal (ACCHCO)';
  String _simContainerType = '40ft High Cube';
  int _simContainersCount = 1;
  int? _simDemFreeDays = 21;
  int? _simDetFreeDays = 7;
  int? _simStorageFreeDays = 7;
  double? _simExchangeRate;
  DateTime _simDischargeDate = DateTime.now().subtract(const Duration(days: 16));
  DateTime? _simGateOutDate;
  DateTime? _simEmptyReturnDate;
  bool _isSimulating = false;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runQuickSimulation();
    });
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
      'port_name': _simPort,
      if (_simTerminal != null && _simTerminal!.isNotEmpty) 'terminal_name': _simTerminal,
      if (_simDemFreeDays != null) 'demurrage_free_days': _simDemFreeDays,
      if (_simDetFreeDays != null) 'detention_free_days': _simDetFreeDays,
      if (_simStorageFreeDays != null) 'port_storage_free_days': _simStorageFreeDays,
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

  Widget _subHeader(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryOf(context),
        ),
      );

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
            SearchableDropdownField<String>(
              labelText: l10n.arrivalPortFieldLabel,
              value: _simPort,
              items: DemurrageLookups.ports.map((p) => SearchableDropdownItem(value: p, label: p)).toList(),
              onChanged: (p) {
                if (p != null) {
                  setState(() {
                    _simPort = p;
                    final terms = DemurrageLookups.terminalsByPort[p] ?? [];
                    _simTerminal = terms.isNotEmpty ? terms.first : null;
                  });
                  _runQuickSimulation();
                }
              },
            ),
            const SizedBox(height: 12),
            SearchableDropdownField<String>(
              labelText: _isAr ? 'محطة الحاويات' : 'Container Terminal / Depot',
              value: _simTerminal,
              items: (DemurrageLookups.terminalsByPort[_simPort] ?? [])
                  .map((t) => SearchableDropdownItem(value: t, label: t))
                  .toList(),
              onChanged: (t) {
                setState(() => _simTerminal = t);
                _runQuickSimulation();
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
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.verified_outlined, size: 14, color: AppTheme.cobalt),
                  label: const Text('عرض 21 يوم خط (خط 21 / ميناء 7)', style: TextStyle(fontSize: 11.5)),
                  backgroundColor: _simDemFreeDays == 21 && _simStorageFreeDays == 7
                      ? AppTheme.cobalt.withValues(alpha: 0.18)
                      : null,
                  onPressed: () {
                    setState(() {
                      _simDemFreeDays = 21;
                      _simDetFreeDays = 7;
                      _simStorageFreeDays = 7;
                    });
                    _runQuickSimulation();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.history_toggle_off_rounded, size: 14, color: AppTheme.charcoal),
                  label: const Text('تعريفة الخط الافتراضية (خط 5 / ميناء 7)', style: TextStyle(fontSize: 11.5)),
                  backgroundColor: _simDemFreeDays == 5 && _simStorageFreeDays == 7
                      ? AppTheme.charcoal.withValues(alpha: 0.18)
                      : null,
                  onPressed: () {
                    setState(() {
                      _simDemFreeDays = 5;
                      _simDetFreeDays = 7;
                      _simStorageFreeDays = 7;
                    });
                    _runQuickSimulation();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsetsDirectional.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.cobalt, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سماح الـ 21 يوماً يسري على غرامات تأخير الحاوية للخط فقط، وتخضع أرضيات الميناء لـ 7 أيام مجاناً.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textPrimaryOf(context)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('dem_$_simDemFreeDays'),
                    initialValue: _simDemFreeDays?.toString() ?? '',
                    decoration: _copyDecoration(l10n, l10n.portDemurrageFreeDaysLabel, () => _simDemFreeDays?.toString() ?? ''),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      _simDemFreeDays = int.tryParse(v);
                      _runQuickSimulation();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('det_$_simDetFreeDays'),
                    initialValue: _simDetFreeDays?.toString() ?? '',
                    decoration: _copyDecoration(l10n, l10n.emptyReturnFreeDaysLabel, () => _simDetFreeDays?.toString() ?? ''),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      _simDetFreeDays = int.tryParse(v);
                      _runQuickSimulation();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('stor_$_simStorageFreeDays'),
                    initialValue: _simStorageFreeDays?.toString() ?? '',
                    decoration: _copyDecoration(l10n, l10n.fdaPortStorage, () => _simStorageFreeDays?.toString() ?? ''),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      _simStorageFreeDays = int.tryParse(v);
                      _runQuickSimulation();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _subHeader(l10n.operationalMilestonesHeader),
            const SizedBox(height: 8),
            AppDatePickerField(
              label: l10n.vesselDischargeDateMilestone,
              value: _simDischargeDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              allowClear: false,
              onChanged: (picked) {
                if (picked != null) {
                  setState(() => _simDischargeDate = picked);
                  _runQuickSimulation();
                }
              },
            ),
            const SizedBox(height: 12),
            AppDatePickerField(
              label: l10n.portGateOutDateMilestone,
              value: _simGateOutDate,
              hint: l10n.notGatedOutCalculatedToday,
              firstDate: _simDischargeDate,
              lastDate: DateTime(2030),
              allowClear: true,
              onChanged: (picked) {
                setState(() => _simGateOutDate = picked);
                _runQuickSimulation();
              },
            ),
            const SizedBox(height: 12),
            AppDatePickerField(
              label: l10n.emptyReturnToDepotMilestone,
              value: _simEmptyReturnDate,
              hint: l10n.notReturnedYet,
              firstDate: _simGateOutDate ?? _simDischargeDate,
              lastDate: DateTime(2030),
              allowClear: true,
              onChanged: (picked) {
                setState(() => _simEmptyReturnDate = picked);
                _runQuickSimulation();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(demurrageProvider);
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
}
