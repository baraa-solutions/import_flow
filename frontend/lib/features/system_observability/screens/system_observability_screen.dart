import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/performance/client_diagnostics_service.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/system_observability_provider.dart';
import '../widgets/observability_metric_strip.dart';
import '../widgets/system_health_table.dart';
import '../widgets/system_logs_tab.dart';

class SystemObservabilityScreen extends ConsumerStatefulWidget {
  const SystemObservabilityScreen({super.key});

  @override
  ConsumerState<SystemObservabilityScreen> createState() =>
      _SystemObservabilityScreenState();
}

class _SystemObservabilityScreenState
    extends ConsumerState<SystemObservabilityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _autoRefreshTimer;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _toggleAutoRefresh(bool enable) {
    ref.read(autoRefreshObservabilityProvider.notifier).state = enable;
    _autoRefreshTimer?.cancel();
    if (enable) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _refreshAllData();
      });
    }
  }

  void _refreshAllData() {
    ref.invalidate(systemMetricsProvider);
    ref.invalidate(databaseHealthProvider);
    ref.invalidate(domainRadarProvider);
    ref.invalidate(recentTrafficProvider);
  }

  Future<void> _exportDiagnosticsBundle() async {
    setState(() => _isExporting = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get<List<int>>(
        '/system/observability/export-bundle',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null && mounted) {
        await FileSaveHelper.exportAndSaveFile(
          context: context,
          bytes: response.data!,
          stageName: 'System Diagnostics',
          importFileNameOrCode: 'Health Bundle',
          extension: 'zip',
          customDialogTitle: 'Save System Diagnostics Bundle',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'Failed to export bundle: ${ApiError.message(e)}',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportClientLogs() async {
    final logText = ClientDiagnosticsService.instance.exportLogText();
    final bytes = logText.codeUnits;
    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: bytes,
      stageName: 'Desktop Client',
      importFileNameOrCode: 'Telemetry Log',
      extension: 'log',
      customDialogTitle: 'Save Desktop Telemetry Log',
    );
  }

  Future<void> _sendTestAlert() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/system/observability/alerts/test-trigger',
        queryParameters: {'channel': 'TOAST'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'تم إرسال إشعار اختباري بنجاح إلى نظام ويندوز!',
            severity: AppSeverity.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'فشل إرسال الإشعار الاختباري: ${ApiError.message(e)}',
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

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
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(systemMetricsProvider);
    final isAutoRefresh = ref.watch(autoRefreshObservabilityProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SelectionArea(
        child: Column(
          children: [
            // ── Compact Header & Toolbar ──────────────────────────────────────
            Container(
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
                    child: const Icon(Icons.monitor_heart_outlined,
                        color: AppTheme.cobalt, size: 20),
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
                  // Canonical System Status Badge
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
                  // Auto-refresh Toggle Switch
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
                        onChanged: _toggleAutoRefresh,
                        activeThumbColor: AppTheme.cobalt,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Refresh Button
                  OutlinedButton.icon(
                    onPressed: _refreshAllData,
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: Text(isArabic ? 'تحديث الآن' : 'Refresh Now', style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Test Toast Alert Button
                  OutlinedButton.icon(
                    onPressed: _sendTestAlert,
                    icon: const Icon(Icons.notifications_active_outlined, size: 15, color: AppTheme.orange),
                    label: Text(isArabic ? 'اختبار التنبيه' : 'Test Alert', style: const TextStyle(fontSize: 12, color: AppTheme.charcoal)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export Diagnostics Button
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportDiagnosticsBundle,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: AppLoadingState.inline(),
                          )
                        : const Icon(Icons.archive_outlined, size: 15),
                    label: Text(isArabic ? 'تصدير حزمة الدعم' : 'Export Diagnostics',
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.charcoal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ),

            // ── Tabs Bar ────────────────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.cobalt,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: AppTheme.cobalt,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(icon: const Icon(Icons.speed_rounded, size: 17), text: isArabic ? 'المؤشرات الحيوية والأداء' : 'Vital Metrics & Performance'),
                  Tab(icon: const Icon(Icons.radar_rounded, size: 17), text: isArabic ? 'رادار العمليات اللوجستية' : 'Operations Radar'),
                  Tab(icon: const Icon(Icons.alt_route_rounded, size: 17), text: isArabic ? 'سجل المرور والاستعلامات' : 'Traffic Telemetry & Queries'),
                  Tab(icon: const Icon(Icons.health_and_safety_outlined, size: 17), text: isArabic ? 'الفحص العميق وحزم الدعم' : 'Deep Health & Diagnostics'),
                ],
              ),
            ),

            // ── Tab Views ───────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLivePulseTab(),
                  _buildDomainRadarTab(),
                  SystemLogsTab(onExportClientLogs: _exportClientLogs),
                  _buildDeepHealthTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: LIVE PULSE & GAUGES
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildLivePulseTab() {
    final metricsAsync = ref.watch(systemMetricsProvider);
    final dbHealthAsync = ref.watch(databaseHealthProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return metricsAsync.when(
      data: (metrics) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modularized Canonical Metric Strip
              ObservabilityMetricStrip(
                metrics: metrics,
                dbHealth: dbHealthAsync.valueOrNull,
                isArabic: isArabic,
              ),
              const SizedBox(height: 16),

              // Traffic Distribution & Top Endpoints Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Traffic status codes card
                  SizedBox(
                    width: 320,
                    child: Card(
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
                              isArabic ? 'توزيع رموز الاستجابة' : 'Status Codes Distribution',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 14),
                            _buildTrafficRow(isArabic ? '2xx / 3xx - طلبات ناجحة' : '2xx / 3xx - Success', metrics.status2xx, AppTheme.emerald),
                            const Divider(height: 16),
                            _buildTrafficRow(isArabic ? '4xx - أخطاء العميل' : '4xx - Client Errors', metrics.status4xx, AppTheme.orange),
                            const Divider(height: 16),
                            _buildTrafficRow(isArabic ? '5xx - أخطاء الخادم' : '5xx - Server Errors', metrics.status5xx, AppTheme.crimson),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(isArabic ? 'إجمالي الأخطاء:' : 'Total Errors:', style: const TextStyle(fontSize: 11)),
                                  Text(
                                    '${metrics.totalErrors} (${metrics.totalRequests > 0 ? ((metrics.totalErrors / metrics.totalRequests) * 100).toStringAsFixed(1) : 0}%)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Top active endpoints via SystemHealthTable component
                  Expanded(
                    child: SystemHealthTable(
                      topEndpoints: metrics.topEndpoints,
                      isArabic: isArabic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const AppLoadingState(),
      error: (e, _) => Center(child: Text('خطأ في تحميل مؤشرات الأداء: $e')),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: DOMAIN LOGISTICS RADAR
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDomainRadarTab() {
    final radarAsync = ref.watch(domainRadarProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return radarAsync.when(
      data: (radar) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3 Domain Risk Cards
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

              // Automated Backup Status
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
              // Expiring ACIDs Detail List
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

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 4: DEEP HEALTH CHECK & DIAGNOSTICS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDeepHealthTab() {
    final deepHealthAsync = ref.watch(deepHealthProbeProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Banner to trigger Deep Probe
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

          // Deep Health Probe Result Display via SystemHealthTable component
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

          // Client Log Export Card
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
                    onPressed: _exportClientLogs,
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

  // ════════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════════════════
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

  Widget _buildTrafficRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11.5)),
          ],
        ),
        Text(
          '$count',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
        ),
      ],
    );
  }
}
