import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/comprehensive_dossier_model.dart';

/// KPI Strip for ComprehensiveDossierExportDialog
class ComprehensiveDossierKpiStrip extends StatelessWidget {
  final ComprehensiveShipmentDossierModel dossier;

  const ComprehensiveDossierKpiStrip({
    super.key,
    required this.dossier,
  });

  static String _formatFob(ComprehensiveShipmentDossierModel dossier) {
    if (dossier.totalFobFc != null && dossier.fobCurrency != null) {
      return '${dossier.totalFobFc!.toStringAsFixed(2)} ${dossier.fobCurrency}';
    }
    if (dossier.fobByCurrency.isNotEmpty) {
      return dossier.fobByCurrency.entries
          .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
          .join(' / ');
    }
    return '—';
  }

  static Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'قيمة البضاعة FOB',
            value: _formatFob(dossier),
            subtitle: dossier.fobSource == 'ESTIMATE'
                ? (dossier.totalFobEgp == null ? 'تقديري (— EGP)' : 'تقديري (${dossier.totalFobEgp!.toStringAsFixed(0)} EGP)')
                : (dossier.totalFobEgp == null ? '— EGP' : '${dossier.totalFobEgp!.toStringAsFixed(0)} EGP'),
            icon: Icons.inventory_2_outlined,
            color: AppTheme.flatCobalt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            title: 'تكلفة الوصول الفعلية',
            value: '${dossier.actualLandedCostTotalEgp.toStringAsFixed(2)} EGP',
            subtitle: dossier.actualLandedCostMarkupFactor == null
                ? '—'
                : 'معامل: ${dossier.actualLandedCostMarkupFactor!.toStringAsFixed(3)}x',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.flatEmerald,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            title: 'الانحراف المالي',
            value: '${dossier.actualLandedCostVariancePct > 0 ? "+" : ""}${dossier.actualLandedCostVariancePct.toStringAsFixed(2)}%',
            subtitle: '${dossier.actualLandedCostVarianceEgp.toStringAsFixed(0)} EGP',
            icon: Icons.trending_up,
            color: dossier.actualLandedCostVariancePct > 5.0 ? AppTheme.flatCrimson : AppTheme.flatOrange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            title: 'حالة الملف والجاهزية',
            value: '${dossier.progressPercent.toStringAsFixed(1)}%',
            subtitle: dossier.status,
            icon: Icons.check_circle_outline,
            color: AppTheme.flatCharcoal,
          ),
        ),
      ],
    );
  }
}
