import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import 'freight_simulator_output_view.dart';

class FreightMonitorSimulatorTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String selectedCarrier;
  final ValueChanged<String?> onCarrierChanged;
  final String selectedPort;
  final ValueChanged<String?> onPortChanged;
  final String selectedContainerType;
  final ValueChanged<String?> onContainerTypeChanged;
  final DateTime dischargeDate;
  final ValueChanged<DateTime> onDischargeDateChanged;
  final int daysInPort;
  final ValueChanged<int> onDaysInPortChanged;
  final TextEditingController fxController;
  final bool fxFromCurrencies;
  final ValueChanged<String> onFxChanged;
  final double? Function(String?) parsedFxRate;
  final bool isCalculating;
  final VoidCallback onCalculate;
  final Map<String, dynamic>? calculationResult;
  final String? calcError;

  static const List<String> carriers = ['msc', 'maersk', 'cma_cgm', 'hapag_lloyd', 'cosco'];
  static const List<String> ports = ['Alexandria', 'Damietta', 'Sokhna', 'Port Said'];
  static const List<String> containerTypes = ['40HC', '20GP', '40ft', '20ft'];

  const FreightMonitorSimulatorTab({
    super.key,
    required this.formKey,
    required this.selectedCarrier,
    required this.onCarrierChanged,
    required this.selectedPort,
    required this.onPortChanged,
    required this.selectedContainerType,
    required this.onContainerTypeChanged,
    required this.dischargeDate,
    required this.onDischargeDateChanged,
    required this.daysInPort,
    required this.onDaysInPortChanged,
    required this.fxController,
    required this.fxFromCurrencies,
    required this.onFxChanged,
    required this.parsedFxRate,
    required this.isCalculating,
    required this.onCalculate,
    required this.calculationResult,
    required this.calcError,
  });

  void _copyCalculationDossier(BuildContext context) {
    final l10n = context.l10n;
    if (calculationResult == null) return;
    final notice = calculationResult!['advisory_notice_ar'] ?? '';
    final det = calculationResult!['detention'] ?? {};
    final port = calculationResult!['port_storage'] ?? {};

    final sb = StringBuffer();
    sb.writeln("=== ${l10n.freightDataTabSimulator} ===");
    sb.writeln("${l10n.freightDataSimShippingLine}: ${selectedCarrier.toUpperCase()}");
    sb.writeln("${l10n.freightDataSimPortAuthority}: $selectedPort");
    sb.writeln("${l10n.freightDataSimContainerType}: $selectedContainerType");
    sb.writeln("${l10n.freightDataSimDaysInPort}: ${calculationResult!['days_in_port']} ${l10n.freightDataDayUnit}");
    sb.writeln("---------------------------------------------");
    sb.writeln("${l10n.freightDataCarrierDetentionTitle}: ${det['total_detention_usd']} USD (${det['chargeable_days']} ${l10n.freightDataDayUnit})");
    sb.writeln("${l10n.freightDataPortStorageTitle}: ${port['total_storage_egp']} EGP (${port['tariff_version_applied']})");
    sb.writeln("${l10n.freightDataConsolidatedEgp}: ${calculationResult!['consolidated_total_egp']} EGP");
    sb.writeln("${l10n.freightDataConsolidatedUsd}: ${calculationResult!['consolidated_total_usd']} USD");
    sb.writeln("${l10n.freightDataSimFxRate}: ${calculationResult!['exchange_rate_applied']} (${calculationResult!['exchange_rate_source']})");
    sb.writeln("---------------------------------------------");
    sb.writeln(notice);

    CopyHelper.copy(context, sb.toString(), customMessage: l10n.freightDataSimulationDossierCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Form(
      key: formKey,
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
                    value: selectedCarrier,
                    items: carriers.map((c) => SearchableDropdownItem(value: c, label: c.toUpperCase())).toList(),
                    onChanged: onCarrierChanged,
                  ),
                  const SizedBox(height: 10),
                  SearchableDropdownField<String>(
                    labelText: l10n.freightDataSimPortAuthority,
                    value: selectedPort,
                    items: ports.map((p) => SearchableDropdownItem(value: p, label: p)).toList(),
                    onChanged: onPortChanged,
                  ),
                  const SizedBox(height: 10),
                  SearchableDropdownField<String>(
                    labelText: l10n.freightDataSimContainerType,
                    value: selectedContainerType,
                    items: containerTypes.map((t) => SearchableDropdownItem(value: t, label: t)).toList(),
                    onChanged: onContainerTypeChanged,
                  ),
                  const SizedBox(height: 10),

                  // Discharge Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dischargeDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        onDischargeDateChanged(picked);
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
                        CcFormat.date(dischargeDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Days In Port
                  TextFormField(
                    initialValue: "$daysInPort",
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
                        onDaysInPortChanged(parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Exchange Rate USD/EGP
                  TextFormField(
                    key: const Key('freightDataFxRateField'),
                    controller: fxController,
                    decoration: InputDecoration(
                      labelText: l10n.freightDataSimFxRate,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      helperText: fxFromCurrencies ? l10n.demFxRateFromCurrencies : l10n.demFxRateMissingHint,
                      helperMaxLines: 2,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => parsedFxRate(v) == null ? l10n.demFxRateRequired : null,
                    onChanged: onFxChanged,
                  ),
                  const SizedBox(height: 14),

                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AppButton(
                        onPressed: isCalculating ? null : onCalculate,
                        isLoading: isCalculating,
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
            child: FreightSimulatorOutputView(
              calculationResult: calculationResult,
              isCalculating: isCalculating,
              calcError: calcError,
              onCopyDossier: () => _copyCalculationDossier(context),
            ),
          ),
        ],
      ),
    );
  }
}
