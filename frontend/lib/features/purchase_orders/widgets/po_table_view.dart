import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart' show ImportFileModel;
import '../../import_files/providers/import_files_provider.dart';
import '../l10n/po_fulfillment_l10n.dart';
import '../models/purchase_order_model.dart';
import '../utils/po_packing_matcher.dart';

class PoTableView extends ConsumerWidget {
  final List<PurchaseOrderModel> orders;
  final ValueChanged<PurchaseOrderModel> onView;
  final ValueChanged<PurchaseOrderModel> onEdit;
  final ValueChanged<PurchaseOrderModel> onClone;
  final ValueChanged<PurchaseOrderModel> onBalanceLedger;
  final ValueChanged<PurchaseOrderModel> onPartialShipment;
  final ValueChanged<PurchaseOrderModel> onToggleActive;
  final ValueChanged<PurchaseOrderModel> onPrint;

  const PoTableView({
    super.key,
    required this.orders,
    required this.onView,
    required this.onEdit,
    required this.onClone,
    required this.onBalanceLedger,
    required this.onPartialShipment,
    required this.onToggleActive,
    required this.onPrint,
  });

  static String _getStatusLabel(String status, AppLocalizations l) =>
      DomainEnums.label(l, DomainEnumType.poStatus, status, fallback: '-');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final Map<int, ImportFileModel> filesById = {};
    final Map<String, ImportFileModel> filesByCode = {};
    for (final f in importFiles) {
      filesById[f.importFileId] = f;
      filesByCode[f.importFileCode] = f;
    }

