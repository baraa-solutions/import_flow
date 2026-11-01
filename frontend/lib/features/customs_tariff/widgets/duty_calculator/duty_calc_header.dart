import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import 'duty_calculator_state.dart';

/// Header controls, currency settings, and top-level invoice value summaries.
class DutyCalcHeader extends StatelessWidget {
  final DutyCalculatorState state;
  final int? initialImportFileId;
  final bool isArabic;
  final WidgetRef ref;

  const DutyCalcHeader({
    super.key,
    required this.state,
    required this.initialImportFileId,
    required this.isArabic,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              isArabic
                  ? 'حساب الجمارك لشحنة متعددة الأصناف وفق نموذج منصة نافذة'
                  : 'Multi-item customs calculation according to Nafeza statement model',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (initialImportFileId != null) ...[
                  AppButton(
                    label: isArabic
                        ? 'محاكاة ملف الاستيراد (#$initialImportFileId)'
                        : 'Simulate File (#$initialImportFileId)',
                    icon: Icons.sync_alt,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    isLoading: state.isMultiCalculating,
                    onPressed: state.isMultiCalculating
                        ? null
                        : () => state.runImportFileSimulation(
                            initialImportFileId!, ref),
                  ),
                  const SizedBox(width: 8),
                ],
                AppButton(
                  label: isArabic
                      ? 'تحميل مثال نافذة الفعلي (2026-612-1-94731)'
                      : 'Load Actual Nafeza Sample (2026-612-1-94731)',
                  icon: Icons.downloading,
                  variant: AppButtonVariant.warning,
                  size: AppButtonSize.small,
                  onPressed: () => state.loadNafezaSample(ref),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 1: Invoice Currency + Exchange Rate + Total FC
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SearchableDropdownField<String>(
                value: state.selectedCurrency,
                labelText: isArabic ? 'عملة الفاتورة *' : 'Invoice Currency *',
                searchHintText:
                    isArabic ? 'ابحث عن عملة الفاتورة...' : 'Search currency...',
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
                    state.setSelectedCurrency(val, ref);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: state.exchangeRateCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => state.syncCalculatedFields(),
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'سعر التحويل (ج.م/${state.selectedCurrency}) *'
                      : 'Exchange Rate (EGP/${state.selectedCurrency}) *',
                  hintText: isArabic ? 'سعر الصرف الجمركي' : 'Customs Rate',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: state.totalInvoiceFcCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'إجمالي قيمة الفاتورة المقر عنها (${state.selectedCurrency})'
                      : 'Total Declared Invoice Value (${state.selectedCurrency})',
                  helperText: isArabic
                      ? 'حاصل جمع قيم جميع السطور بالعملة'
                      : 'Sum of all invoice lines in currency',
                  helperStyle: const TextStyle(fontSize: 9),
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.cobaltLight,
                  suffixIcon: const Icon(Icons.calculate_outlined,
                      size: 16, color: AppTheme.cobalt),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: Declared CIF EGP + Additional Fees EGP
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: state.declaredCifCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'إجمالي القيمة المقرة سيف (ج.م)'
                      : 'Declared CIF Value (EGP)',
                  helperText: isArabic
                      ? 'محسوبة تلقائياً: (فوب + تأمين + نولون)'
                      : 'Calculated: (FOB + Insurance + Freight)',
                  helperStyle: const TextStyle(fontSize: 9),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: state.additionalFeesCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isArabic
                      ? 'رسوم أساسية أو إضافية (ج.م)'
                      : 'Basic / Additional Fees (EGP)',
                  hintText: '0.00',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
