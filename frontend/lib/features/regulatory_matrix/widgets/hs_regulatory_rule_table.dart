import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/enterprise_data_table/enterprise_data_table.dart';
import '../models/regulatory_requirement.dart';

class HsRegulatoryRuleTable extends StatelessWidget {
  final List<RegulatoryRequirement> requirements;
  final bool isLoading;
  final ValueChanged<RegulatoryRequirement>? onSelectRequirement;

  const HsRegulatoryRuleTable({
    super.key,
    required this.requirements,
    this.isLoading = false,
    this.onSelectRequirement,
  });

  @override
  Widget build(BuildContext context) {
    return EnterpriseDataTable<RegulatoryRequirement>(
      data: requirements,
      isLoading: isLoading,
      storageKey: 'hs_regulatory_rule_table',
      title: 'مصفوفة المتطلبات الرقابية للبنوك الجمركية',
      emptyMessage: 'لا توجد متطلبات رقابية مطابقة لمعايير البحث الحالية',
      emptyIcon: Icons.rule_folder_outlined,
      enableSelection: false,
      enableExport: true,
      exportFileName: 'مصفوفة جهات العرض الرقابية للبنوك الجمركية',
      columns: [
        EnterpriseColumn<RegulatoryRequirement>(
          id: 'hs_code',
          title: 'البند الجمركي',
          cellBuilder: (ctx, item, idx) => InkWell(
            onTap: () => CopyHelper.copy(
              ctx,
              item.hsCode,
              customMessage: 'تم نسخ البند الجمركي بنجاح',
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.copy_outlined, size: 14, color: AppTheme.cobalt),
                const SizedBox(width: 4),
                Text(
                  item.hsCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                  ),
                ),
              ],
            ),
          ),
          width: 140,
        ),
        EnterpriseColumn<RegulatoryRequirement>(
          id: 'agency_name',
          title: 'جهة العرض الرقابية',
          cellBuilder: (ctx, item, idx) => Text(
            item.agencyNameAr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          width: 240,
        ),
        EnterpriseColumn<RegulatoryRequirement>(
          id: 'stage_timing',
          title: 'توقيت الطلب والمرحلة',
          cellBuilder: (ctx, item, idx) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              item.localizedTiming,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          width: 180,
        ),
        EnterpriseColumn<RegulatoryRequirement>(
          id: 'inspection_type',
          title: 'نوع الفحص المطلوب',
          cellBuilder: (ctx, item, idx) => Text(
            item.localizedInspection,
            style: const TextStyle(fontSize: 12),
          ),
          width: 160,
        ),
        EnterpriseColumn<RegulatoryRequirement>(
          id: 'required_documents',
          title: 'المستندات المطلوبة',
          cellBuilder: (ctx, item, idx) => Text(
            item.requiredDocuments ?? 'المستندات القياسية للشحنة',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          width: 220,
        ),
        EnterpriseColumn<RegulatoryRequirement>(
          id: 'is_mandatory',
          title: 'صفة الإلزام',
          cellBuilder: (ctx, item, idx) => AppStatusBadge(
            label: item.isMandatory ? 'إلزامي قطعي' : 'إجرائي اختياري',
            severity: item.isMandatory ? AppSeverity.danger : AppSeverity.info,
          ),
          width: 130,
        ),
        EnterpriseColumn<RegulatoryRequirement>(
          id: 'regulatory_notes',
          title: 'الضوابط والملاحظات الفنية',
          cellBuilder: (ctx, item, idx) => Text(
            item.regulatoryNotes ?? '-',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
          width: 250,
        ),
      ],
      onRowTap: onSelectRequirement,
    );
  }
}