    return EnterpriseDataTable<PurchaseOrderModel>(
      storageKey: 'purchase_orders_enterprise_table',
      isScrollable: true,
      minWidth: 1650,
      data: orders,
      columns: _buildPOColumns(context, isDark, l, filesById, filesByCode),
      onRowTap: onView,
      enableExport: true,
      exportFileName: 'Purchase_Orders_Registry_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  List<EnterpriseColumn<PurchaseOrderModel>> _buildPOColumns(
    BuildContext context,
    bool isDark,
    AppLocalizations l,
    Map<int, ImportFileModel> filesById,
    Map<String, ImportFileModel> filesByCode,
  ) {
    return [
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'actions',
        title: l.actionsCol,
        width: 260,
        isLocked: true,
        isSortable: false,
        isSearchable: false,
        cellBuilder: (ctx, po, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (po.poId != null) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 20),
                  tooltip: l.poBalanceLedgerTooltip,
                  onPressed: () => onBalanceLedger(po),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.local_shipping_outlined, color: AppTheme.emerald, size: 20),
                  tooltip: l.poCreatePartialShipment,
                  onPressed: () => onPartialShipment(po),
                ),
              ],
              RowActionsPill(
                onView: () => onView(po),
                onEdit: () => onEdit(po),
                onClone: () => onClone(po),
                cloneTooltip: l.cloneRowTooltip,
                onPrint: () => onPrint(po),
                onDelete: () => onToggleActive(po),
                deleteTooltip: po.isActive ? l.deactivatePoTooltip : l.restorePoTooltip,
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'po_reference',
        title: l.poReferenceCol,
        width: 170,
        exportValue: (po) => po.displayName,
        searchValue: (po) => '${po.displayName} ${po.poNumber}',
        cellBuilder: (ctx, po, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return CopyableTableCell(
            value: po.displayName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => onView(po),
                  child: LtrText(
                    po.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                if (po.poReference != null && po.poReference!.isNotEmpty && po.poReference != po.poNumber)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: LtrText(
                      po.poNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'invoice_date',
        title: l.invoiceDateCol,
        width: 120,
        sortComparator: (a, b) {
          if (a.orderDate == null && b.orderDate == null) return 0;
          if (a.orderDate == null) return -1;
          if (b.orderDate == null) return 1;
          return a.orderDate!.compareTo(b.orderDate!);
        },
        exportValue: (po) => po.orderDate != null
            ? '${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}'
            : '-',
        cellBuilder: (ctx, po, _) {
          final invoiceDateStr = po.orderDate != null
              ? '${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}'
              : '-';
          return CopyableTableCell(value: invoiceDateStr, child: LtrText(invoiceDateStr));
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'import_file',
        title: l.importFileCol,
        width: 180,
        exportValue: (po) {
          final matchedFile = (po.importFileId != null ? filesById[po.importFileId] : null) ??
              (po.importFileCode != null ? filesByCode[po.importFileCode] : null);
          return matchedFile?.displayName ?? po.importFileCode ?? (po.importFileId != null ? 'IMP-${po.importFileId}' : '-');
        },
        cellBuilder: (ctx, po, _) {
          final matchedFile = (po.importFileId != null ? filesById[po.importFileId] : null) ??
              (po.importFileCode != null ? filesByCode[po.importFileCode] : null);
          final fileName = matchedFile?.displayName ?? po.importFileCode ?? (po.importFileId != null ? 'IMP-${po.importFileId}' : '-');
          final fileCode = (matchedFile != null && matchedFile.displayName != matchedFile.importFileCode)
              ? matchedFile.importFileCode
              : (po.importFileCode ?? (po.importFileId != null ? 'IMP-${po.importFileId}' : ''));
          return CopyableTableCell(
            value: fileName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fileName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (fileCode.isNotEmpty)
                  LtrText(fileCode, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'pi_number',
        title: l.piNumberCol,
        width: 140,
        exportValue: (po) => po.proformaInvoiceNumber ?? '-',
        cellBuilder: (ctx, po, _) => CopyableTableCell(
          value: po.proformaInvoiceNumber ?? '-',
          child: LtrText(po.proformaInvoiceNumber ?? '-'),
        ),
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'projects',
        title: l.projectsAndCostCenters,
        width: 170,
        exportValue: (po) => po.projectName ?? 'PRJ-#${po.projectId}',
        cellBuilder: (ctx, po, _) {
          final pName = po.projectName ?? 'PRJ-#${po.projectId}';
          return CopyableTableCell(
            value: pName,
            child: Text(pName, overflow: TextOverflow.ellipsis),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'company',
        title: l.importingCompany,
        width: 170,
        exportValue: (po) => po.companyName ?? 'COMP-#${po.companyId}',
        cellBuilder: (ctx, po, _) {
          final cName = po.companyName ?? 'COMP-#${po.companyId}';
          return CopyableTableCell(
            value: cName,
            child: Text(cName, overflow: TextOverflow.ellipsis),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'supplier',
        title: l.foreignSupplier,
        width: 180,
        exportValue: (po) => po.supplierName ?? 'SUP-#${po.supplierId}',
        cellBuilder: (ctx, po, _) {
          final sName = po.supplierName ?? 'SUP-#${po.supplierId}';
          return CopyableTableCell(
            value: sName,
            child: Text(sName, overflow: TextOverflow.ellipsis),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'total_fob',
        title: l.totalFobMetric,
        width: 140,
        isNumeric: true,
        sortComparator: (a, b) => a.totalAmountFob.compareTo(b.totalAmountFob),
        exportValue: (po) => '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
        cellBuilder: (ctx, po, _) {
          final amountStr = '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}';
          return CopyableTableCell(
            value: amountStr,
            child: LtrText(
              amountStr,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
            ),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'cbm_weight',
        title: l.cbmAndGrossWeightCol,
        width: 180,
        isNumeric: true,
        sortComparator: (a, b) => a.totalCbm.compareTo(b.totalCbm),
        exportValue: (po) => '${po.totalCbm.toStringAsFixed(2)} m³ / ${PoPackingMatcher.formatWeight(po.totalGrossWeightKg)} kg',
        cellBuilder: (ctx, po, _) {
          final cbmWeightStr = '${po.totalCbm.toStringAsFixed(2)} m³ / ${PoPackingMatcher.formatWeight(po.totalGrossWeightKg)} kg';
          return CopyableTableCell(
            value: cbmWeightStr,
            child: LtrText(cbmWeightStr),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'fulfillment_balance',
        title: l.poFulfillmentProgressTitle,
        width: 190,
        sortComparator: (a, b) => a.fulfillmentRate.compareTo(b.fulfillmentRate),
        exportValue: (po) => '${po.fulfillmentRate.toStringAsFixed(1)}% (${po.totalShippedQuantity}/${po.effectiveContractedQuantity})',
        searchValue: (po) => '${po.fulfillmentRate.toStringAsFixed(0)}% ${po.fulfillmentStatus}',
        cellBuilder: (ctx, po, _) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final rate = po.fulfillmentRate;
          final contracted = po.effectiveContractedQuantity;
          final shipped = po.totalShippedQuantity;
          final color = rate >= 100.0 ? AppTheme.emerald : (rate > 0 ? AppTheme.cobalt : AppTheme.orange);

          return InkWell(
            onTap: () => onBalanceLedger(po),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${rate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        '${shipped.toStringAsFixed(0)} / ${contracted.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (rate / 100.0).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: (isDark ? AppTheme.darkBorder : AppTheme.border).withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<PurchaseOrderModel>(
        id: 'status',
        title: l.lifecycleBoard,
        width: 130,
        exportValue: (po) => _getStatusLabel(po.status, l),
        cellBuilder: (ctx, po, _) {
          final localizedStatus = _getStatusLabel(po.status, l);
          final severity = po.status == 'Approved'
              ? AppSeverity.success
              : (po.status == 'Draft' ? AppSeverity.warning : AppSeverity.info);
          return AppStatusBadge(
            label: localizedStatus,
            severity: severity,
          );
        },
      ),
    ];
  }
}
