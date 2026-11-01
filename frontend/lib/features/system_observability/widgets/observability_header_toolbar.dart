import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/system_observability_provider.dart';

class ObservabilityHeaderToolbar extends ConsumerWidget {
  final bool isArabic;
  final bool isAutoRefresh;
  final ValueChanged<bool> onToggleAutoRefresh;
  final VoidCallback onRefreshAllData;
  final VoidCallback onSendTestAlert;
  final VoidCallback onExportDiagnostics;
  final bool isExporting;

  const ObservabilityHeaderToolbar({
    super.key,
    required this.isArabic,
    required this.isAutoRefresh,
    required this.onToggleAutoRefresh,
    required this.onRefreshAllData,
    required this.onSendTestAlert,
    required this.onExportDiagnostics,
    required this.isExporting,
  });

  AppSeverity _statusSeverity(String status) {
    return switch (status.toUpperCase()) {
      'HEALTHY' => AppSeverity.success,
      'DEGRADED' => AppSeverity.warning,
      'CRITICAL' || 'OFFLINE' => AppSeverity.danger,
      _ => AppSeverity.info,
    };
  }

  String _statusLabel(String status, bool isArabic) {
    return switch (status.toUpperCase()) {
      'HEALTHY' => isArabic ? 'مستقر وطبيعي' : 'Healthy',
      'DEGRADED' => isArabic ? 'استجابة متدهورة' : 'Degraded',
      'CRITICAL' => isArabic ? 'تحذير حرج' : 'Critical',
      'OFFLINE' => isArabic ? 'غير متصل' : 'Offline',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(systemMetricsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: AppTheme.cobalt,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabic ? 'مركز مراقبة وصحة النظام' : 'System Observability & Health',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
              Text(
                'Live Metrics • Database WAL • Domain Radar • Diagnostics',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const Spacer(),
          metricsAsync.when(
            data: (m) => AppStatusBadge(
              label: _statusLabel(m.status, isArabic),
              severity: _statusSeverity(m.status),
            ),
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: AppLoadingState.inline(),
            ),
            error: (_, __) => AppStatusBadge(
              label: isArabic ? 'غير متصل' : 'Offline',
              severity: AppSeverity.danger,
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabic ? 'تحديث تلقائي (5 ثوانٍ)' : 'Auto-refresh (5s)',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 4),
              Switch(
                value: isAutoRefresh,
                onChanged: onToggleAutoRefresh,
                activeThumbColor: AppTheme.cobalt,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onRefreshAllData,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: Text(
              isArabic ? 'تحديث الآن' : 'Refresh Now',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onSendTestAlert,
            icon: const Icon(
              Icons.notifications_active_outlined,
              size: 15,
              color: AppTheme.orange,
            ),
            label: Text(
              isArabic ? 'اختبار التنبيه' : 'Test Alert',
              style: const TextStyle(fontSize: 12, color: AppTheme.charcoal),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isExporting ? null : onExportDiagnostics,
            icon: isExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: AppLoadingState.inline(),
                  )
                : const Icon(Icons.archive_outlined, size: 15),
            label: Text(
              isArabic ? 'تصدير حزمة الدعم' : 'Export Diagnostics',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.charcoal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
          ),
        ],
      ),
    );
  }
}
