import '../../../../core/localization/app_localizations.dart';
import '../../../customs_tariff/models/customs_tariff_model.dart';
import '../../models/po_system_message.dart';
import '../../models/purchase_order_model.dart';
import '../../utils/po_packing_matcher.dart';
import '../po_reconciliation_warning_dialog.dart';

/// Precomputed metrics and reports for a Purchase Order's commercial invoice & packing list.
class POResolvedMetrics {
  final List<ResolvedPoItemMetrics> resolvedPoItems;
  final Map<String, Map<String, dynamic>> poHsSummaryMap;
  final Map<String, Map<String, dynamic>> hsSummaryMap;
  final Map<String, Map<String, dynamic>> packageTypeSummaryMap;
  final POReconciliationReport reconciliation;
  final Set<String> mismatchedHsCodes;
  final List<String> validationErrors;
  final List<String> validationWarnings;
  final double palletPlanCbm;
  final double palletPlanGrossWeight;
  final int totalPalletCount;
  final double effectivePackingListCbm;
  final double effectivePackingListGrossWeight;
  final double effectivePackingListNetWeight;
  final bool isPalletized;
  final List<CustomsTariffModel> tariffs;

  const POResolvedMetrics({
    required this.resolvedPoItems,
    required this.poHsSummaryMap,
    required this.hsSummaryMap,
    required this.packageTypeSummaryMap,
    required this.reconciliation,
    required this.mismatchedHsCodes,
    required this.validationErrors,
    required this.validationWarnings,
    required this.palletPlanCbm,
    required this.palletPlanGrossWeight,
    required this.totalPalletCount,
    required this.effectivePackingListCbm,
    required this.effectivePackingListGrossWeight,
    required this.effectivePackingListNetWeight,
    required this.isPalletized,
    required this.tariffs,
  });

  static String formatWeight(double val) => PoPackingMatcher.formatWeight(val);

  factory POResolvedMetrics.compute({
    required PurchaseOrderModel po,
    required List<CustomsTariffModel> tariffs,
    required AppLocalizations l10n,
  }) {
    final reconciliation = evaluatePOReconciliation(
      invoiceItems: po.items,
      packingItems: po.packingListItems,
      tariffs: tariffs,
    );
    final Set<String> mismatchedHsCodes = reconciliation.items
        .where((item) => !item.isMatched || item.isMissingInPacking || item.isMissingInInvoice)
        .map((item) => item.hsCode)
        .toSet();

    // Group packing list items by HS Code for the HS Summary Report
    final Map<String, Map<String, dynamic>> hsSummaryMap = {};
    for (final p in po.packingListItems) {
      final hs = p.hsCode.isNotEmpty ? p.hsCode : 'UNSPECIFIED';
      if (!hsSummaryMap.containsKey(hs)) {
        hsSummaryMap[hs] = {
          'hs_code': hs,
          'qty_pcs': 0.0,
          'qty_pkg': 0.0,
          'total_net': 0.0,
          'total_gross': 0.0,
          'total_cbm': 0.0,
        };
      }
      final double itemNet = (p.netWeightUnitKg > 0 && p.qtyPkg > 0)
          ? (p.qtyPkg * p.netWeightUnitKg)
          : p.totalNetWeightKg;
      final double itemGross = (p.grossWeightUnitKg > 0 && p.qtyPkg > 0)
          ? (p.qtyPkg * p.grossWeightUnitKg)
          : p.totalGrossWeightKg;
      final double itemCbm = p.calculatedCbm > 0 ? p.calculatedCbm : p.totalCbm;
      hsSummaryMap[hs]!['qty_pcs'] += p.qtyPcs;
      hsSummaryMap[hs]!['qty_pkg'] += p.qtyPkg;
      hsSummaryMap[hs]!['total_net'] += itemNet;
      hsSummaryMap[hs]!['total_gross'] += itemGross;
      hsSummaryMap[hs]!['total_cbm'] += itemCbm;
    }

    final bool isPalletized = (po.palletPlanItems.isNotEmpty &&
            po.palletPlanItems.any((p) => p.palletCount > 0)) ||
        po.palletCount > 0;

    final resolvedPoItems = PoPackingMatcher.resolvePoItemMetrics(
      items: po.items,
      packingListItems: po.packingListItems,
      isPalletized: isPalletized,
      tariffs: tariffs,
    );

    // Group PO Line Items by HS Code for PO Items HS Summary Report
    final Map<String, Map<String, dynamic>> poHsSummaryMap =
        PoPackingMatcher.buildPoHsSummaryMap(resolvedPoItems);

    // Group Packing List Items by Package Type for Summary By Package Type Report
    final Map<String, Map<String, dynamic>> packageTypeSummaryMap =
        PoPackingMatcher.buildPackingTypeSummaryMap(po.packingListItems);

    // Validation checks
    final List<String> validationErrors = [];
    final List<String> validationWarnings = [];
    for (int i = 0; i < po.packingListItems.length; i++) {
      final item = po.packingListItems[i];
      if (item.grossWeightUnitKg < item.netWeightUnitKg) {
        validationErrors.add(POSystemMessage(code: 'PO_PL_GROSS_BELOW_NET', params: {
          'line_num': i + 1,
          'item_code': item.itemCode,
          'gross_qty': item.grossWeightUnitKg,
          'net_qty': item.netWeightUnitKg,
        }).text(l10n));
      }
      if (item.lengthCm <= 0 || item.widthCm <= 0 || item.heightCm <= 0) {
        validationWarnings.add(POSystemMessage(
          code: 'PO_PL_DIMENSIONS_MISSING',
          params: {'line_num': i + 1, 'item_code': item.itemCode},
        ).text(l10n));
      }
    }

    final double palletPlanCbm = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<double>(
            0.0,
            (sum, p) =>
                sum +
                (p.calculatedCbm > 0
                    ? p.calculatedCbm
                    : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount),
          )
        : (po.palletCount > 0 &&
                po.palletLengthCm > 0 &&
                po.palletWidthCm > 0 &&
                po.palletHeightCm > 0
            ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) *
                po.palletCount
            : (po.palletCount > 0 && po.totalCbm > 0 ? po.totalCbm : 0.0));

