import 'package:flutter/material.dart';

import '../../../import_files/models/import_file_model.dart';
import '../../models/cargo_shipping_model.dart';
import 'cargo_shipping_containers_card.dart';
import 'cargo_shipping_details_card.dart';

class CargoShippingTrackingStep extends StatelessWidget {
  final List<ImportFileModel> importFiles;
  final List<CargoShippingModel> existingRecords;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileSelected;
  final String shipmentType;
  final ValueChanged<String> onShipmentTypeChanged;
  final ImportFileModel? curFile;
  final List<ContainerLoadingModel> containers;
  final LclLoadingTrackingModel? lclTracking;
  final String cfsWarehouse;
  final Future<void> Function(int) onQuickSaveContainer;
  final Future<void> Function() onQuickSaveLcl;
  final VoidCallback onEditContainer;
  final ValueChanged<int> onCloneContainer;
  final Future<void> Function(int) onDeleteContainer;
  final void Function(int idx, ContainerLoadingModel updated) onUpdateContainer;
  final ValueChanged<LclLoadingTrackingModel> onUpdateLclTracking;
  final Future<String?> Function(BuildContext, {String? initialIso, DateTime? minDate, String? title}) onPickDateTime;

  const CargoShippingTrackingStep({
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
    required this.onQuickSaveContainer,
    required this.onQuickSaveLcl,
    required this.onEditContainer,
    required this.onCloneContainer,
    required this.onDeleteContainer,
    required this.onUpdateContainer,
    required this.onUpdateLclTracking,
    required this.onPickDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CargoShippingDetailsCard(
          importFiles: importFiles,
          existingRecords: existingRecords,
          selectedImportFileId: selectedImportFileId,
          onImportFileSelected: onImportFileSelected,
          shipmentType: shipmentType,
          onShipmentTypeChanged: onShipmentTypeChanged,
          curFile: curFile,
          containers: containers,
          lclTracking: lclTracking,
          cfsWarehouse: cfsWarehouse,
        ),
        CargoShippingContainersCard(
          shipmentType: shipmentType,
          containers: containers,
          lclTracking: lclTracking,
          cfsWarehouse: cfsWarehouse,
          onQuickSaveContainer: onQuickSaveContainer,
          onQuickSaveLcl: onQuickSaveLcl,
          onEditContainer: onEditContainer,
          onCloneContainer: onCloneContainer,
          onDeleteContainer: onDeleteContainer,
          onUpdateContainer: onUpdateContainer,
          onUpdateLclTracking: onUpdateLclTracking,
          onPickDateTime: onPickDateTime,
        ),
      ],
    );
  }
}
