import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/freight_quotation_model.dart';
import '../providers/freight_quotations_provider.dart';

class FreightRfqDetailsDialog {
  static void show(
    BuildContext context,
    WidgetRef ref, {
    required FreightRFQRequestModel rfq,
  }) {
    final isArabic = context.l10n.isArabic;
    showDialog(
      context: context,
      builder: (context) {
        return SelectionArea(
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.directions_boat, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'تفاصيل طلب عرض أسعار الشحن: ${rfq.rfqCode}'
                        : 'Freight RFQ Details: ${rfq.rfqCode}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                AppStatusBadge.fromStatus(status: rfq.status),
              ],
            ),
            content: SizedBox(
              width: 750,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${isArabic ? "العنوان:" : "Title:"} ${rfq.title}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text(
                              '${isArabic ? "وسيلة الشحن:" : "Method:"} ${rfq.shippingMethod} | CRD: ${rfq.crdDate}'),
                          const SizedBox(height: 4),
                          Text(
                              '${isArabic ? "من:" : "From:"} ${rfq.polName} ➔ ${isArabic ? "إلى:" : "To:"} ${rfq.podName}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            data: MetricCardData(
                              title: isArabic ? 'أقل نولون شحن' : 'Lowest Freight',
                              value: '\$${rfq.lowestFreightCost}',
                              icon: Icons.attach_money,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricCard(
                            data: MetricCardData(
                              title: isArabic ? 'متوسط نولون الشحن' : 'Average Freight',
                              value: '\$${rfq.averageFreightCost}',
                              icon: Icons.trending_up,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricCard(
                            data: MetricCardData(
                              title: isArabic ? 'أسرع ترانزيت' : 'Fastest Transit',
                              value: '${rfq.fastestTransitDays} ${isArabic ? "أيام" : "Days"}',
                              icon: Icons.speed,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricCard(
                            data: MetricCardData(
                              title: isArabic ? 'العرض المعتمد' : 'Awarded Carrier',
                              value: rfq.awardedProviderName ??
                                  (isArabic ? 'لم يعتمد بعد' : 'Not awarded yet'),
                              icon: Icons.verified,
                              color: AppTheme.cobalt,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isArabic
                          ? 'عروض أسعار الناقلين والمقارنة التفصيلية (Quotations List):'
                          : 'Carrier Quotations & Detailed Comparison (Quotations List):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(1.5),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                      },
                      children: [
                        TableRow(
                          decoration:
                              BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.05)),
                          children: [
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(isArabic ? 'الحالة / القرار' : 'Status / Decision',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                    isArabic
                                        ? 'الخط الملاحي / السفينة'
                                        : 'Carrier / Vessel',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(isArabic ? 'إجمالي التكلفة' : 'Total Cost',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(isArabic ? 'الترانزيت' : 'Transit',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(isArabic ? 'أيام السماح' : 'Free Days',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        ...rfq.quotations.map(
                          (q) => TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: q.isAwarded
                                    ? Chip(
                                        label: Text(isArabic ? 'المعتمد 🎯' : 'Awarded 🎯',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 10)),
                                        backgroundColor: AppTheme.emerald)
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.cobalt,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2)),
                                        onPressed: () async {
                                          final nav = Navigator.of(context);
                                          await ref
                                              .read(freightQuotationsProvider.notifier)
                                              .awardQuotation(rfq.rfqId, q.quotationId!);
                                          nav.pop();
                                        },
                                        child: Text(isArabic ? 'اعتماد هذا العرض' : 'Award Quote',
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 10)),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(q.providerName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (q.vesselName != null)
                                      Text(
                                          '${isArabic ? "السفينة:" : "Vessel:"} ${q.vesselName}',
                                          style: const TextStyle(
                                              fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('\$${q.totalCost}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, color: Colors.green))),
                              Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('${q.transitDays} ${isArabic ? "يوم" : "d"}',
                                      style: const TextStyle(fontSize: 11))),
                              Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('${q.freeDaysAtPod} ${isArabic ? "يوم" : "d"}',
                                      style: const TextStyle(fontSize: 11))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isArabic ? 'إغلاق' : 'Close')),
            ],
          ),
        );
      },
    );
  }
}
