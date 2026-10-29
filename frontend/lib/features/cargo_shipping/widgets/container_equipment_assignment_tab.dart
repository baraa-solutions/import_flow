import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../freight_booking/models/freight_booking_model.dart';
import '../models/cargo_shipping_model.dart';

/// Helper to retrieve localized labels for standard container types.
String getLocalizedContainerTypeLabel(BuildContext context, String type) {
  final l = context.l10n;
  switch (type) {
    case '20GP':
    case '40GP':
      return '$type - ${l.cshDryContainer}';
    case '40HC':
      return '$type - ${l.cshHighCubeContainer}';
    case '45HC':
      return '$type - ${l.cshSuperHighCubeContainer}';
    case '20RF':
    case '40RF':
      return '$type - ${l.cshReeferContainer}';
    default:
      return type;
  }
}

/// Individual container equipment card for FCL assignment step.
class ContainerEquipmentCard extends StatelessWidget {
  final ContainerLoadingModel item;
  final int index;
  final int totalContainersCount;
  final ShipmentBookingModel? linkedBooking;
  final int totalBookingContainersCount;
  final int totalRegisteredContainersCount;
  final void Function(int index) onDuplicate;
  final void Function(int index) onDelete;
  final void Function(int index, ContainerLoadingModel updated) onUpdate;

  const ContainerEquipmentCard({
    super.key,
    required this.item,
    required this.index,
    required this.totalContainersCount,
    this.linkedBooking,
    required this.totalBookingContainersCount,
    required this.totalRegisteredContainersCount,
    required this.onDuplicate,
    required this.onDelete,
    required this.onUpdate,
  });

  bool get _isBookingLimitReached =>
      linkedBooking != null &&
      totalBookingContainersCount > 0 &&
      totalRegisteredContainersCount >= totalBookingContainersCount;

