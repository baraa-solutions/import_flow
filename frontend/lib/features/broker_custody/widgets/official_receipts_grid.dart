import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/broker_custody_model.dart';

class OfficialReceiptsGrid extends StatelessWidget {
  final List<BrokerSettlementReceiptModel> receipts;

  const OfficialReceiptsGrid({super.key, required this.receipts});

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'لم يتم تقديم أو تسجيل أي إيصالات رسمية لتسوية هذه العهدة حتى الآن',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.receipt, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Text(
                  'قائمة الإيصالات الرسمية وفواتير الأتعاب المقدمة (${receipts.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Table(
            border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200)),
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.2),
              4: FlexColumnWidth(1.2),
              5: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: const [
                  _GridHeaderCell('نوع الإيصال والجهة المصدرة'),
                  _GridHeaderCell('رقم الإيصال'),
                  _GridHeaderCell('المبلغ الإجمالي'),
                  _GridHeaderCell('ضريبة الخصم 1%'),
                  _GridHeaderCell('الصافي المسدد'),
                  _GridHeaderCell('حالة التدقيق'),
                ],
              ),
              ...receipts.map(
                (r) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.localizedReceiptType,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.issuingEntity,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: InkWell(
                        onTap: () => CopyHelper.copy(
                          context,
                          r.receiptNumber,
                          customMessage: 'تم نسخ رقم الإيصال',
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy_outlined, size: 12, color: AppTheme.cobalt),
                            const SizedBox(width: 4),
                            Text(
                              r.receiptNumber,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.cobalt,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: Text(
                        '${r.amount.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: Text(
                        '${r.taxWithheldAmount.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(fontSize: 12, color: AppTheme.crimson),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: Text(
                        '${r.netAmount.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: AppStatusBadge(
                        label: r.localizedStatus,
                        severity: r.verificationStatus == 'VERIFIED'
                            ? AppSeverity.success
                            : (r.verificationStatus == 'REJECTED'
                                ? AppSeverity.danger
                                : AppSeverity.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridHeaderCell extends StatelessWidget {
  final String title;
  const _GridHeaderCell(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
      ),
    );
  }
}
