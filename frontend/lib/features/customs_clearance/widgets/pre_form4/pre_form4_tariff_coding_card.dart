import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'pre_form4_step_card.dart';

/// Step 1: Item Tax Coding on Nafeza
class PreForm4TariffCodingCard extends StatelessWidget {
  final bool isCompleted;
  final String? completionDate;
  final TextEditingController dateController;
  final TextEditingController notesController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const PreForm4TariffCodingCard({
    super.key,
    required this.isCompleted,
    required this.completionDate,
    required this.dateController,
    required this.notesController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = l.isArabic;

    return PreForm4StepCard(
      stepNumber: 1,
      title: isAr
          ? 'التكويد الضريبي للبنود على نافذة'
          : 'Item Tax Coding on Nafeza',
      isCompleted: isCompleted,
      completionDate: completionDate,
      accentColor: AppTheme.cobalt,
      icon: Icons.qr_code_2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: dateController,
                  label: isAr ? 'تاريخ التكويد الضريبي' : 'Tariff Coding Date',
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: CustomTextField(
                  controller: notesController,
                  label: isAr ? 'ملاحظات التكويد (اختياري)' : 'Coding Notes (Optional)',
                  icon: Icons.note_alt_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton(
              label: isCompleted
                  ? (isAr ? 'تحديث تاريخ التكويد' : 'Update Coding Date')
                  : (isAr ? 'اعتماد التكويد الضريبي' : 'Record Tax Coding'),
              icon: Icons.check,
              variant: isCompleted ? AppButtonVariant.secondary : AppButtonVariant.primary,
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