  @override
  Widget build(BuildContext context) {
    final qty = item.quantity;
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  value: item.containerType,
                  labelText: l.cargoShippingContainerType,
                  items: [
                    SearchableDropdownItem(value: '20GP', label: getLocalizedContainerTypeLabel(context, '20GP')),
                    SearchableDropdownItem(value: '40GP', label: getLocalizedContainerTypeLabel(context, '40GP')),
                    SearchableDropdownItem(value: '40HC', label: getLocalizedContainerTypeLabel(context, '40HC')),
                    SearchableDropdownItem(value: '45HC', label: getLocalizedContainerTypeLabel(context, '45HC')),
                    SearchableDropdownItem(value: '20RF', label: getLocalizedContainerTypeLabel(context, '20RF')),
                    SearchableDropdownItem(value: '40RF', label: getLocalizedContainerTypeLabel(context, '40RF')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      onUpdate(index, item.copyWith(containerType: val));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.cargoShippingQty,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final q = int.tryParse(val) ?? 1;
                    final units = item.individualUnits.map((u) => Map<String, String>.from(u)).toList();
                    while (units.length < q) {
                      units.add({'container_no': '', 'seal_no': ''});
                    }
                    if (units.length > q) units.removeRange(q, units.length);
                    onUpdate(
                      index,
                      item.copyWith(
                        quantity: q,
                        containerNo: units.isNotEmpty ? units.first['container_no'] ?? '' : '',
                        sealNo: units.isNotEmpty ? units.first['seal_no'] ?? '' : '',
                        individualUnits: units,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: item.grossWeightKg.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.cargoShippingVgmWeight,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: l.cargoShippingCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, item.grossWeightKg.toStringAsFixed(0)),
                    ),
                  ),
                  onChanged: (val) {
                    final w = double.tryParse(val) ?? 0.0;
                    onUpdate(index, item.copyWith(grossWeightKg: w));
                  },
                ),
              ),
              const SizedBox(width: 6),
              RowActionsPill(
                cloneKey: Key('duplicateContainerBtn_$index'),
                cloneTooltip: _isBookingLimitReached
                    ? l.cargoShippingBookingLimitReached
                    : l.cargoShippingDuplicateContainerTooltip,
                onClone: _isBookingLimitReached ? null : () => onDuplicate(index),
                deleteTooltip: totalContainersCount > 1 ? l.delete : null,
                onDelete: totalContainersCount > 1 ? () => onDelete(index) : null,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Per-Unit Container No & Seal No Fields
          Text(
            l.cargoShippingUnitDetailsHeader,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 6),
          ...List.generate(qty, (unitIdx) {
            final units = item.individualUnits;
            final curCNo = unitIdx < units.length ? (units[unitIdx]['container_no'] ?? '') : item.containerNo;
            final curSNo = unitIdx < units.length ? (units[unitIdx]['seal_no'] ?? '') : item.sealNo;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    l.cargoShippingUnitPrefix(unitIdx + 1),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: curCNo,
                      decoration: InputDecoration(
                        labelText: l.cargoShippingContainerNo,
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: l.cargoShippingCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, curCNo),
                        ),
                      ),
                      onChanged: (cVal) {
                        final updatedUnits = item.individualUnits.map((u) => Map<String, String>.from(u)).toList();
                        while (updatedUnits.length <= unitIdx) {
                          updatedUnits.add({'container_no': '', 'seal_no': ''});
                        }
                        updatedUnits[unitIdx]['container_no'] = cVal;
                        onUpdate(
                          index,
                          item.copyWith(
                            containerNo: updatedUnits.first['container_no'] ?? '',
                            sealNo: updatedUnits.first['seal_no'] ?? '',
                            individualUnits: updatedUnits,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: curSNo,
                      decoration: InputDecoration(
                        labelText: l.cargoShippingSealNo,
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: l.cargoShippingCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, curSNo),
                        ),
                      ),
                      onChanged: (sVal) {
                        final updatedUnits = item.individualUnits.map((u) => Map<String, String>.from(u)).toList();
                        while (updatedUnits.length <= unitIdx) {
                          updatedUnits.add({'container_no': '', 'seal_no': ''});
                        }
                        updatedUnits[unitIdx]['seal_no'] = sVal;
                        onUpdate(
                          index,
                          item.copyWith(
                            containerNo: updatedUnits.first['container_no'] ?? '',
                            sealNo: updatedUnits.first['seal_no'] ?? '',
                            individualUnits: updatedUnits,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Step 1: Container & Equipment Assignment Tab view.
class ContainerEquipmentAssignmentTab extends StatelessWidget {
  final List<dynamic> importFiles;
  final Set<int?> existingActiveFileIds;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileSelected;
  final String shipmentType;
  final ValueChanged<String> onShipmentTypeChanged;
  final bool isStackable;
  final ValueChanged<bool> onStackableChanged;
  final ContainerRecommendationResult? activeContainerRec;
  final double totalCargoCbm;
  final double totalCargoWeightKg;
  final ShipmentBookingModel? linkedBooking;
  final int totalBookingContainersCount;
  final int totalRegisteredContainersCount;
  final String bookingContainersSummary;
  final List<ContainerLoadingModel> containers;
  final VoidCallback onAddContainer;
  final void Function(int index) onDuplicateContainer;
  final void Function(int index) onDeleteContainer;
  final void Function(int index, ContainerLoadingModel updated) onUpdateContainer;
  final TextEditingController cfsWarehouseController;

  const ContainerEquipmentAssignmentTab({
    super.key,
    required this.importFiles,
    required this.existingActiveFileIds,
    required this.selectedImportFileId,
    required this.onImportFileSelected,
    required this.shipmentType,
    required this.onShipmentTypeChanged,
    required this.isStackable,
    required this.onStackableChanged,
    required this.activeContainerRec,
    required this.totalCargoCbm,
    required this.totalCargoWeightKg,
    this.linkedBooking,
    required this.totalBookingContainersCount,
    required this.totalRegisteredContainersCount,
    required this.bookingContainersSummary,
    required this.containers,
    required this.onAddContainer,
    required this.onDuplicateContainer,
    required this.onDeleteContainer,
    required this.onUpdateContainer,
    required this.cfsWarehouseController,
  });

  bool get _isBookingLimitReached =>
      linkedBooking != null &&
      totalBookingContainersCount > 0 &&
      totalRegisteredContainersCount >= totalBookingContainersCount;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SearchableDropdownField<int?>(
                  labelText: l.cargoShippingImportFileLabel,
                  hintText: l.cargoShippingImportFileHint,
                  value: selectedImportFileId,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l.cargoShippingImportFileDefault),
                    ...importFiles.map((f) {
                      final hasExisting = existingActiveFileIds.contains(f.importFileId);
                      return SearchableDropdownItem<int?>(
                        value: f.importFileId,
                        label:
                            '${f.primaryNameWithCode} - ${f.companyName} | ACID: ${f.acidNumber ?? "N/A"}${hasExisting ? " ${l.cargoShippingPreviouslyRegistered}" : ""}',
                        subtitle: f.supplierName,
                      );
                    }),
                  ],
                  onChanged: onImportFileSelected,
                  validator: (v) => v == null ? l.cargoShippingSelectFileValidator : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SearchableDropdownField<String>(
                  labelText: l.cargoShippingShipmentTypeLabel,
                  value: shipmentType,
                  items: [
                    SearchableDropdownItem(value: 'FCL', label: l.cargoShippingFclLabel),
                    SearchableDropdownItem(value: 'LCL', label: l.cargoShippingLclLabel),
                  ],
                  onChanged: (val) {
                    if (val != null) onShipmentTypeChanged(val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stacking & Container Recommendation Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: activeContainerRec == null
                          ? Text(
                              l.cshCargoMetricsMissing,
                              key: const Key('cargoMetricsMissing'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.orange),
                            )
                          : CopyableText(
                              l.cargoShippingAggregatedCargoMetrics(
                                totalCargoCbm.toStringAsFixed(2),
                                totalCargoWeightKg.toStringAsFixed(0),
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                              tooltip: l.cargoShippingCopyFieldTooltip,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(l.cargoShippingCargoStackingLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ChoiceChip(
                      label: Text(l.cargoShippingStackable),
                      selected: isStackable,
                      onSelected: (val) => onStackableChanged(val),
                    ),
                    ChoiceChip(
                      label: Text(l.cargoShippingNonStackable),
                      selected: !isStackable,
                      onSelected: (val) => onStackableChanged(!val),
                    ),
                  ],
                ),
                if (activeContainerRec != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.55)),
                    ),
                    child: CopyableText(
                      l.cargoShippingAutoRecommendation(
                        activeContainerRec!.requiredContainersCount,
                        activeContainerRec!.recommendedContainerCode,
                        activeContainerRec!.spaceUtilizationPercent.toStringAsFixed(1),
                        activeContainerRec!.payloadUtilizationPercent.toStringAsFixed(1),
                      ),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      tooltip: l.cargoShippingCopyFieldTooltip,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Container Allocation Header
          if (shipmentType == 'FCL') ...[
            if (linkedBooking != null && totalBookingContainersCount > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: totalRegisteredContainersCount == totalBookingContainersCount
                      ? AppTheme.emerald.withValues(alpha: 0.08)
                      : AppTheme.crimson.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: totalRegisteredContainersCount == totalBookingContainersCount
                        ? AppTheme.emerald.withValues(alpha: 0.4)
                        : AppTheme.crimson.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      totalRegisteredContainersCount == totalBookingContainersCount
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      color: totalRegisteredContainersCount == totalBookingContainersCount
                          ? AppTheme.emerald
                          : AppTheme.crimson,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${l.cargoShippingBookingStatusBadge(linkedBooking!.bookingCode, bookingContainersSummary)} | $totalRegisteredContainersCount / $totalBookingContainersCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: totalRegisteredContainersCount == totalBookingContainersCount
                              ? AppTheme.emerald
                              : AppTheme.crimson,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: totalRegisteredContainersCount == totalBookingContainersCount
                            ? AppTheme.emerald.withValues(alpha: 0.15)
                            : AppTheme.crimson.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        totalRegisteredContainersCount == totalBookingContainersCount
                            ? l.cargoShippingBookingStatusMatch
                            : l.cargoShippingBookingStatusMismatch,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: totalRegisteredContainersCount == totalBookingContainersCount
                              ? AppTheme.emerald
                              : AppTheme.crimson,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(l.cargoShippingContainersHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                AppButton(
                  label: l.cargoShippingAddContainerType,
                  icon: Icons.add,
                  size: AppButtonSize.small,
                  tooltip: _isBookingLimitReached ? l.cargoShippingBookingLimitReached : null,
                  onPressed: _isBookingLimitReached ? null : onAddContainer,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Container Equipment List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: containers.length,
              separatorBuilder: (c, i) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final item = containers[index];
                return ContainerEquipmentCard(
                  item: item,
                  index: index,
                  totalContainersCount: containers.length,
                  linkedBooking: linkedBooking,
                  totalBookingContainersCount: totalBookingContainersCount,
                  totalRegisteredContainersCount: totalRegisteredContainersCount,
                  onDuplicate: onDuplicateContainer,
                  onDelete: onDeleteContainer,
                  onUpdate: onUpdateContainer,
                );
              },
            ),
          ] else ...[
            // LCL CFS Warehouse Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.cargoShippingCfsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: cfsWarehouseController,
                    decoration: InputDecoration(
                      labelText: l.cargoShippingCfsWarehouseLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.warehouse, color: AppTheme.cobalt),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: l.cargoShippingCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(context, cfsWarehouseController.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
