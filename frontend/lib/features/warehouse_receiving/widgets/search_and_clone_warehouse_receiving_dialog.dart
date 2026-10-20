import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/warehouse_receiving_model.dart';
import 'grn_record_card.dart';
import 'ops_ui_kit.dart';

/// Modal dialog that allows searching and selecting a previous Goods Receiving Note (GRN)
/// to clone into a new draft following the 5-Task Enterprise Protocol.
class SearchAndCloneWarehouseReceivingDialog extends ConsumerStatefulWidget {
  final List<WarehouseReceivingModel> records;
  final ValueChanged<WarehouseReceivingModel> onSelectRecord;

  const SearchAndCloneWarehouseReceivingDialog({
    super.key,
    required this.records,
    required this.onSelectRecord,
  });

  @override
  ConsumerState<SearchAndCloneWarehouseReceivingDialog> createState() =>
      _SearchAndCloneWarehouseReceivingDialogState();
}

class _SearchAndCloneWarehouseReceivingDialogState
    extends ConsumerState<SearchAndCloneWarehouseReceivingDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  String _quarantineFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = (screenWidth - 32).clamp(360.0, 920.0);
    final dialogHeight = (screenHeight * 0.82).clamp(420.0, 780.0);
    final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final query = _searchController.text.trim().toLowerCase();
    final filteredRecords = widget.records.where((rec) {
      if (_statusFilter != 'All' && rec.status != _statusFilter) {
        return false;
      }
      if (_quarantineFilter == 'Quarantine Only' && !rec.quarantineZoneAssigned) {
        return false;
      }
      if (_quarantineFilter == 'Standard Only' && rec.quarantineZoneAssigned) {
        return false;
      }
      if (query.isEmpty) return true;

      final grnCodeMatch = rec.grnCode.toLowerCase().contains(query);
      final whMatch = rec.warehouseName.toLowerCase().contains(query);
      final driverMatch = (rec.driverName ?? '').toLowerCase().contains(query);
      final plateMatch = (rec.truckPlateNumber ?? '').toLowerCase().contains(query);
      final sealMatch = (rec.sealNumber ?? '').toLowerCase().contains(query);
      final inspectorMatch = rec.inspectorName.toLowerCase().contains(query);
      final fileCodeMatch = 'imp-${rec.importFileId}'.contains(query);

      return grnCodeMatch ||
          whMatch ||
          driverMatch ||
          plateMatch ||
          sealMatch ||
          inspectorMatch ||
          fileCodeMatch;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      backgroundColor: AppTheme.surfaceOf(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SelectionArea(
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          padding: const EdgeInsetsDirectional.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OpsSectionHeader(
              title: l.cloneWarehouseReceivingDialogTitle,
              subtitle: l.cloneWarehouseReceivingDialogSubtitle,
              icon: Icons.inventory_outlined,
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.warehouseReceivingSearchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, val, _) {
                    return val.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : const SizedBox.shrink();
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterChip('All', l.warehouseReceivingStatusAll, _statusFilter, (v) {
                  setState(() => _statusFilter = v);
                }),
                _buildFilterChip('Draft / Pending Warehouse Count', l.warehouseReceivingStatusDraft, _statusFilter, (v) {
                  setState(() => _statusFilter = v);
                }),
                _buildFilterChip('Goods Received', l.warehouseReceivingStatusGoodsReceived, _statusFilter, (v) {
                  setState(() => _statusFilter = v);
                }),
                _buildFilterChip('Discrepancy Reported', l.warehouseReceivingStatusDiscrepancy, _statusFilter, (v) {
                  setState(() => _statusFilter = v);
                }),
                const SizedBox(width: 8),
                _buildFilterChip('All', l.warehouseReceivingStatusAll, _quarantineFilter, (v) {
                  setState(() => _quarantineFilter = v);
                }, isSecondary: true),
                _buildFilterChip('Quarantine Only', l.wrFilterQuarantineOnly, _quarantineFilter, (v) {
                  setState(() => _quarantineFilter = v);
                }, isSecondary: true),
              ],
            ),
            Divider(height: 20, color: AppTheme.borderOf(context)),
            Expanded(
              child: filteredRecords.isEmpty
                  ? OpsStateView.empty(
                      compact: true,
                      icon: Icons.search_off,
                      message: l.warehouseReceivingEmptyRecords,
                    )
                  : ListView.separated(
                      itemCount: filteredRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final rec = filteredRecords[idx];
                        final rawFileCode = 'IMP-${rec.importFileId}';
                        final matchedFile = allFiles.where((f) => f.importFileId == rec.importFileId).firstOrNull;
                        final displayFileName = matchedFile?.primaryNameWithCode ?? rawFileCode;
                        final status = GrnStatusView.of(l, rec.status);
                        final hasVariance = rec.totalShortageQty > 0 || rec.totalDamagedQty > 0;

                        return Container(
                          padding: const EdgeInsetsDirectional.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAltOf(context),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.borderOf(context)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                          ),
                                          child: CopyableText(
                                            rec.grnCode,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.cobalt),
                                          ),
                                        ),
                                        OpsStatusChip(label: status.label, severity: status.severity, icon: status.icon, dense: true),
                                        if (rec.quarantineZoneAssigned)
                                          OpsStatusChip(
                                            label: l.wrQuarantineZoneBadge,
                                            severity: AppSeverity.danger,
                                            icon: Icons.warning_amber_rounded,
                                            dense: true,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 14,
                                      runSpacing: 4,
                                      children: [
                                        _meta(context, Icons.warehouse_outlined, rec.warehouseName, strong: true),
                                        _meta(context, Icons.folder_open_outlined, displayFileName),
                                        if (rec.driverName != null && rec.driverName!.isNotEmpty)
                                          _meta(context, Icons.local_shipping_outlined, '${rec.driverName} (${rec.truckPlateNumber ?? "-"})'),
                                        _meta(
                                          context,
                                          Icons.fact_check_outlined,
                                          l.wrCloneRecordSummary(rec.totalAcceptedQty, rec.totalShortageQty, rec.totalDamagedQty),
                                          color: hasVariance ? AppTheme.crimson : AppTheme.emerald,
                                          strong: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                key: Key('selectRecordToCloneBtn_${rec.grnCode}'),
                                label: l.cloneWarehouseReceivingTooltip,
                                icon: Icons.difference_outlined,
                                size: AppButtonSize.small,
                                onPressed: () => widget.onSelectRecord(rec),
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
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text, {Color? color, bool strong = false}) {
    final c = color ?? AppTheme.textSecondaryOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: color ?? (strong ? AppTheme.textPrimaryOf(context) : AppTheme.textSecondaryOf(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String value,
    String label,
    String selectedValue,
    ValueChanged<String> onSelected, {
    bool isSecondary = false,
  }) {
    final isSelected = selectedValue == value;
    final activeColor = isSecondary ? AppTheme.orange : AppTheme.cobalt;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: activeColor.withOpacity(0.2),
      backgroundColor: AppTheme.surfaceAltOf(context),
      side: BorderSide(color: isSelected ? activeColor : AppTheme.borderOf(context)),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? activeColor : AppTheme.textSecondaryOf(context),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 2),
    );
  }
}
