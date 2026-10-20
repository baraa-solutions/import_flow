import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../models/purchase_order_model.dart';

List<String> buildPoExportHeaders(AppLocalizations l) {
  return [
    l.poReferenceCol,
    l.foreignSupplier,
    l.projectsAndCostCenters,
    l.totalFobMetric,
    l.totalCargoCbmMetric,
    l.totalGrossWeightMetric,
    l.statusCol,
  ];
}

List<List<dynamic>> buildPoExportRows(
  List<PurchaseOrderModel> orders,
  AppLocalizations l,
) {
  return orders.map((po) {
    final ref = po.poNumber.trim().isEmpty ? '—' : po.poNumber.trim();
    final supplier = (po.supplierName?.trim().isNotEmpty == true)
        ? po.supplierName!.trim()
        : '—';
    final project = (po.projectName?.trim().isNotEmpty == true)
        ? po.projectName!.trim()
        : '—';
    final fob = po.totalAmountFob.toStringAsFixed(2);
    final cbm = '${po.totalCbm.toStringAsFixed(2)} m³';
    final weight = '${po.totalGrossWeightKg.toStringAsFixed(1)} kg';
    final status = DomainEnums.label(l, DomainEnumType.poStatus, po.status, fallback: '—');

    return [
      ref,
      supplier,
      project,
      fob,
      cbm,
      weight,
      status,
    ];
  }).toList();
}
