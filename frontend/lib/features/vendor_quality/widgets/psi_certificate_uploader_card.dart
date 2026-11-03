import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker_field.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../vendor_quality_provider.dart';

class PsiCertificateUploaderCard extends ConsumerWidget {
  final VendorQualityModel assessment;

  const PsiCertificateUploaderCard({super.key, required this.assessment});

  void _showUploadDialog(BuildContext context, WidgetRef ref) {
    final certNoController = TextEditingController(text: assessment.psiCertificateNumber ?? '');
    final filePathController = TextEditingController(text: assessment.inspectionCertificateFile ?? '');
    final defectsController = TextEditingController(text: assessment.defectsCount.toString());
    final critDefectsController = TextEditingController(text: assessment.criticalDefectsCount.toString());
    DateTime? inspectionDate = assessment.inspectionDate != null ? DateTime.tryParse(assessment.inspectionDate!) : DateTime.now();
    String psiResult = assessment.psiResult == 'PENDING' ? 'PASSED' : assessment.psiResult;
    final notesController = TextEditingController(text: assessment.inspectorNotes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SelectionArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تسجيل ورفع شهادة الفحص قبل الشحن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('المورد: ${assessment.vendorName} — جهة التفتيش: ${assessment.inspectionAgency}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Divider(height: 20),
                    TextField(
                      controller: certNoController,
                      decoration: const InputDecoration(labelText: 'رقم شهادة الفحص الدولية'),
                    ),
                    const SizedBox(height: 12),
                    AppDatePickerField(
                      label: 'تاريخ إجراء التفتيش الميداني',
                      value: inspectionDate,
                      onChanged: (d) => setDialogState(() => inspectionDate = d),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: psiResult,
                      decoration: const InputDecoration(labelText: 'نتيجة التفتيش المعتمدة'),
                      items: const [
                        DropdownMenuItem(value: 'PASSED', child: Text('مطابق ومقبول للشحن')),
                        DropdownMenuItem(value: 'PASSED_WITH_CONDITIONS', child: Text('مقبول بملاحظات وشروط استدراكية')),
                        DropdownMenuItem(value: 'FAILED', child: Text('مرفوض لوجود عيوب غير مطابقة')),
                        DropdownMenuItem(value: 'WAIVED', child: Text('استثناء من الفحص بتفويض إداري')),
                      ],
                      onChanged: (v) => setDialogState(() => psiResult = v ?? 'PASSED'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: defectsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'إجمالي العيوب المرصودة'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: critDefectsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'العيوب الحرجة والجوهرية'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: filePathController,
                      decoration: const InputDecoration(labelText: 'مسار أو رابط ملف الشهادة الإلكترونية'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'ملاحظات وتوصيات المفتش الفني'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(label: 'إلغاء', variant: AppButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop()),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'حفظ واعتماد التقرير',
                          variant: AppButtonVariant.primary,
                          onPressed: () async {
                            final defs = int.tryParse(defectsController.text.trim()) ?? 0;
                            final crit = int.tryParse(critDefectsController.text.trim()) ?? 0;
                            if (inspectionDate == null || certNoController.text.trim().isEmpty) return;

                            await ref.read(vendorQualityActionsProvider).uploadPsi(
                                  assessment.id,
                                  {
                                    'psi_certificate_number': certNoController.text.trim(),
                                    'inspection_date': inspectionDate!.toIso8601String().substring(0, 10),
                                    'psi_result': psiResult,
                                    'inspection_certificate_file': filePathController.text.trim(),
                                    'defects_count': defs,
                                    'critical_defects_count': crit,
                                    'inspector_notes': notesController.text.trim(),
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
    final isPassed = assessment.psiResult == 'PASSED';
    final isFailed = assessment.psiResult == 'FAILED';

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPassed
                    ? AppTheme.emerald.withValues(alpha: 0.1)
                    : isFailed
                        ? AppTheme.crimson.withValues(alpha: 0.1)
                        : AppTheme.cobalt.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPassed
                    ? Icons.verified_user_rounded
                    : isFailed
                        ? Icons.gpp_bad_rounded
                        : Icons.fact_check_rounded,
                color: isPassed
                    ? AppTheme.emerald
                    : isFailed
                        ? AppTheme.crimson
                        : AppTheme.cobalt,
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
                      Text(assessment.vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => CopyHelper.copy(context, assessment.assessmentCode),
                        child: Text(assessment.assessmentCode, style: const TextStyle(color: AppTheme.cobalt, fontSize: 12)),
                      ),
                      const Spacer(),
                      AppStatusBadge(
                        label: isPassed
                            ? 'معتمد ومطابق'
                            : isFailed
                                ? 'مرفوض الفحص'
                                : assessment.psiResult == 'PASSED_WITH_CONDITIONS'
                                    ? 'مقبول بشروط'
                                    : 'بانتظار الفحص',
                        severity: isPassed
                            ? AppSeverity.success
                            : isFailed
                                ? AppSeverity.danger
                                : AppSeverity.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text('وكالة التفتيش: ${assessment.inspectionAgency}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      if (assessment.psiCertificateNumber != null)
                        InkWell(
                          onTap: () => CopyHelper.copy(context, assessment.psiCertificateNumber!),
                          child: Text('رقم الشهادة: ${assessment.psiCertificateNumber}', style: const TextStyle(fontSize: 12, color: AppTheme.charcoal)),
                        ),
                      if (assessment.inspectionDate != null)
                        Text('تاريخ الفحص: ${assessment.inspectionDate}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Text('إجمالي العيوب: ${assessment.defectsCount}', style: TextStyle(fontSize: 12, color: assessment.defectsCount > 0 ? AppTheme.orange : AppTheme.emerald)),
                      if (assessment.criticalDefectsCount > 0)
                        Text('عيوب حرجة: ${assessment.criticalDefectsCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.crimson)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: assessment.psiCertificateNumber == null ? 'تسجيل الشهادة' : 'تحديث الفحص',
              icon: Icons.upload_file_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => _showUploadDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
