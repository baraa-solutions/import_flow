import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../freight_booking/models/freight_booking_model.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/cargo_container_defaults.dart';
import '../models/cargo_shipping_model.dart';
import '../providers/cargo_shipping_provider.dart';
import 'shipping_form/cargo_shipping_actions_bar.dart';
import 'shipping_form/cargo_shipping_dialogs.dart';
import 'shipping_form/cargo_shipping_form_service.dart';
import 'shipping_form/cargo_shipping_header.dart';
import 'shipping_form/cargo_shipping_steps_view.dart';

class CargoShippingFormTab extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;
  final VoidCallback? onSwitchToRegistry;
  final VoidCallback? onRefreshNeeded;
  final ValueChanged<int>? onStepChanged;

  const CargoShippingFormTab({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
    this.onSwitchToRegistry,
    this.onRefreshNeeded,
    this.onStepChanged,
  });

  @override
  ConsumerState<CargoShippingFormTab> createState() => CargoShippingFormTabState();
}

class CargoShippingFormTabState extends ConsumerState<CargoShippingFormTab> {
  int _activeStepIndex = 0;
  int? _editingRecordId;
  String? _editingRecordCode;
  int? _selectedImportFileId;
  String _shipmentType = 'FCL';
  bool _isStackable = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  final _cfsWarehouseCtrl = TextEditingController();

  List<ContainerLoadingModel> _containers = [];
  LclLoadingTrackingModel? _lclTracking;
  late final Set<int> _visitedFormSteps;

  int get activeStepIndex => _activeStepIndex;
  int? get selectedImportFileId => _selectedImportFileId;

  @override
  void initState() {
    super.initState();
    _activeStepIndex = widget.initialSubTab.clamp(0, 1);
    _visitedFormSteps = {_activeStepIndex};
    if (widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
    }
    _initDefaultContainer();
  }

