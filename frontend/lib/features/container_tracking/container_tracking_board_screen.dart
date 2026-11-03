import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/page_header.dart';
import 'container_tracking_provider.dart';
import 'widgets/container_timeline_drawer.dart';
import 'widgets/container_tracker_table.dart';
import 'widgets/demurrage_per_container_card.dart';

/// Container Tracking Board Screen (Type C Coordinator)
/// Displays individual container lifecycle progression, milestone updates, and demurrage penalties.
class ContainerTrackingBoardScreen extends ConsumerStatefulWidget {
  final int shipmentId;

  const ContainerTrackingBoardScreen({
    super.key,
    this.shipmentId = 1,
  });

  @override
  ConsumerState<ContainerTrackingBoardScreen> createState() =>
      _ContainerTrackingBoardScreenState();
}

class _ContainerTrackingBoardScreenState
    extends ConsumerState<ContainerTrackingBoardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  ContainerUnitData? _selectedContainerForDrawer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(containerShipmentIdProvider.notifier).state = widget.shipmentId;
    });
  }

  void _showDemurrageDialog(ContainerUnitData container) {
    showDialog(
      context: context,
      builder: (ctx) => DemurragePerContainerCard(
        container: container,
        onRecalculate: () async {
          Navigator.of(ctx).pop();
          final repo = ref.read(containerTrackingRepositoryProvider);
          await repo.calculateDemurrage(container.id);
          ref.invalidate(containerTrackingListProvider);
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _openTimelineDrawer(ContainerUnitData container) {
    setState(() {
      _selectedContainerForDrawer = container;
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showAddContainerDialog() {
    final numController = TextEditingController();
    final sealController = TextEditingController();
    final weightController = TextEditingController();
    String isoType = '40HC';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة حاوية جديدة للشحنة', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numController,
                decoration: const InputDecoration(labelText: 'رقم الحاوية (مثال: MSKU1234567)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sealController,
                decoration: const InputDecoration(labelText: 'رقم الختم الجمركي'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: isoType,
                items: const [
                  DropdownMenuItem(value: '20GP', child: Text('حاوية 20 قدم عادية')),
                  DropdownMenuItem(value: '40GP', child: Text('حاوية 40 قدم عادية')),
                  DropdownMenuItem(value: '40HC', child: Text('حاوية 40 قدم عالية السقف')),
                  DropdownMenuItem(value: '45HC', child: Text('حاوية 45 قدم عالية السقف')),
                  DropdownMenuItem(value: '20RF', child: Text('حاوية 20 قدم مبردة')),
                  DropdownMenuItem(value: '40RF', child: Text('حاوية 40 قدم مبردة')),
                ],
                onChanged: (v) => isoType = v ?? '40HC',
                decoration: const InputDecoration(labelText: 'نوع ومقاس الحاوية'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الوزن القائم بالكيلوجرام'),
              ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: 'إلغاء',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AppButton(
            label: 'حفظ الحاوية',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              if (numController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              final repo = ref.read(containerTrackingRepositoryProvider);
              await repo.createContainer(widget.shipmentId, {
                'container_number': numController.text.trim().toUpperCase(),
                'seal_number': sealController.text.trim(),
                'iso_type': isoType,
                'gross_weight': double.tryParse(weightController.text.trim()),
                'initial_free_time_days': 14,
                'daily_demurrage_rate': 50.0,
              });
              ref.invalidate(containerTrackingListProvider);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(containerTrackingListProvider);

    return SelectionArea(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.surfaceAlt,
        appBar: PageHeader(
          icon: Icons.view_in_ar,
          iconColor: AppTheme.cobalt,
          title: 'لوحة تتبع دورة حياة الحاويات الفردية وغراماتها',
          subtitle: 'متابعة تفريغ الحاويات، الخروج تحت التحفظ، إرجاع الفارغ، واحتساب فترة السماح',
          actions: [
            AppButton(
              label: 'تحديث',
              icon: Icons.refresh,
              variant: AppButtonVariant.secondary,
              onPressed: () => ref.invalidate(containerTrackingListProvider),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'إضافة حاوية',
              icon: Icons.add,
              variant: AppButtonVariant.primary,
              onPressed: _showAddContainerDialog,
            ),
            const SizedBox(width: 12),
          ],
        ),
        endDrawer: _selectedContainerForDrawer != null
            ? Drawer(
                child: ContainerTimelineDrawer(
                  container: _selectedContainerForDrawer!,
                  onClose: () => Navigator.of(context).pop(),
                  onUpdateMilestone: (payload) async {
                    Navigator.of(context).pop();
                    final repo = ref.read(containerTrackingRepositoryProvider);
                    await repo.updateContainer(_selectedContainerForDrawer!.id, payload);
                    ref.invalidate(containerTrackingListProvider);
                  },
                ),
              )
            : null,
        body: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.crimson),
                const SizedBox(height: 12),
                Text('تعذر تحميل بيانات الحاويات: $err', style: const TextStyle(color: AppTheme.crimson)),
                const SizedBox(height: 12),
                AppButton(
                  label: 'إعادة المحاولة',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.primary,
                  onPressed: () => ref.invalidate(containerTrackingListProvider),
                ),
              ],
            ),
          ),
          data: (result) {
            final metrics = [
              MetricCardData(
                title: 'إجمالي الحاويات',
                value: '${result.total}',
                icon: Icons.inventory_2,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: 'على متن السفينة',
                value: '${result.onVesselCount}',
                icon: Icons.directions_boat,
                color: AppTheme.textSecondary,
              ),
              MetricCardData(
                title: 'تم التفريغ',
                value: '${result.dischargedCount}',
                icon: Icons.download,
                color: AppTheme.charcoal,
              ),
              MetricCardData(
                title: 'خروج تحت التحفظ',
                value: '${result.gateOutHeldCount}',
                icon: Icons.local_shipping,
                color: AppTheme.orange,
              ),
              MetricCardData(
                title: 'تم إرجاع الفارغ',
                value: '${result.returnedEmptyCount}',
                icon: Icons.check_circle,
                color: AppTheme.emerald,
              ),
              MetricCardData(
                title: 'إجمالي الغرامات',
                value: '${result.totalDemurrageAccrued.toStringAsFixed(0)} \$',
                icon: Icons.warning_amber,
                color: result.totalDemurrageAccrued > 0 ? AppTheme.crimson : AppTheme.emerald,
              ),
            ];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MetricCardStrip(metrics: metrics),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppTheme.border.withValues(alpha: 0.3)),
                      ),
                      child: ContainerTrackerTable(
                        containers: result.items,
                        onRefresh: () => ref.invalidate(containerTrackingListProvider),
                        onSelectTimeline: _openTimelineDrawer,
                        onSelectDemurrage: _showDemurrageDialog,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}
