import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../logistics_exceptions_provider.dart';

class ValuationAppealTracker extends ConsumerWidget {
  final LogisticsExceptionModel exception;

  const ValuationAppealTracker({super.key, required this.exception});

  void _showAppealDialog(BuildContext context, WidgetRef ref) {
    final customsValController = TextEditingController(
      text: exception.valuationOriginalCustomsVal?.toString() ?? '',
    );
    final declaredValController = TextEditingController(
      text: exception.valuationDeclaredVal?.toString() ?? '',
    );
    final disputeAmtController = TextEditingController(
      text: exception.valuationDisputeAmount?.toString() ?? '',
    );
    final groundsController = TextEditingController();
    final strategyController = TextEditingController(
      text: exception.resolutionStrategy ?? '',
    );
    String appealStatus = exception.appealStatus ?? 'PENDING_APPEAL';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: SelectionArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تسجيل ومتابعة استئناف نزاع القيمة الجمركية',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: declaredValController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'القيمة المقر عنها بالفاتورة'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: customsValController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'القيمة المقدرة من التثمين'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: disputeAmtController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مبلغ النزاع الجمركي بالجنيه'),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      labelText: 'مرحلة الاستئناف والتظلم',
                      value: appealStatus,
                      decoration: const InputDecoration(labelText: 'مرحلة الاستئناف والتظلم'),
                      items: const [
                        SearchableDropdownItem(value: 'PENDING_APPEAL', label: 'جاري إعداد مذكرة التظلم'),
                        SearchableDropdownItem(value: 'COMMITTEE_HEARING', label: 'منظور أمام لجنة فض النزاعات الجمركية'),
                        SearchableDropdownItem(value: 'APPEAL_ACCEPTED', label: 'تم قبول التظلم وتخفيض القيمة'),
                        SearchableDropdownItem(value: 'APPEAL_REJECTED', label: 'تم تأييد قرار التثمين'),
                      ],
                      onChanged: (v) => setDialogState(() => appealStatus = v ?? 'PENDING_APPEAL'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: groundsController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'أسباب وأسانيد التظلم القانونية'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: strategyController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'خطة التحرك وفض النزاع'),
                    ),
                    const SizedBox(height: 20),
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
                          label: 'حفظ وتحديث التظلم',
                          variant: AppButtonVariant.primary,
                          onPressed: () async {
                            final cVal = double.tryParse(customsValController.text.trim()) ?? 0.0;
                            final dVal = double.tryParse(declaredValController.text.trim()) ?? 0.0;
                            final amt = double.tryParse(disputeAmtController.text.trim()) ?? (cVal - dVal);

                            await ref.read(logisticsExceptionsActionsProvider).submitValuationAppeal(
                                  exception.id,
                                  {
                                    'valuation_original_customs_val': cVal,
                                    'valuation_declared_val': dVal,
                                    'valuation_dispute_amount': amt,
                                    'appeal_status': appealStatus,
                                    'appeal_grounds': groundsController.text.trim(),
                                    'resolution_strategy': strategyController.text.trim(),
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
    final disputeAmt = exception.valuationDisputeAmount ?? 0.0;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.crimson.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gavel_rounded, color: AppTheme.crimson, size: 22),
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
                        label: exception.appealStatus == 'COMMITTEE_HEARING'
                            ? 'جلسة فض النزاع'
                            : exception.appealStatus == 'APPEAL_ACCEPTED'
                                ? 'تم قبول التظلم'
                                : 'نزاع قيد الإجراء',
                        severity: exception.appealStatus == 'APPEAL_ACCEPTED'
                            ? AppSeverity.success
                            : AppSeverity.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text(
                        'مبلغ النزاع: ${disputeAmt.toStringAsFixed(2)} جنيه',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                      ),
                      if (exception.valuationDeclaredVal != null)
                        Text(
                          'القيمة المصرح بها: ${exception.valuationDeclaredVal!.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      if (exception.valuationOriginalCustomsVal != null)
                        Text(
                          'القيمة المقدرة: ${exception.valuationOriginalCustomsVal!.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
                        ),
                    ],
                  ),
                  if (exception.resolutionStrategy != null && exception.resolutionStrategy!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'خطة الحل: ${exception.resolutionStrategy}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: 'متابعة التظلم',
              icon: Icons.assignment_turned_in,
              variant: AppButtonVariant.secondary,
              onPressed: () => _showAppealDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
