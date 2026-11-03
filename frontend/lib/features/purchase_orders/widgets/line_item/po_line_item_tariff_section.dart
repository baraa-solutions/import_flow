import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';

class POLineItemTariffSection extends StatelessWidget {
  final int? tariffId;
  final double? dutyRate;
  final double? vatRate;
  final List<SearchableDropdownItem<int?>> tariffItems;
  final ValueChanged<int?> onTariffChanged;
  final bool isArabic;

  const POLineItemTariffSection({
    super.key,
    required this.tariffId,
    required this.dutyRate,
    required this.vatRate,
    required this.tariffItems,
    required this.onTariffChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SearchableDropdownField<int?>(
            value: tariffId,
            labelText: isArabic
                ? 'بند التعريفة الجمركية (HS Code)'
                : 'Customs Tariff (HS Code)',
            searchHintText: isArabic
                ? 'ابحث برقم البند أو الوصف...'
                : 'Search HS code or description...',
            items: tariffItems,
            onChanged: onTariffChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.charcoalSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cloudWhite),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'الرسوم المقدرة' : 'Estimated Duties',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Duty: ${dutyRate != null ? "${(dutyRate! * 100).toStringAsFixed(1)}%" : "--"} | VAT: ${vatRate != null ? "${(vatRate! * 100).toStringAsFixed(1)}%" : "--"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
