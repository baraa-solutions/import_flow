import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/cargo_shipping_model.dart';
import 'cargo_shipping_ui.dart';
import 'shipping_milestone_timeline_widget.dart';

/// Card displaying tracking, visual milestones, and notes for an individual FCL container.
class FclContainerTrackingCard extends StatelessWidget {
  final ContainerLoadingModel container;
  final int index;
  final int totalContainersCount;
  final VoidCallback onQuickSave;
  final VoidCallback onEdit;
  final VoidCallback onClone;
  final VoidCallback? onDelete;
  final void Function({
    String? assignmentDate,
    String? arrival,
    String? loadingStart,
    String? loadingEnd,
    String? gateIn,
  }) onUpdateTimestamps;
  final Future<String?> Function(
    BuildContext context, {
    String? initialIso,
    DateTime? minDate,
    String? title,
  }) onPickDateTime;
  final String selectedMilestoneStep;
  final ValueChanged<String> onSelectMilestoneStep;
  final TextEditingController noteController;
  final VoidCallback onSaveNote;
  final VoidCallback onClearNote;
  final void Function(String tag) onAddTag;

  const FclContainerTrackingCard({
    super.key,
    required this.container,
    required this.index,
    required this.totalContainersCount,
    required this.onQuickSave,
    required this.onEdit,
    required this.onClone,
    this.onDelete,
    required this.onUpdateTimestamps,
    required this.onPickDateTime,
    required this.selectedMilestoneStep,
    required this.onSelectMilestoneStep,
    required this.noteController,
    required this.onSaveNote,
    required this.onClearNote,
    required this.onAddTag,
  });

