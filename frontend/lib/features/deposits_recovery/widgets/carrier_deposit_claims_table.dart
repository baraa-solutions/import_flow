import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker_field.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../deposits_recovery_provider.dart';

class CarrierDepositClaimsTable extends ConsumerWidget {
  final List<RefundableDepositModel> deposits;

  const CarrierDepositClaimsTable({super.key, required this.deposits});

  void _showLinkEirDialog(BuildContext context, WidgetRef ref, RefundableDepositModel deposit) {
    final eirController = TextEditingController(text: deposit.eirNumber ?? '');
    final containerController = TextEditingController(text: deposit.containerNumber ?? '');
    DateTime? returnDate = deposit.eirReturnDate != null ? DateTime.tryParse(deposit.eirReturnDate!) : DateTime.now();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SelectionArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ربط إيصال استرجاع الحاوية الفارغة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('الخط الملاحي: ${deposit.beneficiaryName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Divider(height: 20),
                    TextField(
                      controller: containerController,
                      decoration: const InputDecoration(labelText: 'رقم الحاوية'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: eirController,
                      decoration: const InputDecoration(labelText: 'رقم إيصال تبادل المعدات'),
                    ),
                    const SizedBox(height: 12),
                    AppDatePickerField(
                      label: 'تاريخ إعادة الحاوية الفارغة للمستودع',
                      value: returnDate,
                      onChanged: (d) => setDialogState(() => returnDate = d),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'حالة الحاوية وملاحظات المعاينة'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(label: 'إلغاء', variant: AppButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop()),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'تأكيد وربط الإيصال',
                          variant: AppButtonVariant.primary,
                          onPressed: () async {
                            if (returnDate == null || eirController.text.trim().isEmpty) return;
                            await ref.read(depositsRecoveryActionsProvider).linkEir(
                                  deposit.id,
                                  containerController.text.trim(),
                                  eirController.text.trim(),
                                  returnDate!.toIso8601String().substring(0, 10),
                                  notesController.text.trim(),
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSettleDialog(BuildContext context, WidgetRef ref, RefundableDepositModel deposit) {
    final refundedController = TextEditingController(text: deposit.depositAmount.toStringAsFixed(2));
    final deductionController = TextEditingController(text: '0.00');
    final refController = TextEditingController();
    final reasonController = TextEditingController();
    DateTime? refundDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SelectionArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تسوية استرداد تأمين الحاوية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('قيمة التأمين الأصلية: ${deposit.depositAmount.toStringAsFixed(2)} جنيه', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: refundedController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'المبلغ المسترد فعلياً'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: deductionController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'مبلغ الاستقطاع'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppDatePickerField(
                      label: 'تاريخ الاسترداد',
                      value: refundDate,
                      onChanged: (d) => setDialogState(() => refundDate = d),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(labelText: 'رقم التحويل البنكي أو إشعار الإيداع'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(labelText: 'سبب الاستقطاع إن وجد (نظافة / إصلاح)'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(label: 'إلغاء', variant: AppButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop()),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'اعتماد التسوية المالية',
                          variant: AppButtonVariant.primary,
                          onPressed: () async {
                            final refAmt = double.tryParse(refundedController.text.trim()) ?? 0.0;
                            final dedAmt = double.tryParse(deductionController.text.trim()) ?? 0.0;
                            if (refundDate == null) return;
                            await ref.read(depositsRecoveryActionsProvider).settleRefund(
                                  deposit.id,
                                  {
                                    'refunded_amount': refAmt,
                                    'deduction_amount': dedAmt,
                                    'refund_date': refundDate!.toIso8601String().substring(0, 10),
                                    'refund_reference': refController.text.trim(),
                                    'deduction_reason': reasonController.text.trim(),
                                  },
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (deposits.isEmpty) {
      return const Center(child: Text('لا توجد تأمينات حاويات مسجلة للتوكيلات الملاحية'));
    }

    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: deposits.length,
        itemBuilder: (ctx, idx) {
          final item = deposits[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(item.beneficiaryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => CopyHelper.copy(ctx, item.depositCode),
                              child: Text(item.depositCode, style: const TextStyle(color: AppTheme.cobalt, fontSize: 12)),
                            ),
                            const Spacer(),
                            AppStatusBadge(
                              label: item.recoveryStatus == 'REFUNDED'
                                  ? 'تم الاسترداد'
                                  : item.recoveryStatus == 'SUBMITTED'
                                      ? 'مرفوع للتوكيل'
                                      : 'قيد المتابعة',
                              severity: item.recoveryStatus == 'REFUNDED' ? AppSeverity.success : AppSeverity.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Text('مبلغ التأمين: ${item.depositAmount.toStringAsFixed(2)} جنيه', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                            if (item.containerNumber != null)
                              InkWell(
                                onTap: () => CopyHelper.copy(ctx, item.containerNumber!),
                                child: Text('الحاوية: ${item.containerNumber}', style: const TextStyle(fontSize: 12, color: AppTheme.cobalt)),
                              ),
                            if (item.eirNumber != null)
                              Text('إيصال الفارغ: ${item.eirNumber}', style: const TextStyle(fontSize: 12, color: AppTheme.emerald))
                            else
                              const Text('إيصال الفارغ: لم يسجل بعد', style: TextStyle(fontSize: 12, color: AppTheme.crimson)),
                            if (item.eirReturnDate != null)
                              Text('تاريخ الإعادة: ${item.eirReturnDate}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (item.eirNumber == null)
                    AppButton(
                      label: 'ربط إيصال الفارغ',
                      icon: Icons.receipt_long_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => _showLinkEirDialog(ctx, ref, item),
                    )
                  else if (item.recoveryStatus != 'REFUNDED')
                    AppButton(
                      label: 'تسوية الاسترداد',
                      icon: Icons.payments_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: () => _showSettleDialog(ctx, ref, item),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
