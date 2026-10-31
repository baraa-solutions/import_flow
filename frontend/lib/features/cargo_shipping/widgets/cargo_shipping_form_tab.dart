import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../freight_booking/models/freight_booking_model.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/cargo_container_defaults.dart';
import '../models/cargo_shipping_model.dart';
import '../providers/cargo_shipping_provider.dart';
import 'cargo_shipping_ui.dart';
import 'container_equipment_assignment_tab.dart';
import 'container_tracking_cards.dart';
import 'shipping_milestone_timeline_widget.dart';

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
  // Form State (2 Focused Steps Only)
  int _activeStepIndex = 0;
  int? _editingRecordId;
  String? _editingRecordCode;
  int? _selectedImportFileId;
  String _shipmentType = 'FCL'; // 'FCL', 'LCL'
  bool _isStackable = true;
  bool _isSaving = false;

  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _cfsWarehouseCtrl = TextEditingController();

  // Milestone Notes State
  final Map<int, String> _selectedMilestoneForNote = {};
  final Map<String, TextEditingController> _milestoneNoteControllers = {};

  List<ContainerLoadingModel> _containers = [];
  LclLoadingTrackingModel? _lclTracking;

  // Lazy step deferral set
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
    for (final c in _milestoneNoteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initDefaultContainer() {
    final nowIso = DateTime.now().toIso8601String();
    _containers = [blankContainer(assignmentDateIso: nowIso)];

    _lclTracking = LclLoadingTrackingModel(
      shipmentType: 'LCL',
      consolidationScheduledDate: nowIso,
      trackingStatus: 'ASSIGNED',
    );
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
      for (final c in _milestoneNoteControllers.values) {
        c.dispose();
      }
      _milestoneNoteControllers.clear();
      _selectedMilestoneForNote.clear();
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

      if (rec.containersLoadingData.isNotEmpty) {
        _containers = List.from(rec.containersLoadingData);
      } else {
        _initDefaultContainer();
      }

      _lclTracking = rec.lclTrackingData;
      _activeStepIndex = 1; // Open container tracking step
      _visitedFormSteps.add(1);
      for (final c in _milestoneNoteControllers.values) {
        c.dispose();
      }
      _milestoneNoteControllers.clear();
      _selectedMilestoneForNote.clear();
    });
    widget.onStepChanged?.call(_activeStepIndex);

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cargoShippingLoadSuccessSnack(rec.importFileCode ?? rec.cargoShippingCode), severity: AppSeverity.info),
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
      if (clonedContainers.isNotEmpty) {
        _containers = clonedContainers;
      } else {
        _initDefaultContainer();
      }
      if (rec.shipmentType == 'LCL' && rec.lclTrackingData != null) {
        final cfsName = rec.lclTrackingData!.cfsWarehouseName ?? 'CFS Warehouse';
        _cfsWarehouseCtrl.text = cfsName;
        _lclTracking = LclLoadingTrackingModel(
          shipmentType: 'LCL',
          cfsWarehouseName: cfsName,
          consolidationScheduledDate: nowIso,
          trackingStatus: 'ASSIGNED',
        );
      }
      _activeStepIndex = 0;
      _visitedFormSteps.add(0);
      for (final c in _milestoneNoteControllers.values) {
        c.dispose();
      }
      _milestoneNoteControllers.clear();
      _selectedMilestoneForNote.clear();
    });
    widget.onStepChanged?.call(_activeStepIndex);
  }

  int? get _linkedBookingId {
    return _linkedBooking?.bookingId;
  }

  ShipmentBookingModel? get _linkedBooking {
    if (_selectedImportFileId == null) return null;
    final bookings = ref.watch(freightBookingProvider).valueOrNull ?? [];
    return bookings.where((b) => b.importFileId == _selectedImportFileId && b.isActive).firstOrNull;
  }

  int get _totalBookingContainersCount {
    final b = _linkedBooking;
    if (b == null || b.containersData.isEmpty) return 0;
    int count = 0;
    for (final alloc in b.containersData) {
      count += alloc.quantity > 0 ? alloc.quantity : math.max(1, alloc.individualContainers.length);
    }
    return count;
  }

  int get _totalRegisteredContainersCount {
    int count = 0;
    for (final c in _containers) {
      count += c.quantity > 0 ? c.quantity : math.max(1, c.individualUnits.length);
    }
    return count;
  }

  String get _bookingContainersSummary {
    final b = _linkedBooking;
    if (b == null || b.containersData.isEmpty) return '';
    return b.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', ');
  }

  Future<void> _onImportFileSelected(int? val) async {
    if (val == null) {
      setState(() => _selectedImportFileId = null);
      return;
    }

    var existingRecords = ref.read(cargoShippingProvider).valueOrNull ?? [];
    if (existingRecords.isEmpty) {
      await ref.read(cargoShippingProvider.notifier).fetchRecords(includeInactive: true);
      existingRecords = ref.read(cargoShippingProvider).valueOrNull ?? [];
    }

    final existingRec = existingRecords.where((r) => r.importFileId == val && r.isActive).firstOrNull;

    if (existingRec != null) {
      loadRecordForEditing(existingRec, showSnack: true);
    } else {
      final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
      final linkedBooking = bookings.where((b) => b.importFileId == val && b.isActive).firstOrNull;

      setState(() {
        _selectedImportFileId = val;
        _editingRecordId = null;
        _editingRecordCode = null;
        for (final c in _milestoneNoteControllers.values) {
          c.dispose();
        }
        _milestoneNoteControllers.clear();

        if (linkedBooking != null) {
          _shipmentType = linkedBooking.shipmentType == 'LCL' ? 'LCL' : 'FCL';
          if (_shipmentType == 'FCL' && linkedBooking.containersData.isNotEmpty) {
            final nowIso = DateTime.now().toIso8601String();
            final List<ContainerLoadingModel> loadedContainers = [];
            for (final alloc in linkedBooking.containersData) {
              final count = alloc.quantity > 0 ? alloc.quantity : math.max(1, alloc.individualContainers.length);
              for (int uIdx = 0; uIdx < count; uIdx++) {
                final indiv = uIdx < alloc.individualContainers.length ? alloc.individualContainers[uIdx] : null;
                final cNo = indiv?.containerNumber ?? '';
                final sNo = indiv?.sealNumber ?? '';
                final vgm = (indiv != null && indiv.vgmWeightKg > 0) ? indiv.vgmWeightKg : 0.0;
                loadedContainers.add(
                  ContainerLoadingModel(
                    containerType: alloc.containerType.isNotEmpty ? alloc.containerType : '40HC',
                    quantity: 1,
                    containerNo: cNo,
                    sealNo: sNo,
                    grossWeightKg: vgm,
                    vgmStatus: 'Pending',
                    containerAssignmentDate: nowIso,
                    trackingStatus: 'ASSIGNED',
                    individualUnits: [
                      {'container_no': cNo, 'seal_no': sNo}
                    ],
                  ),
                );
              }
            }
            if (loadedContainers.isNotEmpty) {
              _containers = loadedContainers;
            } else {
              _initDefaultContainer();
            }
          } else {
            _initDefaultContainer();
          }
        } else {
          _initDefaultContainer();
        }
      });
    }
  }

  void _copyContainerAllocationsManifest() {
    final buffer = StringBuffer();

    final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
    final matchingFiles = importFiles.where((f) => f.importFileId == _selectedImportFileId).toList();
    final curFile = matchingFiles.isNotEmpty ? matchingFiles.first : null;

    final headerTitle = context.l10n.cargoShippingManifestHeader;
    final filePrefix = context.l10n.cargoShippingLinkedFileBannerPrefix;
    final supplierPrefix = context.l10n.cargoShippingSupplierLabel;
    final acidPrefix = context.l10n.cargoShippingAcidPrefix;

    buffer.writeln('# $headerTitle');
    if (curFile != null) {
      buffer.writeln(
        '$filePrefix ${curFile.primaryNameWithCode} - ${curFile.companyName} | $supplierPrefix ${curFile.supplierName}${curFile.acidNumber != null ? " | $acidPrefix: ${curFile.acidNumber}" : ""}',
      );
    }
    buffer.writeln('');

    if (_shipmentType == 'FCL') {
      final colNum = context.l10n.cargoShippingColUnitNumber;
      final colCNo = context.l10n.cargoShippingColContainerNo;
      final colType = context.l10n.cargoShippingColContainerType;
      final colSeal = context.l10n.cargoShippingColSealNo;
      final colGross = context.l10n.cargoShippingColGrossWeight;
      final colVgmStatus = context.l10n.cargoShippingColVgmStatus;
      final colVgmRef = context.l10n.cargoShippingColVgmRef;
      final colStatus = context.l10n.cargoShippingColTrackingStatus;

      buffer.writeln('$colNum\t$colCNo\t$colType\t$colSeal\t$colGross\t$colVgmStatus\t$colVgmRef\t$colStatus');

      int unitCounter = 1;
      for (final c in _containers) {
        final statusLabel = c.getLocalizedStatus(context.l10n);
        if (c.individualUnits.isNotEmpty) {
          for (final u in c.individualUnits) {
            final cNo = u['container_no'] ?? c.containerNo;
            final sNo = u['seal_no'] ?? c.sealNo;
            buffer.writeln('$unitCounter\t$cNo\t${c.containerType}\t$sNo\t${c.grossWeightKg.toStringAsFixed(0)}\t${c.vgmStatus}\t${c.vgmRefNo ?? ""}\t$statusLabel');
            unitCounter++;
          }
        } else {
          buffer.writeln('$unitCounter\t${c.containerNo}\t${c.containerType}\t${c.sealNo}\t${c.grossWeightKg.toStringAsFixed(0)}\t${c.vgmStatus}\t${c.vgmRefNo ?? ""}\t$statusLabel');
          unitCounter++;
        }
      }
    } else {
      final warehouseLabel = context.l10n.cargoShippingCfsWarehouseLabel;
      final statusLabel = _lclTracking?.getLocalizedStatus(context.l10n) ?? context.l10n.cargoShippingStatusAssigned;
      buffer.writeln('${context.l10n.cargoShippingShipmentTypeLabel}\t$warehouseLabel\t${context.l10n.cargoShippingColTrackingStatus}');
      buffer.writeln('LCL\t${_cfsWarehouseCtrl.text}\t$statusLabel');
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: context.l10n.cargoShippingManifestCopySuccess,
    );
  }

  Future<String?> _pickDateTime(BuildContext context, {String? initialIso, DateTime? minDate, String? title}) async {
    final now = DateTime.now();
    final initDt = (initialIso != null && initialIso.isNotEmpty) ? (DateTime.tryParse(initialIso) ?? now) : now;
    final effectiveInit = (minDate != null && initDt.isBefore(minDate)) ? minDate : initDt;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: effectiveInit,
      firstDate: minDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      helpText: title ?? context.l10n.cargoShippingPickMilestone1,
      cancelText: context.l10n.cancel,
      confirmText: context.l10n.confirm,
    );
    if (pickedDate == null) return null;

    if (!context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(effectiveInit),
      helpText: title ?? context.l10n.cargoShippingPickMilestone1,
      cancelText: context.l10n.cancel,
      confirmText: context.l10n.confirm,
    );
    if (pickedTime == null) return null;

    final finalDt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (minDate != null && finalDt.isBefore(minDate)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.cargoShippingDateSequenceError, severity: AppSeverity.danger),
        );
      }
      return null;
    }

    return finalDt.toIso8601String();
  }

  void _duplicateContainer(int index) {
    if (index < 0 || index >= _containers.length) return;
    final item = _containers[index];
    final dupUnits = blankUnits(item.individualUnits.length);
    final dup = ContainerLoadingModel(
      containerType: item.containerType,
      quantity: item.quantity,
      containerNo: '',
      sealNo: '',
      tareWeightKg: item.tareWeightKg,
      netWeightKg: item.netWeightKg,
      grossWeightKg: item.grossWeightKg,
      vgmStatus: 'Pending',
      containerAssignmentDate: DateTime.now().toIso8601String(),
      trackingStatus: 'ASSIGNED',
      individualUnits: dupUnits,
    );
    setState(() {
      _containers.insert(index + 1, dup);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.cshContainerDuplicated(dup.containerType),
        severity: AppSeverity.info,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteContainer(int index) async {
    if (_containers.length <= 1) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: context.l10n.delete,
      message: context.l10n.cargoShippingDeleteConfirmTitle,
      confirmVariant: AppButtonVariant.danger,
    );
    if (confirmed == true) {
      setState(() {
        _containers.removeAt(index);
      });
    }
  }

  Future<void> _quickSaveContainerMilestone(int containerIndex) async {
    final c = _containers[containerIndex];

    if (_selectedImportFileId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.cargoShippingSelectFileFirstForContainer, severity: AppSeverity.warning),
        );
      }
      return;
    }

    if (_editingRecordId == null) {
      final existingRecords = ref.read(cargoShippingProvider).valueOrNull ?? [];
      final existingRec = existingRecords.where((r) => r.importFileId == _selectedImportFileId && r.isActive).firstOrNull;
      if (existingRec != null) {
        _editingRecordId = existingRec.cargoShippingId;
        _editingRecordCode = existingRec.cargoShippingCode;
      }
    }

    if (_editingRecordId != null) {
      setState(() => _isSaving = true);
      try {
        final payload = {
          'container_assignment_date': c.containerAssignmentDate,
          'arrival_at_supplier_at': c.arrivalAtSupplierAt,
          'loading_start_at': c.loadingStartAt,
          'loading_end_at': c.loadingEndAt,
          'port_gate_in_at': c.portGateInAt,
          'milestone_notes': c.milestoneNotes,
        };
        final updatedRecord = await ref.read(cargoShippingProvider.notifier).updateContainerTracking(
          _editingRecordId!,
          c.containerNo,
          payload,
        );
        if (mounted) {
          if (updatedRecord != null && updatedRecord.containersLoadingData.isNotEmpty) {
            setState(() {
              _containers = List.from(updatedRecord.containersLoadingData);
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.cargoShippingSaveContainerMilestoneSuccess(c.containerNo, c.getLocalizedStatus(context.l10n)), severity: AppSeverity.success),
          );
        }
      } catch (e) {
        if (e.toString().contains('404')) {
          _editingRecordId = null;
          await _submitForm(isDraftProgressive: true);
        } else if (mounted) {
          final cleanMsg = e is DioException
              ? (e.response?.data?['detail'] ?? e.message ?? 'Server error')
              : e.toString().replaceAll('Exception:', '').trim();
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.cargoShippingQuickSaveError(cleanMsg), severity: AppSeverity.danger),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      await _submitForm(isDraftProgressive: true);
    }
  }

  Future<void> _quickSaveLclMilestone() async {
    if (_lclTracking == null) return;

    if (_selectedImportFileId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.cargoShippingSelectFileFirstForLcl, severity: AppSeverity.warning),
        );
      }
      return;
    }

    if (_editingRecordId == null) {
      final existingRecords = ref.read(cargoShippingProvider).valueOrNull ?? [];
      final existingRec = existingRecords.where((r) => r.importFileId == _selectedImportFileId && r.isActive).firstOrNull;
      if (existingRec != null) {
        _editingRecordId = existingRec.cargoShippingId;
        _editingRecordCode = existingRec.cargoShippingCode;
      }
    }

    if (_editingRecordId != null) {
      setState(() => _isSaving = true);
      try {
        final updatedRecord = await ref.read(cargoShippingProvider.notifier).updateLclTracking(
          _editingRecordId!,
          _lclTracking!.toJson(),
        );
        if (mounted) {
          if (updatedRecord != null && updatedRecord.lclTrackingData != null) {
            setState(() {
              _lclTracking = updatedRecord.lclTrackingData;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.cargoShippingSaveLclMilestoneSuccess(_lclTracking!.getLocalizedStatus(context.l10n)), severity: AppSeverity.success),
          );
        }
      } catch (e) {
        if (e.toString().contains('404')) {
          _editingRecordId = null;
          await _submitForm(isDraftProgressive: true);
        } else if (mounted) {
          final cleanMsg = e is DioException
              ? (e.response?.data?['detail'] ?? e.message ?? 'Server error')
              : e.toString().replaceAll('Exception:', '').trim();
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.cargoShippingLclSaveError(cleanMsg), severity: AppSeverity.danger),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      await _submitForm(isDraftProgressive: true);
    }
  }

  void _smartSimulationAllContainersTracking() {
    final now = DateTime.now();
    final isoNow = now.toIso8601String();

    setState(() {
      if (_shipmentType == 'FCL') {
        for (int i = 0; i < _containers.length; i++) {
          final c = _containers[i];
          _containers[i] = c.copyWith(
            vgmStatus: 'Submitted',
            vgmRefNo: c.vgmRefNo ?? 'VGM-${now.millisecondsSinceEpoch.toString().substring(8)}',
            containerAssignmentDate: c.containerAssignmentDate ?? now.subtract(const Duration(hours: 40)).toIso8601String(),
            arrivalAtSupplierAt: c.arrivalAtSupplierAt ?? now.subtract(const Duration(hours: 30)).toIso8601String(),
            loadingStartAt: c.loadingStartAt ?? now.subtract(const Duration(hours: 24)).toIso8601String(),
            loadingEndAt: c.loadingEndAt ?? now.subtract(const Duration(hours: 12)).toIso8601String(),
            portGateInAt: c.portGateInAt ?? isoNow,
            trackingStatus: 'GATED_IN_AT_PORT',
            isSlaBreached: false,
          );
        }
      } else {
        _lclTracking = LclLoadingTrackingModel(
          shipmentType: 'LCL',
          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
          consolidationScheduledDate: now.subtract(const Duration(hours: 40)).toIso8601String(),
          arrivalAtCfsAt: now.subtract(const Duration(hours: 30)).toIso8601String(),
          stuffingStartAt: now.subtract(const Duration(hours: 24)).toIso8601String(),
          stuffingEndAt: now.subtract(const Duration(hours: 12)).toIso8601String(),
          portGateInAt: isoNow,
          trackingStatus: 'GATED_IN_AT_PORT',
          isSlaBreached: false,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.cshSmartSimDone, severity: AppSeverity.info),
    );
  }

  Future<void> _submitForm({bool isDraftProgressive = false}) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cargoShippingFillRequiredFields, severity: AppSeverity.danger),
      );
      return;
    }

    if (_selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cargoShippingSelectLinkedFilePrompt, severity: AppSeverity.warning),
      );
      return;
    }

    // Validate container count matches booking
    if (_shipmentType == 'FCL' && _linkedBooking != null && _totalBookingContainersCount > 0) {
      if (_totalRegisteredContainersCount != _totalBookingContainersCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cargoShippingBookingMatchRequired(_totalRegisteredContainersCount, _totalBookingContainersCount),
            severity: AppSeverity.danger,
          ),
        );
        return;
      }
    }

    // Check duplicate import file locally first
    final existingRecords = ref.read(cargoShippingProvider).valueOrNull ?? [];
    final dupRecord = existingRecords.where((r) => r.importFileId == _selectedImportFileId && r.isActive).toList();
    if (dupRecord.isNotEmpty && _editingRecordId == null) {
      _editingRecordId = dupRecord.first.cargoShippingId;
      _editingRecordCode = dupRecord.first.cargoShippingCode;
    }

    setState(() => _isSaving = true);

    final payload = buildCargoShippingPayload(
      importFileId: _selectedImportFileId!,
      shipmentType: _shipmentType,
      containers: _containers,
      lclTracking: _lclTracking,
      isEdit: _editingRecordId != null,
      bookingId: _linkedBookingId,
    );

    try {
      CargoShippingModel? resultRecord;
      if (_editingRecordId != null) {
        resultRecord = await ref.read(cargoShippingProvider.notifier).updateRecord(_editingRecordId!, payload);
      } else {
        resultRecord = await ref.read(cargoShippingProvider.notifier).createRecord(payload);
      }

      if (mounted) {
        if (resultRecord != null) {
          setState(() {
            _editingRecordId = resultRecord!.cargoShippingId;
            _editingRecordCode = resultRecord.cargoShippingCode;
            if (resultRecord.containersLoadingData.isNotEmpty) {
              _containers = List.from(resultRecord.containersLoadingData);
            }
            _lclTracking = resultRecord.lclTrackingData;
          });
        }

        if (isDraftProgressive) {
          ref.read(cargoShippingProvider.notifier).fetchRecords(includeInactive: true);
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.cargoShippingDraftSaveSuccess, severity: AppSeverity.success),
          );
        } else {
          ref.invalidate(lifecycleBoardSummaryProvider);
          ref.invalidate(importFilesProvider);
          ref.read(importFilesProvider.notifier).fetchImportFiles();
          ref.read(cargoShippingProvider.notifier).fetchRecords(includeInactive: true);

          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.cargoShippingStudySaveSuccess(_editingRecordCode ?? ""),
              severity: AppSeverity.success,
            ),
          );
          resetForm();
          widget.onSwitchToRegistry?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is DioException
            ? (e.response?.data is Map && e.response?.data?['detail'] != null
                ? e.response!.data['detail'].toString()
                : (e.message ?? 'Server error'))
            : e.toString().replaceAll('Exception:', '').trim();
        final goToSaved = await AppConfirmDialog.show(
          context,
          title: context.l10n.cargoShippingDuplicateWarningTitle,
          message: errorMsg,
          icon: Icons.warning_amber_rounded,
          confirmLabel: context.l10n.cargoShippingGoToSavedRegistry,
          cancelLabel: context.l10n.close,
          confirmVariant: AppButtonVariant.warning,
        );
        if (goToSaved && mounted) {
          widget.onSwitchToRegistry?.call();
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updateContainerTimestamp(
    int index, {
    String? assignmentDate,
    String? arrival,
    String? loadingStart,
    String? loadingEnd,
    String? gateIn,
  }) {
    final c = _containers[index];
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

    setState(() {
      _containers[index] = c.copyWith(
        containerAssignmentDate: assign,
        arrivalAtSupplierAt: arr,
        loadingStartAt: lStart,
        loadingEndAt: lEnd,
        portGateInAt: gIn,
        trackingStatus: newStatus,
      );
    });
  }

  Widget _buildStep1ContainerAssignment(
    List<dynamic> importFiles,
    double totalCargoCbm,
    double totalCargoWeightKg,
    ContainerRecommendationResult? activeContainerRec,
  ) {
    final existingRecords = ref.watch(cargoShippingProvider).valueOrNull ?? [];
    final existingActiveFileIds = {for (final r in existingRecords) if (r.isActive) r.importFileId};

    return ContainerEquipmentAssignmentTab(
      importFiles: importFiles,
      existingActiveFileIds: existingActiveFileIds,
      selectedImportFileId: _selectedImportFileId,
      onImportFileSelected: (val) => _onImportFileSelected(val),
      shipmentType: _shipmentType,
      onShipmentTypeChanged: (val) => setState(() => _shipmentType = val),
      isStackable: _isStackable,
      onStackableChanged: (val) => setState(() => _isStackable = val),
      activeContainerRec: activeContainerRec,
      totalCargoCbm: totalCargoCbm,
      totalCargoWeightKg: totalCargoWeightKg,
      linkedBooking: _linkedBooking,
      totalBookingContainersCount: _totalBookingContainersCount,
      totalRegisteredContainersCount: _totalRegisteredContainersCount,
      bookingContainersSummary: _bookingContainersSummary,
      containers: _containers,
      onAddContainer: () {
        setState(() {
          _containers.add(blankContainer(assignmentDateIso: DateTime.now().toIso8601String()));
        });
      },
      onDuplicateContainer: _duplicateContainer,
      onDeleteContainer: _deleteContainer,
      onUpdateContainer: (index, updated) {
        setState(() {
          _containers[index] = updated;
        });
      },
      cfsWarehouseController: _cfsWarehouseCtrl,
    );
  }

  Widget _buildStep2ContainerLoadingTracking(List<dynamic> importFiles, dynamic curFile) {
    final existingRecords = ref.watch(cargoShippingProvider).valueOrNull ?? [];

    int totalCount = _shipmentType == 'FCL' ? _containers.length : 1;
    int gatedInCount = 0;
    int inProgressCount = 0;
    int breachedCount = 0;

    if (_shipmentType == 'FCL') {
      for (var c in _containers) {
        if (c.trackingStatus == 'GATED_IN_AT_PORT') gatedInCount++;
        if (c.trackingStatus == 'LOADING_IN_PROGRESS' || c.trackingStatus == 'ARRIVED_AT_SUPPLIER') inProgressCount++;
        if (c.isSlaBreached) breachedCount++;
      }
    } else if (_lclTracking != null) {
      if (_lclTracking!.trackingStatus == 'GATED_IN_AT_PORT') gatedInCount = 1;
      if (_lclTracking!.isSlaBreached) breachedCount = 1;
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
            boxShadow: [BoxShadow(color: AppTheme.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
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
                      value: _selectedImportFileId,
                      items: [
                        SearchableDropdownItem<int?>(value: null, label: context.l10n.cargoShippingImportFileDefault),
                        ...importFiles.map((f) {
                          final hasExisting = existingRecords.any((r) => r.importFileId == f.importFileId && r.isActive);
                          return SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label: '${f.primaryNameWithCode} - ${f.companyName} | ACID: ${f.acidNumber ?? "N/A"}${hasExisting ? " ${context.l10n.cargoShippingPreviouslyRegistered}" : ""}',
                            subtitle: f.supplierName,
                          );
                        }),
                      ],
                      onChanged: (val) => _onImportFileSelected(val),
                      validator: (v) => v == null ? context.l10n.cargoShippingSelectFileValidator : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SearchableDropdownField<String>(
                      labelText: context.l10n.cargoShippingShipmentTypeLabel,
                      value: _shipmentType,
                      items: [
                        SearchableDropdownItem(value: 'FCL', label: context.l10n.cargoShippingFclLabel),
                        SearchableDropdownItem(value: 'LCL', label: context.l10n.cargoShippingLclLabel),
                      ],
                      onChanged: (val) => setState(() => _shipmentType = val ?? 'FCL'),
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
        _buildSlaExportToolbar(curFile, totalCount, inProgressCount, gatedInCount, breachedCount),

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

        // FCL Mode: Individual Container Cards
        if (_shipmentType == 'FCL') ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _containers.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final container = _containers[index];
              return _buildFclContainerTrackingCard(container, index);
            },
          ),
        ] else ...[
          _buildLclConsolidationTrackingCard(),
        ],
      ],
    );
  }

  Widget _buildSlaExportToolbar(dynamic curFile, int totalCount, int inProgressCount, int gatedInCount, int breachedCount) {
    return ShippingSlaExportToolbar(
      curFile: curFile,
      totalCount: totalCount,
      inProgressCount: inProgressCount,
      gatedInCount: gatedInCount,
      breachedCount: breachedCount,
      shipmentType: _shipmentType,
      containers: _containers,
      lclTracking: _lclTracking,
      cfsWarehouse: _cfsWarehouseCtrl.text,
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
      totalContainersCount: _containers.length,
      onQuickSave: () => _quickSaveContainerMilestone(index),
      onEdit: () {
        setState(() => _activeStepIndex = 0);
        widget.onStepChanged?.call(0);
      },
      onClone: () => _duplicateContainer(index),
      onDelete: _containers.length > 1 ? () => _deleteContainer(index) : null,
      onUpdateTimestamps: ({assignmentDate, arrival, loadingStart, loadingEnd, gateIn}) {
        _updateContainerTimestamp(
          index,
          assignmentDate: assignmentDate,
          arrival: arrival,
          loadingStart: loadingStart,
          loadingEnd: loadingEnd,
          gateIn: gateIn,
        );
      },
      onPickDateTime: _pickDateTime,
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
        setState(() {
          _containers[index] = c.copyWith(milestoneNotes: updatedNotes);
        });
        _quickSaveContainerMilestone(index);
      },
      onClearNote: () {
        ctrl.clear();
        final updatedNotes = Map<String, String>.from(c.milestoneNotes);
        updatedNotes.remove(selectedStep);
        setState(() {
          _containers[index] = c.copyWith(milestoneNotes: updatedNotes);
        });
        _quickSaveContainerMilestone(index);
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
    final lcl = _lclTracking ??
        LclLoadingTrackingModel(
          shipmentType: 'LCL',
          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
          consolidationScheduledDate: DateTime.now().toIso8601String(),
          trackingStatus: 'ASSIGNED',
        );

    return LclConsolidationTrackingCard(
      lclTracking: lcl,
      cfsWarehouse: _cfsWarehouseCtrl.text,
      onQuickSave: _quickSaveLclMilestone,
      onUpdateLclTracking: (updated) {
        setState(() => _lclTracking = updated);
      },
      onPickDateTime: _pickDateTime,
    );
  }

  Widget _buildBottomActionToolbar() {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecorationOf(context),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (kDebugMode)
            Tooltip(
              message: l.cshSmartSimTooltip,
              child: CcUi.fit(AppButton(
                label: l.cshSmartSimBtn,
                icon: Icons.auto_awesome,
                variant: AppButtonVariant.saveDraft,
                size: AppButtonSize.small,
                onPressed: _smartSimulationAllContainersTracking,
              )),
            ),
          CcUi.fit(AppButton(
            label: l.cargoShippingExportManifestBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: _copyContainerAllocationsManifest,
          )),
          CcUi.fit(AppButton(
            label: l.liveReload,
            icon: Icons.refresh,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: widget.onRefreshNeeded,
          )),
          CcUi.fit(AppButton(
            label: l.cargoShippingClearStartNew,
            icon: Icons.cleaning_services_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: resetForm,
          )),
          CcUi.fit(AppButton(
            label: l.cargoShippingSaveDraft,
            icon: Icons.save_outlined,
            variant: AppButtonVariant.saveDraft,
            size: AppButtonSize.small,
            onPressed: _isSaving ? null : () => _submitForm(isDraftProgressive: true),
          )),
          CcUi.fit(AppButton(
            label: _editingRecordId != null ? l.cshUpdateCompleteBtn : l.cshSaveCompleteBtn,
            icon: Icons.verified_outlined,
            variant: AppButtonVariant.success,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : () => _submitForm(isDraftProgressive: false),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final poState = ref.watch(purchaseOrdersProvider);
    final poList = poState.purchaseOrders;

    // Selected file details for top banner
    final matchingFiles = importFiles.where((f) => f.importFileId == _selectedImportFileId).toList();
    final curFile = matchingFiles.isNotEmpty ? matchingFiles.first : null;

    // Calculate aggregated cargo metrics from linked POs / Packing Lists
    double totalCargoCbm = 0.0;
    double totalCargoWeightKg = 0.0;
    if (_selectedImportFileId != null && curFile != null) {
      final filePos = ImportFilePoLinker.getLinkedPOs(file: curFile, allPOs: poList);
      final metrics = ImportFilePoLinker.computeMetrics(file: curFile, linkedPOs: filePos);
      totalCargoCbm = metrics.cbm;
      totalCargoWeightKg = metrics.weightKg;
    }

    final dualRec = dualRecommendationOrNull(totalCbm: totalCargoCbm, totalWeightKg: totalCargoWeightKg);
    final activeContainerRec = dualRec == null
        ? null
        : (_isStackable ? dualRec.stackableResult : dualRec.nonStackableResult);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Active File Banner
            if (_selectedImportFileId != null && curFile != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: ShippingLinkedFileBanner(
                  fileLabel: curFile.primaryNameWithCode,
                  companyName: curFile.companyName,
                  supplierName: curFile.supplierName,
                  acidNumber: curFile.acidNumber,
                  recordCode: _editingRecordCode,
                  onCancelEdit: _editingRecordId != null ? resetForm : null,
                ),
              ),
            // Stepper Navigation Sub-Tabs (2 Steps Only)
            ShippingStepSwitcher(
              selectedIndex: _activeStepIndex,
              titles: [context.l10n.cargoShippingStep1Title, context.l10n.cargoShippingStep2Title],
              icons: const [Icons.inventory_2_outlined, Icons.timelapse_outlined],
              onSelected: (index) => setState(() {
                _activeStepIndex = index;
                _visitedFormSteps.add(index);
                widget.onStepChanged?.call(index);
              }),
            ),
            const SizedBox(height: 14),

            // Step Content Area
            IndexedStack(
              index: _activeStepIndex,
              children: [
                _visitedFormSteps.contains(0)
                    ? _buildStep1ContainerAssignment(importFiles, totalCargoCbm, totalCargoWeightKg, activeContainerRec)
                    : const SizedBox.shrink(),
                _visitedFormSteps.contains(1)
                    ? _buildStep2ContainerLoadingTracking(importFiles, curFile)
                    : const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 16),

            // Bottom Action Toolbar
            _buildBottomActionToolbar(),
          ],
        ),
      ),
    );
  }
}