  @override
  Widget build(BuildContext context) {
    final c = container;
    final l = context.l10n;

    final DateTime? assignDt =
        c.containerAssignmentDate != null ? DateTime.tryParse(c.containerAssignmentDate!) : null;
    final DateTime? arrivalDt =
        c.arrivalAtSupplierAt != null ? DateTime.tryParse(c.arrivalAtSupplierAt!) : assignDt;
    final DateTime? loadStartDt =
        c.loadingStartAt != null ? DateTime.tryParse(c.loadingStartAt!) : arrivalDt;
    final DateTime? loadEndDt =
        c.loadingEndAt != null ? DateTime.tryParse(c.loadingEndAt!) : loadStartDt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: c.isSlaBreached ? AppTheme.crimson : AppTheme.borderOf(context),
          width: c.isSlaBreached ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Container No + Status + SLA Alert + Quick Save Milestone Button
          ShippingTrackingHeader(
            icon: Icons.directions_boat,
            title: l.cargoShippingContainerCardHeader(index + 1, c.containerNo, c.containerType, c.sealNo),
            copyText:
                '${l.cargoShippingContainerNo}: ${c.containerNo.isNotEmpty ? c.containerNo : "-"} | ${l.cargoShippingSealNo}: ${c.sealNo.isNotEmpty ? c.sealNo : "-"}',
            copyMessage: l.cargoShippingSlaCopyContainerSuccess,
            statusLabel: c.getLocalizedStatus(l),
            statusSeverity: c.statusSeverity,
            breached: c.isSlaBreached,
            quickSaveLabel: l.cargoShippingQuickSaveContainer,
            onQuickSave: onQuickSave,
            actions: RowActionsPill(
              viewTooltip: l.cargoShippingEditTooltip,
              onView: onEdit,
              editTooltip: l.cargoShippingEditTooltip,
              onEdit: onEdit,
              cloneTooltip: l.cargoShippingDuplicateContainerTooltip,
              onClone: onClone,
              deleteTooltip: totalContainersCount > 1 ? l.delete : null,
              onDelete: totalContainersCount > 1 ? onDelete : null,
            ),
          ),
          const SizedBox(height: 12),

          // 5-Milestone Visual Timeline Progress
          ShippingMilestoneTimelineWidget(
            stepIndex: c.progressStepIndex,
            labels: [
              l.cargoShippingMilestone1,
              l.cargoShippingMilestone2,
              l.cargoShippingMilestone3,
              l.cargoShippingMilestone4,
              l.cargoShippingMilestone5,
            ],
          ),
          const SizedBox(height: 14),

          // 5 Interactive Milestone DateTime Picker Boxes
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Assignment Date & Time
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '1',
                  stepTitle: l.cargoShippingMilestone1Title,
                  valueText: c.containerAssignmentDate,
                  noteText: c.milestoneNotes['1'],
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: c.containerAssignmentDate,
                      title: l.cargoShippingPickMilestone1,
                    );
                    if (dt != null) onUpdateTimestamps(assignmentDate: dt);
                  },
                  onSetNow: () {
                    final nowIso = DateTime.now().toIso8601String();
                    onUpdateTimestamps(assignmentDate: nowIso);
                  },
                  onClear: () => onUpdateTimestamps(assignmentDate: ''),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Arrival at Supplier
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '2',
                  stepTitle: l.cargoShippingMilestone2Title,
                  valueText: c.arrivalAtSupplierAt,
                  noteText: c.milestoneNotes['2'],
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: c.arrivalAtSupplierAt,
                      minDate: assignDt,
                      title: l.cargoShippingPickMilestone2,
                    );
                    if (dt != null) onUpdateTimestamps(arrival: dt);
                  },
                  onSetNow: () {
                    onUpdateTimestamps(arrival: DateTime.now().toIso8601String());
                  },
                  onClear: () => onUpdateTimestamps(arrival: ''),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Loading Start
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '3',
                  stepTitle: l.cargoShippingMilestone3Title,
                  valueText: c.loadingStartAt,
                  noteText: c.milestoneNotes['3'],
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: c.loadingStartAt,
                      minDate: arrivalDt,
                      title: l.cargoShippingPickMilestone3,
                    );
                    if (dt != null) onUpdateTimestamps(loadingStart: dt);
                  },
                  onSetNow: () {
                    onUpdateTimestamps(loadingStart: DateTime.now().toIso8601String());
                  },
                  onClear: () => onUpdateTimestamps(loadingStart: ''),
                ),
              ),
              const SizedBox(width: 8),

              // 4. Loading End
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '4',
                  stepTitle: l.cargoShippingMilestone4Title,
                  valueText: c.loadingEndAt,
                  noteText: c.milestoneNotes['4'],
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: c.loadingEndAt,
                      minDate: loadStartDt,
                      title: l.cargoShippingPickMilestone4,
                    );
                    if (dt != null) onUpdateTimestamps(loadingEnd: dt);
                  },
                  onSetNow: () {
                    onUpdateTimestamps(loadingEnd: DateTime.now().toIso8601String());
                  },
                  onClear: () => onUpdateTimestamps(loadingEnd: ''),
                ),
              ),
              const SizedBox(width: 8),

              // 5. Port Gate-In
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '5',
                  stepTitle: l.cargoShippingMilestone5Title,
                  valueText: c.portGateInAt,
                  noteText: c.milestoneNotes['5'],
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: c.portGateInAt,
                      minDate: loadEndDt,
                      title: l.cargoShippingPickMilestone5,
                    );
                    if (dt != null) onUpdateTimestamps(gateIn: dt);
                  },
                  onSetNow: () {
                    onUpdateTimestamps(gateIn: DateTime.now().toIso8601String());
                  },
                  onClear: () => onUpdateTimestamps(gateIn: ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Milestone-Linked Interactive Notes Section
          MilestoneNotesInteractiveSection(
            containerIndex: index,
            container: c,
            selectedStep: selectedMilestoneStep,
            onSelectStep: onSelectMilestoneStep,
            noteController: noteController,
            onSaveNote: onSaveNote,
            onClearNote: onClearNote,
            onAddTag: onAddTag,
          ),
        ],
      ),
    );
  }
}

/// Card displaying tracking, visual milestones, and timeline for LCL CFS Consolidation.
class LclConsolidationTrackingCard extends StatelessWidget {
  final LclLoadingTrackingModel lclTracking;
  final String cfsWarehouse;
  final VoidCallback onQuickSave;
  final void Function(LclLoadingTrackingModel updated) onUpdateLclTracking;
  final Future<String?> Function(
    BuildContext context, {
    String? initialIso,
    DateTime? minDate,
    String? title,
  }) onPickDateTime;

