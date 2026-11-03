import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../l10n/po_fulfillment_l10n.dart';
import '../models/purchase_order_model.dart';
import '../utils/po_packing_matcher.dart';
import 'po_fulfillment_progress_widget.dart';

class PoMobileCardsView extends StatelessWidget {
  final List<PurchaseOrderModel> orders;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ValueChanged<PurchaseOrderModel> onView;
  final ValueChanged<PurchaseOrderModel> onEdit;
  final ValueChanged<PurchaseOrderModel> onClone;
  final ValueChanged<PurchaseOrderModel> onBalanceLedger;
  final ValueChanged<PurchaseOrderModel> onPartialShipment;
  final ValueChanged<PurchaseOrderModel> onToggleActive;
  final ValueChanged<PurchaseOrderModel> onPrint;

  const PoMobileCardsView({
    super.key,
    required this.orders,
    this.shrinkWrap = false,
    this.physics,
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final po = orders[index];
        final invoiceDateStr = po.orderDate != null
            ? '${po.orderDate!.year}-${po.orderDate!.month.toString().padLeft(2, '0')}-${po.orderDate!.day.toString().padLeft(2, '0')}'
            : '-';
        final amountStr = '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}';
        final cbmWeightStr = '${po.totalCbm.toStringAsFixed(2)} m³ / ${PoPackingMatcher.formatWeight(po.totalGrossWeightKg)} kg';
        final localizedStatus = _getStatusLabel(po.status, l);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: PO Number / Title & Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => onView(po),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            po.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          if (po.displayName != po.poNumber) ...[
                            const SizedBox(height: 2),
                            LtrText(
                              po.poNumber,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  AppStatusBadge.fromStatus(
                    status: po.status,
                    label: localizedStatus,
                    size: AppStatusBadgeSize.small,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Details grid
              Text(
                '${l.importingCompany}: ${po.companyName ?? "COMP-#${po.companyId}"}',
                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
              ),
              const SizedBox(height: 2),
              Text(
                '${l.foreignSupplier}: ${po.supplierName ?? "SUP-#${po.supplierId}"}${po.countryOfOrigin != null ? " (${po.countryOfOrigin})" : ""}',
                style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l.totalFobMetric}: $amountStr',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.wcagEmerald,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cbmWeightStr,
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: POFulfillmentProgressWidget.fromPO(
                  po: po,
                  isCompact: true,
                ),
              ),
              const Divider(height: 16),

              // Bottom Actions Row (Responsive)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l.invoiceDateCol}: $invoiceDateStr',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (po.poId != null) ...[
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.cobalt, size: 18),
                      tooltip: l.poBalanceLedgerTooltip,
                      onPressed: () => onBalanceLedger(po),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.local_shipping_outlined, color: AppTheme.emerald, size: 18),
                      tooltip: l.poCreatePartialShipment,
                      onPressed: () => onPartialShipment(po),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RowActionsPill(
                  onView: () => onView(po),
                  onEdit: () => onEdit(po),
                  onClone: () => onClone(po),
                  cloneTooltip: l.cloneRowTooltip,
                  onPrint: () => onPrint(po),
                  onDelete: () => onToggleActive(po),
                  deleteTooltip: po.isActive ? l.deactivatePoTooltip : l.restorePoTooltip,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
