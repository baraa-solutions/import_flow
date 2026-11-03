import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/cargo_shipping_model.dart';
import '../cargo_shipping_ui.dart';
import '../shipping_milestone_timeline_widget.dart';

/// Card managing the import file selection, shipment type toggle,
/// SLA export toolbar, and 48-hour SLA metric summary strip for Step 2 tracking.
class CargoShippingDetailsCard extends StatelessWidget {
  final List<dynamic> importFiles;
  final List<CargoShippingModel> existingRecords;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileSelected;
  final String shipmentType;
  final ValueChanged<String> onShipmentTypeChanged;
  final dynamic curFile;
  final List<ContainerLoadingModel> containers;
  final LclLoadingTrackingModel? lclTracking;
  final String cfsWarehouse;

  const CargoShippingDetailsCard({
    super.key,
    required this.importFiles,
    required this.existingRecords,
    required this.selectedImportFileId,
    required this.onImportFileSelected,
    required this.shipmentType,
    required this.onShipmentTypeChanged,
    required this.curFile,
    required this.containers,
    required this.lclTracking,
    required this.cfsWarehouse,
  });

  @override
  Widget build(BuildContext context) {
    int totalCount = shipmentType == 'FCL' ? containers.length : 1;
    int gatedInCount = 0;
    int inProgressCount = 0;
    int breachedCount = 0;

    if (shipmentType == 'FCL') {
      for (final c in containers) {
        if (c.trackingStatus == 'GATED_IN_AT_PORT') gatedInCount++;
        if (c.trackingStatus == 'LOADING_IN_PROGRESS' || c.trackingStatus == 'ARRIVED_AT_SUPPLIER') {
          inProgressCount++;
        }
        if (c.isSlaBreached) breachedCount++;
      }
    } else if (lclTracking != null) {
      if (lclTracking!.trackingStatus == 'GATED_IN_AT_PORT') gatedInCount = 1;
      if (lclTracking!.isSlaBreached) breachedCount = 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Import File Selector Card for Step 2
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderOf(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SearchableDropdownField<int?>(
                      labelText: context.l10n.cargoShippingImportFileTrackingLabel,
                      hintText: context.l10n.cargoShippingImportFileTrackingHint,
                      value: selectedImportFileId,
                      items: [
                        SearchableDropdownItem<int?>(
                          value: null,
                          label: context.l10n.cargoShippingImportFileDefault,
                        ),
                        ...importFiles.map((f) {
                          final hasExisting = existingRecords.any(
                            (r) => r.importFileId == f.importFileId && r.isActive,
                          );
                          return SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label:
                                '${f.primaryNameWithCode} - ${f.companyName} | ACID: ${f.acidNumber ?? "N/A"}${hasExisting ? " ${context.l10n.cargoShippingPreviouslyRegistered}" : ""}',
                            subtitle: f.supplierName,
                          );
                        }),
                      ],
                      onChanged: onImportFileSelected,
                      validator: (v) => v == null
                          ? context.l10n.cargoShippingSelectFileValidator
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String>(
                      labelText: context.l10n.cargoShippingShipmentTypeLabel,
                      value: shipmentType,
                      items: [
                        SearchableDropdownItem(
                          value: 'FCL',
                          label: context.l10n.cargoShippingFclLabel,
                        ),
                        SearchableDropdownItem(
                          value: 'LCL',
                          label: context.l10n.cargoShippingLclLabel,
                        ),
                      ],
                      onChanged: (val) => onShipmentTypeChanged(val ?? 'FCL'),
                    ),
                  ),
                ],
              ),
              if (curFile != null) ...[
                const SizedBox(height: 10),
                ShippingLinkedFileBanner(
                  fileLabel: curFile.primaryNameWithCode,
                  companyName: curFile.companyName,
                  supplierName: curFile.supplierName,
                  acidNumber: curFile.acidNumber,
                  copyAll: () => CopyHelper.copy(
                    context,
                    '${curFile.primaryNameWithCode} | ${curFile.companyName} | ${curFile.supplierName} | ACID: ${curFile.acidNumber ?? "-"}',
                  ),
                ),
              ],
            ],
          ),
        ),

        // SLA Export Toolbar
        ShippingSlaExportToolbar(
          curFile: curFile,
          totalCount: totalCount,
          inProgressCount: inProgressCount,
          gatedInCount: gatedInCount,
          breachedCount: breachedCount,
          shipmentType: shipmentType,
          containers: containers,
          lclTracking: lclTracking,
          cfsWarehouse: cfsWarehouse,
        ),

        // Top Summary Dashboard Cards
        MetricCardStrip(
          padding: EdgeInsets.zero,
          metrics: [
            MetricCardData(
              title: context.l10n.cargoShippingMetricTotalContainers,
              value: totalCount.toString(),
              icon: Icons.inventory_2,
              color: AppTheme.cobalt,
            ),
            MetricCardData(
              title: context.l10n.cargoShippingMetricInProgress,
              value: inProgressCount.toString(),
              icon: Icons.hourglass_top,
              color: AppTheme.orange,
            ),
            MetricCardData(
              title: context.l10n.cargoShippingMetricGatedIn,
              value: gatedInCount.toString(),
              icon: Icons.check_circle,
              color: AppTheme.emerald,
            ),
            MetricCardData(
              title: context.l10n.cargoShippingMetricSlaBreached,
              value: breachedCount.toString(),
              icon: Icons.warning,
              color: breachedCount > 0 ? AppTheme.crimson : AppTheme.textMutedOf(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
