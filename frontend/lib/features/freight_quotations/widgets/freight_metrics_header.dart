import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';

class FreightMetricsHeader extends StatelessWidget {
  final double lowestCost;
  final int fastestTransit;
  final int carrierQuotesCount;
  final bool isSaving;
  final VoidCallback? onSaveRFQ;

  const FreightMetricsHeader({
    super.key,
    required this.lowestCost,
    required this.fastestTransit,
    required this.carrierQuotesCount,
    required this.isSaving,
    required this.onSaveRFQ,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;

    return Row(
      children: [
        Expanded(
          child: MetricCard(
            data: MetricCardData(
              title: isArabic ? 'أقل سعر شحن متوفر' : 'Lowest Freight Rate',
              value: '\$$lowestCost',
              icon: Icons.attach_money,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricCard(
            data: MetricCardData(
              title: isArabic ? 'أسرع زمن ترانزيت' : 'Fastest Transit Time',
              value: '$fastestTransit ${isArabic ? 'أيام' : 'Days'}',
              icon: Icons.speed,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricCard(
            data: MetricCardData(
              title: isArabic ? 'عدد عروض الناقلين' : 'Carrier Quotes Count',
              value: '$carrierQuotesCount',
              icon: Icons.analytics_outlined,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 16),
        AppButton(
          label: isArabic ? 'حفظ وتثبيت طلب مقارنة النولون' : 'Save & Pin Freight RFQ',
          variant: AppButtonVariant.success,
          icon: Icons.save,
          isLoading: isSaving,
          onPressed: isSaving ? null : onSaveRFQ,
        ),
      ],
    );
  }
}
