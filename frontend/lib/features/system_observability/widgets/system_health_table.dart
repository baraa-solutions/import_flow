import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/system_observability_model.dart';

/// 🏥 System Health & Integrity Table
///
/// Presents diagnostic integrity probe results and endpoint health metrics
/// with canonical status indicators and severity badges.
class SystemHealthTable extends StatelessWidget {
  final DeepHealthCheckModel? probe;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRunProbe;
  final List<HttpEndpointStatModel>? topEndpoints;
  final bool isArabic;

  const SystemHealthTable({
    super.key,
    this.probe,
    this.isLoading = false,
    this.errorMessage,
    this.onRunProbe,
    this.topEndpoints,
    this.isArabic = true,
  });

  static AppSeverity resolveSeverity(String verdict) {
    return switch (verdict.toUpperCase()) {
      'HEALTHY' || 'PASS' || 'OK' => AppSeverity.success,
      'DEGRADED' || 'WARNING' => AppSeverity.warning,
      'CRITICAL' || 'FAIL' || 'OFFLINE' || 'CORRUPTED' => AppSeverity.danger,
      _ => AppSeverity.info,
    };
  }

  static String resolveLabel(String verdict, bool isArabic) {
    return switch (verdict.toUpperCase()) {
      'HEALTHY' => isArabic ? 'مستقر وطبيعي' : 'Healthy',
      'DEGRADED' => isArabic ? 'استجابة متدهورة' : 'Degraded',
      'CRITICAL' => isArabic ? 'تحذير حرج' : 'Critical',
      'PASS' => isArabic ? 'ناجح' : 'PASS',
      'FAIL' => isArabic ? 'فشل' : 'FAIL',
      'OK' => isArabic ? 'سليم' : 'OK',
      _ => verdict,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topEndpoints != null && topEndpoints!.isNotEmpty) ...[
          _buildEndpointsSection(context),
          const SizedBox(height: 16),
        ],
        _buildProbeSection(context),
      ],
    );
  }

  Widget _buildEndpointsSection(BuildContext context) {
    final endpoints = topEndpoints!;
    return Card(
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
              isArabic ? 'أكثر نقاط النهاية استخداماً' : 'Top Active Endpoints',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: endpoints.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ep = endpoints[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _buildMethodChip(ep.method),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ep.path,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${ep.count} reqs',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'P50: ${ep.p50Ms}ms | P95: ${ep.p95Ms}ms',
                          style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbeSection(BuildContext context) {
    if (isLoading) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text(
                  isArabic
                      ? 'جارٍ تنفيذ الفحص العميق لقاعدة البيانات...'
                      : 'Executing deep database probe...',
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.crimson),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              isArabic
                  ? 'خطأ في الفحص العميق: $errorMessage'
                  : 'Deep probe error: $errorMessage',
              style: const TextStyle(color: AppTheme.crimson),
            ),
          ),
        ),
      );
    }

    if (probe == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              isArabic
                  ? 'اضغط على زر "تشغيل الفحص العميق" لبدء الاختبار الحي لقاعدة البيانات والقرص.'
                  : 'Click "Run Deep Probe" to test live database operations and disk health.',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final p = probe!;
    final probeSeverity = resolveSeverity(p.verdict);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: probeSeverity == AppSeverity.success
              ? AppTheme.emerald
              : (probeSeverity == AppSeverity.warning ? AppTheme.orange : AppTheme.crimson),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AppStatusBadge(
                      label: resolveLabel(p.verdict, isArabic),
                      severity: probeSeverity,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${isArabic ? "وقت الفحص:" : "Probe Time:"} ${p.timestamp}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildProbeItem(
                    label: isArabic ? 'اختبار الكتابة الحية' : 'Live Write Probe',
                    status: p.databaseWriteProbe
                        ? (isArabic ? 'ناجح' : 'PASS')
                        : (isArabic ? 'فشل' : 'FAIL'),
                    detail: '${isArabic ? "زمن تنفيذ الكتابة:" : "Write Latency:"} ${p.databaseWriteLatencyMs} ms',
                    isOk: p.databaseWriteProbe,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProbeItem(
                    label: isArabic ? 'سلامة هياكل الجداول' : 'Table Structure Integrity',
                    status: p.databaseIntegrity == 'ok'
                        ? (isArabic ? 'سليم' : 'Healthy')
                        : (isArabic ? 'تلف محتمل' : 'Corrupted'),
                    detail: p.databaseIntegrity,
                    isOk: p.databaseIntegrity == 'ok',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProbeItem(
                    label: isArabic ? 'مساحة القرص الصلب المتبقية' : 'Remaining Disk Space',
                    status: '${p.freeDiskSpaceGb} GB',
                    detail: '${isArabic ? "حالة القرص:" : "Disk Status:"} ${p.diskStatus}',
                    isOk: p.diskStatus == 'OK',
                  ),
                ),
              ],
            ),
            if (p.issues.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                isArabic ? 'الملاحظات والتحذيرات المكتشفة:' : 'Detected Warnings & Issues:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.crimson,
                ),
              ),
              const SizedBox(height: 6),
              ...p.issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppTheme.crimson),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          issue,
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.crimson),
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

  Widget _buildProbeItem({
    required String label,
    required String status,
    required String detail,
    required bool isOk,
  }) {
    final color = isOk ? AppTheme.emerald : AppTheme.crimson;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const SizedBox(height: 2),
          Text(detail, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        ],
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
}
