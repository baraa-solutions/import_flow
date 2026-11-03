import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker_field.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../deposits_recovery_provider.dart';

class BankLgReleaseTracker extends ConsumerWidget {
  final List<RefundableDepositModel> lgDeposits;

  const BankLgReleaseTracker({super.key, required this.lgDeposits});

  void _showReleaseDialog(BuildContext context, WidgetRef ref, RefundableDepositModel deposit) {
    final refController = TextEditingController();
    DateTime? releaseDate = DateTime.now();
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
                    const Text('تسجيل فك وإلغاء خطاب الضمان البنكي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('رقم خطاب الضمان: ${deposit.bankLgNumber ?? "غير محدد"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Divider(height: 20),
                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(labelText: 'رقم وتاريخ خطاب الإفراج الصادر من الجمارك للبنك'),
                    ),
                    const SizedBox(height: 12),
                    AppDatePickerField(
                      label: 'تاريخ رد أصل الخطاب للبنك وتأكيد الفك',
                      value: releaseDate,
                      onChanged: (d) => setDialogState(() => releaseDate = d),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'ملاحظات تسليم مخالصة الجمارك'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(label: 'إلغاء', variant: AppButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop()),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'تأكيد فك الضمان',
                          variant: AppButtonVariant.primary,
                          onPressed: () async {
                            if (releaseDate == null || refController.text.trim().isEmpty) return;
                            await ref.read(depositsRecoveryActionsProvider).releaseBankLg(
                                  deposit.id,
                                  refController.text.trim(),
                                  releaseDate!.toIso8601String().substring(0, 10),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lgDeposits.isEmpty) {
      return const Center(child: Text('لا توجد خطابات ضمان بنكية أو أمانات جمركية مسجلة'));
    }

    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lgDeposits.length,
        itemBuilder: (ctx, idx) {
          final item = lgDeposits[idx];
          final isReleased = item.recoveryStatus == 'LG_RELEASED';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isReleased
                          ? AppTheme.emerald.withValues(alpha: 0.1)
                          : AppTheme.charcoal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: isReleased ? AppTheme.emerald : AppTheme.charcoal,
                      size: 24,
                    ),
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
                            if (item.bankLgNumber != null)
                              InkWell(
                                onTap: () => CopyHelper.copy(ctx, item.bankLgNumber!),
                                child: Text('رقم الخطاب: ${item.bankLgNumber}', style: const TextStyle(color: AppTheme.cobalt, fontSize: 12)),
                              ),
                            const Spacer(),
                            AppStatusBadge(
                              label: isReleased ? 'تم فك الضمان' : 'خطاب ساري',
                              severity: isReleased ? AppSeverity.success : AppSeverity.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Text('البنك المصدر: ${item.bankLgIssuingBank ?? "غير محدد"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            Text('قيمة الضمان: ${item.depositAmount.toStringAsFixed(2)} جنيه', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                            if (item.bankLgExpiryDate != null)
                              Text('تاريخ الانتهاء: ${item.bankLgExpiryDate}', style: const TextStyle(fontSize: 12, color: AppTheme.crimson)),
                            if (isReleased && item.refundReference != null)
                              Text('رقم مخالصة الفك: ${item.refundReference}', style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isReleased) ...[
                    const SizedBox(width: 12),
                    AppButton(
                      label: 'تسجيل فك الضمان',
                      icon: Icons.lock_open_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: () => _showReleaseDialog(ctx, ref, item),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
