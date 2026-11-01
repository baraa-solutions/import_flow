import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import 'duty_calculator_state.dart';

/// Card containing interactive Insurance and Freight configuration (actual vs deemed).
class DutyCalcFreightInsuranceCard extends StatelessWidget {
  final DutyCalculatorState state;
  final bool isArabic;

  const DutyCalcFreightInsuranceCard({
    super.key,
    required this.state,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Insurance Interactive Row ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: (state.insuranceType == 'deemed'
                    ? AppTheme.orangeLight
                    : AppTheme.cobaltLight),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (state.insuranceType == 'deemed'
                      ? AppTheme.orange
                      : AppTheme.cobalt)
                  .withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    state.insuranceType == 'actual'
                        ? Icons.verified_outlined
                        : Icons.auto_fix_high,
                    size: 14,
                    color: state.insuranceType == 'actual'
                        ? AppTheme.cobalt
                        : AppTheme.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'التأمين:' : 'Insurance:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text(isArabic ? 'فعلي ✔' : 'Actual ✔',
                        style: const TextStyle(fontSize: 11)),
                    selected: state.insuranceType == 'actual',
                    selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                    onSelected: (_) => state.setInsuranceType('actual'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(isArabic ? 'حكمي 2.5% ⚡' : 'Deemed 2.5% ⚡',
                        style: const TextStyle(fontSize: 11)),
                    selected: state.insuranceType == 'deemed',
                    selectedColor: AppTheme.orange.withValues(alpha: 0.2),
                    onSelected: (_) => state.setInsuranceType('deemed'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (state.insuranceType == 'actual') ...[
                    Expanded(
                      child: TextField(
                        controller: state.insuranceCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => state.syncCalculatedFields(),
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'مبلغ التأمين الفعلي (ج.م)'
                              : 'Actual Insurance Amount (EGP)',
                          hintText: '0.00',
                          isDense: true,
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: TextField(
                        controller: state.deemedInsuranceCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'التأمين الحكمي المحتسب (ج.م) — 2.5% من إجمالي فوب'
                              : 'Deemed Insurance (EGP) — 2.5% of FOB',
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.orangeLight,
                          suffixIcon: const Icon(
                            Icons.calculate_outlined,
                            size: 16,
                            color: AppTheme.orange,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: state.insuranceCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'التأمين الفعلي (ج.م) — يُضبط صفراً'
                              : 'Actual Insurance (EGP) — set to 0',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.withValues(alpha: 0.08),
                          helperText: isArabic
                              ? 'صفر لتجنب الاحتساب المزدوج'
                              : 'Zero to prevent double counting',
                          helperStyle: const TextStyle(
                              fontSize: 9, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Freight Interactive Row (Foreign Currency & Amount) ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: (state.freightType == 'deemed'
                    ? AppTheme.orangeLight
                    : AppTheme.cobaltLight),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (state.freightType == 'deemed'
                      ? AppTheme.orange
                      : AppTheme.cobalt)
                  .withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    state.freightType == 'actual'
                        ? Icons.local_shipping_outlined
                        : Icons.auto_fix_high,
                    size: 14,
                    color: state.freightType == 'actual'
                        ? AppTheme.cobalt
                        : AppTheme.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'النولون:' : 'Freight:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: Text(isArabic ? 'فعلي ✔' : 'Actual ✔',
                        style: const TextStyle(fontSize: 11)),
                    selected: state.freightType == 'actual',
                    selectedColor: AppTheme.cobalt.withValues(alpha: 0.2),
                    onSelected: (_) => state.setFreightType('actual'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(isArabic ? 'حكمي 2.0% ⚡' : 'Deemed 2.0% ⚡',
                        style: const TextStyle(fontSize: 11)),
                    selected: state.freightType == 'deemed',
                    selectedColor: AppTheme.orange.withValues(alpha: 0.2),
                    onSelected: (_) => state.setFreightType('deemed'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (state.freightType == 'actual') ...[
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        value: state.selectedFreightCurrency,
                        labelText: isArabic
                            ? 'عملة النولون الفعلي *'
                            : 'Actual Freight Currency *',
                        searchHintText: isArabic
                            ? 'ابحث عن عملة النولون...'
                            : 'Search freight currency...',
                        items: [
                          SearchableDropdownItem(
                              value: 'USD',
                              label: isArabic ? 'USD - دولار' : 'USD - US Dollar'),
                          SearchableDropdownItem(
                              value: 'EUR',
                              label: isArabic ? 'EUR - يورو' : 'EUR - Euro'),
                          SearchableDropdownItem(
                              value: 'GBP',
                              label: isArabic ? 'GBP - إسترليني' : 'GBP - Sterling'),
                          SearchableDropdownItem(
                              value: 'CNY',
                              label: isArabic ? 'CNY - يوان' : 'CNY - Yuan'),
                          SearchableDropdownItem(
                              value: 'SAR',
                              label: isArabic ? 'SAR - ريال سعودي' : 'SAR - Saudi Riyal'),
                          SearchableDropdownItem(
                              value: 'AED',
                              label: isArabic ? 'AED - درهم إماراتي' : 'AED - UAE Dirham'),
                          SearchableDropdownItem(
                              value: 'EGP',
                              label: isArabic ? 'EGP - جنيه مصري' : 'EGP - Egyptian Pound'),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            state.setSelectedFreightCurrency(val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: state.freightForeignCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => state.syncCalculatedFields(),
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'مبلغ النولون (${state.selectedFreightCurrency}) *'
                              : 'Freight Amount (${state.selectedFreightCurrency}) *',
                          hintText: '0.00',
                          isDense: true,
                        ),
                      ),
                    ),
                    if (state.selectedFreightCurrency != 'EGP') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: state.freightExchangeRateCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => state.syncCalculatedFields(),
                          decoration: InputDecoration(
                            labelText: isArabic
                                ? 'معامل تحويل عملة النولون (اختياري)'
                                : 'Freight FX Override (Optional)',
                            hintText: isArabic
                                ? 'اتركه فارغاً لاستخدام سعر الجمارك'
                                : 'Leave blank for customs rate',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: state.multiFreightCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'إجمالي النولون الفعلي (ج.م)'
                              : 'Total Actual Freight (EGP)',
                          helperText: state.selectedFreightCurrency == 'EGP'
                              ? (isArabic ? 'نولون بالجنيه' : 'Freight in EGP')
                              : (isArabic
                                  ? '= النولون (${state.selectedFreightCurrency}) × معامل التحويل'
                                  : '= Freight (${state.selectedFreightCurrency}) × FX Rate'),
                          helperStyle: const TextStyle(fontSize: 9),
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.cobaltLight,
                          suffixIcon: const Icon(
                            Icons.calculate_outlined,
                            size: 16,
                            color: AppTheme.cobalt,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: TextField(
                        controller: state.deemedFreightCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'النولون الحكمي المحتسب (ج.م) — 2.0% من إجمالي فوب'
                              : 'Deemed Freight (EGP) — 2.0% of FOB',
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.orangeLight,
                          suffixIcon: const Icon(
                            Icons.calculate_outlined,
                            size: 16,
                            color: AppTheme.orange,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: state.multiFreightCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: isArabic
                              ? 'النولون الفعلي (ج.م) — يُضبط صفراً'
                              : 'Actual Freight (EGP) — set to 0',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.withValues(alpha: 0.08),
                          helperText: isArabic
                              ? 'صفر لتجنب الاحتساب المزدوج'
                              : 'Zero to prevent double counting',
                          helperStyle: const TextStyle(
                              fontSize: 9, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
