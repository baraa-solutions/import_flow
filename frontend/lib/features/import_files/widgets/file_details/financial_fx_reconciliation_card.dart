// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../comprehensive_report/models/comprehensive_dossier_model.dart';

/// 💱 Foreign Exchange Reconciliation & Currency Variances Card
class FinancialFxReconciliationCard extends StatelessWidget {
  final ComprehensiveShipmentDossierModel? dossier;
  final bool isDark;
  final bool isAr;

  const FinancialFxReconciliationCard({
    super.key,
    this.dossier,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final fx = dossier?.fxReconciliation;
    final customsRate = fx?['customs_exchange_rate'];
    final bankRate = fx?['commercial_bank_exchange_rate'];
    final varianceRate = fx?['fx_variance_rate'] ?? 0.0;
    final varianceTotal = fx?['fx_variance_total_egp'] ?? 0.0;
    final hasVariance = fx?['has_variance'] == true;

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
              const Icon(Icons.currency_exchange_outlined, color: AppTheme.emerald, size: 20),
              const SizedBox(width: 8),
              Text(
                isAr
                    ? 'مطابقة أسعار الصرف وفروق تدبير العملة'
                    : 'Foreign Exchange Reconciliation & Currency Variances',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  isAr
                      ? 'سعر الصرف الجمركي: ${customsRate != null ? "$customsRate ج.م" : "—"}'
                      : 'Customs Rate: ${customsRate != null ? "$customsRate EGP" : "—"}',
                  style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                ),
              ),
              Expanded(
                child: Text(
                  isAr
                      ? 'سعر صرف البنك: ${bankRate != null ? "$bankRate ج.م" : "—"}'
                      : 'Bank Rate: ${bankRate != null ? "$bankRate EGP" : "—"}',
                  style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  isAr
                      ? 'فرق السعر لكل وحدة عملة: $varianceRate ج.م'
                      : 'Variance per Currency Unit: $varianceRate EGP',
                  style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      isAr ? 'إجمالي الفروق: ' : 'Total FX Variance: ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
                    ),
                    Text(
                      '${varianceTotal.toStringAsFixed(2)} ${isAr ? "ج.م" : "EGP"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: hasVariance ? AppTheme.crimson : AppTheme.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasVariance
                  ? (isDark ? AppTheme.crimson.withValues(alpha: 0.3) : AppTheme.crimson.withValues(alpha: 0.08))
                  : (isDark ? AppTheme.emerald.withValues(alpha: 0.3) : AppTheme.emerald.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  hasVariance ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  size: 14,
                  color: hasVariance ? (isDark ? Colors.red.shade300 : AppTheme.crimson) : (isDark ? Colors.green.shade300 : AppTheme.emerald),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasVariance
                        ? (isAr
                            ? 'يوجد فروق أسعار صرف بين تقييم الجمارك والتحويل البنكي الفعلي تؤثر على تكلفة الوصول.'
                            : 'FX rate differences detected between customs valuation and bank transfer.')
                        : (isAr
                            ? 'أسعار الصرف مطابقة تماماً أو لم يتم تسجيل تسويات بنكية بالعملة الأجنبية بعد.'
                            : 'Exchange rates are fully matched or pending foreign settlement.'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: hasVariance ? (isDark ? Colors.red.shade300 : AppTheme.crimson) : (isDark ? Colors.green.shade300 : AppTheme.emerald),
                    ),
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
