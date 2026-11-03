// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../comprehensive_report/models/comprehensive_dossier_model.dart';

/// 🚢 Containers & Seal Matrix Card for Overview Tab
class OverviewContainersSealMatrixCard extends StatelessWidget {
  final ComprehensiveShipmentDossierModel? dossier;
  final bool isDark;
  final bool isAr;

  const OverviewContainersSealMatrixCard({
    super.key,
    this.dossier,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final containers = dossier?.containers ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_boat_filled_outlined, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                isAr ? 'حاويات الشحنة ومطابقة أرقام السيل' : 'Containers & Seal Matrix',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const Spacer(),
              if (containers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isAr ? '${containers.length} حاويات مسجلة' : '${containers.length} Containers',
                    style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (containers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'لم يتم تسجيل الحاويات وأرقام السيل بعد. يتم تأكيدها فور رص الحاويات في مرحلة الشحن الدولي.'
                          : 'Containers and seal numbers are not recorded yet. Confirmed upon container loading in international shipping.',
                      style: TextStyle(color: isDark ? Colors.amber.shade300 : Colors.amber.shade900, fontSize: 12),
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
              separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                    color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blueGrey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 16),
                          const SizedBox(width: 8),
                          SelectableText(
                            cNo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildCopyBadge(context, cNo, tooltip: isAr ? 'نسخ رقم الحاوية' : 'Copy Container No'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cType,
                              style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 14, color: isDark ? AppTheme.darkBorder : null),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(isAr ? 'سيل التوكيل الملاحي: ' : 'Liner Seal: ', style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                            const SizedBox(width: 8),
                            SelectableText(
                              lSeal,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            ),
                            if (lSeal != '—') ...[
                              const SizedBox(width: 4),
                              _buildCopyBadge(context, lSeal, tooltip: isAr ? 'نسخ سيل الخط' : 'Copy Liner Seal'),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(isAr ? 'سيل الترصيص الجمركي: ' : 'Customs Seal: ', style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                            const SizedBox(width: 8),
                            SelectableText(
                              cSeal,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: cSeal != '—' ? AppTheme.emerald : (isDark ? AppTheme.darkTextMuted : Colors.grey.shade600),
                              ),
                            ),
                            if (cSeal != '—') ...[
                              const SizedBox(width: 4),
                              _buildCopyBadge(context, cSeal, tooltip: isAr ? 'نسخ سيل الجمارك' : 'Copy Customs Seal'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(isAr ? 'وزن فارغ: $tare كجم' : 'Tare: $tare kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                          const SizedBox(width: 14),
                          Text(isAr ? 'وزن قائم: $gross كجم' : 'Gross: $gross kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
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

  Widget _buildCopyBadge(
    BuildContext context,
    String text, {
    String? tooltip,
    String? customMessage,
  }) {
    final tip = tooltip ?? (isAr ? 'نسخ: $text' : 'Copy: $text');

    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => CopyHelper.copy(context, text, customMessage: customMessage),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 11,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
