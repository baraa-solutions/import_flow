import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/system_observability_provider.dart';

class DomainRadarTab extends ConsumerWidget {
  final bool isArabic;

  const DomainRadarTab({
    super.key,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarAsync = ref.watch(domainRadarProvider);

    return radarAsync.when(
      data: (radar) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildRadarCard(
                      title: isArabic ? 'رادار انتهاء صلاحية الـ ACID' : 'ACID Expiry Radar',
                      count: radar.expiringAcidsCount,
                      subtitle: isArabic ? 'شحنات تنتهي صلاحية رقم القيد خلال < 7 أيام' : 'Shipments expiring within 7 days',
                      icon: Icons.timelapse_rounded,
                      color: radar.expiringAcidsCount > 0 ? AppTheme.crimson : AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRadarCard(
                      title: isArabic ? 'مخاطر غرامات الحاويات' : 'Demurrage Penalty Risks',
                      count: radar.demurrageRisksCount,
                      subtitle: isArabic ? 'حاويات متبقي لها أقل من 48 ساعة فترة سماح' : 'Containers with < 48h free time',
                      icon: Icons.warning_amber_rounded,
                      color: radar.demurrageRisksCount > 0 ? AppTheme.orange : AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildRadarCard(
                      title: isArabic ? 'الشحنات العالقة' : 'Stuck Shipments',
                      count: radar.stuckShipmentsCount,
                      subtitle: isArabic ? 'ملفات متوقفة في نفس المرحلة لأكثر من 10 أيام' : 'Files stuck in stage for > 10 days',
                      icon: Icons.pause_circle_outline_rounded,
                      color: radar.stuckShipmentsCount > 0 ? AppTheme.orange : AppTheme.emerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (radar.lastBackupStatus == 'HEALTHY'
                                  ? AppTheme.emerald
                                  : AppTheme.crimson)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.backup_rounded,
                          color: radar.lastBackupStatus == 'HEALTHY'
                              ? AppTheme.emerald
                              : AppTheme.crimson,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'حالة النسخ الاحتياطي التلقائي اليومي' : 'Daily Automated Backup Health',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              radar.lastBackupFile != null
                                  ? 'الملف: ${radar.lastBackupFile} (${radar.lastBackupSizeMb} MB) • الوقت: ${radar.lastBackupTimestamp}'
                                  : 'لم يتم العثور على أي نسخ احتياطية في مجلد backups',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      AppStatusBadge(
                        label: radar.lastBackupStatus,
                        severity: radar.lastBackupStatus == 'HEALTHY'
                            ? AppSeverity.success
                            : AppSeverity.danger,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (radar.expiringAcids.isNotEmpty) ...[
                const Text(
                  'تفاصيل الشحنات المهددة بانتهاء الـ ACID:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: radar.expiringAcids.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = radar.expiringAcids[i];
                      final isExpired = item['is_expired'] == true;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.timelapse_rounded,
                          color: isExpired ? AppTheme.crimson : AppTheme.orange,
                        ),
                        title: Text(
                          'ACID: ${item['acid_number']} (فاتورة: ${item['proforma_invoice'] ?? 'N/A'})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        subtitle: Text(
                          isExpired
                              ? 'انتهت الصلاحية! يرجى تجديد أو تمديد الرقم في نافذة فوراً'
                              : 'متبقي ${item['days_remaining']} يوم على انتهاء الصلاحية',
                          style: TextStyle(
                            color: isExpired ? AppTheme.crimson : AppTheme.orange,
                            fontSize: 11,
                          ),
                        ),
                        trailing: AppStatusBadge(
                          label: isExpired ? 'EXPIRED' : 'URGENT',
                          severity: isExpired ? AppSeverity.danger : AppSeverity.warning,
                          size: AppStatusBadgeSize.small,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const AppLoadingState(),
      error: (e, _) => Center(child: Text('خطأ في جلب بيانات الرادار: $e')),
    );
  }

  Widget _buildRadarCard({
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
