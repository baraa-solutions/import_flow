import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../po_decimal_field.dart';

class POLineItemLogisticsSection extends StatelessWidget {
  final TextEditingController cbmPerUnitController;
  final TextEditingController netWeightController;
  final TextEditingController grossWeightController;
  final double calculatedTotalCbm;
  final double calculatedTotalGrossWeight;
  final VoidCallback onValuesChanged;
  final bool isArabic;

  const POLineItemLogisticsSection({
    super.key,
    required this.cbmPerUnitController,
    required this.netWeightController,
    required this.grossWeightController,
    required this.calculatedTotalCbm,
    required this.calculatedTotalGrossWeight,
    required this.onValuesChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cloudWhite),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.scale_rounded, size: 16, color: AppTheme.cobalt),
              const SizedBox(width: 6),
              Text(
                isArabic
                    ? 'الأوزان والأحجام اللوجستية (تعبئة تلقائية من الكاتالوج)'
                    : 'Logistics Weights & Dimensions (Auto-filled)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: cbmPerUnitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [PoDecimalField.decimalFormatter(4)],
                  decoration: InputDecoration(
                    labelText: isArabic ? 'الحجم للوحدة (CBM)' : 'CBM / Unit',
                    isDense: true,
                  ),
                  onChanged: (_) => onValuesChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: netWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [PoDecimalField.decimalFormatter(4)],
                  decoration: InputDecoration(
                    labelText: isArabic ? 'الوزن الصافي (KG)' : 'Net Wt / Unit (KG)',
                    isDense: true,
                  ),
                  onChanged: (_) => onValuesChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: grossWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [PoDecimalField.decimalFormatter(4)],
                  decoration: InputDecoration(
                    labelText: isArabic ? 'الوزن القائم (KG)' : 'Gross Wt / Unit (KG)',
                    isDense: true,
                  ),
                  onChanged: (_) => onValuesChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: [
              Text(
                '${isArabic ? "إجمالي الحجم:" : "Total CBM:"} ${calculatedTotalCbm.toStringAsFixed(4)} m³',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '${isArabic ? "إجمالي الوزن القائم:" : "Total Gross Wt:"} ${calculatedTotalGrossWeight.toStringAsFixed(2)} kg',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
