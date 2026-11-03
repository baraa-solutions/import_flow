import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/container_deposit_model.dart';

class DepositLedgerCard extends StatelessWidget {
  final ContainerDepositModel item;
  final VoidCallback onRecordEir;
  final VoidCallback onEditEir;
  final VoidCallback onDispute;
  final VoidCallback onRecordRefund;

  const DepositLedgerCard({
    super.key,
    required this.item,
    required this.onRecordEir,
    required this.onEditEir,
    required this.onDispute,
    required this.onRecordRefund,
  });

  AppSeverity _refundStatusSeverity(DepositRefundStatus status) {
    switch (status) {
      case DepositRefundStatus.overdue30Days:
        return AppSeverity.danger;
      case DepositRefundStatus.pendingReturn:
        return AppSeverity.warning;
      case DepositRefundStatus.claimSubmitted:
        return AppSeverity.info;
      case DepositRefundStatus.refundedFull:
      case DepositRefundStatus.refundedPartial:
        return AppSeverity.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.daysOverdue > 0 ? AppTheme.crimson.withValues(alpha: 0.5) : Colors.grey.shade300,
          width: item.daysOverdue > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Icon Badge
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: item.daysOverdue > 0 ? AppTheme.crimson.withValues(alpha: 0.12) : Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: item.daysOverdue > 0 ? AppTheme.crimson : AppTheme.cobalt,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  item.containerType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.daysOverdue > 0 ? AppTheme.crimson : AppTheme.cobalt,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Main Details
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.containerNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.cobalt),
                    ),
                    const SizedBox(width: 8),
                    AppStatusBadge(
                      label: item.refundStatus.labelAr,
                      severity: _refundStatusSeverity(item.refundStatus),
                    ),
                    if (item.daysOverdue > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.crimson.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'متأخر ${item.daysOverdue} يوم',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'الخط الملاحي: ${item.carrierName} | التأمين المدفوع: ${item.depositAmountEgp.toStringAsFixed(2)} ج.م | تاريخ الدفع: ${item.paymentDate}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                Row(
                  children: [
                    if (item.eirReturnNumber != null) ...[
                      const Icon(Icons.assignment_turned_in_outlined, size: 14, color: Colors.green),
                      const SizedBox(width: 3),
                      Text('EIR: ${item.eirReturnNumber} (${item.eirReturnDate})', style: const TextStyle(fontSize: 11, color: Colors.green)),
                      const SizedBox(width: 10),
                      Text('الحالة: ${item.containerCondition.labelAr}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      const SizedBox(width: 10),
                    ],
                    if (item.deductionAmountEgp > 0) ...[
                      const Icon(Icons.money_off_rounded, size: 14, color: AppTheme.crimson),
                      const SizedBox(width: 3),
                      Text('خصم: ${item.deductionAmountEgp.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 11, color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                    ],
                    if (item.refundChequeOrTransferNo != null) ...[
                      const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.emerald),
                      const SizedBox(width: 3),
                      Text('مسترد: شيك/تحويل ${item.refundChequeOrTransferNo}', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Operations Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.eirReturnNumber == null)
                AppButton(
                  label: 'تسجيل EIR',
                  icon: Icons.assignment_outlined,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: onRecordEir,
                )
              else ...[
                AppButton(
                  label: 'تعديل EIR',
                  icon: Icons.edit_note_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onEditEir,
                ),
                const SizedBox(width: 6),
                if (item.deductionAmountEgp > 0) ...[
                  AppButton(
                    label: 'اعتراض خصم',
                    icon: Icons.gavel_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: onDispute,
                  ),
                  const SizedBox(width: 6),
                ],
                if (item.refundChequeOrTransferNo == null)
                  AppButton(
                    label: 'استلام الاسترداد',
                    icon: Icons.payments_outlined,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    onPressed: onRecordRefund,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
