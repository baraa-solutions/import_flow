import 'package:flutter/material.dart';

import '../../../import_files/models/import_file_model.dart';
import '../../models/cargo_shipping_model.dart';
import 'cargo_shipping_assignment_step.dart';
import 'cargo_shipping_dialogs.dart';
import 'cargo_shipping_tracking_step.dart';

class CargoShippingStepsView extends StatelessWidget {
  final int activeStepIndex;
  final Set<int> visitedFormSteps;
  final List<ImportFileModel> importFiles;
  final Set<int?> existingActiveFileIds;
  final List<CargoShippingModel> existingRecords;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileSelected;
  final String shipmentType;
  final ValueChanged<String> onShipmentTypeChanged;
  final bool isStackable;
  final ValueChanged<bool> onStackableChanged;
  final dynamic activeContainerRec;
  final double totalCargoCbm;
  final double totalCargoWeightKg;
  final dynamic linkedBooking;
  final int totalBookingContainersCount;
  final int totalRegisteredContainersCount;
  final String bookingContainersSummary;
  final List<ContainerLoadingModel> containers;
  final LclLoadingTrackingModel? lclTracking;
  final VoidCallback onAddContainer;
  final ValueChanged<int> onDuplicateContainer;
  final Future<void> Function(int) onDeleteContainer;
  final void Function(int, ContainerLoadingModel) onUpdateContainer;
  final ValueChanged<LclLoadingTrackingModel> onUpdateLclTracking;
  final TextEditingController cfsWarehouseController;
  final ImportFileModel? curFile;
  final Future<void> Function(int) onQuickSaveContainer;
  final Future<void> Function() onQuickSaveLcl;
  final VoidCallback onEditContainer;

  const CargoShippingStepsView({
    super.key,
    required this.activeStepIndex,
    required this.visitedFormSteps,
    required this.importFiles,
    required this.existingActiveFileIds,
    required this.existingRecords,
    required this.selectedImportFileId,
    required this.onImportFileSelected,
    required this.shipmentType,
    required this.onShipmentTypeChanged,
    required this.isStackable,
    required this.onStackableChanged,
    required this.activeContainerRec,
    required this.totalCargoCbm,
    required this.totalCargoWeightKg,
    required this.linkedBooking,
    required this.totalBookingContainersCount,
    required this.totalRegisteredContainersCount,
    required this.bookingContainersSummary,
    required this.containers,
    required this.lclTracking,
    required this.onAddContainer,
    required this.onDuplicateContainer,
    required this.onDeleteContainer,
    required this.onUpdateContainer,
    required this.onUpdateLclTracking,
    required this.cfsWarehouseController,
    required this.curFile,
    required this.onQuickSaveContainer,
    required this.onQuickSaveLcl,
    required this.onEditContainer,
  });

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: activeStepIndex,
      children: [
        visitedFormSteps.contains(0)
            ? CargoShippingAssignmentStep(
                importFiles: importFiles,
                existingActiveFileIds: existingActiveFileIds,
                selectedImportFileId: selectedImportFileId,
                onImportFileSelected: onImportFileSelected,
                shipmentType: shipmentType,
                onShipmentTypeChanged: onShipmentTypeChanged,
                isStackable: isStackable,
                onStackableChanged: onStackableChanged,
                activeContainerRec: activeContainerRec,
                totalCargoCbm: totalCargoCbm,
                totalCargoWeightKg: totalCargoWeightKg,
                linkedBooking: linkedBooking,
                totalBookingContainersCount: totalBookingContainersCount,
                totalRegisteredContainersCount: totalRegisteredContainersCount,
                bookingContainersSummary: bookingContainersSummary,
                containers: containers,
                onAddContainer: onAddContainer,
                onDuplicateContainer: onDuplicateContainer,
                onDeleteContainer: onDeleteContainer,
                onUpdateContainer: onUpdateContainer,
                cfsWarehouseController: cfsWarehouseController,
              )
            : const SizedBox.shrink(),
        visitedFormSteps.contains(1)
            ? CargoShippingTrackingStep(
                importFiles: importFiles,
                existingRecords: existingRecords,
                selectedImportFileId: selectedImportFileId,
                onImportFileSelected: onImportFileSelected,
                shipmentType: shipmentType,
                onShipmentTypeChanged: onShipmentTypeChanged,
                curFile: curFile,
                containers: containers,
                lclTracking: lclTracking,
                cfsWarehouse: cfsWarehouseController.text,
                onQuickSaveContainer: onQuickSaveContainer,
                onQuickSaveLcl: onQuickSaveLcl,
                onEditContainer: onEditContainer,
                onCloneContainer: onDuplicateContainer,
                onDeleteContainer: onDeleteContainer,
                onUpdateContainer: onUpdateContainer,
                onUpdateLclTracking: onUpdateLclTracking,
                onPickDateTime: pickShippingDateTime,
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}
