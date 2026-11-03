import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

import '../../../core/widgets/buttons/app_button.dart';
import '../container_tracking_provider.dart';

/// Drawer/Panel showing individual container lifecycle milestones and timeline progression.
class ContainerTimelineDrawer extends StatelessWidget {
  final ContainerUnitData container;
  final VoidCallback onClose;
  final Function(Map<String, dynamic> updatePayload) onUpdateMilestone;

  const ContainerTimelineDrawer({
    super.key,
    required this.container,
    required this.onClose,
    required this.onUpdateMilestone,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'لم يحدد بعد';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Widget _buildTimelineStep({
    required String title,
    required String dateText,
    required bool isDone,
    required bool isCurrent,
    required IconData icon,
    VoidCallback? onSetToday,
  }) {
    final color = isDone
        ? AppTheme.emerald
        : isCurrent
            ? AppTheme.cobalt
            : AppTheme.border;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDone || isCurrent ? AppTheme.charcoal : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateText,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (!isDone && onSetToday != null)
            AppButton(
              label: 'تسجيل الآن',
              icon: Icons.check,
              variant: AppButtonVariant.secondary,
              onPressed: onSetToday,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مسار الحاوية ${container.containerNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.charcoal,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Specs Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('نوع الحاوية:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    Text(container.isoType, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('رقم الختم:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    Text(container.sealNumber ?? 'غير مسجل', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الوزن القائم (VGM):', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    Text(
                      container.vgmWeight != null ? '${container.vgmWeight!.toStringAsFixed(0)} كجم' : '—',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'المحطات الزمنية للحاوية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              children: [
                _buildTimelineStep(
                  title: 'وصول السفينة والشحن البحري',
                  dateText: 'تم شحن الحاوية بنجاح',
                  isDone: true,
                  isCurrent: container.status == 'ON_VESSEL',
                  icon: Icons.directions_boat,
                ),
                _buildTimelineStep(
                  title: 'تفريغ الحاوية في الميناء',
                  dateText: _formatDate(container.dischargeDate),
                  isDone: container.dischargeDate != null,
                  isCurrent: container.status == 'DISCHARGED',
                  icon: Icons.download,
                  onSetToday: () {
                    final now = DateTime.now();
                    onUpdateMilestone({
                      'discharge_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                    });
                  },
                ),
                _buildTimelineStep(
                  title: 'خروج تحت التحفظ الجمركي',
                  dateText: _formatDate(container.gateOutHeldDate),
                  isDone: container.gateOutHeldDate != null,
                  isCurrent: container.status == 'GATE_OUT_HELD',
                  icon: Icons.local_shipping,
                  onSetToday: () {
                    final now = DateTime.now();
                    onUpdateMilestone({
                      'gate_out_held_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                    });
                  },
                ),
                _buildTimelineStep(
                  title: 'إرجاع الحاوية الفارغة للمستودع',
                  dateText: _formatDate(container.emptyReturnedDate),
                  isDone: container.emptyReturnedDate != null,
                  isCurrent: container.status == 'RETURNED_EMPTY',
                  icon: Icons.assignment_return,
                  onSetToday: () {
                    final now = DateTime.now();
                    onUpdateMilestone({
                      'empty_returned_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
