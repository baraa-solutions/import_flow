import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/app_date_picker_field.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../logistics_exceptions_provider.dart';

class AcidImpactResolverCard extends ConsumerWidget {
  final LogisticsExceptionModel exception;

  const AcidImpactResolverCard({super.key, required this.exception});

  void _showResolutionDialog(BuildContext context, WidgetRef ref) {
    DateTime? adjustedDate = exception.acidAdjustedExpiry != null
        ? DateTime.tryParse(exception.acidAdjustedExpiry!)
        : DateTime.now().add(const Duration(days: 30));
    String status = 'EXTENSION_REQUESTED';
    final notesController = TextEditingController();

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
                    const Text(
                      'مواءمة وتمديد صلاحية القيد الجمركي المبدئي',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'رقم القيد: ${exception.acidNumber ?? "غير محدد"}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const Divider(height: 24),
                    AppDatePickerField(
                      label: 'تاريخ الانتهاء الممدد الجديد',
                      value: adjustedDate,
                      onChanged: (d) => setDialogState(() => adjustedDate = d),
                    ),
                    const SizedBox(height: 16),
                    SearchableDropdownField<String>(
                      labelText: 'حالة إجراء التمديد',
                      value: status,
                      decoration: const InputDecoration(labelText: 'حالة إجراء التمديد'),
                      items: const [
                        SearchableDropdownItem(value: 'EXTENSION_REQUESTED', label: 'تم تقديم طلب التمديد بالنافذة'),
                        SearchableDropdownItem(value: 'SUSPENDED', label: 'معلق لحين البت الجمركي'),
                        SearchableDropdownItem(value: 'RESOLVED', label: 'تم قبول التمديد واعتماد الصلاحية'),
                      ],
                      onChanged: (v) => setDialogState(() => status = v ?? 'EXTENSION_REQUESTED'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'ملاحظات التنسيق مع نافذة'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(
                          label: 'إلغاء',
                          variant: AppButtonVariant.ghost,
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'تأكيد وحفظ الصلاحية',
                          variant: AppButtonVariant.primary,
                          onPressed: () async {
                            if (adjustedDate == null) return;
                            final dateStr = adjustedDate!.toIso8601String().substring(0, 10);
                            await ref.read(logisticsExceptionsActionsProvider).resolveAcid(
                                  exception.id,
                                  dateStr,
                                  status,
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
    final isActionRequired = exception.acidImpactStatus == 'ACTION_REQUIRED';

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActionRequired ? AppTheme.orange.withValues(alpha: 0.05) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isActionRequired ? AppTheme.orange.withValues(alpha: 0.4) : AppTheme.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActionRequired
                    ? AppTheme.orange.withValues(alpha: 0.15)
                    : AppTheme.cobalt.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_outlined,
                color: isActionRequired ? AppTheme.orange : AppTheme.cobalt,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        exception.titleAr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => CopyHelper.copy(context, exception.exceptionCode),
                        child: Text(
                          exception.exceptionCode,
                          style: const TextStyle(color: AppTheme.cobalt, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      AppStatusBadge(
                        label: exception.acidImpactStatus == 'ACTION_REQUIRED'
                            ? 'مطلوب تمديد عاجل'
                            : exception.acidImpactStatus == 'EXTENSION_REQUESTED'
                                ? 'جاري التمديد'
                                : 'الصلاحية سليمة',
                        severity: isActionRequired ? AppSeverity.warning : AppSeverity.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (exception.acidNumber != null)
                        InkWell(
                          onTap: () => CopyHelper.copy(context, exception.acidNumber!),
                          child: Text(
                            'رقم القيد الجمركي: ${exception.acidNumber}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
                          ),
                        ),
                      Text(
                        'تاريخ الانتهاء الأصلي: ${exception.acidOriginalExpiry ?? "غير مسجل"}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      if (exception.acidAdjustedExpiry != null)
                        Text(
                          'تاريخ الانتهاء الممدد: ${exception.acidAdjustedExpiry}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                        ),
                      Text(
                        'الأثر على الموعد: +${exception.delayImpactDays} يوم تأخير',
                        style: const TextStyle(fontSize: 12, color: AppTheme.crimson),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: 'مواءمة الصلاحية',
              icon: Icons.edit_calendar,
              variant: AppButtonVariant.secondary,
              onPressed: () => _showResolutionDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