  const LclConsolidationTrackingCard({
    super.key,
    required this.lclTracking,
    required this.cfsWarehouse,
    required this.onQuickSave,
    required this.onUpdateLclTracking,
    required this.onPickDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final lcl = lclTracking;
    final l = context.l10n;

    final DateTime? schedDt =
        lcl.consolidationScheduledDate != null ? DateTime.tryParse(lcl.consolidationScheduledDate!) : null;
    final DateTime? arrCfsDt =
        lcl.arrivalAtCfsAt != null ? DateTime.tryParse(lcl.arrivalAtCfsAt!) : schedDt;
    final DateTime? stuffStartDt =
        lcl.stuffingStartAt != null ? DateTime.tryParse(lcl.stuffingStartAt!) : arrCfsDt;
    final DateTime? stuffEndDt =
        lcl.stuffingEndAt != null ? DateTime.tryParse(lcl.stuffingEndAt!) : stuffStartDt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShippingTrackingHeader(
            icon: Icons.warehouse,
            title: l.cargoShippingLclTrackingHeader(cfsWarehouse),
            copyText: cfsWarehouse.isNotEmpty ? cfsWarehouse : l.cargoShippingCfsWarehouseLabel,
            copyMessage: null,
            statusLabel: lcl.getLocalizedStatus(l),
            statusSeverity: lcl.statusSeverity,
            breached: lcl.isSlaBreached,
            quickSaveLabel: l.cargoShippingQuickSaveLcl,
            onQuickSave: onQuickSave,
          ),
          const SizedBox(height: 12),

          // Timeline
          ShippingMilestoneTimelineWidget(
            stepIndex: lcl.progressStepIndex,
            labels: [
              l.cargoShippingLclMilestone1,
              l.cargoShippingLclMilestone2,
              l.cargoShippingLclMilestone3,
              l.cargoShippingLclMilestone4,
              l.cargoShippingLclMilestone5,
            ],
          ),
          const SizedBox(height: 14),

          // 5 LCL Interactive Pickers
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sched Date
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '1',
                  stepTitle: l.cargoShippingLclMilestone1,
                  valueText: lcl.consolidationScheduledDate,
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: lcl.consolidationScheduledDate,
                      title: l.cargoShippingLclPickMilestone1,
                    );
                    if (dt != null) {
                      onUpdateLclTracking(LclLoadingTrackingModel(
                        cfsWarehouseName: cfsWarehouse.trim(),
                        consolidationScheduledDate: dt,
                        arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                        stuffingStartAt: lcl.stuffingStartAt,
                        stuffingEndAt: lcl.stuffingEndAt,
                        portGateInAt: lcl.portGateInAt,
                        trackingStatus: 'ASSIGNED',
                      ));
                    }
                  },
                  onSetNow: () {
                    final nowIso = DateTime.now().toIso8601String();
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: nowIso,
                      arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                      stuffingStartAt: lcl.stuffingStartAt,
                      stuffingEndAt: lcl.stuffingEndAt,
                      portGateInAt: lcl.portGateInAt,
                      trackingStatus: 'ASSIGNED',
                    ));
                  },
                  onClear: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: '',
                      arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                      stuffingStartAt: lcl.stuffingStartAt,
                      stuffingEndAt: lcl.stuffingEndAt,
                      portGateInAt: lcl.portGateInAt,
                      trackingStatus: 'PENDING_ASSIGNMENT',
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),

              // 2. Arrival CFS
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '2',
                  stepTitle: l.cargoShippingLclMilestone2,
                  valueText: lcl.arrivalAtCfsAt,
                  noteText: null,
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: lcl.arrivalAtCfsAt,
                      minDate: schedDt,
                      title: l.cargoShippingLclPickMilestone2,
                    );
                    if (dt != null) {
                      onUpdateLclTracking(LclLoadingTrackingModel(
                        cfsWarehouseName: cfsWarehouse.trim(),
                        consolidationScheduledDate: lcl.consolidationScheduledDate,
                        arrivalAtCfsAt: dt,
                        stuffingStartAt: lcl.stuffingStartAt,
                        stuffingEndAt: lcl.stuffingEndAt,
                        portGateInAt: lcl.portGateInAt,
                        trackingStatus: 'ARRIVED_AT_CFS',
                      ));
                    }
                  },
                  onSetNow: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: lcl.consolidationScheduledDate,
                      arrivalAtCfsAt: DateTime.now().toIso8601String(),
                      stuffingStartAt: lcl.stuffingStartAt,
                      stuffingEndAt: lcl.stuffingEndAt,
                      portGateInAt: lcl.portGateInAt,
                      trackingStatus: 'ARRIVED_AT_CFS',
                    ));
                  },
                  onClear: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: lcl.consolidationScheduledDate,
                      arrivalAtCfsAt: '',
                      stuffingStartAt: lcl.stuffingStartAt,
                      stuffingEndAt: lcl.stuffingEndAt,
                      portGateInAt: lcl.portGateInAt,
                      trackingStatus: lcl.consolidationScheduledDate != null ? 'ASSIGNED' : 'PENDING_ASSIGNMENT',
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),

              // 3. Stuffing Start
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '3',
                  stepTitle: l.cargoShippingLclMilestone3,
                  valueText: lcl.stuffingStartAt,
                  noteText: null,
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: lcl.stuffingStartAt,
                      minDate: arrCfsDt,
                      title: l.cargoShippingLclPickMilestone3,
                    );
                    if (dt != null) {
                      onUpdateLclTracking(LclLoadingTrackingModel(
                        cfsWarehouseName: cfsWarehouse.trim(),
                        consolidationScheduledDate: lcl.consolidationScheduledDate,
                        arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                        stuffingStartAt: dt,
                        stuffingEndAt: lcl.stuffingEndAt,
                        portGateInAt: lcl.portGateInAt,
                        trackingStatus: 'LOADING_IN_PROGRESS',
                      ));
                    }
                  },
                  onSetNow: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: lcl.consolidationScheduledDate,
                      arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                      stuffingStartAt: DateTime.now().toIso8601String(),
                      stuffingEndAt: lcl.stuffingEndAt,
                      portGateInAt: lcl.portGateInAt,
                      trackingStatus: 'LOADING_IN_PROGRESS',
                    ));
                  },
                  onClear: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: lcl.consolidationScheduledDate,
                      arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                      stuffingStartAt: '',
                      stuffingEndAt: lcl.stuffingEndAt,
                      portGateInAt: lcl.portGateInAt,
                      trackingStatus: lcl.arrivalAtCfsAt != null ? 'ARRIVED_AT_CFS' : 'ASSIGNED',
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),

              // 4. Stuffing End
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '4',
                  stepTitle: l.cargoShippingLclMilestone4,
                  valueText: lcl.stuffingEndAt,
                  noteText: null,
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: lcl.stuffingEndAt,
                      minDate: stuffStartDt,
                      title: l.cargoShippingLclPickMilestone4,
                    );
                    if (dt != null) {
                      onUpdateLclTracking(LclLoadingTrackingModel(
                        cfsWarehouseName: cfsWarehouse.trim(),
                        consolidationScheduledDate: lcl.consolidationScheduledDate,
                        arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                        stuffingStartAt: lcl.stuffingStartAt,
                        stuffingEndAt: dt,
                        portGateInAt: lcl.portGateInAt,
                        trackingStatus: 'LOADING_COMPLETED',
                      ));
                    }
                  },
                  onSetNow: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: lcl.consolidationScheduledDate,
                      arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                      stuffingStartAt: lcl.stuffingStartAt,
                      stuffingEndAt: DateTime.now().toIso8601String(),
                      portGateInAt: lcl.portGateInAt,
                      trackingStatus: 'LOADING_COMPLETED',
                    ));
                  },
                  onClear: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: lcl.consolidationScheduledDate,
                      arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                      stuffingStartAt: lcl.stuffingStartAt,
                      stuffingEndAt: '',
                      portGateInAt: lcl.portGateInAt,
                      trackingStatus: lcl.stuffingStartAt != null ? 'LOADING_IN_PROGRESS' : 'ARRIVED_AT_CFS',
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),

              // 5. Port Gate-In
              Expanded(
                child: MilestonePickerBox(
                  stepNumber: '5',
                  stepTitle: l.cargoShippingLclMilestone5,
                  valueText: lcl.portGateInAt,
                  noteText: null,
                  onPick: () async {
                    final dt = await onPickDateTime(
                      context,
                      initialIso: lcl.portGateInAt,
                      minDate: stuffEndDt,
                      title: l.cargoShippingLclPickMilestone5,
                    );
                    if (dt != null) {
                      onUpdateLclTracking(LclLoadingTrackingModel(
                        cfsWarehouseName: cfsWarehouse.trim(),
                        consolidationScheduledDate: lcl.consolidationScheduledDate,
                        arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                        stuffingStartAt: lcl.stuffingStartAt,
                        stuffingEndAt: lcl.stuffingEndAt,
                        portGateInAt: dt,
                        trackingStatus: 'GATED_IN_AT_PORT',
                      ));
                    }
                  },
                  onSetNow: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: lcl.consolidationScheduledDate,
                      arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                      stuffingStartAt: lcl.stuffingStartAt,
                      stuffingEndAt: lcl.stuffingEndAt,
                      portGateInAt: DateTime.now().toIso8601String(),
                      trackingStatus: 'GATED_IN_AT_PORT',
                    ));
                  },
                  onClear: () {
                    onUpdateLclTracking(LclLoadingTrackingModel(
                      cfsWarehouseName: cfsWarehouse.trim(),
                      consolidationScheduledDate: lcl.consolidationScheduledDate,
                      arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                      stuffingStartAt: lcl.stuffingStartAt,
                      stuffingEndAt: lcl.stuffingEndAt,
                      portGateInAt: '',
                      trackingStatus: lcl.stuffingEndAt != null ? 'LOADING_COMPLETED' : 'LOADING_IN_PROGRESS',
                    ));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
