import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_tariff_model.dart';
import '../providers/customs_tariff_provider.dart';

class HsCodeQuickCalculatorTab extends ConsumerStatefulWidget {
  final CustomsTariffModel tariff;

  const HsCodeQuickCalculatorTab({super.key, required this.tariff});

  @override
  ConsumerState<HsCodeQuickCalculatorTab> createState() => _HsCodeQuickCalculatorTabState();
}

class _HsCodeQuickCalculatorTabState extends ConsumerState<HsCodeQuickCalculatorTab> {
  final _cifValueCtrl = TextEditingController();
  final _freightCtrl = TextEditingController();
  String _selectedOriginCountry = 'ITALY';
  CustomsDutyBreakdownModel? _dutyBreakdown;
  bool _isCalculating = false;

  @override
  void didUpdateWidget(covariant HsCodeQuickCalculatorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tariff.tariffId != widget.tariff.tariffId) {
      _dutyBreakdown = null;
    }
  }

  @override
  void dispose() {
    _cifValueCtrl.dispose();
    _freightCtrl.dispose();
    super.dispose();
  }

  void _calculateDuty() async {
    final cif = double.tryParse(_cifValueCtrl.text.trim()) ?? 0.0;
    final freight = double.tryParse(_freightCtrl.text.trim()) ?? 0.0;
    if (cif <= 0) return;

    setState(() => _isCalculating = true);
    try {
      final breakdown = await ref.read(customsTariffProvider.notifier).estimateDuty(
            hsCode: widget.tariff.hsCode,
            cifValue: cif,
            freight: freight,
            originCountry: _selectedOriginCountry,
          );
      if (mounted) {
        setState(() {
          _dutyBreakdown = breakdown;
          _isCalculating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCalculating = false);
      }
    }
  }

  void _copyDutyBreakdownSummary(BuildContext context, CustomsDutyBreakdownModel b) {
    final l = context.l10n;
    final sb = StringBuffer();
    sb.writeln('📋 ${l.hsCalculatorSectionHeader}');
    sb.writeln('🏷️ ${l.tariffHsCodeCol}: ${widget.tariff.hsCode}');
    sb.writeln('📝 ${l.tariffDescAndAuthorityCol}: ${widget.tariff.hsDescription}');
    sb.writeln('💰 ${l.hsCifValueLabel}: ${_cifValueCtrl.text}');
    sb.writeln('🚢 ${l.hsFreightValueLabel}: ${_freightCtrl.text}');
    sb.writeln('🌍 ${l.hsOriginCountryLabel}: $_selectedOriginCountry');
    sb.writeln('----------------------------------------');
    sb.writeln(l.hsImportDutyBreakdown(b.customsDutyRate, b.importDutyAmount.toStringAsFixed(2)));
    sb.writeln(l.hsVatBreakdown(b.vatRate, b.vatAmount.toStringAsFixed(2)));
    if (b.scheduleTaxAmount > 0) sb.writeln(l.hsScheduleBreakdown(b.scheduleTaxAmount.toStringAsFixed(2)));
    if (b.customsServiceFeeAmount > 0) sb.writeln(l.hsServiceFeeBreakdown(b.customsServiceFeeAmount.toStringAsFixed(2)));
    sb.writeln('========================================');
    sb.writeln(l.hsTotalTaxesAndFeesDue(b.totalTaxesAndFees.toStringAsFixed(2)));
    if (b.conditionsNote != null && b.conditionsNote!.isNotEmpty) {
      sb.writeln(l.hsNotePrefix(b.conditionsNote!));
    }
    CopyHelper.copy(context, sb.toString(), customMessage: l.hsExplorerCopyDutyBreakdownSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.hsCalculatorSectionHeader,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cifValueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.hsCifValueLabel,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: l.hsExplorerCopyCardRateTooltip,
                      onPressed: () => CopyHelper.copy(context, _cifValueCtrl.text),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _freightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.hsFreightValueLabel,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                      tooltip: l.hsExplorerCopyCardRateTooltip,
                      onPressed: () => CopyHelper.copy(context, _freightCtrl.text),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SearchableDropdownField<String>(
                  value: _selectedOriginCountry,
                  labelText: l.hsOriginCountryLabel,
                  items: [
                    SearchableDropdownItem(value: 'ITALY', label: l.hsOriginItalyEur1),
                    SearchableDropdownItem(value: 'GERMANY', label: l.hsOriginGermanyEur1),
                    SearchableDropdownItem(value: 'CHINA', label: l.hsOriginChinaGeneral),
                    SearchableDropdownItem(value: 'TURKEY', label: l.hsOriginTurkeyFta),
                    SearchableDropdownItem(value: 'BRAZIL', label: l.hsOriginBrazilMercosur),
                    SearchableDropdownItem(value: 'SERBIA', label: l.hsOriginSerbiaFta),
                    SearchableDropdownItem(value: 'UK', label: l.hsOriginUkPartnership),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedOriginCountry = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: l.hsCalculateDutyBtn,
                icon: Icons.calculate,
                isLoading: _isCalculating,
                variant: AppButtonVariant.primary,
                onPressed: _calculateDuty,
              ),
            ],
          ),
          if (_dutyBreakdown != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.hsTotalTaxesAndFeesDue(_dutyBreakdown!.totalTaxesAndFees.toStringAsFixed(2)),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                      if (_dutyBreakdown!.conditionsNote != null && _dutyBreakdown!.conditionsNote!.isNotEmpty) ...[
                        Chip(
                          label: Text(l.hsNotePrefix(_dutyBreakdown!.conditionsNote!)),
                          backgroundColor: Colors.white,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: Text(
                          l.hsExplorerCopyDutyBreakdownBtn,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _copyDutyBreakdownSummary(context, _dutyBreakdown!),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.hsImportDutyBreakdown(_dutyBreakdown!.customsDutyRate, _dutyBreakdown!.importDutyAmount.toStringAsFixed(2))),
                      Text(l.hsVatBreakdown(_dutyBreakdown!.vatRate, _dutyBreakdown!.vatAmount.toStringAsFixed(2))),
                      Text(l.hsScheduleBreakdown(_dutyBreakdown!.scheduleTaxAmount.toStringAsFixed(2))),
                      Text(l.hsServiceFeeBreakdown(_dutyBreakdown!.customsServiceFeeAmount.toStringAsFixed(2))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