  @override
  void didUpdateWidget(covariant CargoShippingFormTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() {
        _activeStepIndex = widget.initialSubTab.clamp(0, 1);
        _visitedFormSteps.add(_activeStepIndex);
      });
    }
  }

  @override
  void dispose() {
    _cfsWarehouseCtrl.dispose();
    super.dispose();
  }

  void _initDefaultContainer() {
    final nowIso = DateTime.now().toIso8601String();
    _containers = [blankContainer(assignmentDateIso: nowIso)];
    _lclTracking = LclLoadingTrackingModel(shipmentType: 'LCL', consolidationScheduledDate: nowIso, trackingStatus: 'ASSIGNED');
  }

  void resetForm() {
    setState(() {
      _editingRecordId = null;
      _editingRecordCode = null;
      _selectedImportFileId = null;
      _shipmentType = 'FCL';
      _isStackable = true;
      _cfsWarehouseCtrl.clear();
      _activeStepIndex = 0;
      _visitedFormSteps.add(0);
      _initDefaultContainer();
    });
    widget.onStepChanged?.call(_activeStepIndex);
  }

  void loadRecordForEditing(CargoShippingModel rec, {bool showSnack = true}) {
    setState(() {
      _editingRecordId = rec.cargoShippingId;
      _editingRecordCode = rec.cargoShippingCode;
      _selectedImportFileId = rec.importFileId;
      _shipmentType = rec.shipmentType;
      _containers = rec.containersLoadingData.isNotEmpty
          ? List.from(rec.containersLoadingData)
          : [blankContainer(assignmentDateIso: DateTime.now().toIso8601String())];
      _lclTracking = rec.lclTrackingData;
      _activeStepIndex = 1;
      _visitedFormSteps.add(1);
    });
    widget.onStepChanged?.call(_activeStepIndex);

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cargoShippingLoadSuccessSnack(rec.importFileCode ?? rec.cargoShippingCode),
          severity: AppSeverity.info,
        ),
      );
    }
  }

  void loadClonedRecord(CargoShippingModel rec, String newCode, List<ContainerLoadingModel> clonedContainers) {
    final nowIso = DateTime.now().toIso8601String();
    setState(() {
      _editingRecordId = null;
      _editingRecordCode = newCode;
      _selectedImportFileId = null;
      _shipmentType = rec.shipmentType;
      _containers = clonedContainers.isNotEmpty ? clonedContainers : [blankContainer(assignmentDateIso: nowIso)];
      if (rec.shipmentType == 'LCL' && rec.lclTrackingData != null) {
        final cfsName = rec.lclTrackingData!.cfsWarehouseName ?? 'CFS Warehouse';
        _cfsWarehouseCtrl.text = cfsName;
        _lclTracking = LclLoadingTrackingModel(shipmentType: 'LCL', cfsWarehouseName: cfsName, consolidationScheduledDate: nowIso, trackingStatus: 'ASSIGNED');
      }
      _activeStepIndex = 0;
      _visitedFormSteps.add(0);
    });
    widget.onStepChanged?.call(_activeStepIndex);
  }

  int? get _linkedBookingId => _linkedBooking?.bookingId;
  ShipmentBookingModel? get _linkedBooking => _selectedImportFileId == null
      ? null
      : (ref.watch(freightBookingProvider).valueOrNull ?? []).where((b) => b.importFileId == _selectedImportFileId && b.isActive).firstOrNull;

  int get _totalBookingContainersCount => CargoShippingFormService.countBookingContainers(_linkedBooking);
  int get _totalRegisteredContainersCount => CargoShippingFormService.countRegisteredContainers(_containers);
  String get _bookingContainersSummary => CargoShippingFormService.formatBookingContainersSummary(_linkedBooking);

  Future<void> _onImportFileSelected(int? val) async {
    if (val == null) {
      setState(() => _selectedImportFileId = null);
      return;
    }
    final res = await CargoShippingFormService.resolveFileSelection(ref: ref, fileId: val);
    if (res.existingRecord != null) {
      loadRecordForEditing(res.existingRecord!, showSnack: true);
    } else {
      setState(() {
        _selectedImportFileId = val;
        _editingRecordId = null;
        _editingRecordCode = null;
        _shipmentType = res.shipmentType;
        _containers = res.containers;
      });
    }
  }

  void _duplicateContainer(int index) {
    final updated = CargoShippingFormService.duplicateContainer(_containers, index);
    if (updated.length > _containers.length) {
      setState(() => _containers = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cshContainerDuplicated(updated[index + 1].containerType), severity: AppSeverity.info, duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _deleteContainer(int index) async {
    if (_containers.length > 1 && await confirmDeleteContainer(context)) {
      setState(() => _containers.removeAt(index));
    }
  }

  void _ensureEditingRecordId() {
    if (_editingRecordId == null && _selectedImportFileId != null) {
      final rec = (ref.read(cargoShippingProvider).valueOrNull ?? []).where((r) => r.importFileId == _selectedImportFileId && r.isActive).firstOrNull;
      if (rec != null) {
        _editingRecordId = rec.cargoShippingId;
        _editingRecordCode = rec.cargoShippingCode;
      }
    }
  }

  Future<void> _quickSaveContainerMilestone(int containerIndex) async {
    final c = _containers[containerIndex];
    final updated = await CargoShippingFormService.quickSaveContainerMilestone(
      context: context,
      ref: ref,
      selectedImportFileId: _selectedImportFileId,
      editingRecordId: _editingRecordId,
      container: c,
      onSetSaving: (s) => setState(() => _isSaving = s),
    );
    if (updated != null && updated.containersLoadingData.isNotEmpty && mounted) {
      setState(() => _containers = List.from(updated.containersLoadingData));
    }
  }

  Future<void> _quickSaveLclMilestone() async {
    final updated = await CargoShippingFormService.quickSaveLclMilestone(
      context: context,
      ref: ref,
      selectedImportFileId: _selectedImportFileId,
      editingRecordId: _editingRecordId,
      lclTracking: _lclTracking,
      onSetSaving: (s) => setState(() => _isSaving = s),
    );
    if (updated != null && updated.lclTrackingData != null && mounted) {
      setState(() => _lclTracking = updated.lclTrackingData);
    }
  }

  void _smartSimulationAllContainersTracking() {
    final sim = CargoShippingFormService.simulateTracking(
      shipmentType: _shipmentType,
      currentContainers: _containers,
      cfsWarehouse: _cfsWarehouseCtrl.text,
    );
    setState(() {
      _containers = sim.containers;
      if (sim.lclTracking != null) _lclTracking = sim.lclTracking;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.cshSmartSimDone, severity: AppSeverity.info),
    );
  }

  Future<void> _submitForm({bool isDraftProgressive = false}) async {
    _ensureEditingRecordId();
    await CargoShippingFormService.submitCargoShippingForm(
      context: context,
      ref: ref,
      formKey: _formKey,
      selectedImportFileId: _selectedImportFileId,
      editingRecordId: _editingRecordId,
      shipmentType: _shipmentType,
      containers: _containers,
      lclTracking: _lclTracking,
      linkedBookingId: _linkedBookingId,
      linkedBooking: _linkedBooking,
      totalBookingContainersCount: _totalBookingContainersCount,
      totalRegisteredContainersCount: _totalRegisteredContainersCount,
      isDraftProgressive: isDraftProgressive,
      onSetSaving: (s) => setState(() => _isSaving = s),
      onSuccess: (res) {
        setState(() {
          _editingRecordId = res.cargoShippingId;
          _editingRecordCode = res.cargoShippingCode;
          if (res.containersLoadingData.isNotEmpty) {
            _containers = List.from(res.containersLoadingData);
          }
          _lclTracking = res.lclTrackingData;
        });
      },
      onSwitchToRegistry: widget.onSwitchToRegistry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final poList = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final curFile = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;

    final metrics = CargoShippingFormService.computeCargoMetrics(
      curFile: curFile,
      allPOs: poList,
      isStackable: _isStackable,
    );

    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CargoShippingHeader(
                curFile: curFile,
                selectedImportFileId: _selectedImportFileId,
                editingRecordCode: _editingRecordCode,
                editingRecordId: _editingRecordId,
                activeStepIndex: _activeStepIndex,
                onStepChanged: (index) => setState(() {
                  _activeStepIndex = index;
                  _visitedFormSteps.add(index);
                  widget.onStepChanged?.call(index);
                }),
                onCancelEdit: resetForm,
              ),
              const SizedBox(height: 14),
              CargoShippingStepsView(
                activeStepIndex: _activeStepIndex,
                visitedFormSteps: _visitedFormSteps,
                importFiles: importFiles,
                existingActiveFileIds: {for (final r in ref.watch(cargoShippingProvider).valueOrNull ?? []) if (r.isActive) r.importFileId},
                existingRecords: ref.watch(cargoShippingProvider).valueOrNull ?? [],
                selectedImportFileId: _selectedImportFileId,
                onImportFileSelected: _onImportFileSelected,
                shipmentType: _shipmentType,
                onShipmentTypeChanged: (val) => setState(() => _shipmentType = val),
                isStackable: _isStackable,
                onStackableChanged: (val) => setState(() => _isStackable = val),
                activeContainerRec: metrics.activeRec,
                totalCargoCbm: metrics.cbm,
                totalCargoWeightKg: metrics.weightKg,
                linkedBooking: _linkedBooking,
                totalBookingContainersCount: _totalBookingContainersCount,
                totalRegisteredContainersCount: _totalRegisteredContainersCount,
                bookingContainersSummary: _bookingContainersSummary,
                containers: _containers,
                lclTracking: _lclTracking,
                onAddContainer: () {
                  setState(() {
                    _containers.add(blankContainer(assignmentDateIso: DateTime.now().toIso8601String()));
                  });
                },
                onDuplicateContainer: _duplicateContainer,
                onDeleteContainer: _deleteContainer,
                onUpdateContainer: (index, updated) => setState(() => _containers[index] = updated),
                onUpdateLclTracking: (updated) => setState(() => _lclTracking = updated),
                cfsWarehouseController: _cfsWarehouseCtrl,
                curFile: curFile,
                onQuickSaveContainer: _quickSaveContainerMilestone,
                onQuickSaveLcl: _quickSaveLclMilestone,
                onEditContainer: () {
                  setState(() => _activeStepIndex = 0);
                  widget.onStepChanged?.call(0);
                },
              ),
              const SizedBox(height: 16),
              CargoShippingActionsBar(
                isSaving: _isSaving,
                isEditing: _editingRecordId != null,
                onSmartSim: _smartSimulationAllContainersTracking,
                onExportManifest: () => CargoShippingManifestHelper.copyContainerAllocationsManifest(
                  context,
                  curFile: curFile,
                  shipmentType: _shipmentType,
                  containers: _containers,
                  lclTracking: _lclTracking,
                  cfsWarehouse: _cfsWarehouseCtrl.text,
                ),
                onRefresh: widget.onRefreshNeeded,
                onClear: resetForm,
                onSaveDraft: () => _submitForm(isDraftProgressive: true),
                onSaveComplete: () => _submitForm(isDraftProgressive: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
