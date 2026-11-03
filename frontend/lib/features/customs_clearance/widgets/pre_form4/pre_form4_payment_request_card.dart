import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'pre_form4_step_card.dart';

/// Step 3: Duty Payment Request & Nafeza Claim (Form 4)
class PreForm4PaymentRequestCard extends StatelessWidget {
  final bool isCompleted;
  final String? completionDate;
  final bool isBankLinkCompleted;
  final TextEditingController dateController;
  final TextEditingController claimNumberController;
  final TextEditingController estimatedAmountController;
  final TextEditingController notesController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const PreForm4PaymentRequestCard({
    super.key,
    required this.isCompleted,
    required this.completionDate,
    required this.isBankLinkCompleted,
    required this.dateController,
    required this.claimNumberController,
    required this.estimatedAmountController,
    required this.notesController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = l.isArabic;

    return PreForm4StepCard(
      stepNumber: 3,
      title: isAr
          ? 'إصدار مطالبة الرسوم وطلب فورمة 4 (Duty Payment Request / Form 4)'
          : 'Duty Payment Request & Nafeza Claim',
      isCompleted: isCompleted,
      completionDate: completionDate,
      accentColor: AppTheme.cobalt,
      icon: Icons.receipt_long,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isBankLinkCompleted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.charcoal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.charcoal.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'يوصى باكتمال ربط البنك أولاً قبل طلب السداد لضمان مطابقة المنظومة البنكية مع نافذة.'
                          : 'Recommended to accept bank linkage before requesting duty payment to match MTS with bank systems.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: dateController,
                  label: isAr ? 'تاريخ طلب السداد (YYYY-MM-DD)' : 'Request Date',
                  icon: Icons.calendar_month,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: claimNumberController,
                  label: isAr ? 'رقم مطالبة نافذة' : 'Nafeza Claim Number',
                  icon: Icons.tag,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: estimatedAmountController,
                  label: isAr ? 'الرسوم التقديرية (ج.م)' : 'Estimated Duty (EGP)',
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: notesController,
            label: isAr ? 'ملاحظات طلب السداد والمطالبة' : 'Payment Request Notes',
            icon: Icons.note_alt_outlined,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton(
              label: isCompleted
                  ? (isAr ? 'تحديث طلب السداد والمطالبة' : 'Update Payment Request')
                  : (isAr ? 'إرسال طلب السداد (طلب فورمة 4)' : 'Submit Duty Payment Request'),
              icon: Icons.send_rounded,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              isLoading: isSubmitting,
              onPressed: onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}
