import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_basic_info_card.dart';
import 'report_card_container.dart';

/// Foreign exchange reconciliation and bank vs customs rate variance card.
class ReportFxReconciliationCard extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;

  const ReportFxReconciliationCard({
    super.key,
    required this.file,
    this.dossier,
  });

  @override
  Widget build(BuildContext context) {
    final fx = dossier?.fxReconciliation;
    final customsRate = fx?['customs_exchange_rate'];
    final bankRate = fx?['commercial_bank_exchange_rate'];
    final varianceRate = fx?['fx_variance_rate'] ?? 0.0;
    final varianceTotal = fx?['fx_variance_total_egp'] ?? 0.0;
    final hasVariance = fx?['has_variance'] == true;

    return ReportCardContainer(
      title: 'مطابقة أسعار الصرف وفروق تدبير العملة (FX Variance)',
      icon: Icons.currency_exchange_outlined,
      iconColor: AppTheme.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReportBasicInfoCard.buildInfoRow(context, 'سعر الصرف الجمركي (جمارك/ضرائب):', customsRate != null ? '$customsRate ج.م' : '—'),
          ReportBasicInfoCard.buildInfoRow(context, 'سعر صرف البنك التجاري (التحويل):', bankRate != null ? '$bankRate ج.م' : '—'),
          ReportBasicInfoCard.buildInfoRow(context, 'فرق سعر الصرف لكل وحدة عملة:', '$varianceRate ج.م'),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي فروق العملة التقديرية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(
                '${varianceTotal.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: hasVariance ? AppTheme.crimson : AppTheme.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasVariance ? AppTheme.crimson.withValues(alpha: 0.08) : AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(hasVariance ? Icons.warning_amber_rounded : Icons.check_circle_outline, size: 14, color: hasVariance ? AppTheme.crimson : AppTheme.emerald),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasVariance
                        ? 'يوجد فروق أسعار صرف بين تقييم الجمارك والتحويل البنكي الفعلي تؤثر على تكلفة الوصول.'
                        : 'أسعار الصرف مطابقة تماماً أو لم يتم تسجيل تسويات بنكية بالعملة الأجنبية بعد.',
                    style: TextStyle(fontSize: 10.5, color: hasVariance ? AppTheme.crimson : AppTheme.emerald),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
