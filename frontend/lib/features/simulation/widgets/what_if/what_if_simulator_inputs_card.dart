import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/providers/import_files_provider.dart';

class WhatIfSimulatorInputsCard extends ConsumerWidget {
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileSelected;
  final TextEditingController invoiceAmountCtrl;
  final TextEditingController freightCtrl;
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final double baseRate;
  final double fxRateChangePct;
  final ValueChanged<double> onFxRateChanged;
  final String shippingRoute;
  final ValueChanged<String> onRouteChanged;
  final int portDelayDays;
  final ValueChanged<int> onPortDelayChanged;
  final int containerCount;
  final ValueChanged<int> onContainerCountChanged;
  final bool isSimulating;
  final VoidCallback onRunSimulation;

  const WhatIfSimulatorInputsCard({
    super.key,
    required this.selectedImportFileId,
    required this.onImportFileSelected,
    required this.invoiceAmountCtrl,
    required this.freightCtrl,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    required this.baseRate,
    required this.fxRateChangePct,
    required this.onFxRateChanged,
    required this.shippingRoute,
    required this.onRouteChanged,
    required this.portDelayDays,
    required this.onPortDelayChanged,
    required this.containerCount,
    required this.onContainerCountChanged,
    required this.isSimulating,
    required this.onRunSimulation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return SizedBox(
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
                Text(
                  l10n.whatIfShipmentAndCurrencyInputs,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildImportFileSelector(context, ref),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: invoiceAmountCtrl,
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
                      child: SearchableDropdownField<String>(
                        value: selectedCurrency,
                        labelText: l10n.currency,
                        decoration: InputDecoration(
                          labelText: l10n.currency,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          SearchableDropdownItem<String>(value: 'USD', label: 'USD'),
                          SearchableDropdownItem<String>(value: 'EUR', label: 'EUR'),
                          SearchableDropdownItem<String>(value: 'CNY', label: 'CNY'),
                          SearchableDropdownItem<String>(value: 'GBP', label: 'GBP'),
                        ],
                        onChanged: (val) {
                          if (val != null) onCurrencyChanged(val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: freightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${l10n.whatIfFreightCost} ($selectedCurrency)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  l10n.whatIfFxShockSimulation,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${l10n.whatIfBaseRate} ${baseRate.toStringAsFixed(2)} ${l10n.egpCurrency}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: fxRateChangePct > 0 ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: fxRateChangePct > 0 ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                      child: Text(
                        '${l10n.whatIfSimulatedRate} ${(baseRate * (1 + fxRateChangePct / 100)).toStringAsFixed(2)} ${l10n.egpCurrency} (${fxRateChangePct > 0 ? "+" : ""}${fxRateChangePct.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: fxRateChangePct > 0 ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: fxRateChangePct,
                  min: -10.0,
                  max: 60.0,
                  divisions: 14,
                  activeColor: fxRateChangePct > 0 ? AppTheme.crimson : AppTheme.cobalt,
                  label: '${fxRateChangePct.toStringAsFixed(0)}%',
                  onChanged: onFxRateChanged,
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  l10n.whatIfShippingRouteRisk,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                SearchableDropdownField<String>(
                  value: shippingRoute,
                  labelText: l10n.whatIfShippingRouteRisk,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    SearchableDropdownItem<String>(
                      value: 'RED_SEA',
                      label: l10n.whatIfRouteRedSea,
                    ),
                    SearchableDropdownItem<String>(
                      value: 'CAPE_OF_GOOD_HOPE',
                      label: l10n.whatIfRouteCape,
                    ),
                  ],
                  onChanged: (val) => onRouteChanged(val ?? 'RED_SEA'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.whatIfPortDelay} $portDelayDays ${l10n.whatIfDaysUnit}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Slider(
                            value: portDelayDays.toDouble(),
                            min: 0.0,
                            max: 30.0,
                            divisions: 30,
                            label: '$portDelayDays ${l10n.whatIfDaysUnit}',
                            onChanged: (val) => onPortDelayChanged(val.toInt()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SearchableDropdownField<int>(
                        value: containerCount,
                        labelText: l10n.whatIfContainersCount,
                        decoration: InputDecoration(
                          labelText: l10n.whatIfContainersCount,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [1, 2, 3, 4, 5, 10]
                            .map((c) => SearchableDropdownItem<int>(
                                  value: c,
                                  label: '$c ${l10n.whatIfContainerUnit}',
                                ))
                            .toList(),
                        onChanged: (val) => onContainerCountChanged(val ?? 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSimulating ? null : onRunSimulation,
                    icon: isSimulating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      l10n.whatIfRunSimulationNow,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
    );
  }

  Widget _buildImportFileSelector(BuildContext context, WidgetRef ref) {
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
                    label:
                        '${f.primaryNameWithCode} - ${f.companyName} (${f.estimatedCost} ${f.estimatedCostCurrency})',
                  ))
              .toList(),
          value: selectedImportFileId,
          onChanged: onImportFileSelected,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
