import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../l10n/po_fulfillment_l10n.dart';
import '../../models/purchase_order_model.dart';
import '../../providers/purchase_orders_provider.dart';
import '../create_partial_shipment_dialog.dart';
import '../po_fulfillment_progress_widget.dart';
import '../po_table_cells.dart';
import 'po_resolved_metrics.dart';

/// Shipment Allocations Ledger & Fulfillment Balance Tab (EPIC-PO-PART).
///
/// Features:
/// - Real-time PO fulfillment balance & progress indicators
/// - Ordered vs Shipped vs Remaining KPI balance cards
/// - Direct "Allocate Partial Shipment" button triggering the modal dialog
/// - Line Items fulfillment balance breakdown table
/// - Shipment allocations ledger / batch history log
class PoDetailsAllocationsTab extends ConsumerStatefulWidget {
  final PurchaseOrderModel po;
  final POResolvedMetrics metrics;

  const PoDetailsAllocationsTab({
    super.key,
    required this.po,
    required this.metrics,
  });

  @override
  ConsumerState<PoDetailsAllocationsTab> createState() =>
      _PoDetailsAllocationsTabState();
}

class _PoDetailsAllocationsTabState
    extends ConsumerState<PoDetailsAllocationsTab> {
  bool _isLoadingBalance = false;
  POBalanceSummaryModel? _balanceSummary;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('PoDetailsAllocationsTab disposed');
    super.dispose();
  }

  Future<void> _fetchBalance() async {
    final poId = widget.po.poId;
    if (poId == null) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    setState(() => _isLoadingBalance = true);

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/purchase-orders/$poId/balance',
        cancelToken: _cancelToken,
      );
      if (mounted && res.data is Map<String, dynamic>) {
        setState(() {
          _balanceSummary = POBalanceSummaryModel.fromJson(res.data);
          _isLoadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  Future<void> _handleAllocateShipment(BuildContext context) async {
    final result = await showCreatePartialShipmentDialog(
      context,
      po: widget.po,
    );
    if (result == true) {
      ref.invalidate(purchaseOrdersProvider);
      _fetchBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final contracted = _balanceSummary?.totalContractedQty ??
        widget.po.effectiveContractedQuantity;
    final shipped =
        _balanceSummary?.totalShippedQty ?? widget.po.totalShippedQuantity;
    final remaining = _balanceSummary?.totalRemainingQty ??
        (widget.po.remainingBalanceQuantity > 0
            ? widget.po.remainingBalanceQuantity
            : (contracted > shipped ? contracted - shipped : 0.0));

    final orderedAmount = _balanceSummary?.totalOrderedAmountFob ??
        widget.po.totalAmountFob;
    final shippedAmount = _balanceSummary?.totalShippedAmountFob ?? 0.0;
    final remainingAmount = _balanceSummary?.totalRemainingAmountFob ??
        (orderedAmount > shippedAmount ? orderedAmount - shippedAmount : 0.0);

    final currency =
        _balanceSummary?.currencyCode ?? widget.po.currencyCode ?? 'USD';

    final allocations = _balanceSummary?.allocations ?? const <POShipmentAllocationModel>[];

    final lineBalances = _balanceSummary?.lineItemsBalance ?? const [];

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.poFulfillmentProgressTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.poFulfillmentSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: l.poCreatePartialShipmentBtn,
                  icon: Icons.add_shopping_cart,
                  variant: AppButtonVariant.primary,
                  onPressed: () => _handleAllocateShipment(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: l.refresh,
                  onPressed: _isLoadingBalance ? null : _fetchBalance,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Main Fulfillment Progress Widget
            if (_balanceSummary != null)
              POFulfillmentProgressWidget.fromBalanceSummary(
                balance: _balanceSummary!,
                isCompact: false,
                onAllocatePressed: () => _handleAllocateShipment(context),
              )
            else
              POFulfillmentProgressWidget.fromPO(
                po: widget.po,
                isCompact: false,
                onAllocatePressed: () => _handleAllocateShipment(context),
              ),

            const SizedBox(height: 16),

            // 3 KPI Cards: Contracted vs Shipped vs Remaining Balance
            Row(
              children: [
                Expanded(
                  child: _buildBalanceKpiCard(
                    title: l.poContractedQty,
                    qtyText: '${contracted.toStringAsFixed(0)} ${l.poUnitsLabel}',
                    valueText: '$currency ${orderedAmount.toStringAsFixed(2)}',
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    icon: Icons.inventory_2_outlined,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBalanceKpiCard(
                    title: l.poShippedQty,
                    qtyText: '${shipped.toStringAsFixed(0)} ${l.poUnitsLabel}',
                    valueText: '$currency ${shippedAmount.toStringAsFixed(2)}',
                    color: AppTheme.emerald,
                    icon: Icons.local_shipping_outlined,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBalanceKpiCard(
                    title: l.poRemainingQty,
                    qtyText: '${remaining.toStringAsFixed(0)} ${l.poUnitsLabel}',
                    valueText: '$currency ${remainingAmount.toStringAsFixed(2)}',
                    color: remaining > 0 ? AppTheme.orange : AppTheme.emerald,
                    icon: Icons.hourglass_bottom_outlined,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Line Items Balance Breakdown Table (if available)
            if (lineBalances.isNotEmpty) ...[
              Text(
                l.poBalanceLineItemsTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Table(
                border: TableBorder.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.charcoalSurface,
                    ),
                    children: [
                      PoHeaderCell(l.poBalanceColItemCode, fontSize: 11),
                      PoHeaderCell(l.poBalanceColDescription, fontSize: 11),
                      PoHeaderCell(l.poBalanceColOrderedQty, fontSize: 11),
                      PoHeaderCell(l.poBalanceColShippedQty, fontSize: 11),
                      PoHeaderCell(l.poBalanceColRemaining, fontSize: 11),
                      PoHeaderCell(l.poBalanceColStatus, fontSize: 11),
                    ],
                  ),
                  ...lineBalances.map((line) {
                    final isDone = line.remainingQty <= 0 && line.contractedQty > 0;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            line.itemCode ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextPrimary : null,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            line.descriptionAr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextPrimary : null,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            line.contractedQty.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextPrimary : null,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            line.shippedQty.toStringAsFixed(0),
                            style: const TextStyle(
                              color: AppTheme.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            line.remainingQty.toStringAsFixed(0),
                            style: TextStyle(
                              color: line.remainingQty > 0
                                  ? AppTheme.orange
                                  : AppTheme.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Center(
                            child: AppStatusBadge(
                              label: isDone
                                  ? l.poBalanceStatusCompleted
                                  : l.poBalanceStatusPartial,
                              severity: isDone
                                  ? AppSeverity.success
                                  : AppSeverity.warning,
                              size: AppStatusBadgeSize.small,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Previous Shipment Allocations History Table
            Text(
              l.poAllocationsListTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 6),

            if (allocations.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_shipping_outlined,
                      size: 36,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.poNoAllocationsYet,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: l.poCreatePartialShipmentBtn,
                      icon: Icons.add,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: () => _handleAllocateShipment(context),
                    ),
                  ],
                ),
              )
            else
              Table(
                border: TableBorder.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
                ),
                columnWidths: const {
                  0: FlexColumnWidth(1.6),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.4),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1.2),
                  5: FlexColumnWidth(1.8),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
                    ),
                    children: [
                      PoHeaderCell(l.poShipmentBatchNo, fontSize: 11),
                      PoHeaderCell(l.poAllocatedQuantity, fontSize: 11),
                      PoHeaderCell(l.poAllocatedFobAmount, fontSize: 11),
                      PoHeaderCell(l.poShippingDate, fontSize: 11),
                      PoHeaderCell(l.poAllocationBatchStatus, fontSize: 11),
                      PoHeaderCell(l.poAllocationNotes, fontSize: 11),
                    ],
                  ),
                  ...allocations.map((alloc) {
                    final dateStr = alloc.shippingDate != null
                        ? "${alloc.shippingDate!.year}-${alloc.shippingDate!.month.toString().padLeft(2, '0')}-${alloc.shippingDate!.day.toString().padLeft(2, '0')}"
                        : '-';
                    final qty = alloc.allocatedQuantity > 0
                        ? alloc.allocatedQuantity
                        : alloc.shippedQuantity;
                    final fob = alloc.allocatedFobAmount > 0
                        ? alloc.allocatedFobAmount
                        : alloc.shippedAmountFob;

                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            alloc.shipmentBatchNo ?? alloc.shipmentRef,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppTheme.cobalt,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${qty.toStringAsFixed(0)} ${l.poUnitsLabel}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextPrimary : null,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '$currency ${fob.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppTheme.emerald,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextPrimary : null,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Center(
                            child: AppStatusBadge.fromStatus(
                              status: alloc.status,
                              size: AppStatusBadgeSize.small,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            alloc.notes ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceKpiCard({
    required String title,
    required String qtyText,
    required String valueText,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
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
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            qtyText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valueText,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
