import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../core/widgets/back_to_dashboard_button.dart';
import '../../core/widgets/buttons/app_button.dart';
import '../../core/widgets/copyable_data_helper.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_header.dart';
import 'logistics_exceptions_provider.dart';
import 'widgets/acid_impact_resolver_card.dart';
import 'widgets/exception_logger_dialog.dart';
import 'widgets/valuation_appeal_tracker.dart';

/// Coordinator Screen: Logistics Exceptions & Disruptions (Type C).
/// < 350 lines, Parallel UI Decomposition, Pure Arabic.
class LogisticsExceptionsScreen extends ConsumerStatefulWidget {
  const LogisticsExceptionsScreen({super.key});

  @override
  ConsumerState<LogisticsExceptionsScreen> createState() => _LogisticsExceptionsScreenState();
}

class _LogisticsExceptionsScreenState extends ConsumerState<LogisticsExceptionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openResolveDialog(BuildContext context, LogisticsExceptionModel exception) {
    final strategyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إغلاق وحل الاستثناء التشغيلي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('الاستثناء: ${exception.titleAr}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const Divider(height: 20),
                  TextField(
                    controller: strategyController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'خطة وإجراءات الحل المطبقة لإغلاق الحدث'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton(label: 'إلغاء', variant: AppButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop()),
                      const SizedBox(width: 8),
                      AppButton(
                        label: 'اعتماد الحل وإعادة المؤشرات',
                        variant: AppButtonVariant.primary,
                        onPressed: () async {
                          if (strategyController.text.trim().isEmpty) return;
                          await ref.read(logisticsExceptionsActionsProvider).resolveException(
                                exception.id,
                                strategyController.text.trim(),
                              );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<MetricCardData> _buildMetricCards(ExceptionMetricsModel m) {
    return [
      MetricCardData(
        title: 'إجمالي الاستثناءات',
        value: '${m.totalExceptions}',
        icon: Icons.alt_route_rounded,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: 'استثناءات حرجة قيد المتابعة',
        value: '${m.criticalExceptions}',
        icon: Icons.report_problem_rounded,
        color: AppTheme.crimson,
      ),
      MetricCardData(
        title: 'شحنات متأثرة بالقيد الجمركي',
        value: '${m.acidImpactedCount}',
        icon: Icons.calendar_month_rounded,
        color: AppTheme.orange,
      ),
      MetricCardData(
        title: 'مؤشرات تأخير معلقة',
        value: '${m.kpiSuspendedCount}',
        icon: Icons.pause_circle_filled_rounded,
        color: AppTheme.orange,
      ),
      MetricCardData(
        title: 'إجمالي مبالغ النزاع الجمركي',
        value: '${m.totalDisputeAmountEgp.toStringAsFixed(0)} ج.م',
        icon: Icons.monetization_on_rounded,
        color: AppTheme.emerald,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final exceptionsAsync = ref.watch(logisticsExceptionsProvider);
    final metricsAsync = ref.watch(exceptionMetricsProvider);
    final metrics = metricsAsync.value ?? ExceptionMetricsModel.empty;

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: PageHeader(
          title: 'إدارة الاستثناءات والاضطرابات اللوجستية',
          subtitle: 'تتبع أحداث الشحن الطارئة ومواءمة الصلاحيات وتعليق مؤشرات التأخير',
          icon: Icons.alt_route_rounded,
          actions: [
            AppButton(
              label: 'تحديث',
              icon: Icons.refresh,
              variant: AppButtonVariant.ghost,
              onPressed: () {
                ref.invalidate(logisticsExceptionsProvider);
                ref.invalidate(exceptionMetricsProvider);
              },
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'تسجيل استثناء جديد',
              icon: Icons.add_alert_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const ExceptionLoggerDialog(),
              ),
            ),
            const SizedBox(width: 8),
            const BackToDashboardButton(),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: MetricCardStrip(metrics: _buildMetricCards(metrics)),
            ),
            Container(
              color: AppTheme.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.cobalt,
                indicatorColor: AppTheme.cobalt,
                tabs: const [
                  Tab(icon: Icon(Icons.list_alt), text: 'سجل الاستثناءات النشطة'),
                  Tab(icon: Icon(Icons.security), text: 'مواءمة صلاحية القيد الجمركي المبدئي'),
                  Tab(icon: Icon(Icons.gavel), text: 'نزاعات التثمين والاستئناف الجمركي'),
                ],
              ),
            ),
            Expanded(
              child: exceptionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('حدث خطأ في جلب الاستثناءات: $e')),
                data: (items) => TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllExceptionsList(items),
                    _buildAcidResolversList(items.where((x) => x.acidNumber != null || x.delayImpactDays > 0).toList()),
                    _buildValuationAppealsList(items.where((x) => x.exceptionType == 'VALUATION_DISPUTE' || (x.valuationDisputeAmount != null && x.valuationDisputeAmount! > 0)).toList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllExceptionsList(List<LogisticsExceptionModel> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد استثناءات أو اضطرابات تشغيلية مسجلة حالياً'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  item.severity == 'CRITICAL' ? Icons.error_rounded : Icons.warning_amber_rounded,
                  color: item.severity == 'CRITICAL' ? AppTheme.crimson : AppTheme.orange,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(item.titleAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => CopyHelper.copy(ctx, item.exceptionCode),
                            child: Text(item.exceptionCode, style: const TextStyle(color: AppTheme.cobalt, fontSize: 12)),
                          ),
                          const Spacer(),
                          AppStatusBadge.fromStatus(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item.description ?? 'لا يوجد وصف تفصيلي', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        children: [
                          Text('الأثر الزمني: +${item.delayImpactDays} يوم', style: const TextStyle(fontSize: 11, color: AppTheme.crimson)),
                          if (item.delayKpiSuspended)
                            const Text('مؤشرات التأخير: معلقة تلقائياً', style: TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (item.status != 'RESOLVED' && item.status != 'CLOSED') ...[
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'حل وإغلاق',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _openResolveDialog(ctx, item),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAcidResolversList(List<LogisticsExceptionModel> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد شحنات تتطلب تمديد أو مواءمة القيد الجمركي المبدئي'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, idx) => AcidImpactResolverCard(exception: items[idx]),
    );
  }

  Widget _buildValuationAppealsList(List<LogisticsExceptionModel> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد نزاعات تثمين جمركي مسجلة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, idx) => ValuationAppealTracker(exception: items[idx]),
    );
  }
}
