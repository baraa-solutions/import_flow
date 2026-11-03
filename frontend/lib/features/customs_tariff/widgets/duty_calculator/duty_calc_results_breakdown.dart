import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import 'duty_calculator_state.dart';

/// Detailed breakdown tables for calculated duties, taxes, per-line CIF allocations,
/// and official Nafeza statement fee codes.
class DutyCalcResultsBreakdown extends StatelessWidget {
  final Map<String, dynamic> multiResult;
  final bool isArabic;
  final bool isDark;

  const DutyCalcResultsBreakdown({
    super.key,
    required this.multiResult,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        Text(
          isArabic
              ? 'نتيجة حساب الشحنة (إقرار نافذة):'
              : 'Shipment Calculation Result (Nafeza Statement):',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.charcoal,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),

        // Multi-Item Line Items Results Table
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 32,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 32,
            headingRowColor: WidgetStateProperty.all(
              AppTheme.charcoal.withValues(alpha: 0.05),
            ),
            columns: [
              DataColumn(label: Text(isArabic ? 'سطر' : 'Line')),
              const DataColumn(label: Text('HS Code')),
              DataColumn(
                  label: Text(
                      isArabic ? 'المنشأ / الاتفاقية' : 'Origin / Agreement')),
              const DataColumn(label: Text('CIF (EGP)')),
              DataColumn(label: Text(isArabic ? 'جمرك' : 'Duty')),
              DataColumn(label: Text(isArabic ? 'ض.جدول' : 'Schedule Tax')),
              DataColumn(
                  label: Text(isArabic ? 'أ.ن.ص (1%)' : 'Service Fee (1%)')),
              const DataColumn(label: Text('VAT (14%)')),
              DataColumn(
                label: Text(
                  isArabic
                      ? 'ملاحظات الإعفاء والاتفاقيات'
                      : 'Exemption / Agreement Notes',
                ),
              ),
            ],
            rows: (multiResult['lines'] as List).map((l) {
              final isExempt = numToDouble(l['customs_duty_rate']) == 0.0 ||
                  l['is_exemption_applied'] == true;

              return DataRow(cells: [
                DataCell(Text('#${l['line_no']}')),
                DataCell(Text(l['hs_code'].toString())),
                DataCell(Text(
                  l['preferential_agreement_applied'] != null
                      ? '${l['origin_country']} (${isArabic ? "تفضيل 0%" : "Pref. 0%"})'
                      : '${l['origin_country'] ?? "-"}',
                )),
                DataCell(Text('${l['cif_value_egp']} EGP')),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${l['duty_egp']} EGP (${l['customs_duty_rate']}%)'),
                    if (isExempt) ...[
                      const SizedBox(width: 4),
                      AppStatusBadge(
                        label: isArabic
                            ? 'معفى بموجب اتفاقية / استيفاء الشروط'
                            : 'Exempt per agreement',
                        severity: AppSeverity.success,
                        size: AppStatusBadgeSize.small,
                      ),
                    ],
                  ],
                )),
                DataCell(Text('${l['schedule_tax_egp']} EGP')),
                DataCell(Text('${l['customs_service_fee_egp']} EGP (1%)')),
                DataCell(Text('${l['vat_egp']} EGP')),
                DataCell(Text(
                  l['exemption_applied_details'] ??
                      l['preferential_agreement_applied'] ??
                      (isArabic ? 'خاضع بالكامل' : 'Fully Taxable'),
                  style: TextStyle(
                    fontSize: 10,
                    color: (l['exemption_applied_details'] != null ||
                            l['preferential_agreement_applied'] != null)
                        ? AppTheme.emerald
                        : (isDark
                            ? AppTheme.darkTextPrimary
                            : Colors.black87),
                  ),
                )),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // ── Nafeza Statement Fee Codes Breakdown Table ──
        if (multiResult['fee_codes_breakdown'] != null) ...[
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.cobalt.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppTheme.cobaltLight,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long,
                              color: AppTheme.cobalt, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isArabic
                                ? 'تفاصيل بنود التحصيل والإقرارات الرسمية'
                                : 'Nafeza Statement Fee Breakdown & Official Declarations',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.cobalt,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isArabic
                            ? 'إجمالي البيان: ${numToDouble(multiResult['fee_codes_breakdown']['grand_total']).toStringAsFixed(2)} ج.م'
                            : 'Statement Grand Total: ${numToDouble(multiResult['fee_codes_breakdown']['grand_total']).toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.cobalt,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Grouped Fee Items
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      ...((multiResult['fee_codes_breakdown']['group_items']
                                  as Map<String, dynamic>? ??
                              {})
                          .entries
                          .map((groupEntry) {
                        final groupName = groupEntry.key;
                        final itemsList =
                            groupEntry.value as List<dynamic>? ?? [];
                        final groupSum = (multiResult['fee_codes_breakdown']
                                    ['by_group']
                                as Map<String, dynamic>? ??
                            {})[groupName] ??
                            0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkCardBackground
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkBorder
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Group Subheader Bar
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                color: AppTheme.charcoal
                                    .withValues(alpha: 0.08),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isArabic
                                          ? 'تحصيل $groupName'
                                          : 'Collection: $groupName',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppTheme.charcoal,
                                      ),
                                    ),
                                    Text(
                                      '${numToDouble(groupSum).toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppTheme.charcoal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Group Items List
                              ...itemsList.map((item) {
                                final itemMap = item as Map<String, dynamic>;
                                final code =
                                    itemMap['code']?.toString() ?? '';
                                final name =
                                    itemMap['name_ar']?.toString() ?? '';
                                final calcType =
                                    itemMap['calculation_type']?.toString() ??
                                        'flat';
                                final amt =
                                    numToDouble(itemMap['calculated_amount']);
                                final typeLabel = calcType == 'flat'
                                    ? (isArabic ? 'قطعي' : 'Flat')
                                    : (calcType == 'reference'
                                        ? (isArabic ? 'مرجعي' : 'Ref')
                                        : (isArabic ? 'مشتق' : 'Derived'));

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppTheme.darkSurface
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '[$code]',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        typeLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      SizedBox(
                                        width: 95,
                                        child: Text(
                                          '${amt.toStringAsFixed(2)} ${isArabic ? "ج.م" : "EGP"}',
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
