import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'pre_form4_step_card.dart';

/// Step 2: Nafeza Bank Linkage Acceptance
class PreForm4BankLinkCard extends StatelessWidget {
  final bool isCompleted;
  final String? completionDate;
  final bool isTariffCodingCompleted;
  final TextEditingController dateController;
  final TextEditingController bankNameController;
  final TextEditingController notesController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const PreForm4BankLinkCard({
    super.key,
    required this.isCompleted,
    required this.completionDate,
    required this.isTariffCodingCompleted,
    required this.dateController,
    required this.bankNameController,
    required this.notesController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = l.isArabic;

    return PreForm4StepCard(
      stepNumber: 2,
      title: isAr
          ? 'قبول ربط البنك على نافذة'
          : 'Nafeza Bank Linkage Acceptance',
      isCompleted: isCompleted,
      completionDate: completionDate,
      accentColor: AppTheme.emerald,
      icon: Icons.account_balance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isTariffCodingCompleted) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'شرط مسبق: لا يمكن قبول ربط البنك إلا بعد تسجيل التكويد الضريبي للبنود أعلاه.'
                          : 'Prerequisite: Bank linkage cannot be accepted before item tax coding is completed.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.orange,
                      ),
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
                  label: isAr ? 'تاريخ قبول الربط (YYYY-MM-DD)' : 'Acceptance Date',
                  icon: Icons.event_available,
                  enabled: isTariffCodingCompleted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: bankNameController,
                  label: isAr ? 'اسم البنك المعتمد' : 'Bank Name',
                  icon: Icons.account_balance_outlined,
                  enabled: isTariffCodingCompleted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: CustomTextField(
                  controller: notesController,
                  label: isAr ? 'ملاحظات الربط (اختياري)' : 'Link Notes (Optional)',
                  icon: Icons.notes,
                  enabled: isTariffCodingCompleted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton(
              label: isCompleted
                  ? (isAr ? 'تحديث قبول ربط البنك' : 'Update Bank Link')
                  : (isAr ? 'اعتماد وقبول ربط البنك' : 'Accept Bank Linkage'),
              icon: Icons.check_circle_outline,
              variant: isCompleted ? AppButtonVariant.secondary : AppButtonVariant.success,
              size: AppButtonSize.small,
              isLoading: isSubmitting,
              onPressed: isTariffCodingCompleted ? onSubmit : null,
            ),
          ),
        ],
      ),
    );
  }
}
