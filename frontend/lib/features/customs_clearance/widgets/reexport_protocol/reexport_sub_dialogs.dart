import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/reexport_protocol_model.dart';
import '../../services/reexport_protocol_service.dart';

class ReexportBookingDialog extends ConsumerWidget {
  final ReexportDossierModel item;
  final VoidCallback onSaved;

  const ReexportBookingDialog({
    super.key,
    required this.item,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, {required ReexportDossierModel item, required VoidCallback onSaved}) {
    return showDialog(
      context: context,
      builder: (ctx) => ReexportBookingDialog(item: item, onSaved: onSaved),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingNoController = TextEditingController(text: item.returnBookingNumber ?? '');
    final podController = TextEditingController(text: item.returnPortOfDischarge ?? 'Port of Origin');
    final blNoController = TextEditingController(text: item.outboundBlNumber ?? '');

    return AlertDialog(
      title: Text('تسجيل حجز الشحن العكسي — ${item.importFileCode}'),
      content: SizedBox(
        width: 450,
        child: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'رقم حجز الشحن العكسي',
                controller: bookingNoController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: 'ميناء الوصول النهائي لإعادة التصدير',
                controller: podController,
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: 'رقم بوليصة الشحن الصادر',
                controller: blNoController,
                hint: 'اختياري في مرحلة الحجز المبدئي',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        AppButton(
          label: 'حفظ الحجز',
          variant: AppButtonVariant.primary,
          onPressed: () async {
            if (bookingNoController.text.trim().isEmpty) {
              AppTheme.snackBar(context, 'يرجى إدخال رقم الحجز', severity: AppSeverity.warning);
              return;
            }
            Navigator.of(context).pop();
            try {
              final service = ref.read(reexportProtocolServiceProvider);
              await service.recordOutboundBooking(
                item.reexportId,
                returnBookingNumber: bookingNoController.text.trim(),
                returnPortOfDischarge: podController.text.trim(),
                outboundBlNumber: blNoController.text.trim().isNotEmpty ? blNoController.text.trim() : null,
              );
              onSaved();
            } catch (e) {
              // handled
            }
          },
        ),
      ],
    );
  }
}

class SupervisionCommitteeDialog extends ConsumerWidget {
  final ReexportDossierModel item;
  final VoidCallback onSaved;

  const SupervisionCommitteeDialog({
    super.key,
    required this.item,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, {required ReexportDossierModel item, required VoidCallback onSaved}) {
    return showDialog(
      context: context,
      builder: (ctx) => SupervisionCommitteeDialog(item: item, onSaved: onSaved),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officerController = TextEditingController(text: item.customsOfficerInCharge ?? '');
    final declNoController = TextEditingController(text: item.customsOutboundDeclarationNo ?? '');

    return AlertDialog(
      title: Text('تشكيل لجنة الإشراف ومظهر الصادر — ${item.importFileCode}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              label: 'اسم مأمور الجمرك المكلف بالإشراف والمعاينة',
              controller: officerController,
            ),
            const SizedBox(height: 10),
            CustomTextField(
              label: 'رقم مظهر الصادر الجمركي المعتمد',
              controller: declNoController,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        AppButton(
          label: 'اعتماد اللجنة',
          variant: AppButtonVariant.primary,
          onPressed: () async {
            if (officerController.text.trim().isEmpty || declNoController.text.trim().isEmpty) {
              AppTheme.snackBar(context, 'يرجى إدخال اسم المأمور ورقم مظهر الصادر', severity: AppSeverity.warning);
              return;
            }
            Navigator.of(context).pop();
            try {
              final service = ref.read(reexportProtocolServiceProvider);
              await service.formSupervisionCommittee(
                item.reexportId,
                customsOfficerInCharge: officerController.text.trim(),
                customsOutboundDeclarationNo: declNoController.text.trim(),
              );
              onSaved();
            } catch (e) {
              // handled
            }
          },
        ),
      ],
    );
  }
}

class ReexportCreditNoteDialog extends ConsumerWidget {
  final ReexportDossierModel item;
  final VoidCallback onSaved;

  const ReexportCreditNoteDialog({
    super.key,
    required this.item,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, {required ReexportDossierModel item, required VoidCallback onSaved}) {
    return showDialog(
      context: context,
      builder: (ctx) => ReexportCreditNoteDialog(item: item, onSaved: onSaved),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String selectedStatus = item.supplierCreditNoteStatus.name.toUpperCase();
    final amountController = TextEditingController(
      text: item.creditNoteAmountUsd > 0 ? item.creditNoteAmountUsd.toStringAsFixed(2) : '',
    );

    return StatefulBuilder(
      builder: (dlgCtx, setDlgState) => AlertDialog(
        title: Text('إشعار الخصم الدائن للمورد — ${item.importFileCode}'),
        content: SizedBox(
          width: 450,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchableDropdownField<String>(
                  value: selectedStatus,
                  labelText: 'حالة إشعار الخصم',
                  items: const [
                    SearchableDropdownItem(value: 'REQUESTED', label: 'تمت المطالبة وقيد المتابعة'),
                    SearchableDropdownItem(value: 'RECEIVED', label: 'تم استلام إشعار الخصم الدائن'),
                    SearchableDropdownItem(value: 'ARBITRATION', label: 'نزاع وتحكيم تجاري مع المورد'),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'قيمة إشعار الخصم (\$)',
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          AppButton(
            label: 'حفظ الإشعار',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              Navigator.of(context).pop();
              try {
                final service = ref.read(reexportProtocolServiceProvider);
                await service.recordCreditNote(
                  item.reexportId,
                  supplierCreditNoteStatus: selectedStatus,
                  creditNoteAmountUsd: amt,
                );
                onSaved();
              } catch (e) {
                // handled
              }
            },
          ),
        ],
      ),
    );
  }
}

class DutyDrawbackDialog extends ConsumerWidget {
  final ReexportDossierModel item;
  final VoidCallback onSaved;

  const DutyDrawbackDialog({
    super.key,
    required this.item,
    required this.onSaved,
  });

  static Future<void> show(BuildContext context, {required ReexportDossierModel item, required VoidCallback onSaved}) {
    return showDialog(
      context: context,
      builder: (ctx) => DutyDrawbackDialog(item: item, onSaved: onSaved),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String selectedStatus = item.dutyDrawbackStatus.name.toUpperCase();
    if (selectedStatus == 'PENDINGAPPLICATION') selectedStatus = 'PENDING_APPLICATION';
    if (selectedStatus == 'APPROVEDREFUNDED') selectedStatus = 'APPROVED_REFUNDED';
    if (selectedStatus == 'EXEMPTIONSUSPENDED') selectedStatus = 'EXEMPTION_SUSPENDED';

    final amountController = TextEditingController(
      text: item.dutyAmountRefundableEgp > 0 ? item.dutyAmountRefundableEgp.toStringAsFixed(2) : '',
    );

    return StatefulBuilder(
      builder: (dlgCtx, setDlgState) => AlertDialog(
        title: Text('استرداد الرسوم الجمركية (دروباك) — ${item.importFileCode}'),
        content: SizedBox(
          width: 450,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchableDropdownField<String>(
                  value: selectedStatus,
                  labelText: 'حالة طلب رد الرسوم',
                  items: const [
                    SearchableDropdownItem(value: 'PENDING_APPLICATION', label: 'قيد تقديم طلب الاسترداد'),
                    SearchableDropdownItem(value: 'APPROVED_REFUNDED', label: 'تمت الموافقة ورد الرسوم الجمركية'),
                    SearchableDropdownItem(value: 'EXEMPTION_SUSPENDED', label: 'موقوف ومعلق الإعفاء'),
                  ],
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'قيمة الرسوم الجمركية القابلة للاسترداد (ج.م)',
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          AppButton(
            label: 'حفظ طلب الدروباك',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              Navigator.of(context).pop();
              try {
                final service = ref.read(reexportProtocolServiceProvider);
                await service.recordDutyDrawback(
                  item.reexportId,
                  dutyDrawbackStatus: selectedStatus,
                  dutyAmountRefundableEgp: amt,
                );
                onSaved();
              } catch (e) {
                // handled
              }
            },
          ),
        ],
      ),
    );
  }
}
