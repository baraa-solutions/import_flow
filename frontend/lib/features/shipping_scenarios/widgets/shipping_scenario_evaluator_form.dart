import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/container_requirement_engine.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/models/purchase_order_model.dart';

/// نموذج إدخال جاهزية الشحنة والـ pick-up ومحددات الحاويات
class ShippingScenarioEvaluatorForm extends ConsumerWidget {
  final String title;
  final ValueChanged<String> onTitleChanged;
  final DateTime cargoReadyDate;
  final ValueChanged<DateTime> onCargoReadyDateChanged;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final String pickUpAddress;
  final ValueChanged<String> onPickUpAddressChanged;
  final int? selectedPoId;
  final ValueChanged<int?> onPoChanged;
  final int? selectedProjectId;
  final ValueChanged<int?> onProjectChanged;
  final int avgForm4Days;
  final ValueChanged<int> onAvgForm4DaysChanged;
  final int avgClearanceDays;
  final ValueChanged<int> onAvgClearanceDaysChanged;
  final bool isStackable;
  final ValueChanged<bool> onStackableChanged;
  final int? editingSessionId;
  final String? editingSessionCode;
  final int editFormVersion;
  final VoidCallback onCancelEdit;
  final List<PurchaseOrderModel> poList;
  final List<dynamic> projectsList;
  final void Function(ContainerDualRecommendationResult dualRec, double cbm, double weightKg) onShowContainerComparison;
  final void Function(List<PurchaseOrderModel> filteredPOs, double cbm, double weightKg) onShowVisualLoadPlan;

  const ShippingScenarioEvaluatorForm({
    super.key,
    required this.title,
    required this.onTitleChanged,
    required this.cargoReadyDate,
    required this.onCargoReadyDateChanged,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.pickUpAddress,
    required this.onPickUpAddressChanged,
    required this.selectedPoId,
    required this.onPoChanged,
    required this.selectedProjectId,
    required this.onProjectChanged,
    required this.avgForm4Days,
    required this.onAvgForm4DaysChanged,
    required this.avgClearanceDays,
    required this.onAvgClearanceDaysChanged,
    required this.isStackable,
    required this.onStackableChanged,
    required this.editingSessionId,
    required this.editingSessionCode,
    required this.editFormVersion,
    required this.onCancelEdit,
    required this.poList,
    required this.projectsList,
    required this.onShowContainerComparison,
    required this.onShowVisualLoadPlan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Linked PO packing list metrics
    double totalCargoCbm = 0.0;
    double totalCargoWeightKg = 0.0;
    double totalFloorAreaM2 = 0.0;
    int linkedPlCount = 0;
    bool hasNonStackableItems = false;
    bool hasExplicitPackingList = false;

    List<PurchaseOrderModel> filteredPOs = [];
    if (selectedImportFileId != null) {
      final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
      final selectedFile = importFiles.where((f) => f.importFileId == selectedImportFileId).firstOrNull;
      if (selectedFile != null) {
        final filePoIds = selectedFile.poIds ?? [];
        filteredPOs = poList.where((p) =>
            (p.poId != null && filePoIds.contains(p.poId)) ||
            (p.importFileId != null && p.importFileId == selectedFile.importFileId) ||
            (selectedFile.importFileCode.isNotEmpty && p.importFileCode != null && p.importFileCode == selectedFile.importFileCode)).toList();
      }
    } else if (selectedPoId != null) {
      filteredPOs = poList.where((p) => p.poId == selectedPoId).toList();
    }

    for (var po in filteredPOs) {
      if (po.packingListItems.isNotEmpty) {
        hasExplicitPackingList = true;
        linkedPlCount += po.packingListItems.length;
        for (var pl in po.packingListItems) {
          totalCargoCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
          totalCargoWeightKg += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
          final lM = pl.lengthCm > 0 ? pl.lengthCm / 100.0 : 0.0;
          final wM = pl.widthCm > 0 ? pl.widthCm / 100.0 : 0.0;
          totalFloorAreaM2 += ContainerRequirementEngine.calculateFloorAreaM2(lengthM: lM, widthM: wM, quantity: pl.qtyPkg.toInt());
          if (!pl.isStackable) hasNonStackableItems = true;
        }
      }
    }

    final containerRec = ContainerRequirementEngine.calculate(
      totalCbm: totalCargoCbm,
      totalWeightKg: totalCargoWeightKg,
      isStackable: isStackable,
    );

    final dualRec = ContainerRequirementEngine.calculateBoth(
      totalCbm: totalCargoCbm,
      totalWeightKg: totalCargoWeightKg,
    );

    final totalLdm = ContainerRequirementEngine.calculateLdm(floorAreaM2: totalFloorAreaM2);
    final lclChargeableCbm = ContainerRequirementEngine.calculateLclChargeableCbm(
      physicalCbm: totalCargoCbm,
      floorAreaM2: totalFloorAreaM2,
      isStackable: isStackable && !hasNonStackableItems,
    );
    final oceanRevenueTon = ContainerRequirementEngine.calculateOceanRevenueTon(
      chargeableCbm: lclChargeableCbm,
      totalGrossWeightKg: totalCargoWeightKg,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Edit Study Banner
        if (editingSessionId != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.orangeLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.orange),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: AppTheme.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⚠️ ${l.activeEditStudyBanner}: ${editingSessionCode ?? ''} (${title.isNotEmpty ? title : l.noDataFound}). ${l.activeEditStudyHint}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.wcagOrange, fontSize: 13),
                  ),
                ),
                AppButton(
                  label: l.cancelEditAndStartNew,
                  icon: Icons.cancel_outlined,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onCancelEdit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Study Main Settings Card
        Card(
          elevation: 2,
          color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, paramConstraints) {
                final isNarrowParam = paramConstraints.maxWidth < 768;

                final titleWidget = TextFormField(
                  key: ValueKey('title_${editingSessionId ?? "new"}_$editFormVersion'),
                  initialValue: title,
                  decoration: InputDecoration(labelText: '${l.studyTitleLabel} *', hintText: l.studyTitleLabel, isDense: true),
                  validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
                  onChanged: (v) => onTitleChanged(v.trim()),
                );

                final crdWidget = InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: cargoReadyDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      onCargoReadyDateChanged(picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: '${l.crdLabel} *', isDense: true),
                    child: Text(cargoReadyDate.toString().substring(0, 10), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );

                final importFileWidget = SearchableDropdownField<int?>(
                  value: selectedImportFileId,
                  labelText: l.linkImportFile,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                    ...(ref.watch(importFilesProvider).valueOrNull ?? []).map((f) => SearchableDropdownItem<int?>(
                          value: f.importFileId,
                          label: '${f.primaryNameWithCode} - ${f.companyName}',
                        )),
                  ],
                  onChanged: (v) {
                    onImportFileChanged(v);
                    if (v != null) {
                      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
                      final f = importFiles.where((file) => file.importFileId == v).firstOrNull;
                      if (f != null) {
                        final fCode = f.displayName;
                        onTitleChanged('[$fCode] ${f.companyName}');
                      }
                    }
                  },
                );

                final poWidget = SearchableDropdownField<int?>(
                  value: selectedPoId,
                  labelText: l.linkPurchaseOrder,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                    ...poList.map((po) => SearchableDropdownItem<int?>(
                          value: po.poId,
                          label: '${po.displayName} (${po.poNumber}) (${po.supplierName ?? "Supplier"})',
                        )),
                  ],
                  onChanged: onPoChanged,
                );

