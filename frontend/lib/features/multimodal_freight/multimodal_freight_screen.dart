import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/import_file_scope_selector.dart';
import '../../../core/widgets/master_data_toolbar.dart';
import '../../../core/widgets/page_header.dart';
import '../air_freight/widgets/air_freight_panel.dart';
import 'multimodal_freight_provider.dart';
import 'widgets/air_freight_details_card.dart';
import 'widgets/lcl_consolidation_card.dart';
import 'widgets/roro_bulk_specs_card.dart';

/// Coordinator screen for Multimodal Freight (Type B List/Master Screen).
class MultimodalFreightScreen extends ConsumerStatefulWidget {
  /// Import file to open on; null shows the file picker's empty state.
  final int? shipmentId;

  const MultimodalFreightScreen({super.key, this.shipmentId});

  @override
  ConsumerState<MultimodalFreightScreen> createState() => _MultimodalFreightScreenState();
}

class _MultimodalFreightScreenState extends ConsumerState<MultimodalFreightScreen> {
  int _selectedModeIndex = 0; // 0: AIR (AWB records & review), 1: LCL, 2: RORO/BULK, 3: AIR handling charges

  late int? _fileId = widget.shipmentId;

  void _handleSave(Map<String, dynamic> payload) async {
    final fileId = _fileId;
    if (fileId == null) return;
    try {
      await ref.read(multimodalFreightRepositoryProvider).createDetails(fileId, payload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiErrorText.of(context.l10n, e)), backgroundColor: AppTheme.crimson));
      }
      return;
    }
    ref.invalidate(multimodalFreightListProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ مواصفات وسيط الشحن وتحديث التكاليف بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileId = _fileId;

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
              onPressed: fileId == null ? null : () => ref.invalidate(multimodalFreightListProvider),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            ImportFileScopeSelector(selectedImportFileId: fileId, onChanged: (id) => setState(() => _fileId = id)),
            if (fileId == null)
              const Expanded(child: ImportFileRequiredState())
            else ...[
              MasterDataToolbarWidget(
                moduleEndpoint: '/api/v1/multimodal-freight/shipments/$fileId/freight-details',
                title: 'بيانات_وسائط_الشحن_المتعدد',
                onRefreshNeeded: () => ref.invalidate(multimodalFreightListProvider),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.flight_takeoff, size: 18),
                      label: const Text('الشحن الجوي وبوالص AWB'),
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
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.local_airport, size: 18),
                      label: const Text('رسوم مناولة المطار'),
                      selected: _selectedModeIndex == 3,
                      onSelected: (sel) => setState(() => _selectedModeIndex = 3),
                    ),
                  ],
                ),
              ),
              if (_selectedModeIndex == 0)
                Expanded(
                  child: AirFreightPanel(key: ValueKey('air_freight_panel_$fileId'), importFileId: fileId),
                )
              else
                Expanded(
                  child: ref
                      .watch(multimodalFreightListProvider(fileId))
                      .when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(
                          child: Text(
                            ApiErrorText.of(context.l10n, err),
                            style: const TextStyle(color: AppTheme.crimson),
                          ),
                        ),
                        data: (result) {
                          MultimodalFreightRecord? activeRecord;
                          if (_selectedModeIndex == 3) {
                            activeRecord = result.items.where((i) => i.transportMode == 'AIR').firstOrNull;
                          } else if (_selectedModeIndex == 1) {
                            activeRecord = result.items.where((i) => i.transportMode == 'LCL').firstOrNull;
                          } else {
                            activeRecord = result.items
                                .where((i) => i.transportMode == 'RORO' || i.transportMode == 'BULK')
                                .firstOrNull;
                          }

                          Widget cardWidget;
                          if (_selectedModeIndex == 3) {
                            cardWidget = AirFreightDetailsCard(record: activeRecord, onSave: _handleSave);
                          } else if (_selectedModeIndex == 1) {
                            cardWidget = LclConsolidationCard(record: activeRecord, onSave: _handleSave);
                          } else {
                            cardWidget = RoroBulkSpecsCard(record: activeRecord, onSave: _handleSave);
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
