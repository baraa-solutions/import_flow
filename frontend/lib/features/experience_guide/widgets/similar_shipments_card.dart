import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/similar_shipment_model.dart';
import '../providers/experience_guide_provider.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class SimilarShipmentsCard extends ConsumerWidget {
  final int importFileId;

  const SimilarShipmentsCard({
    super.key,
    required this.importFileId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similarAsync = ref.watch(similarShipmentsProvider(importFileId));

    return similarAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (shipments) {
        if (shipments.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 14, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            leading: const Icon(Icons.history_toggle_off_rounded, color: AppTheme.flatCobalt),
            title: Text(
              'سجل الشحنات السابقة المماثلة (${shipments.length} شحنة مطابقة)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.flatCharcoal,
              ),
            ),
            subtitle: const Text(
              'مقارنة الأداء الزمني، نسب انحراف التكلفة، وملاحظات الشحنات السابقة بنفس المورد/الميناء',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            children: [
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shipments.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final s = shipments[idx];
                  return _buildShipmentItem(s);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShipmentItem(SimilarShipmentModel s) {
    final variance = s.costVariancePct ?? 0.0;
    final isVarianceHigh = variance > 10.0;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.flatCobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: LtrText(
                  s.importFileCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.flatCobalt,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                s.supplierName ?? 'مورد غير محدد',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: s.status == 'Closed' ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: s.status == 'Closed' ? Colors.green.shade300 : Colors.blue.shade300,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  s.status ?? 'مكتمل',
                  style: TextStyle(
                    fontSize: 10,
                    color: s.status == 'Closed' ? AppTheme.flatEmerald : AppTheme.flatCobalt,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Metrics Row
          Row(
            children: [
              if (s.portOfDischarge != null) ...[
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(s.portOfDischarge!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 14),
              ],
              if (s.shippingLine != null) ...[
                const Icon(Icons.directions_boat_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(s.shippingLine!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 14),
              ],
              if (s.customsExecutionDays != null) ...[
                const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${s.customsExecutionDays} يوم تخليص',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 14),
              ],
              if (s.costVariancePct != null) ...[
                Icon(
                  isVarianceHigh ? Icons.trending_up : Icons.trending_flat,
                  size: 14,
                  color: isVarianceHigh ? AppTheme.flatCrimson : AppTheme.flatEmerald,
                ),
                const SizedBox(width: 4),
                Text(
                  'انحراف تكلفة: ${variance >= 0 ? "+" : ""}${variance.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isVarianceHigh ? AppTheme.flatCrimson : AppTheme.flatEmerald,
                  ),
                ),
              ],
            ],
          ),
          if (s.notes != null && s.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'درس من الشحنة: ${s.notes!}',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
