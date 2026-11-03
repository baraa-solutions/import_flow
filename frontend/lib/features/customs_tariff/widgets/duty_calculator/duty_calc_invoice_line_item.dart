import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../smart_tasks/providers/smart_tasks_provider.dart';
import '../../models/customs_tariff_model.dart';
import 'duty_calculator_state.dart';

/// Single item line in the multi-item customs duty declaration.
class DutyCalcInvoiceLineItem extends StatelessWidget {
  final int index;
  final Map<String, dynamic> line;
  final DutyCalculatorState state;
  final bool isArabic;
  final bool isDark;
  final List<CustomsTariffModel> registeredTariffs;
  final List<SearchableDropdownItem<String>> hsDropdownItems;
  final WidgetRef ref;
  final int? initialImportFileId;

  const DutyCalcInvoiceLineItem({
    super.key,
    required this.index,
    required this.line,
    required this.state,
    required this.isArabic,
    required this.isDark,
    required this.registeredTariffs,
    required this.hsDropdownItems,
    required this.ref,
    required this.initialImportFileId,
  });

  @override
  Widget build(BuildContext context) {
    final currentHs = (line['hs'] as TextEditingController).text.trim();
    final matchedTariff = registeredTariffs.cast<CustomsTariffModel?>().firstWhere(
          (t) =>
              t != null &&
              (t.hsCode == currentHs ||
                  t.hsCode.replaceAll('.', '') ==
                      currentHs.replaceAll('.', '')),
          orElse: () => null,
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.cobalt,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SearchableDropdownField<String>(
                  value: currentHs.isEmpty ? null : currentHs,
                  labelText: isArabic
                      ? 'بند التعريفة الجمركية *'
                      : 'HS Code (Customs Tariff) *',
                  searchHintText: isArabic
                      ? 'ابحث برقم البند أو الوصف الجمركي...'
                      : 'Search HS code or description...',
                  items: [
                    if (currentHs.isNotEmpty &&
                        !registeredTariffs.any((t) => t.hsCode == currentHs))
                      SearchableDropdownItem<String>(
                        value: currentHs,
                        label: currentHs,
                        subtitle:
                            isArabic ? 'بند غير مسجل / حرة' : 'Unregistered / Free',
                      ),
                    ...hsDropdownItems,
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      (line['hs'] as TextEditingController).text = val;
                      state.syncCalculatedFields();
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: line['value'] as TextEditingController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => state.syncCalculatedFields(),
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? 'القيمة (${state.selectedCurrency})'
                        : 'Value (${state.selectedCurrency})',
                    hintText: '0.00',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  value: line['origin'] as String?,
                  labelText: isArabic ? 'المنشأ' : 'Origin',
                  searchHintText:
                      isArabic ? 'ابحث عن بلد المنشأ...' : 'Search origin...',
                  items: [
                    SearchableDropdownItem(
                        value: 'CN',
                        label: isArabic ? 'الصين (CN)' : 'China (CN)'),
                    SearchableDropdownItem(
                        value: 'TR',
                        label: isArabic
                            ? 'تركيا - اتفاقية (TR)'
                            : 'Turkey - Agreement (TR)'),
                    SearchableDropdownItem(
                        value: 'DE',
                        label: isArabic
                            ? 'ألمانيا - شراكة (DE)'
                            : 'Germany - Partnership (DE)'),
                    SearchableDropdownItem(
                        value: 'IT',
                        label: isArabic
                            ? 'إيطاليا - شراكة (IT)'
                            : 'Italy - Partnership (IT)'),
                    SearchableDropdownItem(
                        value: 'EG',
                        label: isArabic ? 'مصر (EG)' : 'Egypt (EG)'),
                    SearchableDropdownItem(
                        value: 'GB',
                        label: isArabic
                            ? 'المملكة المتحدة (GB)'
                            : 'United Kingdom (GB)'),
                    SearchableDropdownItem(
                        value: 'US',
                        label: isArabic
                            ? 'الولايات المتحدة (US)'
                            : 'United States (US)'),
                    SearchableDropdownItem(
                        value: 'IN',
                        label: isArabic ? 'الهند (IN)' : 'India (IN)'),
                    SearchableDropdownItem(
                        value: 'BR',
                        label: isArabic
                            ? 'البرازيل - ميركوسور (BR)'
                            : 'Brazil - Mercosur (BR)'),
                    SearchableDropdownItem(
                        value: 'RS',
                        label: isArabic
                            ? 'صربيا - اتفاقية (RS)'
                            : 'Serbia - Agreement (RS)'),
                    SearchableDropdownItem(
                        value: 'CH',
                        label: isArabic
                            ? 'سويسرا - إفتا (CH)'
                            : 'Switzerland - EFTA (CH)'),
                  ],
                  onChanged: (val) {
                    state.updateLineOrigin(index, val);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String?>(
                  value: line['exemption'] as String?,
                  labelText: isArabic ? 'الإعفاء' : 'Exemption',
                  searchHintText:
                      isArabic ? 'ابحث عن كود الإعفاء...' : 'Search exemption...',
                  items: [
                    SearchableDropdownItem(
                        value: null,
                        label: isArabic ? 'لا يوجد إعفاء' : 'No Exemption'),
                    SearchableDropdownItem(
                        value: 'INV-LAW-EXEMPT-01',
                        label: isArabic
                            ? 'قانون الاستثمار (100%)'
                            : 'Investment Law (100%)'),
                    SearchableDropdownItem(
                        value: 'FREEZONE-EXEMPT-02',
                        label: isArabic
                            ? 'منطقة حرة (100%)'
                            : 'Free Zone (100%)'),
                    SearchableDropdownItem(
                        value: 'DIPLO-EXEMPT-03',
                        label: isArabic
                            ? 'إعفاء دبلوماسي (100%)'
                            : 'Diplomatic Exemption (100%)'),
                    SearchableDropdownItem(
                        value: 'PARTIAL-50-EXEMPT',
                        label: isArabic
                            ? 'إعفاء جزئي (50%)'
                            : 'Partial Exemption (50%)'),
                  ],
                  onChanged: (val) {
                    state.updateLineExemption(index, val);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: line['inspection'] as TextEditingController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isArabic
                        ? 'خدمات جمركية (ج.م)'
                        : 'Customs Services (EGP)',
                    hintText: '0.00',
                    isDense: true,
                  ),
                ),
              ),
              if (state.multiLines.length > 1) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.crimson, size: 18),
                  onPressed: () => state.removeLine(index),
                ),
              ],
            ],
          ),
          if (matchedTariff != null &&
              (matchedTariff.priorApprovalNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.orangeLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.orange, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isArabic
                            ? 'تنبيه إعفاء وشروط مستندية مطلوبة للمورد الخارجي (HS Code: ${matchedTariff.hsCode}):'
                            : 'Exemption & Documentary Requirements for Foreign Supplier (HS Code: ${matchedTariff.hsCode}):',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppTheme.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? '• توجد اتفاقيات وشروط مستندية يجب طلب استيفائها من المورد الخارجي (مثل شهادة EUR.1 الأصلي أو منشأ الميركسور) قبل تطبيق الإعفاء الجمركي:'
                        : '• Documentary requirements must be requested from foreign supplier (e.g. Original EUR.1 or Mercosur origin) prior to tariff exemption:',
                    style:
                        const TextStyle(fontSize: 10.5, color: AppTheme.orange),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    matchedTariff.priorApprovalNote!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Interactive Exemption Checklist Checkbox
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (line['is_exemption_conditions_met'] == true)
                  ? AppTheme.emeraldLight
                  : (isDark
                      ? AppTheme.darkSurface
                      : Colors.grey.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (line['is_exemption_conditions_met'] == true)
                    ? AppTheme.emerald
                    : (isDark
                        ? AppTheme.darkBorder
                        : Colors.grey.withValues(alpha: 0.25)),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: line['is_exemption_conditions_met'] == true,
                  activeColor: AppTheme.emerald,
                  onChanged: (bool? val) async {
                    final isChecked = val ?? false;
                    state.updateLineExemptionMet(index, isChecked);

                    // Task Automation:
                    if (isChecked && initialImportFileId != null) {
                      final hsCodeStr =
                          (line['hs'] as TextEditingController).text.trim();
                      try {
                        await ref.read(smartTasksProvider.notifier).createTask({
                          'title':
                              'Mandatory task: meet the exemption conditions for HS [$hsCodeStr] (matching certificate of origin / agreement requirements / required documents) to avoid the import duty.',
                          'description':
                              'The customs exemption conditions option was enabled in the customs calculator for HS $hsCodeStr. Meet the agreement conditions and provide the matching certificate of origin and all required documents to avoid the import duty.',
                          'task_type': 'System Generated',
                          'priority': 'Critical',
                          'reminder_type': 'Document',
                          'status': 'Pending',
                          'import_file_id': initialImportFileId,
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(
                              context,
                              isArabic
                                  ? 'مهمة إلزامية: تم تسجيل مهمة في قائمة مهام الشحنة لاستيفاء شروط ومستندات إعفاء البند [$hsCodeStr]'
                                  : 'Mandatory task created in shipment checklist for HS [$hsCodeStr] exemption conditions',
                              severity: AppSeverity.success,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (_) {}
                    }
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'هل سيتم استيفاء وتطبيق شروط الإعفاء الجمركي لهذا البند؟ (اتفاقية شراكة / تصنيع / شهادة منشأ مستوفاة)'
                        : 'Will customs exemption conditions be fulfilled for this item? (Partnership / Manufacturing / COO fulfilled)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: (line['is_exemption_conditions_met'] == true)
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: (line['is_exemption_conditions_met'] == true)
                          ? (isDark ? Colors.green.shade300 : AppTheme.emerald)
                          : (isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal),
                    ),
                  ),
                ),
                if (line['is_exemption_conditions_met'] == true)
                  AppStatusBadge(
                    label: isArabic ? 'معفى (0% جمرك)' : 'Exempt (0% Duty)',
                    severity: AppSeverity.success,
                    size: AppStatusBadgeSize.small,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
