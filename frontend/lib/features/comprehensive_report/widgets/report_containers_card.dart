import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_card_container.dart';
import 'report_copy_badge.dart';

/// Containers and seal numbers matrix card for Comprehensive Report.
class ReportContainersCard extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;

  const ReportContainersCard({
    super.key,
    required this.file,
    this.dossier,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containers = dossier?.containers ?? [];

    return ReportCardContainer(
      title: 'حاويات الشحنة ومطابقة أرقام السيل (Containers & Seal Matrix)',
      icon: Icons.directions_boat_filled_outlined,
      iconColor: AppTheme.cobalt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (containers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تسجيل الحاويات وأرقام السيل بعد. يتم تأكيدها فور رص الحاويات في مرحلة الشحن الدولي (Phase 5).',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: containers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, idx) {
                final c = containers[idx];
                final cNo = c['container_no']?.toString() ?? 'CONT-${idx + 1}';
                final cType = c['container_type']?.toString() ?? '-';
                final lSeal = c['liner_seal_no']?.toString() ?? c['seal_no']?.toString() ?? '—';
                final cSeal = c['customs_seal_no']?.toString() ?? '—';
                final tare = c['tare_weight_kg'] ?? 0.0;
                final gross = c['gross_weight_kg'] ?? 0.0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blueGrey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 18),
                          const SizedBox(width: 8),
                          SelectableText(
                            cNo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                          ),
                          const SizedBox(width: 6),
                          ReportCopyBadge(textToCopy: cNo),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cType,
                              style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      // Liner Seal Row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Text('سيل التوكيل / الخط الملاحي:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 8),
                            SelectableText(
                              lSeal,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                            ),
                            if (lSeal != '—') ...[
                              const SizedBox(width: 4),
                              ReportCopyBadge(textToCopy: lSeal),
                            ],
                          ],
                        ),
                      ),
                      // Customs Seal Row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Text('سيل الجمارك / الترصيص الجمركي:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 8),
                            SelectableText(
                              cSeal,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: cSeal != '—' ? AppTheme.emerald : Colors.grey.shade600,
                              ),
                            ),
                            if (cSeal != '—') ...[
                              const SizedBox(width: 4),
                              ReportCopyBadge(textToCopy: cSeal),
                            ],
                          ],
                        ),
                      ),
                      // Weights
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('وزن فارغ: $tare كجم', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(width: 14),
                          Text('وزن قائم: $gross كجم', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const Spacer(),
                          Text('VGM: ${c['vgm_status'] ?? "-"}', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
