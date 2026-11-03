import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../models/trade_finance_model.dart';

class FxVarianceSummaryCard extends StatelessWidget {
  final List<FxVarianceRecord> fxRecords;

  const FxVarianceSummaryCard({super.key, required this.fxRecords});

  @override
  Widget build(BuildContext context) {
    final netVariance = fxRecords.fold<double>(0.0, (sum, item) => sum + item.varianceAmountEgp);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.currency_exchange, color: AppTheme.cobalt, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'تقييم عقود التحوط وفروق أسعار صرف العملة الأجنبية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: netVariance > 0
                      ? Colors.red.shade50
                      : (netVariance < 0 ? Colors.green.shade50 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: netVariance > 0
                        ? Colors.red.shade300
                        : (netVariance < 0 ? Colors.green.shade300 : Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  netVariance > 0
                      ? 'صافي خسائر فروق عملة: ${netVariance.toStringAsFixed(2)} ج.م'
                      : (netVariance < 0
                          ? 'صافي وفورات فروق عملة: ${(netVariance.abs()).toStringAsFixed(2)} ج.م'
                          : 'تعادل سعري تام'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: netVariance > 0
                        ? AppTheme.crimson
                        : (netVariance < 0 ? Colors.green.shade900 : AppTheme.charcoal),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (fxRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  'لم يتم تسجيل قيود تحوط أو تسوية لفروق العملة لهذا الاعتماد حتى الآن',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ...fxRecords.map(
              (rec) => Card(
                elevation: 0,
                color: Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المبلغ: ${rec.originalAmount.toStringAsFixed(2)} ${rec.foreignCurrency}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          AppStatusBadge(
                            label: rec.localizedNature,
                            severity: rec.varianceAmountEgp > 0
                                ? AppSeverity.danger
                                : (rec.varianceAmountEgp < 0 ? AppSeverity.success : AppSeverity.info),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCol(
                              'سعر الحجز عند الفتح',
                              '${rec.bookingRate.toStringAsFixed(4)} ج.م (${rec.bookingDate})',
                              'الإجمالي: ${rec.bookingTotalEgp.toStringAsFixed(2)} ج.م',
                            ),
                          ),
                          Expanded(
                            child: _buildInfoCol(
                              'سعر السداد الفعلي للبنك',
                              rec.settlementRate != null
                                  ? '${rec.settlementRate!.toStringAsFixed(4)} ج.م (${rec.settlementDate ?? "-"})'
                                  : 'قيد الانتظار حتى السداد',
                              rec.settlementTotalEgp != null
                                  ? 'الإجمالي: ${rec.settlementTotalEgp!.toStringAsFixed(2)} ج.م'
                                  : '-',
                            ),
                          ),
                          Expanded(
                            child: _buildInfoCol(
                              'عقد التحوط وفروق العملة',
                              rec.hedgingContractRef ?? 'تحوط ذاتي بدون عقد خارجي',
                              'الفارق: ${rec.varianceAmountEgp.toStringAsFixed(2)} ج.م',
                              isHighlight: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String mainVal, String subVal, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          mainVal,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isHighlight ? AppTheme.cobalt : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subVal,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
