import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import 'clearance_followup_card.dart';

const List<String> kFollowupAuthoritiesList = [
  'Customs Inspection Yard / ساحة الكشف والمعاينة',
  'Customs Valuation Committee / لجنة التثمين الجمركي',
  'GOEIC Inspection / هيئة الصادرات والواردات',
  'Food Safety Authority / هيئة سلامة الغذاء (NFSA)',
  'Quarantine / الحجر الزراعي والبيطري',
  'Chemistry Administration / مصلحة الكيمياء والفحص المعملي',
  'NTRA Telecomm / الجهاز القومي لتنظيم الاتصالات',
  'Customs Tariff & Classification / لجنة التعريفة والتصنيف',
];

/// Form widget for creating a new customs clearance follow-up
class ClearanceFollowupForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final int followupSeq;
  final String selectedAuthorityType;
  final TextEditingController officialContactController;
  final TextEditingController statusSummaryController;
  final TextEditingController actionRequiredController;
  final DateTime followupDate;
  final DateTime? nextVisitDate;
  final bool isSubmitting;
  final ValueChanged<int> onSeqChanged;
  final ValueChanged<String> onAuthorityChanged;
  final ValueChanged<DateTime> onFollowupDateChanged;
  final ValueChanged<DateTime?> onNextVisitDateChanged;
  final VoidCallback onSubmit;

  const ClearanceFollowupForm({
    super.key,
    required this.formKey,
    required this.followupSeq,
    required this.selectedAuthorityType,
    required this.officialContactController,
    required this.statusSummaryController,
    required this.actionRequiredController,
    required this.followupDate,
    required this.nextVisitDate,
    required this.isSubmitting,
    required this.onSeqChanged,
    required this.onAuthorityChanged,
    required this.onFollowupDateChanged,
    required this.onNextVisitDateChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_task_rounded, size: 18, color: AppTheme.emerald),
                const SizedBox(width: 8),
                Text(
                  l.isArabic ? 'تسجيل متابعة ميدانية جديدة' : 'Add New Field Follow-up',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Sequence + Authority Type
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: SearchableDropdownField<int>(
                    value: followupSeq,
                    labelText: l.isArabic ? 'المتابعة #' : 'Seq #',
                    items: [1, 2, 3, 4, 5]
                        .map((s) => SearchableDropdownItem<int>(
                              value: s,
                              label: '#$s',
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onSeqChanged(v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SearchableDropdownField<String>(
                    value: selectedAuthorityType,
                    labelText: l.isArabic ? 'الجهة الجمركية / المعاينة *' : 'Authority / Inspection *',
                    items: kFollowupAuthoritiesList
                        .map((a) => SearchableDropdownItem<String>(
                              value: a,
                              label: ClearanceFollowupCard.authorityLabel(a, l.isArabic),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onAuthorityChanged(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Official Contact Name + Followup Date
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: officialContactController,
                    decoration: InputDecoration(
                      labelText: l.isArabic ? 'اسم المسؤول / المثمن / المأمور' : 'Official / Officer Contact',
                      hintText: l.isArabic ? 'مثال: مأمور الكشف م. وليد' : 'Officer Name',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: followupDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        onFollowupDateChanged(picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l.isArabic ? 'تاريخ المتابعة *' : 'Followup Date *',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
                      ),
                      child: Text(
                        followupDate.toIso8601String().substring(0, 10),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status Summary
            TextFormField(
              controller: statusSummaryController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l.isArabic ? 'ملخص المعاينة / الإجراء الميداني *' : 'Status Summary / Inspection Outcome *',
                hintText: l.isArabic ? 'مثال: تم فتح الحاويات وسحب عينات الكيماويات للمطابقة' : 'Inspection completed, samples taken',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (l.isArabic ? 'مطلوب إدخال ملخص المتابعة' : 'Summary required')
                  : null,
            ),
            const SizedBox(height: 12),

            // Action Required
            TextFormField(
              controller: actionRequiredController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l.isArabic ? 'الإجراء المطلوب من المستورد / المخلص' : 'Action Required from Importer/Broker',
                hintText: l.isArabic ? 'مثال: سداد رسوم الفحص المعملي واستيفاء موافقة الهيئة' : 'Pay lab fees, submit certificate',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Next Visit Date
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: nextVisitDate ?? DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  onNextVisitDateChanged(picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.isArabic ? 'موعد الزيارة / المتابعة القادمة' : 'Next Visit Date',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.event_repeat_rounded, size: 16),
                ),
                child: Text(
                  nextVisitDate != null ? nextVisitDate!.toIso8601String().substring(0, 10) : (l.isArabic ? 'غير محدد' : 'Not Set'),
                  style: TextStyle(
                    fontSize: 12,
                    color: nextVisitDate != null ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                label: l.isArabic ? 'حفظ المتابعة الميدانية' : 'Save Field Follow-up',
                icon: Icons.save_rounded,
                variant: AppButtonVariant.primary,
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
