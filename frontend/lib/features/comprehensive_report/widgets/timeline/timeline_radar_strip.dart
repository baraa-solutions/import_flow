import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../models/shipment_audit_timeline_model.dart';

/// Financial and transit radar summary strip (storage, demurrage, expected and actual warehouse delivery).
class TimelineRadarStrip extends StatelessWidget {
  final FinancialRadarSummaryModel radar;
  final bool isDark;

  const TimelineRadarStrip({
    super.key,
    required this.radar,
    required this.isDark,
  });

  Widget _buildRadarCardItem({
    required String title,
    required IconData icon,
    required String dateStr,
    required String subtitle,
    required String statusBadge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 4,
            runSpacing: 2,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: AppTheme.cobalt),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LtrText(
            dateStr,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;
          final items = [
            _buildRadarCardItem(
              title: 'أرضيات الميناء (Storage)',
              icon: Icons.domain,
              dateStr: radar.portStorageStartDate ?? 'غير محدد',
              subtitle: 'سماح: ${radar.portStorageFreeDays} أيام │ متبقي: ${radar.portStorageDaysRemaining ?? "-"} أيام',
              statusBadge: radar.portStorageStatus,
              badgeColor: radar.portStorageStatus == 'SAFE' ? AppTheme.emerald : AppTheme.wcagCrimson,
            ),
            _buildRadarCardItem(
              title: 'غرامات الحاوية (Demurrage)',
              icon: Icons.directions_boat,
              dateStr: radar.demurrageStartDate ?? 'غير محدد',
              subtitle: 'سماح: ${radar.demurrageFreeDays} يوماً │ متبقي: ${radar.demurrageDaysRemaining ?? "-"} أيام',
              statusBadge: radar.demurrageStatus,
              badgeColor: radar.demurrageStatus == 'SAFE' ? AppTheme.emerald : AppTheme.wcagCrimson,
            ),
            _buildRadarCardItem(
              title: 'المتوقع لوصول المخزن (ديناميكي)',
              icon: Icons.schedule,
              dateStr: radar.expectedWarehouseDeliveryDate ?? 'غير محدد',
              subtitle: 'محسوب آلياً بناءً على تتبع الباخرة',
              statusBadge: 'هدف استرشادي',
              badgeColor: AppTheme.cobalt,
            ),
            _buildRadarCardItem(
              title: 'الوصول الفعلي للمخزن (GRN)',
              icon: Icons.inventory_2,
              dateStr: radar.actualWarehouseDeliveryDate ?? '⏳ جاري الإبحار والتخليص',
              subtitle: radar.warehouseVarianceDays != null
                  ? (radar.warehouseVarianceDays == 0
                      ? 'في الموعد المحدد'
                      : 'انحراف: +${radar.warehouseVarianceDays} يوم')
                  : 'بانتظار التفريغ',
              statusBadge: radar.actualWarehouseDeliveryDate != null ? '✅ تم الاستلام' : 'قيد المتابعة',
              badgeColor: radar.actualWarehouseDeliveryDate != null ? AppTheme.emerald : Colors.blueGrey,
            ),
          ];

          if (isNarrow) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: items[0]),
                    const SizedBox(width: 8),
                    Expanded(child: items[1]),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: items[2]),
                    const SizedBox(width: 8),
                    Expanded(child: items[3]),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: items[0]),
              const SizedBox(width: 8),
              Expanded(child: items[1]),
              const SizedBox(width: 8),
              Expanded(child: items[2]),
              const SizedBox(width: 8),
              Expanded(child: items[3]),
            ],
          );
        },
      ),
    );
  }
}