                final projectWidget = SearchableDropdownField<int?>(
                  value: selectedProjectId,
                  labelText: l.linkProject,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: l.unassigned),
                    ...projectsList.map((p) => SearchableDropdownItem<int?>(
                          value: p.projectId,
                          label: '${p.projectCode} - ${p.projectName}',
                        )),
                  ],
                  onChanged: onProjectChanged,
                );

                final form4Widget = TextFormField(
                  key: ValueKey('avg_form4_${editingSessionId ?? "new"}_$editFormVersion'),
                  initialValue: avgForm4Days.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.avgForm4DaysLabel, isDense: true, suffixText: 'd'),
                  onChanged: (v) => onAvgForm4DaysChanged(int.tryParse(v) ?? 5),
                );

                final clearanceWidget = TextFormField(
                  key: ValueKey('avg_clearance_${editingSessionId ?? "new"}_$editFormVersion'),
                  initialValue: avgClearanceDays.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.avgClearanceDaysLabel, isDense: true, suffixText: 'd'),
                  onChanged: (v) => onAvgClearanceDaysChanged(int.tryParse(v) ?? 7),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune, color: AppTheme.cobalt, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.studySetupAndParameters,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Parameters Row 1
                    if (isNarrowParam) ...[
                      titleWidget,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: crdWidget),
                          const SizedBox(width: 10),
                          Expanded(child: importFileWidget),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(flex: 2, child: titleWidget),
                          const SizedBox(width: 12),
                          Expanded(child: crdWidget),
                          const SizedBox(width: 12),
                          Expanded(child: importFileWidget),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Parameters Row 2 (Pick-up Address)
                    TextFormField(
                      key: ValueKey('pickup_addr_${editingSessionId ?? "new"}_$editFormVersion'),
                      initialValue: pickUpAddress,
                      decoration: InputDecoration(
                        labelText: l.pickupAddressLabel,
                        hintText: 'Factory / Industrial Zone, Origin Country',
                        prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.cobalt),
                        isDense: true,
                      ),
                      onChanged: (v) => onPickUpAddressChanged(v.trim()),
                    ),
                    const SizedBox(height: 12),

                    // Parameters Row 3 (PO Link & Project Link)
                    if (isNarrowParam) ...[
                      Row(
                        children: [
                          Expanded(child: poWidget),
                          const SizedBox(width: 10),
                          Expanded(child: projectWidget),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: form4Widget),
                          const SizedBox(width: 10),
                          Expanded(child: clearanceWidget),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: poWidget),
                          const SizedBox(width: 12),
                          Expanded(child: projectWidget),
                          const SizedBox(width: 12),
                          Expanded(child: form4Widget),
                          const SizedBox(width: 12),
                          Expanded(child: clearanceWidget),
                        ],
                      ),
                    ],

                    // Linked Packing List & Container Engine Section
                    if (selectedImportFileId != null || selectedPoId != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cobaltLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cobaltBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${l.totalShipmentSummary}: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                                ),
                                Expanded(
                                  child: Text(
                                    '${totalCargoCbm.toStringAsFixed(3)} m³ | ${totalCargoWeightKg.toStringAsFixed(0)} kg | ${totalFloorAreaM2.toStringAsFixed(2)} m² | ${totalLdm.toStringAsFixed(2)} LDM | ${oceanRevenueTon.toStringAsFixed(2)} RT (${filteredPOs.length} POs | $linkedPlCount items)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (hasExplicitPackingList) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: hasNonStackableItems ? AppTheme.orangeLight : AppTheme.emeraldLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: hasNonStackableItems ? AppTheme.orange : AppTheme.emeraldBorder),
                                ),
                                child: Text(
                                  hasNonStackableItems ? '⚠️ ${l.nonStackableOption}' : '✅ ${l.stackableOption}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: hasNonStackableItems ? AppTheme.wcagOrange : AppTheme.wcagEmerald,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (totalFloorAreaM2 > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cobaltLight,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.cobaltBorder),
                                      ),
                                      child: Text(
                                        '📐 ${totalFloorAreaM2.toStringAsFixed(2)} m² | ${totalLdm.toStringAsFixed(2)} LDM',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.cobalt),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emeraldLight,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.emeraldBorder),
                                    ),
                                    child: Text(
                                      '🌊 ${oceanRevenueTon.toStringAsFixed(2)} RT (Revenue Ton W/M)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.wcagEmerald),
                                    ),
                                  ),
                                  if (lclChargeableCbm > totalCargoCbm)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.orangeLight,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.orange),
                                      ),
                                      child: Text(
                                        '⚠️ Billed CBM: ${lclChargeableCbm.toStringAsFixed(2)} m³ (+${(lclChargeableCbm - totalCargoCbm).toStringAsFixed(2)} m³)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.wcagOrange),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('${l.cargoStackingType}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text('📦 ${l.stackableOption}'),
                                  selected: isStackable,
                                  selectedColor: AppTheme.cobalt,
                                  labelStyle: TextStyle(
                                    color: isStackable ? AppTheme.white : AppTheme.charcoal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) => onStackableChanged(true),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text('🚫 ${l.nonStackableOption}'),
                                  selected: !isStackable,
                                  selectedColor: AppTheme.wcagOrange,
                                  labelStyle: TextStyle(
                                    color: !isStackable ? AppTheme.white : AppTheme.charcoal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) => onStackableChanged(false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text('${l.approvedRecommendation}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isStackable ? AppTheme.emerald : AppTheme.wcagOrange).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isStackable ? AppTheme.emerald : AppTheme.wcagOrange),
                                  ),
                                  child: Text(
                                    containerRec.recommendationSummary,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isStackable ? AppTheme.emerald : AppTheme.wcagOrange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cloudWhite,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.textMuted),
                                  ),
                                  child: Text(
                                    isStackable
                                        ? '${l.nonStackableOption}: ${dualRec.nonStackableResult.requiredContainersCount}x ${dualRec.nonStackableResult.recommendedContainerCode}'
                                        : '${l.stackableOption}: ${dualRec.stackableResult.requiredContainersCount}x ${dualRec.stackableResult.recommendedContainerCode}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.charcoal, fontSize: 11),
                                  ),
                                ),
                                AppButton(
                                  label: l.compareContainersMatrix,
                                  icon: Icons.table_chart,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  onPressed: () => onShowContainerComparison(dualRec, totalCargoCbm, totalCargoWeightKg),
                                ),
                                const SizedBox(width: 8),
                                AppButton(
                                  label: l.visualLoadPlanSimulator,
                                  icon: Icons.view_in_ar,
                                  variant: AppButtonVariant.success,
                                  size: AppButtonSize.small,
                                  onPressed: () => onShowVisualLoadPlan(filteredPOs, totalCargoCbm, totalCargoWeightKg),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
