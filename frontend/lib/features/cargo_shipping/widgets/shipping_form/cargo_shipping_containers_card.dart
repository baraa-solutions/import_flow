import 'package:flutter/material.dart';

import '../../models/cargo_shipping_model.dart';
import '../container_tracking_cards.dart';

/// Renders the container loading tracking cards (FCL individual container cards or LCL consolidation card).
///
/// Encapsulates the milestone note controllers, active milestone step selection,
/// and milestone timestamp status transitions.
class CargoShippingContainersCard extends StatefulWidget {
  final String shipmentType;
  final List<ContainerLoadingModel> containers;
  final LclLoadingTrackingModel? lclTracking;
  final String cfsWarehouse;
  final Future<void> Function(int index) onQuickSaveContainer;
  final Future<void> Function() onQuickSaveLcl;
  final VoidCallback onEditContainer;
  final void Function(int index) onCloneContainer;
  final void Function(int index) onDeleteContainer;
  final void Function(int index, ContainerLoadingModel updated) onUpdateContainer;
  final void Function(LclLoadingTrackingModel updated) onUpdateLclTracking;
  final Future<String?> Function(
    BuildContext context, {
    String? initialIso,
    DateTime? minDate,
    String? title,
  }) onPickDateTime;

  const CargoShippingContainersCard({
    super.key,
    required this.shipmentType,
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
  State<CargoShippingContainersCard> createState() => _CargoShippingContainersCardState();
}

class _CargoShippingContainersCardState extends State<CargoShippingContainersCard> {
  final Map<int, String> _selectedMilestoneForNote = {};
  final Map<String, TextEditingController> _milestoneNoteControllers = {};

  @override
  void dispose() {
    for (final c in _milestoneNoteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateContainerTimestamp(
    int index,
    ContainerLoadingModel c, {
    String? assignmentDate,
    String? arrival,
    String? loadingStart,
    String? loadingEnd,
    String? gateIn,
  }) {
    final assign = assignmentDate ?? c.containerAssignmentDate;
    final arr = arrival ?? c.arrivalAtSupplierAt;
    final lStart = loadingStart ?? c.loadingStartAt;
    final lEnd = loadingEnd ?? c.loadingEndAt;
    final gIn = gateIn ?? c.portGateInAt;

    String newStatus = 'PENDING_ASSIGNMENT';
    if (gIn != null && gIn.isNotEmpty) {
      newStatus = 'GATED_IN_AT_PORT';
    } else if (lEnd != null && lEnd.isNotEmpty) {
      newStatus = 'LOADING_COMPLETED';
    } else if (lStart != null && lStart.isNotEmpty) {
      newStatus = 'LOADING_IN_PROGRESS';
    } else if (arr != null && arr.isNotEmpty) {
      newStatus = 'ARRIVED_AT_SUPPLIER';
    } else if (assign != null && assign.isNotEmpty) {
      newStatus = 'ASSIGNED';
    }

    widget.onUpdateContainer(
      index,
      c.copyWith(
        containerAssignmentDate: assign,
        arrivalAtSupplierAt: arr,
        loadingStartAt: lStart,
        loadingEndAt: lEnd,
        portGateInAt: gIn,
        trackingStatus: newStatus,
      ),
    );
  }

  Widget _buildFclContainerTrackingCard(ContainerLoadingModel c, int index) {
    final selectedStep = _selectedMilestoneForNote[index] ?? '1';
    final noteKey = '${index}_$selectedStep';
    final ctrl = _milestoneNoteControllers.putIfAbsent(
      noteKey,
      () => TextEditingController(text: c.milestoneNotes[selectedStep] ?? ''),
    );
    if (ctrl.text != (c.milestoneNotes[selectedStep] ?? '')) {
      ctrl.text = c.milestoneNotes[selectedStep] ?? '';
    }

    return FclContainerTrackingCard(
      container: c,
      index: index,
      totalContainersCount: widget.containers.length,
      onQuickSave: () => widget.onQuickSaveContainer(index),
      onEdit: widget.onEditContainer,
      onClone: () => widget.onCloneContainer(index),
      onDelete: widget.containers.length > 1 ? () => widget.onDeleteContainer(index) : null,
      onUpdateTimestamps: ({assignmentDate, arrival, loadingStart, loadingEnd, gateIn}) {
        _updateContainerTimestamp(
          index,
          c,
          assignmentDate: assignmentDate,
          arrival: arrival,
          loadingStart: loadingStart,
          loadingEnd: loadingEnd,
          gateIn: gateIn,
        );
      },
      onPickDateTime: widget.onPickDateTime,
      selectedMilestoneStep: selectedStep,
      onSelectMilestoneStep: (step) {
        setState(() {
          _selectedMilestoneForNote[index] = step;
          final nextKey = '${index}_$step';
          final nextCtrl = _milestoneNoteControllers.putIfAbsent(
            nextKey,
            () => TextEditingController(text: c.milestoneNotes[step] ?? ''),
          );
          nextCtrl.text = c.milestoneNotes[step] ?? '';
        });
      },
      noteController: ctrl,
      onSaveNote: () {
        final text = ctrl.text.trim();
        final updatedNotes = Map<String, String>.from(c.milestoneNotes);
        if (text.isEmpty) {
          updatedNotes.remove(selectedStep);
        } else {
          updatedNotes[selectedStep] = text;
        }
        widget.onUpdateContainer(index, c.copyWith(milestoneNotes: updatedNotes));
        widget.onQuickSaveContainer(index);
      },
      onClearNote: () {
        ctrl.clear();
        final updatedNotes = Map<String, String>.from(c.milestoneNotes);
        updatedNotes.remove(selectedStep);
        widget.onUpdateContainer(index, c.copyWith(milestoneNotes: updatedNotes));
        widget.onQuickSaveContainer(index);
      },
      onAddTag: (tag) {
        final cur = ctrl.text.trim();
        if (cur.isEmpty) {
          ctrl.text = tag;
        } else if (!cur.contains(tag)) {
          ctrl.text = '$cur | $tag';
        }
        setState(() {});
      },
    );
  }

  Widget _buildLclConsolidationTrackingCard() {
    final lcl = widget.lclTracking ??
        LclLoadingTrackingModel(
          shipmentType: 'LCL',
          cfsWarehouseName: widget.cfsWarehouse.trim(),
          consolidationScheduledDate: DateTime.now().toIso8601String(),
          trackingStatus: 'ASSIGNED',
        );

    return LclConsolidationTrackingCard(
      lclTracking: lcl,
      cfsWarehouse: widget.cfsWarehouse,
      onQuickSave: widget.onQuickSaveLcl,
      onUpdateLclTracking: widget.onUpdateLclTracking,
      onPickDateTime: widget.onPickDateTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shipmentType == 'FCL') {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.containers.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final container = widget.containers[index];
          return _buildFclContainerTrackingCard(container, index);
        },
      );
    } else {
      return _buildLclConsolidationTrackingCard();
    }
  }
}
