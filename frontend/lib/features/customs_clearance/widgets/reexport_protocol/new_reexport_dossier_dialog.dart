import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../services/reexport_protocol_service.dart';

class NewReexportDossierDialog extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final VoidCallback onDossierCreated;

  const NewReexportDossierDialog({
    super.key,
    this.initialImportFileId,
    required this.onDossierCreated,
  });

  static Future<void> show(
    BuildContext context, {
    int? initialImportFileId,
    required VoidCallback onDossierCreated,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => NewReexportDossierDialog(
        initialImportFileId: initialImportFileId,
        onDossierCreated: onDossierCreated,
      ),
    );
  }

  @override
  ConsumerState<NewReexportDossierDialog> createState() => _NewReexportDossierDialogState();
}

class _NewReexportDossierDialogState extends ConsumerState<NewReexportDossierDialog> {
  late final TextEditingController fileIdController;
  late final TextEditingController fileCodeController;
  late final TextEditingController authorityController;
  late final TextEditingController decreeController;
  late final TextEditingController dateController;
  late final TextEditingController reasonController;
  late final TextEditingController containersController;

  @override
  void initState() {
    super.initState();
    fileIdController = TextEditingController(text: widget.initialImportFileId?.toString() ?? '');
    fileCodeController = TextEditingController();
    authorityController = TextEditingController(text: 'الهيئة العامة للرقابة على الصادرات والواردات (GOEIC)');
    decreeController = TextEditingController();
    dateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    reasonController = TextEditingController();
    containersController = TextEditingController();
  }

  @override
  void dispose() {
    fileIdController.dispose();
    fileCodeController.dispose();
    authorityController.dispose();
    decreeController.dispose();
    dateController.dispose();
    reasonController.dispose();
    containersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.assignment_late_outlined, color: AppTheme.crimson),
          SizedBox(width: 8),
          Text('تسجيل ملف إعادة تصدير لبضاعة مرفوضة رقابياً'),
        ],
      ),
      content: SizedBox(
        width: 550,
        child: SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'المادة 67 من قانون 207/2020: يبدأ سريان مهلة الـ 30 يوماً فور صدور قرار الرفض النهائي قبل الشروع في إجراءات الإعدام الجمركي.',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.crimson),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
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
                        label: 'كود الملف (مثال: IMP-2026-001)',
                        controller: fileCodeController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'الجهة الرقابية الصادر عنها الرفض',
                  controller: authorityController,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'رقم قرار الرفض الرسمي',
                        controller: decreeController,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        label: 'تاريخ صدور القرار (YYYY-MM-DD)',
                        controller: dateController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'أسباب الرفض الفنية / المعملية بالتفصيل',
                  controller: reasonController,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  label: 'أرقام الحاويات المرفوضة (مفصولة بفواصل)',
                  controller: containersController,
                  hint: 'MSKU1234567, CMAU7654321',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        AppButton(
          label: 'تأكيد وقيد الملف',
          variant: AppButtonVariant.primary,
          onPressed: () async {
            final fid = int.tryParse(fileIdController.text.trim());
            if (fid == null || fileCodeController.text.trim().isEmpty || decreeController.text.trim().isEmpty) {
              AppTheme.snackBar(context, 'يرجى استيفاء الحقول الإلزامية ورقم الملف وقرار الرفض', severity: AppSeverity.warning);
              return;
            }
            final containers = containersController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();

            Navigator.of(context).pop();
            try {
              final service = ref.read(reexportProtocolServiceProvider);
              await service.createDossier(
                importFileId: fid,
                importFileCode: fileCodeController.text.trim(),
                rejectionAuthority: authorityController.text.trim(),
                rejectionDecreeNumber: decreeController.text.trim(),
                rejectionDate: dateController.text.trim(),
                reexportReason: reasonController.text.trim().isNotEmpty
                    ? reasonController.text.trim()
                    : 'مرفوض لعدم مطابقة المواصفات القياسية',
                containerNumbers: containers,
              );
              widget.onDossierCreated();
            } catch (e) {
              // error handled by parent or snackbar
            }
          },
        ),
      ],
    );
  }
}
