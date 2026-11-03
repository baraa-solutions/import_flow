import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../freight_booking/l10n/air_lcl_l10n.dart';
import 'dual_divisor_selector_card.dart';
import 'volumetric_weight_comparison_tile.dart';

/// Reusable Air Freight IATA Volumetric & Chargeable Weight Calculator Component.
/// Strict adherence to:
/// - Root wrapped in SelectionArea
/// - Pure language separation (no mixing Arabic and English in parentheses)
/// - Unified widgets: AppButton, CustomTextField, AppStatusBadge, AppTheme.cardDecorationOf
/// - Safe clipboard copying via CopyHelper.copy
/// - Dual Divisor support (IATA 6000 vs Express Courier 5000)
class AirFreightCalculatorWidget extends StatefulWidget {
  final double? initialGrossWeightKg;
  final ValueChanged<double>? onWeightApplied;

  const AirFreightCalculatorWidget({
    super.key,
    this.initialGrossWeightKg,
    this.onWeightApplied,
  });

  @override
  State<AirFreightCalculatorWidget> createState() => _AirFreightCalculatorWidgetState();
}

class _AirFreightCalculatorWidgetState extends State<AirFreightCalculatorWidget> {
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  AirFreightDivisorMode _divisorMode = AirFreightDivisorMode.generalAir;

  double? _calculatedVolumetricKg;
  double? _calculatedChargeableKg;
  double? _calculatedCbm;
  double? _actualGrossTotalKg;
  bool _isHigherVolumetric = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialGrossWeightKg != null && widget.initialGrossWeightKg! > 0) {
      _grossWeightController.text = widget.initialGrossWeightKg!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _grossWeightController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _calculate() {
    final length = double.tryParse(_lengthController.text.trim()) ?? 0.0;
    final width = double.tryParse(_widthController.text.trim()) ?? 0.0;
    final height = double.tryParse(_heightController.text.trim()) ?? 0.0;
    final grossPerUnit = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;

    if (length <= 0 || width <= 0 || height <= 0 || quantity <= 0) {
      return;
    }

    // Dynamic formula based on selected divisor: (L * W * H cm) / divisor
    final divisor = _divisorMode.divisor;
    final volPerUnit = (length * width * height) / divisor;
    final totalVolumetric = volPerUnit * quantity;
    final totalGross = grossPerUnit * quantity;
    final totalCbm = ((length * width * height) / 1000000.0) * quantity;
    final chargeable = totalGross > totalVolumetric ? totalGross : totalVolumetric;

    setState(() {
      _calculatedVolumetricKg = double.parse(totalVolumetric.toStringAsFixed(2));
      _actualGrossTotalKg = double.parse(totalGross.toStringAsFixed(2));
      _calculatedChargeableKg = double.parse(chargeable.toStringAsFixed(2));
      _calculatedCbm = double.parse(totalCbm.toStringAsFixed(4));
      _isHigherVolumetric = totalVolumetric > totalGross;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: Container(
        decoration: AppTheme.cardDecorationOf(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.airVolumetricCalcTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.flatCharcoal,
                    ),
                  ),
                ),
                AppStatusBadge(
                  label: _divisorMode.title(l.isArabic),
                  severity: AppSeverity.info,
                  icon: _divisorMode.isGeneralAir ? Icons.flight_takeoff : Icons.local_shipping_outlined,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DualDivisorSelectorCard(
              selectedMode: _divisorMode,
              onModeChanged: (mode) {
                setState(() => _divisorMode = mode);
                _calculate();
              },
              showDensityExplanation: true,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _lengthController,
                    label: l.lengthCmLabel,
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomTextField(
                    controller: _widthController,
                    label: l.widthCmLabel,
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomTextField(
                    controller: _heightController,
                    label: l.heightCmLabel,
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _grossWeightController,
                    label: l.grossWeightKgLabel,
                    hint: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomTextField(
                    controller: _quantityController,
                    label: l.packageQuantityLabel,
                    hint: '1',
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                AppButton(
                  label: l.calculateWeightBtn,
                  icon: Icons.sync,
                  variant: AppButtonVariant.primary,
                  onPressed: _calculate,
                ),
                if (_calculatedChargeableKg != null && widget.onWeightApplied != null) ...[
                  const SizedBox(width: 10),
                  AppButton(
                    label: l.applyChargeableWeightToBooking,
                    icon: Icons.check,
                    variant: AppButtonVariant.success,
                    onPressed: () {
                      widget.onWeightApplied!(_calculatedChargeableKg!);
                    },
                  ),
                ],
              ],
            ),
            if (_calculatedChargeableKg != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              VolumetricWeightComparisonTile(
                actualGrossWeightKg: _actualGrossTotalKg ?? 0.0,
                totalCbm: _calculatedCbm ?? 0.0,
                activeMode: _divisorMode,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _metricPill(
                    context,
                    label: l.grossWeightKgLabel,
                    value: '${_actualGrossTotalKg ?? 0.0} ${l.unitKg}',
                    icon: Icons.fitness_center,
                  ),
                  _metricPill(
                    context,
                    label: l.volumetricWeightResult,
                    value: '$_calculatedVolumetricKg ${l.unitKg}',
                    icon: Icons.view_in_ar,
                  ),
                  _metricPill(
                    context,
                    label: l.chargeableWeightResult,
                    value: '$_calculatedChargeableKg ${l.unitKg}',
                    icon: Icons.price_check,
                    highlight: true,
                  ),
                  _metricPill(
                    context,
                    label: l.totalCbmResult,
                    value: '$_calculatedCbm ${l.unitCbm}',
                    icon: Icons.straighten,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isHigherVolumetric
                      ? AppTheme.flatOrange.withValues(alpha: 0.08)
                      : AppTheme.flatEmerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isHigherVolumetric
                        ? AppTheme.flatOrange.withValues(alpha: 0.3)
                        : AppTheme.flatEmerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isHigherVolumetric ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: _isHigherVolumetric ? AppTheme.flatOrange : AppTheme.flatEmerald,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isHigherVolumetric ? l.higherVolumetricNotice : l.higherGrossNotice,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isHigherVolumetric ? AppTheme.flatOrange : AppTheme.flatEmerald,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricPill(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? AppTheme.cobalt.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: highlight ? AppTheme.cobalt.withValues(alpha: 0.4) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: highlight ? AppTheme.cobalt : Colors.grey.shade700),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: highlight ? AppTheme.cobalt : AppTheme.flatCharcoal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
