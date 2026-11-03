import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class TariffSmartTextModeView extends StatelessWidget {
  final TextEditingController rawTextCtrl;
  final Map<String, dynamic>? parsedTariffData;
  final List<Map<String, dynamic>> parsedAgreements;
  final Map<String, dynamic>? parsedComparisonData;
  final String? parseError;
  final ValueChanged<String> onParseRequested;
  final VoidCallback onSwitchToManual;

  const TariffSmartTextModeView({
    super.key,
    required this.rawTextCtrl,
    required this.parsedTariffData,
    required this.parsedAgreements,
    required this.parsedComparisonData,
    required this.parseError,
    required this.onParseRequested,
    required this.onSwitchToManual,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Examples Toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  l10n.quickExamplesLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.ac_unit, size: 14, color: AppTheme.cobalt),
                  label: Text(l10n.exampleAirConditioners, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    rawTextCtrl.text = '''رقم البند :
8415820010
نص البند :
آلات وأجهزة تكييف أخر متضمنة وحدة تبريد ، وحدات كاملة .
الضرائب :
ضريبة الوارد :
60.000 %
ضريبة الجدول :
8.000 %
ضريبة قيمه مضافه :
14.000 %
المستندات والأعمال :
ر6722 - اتفاقية صربيا تخفيض 10%
ق4518 - لايصرح باستيراد صنف الا بموافقة مختومة بخاتم شعارجمهوريةمن هـ .ع.ص.وطبقا لملحق8 وتعديلاته
ر6668 - تخفض ض .ج ورسوم بنسبة100%علىسلع صناعيةواردةفى ظل اتفاقية الشراكةالمصرية والمملكة المتحدة
ق9994 - لايفرج عن صنف بضاعة مرشدةللمنطقة الحرة الابحصص لكل مستورد يحددهاجهاز تنفيذى للمنطقةالحرة
ر6704 - فى ظل اتفاق التجارة الحرة بين مصر وتجمع الميركسور تحصل ضريبة جمركية بنسبة 3%
ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%
ر6607 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة100%
ر6663 - تخفض ضريبةجمركيةورسوم ذات أثر مماثل بنسبة 100% علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2''';
                    onParseRequested(rawTextCtrl.text);
                  },
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.category_outlined, size: 14, color: AppTheme.orange),
                  label: Text(l10n.examplePlasticsBuilding, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    rawTextCtrl.text = '''رقم البند :
3925900090
نص البند :
أصناف أخر لتجهيزات البناء من لدائن ، غير مذكورة أو داخلة في مكان أخر .
الضرائب :
ضريبة الوارد (النظام الاساسي) :
40.000 %
ضريبة الوارد (اتفاقية أمريكا اللاتينية الميركسور) :
3.000 %
ضريبة قيمه مضافه :
14.000 %
المستندات والأعمال :
ر6722 - اتفاقية صربيا تخفيض 10%
ر6668 - تخفض ض .ج ورسوم بنسبة100%علىسلع صناعيةواردةفى ظل اتفاقية الشراكةالمصرية والمملكة المتحدة
ر6706 - تحصل ض. وارد طبقا للفئات الموضحة قرين كل بند على سلع واردة فى إطار إتفاقيةالميركسور
ر6631 - يعفى من الضريبة الجمركية والرسوم ذات الاثر المماثل الأصناف الواردة من دول الافتا بنسبة100%
ر6607 - تخفض الرسوم الجمركية فى ظل اتفاقيةتركيا بنسبة100% على اصناف واردةبالقائمة 1 برتوكول 1
ر6663 - تخفض ضريبةجمركيةورسوم ذات أثر مماثل بنسبة 100% علىسلع صناعيةواردةفى ظل شراكةأوربيةملحق2''';
                    onParseRequested(rawTextCtrl.text);
                  },
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 16, color: Colors.grey),
                  label: Text(l10n.clearTextBtn, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  onPressed: () {
                    rawTextCtrl.clear();
                    onParseRequested('');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: rawTextCtrl,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: l10n.pasteTariffBlockLabel,
              hintText: l10n.pasteTariffBlockHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.cobalt),
                    tooltip: l10n.copyTooltip,
                    onPressed: () => CopyHelper.copy(context, rawTextCtrl.text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high, color: AppTheme.cobalt),
                    tooltip: l10n.parseNowTooltip,
                    onPressed: () => onParseRequested(rawTextCtrl.text),
                  ),
                ],
              ),
            ),
            onChanged: onParseRequested,
          ),
          if (parseError != null) ...[
            const SizedBox(height: 8),
            Text('⚠️ $parseError', style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 10),

          // Live Parsed Preview Box
          if (parsedTariffData != null && (parsedTariffData!['hs_code'] as String).isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.emerald, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        l10n.parsedPreviewHeader(parsedTariffData!['hs_code']),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emerald),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onSwitchToManual,
                        icon: const Icon(Icons.edit, size: 14),
                        label: Text(l10n.editFieldsManuallyBtn, style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الوصف: ${parsedTariffData!['hs_description']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text('ضريبة الوارد: ${parsedTariffData!['customs_duty_rate']}%'),
                        backgroundColor: Colors.blue.shade50,
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text('ضريبة الجدول: ${parsedTariffData!['schedule_tax_rate']}%'),
                        backgroundColor: Colors.purple.shade50,
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text('القيمة المضافة: ${parsedTariffData!['vat_rate']}%'),
                        backgroundColor: Colors.green.shade50,
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (parsedTariffData!['regulatory_authority'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'الجهة الرقابية: ${parsedTariffData!['regulatory_authority']}',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800, fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (parsedAgreements.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'الاتفاقيات التفضيلية المستخرجة (${parsedAgreements.length} اتفاقية):',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: parsedAgreements.map((ag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            '${ag['publication_notice'] ?? ""}: ${ag['agreement_name']} ${ag['preferential_duty_rate'] != null ? "(${ag['preferential_duty_rate']}%)" : ""}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Diff Comparison & Version History Section
          if (parsedComparisonData != null) ...[
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final comp = parsedComparisonData!;
              final hasPrev = comp['has_previous_version'] == true;
              final prevFrom = comp['previous_effective_from'];
              final prevTo = comp['previous_effective_to'];
              final newFrom = comp['new_effective_from'];
              final diffItems = (comp['diff_items'] as List?) ?? [];

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_edu, color: AppTheme.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          hasPrev ? l10n.diffHistoryTitle : l10n.newHsVersionTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasPrev) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '📅 النسخة السابقة: من ${prevFrom ?? "—"} حتى ${prevTo ?? "اليوم"}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.crimson),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '⚡ النسخة الجديدة سارية من: ${newFrom ?? "اليوم"}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (comp['summary_ar'] != null)
                      Text(
                        comp['summary_ar'],
                        style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, height: 1.4),
                      ),
                    if (diffItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.diffDetailsHeader,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      ...diffItems.map((item) {
                        final hexColorStr = item['color_code'] ?? '#2C3E50';
                        final colorVal = int.tryParse(hexColorStr.replaceFirst('#', '0xFF')) ?? 0xFF2C3E50;
                        final itemColor = Color(colorVal);
                        final changeType = item['change_type'] ?? 'unchanged';

                        IconData icon = Icons.info_outline;
                        if (changeType == 'added') icon = Icons.add_circle_outline;
                        if (changeType == 'removed') icon = Icons.remove_circle_outline;
                        if (changeType == 'modified') icon = Icons.edit_note;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: itemColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: itemColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, size: 14, color: itemColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['summary_ar'] ?? item['description_ar'] ?? item['agreement_name'] ?? '',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: itemColor),
                                    ),
                                    if (item['old_value_desc'] != null && item['new_value_desc'] != null)
                                      Text(
                                        'السابق: ${item['old_value_desc']} ➔ الجديد: ${item['new_value_desc']}',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                      ),
                                  ],
                                ),
                              ),
                              if (item['publication_notice'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: itemColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['publication_notice'],
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: itemColor),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
