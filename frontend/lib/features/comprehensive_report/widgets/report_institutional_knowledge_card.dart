import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_card_container.dart';
import 'report_copy_badge.dart';

/// Institutional knowledge, past patterns, and experience guide card for Comprehensive Report.
class ReportInstitutionalKnowledgeCard extends StatefulWidget {
  final ComprehensiveShipmentDossierModel? dossier;
  final ImportFileModel file;
  final Set<int>? initialAcknowledgedAlerts;

  const ReportInstitutionalKnowledgeCard({
    super.key,
    required this.file,
    this.dossier,
    this.initialAcknowledgedAlerts,
  });

  @override
  State<ReportInstitutionalKnowledgeCard> createState() => _ReportInstitutionalKnowledgeCardState();
}

class _ReportInstitutionalKnowledgeCardState extends State<ReportInstitutionalKnowledgeCard> {
  late Set<int> _acknowledgedAlerts;

  @override
  void initState() {
    super.initState();
    _acknowledgedAlerts = widget.initialAcknowledgedAlerts != null
        ? Set<int>.from(widget.initialAcknowledgedAlerts!)
        : <int>{};
  }

  @override
  Widget build(BuildContext context) {
    final dossier = widget.dossier;
    final kb = dossier?.institutionalKnowledge;
    final criticalEntries = (kb?['critical_entries'] as List<dynamic>?) ?? [];
    final warningEntries = (kb?['warning_entries'] as List<dynamic>?) ?? [];
    final matchedEntries = (kb?['matched_entries'] as List<dynamic>?) ?? [];
    final requiredDocs = (kb?['required_documents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final suggestedNotes = (kb?['suggested_notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final hasCritical = kb?['has_critical_alert'] == true || criticalEntries.isNotEmpty;
    final hasSimilar = dossier?.similarPastShipments.isNotEmpty == true;
    final hasPatterns = dossier?.recurringPatterns.isNotEmpty == true;
    final hasKbContent = criticalEntries.isNotEmpty ||
        warningEntries.isNotEmpty ||
        matchedEntries.isNotEmpty ||
        requiredDocs.isNotEmpty ||
        suggestedNotes.isNotEmpty ||
        hasSimilar ||
        hasPatterns;

    return ReportCardContainer(
      title: 'الذاكرة المؤسسية ودليل الخبرة ومطابقة الأنماط (Institutional Knowledge & KB Engine)',
      icon: Icons.psychology_outlined,
      iconColor: hasCritical ? AppTheme.crimson : const Color(0xFF7C3AED),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasKbContent)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تسجيل تنبيهات خاصة أو أنماط حرجة سابقة لهذا المورد أو الميناء في الذاكرة المؤسسية حتى الآن.',
                      style: TextStyle(color: AppTheme.charcoal, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // 1. Critical Alerts with Acknowledgment Requirement
            if (criticalEntries.isNotEmpty) ...[
              const Text(
                '🚨 تنبيهات حرجة ومخاطر تشغيلية (تتطلب إقرار واطلاع مسؤول الشحن):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.crimson),
              ),
              const SizedBox(height: 8),
              ...criticalEntries.map((entry) {
                final entryId = (entry['entry_id'] as num?)?.toInt() ?? 0;
                final title = entry['title']?.toString() ?? 'تنبيه حرج';
                final content = entry['content']?.toString() ?? '';
                final isAck = _acknowledgedAlerts.contains(entryId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAck ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isAck ? AppTheme.emerald : AppTheme.crimson,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAck ? Icons.verified_user_outlined : Icons.warning_rounded,
                            color: isAck ? AppTheme.emerald : AppTheme.crimson,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isAck ? Colors.green.shade900 : AppTheme.crimson,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ReportCopyBadge(textToCopy: title),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        content,
                        style: const TextStyle(fontSize: 12, color: AppTheme.charcoal, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isAck)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.emerald),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: AppTheme.emerald),
                                  SizedBox(width: 6),
                                  Text(
                                    'تم الاطلاع والإقرار بالمسؤولية التشغيلية',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                  ),
                                ],
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.crimson,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.touch_app, size: 15),
                              label: const Text(
                                'إقرار واطلاع مطلوب (اضغط للتأكيد)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                setState(() {
                                  _acknowledgedAlerts.add(entryId);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  AppTheme.snackBar(context, 'تم تسجيل إقرار واطلاع مسؤول الشحن على تنبيه: $title', severity: AppSeverity.success),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],

            // 2. Warnings & Operational Lessons
            if (warningEntries.isNotEmpty) ...[
              const Text(
                '⚠️ تحذيرات ودروس مستفادة من شحنات سابقة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFB45309)),
              ),
              const SizedBox(height: 8),
              ...warningEntries.map((entry) {
                final title = entry['title']?.toString() ?? 'تنبيه';
                final content = entry['content']?.toString() ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              content,
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],

            // 3. Required Regulatory Documents & Certificates
            if (requiredDocs.isNotEmpty) ...[
              const Text(
                '📋 المستندات والشهادات الإلزامية المطلوبة جمركياً بحسب النمط:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: requiredDocs.map((doc) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_outlined, size: 14, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 6),
                        SelectableText(
                          doc,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                        ),
                        const SizedBox(width: 6),
                        ReportCopyBadge(textToCopy: doc),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // 4. Suggested Operational Notes
            if (suggestedNotes.isNotEmpty) ...[
              const Text(
                '💡 إرشادات ونصائح تشغيلية مقترحة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal),
              ),
              const SizedBox(height: 6),
              ...suggestedNotes.map((note) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                      Expanded(
                        child: SelectableText(
                          note,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // 5. Similar Past Shipments Accordion
            if (dossier != null && dossier.similarPastShipments.isNotEmpty) ...[
              const SizedBox(height: 14),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  leading: const Icon(Icons.history_toggle_off, color: Color(0xFF2563EB), size: 20),
                  title: Text(
                    'سجل الشحنات السابقة المماثلة (${dossier.similarPastShipments.length} شحنة مطابقة بالكامل):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E3A8A)),
                  ),
                  children: dossier.similarPastShipments.map((s) {
                    final fCode = s['file_code']?.toString() ?? s['import_file_code']?.toString() ?? '—';
                    final sName = s['supplier_name']?.toString() ?? '—';
                    final cbm = s['cbm'] != null ? '${s['cbm']} m³' : (s['total_cbm'] != null ? '${s['total_cbm']} m³' : '—');
                    final days = s['duration_days'] != null ? '${s['duration_days']} يوم' : (s['clearance_duration_days'] != null ? '${s['clearance_duration_days']} يوم' : '—');
                    final cost = s['actual_landed_cost'] != null ? '${(s['actual_landed_cost'] as num).toStringAsFixed(0)} ج.م' : (s['status']?.toString() ?? 'مكتمل');
                    final variance = s['variance_pct'] != null ? '${s['variance_pct']}%' : (s['cost_variance_pct'] != null ? '${s['cost_variance_pct']}%' : '0.0%');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Icon(Icons.folder_shared_outlined, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            SelectableText(
                              fCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(width: 8),
                            ReportCopyBadge(textToCopy: fCode),
                            const SizedBox(width: 14),
                            Text('المورد: $sName', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            const SizedBox(width: 14),
                            Text('الحجم: $cbm', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                            const SizedBox(width: 12),
                            Text('المدة: $days', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                            const SizedBox(width: 12),
                            Text('التكلفة: $cost', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('انحراف: $variance', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // 6. Recurring Operational Patterns Accordion
            if (dossier != null && dossier.recurringPatterns.isNotEmpty) ...[
              const SizedBox(height: 14),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  leading: const Icon(Icons.auto_graph, color: Color(0xFF7C3AED), size: 20),
                  title: Text(
                    'الأنماط التشغيلية المتكررة المكتشفة (${dossier.recurringPatterns.length} نمط متكرر):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF5B21B6)),
                  ),
                  children: dossier.recurringPatterns.map((p) {
                    final title = p['suggested_title']?.toString() ?? p['pattern_title']?.toString() ?? p['title']?.toString() ?? 'نمط تشغيلي';
                    final desc = p['suggested_content']?.toString() ?? p['pattern_description']?.toString() ?? p['description']?.toString() ?? '';
                    final conf = (p['confidence_score'] as num?)?.toDouble() ?? 0.85;
                    final rec = p['suggested_severity']?.toString() ?? p['severity']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb, size: 16, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6B21A8)),
                                ),
                              ),
                              if (conf > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFDDD6FE)),
                                  ),
                                  child: Text(
                                    'ثقة: ${(conf * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8)),
                                  ),
                                ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            SelectableText(
                              desc,
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal, height: 1.3),
                            ),
                          ],
                          if (rec.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'الإجراء المقترح: $rec',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4C1D95)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
