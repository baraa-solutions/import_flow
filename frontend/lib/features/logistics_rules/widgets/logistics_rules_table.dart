import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/logistics_rule.dart';
import 'logistics_rule_form_dialog.dart';
import 'logistics_rule_verify_dialog.dart';

/// Data table component for rendering operational logistics rules.
/// Pure presentation widget supporting parallel UI composition.
class LogisticsRulesTable extends StatelessWidget {
  final List<LogisticsRule> rules;

  const LogisticsRulesTable({super.key, required this.rules});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(AppTheme.sorourSurfaceTint),
              columns: const [
                DataColumn(label: Text('القاعدة التشغيلية')),
                DataColumn(label: Text('الوحدة')),
                DataColumn(label: Text('القيمة الاحترازية')),
                DataColumn(label: Text('القيمة الموثقة')),
                DataColumn(label: Text('مستوى الإلزام / الحماية')),
                DataColumn(label: Text('المرجع اللائحي')),
                DataColumn(label: Text('الإجراءات')),
              ],
              rows: rules.map((r) => _buildDataRow(context, r)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(BuildContext context, LogisticsRule r) {
    Color verifiedColor;
    String verifiedText;

    if (r.verifiedValue == null || r.verifiedValue!.isEmpty) {
      verifiedColor = AppTheme.crimson;
      verifiedText = 'غير محدد (NULL)';
    } else if (r.verificationStatus == 'VERIFIED') {
      verifiedColor = AppTheme.emerald;
      verifiedText = r.verifiedValue!;
    } else {
      verifiedColor = AppTheme.orange;
      verifiedText = '${r.verifiedValue!} (غير معتمد)';
    }

    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                r.ruleNameAr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${r.ruleKey} (v${r.versionId})',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        DataCell(Text(r.valueUnit)),
        DataCell(
          Text(
            r.conservativeDefault ?? '—',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        DataCell(
          Text(
            verifiedText,
            style: TextStyle(
              color: verifiedColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          r.safetyGuardTriggered
              ? Tooltip(
                  message: r.guardReason ?? 'حارس الأمان خفض الإلزام إلى تنبيه',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.warningForeground),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppTheme.warningForeground),
                        SizedBox(width: 4),
                        Text(
                          'تحذير (حارس أمان)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Chip(
                  label: Text(
                    r.enforcementLevel,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: r.enforcementLevel == 'BLOCKING'
                      ? AppTheme.dangerBackground
                      : AppTheme.cloudWhite,
                ),
        ),
        DataCell(
          SizedBox(
            width: 180,
            child: Text(
              r.sourceRef ?? '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'توثيق واعتماد رسمي',
                icon: const Icon(Icons.verified_outlined,
                    color: AppTheme.emerald, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => LogisticsRuleVerifyDialog(rule: r),
                  );
                },
              ),
              IconButton(
                tooltip: 'تعديل وإنشاء نسخة',
                icon: const Icon(Icons.edit_outlined,
                    color: AppTheme.cobalt, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => LogisticsRuleFormDialog(rule: r),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
