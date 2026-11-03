import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/page_header.dart';
import 'multimodal_freight_provider.dart';
import 'widgets/air_freight_details_card.dart';
import 'widgets/lcl_consolidation_card.dart';
import 'widgets/roro_bulk_specs_card.dart';

/// Coordinator screen for Multimodal Freight (Type B List/Master Screen).
class MultimodalFreightScreen extends ConsumerStatefulWidget {
  final int shipmentId;

  const MultimodalFreightScreen({
    super.key,
    this.shipmentId = 1,
  });

  @override
  ConsumerState<MultimodalFreightScreen> createState() =>
      _MultimodalFreightScreenState();
}

class _MultimodalFreightScreenState
    extends ConsumerState<MultimodalFreightScreen> {
  int _selectedModeIndex = 0; // 0: AIR, 1: LCL, 2: RORO/BULK

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(multimodalShipmentIdProvider.notifier).state = widget.shipmentId;
    });
  }

  void _handleSave(Map<String, dynamic> payload) async {
    final repo = ref.read(multimodalFreightRepositoryProvider);
    await repo.createDetails(widget.shipmentId, payload);
    ref.invalidate(multimodalFreightListProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ مواصفات وسيط الشحن وتحديث التكاليف بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final freightAsync = ref.watch(multimodalFreightListProvider);

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: PageHeader(
          icon: Icons.alt_route,
          iconColor: AppTheme.cobalt,
          title: 'إدارة وسائط الشحن المتعدد (جوي، LCL، مدحرج، صب)',
          subtitle: 'ضبط مواصفات الشحن غير الحاوي وحساب رسوم المحطات والمناولة',
          actions: [
            AppButton(
              label: 'تحديث',
              icon: Icons.refresh,
              variant: AppButtonVariant.secondary,
              onPressed: () => ref.invalidate(multimodalFreightListProvider),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            MasterDataToolbarWidget(
              moduleEndpoint: '/api/v1/multimodal-freight/shipments/${widget.shipmentId}/freight-details',
              title: 'بيانات_وسائط_الشحن_المتعدد',
              onRefreshNeeded: () => ref.invalidate(multimodalFreightListProvider),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.flight_takeoff, size: 18),
                    label: const Text('الشحن الجوي ومناولة المطار'),
                    selected: _selectedModeIndex == 0,
                    onSelected: (sel) => setState(() => _selectedModeIndex = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('شحن الحاويات المشترك (LCL)'),
                    selected: _selectedModeIndex == 1,
                    onSelected: (sel) => setState(() => _selectedModeIndex = 1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.directions_car, size: 18),
                    label: const Text('السيارات المدحرجة والبضائع الصب'),
                    selected: _selectedModeIndex == 2,
                    onSelected: (sel) => setState(() => _selectedModeIndex = 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: freightAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('خطأ في تحميل بيانات الشحن: $err', style: const TextStyle(color: AppTheme.crimson)),
                ),
                data: (result) {
                  MultimodalFreightRecord? activeRecord;
                  if (_selectedModeIndex == 0) {
                    activeRecord = result.items.where((i) => i.transportMode == 'AIR').firstOrNull;
                  } else if (_selectedModeIndex == 1) {
                    activeRecord = result.items.where((i) => i.transportMode == 'LCL').firstOrNull;
                  } else {
                    activeRecord = result.items.where((i) => i.transportMode == 'RORO' || i.transportMode == 'BULK').firstOrNull;
                  }

                  Widget cardWidget;
                  if (_selectedModeIndex == 0) {
                    cardWidget = AirFreightDetailsCard(
                      record: activeRecord,
                      onSave: _handleSave,
                    );
                  } else if (_selectedModeIndex == 1) {
                    cardWidget = LclConsolidationCard(
                      record: activeRecord,
                      onSave: _handleSave,
                    );
                  } else {
                    cardWidget = RoroBulkSpecsCard(
                      record: activeRecord,
                      onSave: _handleSave,
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cardWidget,
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: AppTheme.border.withValues(alpha: 0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetric('شحنات جوية', '${result.airCount}'),
                                _buildMetric('شحنات مشتركة (LCL)', '${result.lclCount}'),
                                _buildMetric('شحنات مدحرجة (Ro-Ro)', '${result.roroCount}'),
                                _buildMetric('شحنات صب (Bulk)', '${result.bulkCount}'),
                                _buildMetric(
                                  'إجمالي التكاليف التقديرية',
                                  '${result.totalEstimatedCharges.toStringAsFixed(2)} دولار',
                                  isHighlight: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String title, String val, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.cobalt : AppTheme.charcoal,
          ),
        ),
      ],
    );
  }
}
