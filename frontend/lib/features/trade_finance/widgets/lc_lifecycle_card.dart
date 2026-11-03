import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/trade_finance_model.dart';

class LcLifecycleCard extends StatelessWidget {
  final FinanceInstrument? instrument;

  const LcLifecycleCard({super.key, required this.instrument});

  @override
  Widget build(BuildContext context) {
    if (instrument == null) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'لم يتم تحديد أو تسجيل اعتماد مستندي لهذه الشحنة حتى الآن',
            style: TextStyle(color: AppTheme.charcoal, fontSize: 14),
          ),
        ),
      );
    }

    final inst = instrument!;

    return Container(
      padding: const EdgeInsets.all(20.0),
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
              const Icon(Icons.account_balance, color: AppTheme.cobalt, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inst.localizedType,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
              AppStatusBadge.fromStatus(
                status: inst.status,
                label: inst.localizedStatus,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  context,
                  label: 'رقم المعاملة البنكية',
                  value: inst.instrumentNumber,
                  isCopyable: true,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  context,
                  label: 'القيمة المالية الإجمالية',
                  value: '${inst.amount.toStringAsFixed(2)} ${inst.currency}',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  context,
                  label: 'البنك المصدر',
                  value: inst.issuingBank,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  context,
                  label: 'البنك المراسل أو المعزز',
                  value: inst.advisingBank ?? 'غير محدد',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  context,
                  label: 'تاريخ الفتح والإصدار',
                  value: inst.issueDate ?? 'غير محدد',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  context,
                  label: 'تاريخ انتهاء الصلاحية',
                  value: inst.expiryDate ?? 'غير محدد',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  context,
                  label: 'آخر موعد للشحن',
                  value: inst.shipmentDeadline ?? 'غير محدد',
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  context,
                  label: 'مهلة تقديم المستندات',
                  value: '${inst.presentationPeriodDays} يوماً',
                ),
              ),
            ],
          ),
          if (inst.paymentTerms != null && inst.paymentTerms!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'شروط الدفع والتعزيز: ${inst.paymentTerms!}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.charcoal),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required String label,
    required String value,
    bool isCopyable = false,
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
              customMessage: 'تم نسخ $label بنجاح',
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.charcoal,
            ),
          ),
      ],
    );
  }
}
