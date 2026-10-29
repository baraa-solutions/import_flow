import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:frontend/core/widgets/copyable_data_helper.dart';
import '../../purchase_orders/utils/po_packing_matcher.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_card_container.dart';
import 'report_copy_badge.dart';

/// Packing list and cargo physical breakdown card for Comprehensive Report.
class ReportPackingListCard extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;

  const ReportPackingListCard({
    super.key,
    required this.file,
    this.dossier,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cbmFromDossier = (dossier?.cargoPhysicalSummary?['total_cbm'] as num?)?.toDouble() ??
        (dossier != null && dossier!.totalCbm > 0 ? dossier!.totalCbm : 0.0);
    final grossFromDossier = (dossier?.cargoPhysicalSummary?['total_gross_weight_kg'] as num?)?.toDouble() ??
        (dossier?.cargoPhysicalSummary?['gross_weight_kg'] as num?)?.toDouble() ??
        (dossier != null && dossier!.grossWeightKg > 0 ? dossier!.grossWeightKg : 0.0);
    final netFromDossier = dossier?.netWeightKg ??
        (dossier?.cargoPhysicalSummary?['total_net_weight_kg'] as num?)?.toDouble() ?? 0.0;
    final pkgsFromDossier = (dossier?.cargoPhysicalSummary?['total_packages'] as num?)?.toInt() ??
        (dossier != null && dossier!.totalPackages > 0 ? dossier!.totalPackages : 0);

    final double totalCbm = cbmFromDossier > 0 ? cbmFromDossier : file.packingListsData.fold(0.0, (s, p) => s + p.cbm);
    final double totalWeight = grossFromDossier > 0 ? grossFromDossier : file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg);
    final double totalNet = netFromDossier > 0 ? netFromDossier : 0.0;
    final int totalPkgs = pkgsFromDossier > 0 ? pkgsFromDossier : file.packingListsData.fold(0, (s, p) => s + p.totalPackages);

    final hasPhysicalData = totalCbm > 0 || totalWeight > 0 || totalPkgs > 0 || file.packingListsData.isNotEmpty;

    final plCount = file.packingListsData.isNotEmpty
        ? file.packingListsData.length
        : (dossier != null && dossier!.posCount > 0 ? 1 : 0);

    return ReportCardContainer(
      title: 'بيان العبوة ومواصفات الشحن ($plCount بيان تعبئة)',
      icon: Icons.inventory_2_outlined,
      iconColor: AppTheme.cobalt,
      child: !hasPhysicalData
          ? Text(l.compReportNoPackingLists, style: const TextStyle(color: Colors.grey, fontSize: 12))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary totals
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat('إجمالي الطرود', '$totalPkgs طرد'),
                      _miniStat('الوزن القائم', '${PoPackingMatcher.formatWeight(totalWeight)} كجم'),
                      if (totalNet > 0)
                        _miniStat('الوزن الصافي', '${PoPackingMatcher.formatWeight(totalNet)} كجم'),
                      _miniStat('الحجم الإجمالي', '${totalCbm.toStringAsFixed(3)} m³'),
                    ],
                  ),
                ),
                if (file.packingListsData.isNotEmpty)
                  ...file.packingListsData.map((pl) {
                    final rowSummary = '${pl.plNo} | ${pl.totalPackages} pkgs | ${PoPackingMatcher.formatWeight(pl.grossWeightKg)} KG | ${pl.cbm.toStringAsFixed(2)} CBM';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: CopyableTableCell(
                        value: pl.plNo,
                        rowSummary: rowSummary,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.indigo.shade100),
                          ),
                          child: Row(
                            children: [
                              ReportCopyBadge(textToCopy: pl.plNo),
                              const SizedBox(width: 8),
                              Text('${pl.totalPackages} pkgs', style: const TextStyle(fontSize: 11)),
                              const Spacer(),
                              Text('${PoPackingMatcher.formatWeight(pl.grossWeightKg)} KG', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('${pl.cbm.toStringAsFixed(2)} m³', style: const TextStyle(fontSize: 11, color: AppTheme.cobalt)),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                else if (dossier != null && dossier!.purchaseOrders.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.emerald),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تم اعتماد أوزان وأحجام الشحنة من أمر التوريد ${dossier!.purchaseOrders.first["po_number"]} بإجمالي $totalPkgs طرد (${PoPackingMatcher.formatWeight(totalWeight)} كجم قائم / ${totalCbm.toStringAsFixed(3)} CBM).',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
      ],
    );
  }
}
