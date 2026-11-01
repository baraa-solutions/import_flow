import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/guide_entry_model.dart';

/// Contributing files table and evidence reasoning cards for autonomous evidence trail
class EvidenceTrailContributingFiles extends StatelessWidget {
  final ProvenanceModel provenance;
  final String? initialReason;
  final String? initialEvidence;

  const EvidenceTrailContributingFiles({
    super.key,
    required this.provenance,
    this.initialReason,
    this.initialEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final p = provenance;
    final reasonText = initialReason ?? p.reasonWhy;
    final evidenceText = initialEvidence ?? p.evidenceSummary;
    final files = p.contributingFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Why am I seeing this note? (Panel)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_outline_rounded, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لماذا يظهر هذا الاستنتاج التشغيلي؟',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reasonText ?? 'تم رصد هذا النمط تلقائياً استناداً إلى نتائج وتكرار البيانات في الشحنات السابقة.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Evidence Summary Card
        if (evidenceText != null && evidenceText.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.fact_check_outlined, size: 16, color: AppTheme.charcoal),
                    SizedBox(width: 6),
                    Text(
                      'ملخص الإثبات والقياس الإحصائي (Comparative Metrics):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  evidenceText,
                  style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.charcoal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Contributing Files Table
        Row(
          children: [
            const Icon(Icons.table_rows_rounded, size: 16, color: AppTheme.cobalt),
            const SizedBox(width: 6),
            Text(
              'الشحنات السابقة المساهمة في هذا الاستنتاج (${files.length} شحنات):',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (files.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('لا توجد تفاصيل شحنات تفصيلية مسجلة في هذا الاستنتاج', style: TextStyle(fontSize: 12)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Table(
                border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade200)),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('كود الشحنة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('المقياس المرصود', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('حالة الشحنة / التفاصيل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...files.map((f) {
                    final code = f['import_file_code'] ?? f['booking_id']?.toString() ?? 'SHP';
                    final metric = f['metric_measured'] ?? f['variance_egp']?.toString() ?? '-';
                    final status = f['file_status'] ?? f['status'] ?? f['route'] ?? 'مسجلة';

                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            code.toString(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            metric.toString(),
                            style: const TextStyle(fontSize: 12, color: AppTheme.crimson, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            status.toString(),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
