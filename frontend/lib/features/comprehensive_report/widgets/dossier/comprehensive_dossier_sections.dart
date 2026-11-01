import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/comprehensive_dossier_model.dart';

/// 10-Phase Sections Status Breakdown for ComprehensiveDossierExportDialog
class ComprehensiveDossierSectionsBreakdown extends StatelessWidget {
  final ComprehensiveShipmentDossierModel dossier;

  const ComprehensiveDossierSectionsBreakdown({
    super.key,
    required this.dossier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مراحل وجاهزية الملف الاستيرادي الشامل (10 Phases):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.flatCharcoal),
              ),
              Text(
                'مكتمل ${dossier.sections.where((s) => s.status == "COMPLETED").length} من 10 مراحل',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.flatEmerald),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dossier.sections.map((sec) {
              final isCompleted = sec.status == 'COMPLETED';
              final isInProgress = sec.status == 'IN_PROGRESS';
              final badgeColor = isCompleted
                  ? AppTheme.flatEmerald
                  : (isInProgress ? AppTheme.flatCobalt : Colors.grey.shade600);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : (isInProgress ? Icons.hourglass_top : Icons.radio_button_unchecked),
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${sec.sectionCode}: ${sec.sectionNameAr}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                        color: AppTheme.flatCharcoal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sec.statusAr,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
