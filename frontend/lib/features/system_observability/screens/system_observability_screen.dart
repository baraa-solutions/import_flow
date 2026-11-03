import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/performance/client_diagnostics_service.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/system_observability_provider.dart';
import '../widgets/deep_health_tab.dart';
import '../widgets/domain_radar_tab.dart';
import '../widgets/live_pulse_tab.dart';
import '../widgets/observability_header_toolbar.dart';
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

  @override
  Widget build(BuildContext context) {
    final isAutoRefresh = ref.watch(autoRefreshObservabilityProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SelectionArea(
        child: Column(
          children: [
            ObservabilityHeaderToolbar(
              isArabic: isArabic,
              isAutoRefresh: isAutoRefresh,
              onToggleAutoRefresh: _toggleAutoRefresh,
              onRefreshAllData: _refreshAllData,
              onSendTestAlert: _sendTestAlert,
              onExportDiagnostics: _exportDiagnosticsBundle,
              isExporting: _isExporting,
            ),
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
                  Tab(
                    icon: const Icon(Icons.speed_rounded, size: 17),
                    text: isArabic ? 'المؤشرات الحيوية والأداء' : 'Vital Metrics & Performance',
                  ),
                  Tab(
                    icon: const Icon(Icons.radar_rounded, size: 17),
                    text: isArabic ? 'رادار العمليات اللوجستية' : 'Operations Radar',
                  ),
                  Tab(
                    icon: const Icon(Icons.alt_route_rounded, size: 17),
                    text: isArabic ? 'سجل المرور والاستعلامات' : 'Traffic Telemetry & Queries',
                  ),
                  Tab(
                    icon: const Icon(Icons.health_and_safety_outlined, size: 17),
                    text: isArabic ? 'الفحص العميق وحزم الدعم' : 'Deep Health & Diagnostics',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  LivePulseTab(isArabic: isArabic),
                  DomainRadarTab(isArabic: isArabic),
                  SystemLogsTab(onExportClientLogs: _exportClientLogs),
                  DeepHealthTab(
                    isArabic: isArabic,
                    onExportClientLogs: _exportClientLogs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
