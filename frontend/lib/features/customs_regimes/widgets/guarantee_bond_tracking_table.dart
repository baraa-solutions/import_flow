import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../customs_regimes_provider.dart';

class GuaranteeBondTrackingTable extends StatelessWidget {
  final List<CustomsRegimeItem> items;
  final ValueChanged<CustomsRegimeItem> onSelect;
  final ValueChanged<CustomsRegimeItem> onSettle;

  const GuaranteeBondTrackingTable({
    super.key,
    required this.items,
    required this.onSelect,
    required this.onSettle,
  });

  String _formatRegimeType(String type) {
    switch (type) {
      case 'TEMPORARY_ADMISSION':
        return 'السماح المؤقت';
      case 'DRAWBACK':
        return 'الدروباك';
      case 'FREE_ZONE':
        return 'المناطق الحرة';
      case 'CUSTOMS_WAREHOUSE':
        return 'المستودعات الجمركية';
      case 'TRANSIT':
        return 'الترانزيت';
      default:
        return type;
    }
  }

  String _formatGuaranteeType(String? type) {
    switch (type) {
      case 'LETTER_OF_GUARANTEE':
        return 'خطاب ضمان بنكي';
      case 'CASH_DEPOSIT':
        return 'أمانة نقدية معلقة';
      case 'INSURANCE_POLICY':
        return 'وثيقة تأمين';
      case 'PROMISSORY_NOTE':
        return 'سند لأمر';
      default:
        return 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'لا توجد سجلات نظم معلقة مسجلة حالياً',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.sorourSurfaceTint),
            columns: const [
              DataColumn(label: Text('كود السجل')),
              DataColumn(label: Text('النظام الجمركي')),
              DataColumn(label: Text('نوع الضمان')),
              DataColumn(label: Text('البنك / المرجع')),
              DataColumn(label: Text('قيمة الضمان')),
              DataColumn(label: Text('تاريخ انتهاء الضمان')),
              DataColumn(label: Text('حالة السجل')),
              DataColumn(label: Text('الإجراءات')),
            ],
            rows: items.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    InkWell(
                      onTap: () => CopyHelper.copy(context, item.regimeCode),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.regimeCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  ),
                  DataCell(Text(_formatRegimeType(item.regimeType))),
                  DataCell(Text(_formatGuaranteeType(item.guaranteeType))),
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(item.guaranteeBank ?? 'بدون بنك', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (item.guaranteeReference != null)
                          Text(item.guaranteeReference!, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      '${item.guaranteeAmount.toStringAsFixed(2)} ${item.guaranteeCurrency}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.guaranteeExpiryDate != null
                          ? item.guaranteeExpiryDate!.toIso8601String().substring(0, 10)
                          : 'غير محدد',
                      style: TextStyle(
                        color: item.guaranteeActive ? AppTheme.emerald : AppTheme.crimson,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    AppStatusBadge.fromStatus(
                      status: item.status,
                      label: item.status == 'SETTLED'
                          ? 'تمت التسوية'
                          : item.status == 'ACTIVE'
                              ? 'ساري'
                              : 'مغلق',
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.cobalt),
                          tooltip: 'عرض التفاصيل',
                          onPressed: () => onSelect(item),
                        ),
                        if (item.status == 'ACTIVE')
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.emerald),
                            tooltip: 'تسوية النظام',
                            onPressed: () => onSettle(item),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
