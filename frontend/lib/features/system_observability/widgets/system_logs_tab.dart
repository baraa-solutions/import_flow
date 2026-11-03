import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/system_observability_provider.dart';

/// 📜 System Logs & Traffic Telemetry Tab
///
/// Displays slow database query telemetry and recent incoming HTTP traffic
/// with correlation IDs, latency tracking, and client log export.
class SystemLogsTab extends ConsumerWidget {
  final Future<void> Function()? onExportClientLogs;

  const SystemLogsTab({
    super.key,
    this.onExportClientLogs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trafficAsync = ref.watch(recentTrafficProvider);
    final dbHealthAsync = ref.watch(databaseHealthProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slow Queries Card (if any)
            dbHealthAsync.when(
              data: (dbh) {
                if (dbh.recentSlowQueries.isEmpty) {
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isArabic
                                ? 'لا توجد استعلامات بطيئة مسجلة (أقل من 150 مللي ثانية)'
                                : 'No slow queries recorded (< 150ms)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppTheme.orange.withValues(alpha: 0.4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isArabic
                                  ? 'استعلامات بطيئة تجاوزت 150 مللي ثانية (${dbh.recentSlowQueries.length})'
                                  : 'Slow queries exceeding 150ms (${dbh.recentSlowQueries.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.charcoal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...dbh.recentSlowQueries.map(
                          (sq) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${sq.durationMs} ms',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.crimson,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sq.statement,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5),
                                    ),
                                  ),
                                  Text(
                                    sq.timestamp,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Recent HTTP Requests Table
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'سجل حركة المرور المباشر مع معرّف التتبع'
                          : 'Recent Traffic & Correlation IDs',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 10),
                    trafficAsync.when(
                      data: (traffic) {
                        if (traffic.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(isArabic ? 'لا توجد طلبات مسجلة' : 'No recorded requests'),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: traffic.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = traffic[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  _buildMethodChip(item.method),
                                  const SizedBox(width: 8),
                                  _buildStatusCodeChip(item.statusCode),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.path,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${item.durationMs} ms',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: item.durationMs > 300 ? AppTheme.orange : Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.requestId,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => CopyHelper.copy(
                                            context,
                                            item.requestId,
                                            customMessage: isArabic
                                                ? 'تم نسخ معرّف الطلب'
                                                : 'Request ID copied',
                                          ),
                                          child: Icon(
                                            Icons.copy_rounded,
                                            size: 11,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.timestamp.split(' ').last,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          isArabic ? 'خطأ في جلب سجل المرور: $e' : 'Error fetching traffic logs: $e',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (onExportClientLogs != null) ...[
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
                      const Icon(Icons.desktop_windows_outlined, color: AppTheme.charcoal, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'تصدير سجل أحداث واجهة الديسكتوب' : 'Client Diagnostics Log',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArabic
                                  ? 'تصدير ملف يحتوي على آخر الأحداث وأخطاء الشبكة والواجهة المسجلة على جهاز المستخدم الحالي.'
                                  : 'Export a file containing recent events, network requests, and client logs recorded on this device.',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onExportClientLogs,
                        icon: const Icon(Icons.download_rounded, size: 15),
                        label: Text(
                          isArabic ? 'تصدير سجل العميل (.log)' : 'Export Client Log (.log)',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String method) {
    Color bg;
    switch (method.toUpperCase()) {
      case 'GET':
        bg = AppTheme.cobalt;
        break;
      case 'POST':
        bg = AppTheme.emerald;
        break;
      case 'PUT':
      case 'PATCH':
        bg = AppTheme.orange;
        break;
      case 'DELETE':
        bg = AppTheme.crimson;
        break;
      default:
        bg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(color: bg, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildStatusCodeChip(int code) {
    Color color;
    if (code >= 200 && code < 300) {
      color = AppTheme.emerald;
    } else if (code >= 300 && code < 400) {
      color = AppTheme.cobalt;
    } else if (code >= 400 && code < 500) {
      color = AppTheme.orange;
    } else {
      color = AppTheme.crimson;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$code',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
