import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/system_observability_provider.dart';
import 'system_health_table.dart';

class DeepHealthTab extends ConsumerWidget {
  final bool isArabic;
  final VoidCallback onExportClientLogs;

  const DeepHealthTab({
    super.key,
    required this.isArabic,
    required this.onExportClientLogs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deepHealthAsync = ref.watch(deepHealthProbeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.troubleshoot_rounded, color: AppTheme.cobalt, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'الفحص العميق لقاعدة البيانات والنظام' : 'Deep Integrity Probe',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.charcoal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isArabic
                              ? 'يختبر فعلياً عملية الكتابة والقراءة الحية، وفحص سلامة هياكل الجداول، والمساحة المتبقية على القرص.'
                              : 'Actively probes live read/write operations, table structure integrity, and remaining disk space.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(deepHealthProbeProvider.notifier).runProbe(),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(isArabic ? 'تشغيل الفحص العميق' : 'Run Deep Probe', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          deepHealthAsync.when(
            data: (probe) => SystemHealthTable(
              probe: probe,
              isArabic: isArabic,
              onRunProbe: () => ref.read(deepHealthProbeProvider.notifier).runProbe(),
            ),
            loading: () => SystemHealthTable(
              isLoading: true,
              isArabic: isArabic,
            ),
            error: (e, _) => SystemHealthTable(
              errorMessage: e.toString(),
              isArabic: isArabic,
            ),
          ),
          const SizedBox(height: 20),
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
                    label: Text(isArabic ? 'تصدير سجل العميل (.log)' : 'Export Client Log (.log)', style: const TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
