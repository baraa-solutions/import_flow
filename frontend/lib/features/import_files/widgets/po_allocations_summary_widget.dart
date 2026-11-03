import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../purchase_orders/l10n/po_fulfillment_l10n.dart';
import '../../purchase_orders/models/purchase_order_model.dart';

/// Displays PO allocations associated with an Import File (EPIC-PO-PART).
class POAllocationsSummaryWidget extends ConsumerWidget {
  final int importFileId;
  final List<POShipmentAllocationModel> allocations;

  const POAllocationsSummaryWidget({
    super.key,
    required this.importFileId,
    this.allocations = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fileAllocations = allocations.where((a) => a.importFileId == importFileId).toList();

    return SelectionArea(
      child: Container(
        decoration: AppTheme.cardDecorationOf(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.share_arrival_time_outlined, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.poAllocationsListTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${fileAllocations.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.cobalt,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (fileAllocations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.poNoAllocationsYet,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fileAllocations.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (ctx, index) {
                  final alloc = fileAllocations[index];
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alloc.shipmentBatchNo ?? alloc.shipmentRef,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (alloc.shippingDate != null)
                              Text(
                                '${alloc.shippingDate!.year}-${alloc.shippingDate!.month.toString().padLeft(2, '0')}-${alloc.shippingDate!.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${alloc.allocatedQuantity.toStringAsFixed(alloc.allocatedQuantity % 1 == 0 ? 0 : 2)} ${l.poUnitsLabel}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      AppStatusBadge.fromStatus(status: alloc.status),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
