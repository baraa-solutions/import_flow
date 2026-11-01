import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/broker_custody_model.dart';

class BrokerCustodyReconciliationDialog extends StatelessWidget {
  final SettlementReconciliationModel reconciliation;
  final VoidCallback onDismissed;

  const BrokerCustodyReconciliationDialog({
    super.key,
    required this.reconciliation,
    required this.onDismissed,
  });

  static Future<void> show(
    BuildContext context, {
    required SettlementReconciliationModel reconciliation,
    required VoidCallback onDismissed,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => BrokerCustodyReconciliationDialog(
        reconciliation: reconciliation,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.emerald),
          const SizedBox(width: 8),
          Text('تقرير التسوية والمقاصة النهائية — ${reconciliation.advanceCode}'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reconciliation.reconciliationSummary,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.5),
              ),
              const Divider(height: 24),
              _buildSummaryRow('قيمة العهدة المصروفة:', '${reconciliation.advanceAmount.toStringAsFixed(2)} ج.م', AppTheme.cobalt),
              _buildSummaryRow('إجمالي المصروفات المطالب بها:', '${reconciliation.totalExpensesClaimed.toStringAsFixed(2)} ج.م', Colors.black87),
              _buildSummaryRow('ضريبة الخصم والإضافة المستقطعة (1% نموذج 41):', '${reconciliation.totalTaxWithheldW41.toStringAsFixed(2)} ج.م', AppTheme.orange),
              _buildSummaryRow('صافي المستحق تسويته:', '${reconciliation.totalNetSettled.toStringAsFixed(2)} ج.م', Colors.blueGrey.shade800),
              const Divider(height: 16),
              _buildSummaryRow(
                reconciliation.balanceRemaining >= 0 ? 'المتبقي طرف المخلص (واجب الرد):' : 'مستحق للمخلص (واجب الصرف):',
                '${reconciliation.balanceRemaining.abs().toStringAsFixed(2)} ج.م',
                reconciliation.balanceRemaining >= 0 ? AppTheme.emerald : AppTheme.crimson,
              ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: 'تم والعودة',
          variant: AppButtonVariant.primary,
          onPressed: () {
            Navigator.of(context).pop();
            onDismissed();
          },
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12.5)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
