import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../container_tracking_provider.dart';

/// Card/Dialog detailing individual container demurrage and free time calculation.
class DemurragePerContainerCard extends StatelessWidget {
  final ContainerUnitData container;
  final VoidCallback onRecalculate;
  final VoidCallback onClose;

  const DemurragePerContainerCard({
    super.key,
    required this.container,
    required this.onRecalculate,
    required this.onClose,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'غير محدد';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final demurrage = container.demurrageCharges.isNotEmpty
        ? container.demurrageCharges.first
        : null;

    final freeDays = demurrage?.freeTimeDays ?? 14;
    final freeEndDate = demurrage?.freeTimeEndDate;
    final dailyRate = demurrage?.dailyDemurrageRate ?? 0.0;
    final overdueDays = demurrage?.daysOverdue ?? 0;
    final totalAmount = demurrage?.totalDemurrageAmount ?? 0.0;
    final currency = demurrage?.currency ?? 'USD';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.alarm, color: AppTheme.orange, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'غرامات تأخير الحاوية: ${container.containerNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Metrics summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: totalAmount > 0 ? AppTheme.crimson.withValues(alpha: 0.08) : AppTheme.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: totalAmount > 0 ? AppTheme.crimson.withValues(alpha: 0.3) : AppTheme.emerald.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('أيام التأخير', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '$overdueDays يوم',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: overdueDays > 0 ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 36, width: 1, color: AppTheme.border),
                  Column(
                    children: [
                      const Text('إجمالي الغرامة', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '${totalAmount.toStringAsFixed(2)} $currency',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: totalAmount > 0 ? AppTheme.crimson : AppTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Parameters breakdown
            _buildInfoRow('فترة السماح الممنوحة:', '$freeDays يوماً'),
            const SizedBox(height: 8),
            _buildInfoRow('تاريخ نهاية فترة السماح:', _formatDate(freeEndDate)),
            const SizedBox(height: 8),
            _buildInfoRow('المعدل اليومي للغرامة:', '${dailyRate.toStringAsFixed(2)} $currency / يوم'),
            const SizedBox(height: 8),
            _buildInfoRow('تاريخ إرجاع الفارغ الفعلي:', _formatDate(container.emptyReturnedDate)),
            const SizedBox(height: 8),
            _buildInfoRow('الملاحظات / الإعفاءات:', demurrage?.notes ?? 'لا توجد إعفاءات مسجلة'),

            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: 'إغلاق',
                  variant: AppButtonVariant.secondary,
                  onPressed: onClose,
                ),
                AppButton(
                  label: 'إعادة احتساب الغرامة',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.primary,
                  onPressed: onRecalculate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
          ),
        ),
      ],
    );
  }
}
