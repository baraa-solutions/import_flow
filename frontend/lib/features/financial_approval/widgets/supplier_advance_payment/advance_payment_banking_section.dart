import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class AdvancePaymentBankingSection extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController beneficiaryController;
  final TextEditingController bankNameController;
  final TextEditingController swiftController;
  final TextEditingController ibanController;
  final TextEditingController notesController;
  final DateTime dueDate;
  final ValueChanged<DateTime> onDueDateChanged;
  final bool isDark;

  const AdvancePaymentBankingSection({
    super.key,
    required this.titleController,
    required this.beneficiaryController,
    required this.bankNameController,
    required this.swiftController,
    required this.ibanController,
    required this.notesController,
    required this.dueDate,
    required this.onDueDateChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Request Title
        TextFormField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: context.l10n.faPaymentTitleLabel,
            border: const OutlineInputBorder(),
          ),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return context.l10n.required;
            if (s.length < 3) {
              return context.l10n.faTitleMinLength;
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Supplier Banking Details Section
        Text(
          context.l10n.faBeneficiaryBankDetails,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: beneficiaryController,
                decoration: InputDecoration(
                  labelText: context.l10n.faBeneficiaryNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? (context.l10n.required) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: bankNameController,
                decoration: InputDecoration(
                  labelText: context.l10n.faBankNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? (context.l10n.required) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: swiftController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: context.l10n.faSwiftBicLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? (context.l10n.required) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: ibanController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: context.l10n.faAccountIbanLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? (context.l10n.required) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Due Date & Notes
        AppDatePickerField(
          label: context.l10n.faRequestedDueDateLabel,
          value: dueDate,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          allowClear: false,
          isRequired: true,
          onChanged: (picked) {
            if (picked != null) {
              onDueDateChanged(picked);
            }
          },
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: notesController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: context.l10n.faNotesForFinance,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // Informational Workflow Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.cobalt.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.cobalt,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.faAdvanceConfirmNote,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.cobalt,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
