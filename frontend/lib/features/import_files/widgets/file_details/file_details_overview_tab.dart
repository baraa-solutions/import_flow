// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../../purchase_orders/utils/po_packing_matcher.dart';
import '../../models/import_file_model.dart';
import '../../../comprehensive_report/models/comprehensive_dossier_model.dart';
import 'overview_acid_status_card.dart';
import 'overview_containers_seal_matrix_card.dart';
import 'overview_linked_pos_table.dart';
import 'overview_product_quantity_summary.dart';
import 'overview_cargo_stacking_card.dart';

/// 🌐 Overview tab for Import File Details
/// Displays key logistics metrics, ACID number, linked POs, products summary,
/// container & seal matrix, and container stacking calculations.
class FileDetailsOverviewTab extends ConsumerWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> linkedPOs;
  final Set<String> invoiceNumbers;
  final double totalPackingListCbm;
  final double totalPackingListWeight;
  final int totalPackingListsCount;
  final ComprehensiveShipmentDossierModel? dossier;

  const FileDetailsOverviewTab({
    super.key,
    required this.file,
    required this.linkedPOs,
    required this.invoiceNumbers,
    required this.totalPackingListCbm,
    required this.totalPackingListWeight,
    required this.totalPackingListsCount,
    this.dossier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final isAr = ref.watch(localeProvider).languageCode == 'ar' ||
        Localizations.localeOf(context).languageCode == 'ar';

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Executive Metric Summary ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: isDark ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: isDark ? 0.4 : 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? '📊 مؤشرات الشحنة التنفيذية والمطابقة الفعلية:' : '📊 Executive Shipment Metrics & Reconciliation:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  ),
                  const SizedBox(height: 10),
                  () {
                    final netWeight = dossier?.netWeightKg;
                    final displayNet = (netWeight != null && netWeight > 0)
                        ? (isAr ? 'صافي: ${PoPackingMatcher.formatWeight(netWeight)} كجم' : 'Net: ${PoPackingMatcher.formatWeight(netWeight)} kg')
                        : l.grossWeightSumDescription;

                    final actualLanded = dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp;
                    final variancePct = dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct;
                    final varianceEgp = dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp;
                    final hasVariance = actualLanded > 0 && varianceEgp != 0;

                    int driftDays = 0;
                    if (dossier != null && dossier!.etaRevisionsLog.isNotEmpty) {
                      final lastLog = dossier!.etaRevisionsLog.last;
                      driftDays = (lastLog['drift_days'] as num?)?.toInt() ?? 0;
                    }
                    final isDrifted = driftDays > 0;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            l.totalCbmFromPackingList,
                            '${totalPackingListCbm.toStringAsFixed(3)} m³',
                            subtitle: '$totalPackingListsCount ${l.packingListsUnit}',
                            icon: Icons.view_in_ar,
                            color: AppTheme.orange,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            l.totalGrossWeightFromPl,
                            '${PoPackingMatcher.formatWeight(totalPackingListWeight)} kg',
                            subtitle: displayNet,
                            icon: Icons.fitness_center,
                            color: AppTheme.emerald,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            isAr ? 'الفواتير وأوامر الشراء' : 'Invoices & Orders',
                            isAr
                                ? '${invoiceNumbers.length} فاتورة • ${linkedPOs.length} أمر شراء'
                                : '${invoiceNumbers.length} Invoices • ${linkedPOs.length} POs',
                            subtitle: isAr ? '${dossier?.itemsCount ?? 0} صنف تفصيلي' : '${dossier?.itemsCount ?? 0} line items',
                            icon: Icons.receipt_long,
                            color: AppTheme.cobalt,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            actualLanded > 0
                                ? (isAr ? 'تكلفة الوصول والتسوية' : 'Landed Cost')
                                : (isAr ? 'التكلفة التقديرية' : 'Estimated Cost'),
                            actualLanded > 0
                                ? '${actualLanded.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}'
                                : (file.estimatedCost > 0 ? '${file.estimatedCost.toStringAsFixed(0)} \$' : '—'),
                            subtitle: hasVariance
                                ? (isAr
                                    ? 'تباين: ${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}%'
                                    : 'Variance: ${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}%')
                                : (file.estimatedCost > 0
                                    ? (isAr ? 'تقديري مبدئي' : 'Initial estimate')
                                    : (isAr ? 'بانتظار التسوية' : 'Pending settlement')),
                            icon: Icons.account_balance_wallet,
                            color: hasVariance
                                ? (variancePct.abs() > 5 ? AppTheme.crimson : AppTheme.orange)
                                : AppTheme.emerald,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            isAr ? 'الجدول الزمني والانحراف' : 'Schedule & Drift',
                            file.requiredEta ?? '—',
                            subtitle: isDrifted
                                ? (isAr ? '⚠️ تأخير +$driftDays يوم' : '⚠️ Delayed +$driftDays d')
                                : (driftDays < 0
                                    ? (isAr ? 'تبكير $driftDays يوم' : 'Ahead $driftDays d')
                                    : (isAr ? 'منتظم بالجدول' : 'On schedule')),
                            icon: Icons.access_time,
                            color: isDrifted ? AppTheme.orange : AppTheme.cobalt,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    );
                  }(),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── ACID & Expiry Tracking Card ───────────────────────────────────
            OverviewAcidStatusCard(
              file: file,
              isDark: isDark,
              isAr: isAr,
            ),
            const SizedBox(height: 14),

            // ── Containers & Seal Matrix Card ─────────────────────────────────
            OverviewContainersSealMatrixCard(
              dossier: dossier,
              isDark: isDark,
              isAr: isAr,
            ),
            const SizedBox(height: 14),

            // ── Linked Purchase Orders Table ──────────────────────────────────
            OverviewLinkedPosTable(
              linkedPOs: linkedPOs,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // ── Product & Quantity Summary Section ────────────────────────────
            OverviewProductQuantitySummary(
              file: file,
              linkedPOs: linkedPOs,
              isAr: isAr,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // ── Cargo Stacking & Container Requirements Widget ─────────────────
            OverviewCargoStackingCard(
              file: file,
              linkedPOs: linkedPOs,
              totalPackingListCbm: totalPackingListCbm,
              totalPackingListWeight: totalPackingListWeight,
              isDark: isDark,
              isAr: isAr,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, {required String subtitle, required IconData icon, required Color color, bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.5 : 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
  }
}
