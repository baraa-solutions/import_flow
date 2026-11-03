import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../purchase_orders/utils/po_packing_matcher.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/comprehensive_dossier_model.dart';

/// Top executive KPI metric tiles for physical and financial overview of the shipment.
class ReportExecutiveMetricTiles extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final List<PurchaseOrderModel> allPOs;
  final bool isLoading;

  const ReportExecutiveMetricTiles({
    super.key,
    required this.file,
    this.dossier,
    this.allPOs = const [],
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
    final poMetrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);

    // 1. CBM
    final fallbackCbm = poMetrics.cbm > 0
        ? poMetrics.cbm
        : file.packingListsData.fold(0.0, (s, p) => s + p.cbm);
    final cbmVal = (dossier?.cargoPhysicalSummary?['total_cbm'] as num?)?.toDouble() ??
        (dossier != null && dossier!.totalCbm > 0 ? dossier!.totalCbm : fallbackCbm);
    final displayCbm = cbmVal > 0 ? '${cbmVal.toStringAsFixed(3)} m³' : (isLoading ? '...' : '—');

    // 2. Gross Weight
    final fallbackGross = poMetrics.weightKg > 0
        ? poMetrics.weightKg
        : file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg);
    final grossVal = (dossier?.cargoPhysicalSummary?['total_gross_weight_kg'] as num?)?.toDouble() ??
        (dossier?.cargoPhysicalSummary?['gross_weight_kg'] as num?)?.toDouble() ??
        (dossier != null && dossier!.grossWeightKg > 0 ? dossier!.grossWeightKg : fallbackGross);
    const double? fallbackNet = null;
    final netVal = dossier?.netWeightKg ??
        (dossier?.cargoPhysicalSummary?['total_net_weight_kg'] as num?)?.toDouble() ??
        fallbackNet;
    final displayGross = grossVal > 0 ? '${PoPackingMatcher.formatWeight(grossVal)} كجم' : (isLoading ? '...' : '—');
    final displayNet = netVal != null && netVal > 0 ? 'صافي: ${PoPackingMatcher.formatWeight(netVal)} كجم' : (isLoading ? '...' : 'وزن الشحن القائم');

    // 3. POs & Invoices
    final invCount = dossier?.invoicesCount ?? dossier?.cargoPhysicalSummary?['invoices_count'] ?? file.invoicesData.length;
    final poCount = dossier?.posCount ?? dossier?.cargoPhysicalSummary?['pos_count'] ?? (linkedPOs.isNotEmpty ? linkedPOs.length : (file.poNumber != null && file.poNumber!.isNotEmpty ? 1 : 0));
    final int itemsCount = dossier?.itemsCount ?? (linkedPOs.isNotEmpty ? linkedPOs.fold<int>(0, (int s, po) => s + po.items.length) : 0);

    // 4. Landed Cost & Variance
    final actualLanded = dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp;
    final displayCost = actualLanded > 0
        ? '${actualLanded.toStringAsFixed(0)} ج.م'
        : (file.estimatedCost > 0 ? '${file.estimatedCost.toStringAsFixed(0)} \$' : (isLoading ? '...' : '—'));
    final variancePct = dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct;
    final varianceEgp = dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp;
    final hasVariance = actualLanded > 0 && varianceEgp != 0;

    // 5. ETA Drift
    final etaStr = file.requiredEta ?? (dossier?.timelineEvents.isNotEmpty == true
        ? dossier!.timelineEvents.firstWhere((e) => e['stage_code'] == 'STEP_11', orElse: () => {})['planned_date']?.toString()
        : null) ?? '—';
    int driftDays = 0;
    if (dossier != null && dossier!.etaRevisionsLog.isNotEmpty) {
      final lastLog = dossier!.etaRevisionsLog.last;
      driftDays = (lastLog['drift_days'] as num?)?.toInt() ?? 0;
    }
    final isDrifted = driftDays > 0;

    return Row(
      children: [
        _buildKpiMetricCard(
          context: context,
          title: 'الحجم الإجمالي (CBM)',
          primaryValue: displayCbm,
          subtitle: 'حجم البضائع المشحونة',
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFF2563EB),
          bgGradient: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        ),
        const SizedBox(width: 12),
        _buildKpiMetricCard(
          context: context,
          title: 'الوزن القائم (Gross Wt)',
          primaryValue: displayGross,
          subtitle: displayNet,
          icon: Icons.scale_outlined,
          color: const Color(0xFF475569),
          bgGradient: const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        ),
        const SizedBox(width: 12),
        _buildKpiMetricCard(
          context: context,
          title: 'الفواتير وأوامر الشراء',
          primaryValue: '$poCount PO  •  $invCount فاتورة',
          subtitle: itemsCount > 0 ? '$itemsCount صنف مدرج بالملف' : 'أوامر التوريد المعتمدة',
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFFD97706),
          bgGradient: const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        const SizedBox(width: 12),
        _buildKpiMetricCard(
          context: context,
          title: actualLanded > 0 ? 'تكلفة الوصول الفعلية' : 'التكلفة التقديرية',
          primaryValue: displayCost,
          subtitle: hasVariance
              ? 'انحراف: ${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}% (${varianceEgp.toStringAsFixed(0)} ج.م)'
              : 'مطابقة للتكلفة المخططة',
          icon: Icons.monetization_on_outlined,
          color: hasVariance ? (variancePct > 5 ? AppTheme.crimson : const Color(0xFFD97706)) : AppTheme.emerald,
          bgGradient: hasVariance
              ? const [Color(0xFFFEF2F2), Color(0xFFFEE2E2)]
              : const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        ),
        const SizedBox(width: 12),
        _buildKpiMetricCard(
          context: context,
          title: 'تتبع موعد الوصول ETA',
          primaryValue: etaStr,
          subtitle: isDrifted ? '⚠️ انحراف تأخير: +$driftDays يوم' : '✅ في الموعد المحدد',
          icon: isDrifted ? Icons.warning_amber_rounded : Icons.schedule_outlined,
          color: isDrifted ? AppTheme.crimson : AppTheme.emerald,
          bgGradient: isDrifted
              ? const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)]
              : const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        ),
      ],
    );
  }

  Widget _buildKpiMetricCard({
    required BuildContext context,
    required String title,
    required String primaryValue,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> bgGradient,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgGradient,
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              primaryValue,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
