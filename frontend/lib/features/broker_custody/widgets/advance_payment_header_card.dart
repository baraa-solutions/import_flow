import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/broker_custody_model.dart';

class AdvancePaymentHeaderCard extends StatelessWidget {
  final CustomsBrokerAdvanceModel advance;

  const AdvancePaymentHeaderCard({super.key, required this.advance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: AppTheme.cobalt, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'عهدة المخلص الجمركي: ${advance.brokerName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
              AppStatusBadge.fromStatus(
                status: advance.status,
                label: advance.localizedStatus,
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDetailColumn(
                  context,
                  label: 'كود العهدة المصروفة',
                  value: advance.advanceCode,
                  isCopyable: true,
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  context,
                  label: 'مبلغ العهدة الأصلي',
                  value: '${advance.advanceAmount.toStringAsFixed(2)} ج.م',
                  isBold: true,
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  context,
                  label: 'تاريخ الصرف الفعلي',
                  value: advance.disbursementDate,
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  context,
                  label: 'طريقة الصرف',
                  value: advance.localizedPaymentMethod,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailColumn(
    BuildContext context, {
    required String label,
    required String value,
    bool isCopyable = false,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        if (isCopyable)
          InkWell(
            onTap: () => CopyHelper.copy(
              context,
              value,
              customMessage: 'تم نسخ كود العهدة',
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_outlined, size: 14, color: AppTheme.cobalt),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: AppTheme.charcoal,
            ),
          ),
      ],
    );
  }
}
