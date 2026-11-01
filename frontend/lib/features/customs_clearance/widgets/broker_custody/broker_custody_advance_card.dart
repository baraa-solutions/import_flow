import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/broker_custody_model.dart';

class BrokerCustodyAdvanceCard extends StatelessWidget {
  final BrokerCustodyAdvanceModel advance;
  final ValueChanged<BrokerCustodyAdvanceModel> onAddExpense;
  final ValueChanged<BrokerCustodyAdvanceModel> onSettleAdvance;
  final ValueChanged<BrokerExpenseItemModel> onApproveItem;
  final AppSeverity Function(String status) statusSeverity;

  const BrokerCustodyAdvanceCard({
    super.key,
    required this.advance,
    required this.onAddExpense,
    required this.onSettleAdvance,
    required this.onApproveItem,
    required this.statusSeverity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Text(
                  advance.advanceCode,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.cobalt),
                ),
                const SizedBox(width: 8),
                Text(
                  'المخلص: ${advance.brokerName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 8),
                AppStatusBadge(
                  label: advance.statusLabelAr,
                  severity: statusSeverity(advance.status),
                ),
                const Spacer(),
                Text(
                  'العهدة: ${advance.advanceAmount.toStringAsFixed(2)} ج.م | المسوّى: ${advance.settledAmount.toStringAsFixed(2)} ج.م | المتبقي: ${advance.remainingBalance.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: 'إضافة مصروف',
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => onAddExpense(advance),
                ),
                const SizedBox(width: 6),
                AppButton(
                  label: 'تسوية ومقاصة',
                  icon: Icons.done_all_rounded,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => onSettleAdvance(advance),
                ),
              ],
            ),
          ),
          if (advance.expenseItems.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: advance.expenseItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, iIdx) {
                final item = advance.expenseItems[iIdx];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.categoryLabelAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            if (item.receiptReference != null)
                              Text('مستند: ${item.receiptReference}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      if (item.isEInvoiceBacked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                          child: const Text('فاتورة إلكترونية ✔', style: TextStyle(color: Colors.green, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 12),
                      Text('الإجمالي: ${item.amount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('خصم 1%: ${item.taxWithheldAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12, color: AppTheme.crimson)),
                      const SizedBox(width: 12),
                      Text('الصافي: ${item.netSettledAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                      const SizedBox(width: 12),
                      AppStatusBadge(
                        label: item.approvalStatus == 'APPROVED' ? 'معتمد' : 'قيد المراجعة',
                        severity: item.approvalStatus == 'APPROVED' ? AppSeverity.success : AppSeverity.warning,
                      ),
                      if (item.approvalStatus != 'APPROVED') ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 20),
                          tooltip: 'اعتماد البند',
                          onPressed: () => onApproveItem(item),
                        ),
                      ],
                    ],
                  ),
                );
              },
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('لم يتم تسجيل أي بنود مصروفات لهذه العهدة بعد', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
