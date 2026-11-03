import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/logistics_rule.dart';

/// Helper to classify and group rules by field party for auditing questionnaire.
String classifyRuleParty(String ruleKey) {
  final key = ruleKey.toUpperCase();
  if (key.contains('DAMAGE') || key.contains('TIME_BAR') || key.contains('CLAIM_SUIT')) {
    return 'المستشار القانوني / محامي بحري';
  } else if (key.contains('BANK') || key.contains('FORM4') || key.contains('FORM_4')) {
    return 'البنك المعتمد';
  } else if (key.contains('ACID') ||
      key.contains('DO_') ||
      key.contains('PRE_CLEARANCE') ||
      key.contains('CUSTOMS')) {
    return 'المخلص الجمركي المعتمد';
  } else if (key.contains('DEMURRAGE') ||
      key.contains('DETENTION') ||
      key.contains('SHIPPING_LINE')) {
    return 'التوكيل الملاحي';
  } else if (key.contains('INSURANCE')) {
    return 'شركة التأمين البحري';
  } else if (key.contains('ROAD') || key.contains('PAYLOAD') || key.contains('TRANSPORT')) {
    return 'شركة النقل البري';
  }
  return 'جهة الاختصاص';
}

Map<String, List<LogisticsRule>> groupRulesByParty(List<LogisticsRule> rules) {
  final map = <String, List<LogisticsRule>>{};
  for (final r in rules) {
    final party = classifyRuleParty(r.ruleKey);
    map.putIfAbsent(party, () => []).add(r);
  }
  return map;
}

/// Dialog presenting field verification checklist and CSV export capability.
class LogisticsRulesExportDialog extends ConsumerStatefulWidget {
  final List<LogisticsRule> rules;

  const LogisticsRulesExportDialog({super.key, required this.rules});

  @override
  ConsumerState<LogisticsRulesExportDialog> createState() =>
      _LogisticsRulesExportDialogState();
}

class _LogisticsRulesExportDialogState
    extends ConsumerState<LogisticsRulesExportDialog> {
  bool _isExporting = false;

  Future<void> _exportChecklist() async {
    setState(() => _isExporting = true);

    try {
      final buffer = StringBuffer();
      // UTF-8 BOM for Excel Arabic support
      buffer.write('\uFEFF');
      buffer.writeln(
          'م,رمز القاعدة,اسم القاعدة بالعربية,اسم القاعدة بالإنجليزية,الوحدة,القيمة الاحترازية الحالية,الجهة الميدانية المختصة,المرجع اللائحي المقترح,حالة التوثيق');

      int index = 1;
      for (final r in widget.rules) {
        final party = classifyRuleParty(r.ruleKey);
        buffer.writeln(
            '$index,"${r.ruleKey}","${r.ruleNameAr}","${r.ruleNameEn}","${r.valueUnit}","${r.conservativeDefault ?? ""}","$party","${r.sourceRef ?? ""}","${r.verificationStatus}"');
        index++;
      }

      await FileSaveHelper.saveText(
        context: context,
        textContent: buffer.toString(),
        defaultFileName: 'قائمة الأسئلة الميدانية - قواعد التشغيل.csv',
        dialogTitle: 'حفظ قائمة الأسئلة الميدانية',
        allowedExtensions: ['csv', 'txt'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التصدير: $e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unverified = widget.rules.where((r) => !r.isVerified).toList();
    final grouped = groupRulesByParty(unverified);

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 720,
          height: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  const Text(
                    'قائمة الأسئلة الميدانية للتحقق (Field Questionnaire)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cobaltBorder),
                ),
                child: Text(
                  'يوجد ${unverified.length} قاعدة تشغيلية غير موثقة رسمياً. يمكنك مراجعة الأسئلة وتصديرها كملف جدول بيانات لمشاركتها مع الجهات المختصة.',
                  style: const TextStyle(color: AppTheme.charcoal, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: grouped.entries.map((entry) {
                    return ExpansionTile(
                      initiallyExpanded: true,
                      leading: const Icon(Icons.account_balance,
                          color: AppTheme.cobalt, size: 20),
                      title: Text(
                        '${entry.key} (${entry.value.length} قواعد)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      children: entry.value.map((rule) {
                        return ListTile(
                          dense: true,
                          title: Text(rule.ruleNameAr,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${rule.ruleKey} | افتراضي: ${rule.conservativeDefault ?? "NULL"} (${rule.valueUnit})',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                          trailing: rule.sourceRef != null
                              ? Chip(
                                  label: Text(
                                    rule.sourceRef!,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: AppTheme.cloudWhite,
                                )
                              : null,
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'إغلاق',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'تصدير جدول الأسئلة (CSV / Excel)',
                    icon: Icons.file_download,
                    variant: AppButtonVariant.primary,
                    isLoading: _isExporting,
                    onPressed: _exportChecklist,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
