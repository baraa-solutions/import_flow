import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../models/container_deposit_model.dart';
import '../../services/container_deposit_service.dart';

class DepositSubDialogs {
  const DepositSubDialogs._();

  static void showNewDepositDialog(
    BuildContext context,
    WidgetRef ref, {
    int? initialImportFileId,
    required VoidCallback onSaved,
  }) {
    final fileIdController = TextEditingController(text: initialImportFileId?.toString() ?? '');
    final carrierController = TextEditingController();
    final containerNoController = TextEditingController();
    final containerTypeController = TextEditingController(text: '40HC');
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);

    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_card_rounded, color: AppTheme.cobalt),
              SizedBox(width: 8),
              Text('تسجيل تأمين حاوية جديد مدفوع للخط الملاحي'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'معرف الملف الاستيرادي',
                          controller: fileIdController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'اسم الخط الملاحي / التوكيل',
                          controller: carrierController,
                          hint: 'Maersk, MSC, CMA CGM...',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: CustomTextField(
                          label: 'رقم الحاوية',
                          controller: containerNoController,
                          hint: 'MSKU1234567',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'نوع الحاوية',
                          controller: containerTypeController,
                          hint: '20ft, 40HC, Reefer',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'مبلغ التأمين (ج.م)',
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'تاريخ الدفع (YYYY-MM-DD)',
                          controller: dateController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    label: 'رقم إيصال / شيك / مرجع السداد',
                    controller: refController,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'حفظ التأمين',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final fid = int.tryParse(fileIdController.text.trim());
                final amt = double.tryParse(amountController.text.trim());
                if (fid == null || amt == null || containerNoController.text.trim().isEmpty || carrierController.text.trim().isEmpty) {
                  AppTheme.snackBar(ctx, 'يرجى استيفاء الحقول الإجبارية ورقم الحاوية والمبلغ', severity: AppSeverity.warning);
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(containerDepositServiceProvider);
                  await service.createDeposit(
                    importFileId: fid,
                    carrierName: carrierController.text.trim(),
                    containerNumber: containerNoController.text.trim(),
                    containerType: containerTypeController.text.trim(),
                    depositAmountEgp: amt,
                    paymentDate: dateController.text.trim(),
                    paymentReference: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                  );
                  if (context.mounted) {
                    AppTheme.snackBar(context, 'تم تسجيل تأمين الحاوية بنجاح', severity: AppSeverity.success);
                    onSaved();
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppTheme.snackBar(context, 'فشل في حفظ التأمين: $e', severity: AppSeverity.danger);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static void showRecordEirDialog(
    BuildContext context,
    WidgetRef ref, {
    required ContainerDepositModel item,
    required VoidCallback onSaved,
  }) {
    final eirNoController = TextEditingController(text: item.eirReturnNumber ?? '');
    final eirDateController = TextEditingController(text: item.eirReturnDate ?? DateTime.now().toIso8601String().split('T').first);
    String condition = item.containerCondition.name.toUpperCase();
    if (condition == 'SOUNDCLEAN') condition = 'SOUND_CLEAN';
    if (condition == 'DAMAGECLAIMED') condition = 'DAMAGE_CLAIMED';
    if (condition == 'CLEANINGFEEDEDUCTED') condition = 'CLEANING_FEE_DEDUCTED';

    final deductionController = TextEditingController(text: item.deductionAmountEgp > 0 ? item.deductionAmountEgp.toStringAsFixed(2) : '0');
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => SelectionArea(
          child: AlertDialog(
            title: Text('تسجيل إيصال استرجاع الفارغ (EIR) — ${item.containerNumber}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'تسجيل إيصال الـ EIR يبدأ مهلة الـ 30 يوماً القانونية الممنوحة للخط الملاحي لرد مبلغ التأمين.',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.cobalt),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'رقم إيصال التسليم',
                            controller: eirNoController,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomTextField(
                            label: 'تاريخ الإيصال (YYYY-MM-DD)',
                            controller: eirDateController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      value: condition,
                      labelText: 'حالة الحاوية في محطة الإرجاع',
                      items: const [
                        SearchableDropdownItem<String>(value: 'SOUND_CLEAN', label: 'سليمة ونظيفة'),
                        SearchableDropdownItem<String>(value: 'DAMAGE_CLAIMED', label: 'مطالبة بأضرار وتلفيات'),
                        SearchableDropdownItem<String>(value: 'CLEANING_FEE_DEDUCTED', label: 'خصم غسيل ونظافة'),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => condition = v);
                      },
                    ),
                    if (condition != 'SOUND_CLEAN') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'مبلغ الخصم المدعى (ج.م)',
                              controller: deductionController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CustomTextField(
                              label: 'سبب الخصم / التلفيات',
                              controller: reasonController,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
              AppButton(
                label: 'حفظ إيصال الـ EIR',
                variant: AppButtonVariant.primary,
                onPressed: () async {
                  if (eirNoController.text.trim().isEmpty) {
                    AppTheme.snackBar(ctx, 'يرجى إدخال رقم إيصال الـ EIR', severity: AppSeverity.warning);
                    return;
                  }
                  final ded = double.tryParse(deductionController.text.trim()) ?? 0.0;
                  Navigator.of(ctx).pop();
                  try {
                    final service = ref.read(containerDepositServiceProvider);
                    await service.recordEirReturn(
                      item.depositId,
                      eirReturnNumber: eirNoController.text.trim(),
                      eirReturnDate: eirDateController.text.trim(),
                      containerCondition: condition,
                      deductionAmountEgp: ded,
                      deductionReason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                    );
                    if (context.mounted) {
                      AppTheme.snackBar(context, 'تم حفظ إيصال استرجاع الحاوية بنجاح وبدء مهلة المطالبة', severity: AppSeverity.success);
                      onSaved();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppTheme.snackBar(context, 'فشل في حفظ إيصال EIR: $e', severity: AppSeverity.danger);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showRecordRefundDialog(
    BuildContext context,
    WidgetRef ref, {
    required ContainerDepositModel item,
    required VoidCallback onSaved,
  }) {
    final refController = TextEditingController(text: item.refundChequeOrTransferNo ?? '');
    final dateController = TextEditingController(text: item.refundReceivedDate ?? DateTime.now().toIso8601String().split('T').first);
    final expectedAmount = item.depositAmountEgp - item.deductionAmountEgp;
    final amountController = TextEditingController(text: expectedAmount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: Text('تسجيل استرداد مبلغ التأمين — ${item.containerNumber}'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الخط الملاحي: ${item.carrierName} | التأمين الأصلي: ${item.depositAmountEgp.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                if (item.deductionAmountEgp > 0)
                  Text(
                    'الخصومات المقتطعة: ${item.deductionAmountEgp.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(color: AppTheme.crimson, fontSize: 12),
                  ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'رقم الشيك أو التحويل البنكي المستلم',
                  controller: refController,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'المبلغ المسترد فعلياً (ج.م EGP)',
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        label: 'تاريخ الاستلام (YYYY-MM-DD)',
                        controller: dateController,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'تأكيد استلام الاسترداد',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (refController.text.trim().isEmpty || amt <= 0) {
                  AppTheme.snackBar(ctx, 'يرجى إدخال رقم الشيك/التحويل والمبلغ المسترد', severity: AppSeverity.warning);
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  final service = ref.read(containerDepositServiceProvider);
                  await service.recordRefund(
                    item.depositId,
                    refundChequeOrTransferNo: refController.text.trim(),
                    refundReceivedDate: dateController.text.trim(),
                    refundAmountEgp: amt,
                  );
                  if (context.mounted) {
                    AppTheme.snackBar(context, 'تم تسجيل استرداد تأمين الحاوية بنجاح وإغلاق المطالبة', severity: AppSeverity.success);
                    onSaved();
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppTheme.snackBar(context, 'فشل في حفظ استرداد التأمين: $e', severity: AppSeverity.danger);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static void showDisputeDialog(
    BuildContext context,
    WidgetRef ref, {
    required ContainerDepositModel item,
    required VoidCallback onSaved,
  }) {
    final reasonController = TextEditingController();
    final revisedController = TextEditingController(text: '0.00');
    bool waive = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => SelectionArea(
          child: AlertDialog(
            title: Text('اعتراض على خصومات التأمين — ${item.containerNumber}'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قيمة الخصم الحالية: ${item.deductionAmountEgp.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    label: 'أسباب الاعتراض ومبررات إلغاء الخصم',
                    controller: reasonController,
                    maxLines: 2,
                    hint: 'تقديم صور الحاوية عند التحميل، أو تقرير سلامة سليم...',
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('إلغاء الخصم بالكامل (إعفاء 100%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    value: waive,
                    onChanged: (v) => setDlgState(() => waive = v ?? false),
                  ),
                  if (!waive) ...[
                    const SizedBox(height: 8),
                    CustomTextField(
                      label: 'قيمة الخصم المتفق عليها بعد التفاوض (ج.م EGP)',
                      controller: revisedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
              AppButton(
                label: 'حفظ نتيجة الاعتراض',
                variant: AppButtonVariant.primary,
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) {
                    AppTheme.snackBar(ctx, 'يرجى كتابة سبب ومستند الاعتراض', severity: AppSeverity.warning);
                    return;
                  }
                  final revised = waive ? 0.0 : (double.tryParse(revisedController.text.trim()) ?? 0.0);
                  Navigator.of(ctx).pop();
                  try {
                    final service = ref.read(containerDepositServiceProvider);
                    await service.disputeDeduction(
                      item.depositId,
                      disputeReason: reasonController.text.trim(),
                      revisedDeductionAmountEgp: revised,
                      waived: waive,
                    );
                    if (context.mounted) {
                      AppTheme.snackBar(context, 'تم تسجيل نتيجة الاعتراض وتعديل قيمة الخصم', severity: AppSeverity.success);
                      onSaved();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppTheme.snackBar(context, 'فشل في تسجيل الاعتراض: $e', severity: AppSeverity.danger);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
