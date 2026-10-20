import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/performance/client_diagnostics_service.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/system_observability_provider.dart';

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
          SnackBar(
            content: Text('Failed to export bundle: ${ApiError.message(e)}'),
            backgroundColor: AppTheme.crimson,
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
          const SnackBar(
            content: Text('تم إرسال إشعار اختباري بنجاح إلى نظام ويندوز!'),
            backgroundColor: AppTheme.emerald,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الإشعار الاختباري: ${ApiError.message(e)}'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    }
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
            // ── Compact Header & Toolbar (Unified Header Rule) ──────────────────
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
                  // Overall System Status Badge
                  metricsAsync.when(
                    data: (m) => _buildStatusBadge(m.status, isArabic),
                    loading: () => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => _buildStatusBadge('OFFLINE', isArabic),
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
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
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
                _buildTrafficTelemetryTab(),
                _buildDeepHealthTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildStatusBadge(String status, [bool isArabic = true]) {
    Color bg;
    Color fg;
    String label;

    switch (status.toUpperCase()) {
      case 'HEALTHY':
        bg = AppTheme.emerald.withValues(alpha: 0.15);
        fg = AppTheme.emerald;
        label = isArabic ? '🟢 مستقر وطبيعي' : '🟢 Healthy';
        break;
      case 'DEGRADED':
        bg = AppTheme.orange.withValues(alpha: 0.15);
        fg = AppTheme.orange;
        label = isArabic ? '🟡 استجابة متدهورة' : '🟡 Degraded';
        break;
      case 'CRITICAL':
      case 'OFFLINE':
      default:
        bg = AppTheme.crimson.withValues(alpha: 0.15);
        fg = AppTheme.crimson;
        label = isArabic ? '🔴 تحذير حرج' : '🔴 Critical';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11.5),
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
              // 4 Core KPI Cards
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: isArabic ? 'خادم النظام والذاكرة' : 'Server & Memory',
                      value: '${metrics.processMemoryMb} MB',
                      subtitle: 'Uptime: ${metrics.uptimeHuman} • Port: ${ApiConstants.serverPort}',
                      icon: Icons.memory_rounded,
                      color: AppTheme.cobalt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: dbHealthAsync.when(
                      data: (dbh) => _buildKpiCard(
                        title: isArabic ? 'محرك قاعدة البيانات' : 'SQLite WAL Engine',
                        value: '${dbh.databaseSizeMb} MB',
                        subtitle: 'WAL: ${dbh.walSizeMb} MB • Timeout: ${dbh.busyTimeoutMs}ms',
                        icon: Icons.storage_rounded,
                        color: AppTheme.charcoal,
                      ),
                      loading: () => _buildLoadingKpiCard(isArabic ? 'جلب بيانات DB...' : 'Loading DB metrics...'),
                      error: (_, __) => _buildKpiCard(
                        title: isArabic ? 'قاعدة البيانات' : 'Database',
                        value: isArabic ? 'خطأ اتصال' : 'Connection Error',
                        subtitle: isArabic ? 'تعذر الاتصال' : 'Unavailable',
                        icon: Icons.storage_rounded,
                        color: AppTheme.crimson,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: isArabic ? 'معدل الطلبات والتزامن' : 'Request Throughput',
                      value: '${metrics.requestsPerSecond} req/s',
                      subtitle: 'Total requests: ${metrics.totalRequests}',
                      icon: Icons.bolt_rounded,
                      color: AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: isArabic ? 'أزمنة الاستجابة' : 'Response Latencies',
                      value: 'P50: ${metrics.p50LatencyMs} ms',
                      subtitle: 'P95: ${metrics.p95LatencyMs} ms • P99: ${metrics.p99LatencyMs} ms',
                      icon: Icons.timer_outlined,
                      color: AppTheme.orange,
                    ),
                  ),
                ],
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

                  // Top active endpoints
                  Expanded(
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
                              isArabic ? 'أكثر نقاط النهاية استخداماً' : 'Top Active Endpoints',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.charcoal),
                            ),
                            const SizedBox(height: 10),
                            if (metrics.topEndpoints.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('لا توجد طلبات مسجلة بعد')),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: metrics.topEndpoints.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final ep = metrics.topEndpoints[index];
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
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${ep.count} reqs',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700)),
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
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (radar.lastBackupStatus == 'HEALTHY'
                                  ? AppTheme.emerald
                                  : AppTheme.crimson)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          radar.lastBackupStatus,
                          style: TextStyle(
                            color: radar.lastBackupStatus == 'HEALTHY'
                                ? AppTheme.emerald
                                : AppTheme.crimson,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
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
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? AppTheme.crimson.withValues(alpha: 0.15)
                                : AppTheme.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isExpired ? 'EXPIRED' : 'URGENT',
                            style: TextStyle(
                              color: isExpired ? AppTheme.crimson : AppTheme.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ في جلب بيانات الرادار: $e')),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3: TRAFFIC TELEMETRY & SLOW QUERIES
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildTrafficTelemetryTab() {
    final trafficAsync = ref.watch(recentTrafficProvider);
    final dbHealthAsync = ref.watch(databaseHealthProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return SingleChildScrollView(
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
                          isArabic ? 'لا توجد استعلامات بطيئة مسجلة (أقل من 150 مللي ثانية)' : 'No slow queries recorded (< 150ms)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...dbh.recentSlowQueries.map((sq) => Padding(
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
                                  Text('${sq.durationMs} ms',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.crimson,
                                          fontSize: 11)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sq.statement,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5),
                                    ),
                                  ),
                                  Text(sq.timestamp,
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          )),
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
                    isArabic ? 'سجل حركة المرور المباشر مع معرّف التتبع' : 'Recent Traffic & Correlation IDs',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 10),
                  trafficAsync.when(
                    data: (traffic) {
                      if (traffic.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text(isArabic ? 'لا توجد طلبات مسجلة' : 'No recorded requests')),
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
                                  child: SelectableText(
                                    item.requestId,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      color: Colors.grey.shade800,
                                    ),
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
                    error: (e, _) => Center(child: Text(isArabic ? 'خطأ في جلب سجل المرور: $e' : 'Error fetching traffic logs: $e')),
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

          // Deep Health Probe Result Display
          deepHealthAsync.when(
            data: (probe) {
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

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: probe.verdict == 'HEALTHY'
                        ? AppTheme.emerald
                        : (probe.verdict == 'DEGRADED' ? AppTheme.orange : AppTheme.crimson),
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
                              _buildStatusBadge(probe.verdict, isArabic),
                              const SizedBox(width: 10),
                              Text('${isArabic ? 'وقت الفحص:' : 'Probe Time:'} ${probe.timestamp}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
                              status: probe.databaseWriteProbe ? (isArabic ? 'ناجح' : 'PASS') : (isArabic ? 'فشل' : 'FAIL'),
                              detail: '${isArabic ? 'زمن تنفيذ الكتابة:' : 'Write Latency:'} ${probe.databaseWriteLatencyMs} ms',
                              isOk: probe.databaseWriteProbe,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildProbeItem(
                              label: isArabic ? 'سلامة هياكل الجداول' : 'Table Structure Integrity',
                              status: probe.databaseIntegrity == 'ok' ? (isArabic ? 'سليم' : 'Healthy') : (isArabic ? 'تلف محتمل' : 'Corrupted'),
                              detail: probe.databaseIntegrity,
                              isOk: probe.databaseIntegrity == 'ok',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildProbeItem(
                              label: isArabic ? 'مساحة القرص الصلب المتبقية' : 'Remaining Disk Space',
                              status: '${probe.freeDiskSpaceGb} GB',
                              detail: '${isArabic ? 'حالة القرص:' : 'Disk Status:'} ${probe.diskStatus}',
                              isOk: probe.diskStatus == 'OK',
                            ),
                          ),
                        ],
                      ),
                      if (probe.issues.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          isArabic ? 'الملاحظات والتحذيرات المكتشفة:' : 'Detected Warnings & Issues:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.crimson),
                        ),
                        const SizedBox(height: 6),
                        ...probe.issues.map((issue) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle, size: 6, color: AppTheme.crimson),
                                  const SizedBox(width: 6),
                                  Text(issue, style: const TextStyle(fontSize: 11.5, color: AppTheme.crimson)),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              );
            },
            loading: () => Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 10),
                      Text(isArabic ? 'جارٍ تنفيذ الفحص العميق لقاعدة البيانات...' : 'Executing deep database probe...'),
                    ],
                  ),
                ),
              ),
            ),
            error: (e, _) => Center(child: Text(isArabic ? 'خطأ في الفحص العميق: $e' : 'Deep probe error: $e')),
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
  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingKpiCard(String label) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      ),
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
