import 'package:flutter/material.dart';

import '../../../../core/utils/container_requirement_engine.dart';
import '../../../freight_booking/models/freight_booking_model.dart';
import '../../models/cargo_shipping_model.dart';
import '../container_equipment_assignment_tab.dart';

/// Step 1: Container and equipment assignment builder widget.
class CargoShippingAssignmentStep extends StatelessWidget {
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

  const CargoShippingAssignmentStep({
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
    required this.linkedBooking,
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

  @override
  Widget build(BuildContext context) {
    return ContainerEquipmentAssignmentTab(
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
    );
  }
}
