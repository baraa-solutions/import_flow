import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/trade_finance_model.dart';

class BankChargesTab extends StatelessWidget {
  final List<BankCharge> charges;

  const BankChargesTab({super.key, required this.charges});

  @override
  Widget build(BuildContext context) {
    final totalEgp = charges.fold<double>(0.0, (sum, item) => sum + item.amountEgp);

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
                  Icon(Icons.receipt_long_outlined, color: AppTheme.cobalt, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'بيان العمولات والمصروفات البنكية ومصاريف السويفت',
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
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(
                  'إجمالي المصروفات: ${totalEgp.toStringAsFixed(2)} جنيه مصري',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (charges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  'لا توجد مصروفات أو عمولات بنكية مسجلة لهذا الاعتماد حتى الآن',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            Table(
              border: TableBorder.all(color: Colors.grey.shade200),
              columnWidths: const {
                0: FlexColumnWidth(2.5),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(2.0),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    _TableHeaderCell('نوع المصروف البنكي'),
                    _TableHeaderCell('المبلغ الأصلي'),
                    _TableHeaderCell('المعادل بالجنيه'),
                    _TableHeaderCell('تاريخ الخصم'),
                    _TableHeaderCell('رقم مرجع السويفت'),
                  ],
                ),
                ...charges.map(
                  (c) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(
                          c.localizedChargeType,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(
                          '${c.amount.toStringAsFixed(2)} ${c.currency}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(
                          '${c.amountEgp.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(
                          c.debitDate,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: c.swiftReference != null && c.swiftReference!.isNotEmpty
                            ? InkWell(
                                onTap: () => CopyHelper.copy(
                                  context,
                                  c.swiftReference!,
                                  customMessage: 'تم نسخ مرجع السويفت',
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.copy_outlined, size: 12, color: AppTheme.cobalt),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.swiftReference!,
                                      style: const TextStyle(color: AppTheme.cobalt, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : const Text('-', style: TextStyle(fontSize: 13)),
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

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
      ),
    );
  }
}