    final double palletPlanGrossWeight = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<double>(
            0.0,
            (sum, p) => sum + (p.grossWeightPerPalletKg * p.palletCount),
          )
        : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);

    final int totalPalletCount = po.palletPlanItems.isNotEmpty
        ? po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount)
        : po.palletCount;

    final double effectivePackingListCbm = palletPlanCbm > 0
        ? palletPlanCbm
        : (po.totalCbm > 0
            ? po.totalCbm
            : (po.packingListItems.isNotEmpty
                ? po.packingListItems.fold(
                    0.0,
                    (sum, pl) =>
                        sum + (pl.calculatedCbm > 0 ? pl.calculatedCbm : pl.totalCbm))
                : 0.0));

    final double effectivePackingListGrossWeight = palletPlanGrossWeight > 0
        ? palletPlanGrossWeight
        : (po.totalGrossWeightKg > 0
            ? po.totalGrossWeightKg
            : (po.packingListItems.isNotEmpty
                ? po.packingListItems.fold(
                    0.0,
                    (sum, pl) =>
                        sum +
                        ((pl.grossWeightUnitKg > 0 && pl.qtyPkg > 0)
                            ? (pl.grossWeightUnitKg * pl.qtyPkg)
                            : pl.totalGrossWeightKg))
                : 0.0));

    final double effectivePackingListNetWeight = po.totalNetWeightKg > 0
        ? po.totalNetWeightKg
        : (po.packingListItems.isNotEmpty
            ? po.packingListItems.fold(
                0.0,
                (sum, pl) =>
                    sum +
                    ((pl.netWeightUnitKg > 0 && pl.qtyPkg > 0)
                        ? (pl.netWeightUnitKg * pl.qtyPkg)
                        : pl.totalNetWeightKg))
            : 0.0);

    return POResolvedMetrics(
      resolvedPoItems: resolvedPoItems,
      poHsSummaryMap: poHsSummaryMap,
      hsSummaryMap: hsSummaryMap,
      packageTypeSummaryMap: packageTypeSummaryMap,
      reconciliation: reconciliation,
      mismatchedHsCodes: mismatchedHsCodes,
      validationErrors: validationErrors,
      validationWarnings: validationWarnings,
      palletPlanCbm: palletPlanCbm,
      palletPlanGrossWeight: palletPlanGrossWeight,
      totalPalletCount: totalPalletCount,
      effectivePackingListCbm: effectivePackingListCbm,
      effectivePackingListGrossWeight: effectivePackingListGrossWeight,
      effectivePackingListNetWeight: effectivePackingListNetWeight,
      isPalletized: isPalletized,
      tariffs: tariffs,
    );
  }
}
