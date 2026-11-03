import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../customs_regimes_provider.dart';

class ReExportReconciliationCard extends StatelessWidget {
  final CustomsRegimeItem item;
  final VoidCallback onSettlePressed;

  const ReExportReconciliationCard({
    super.key,
    required this.item,
    required this.onSettlePressed,
  });

  @override
  Widget build(BuildContext context) {
    final days = item.daysUntilReExport;
    Color statusColor;
    String statusTitle;

    if (item.isSettled) {
      statusColor = AppTheme.emerald;
      statusTitle = 'تمت التسوية وإعادة التصدير بنجاح';
    } else if (days == null) {
      statusColor = AppTheme.textMuted;
      statusTitle = 'لم تحدد مهلة قانونية لإعادة التصدير';
    } else if (days < 0) {
      statusColor = AppTheme.crimson;
      statusTitle = 'تجاوزت المهلة القانونية لإعادة التصدير (متأخر $days- يوم)';
    } else if (days <= 30) {
      statusColor = AppTheme.orange;
      statusTitle = 'اقتراب انتهاء مهلة إعادة التصدير (متبقي $days يوم)';
    } else {
      statusColor = AppTheme.emerald;
      statusTitle = 'المهلة القانونية سارية (متبقي $days يوم)';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: statusColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.isSettled ? Icons.verified_outlined : Icons.alarm_outlined,
                  color: statusColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (!item.isSettled)
                  AppButton(
                    label: 'تسوية وإغلاق النظام',
                    icon: Icons.check,
                    variant: AppButtonVariant.success,
                    onPressed: onSettlePressed,
                  ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    'المهلة القانونية القصوى',
                    item.reExportDeadline != null
                        ? item.reExportDeadline!.toIso8601String().substring(0, 10)
                        : 'غير مسجل',
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    'تاريخ إعادة التصدير الفعلي',
                    item.actualReExportDate != null
                        ? item.actualReExportDate!.toIso8601String().substring(0, 10)
                        : 'قيد التنفيذ',
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    'رقم شهادة الصادر',
                    item.reExportExportDeclarationNo ?? 'غير متوفر',
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    'مبالغ رد الرسوم المستردة',
                    '${item.drawbackRefundAmount.toStringAsFixed(2)} ${item.guaranteeCurrency}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
      ],
    );
  }
}
