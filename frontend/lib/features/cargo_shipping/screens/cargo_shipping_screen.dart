import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../../core/widgets/widgets.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../import_documentation/widgets/smart_invoice_bl_extractor_dialog.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/cargo_container_defaults.dart';
import '../models/cargo_shipping_model.dart';
import '../providers/cargo_shipping_provider.dart';
import '../services/cargo_shipping_sla_export_service.dart';
import '../../lifecycle_board/providers/lifecycle_board_provider.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../widgets/search_and_clone_cargo_shipping_dialog.dart';
import '../widgets/cargo_shipping_ui.dart';
import '../../customs_clearance/widgets/customs_ui.dart';


class CargoShippingScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  const CargoShippingScreen({super.key, this.initialSubTab = 0});

  @override
  ConsumerState<CargoShippingScreen> createState() => _CargoShippingScreenState();
}

class _CargoShippingScreenState extends ConsumerState<CargoShippingScreen> with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  final TextEditingController _searchController = TextEditingController();

  // Registry Filters
  String _registryStatusFilter = 'All';
  String _registrySlaFilter = 'All'; // 'All', 'OnTime', 'Breached'
  String _registryActiveFilter = 'Active'; // 'All', 'Active', 'Deleted'

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

  // Lazy tab & step deferral sets
  final Set<int> _visitedMainTabs = {0};
  late final Set<int> _visitedFormSteps;

  @override
  void initState() {
    super.initState();
    _activeStepIndex = widget.initialSubTab.clamp(0, 1);
    _visitedMainTabs.add(0);
    _visitedFormSteps = {_activeStepIndex};
    _mainTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        if (!_visitedMainTabs.contains(_mainTabController.index)) {
          setState(() {
            _visitedMainTabs.add(_mainTabController.index);
          });
        }
      }
    });
    _initDefaultContainer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  void didUpdateWidget(covariant CargoShippingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubTab != widget.initialSubTab) {
      setState(() {
        _activeStepIndex = widget.initialSubTab.clamp(0, 1);
        _visitedFormSteps.add(_activeStepIndex);
        _mainTabController.index = 0;
        _visitedMainTabs.add(0);
      });
    }
  }

  void _initDefaultContainer() {
    final nowIso = DateTime.now().toIso8601String();
    // No invented container / seal / VGM / CFS values: the user enters the real ones.
    _containers = [blankContainer(assignmentDateIso: nowIso)];

    _lclTracking = LclLoadingTrackingModel(
      shipmentType: 'LCL',
      consolidationScheduledDate: nowIso,
      trackingStatus: 'ASSIGNED',
    );
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _searchController.dispose();
    _cfsWarehouseCtrl.dispose();
    for (final c in _milestoneNoteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _refreshAllData() {
    if (!ref.read(cargoShippingProvider).isLoading) {
      ref.read(cargoShippingProvider.notifier).fetchRecords(includeInactive: true);
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(freightBookingProvider).isLoading) {
      ref.read(freightBookingProvider.notifier).fetchBookings();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
  }

  void _resetForm() {
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
      _initDefaultContainer();
    });
  }

  void _loadRecordForEditing(CargoShippingModel rec, {bool showSnack = true}) {
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

    _visitedMainTabs.add(0);
    _mainTabController.animateTo(0);
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cargoShippingLoadSuccessSnack(rec.importFileCode ?? rec.cargoShippingCode), severity: AppSeverity.info),
      );
    }
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
      // Automatically load the saved draft/record seamlessly!
      _loadRecordForEditing(existingRec, showSnack: true);
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
              for (int uIdx = 0; uIdx < alloc.individualContainers.length; uIdx++) {
                final indiv = alloc.individualContainers[uIdx];
                // Only what the freight booking really recorded; blank otherwise.
                final cNo = indiv.containerNumber;
                final sNo = indiv.sealNumber;
                loadedContainers.add(
                  ContainerLoadingModel(
                    containerType: alloc.containerType.isNotEmpty ? alloc.containerType : '40HC',
                    quantity: 1,
                    containerNo: cNo,
                    sealNo: sNo,
                    grossWeightKg: indiv.vgmWeightKg > 0 ? indiv.vgmWeightKg : 0,
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

  String _getLocalizedContainerTypeLabel(String type) {
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

  void _openSearchAndCloneShippingDialog(List<CargoShippingModel> records) {
    final l = context.l10n;
    final isAr = l.isArabic;
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: SearchAndCloneCargoShippingDialog(
            records: records,
            onSelectRecord: (selected) => _onCloneCargoShipping(selected),
          ),
        ),
      ),
    );
  }

  void _onCloneCargoShipping(CargoShippingModel rec) {
    final l = context.l10n;
    final isAr = l.isArabic;
    final newDraftCode = 'SHP-DRAFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final containerSummary = rec.containersLoadingData.isNotEmpty
        ? rec.containersLoadingData.map((c) => '${c.quantity}x ${c.containerType}').join(', ')
        : (rec.shipmentType == 'LCL' ? l.cshLclConsolidation : l.cshStandard40hc);

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: isAr ? const Locale('ar') : const Locale('en'),
        child: Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: CloneEntityReviewDialog(
            entityType: l.cshCloneEntityType,
            sourceCode: rec.cargoShippingCode,
            suggestedNewCode: newDraftCode,
            sourceTitle: '${rec.importFileCode ?? "IMP-${rec.importFileId}"} - ${rec.companyName ?? ""}',
            copiedFieldsSummary: {
              l.cshCloneFieldShipmentType: rec.shipmentType,
              l.cshCloneFieldContainers: containerSummary,
              l.cshCloneFieldVgm: l.cshWeightKg(rec.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg).toStringAsFixed(0)),
              if (rec.shipmentType == 'LCL' && rec.lclTrackingData?.cfsWarehouseName != null)
                l.cshCloneFieldCfs: rec.lclTrackingData!.cfsWarehouseName ?? '',
            },
            mandatorilyResetFields: [
              l.cshCloneReset1,
              l.cshCloneReset2,
              l.cshCloneReset3,
              l.cshCloneReset4,
              l.cshCloneReset5,
            ],
            allowCopyLineItems: true,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              final nowIso = DateTime.now().toIso8601String();
              final List<ContainerLoadingModel> clonedContainers = [];

              if (copyLineItems && rec.containersLoadingData.isNotEmpty) {
                for (final c in rec.containersLoadingData) {
                  // Container / seal / VGM numbers are reset on clone (never invented).
                  final dupUnits = blankUnits(c.individualUnits.length);

                  clonedContainers.add(
                    ContainerLoadingModel(
                      containerType: c.containerType,
                      quantity: c.quantity,
                      containerNo: '',
                      sealNo: '',
                      tareWeightKg: c.tareWeightKg,
                      netWeightKg: c.netWeightKg,
                      grossWeightKg: c.grossWeightKg,
                      vgmStatus: 'Pending',
                      containerAssignmentDate: nowIso,
                      trackingStatus: 'ASSIGNED',
                      individualUnits: dupUnits,
                    ),
                  );
                }
              }

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

              _visitedMainTabs.add(0);
              _mainTabController.animateTo(0);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  AppTheme.snackBar(context, '${l.cloneCargoShippingTooltip}: $newCode', severity: AppSeverity.info),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _copyShippingRowTsv(CargoShippingModel rec, AppLocalizations l) {
    final containerSummary = rec.containersLoadingData
        .map((c) => '${c.containerNo} (${c.containerType})')
        .join(', ');
    final gatedCount = rec.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
    final hasBreach = rec.containersLoadingData.any((c) => c.isSlaBreached) || (rec.lclTrackingData?.isSlaBreached ?? false);

    final rowData = [
      rec.cargoShippingCode,
      rec.importFileCode ?? 'IMP-${rec.importFileId}',
      rec.companyName ?? '',
      rec.shipmentType,
      containerSummary,
      rec.status,
      '$gatedCount/${rec.containersLoadingData.length}',
      hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
      rec.isActive ? l.cshStateActive : l.cshStateDeleted,
    ];

    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainersSeals,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    TableCopyHelper.copyRow(
      context,
      rowData,
      headers: headers,
      includeHeaders: true,
      customMessage: l.copyCargoShippingRowSuccess,
    );
  }

  void _copyShippingTableTsv(List<CargoShippingModel> records, AppLocalizations l) {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainers,
      l.cshColTotalVgm,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '',
        r.shipmentType,
        containerSummary,
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
        r.isActive ? l.cshStateActive : l.cshStateDeleted,
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.copyCargoShippingTableSuccess,
    );
  }

  Future<void> _exportShippingExcel(List<CargoShippingModel> records, AppLocalizations l) async {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainers,
      l.cshColTotalVgm,
      l.cshColStatus,
      l.cshColGateIn,
      l.cshColSla,
      l.cshColOp,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '',
        r.shipmentType,
        containerSummary,
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
        r.isActive ? l.cshStateActive : l.cshStateDeleted,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Cargo Shipping',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _exportShippingPdf(List<CargoShippingModel> records, AppLocalizations l) async {
    final headers = [
      l.cshColCode,
      l.cshColImportFile,
      l.cshColCompany,
      l.cshColShipType,
      l.cshColContainersShort,
      l.cshColWeightShort,
      l.cshColStatus,
      l.cshColGateInShort,
      l.cshColSlaShort,
    ];

    final rows = records.map((r) {
      final containerSummary = r.containersLoadingData
          .map((c) => '${c.containerNo} (${c.containerType})')
          .join(', ');
      final totalVgm = r.containersLoadingData.fold<double>(0.0, (acc, c) => acc + c.grossWeightKg);
      final gatedCount = r.containersLoadingData.where((c) => c.trackingStatus == 'GATED_IN_AT_PORT').length;
      final hasBreach = r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false);

      return [
        r.cargoShippingCode,
        r.importFileCode ?? 'IMP-${r.importFileId}',
        r.companyName ?? '—',
        r.shipmentType,
        containerSummary.isNotEmpty ? containerSummary : '—',
        l.cshWeightKg(totalVgm.toStringAsFixed(0)),
        r.status,
        '$gatedCount/${r.containersLoadingData.length}',
        hasBreach ? l.cargoShippingSlaBreached : l.cargoShippingSlaOnTime,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'Cargo Shipping',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
      headerContext: TableExportHeaderContext(
        title: l.cshPdfTitle,
        subtitle: l.cshPdfSubtitle,
        metadata: {
          l.cshPdfMetaTotal: records.length.toString(),
          l.cshPdfMetaFcl: records.where((r) => r.shipmentType == 'FCL').length.toString(),
          l.cshPdfMetaLcl: records.where((r) => r.shipmentType == 'LCL').length.toString(),
        },
      ),
    );
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

  // ===========================================================================
  // DATE & TIME PICKER HELPERS
  // ===========================================================================
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

  // ===========================================================================
  // PROGRESSIVE / QUICK SAVE FOR CONTAINER MILESTONE
  // ===========================================================================
  Future<void> _quickSaveContainerMilestone(int containerIndex) async {
    final c = _containers[containerIndex];

    // If no import file is selected yet, prompt the user
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
          _resetForm();
          _visitedMainTabs.add(1);
          _mainTabController.animateTo(1);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is DioException
            ? (e.response?.data is Map && e.response?.data?['detail'] != null
                ? e.response!.data['detail'].toString()
                : (e.message ?? 'Server error'))
            : e.toString().replaceAll('Exception:', '').trim();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.severityForegroundOf(context, AppSeverity.warning), size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(context.l10n.cargoShippingDuplicateWarningTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            content: Text(errorMsg, style: const TextStyle(fontSize: 13, height: 1.5)),
            actions: [
              AppButton(
                label: context.l10n.close,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => Navigator.pop(ctx),
              ),
              AppButton(
                label: context.l10n.cargoShippingGoToSavedRegistry,
                icon: Icons.history_edu_outlined,
                size: AppButtonSize.small,
                onPressed: () {
                  Navigator.pop(ctx);
                  _mainTabController.animateTo(1);
                },
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const VerticalNavTabItem(
        icon: Icons.local_shipping_outlined,
        titleEn: 'Loading & Tracking Form',
        titleAr: 'تجهيز الشحن ومتابعة التحميل',
      ),
      const VerticalNavTabItem(
        icon: Icons.history_edu_outlined,
        titleEn: 'Saved Cargo Registry',
        titleAr: 'سجل متابعة الشحنات والتحميل',
      ),
    ];
    final isTrackingTab = _activeStepIndex == 1;

    return VerticalStageScaffold(
      stageCode: isTrackingTab ? 'STEP-08' : 'STEP-07',
      titleEn: isTrackingTab ? 'Cargo Shipping Tracking (48h SLA)' : 'Freight Allocations & Cargo Shipping (VGM)',
      titleAr: isTrackingTab ? context.l10n.cargoShippingSlaStageTitle : context.l10n.cargoShippingAllocationsTitle,
      headerIcon: isTrackingTab ? Icons.directions_boat_outlined : Icons.grid_view_outlined,
      headerColor: isTrackingTab ? AppTheme.cobalt : AppTheme.emerald,
      tabs: tabs,
      selectedIndex: _mainTabController.index,
      onTabSelected: (index) => setState(() {
        _mainTabController.index = index;
        _visitedMainTabs.add(index);
      }),
      selectedImportFileId: _selectedImportFileId,
      onShipmentStatusChanged: () {
        ref.read(importFilesProvider.notifier).fetchImportFiles();
      },
      headerActions: [
        AppButton(
          label: context.l10n.cargoShippingAiExtractorBtn,
          icon: Icons.auto_awesome,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => SmartInvoiceBLExtractorDialog(
                initialImportFileId: _selectedImportFileId,
                initialTabIndex: 1,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        SmartUploadButton(
          module: SmartUploadModule.cargoShipping,
          label: context.l10n.cargoShippingUploadBlLabel,

          onDataExtracted: (result) {
            final fields = result.extractedFields;
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(context, context.l10n.cargoShippingUploadBlSuccess(fields['bl_number'] ?? 'N/A'), severity: AppSeverity.success, duration: const Duration(seconds: 5)),
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.70)),
          tooltip: context.l10n.liveReload,
          onPressed: _refreshAllData,
        ),
      ],
      body: SelectionArea(
        child: IndexedStack(
          index: _mainTabController.index,
          children: [
            _visitedMainTabs.contains(0) ? _buildInteractiveShippingFormTab() : const SizedBox.shrink(),
            _visitedMainTabs.contains(1) ? _buildSavedShippingRegistryTab() : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: INTERACTIVE FORM & 2-STEP WORKSPACE
  // ===========================================================================
  Widget _buildInteractiveShippingFormTab() {
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

    // Real metrics only: a file without CBM / weight shows "missing" and nothing is computed.
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
                  onCancelEdit: _editingRecordId != null ? _resetForm : null,
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

  // ================= STEP 1: CONTAINERS & VGM ASSIGNMENT =================
  Widget _buildStep1ContainerAssignment(
    List<dynamic> importFiles,
    double totalCargoCbm,
    double totalCargoWeightKg,
    ContainerRecommendationResult? activeContainerRec,
  ) {
    final existingRecords = ref.watch(cargoShippingProvider).valueOrNull ?? [];
    final existingActiveFileIds = {for (final r in existingRecords) if (r.isActive) r.importFileId};

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
                  labelText: context.l10n.cargoShippingImportFileLabel,
                  hintText: context.l10n.cargoShippingImportFileHint,
                  value: _selectedImportFileId,
                  items: [
                    SearchableDropdownItem<int?>(value: null, label: context.l10n.cargoShippingImportFileDefault),
                    ...importFiles.map((f) {
                      final hasExisting = existingActiveFileIds.contains(f.importFileId);
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
                              context.l10n.cshCargoMetricsMissing,
                              key: const Key('cargoMetricsMissing'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.orange),
                            )
                          : CopyableText(
                              context.l10n.cargoShippingAggregatedCargoMetrics(totalCargoCbm.toStringAsFixed(2), totalCargoWeightKg.toStringAsFixed(0)),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.cobalt),
                              tooltip: context.l10n.cargoShippingCopyFieldTooltip,
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
                    Text(context.l10n.cargoShippingCargoStackingLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ChoiceChip(
                      label: Text(context.l10n.cargoShippingStackable),
                      selected: _isStackable,
                      onSelected: (val) => setState(() => _isStackable = val),
                    ),
                    ChoiceChip(
                      label: Text(context.l10n.cargoShippingNonStackable),
                      selected: !_isStackable,
                      onSelected: (val) => setState(() => _isStackable = !val),
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
                    context.l10n.cargoShippingAutoRecommendation(
                      activeContainerRec.requiredContainersCount,
                      activeContainerRec.recommendedContainerCode,
                      activeContainerRec.spaceUtilizationPercent.toStringAsFixed(1),
                      activeContainerRec.payloadUtilizationPercent.toStringAsFixed(1),
                    ),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                    tooltip: context.l10n.cargoShippingCopyFieldTooltip,
                  ),
                ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Container Allocation Header
          if (_shipmentType == 'FCL') ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(context.l10n.cargoShippingContainersHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                AppButton(
                  label: context.l10n.cargoShippingAddContainerType,
                  icon: Icons.add,
                  size: AppButtonSize.small,
                  onPressed: () {
                    setState(() {
                      _containers.add(blankContainer(assignmentDateIso: DateTime.now().toIso8601String()));
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Container Equipment List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _containers.length,
              separatorBuilder: (c, i) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final item = _containers[index];
                return _buildContainerEquipmentCard(item, index);
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
                  Text(context.l10n.cargoShippingCfsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _cfsWarehouseCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.cargoShippingCfsWarehouseLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.warehouse, color: AppTheme.cobalt),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: context.l10n.cargoShippingCopyFieldTooltip,
                        onPressed: () => CopyHelper.copy(context, _cfsWarehouseCtrl.text),
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

  Widget _buildContainerEquipmentCard(ContainerLoadingModel item, int index) {
    final qty = item.quantity;
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
                  labelText: context.l10n.cargoShippingContainerType,
                  items: [
                    SearchableDropdownItem(value: '20GP', label: _getLocalizedContainerTypeLabel('20GP')),
                    SearchableDropdownItem(value: '40GP', label: _getLocalizedContainerTypeLabel('40GP')),
                    SearchableDropdownItem(value: '40HC', label: _getLocalizedContainerTypeLabel('40HC')),
                    SearchableDropdownItem(value: '45HC', label: _getLocalizedContainerTypeLabel('45HC')),
                    SearchableDropdownItem(value: '20RF', label: _getLocalizedContainerTypeLabel('20RF')),
                    SearchableDropdownItem(value: '40RF', label: _getLocalizedContainerTypeLabel('40RF')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _containers[index] = item.copyWith(containerType: val);
                      });
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
                  decoration: InputDecoration(labelText: context.l10n.cargoShippingQty, border: const OutlineInputBorder()),
                  onChanged: (val) {
                    final q = int.tryParse(val) ?? 1;
                    setState(() {
                      final units = item.individualUnits.map((u) => Map<String, String>.from(u)).toList();
                      while (units.length < q) {
                        units.add({'container_no': '', 'seal_no': ''});
                      }
                      if (units.length > q) units.removeRange(q, units.length);
                      _containers[index] = item.copyWith(
                        quantity: q,
                        containerNo: units.isNotEmpty ? units.first['container_no'] ?? '' : '',
                        sealNo: units.isNotEmpty ? units.first['seal_no'] ?? '' : '',
                        individualUnits: units,
                      );
                    });
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
                    labelText: context.l10n.cargoShippingVgmWeight,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: context.l10n.cargoShippingCopyFieldTooltip,
                      onPressed: () => CopyHelper.copy(context, item.grossWeightKg.toStringAsFixed(0)),
                    ),
                  ),
                  onChanged: (val) {
                    final w = double.tryParse(val) ?? 0.0;
                    setState(() {
                      _containers[index] = item.copyWith(grossWeightKg: w);
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Task E: Table Row-Level Container Duplicate
              Tooltip(
                message: context.l10n.cargoShippingDuplicateContainerTooltip,
                child: IconButton(
                  key: Key('duplicateContainerBtn_$index'),
                  icon: const Icon(Icons.copy_rounded, color: AppTheme.cobalt),
                  onPressed: () {
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
                      AppTheme.snackBar(context, context.l10n.cshContainerDuplicated(dup.containerType), severity: AppSeverity.info, duration: const Duration(seconds: 2)),
                    );
                  },
                ),
              ),
              if (_containers.length > 1) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: Key('deleteContainerBtn_$index'),
                  icon: const Icon(Icons.delete, color: AppTheme.crimson),
                  onPressed: () => setState(() => _containers.removeAt(index)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Per-Unit Container No & Seal No Fields
          Text(context.l10n.cargoShippingUnitDetailsHeader, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondaryOf(context))),
          const SizedBox(height: 6),
          ...List.generate(qty, (unitIdx) {
            final units = item.individualUnits;
            final curCNo = unitIdx < units.length ? (units[unitIdx]['container_no'] ?? '') : item.containerNo;
            final curSNo = unitIdx < units.length ? (units[unitIdx]['seal_no'] ?? '') : item.sealNo;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(context.l10n.cargoShippingUnitPrefix(unitIdx + 1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: TextFormField(
                      initialValue: curCNo,
                      decoration: InputDecoration(
                        labelText: context.l10n.cargoShippingContainerNo,
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: context.l10n.cargoShippingCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, curCNo),
                        ),
                      ),
                      onChanged: (cVal) {
                        final updatedUnits = item.individualUnits.map((u) => Map<String, String>.from(u)).toList();
                        while (updatedUnits.length <= unitIdx) {
                          updatedUnits.add({'container_no': '', 'seal_no': ''});
                        }
                        updatedUnits[unitIdx]['container_no'] = cVal;
                        _containers[index] = item.copyWith(
                          containerNo: updatedUnits.first['container_no'] ?? '',
                          sealNo: updatedUnits.first['seal_no'] ?? '',
                          individualUnits: updatedUnits,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: curSNo,
                      decoration: InputDecoration(
                        labelText: context.l10n.cargoShippingSealNo,
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: context.l10n.cargoShippingCopyFieldTooltip,
                          onPressed: () => CopyHelper.copy(context, curSNo),
                        ),
                      ),
                      onChanged: (sVal) {
                        final updatedUnits = item.individualUnits.map((u) => Map<String, String>.from(u)).toList();
                        while (updatedUnits.length <= unitIdx) {
                          updatedUnits.add({'container_no': '', 'seal_no': ''});
                        }
                        updatedUnits[unitIdx]['seal_no'] = sVal;
                        _containers[index] = item.copyWith(
                          containerNo: updatedUnits.first['container_no'] ?? '',
                          sealNo: updatedUnits.first['seal_no'] ?? '',
                          individualUnits: updatedUnits,
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


  // ================= STEP 2: CONTAINER LOADING FOLLOW-UP & 48H SLA TRACKING =================
  Widget _buildStep2ContainerLoadingTracking(List<dynamic> importFiles, dynamic curFile) {
    final existingRecords = ref.watch(cargoShippingProvider).valueOrNull ?? [];

    // Calculate summary statistics
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

        // SLA Export Toolbar (TSV, Excel, Print/PDF, Dossier)
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
          // LCL Mode: Single CFS Consolidation Card
          _buildLclConsolidationTrackingCard(),
        ],
      ],
    );
  }

  /// Toolbar providing TSV, Excel, Vector PDF, and Dossier exports for 48h SLA Tracking.
  Widget _buildSlaExportToolbar(dynamic curFile, int totalCount, int inProgressCount, int gatedInCount, int breachedCount) {
    final l10n = context.l10n;
    final fileModel = curFile is ImportFileModel ? curFile : null;
    final exportService = CargoShippingSlaExportService(
      context: context,
      importFile: fileModel,
      shipmentType: _shipmentType,
      containers: _containers,
      lclTracking: _lclTracking,
      cfsWarehouse: _cfsWarehouseCtrl.text.trim(),
      totalCount: totalCount,
      inProgressCount: inProgressCount,
      gatedInCount: gatedInCount,
      breachedCount: breachedCount,
    );

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 14),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.toolbarDecorationOf(context),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CcUi.fit(AppButton(
            label: l10n.cargoShippingSlaExportTsvBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: () => exportService.exportToTsv(),
          )),
          CcUi.fit(AppButton(
            label: l10n.cargoShippingSlaExportExcelBtn,
            icon: Icons.table_chart,
            variant: AppButtonVariant.success,
            size: AppButtonSize.small,
            onPressed: () => exportService.exportToExcel(),
          )),
          CcUi.fit(AppButton(
            label: l10n.cargoShippingSlaPrintPdfBtn,
            icon: Icons.picture_as_pdf,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () => exportService.printOrSavePdf(),
          )),
          CcUi.fit(AppButton(
            label: l10n.shipmentUpdateBtnSavePdf,
            icon: Icons.save_alt_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => exportService.printOrSavePdf(save: true),
          )),
          CcUi.fit(AppButton(
            label: l10n.cargoShippingSlaCopyDossierBtn,
            icon: Icons.copy_all_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => exportService.copyDossierToClipboard(),
          )),
        ],
      ),
    );
  }

  Widget _buildFclContainerTrackingCard(ContainerLoadingModel c, int index) {
    DateTime? assignDt = c.containerAssignmentDate != null ? DateTime.tryParse(c.containerAssignmentDate!) : null;
    DateTime? arrivalDt = c.arrivalAtSupplierAt != null ? DateTime.tryParse(c.arrivalAtSupplierAt!) : assignDt;
    DateTime? loadStartDt = c.loadingStartAt != null ? DateTime.tryParse(c.loadingStartAt!) : arrivalDt;
    DateTime? loadEndDt = c.loadingEndAt != null ? DateTime.tryParse(c.loadingEndAt!) : loadStartDt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.isSlaBreached ? AppTheme.crimson : AppTheme.borderOf(context), width: c.isSlaBreached ? 1.5 : 1),
        boxShadow: [BoxShadow(color: AppTheme.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Container No + Status + SLA Alert + Quick Save Milestone Button
          ShippingTrackingHeader(
            icon: Icons.directions_boat,
            title: context.l10n.cargoShippingContainerCardHeader(index + 1, c.containerNo, c.containerType, c.sealNo),
            copyText:
                '${context.l10n.cargoShippingContainerNo}: ${c.containerNo.isNotEmpty ? c.containerNo : "-"} | ${context.l10n.cargoShippingSealNo}: ${c.sealNo.isNotEmpty ? c.sealNo : "-"}',
            copyMessage: context.l10n.cargoShippingSlaCopyContainerSuccess,
            statusLabel: c.getLocalizedStatus(context.l10n),
            statusSeverity: c.statusSeverity,
            breached: c.isSlaBreached,
            quickSaveLabel: context.l10n.cargoShippingQuickSaveContainer,
            onQuickSave: () => _quickSaveContainerMilestone(index),
          ),
          const SizedBox(height: 12),
          // 5-Milestone Visual Timeline Progress
          _buildMilestoneTimelineProgress(
            stepIndex: c.progressStepIndex,
            labels: [
              context.l10n.cargoShippingMilestone1,
              context.l10n.cargoShippingMilestone2,
              context.l10n.cargoShippingMilestone3,
              context.l10n.cargoShippingMilestone4,
              context.l10n.cargoShippingMilestone5,
            ],
          ),
          const SizedBox(height: 14),

          // 5 Interactive Milestone DateTime Picker Boxes (With Date + Time for all 5 steps)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Assignment Date & Time
              Expanded(
                child: _buildMilestonePickerBox(
                  stepNumber: '1',
                  stepTitle: context.l10n.cargoShippingMilestone1Title,
                  valueText: c.containerAssignmentDate,
                  noteText: c.milestoneNotes['1'],
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: c.containerAssignmentDate,
                      title: context.l10n.cargoShippingPickMilestone1,
                    );
                    if (dt != null) _updateContainerTimestamp(index, assignmentDate: dt);
                  },
                  onSetNow: () {
                    final nowIso = DateTime.now().toIso8601String();
                    _updateContainerTimestamp(index, assignmentDate: nowIso);
                  },
                  onClear: () => _updateContainerTimestamp(index, assignmentDate: ''),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Arrival at Supplier
              Expanded(
                child: _buildMilestonePickerBox(
                  stepNumber: '2',
                  stepTitle: context.l10n.cargoShippingMilestone2Title,
                  valueText: c.arrivalAtSupplierAt,
                  noteText: c.milestoneNotes['2'],
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: c.arrivalAtSupplierAt,
                      minDate: assignDt,
                      title: context.l10n.cargoShippingPickMilestone2,
                    );
                    if (dt != null) _updateContainerTimestamp(index, arrival: dt);
                  },
                  onSetNow: () {
                    _updateContainerTimestamp(index, arrival: DateTime.now().toIso8601String());
                  },
                  onClear: () => _updateContainerTimestamp(index, arrival: ''),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Loading Start
              Expanded(
                child: _buildMilestonePickerBox(
                  stepNumber: '3',
                  stepTitle: context.l10n.cargoShippingMilestone3Title,
                  valueText: c.loadingStartAt,
                  noteText: c.milestoneNotes['3'],
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: c.loadingStartAt,
                      minDate: arrivalDt,
                      title: context.l10n.cargoShippingPickMilestone3,
                    );
                    if (dt != null) _updateContainerTimestamp(index, loadingStart: dt);
                  },
                  onSetNow: () {
                    _updateContainerTimestamp(index, loadingStart: DateTime.now().toIso8601String());
                  },
                  onClear: () => _updateContainerTimestamp(index, loadingStart: ''),
                ),
              ),
              const SizedBox(width: 8),

              // 4. Loading End
              Expanded(
                child: _buildMilestonePickerBox(
                  stepNumber: '4',
                  stepTitle: context.l10n.cargoShippingMilestone4Title,
                  valueText: c.loadingEndAt,
                  noteText: c.milestoneNotes['4'],
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: c.loadingEndAt,
                      minDate: loadStartDt,
                      title: context.l10n.cargoShippingPickMilestone4,
                    );
                    if (dt != null) _updateContainerTimestamp(index, loadingEnd: dt);
                  },
                  onSetNow: () {
                    _updateContainerTimestamp(index, loadingEnd: DateTime.now().toIso8601String());
                  },
                  onClear: () => _updateContainerTimestamp(index, loadingEnd: ''),
                ),
              ),
              const SizedBox(width: 8),

              // 5. Port Gate-In
              Expanded(
                child: _buildMilestonePickerBox(
                  stepNumber: '5',
                  stepTitle: context.l10n.cargoShippingMilestone5Title,
                  valueText: c.portGateInAt,
                  noteText: c.milestoneNotes['5'],
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: c.portGateInAt,
                      minDate: loadEndDt,
                      title: context.l10n.cargoShippingPickMilestone5,
                    );
                    if (dt != null) _updateContainerTimestamp(index, gateIn: dt);
                  },
                  onSetNow: () {
                    _updateContainerTimestamp(index, gateIn: DateTime.now().toIso8601String());
                  },
                  onClear: () => _updateContainerTimestamp(index, gateIn: ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Milestone-Linked Interactive Notes Section
          _buildMilestoneNotesInteractiveSection(index, c),
        ],
      ),
    );
  }

  Widget _buildMilestonePickerBox({
    required String stepNumber,
    required String stepTitle,
    required String? valueText,
    String? noteText,
    required VoidCallback onPick,
    required VoidCallback onSetNow,
    required VoidCallback onClear,
  }) {
    return ShippingMilestoneBox(
      stepNumber: stepNumber,
      stepTitle: stepTitle,
      valueText: valueText,
      noteText: noteText,
      onPick: onPick,
      onSetNow: onSetNow,
      onClear: onClear,
    );
  }

  Widget _buildMilestoneNotesInteractiveSection(int containerIndex, ContainerLoadingModel c) {
    final selectedStep = _selectedMilestoneForNote[containerIndex] ?? '1';
    final noteKey = '${containerIndex}_$selectedStep';
    final ctrl = _milestoneNoteControllers.putIfAbsent(
      noteKey,
      () => TextEditingController(text: c.milestoneNotes[selectedStep] ?? ''),
    );
    if (ctrl.text != (c.milestoneNotes[selectedStep] ?? '')) {
      ctrl.text = c.milestoneNotes[selectedStep] ?? '';
    }

    final stepTitles = {
      '1': context.l10n.cargoShippingMilestone1,
      '2': context.l10n.cargoShippingMilestone2,
      '3': context.l10n.cargoShippingMilestone3,
      '4': context.l10n.cargoShippingMilestone4,
      '5': context.l10n.cargoShippingMilestone5,
    };

    final quickTags = [
      context.l10n.cargoShippingTagDriverDelayed,
      context.l10n.cargoShippingTagPermitPending,
      context.l10n.cargoShippingTagContainerInspection,
      context.l10n.cargoShippingTagPortCongestion,
      context.l10n.cargoShippingTagPalletizedCargo,
      context.l10n.cargoShippingTagVisualCheck,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined, color: AppTheme.cobalt, size: 18),
              const SizedBox(width: 6),
              Text(
                context.l10n.cargoShippingNotesHeader(c.containerNo.isNotEmpty ? c.containerNo : context.l10n.cargoShippingUnitPrefix(containerIndex + 1)),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Selector of Milestone
          Row(
            children: [
              Text(context.l10n.cargoShippingSelectMilestoneTarget, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: stepTitles.entries.map((entry) {
                    final isSel = selectedStep == entry.key;
                    final hasExistingNote = (c.milestoneNotes[entry.key]?.isNotEmpty ?? false);
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.value, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          if (hasExistingNote) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.comment, size: 12, color: AppTheme.orange),
                          ],
                        ],
                      ),
                      selected: isSel,
                      selectedColor: AppTheme.severityBackgroundOf(context, AppSeverity.info),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedMilestoneForNote[containerIndex] = entry.key;
                            final nextKey = '${containerIndex}_${entry.key}';
                            final nextCtrl = _milestoneNoteControllers.putIfAbsent(
                              nextKey,
                              () => TextEditingController(text: c.milestoneNotes[entry.key] ?? ''),
                            );
                            nextCtrl.text = c.milestoneNotes[entry.key] ?? '';
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Quick Tags
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: quickTags.map((tag) {
              return ActionChip(
                backgroundColor: AppTheme.surfaceOf(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: AppTheme.borderOf(context))),
                label: Text(tag, style: TextStyle(fontSize: 11, color: AppTheme.textPrimaryOf(context))),
                onPressed: () {
                  final cur = ctrl.text.trim();
                  if (cur.isEmpty) {
                    ctrl.text = tag;
                  } else if (!cur.contains(tag)) {
                    ctrl.text = '$cur | $tag';
                  }
                  setState(() {});
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // 3. Note Input & Save Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: ctrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: context.l10n.cargoShippingNoteHint(stepTitles[selectedStep] ?? ""),
                    hintStyle: TextStyle(fontSize: 11, color: AppTheme.textMutedOf(context)),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.surfaceOf(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  AppButton(
                    label: context.l10n.cargoShippingSaveNote,
                    icon: Icons.check,
                    size: AppButtonSize.small,
                    onPressed: () {
                      final text = ctrl.text.trim();
                      final updatedNotes = Map<String, String>.from(c.milestoneNotes);
                      if (text.isEmpty) {
                        updatedNotes.remove(selectedStep);
                      } else {
                        updatedNotes[selectedStep] = text;
                      }
                      setState(() {
                        _containers[containerIndex] = c.copyWith(milestoneNotes: updatedNotes);
                      });
                      _quickSaveContainerMilestone(containerIndex);
                    },
                  ),
                  const SizedBox(height: 4),
                  if (c.milestoneNotes[selectedStep]?.isNotEmpty ?? false)
                    AppButton(
                      label: context.l10n.cargoShippingClearNote,
                      icon: Icons.delete_outline,
                      variant: AppButtonVariant.danger,
                      size: AppButtonSize.small,
                      onPressed: () {
                        ctrl.clear();
                        final updatedNotes = Map<String, String>.from(c.milestoneNotes);
                        updatedNotes.remove(selectedStep);
                        setState(() {
                          _containers[containerIndex] = c.copyWith(milestoneNotes: updatedNotes);
                        });
                        _quickSaveContainerMilestone(containerIndex);
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildLclConsolidationTrackingCard() {
    final lcl = _lclTracking ??
        LclLoadingTrackingModel(
          shipmentType: 'LCL',
          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
          consolidationScheduledDate: DateTime.now().toIso8601String(),
          trackingStatus: 'ASSIGNED',
        );

    DateTime? schedDt = lcl.consolidationScheduledDate != null ? DateTime.tryParse(lcl.consolidationScheduledDate!) : null;
    DateTime? arrCfsDt = lcl.arrivalAtCfsAt != null ? DateTime.tryParse(lcl.arrivalAtCfsAt!) : schedDt;
    DateTime? stuffStartDt = lcl.stuffingStartAt != null ? DateTime.tryParse(lcl.stuffingStartAt!) : arrCfsDt;
    DateTime? stuffEndDt = lcl.stuffingEndAt != null ? DateTime.tryParse(lcl.stuffingEndAt!) : stuffStartDt;

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
            title: context.l10n.cargoShippingLclTrackingHeader(_cfsWarehouseCtrl.text),
            copyText: _cfsWarehouseCtrl.text.isNotEmpty ? _cfsWarehouseCtrl.text : context.l10n.cargoShippingCfsWarehouseLabel,
            copyMessage: null,
            statusLabel: lcl.getLocalizedStatus(context.l10n),
            statusSeverity: lcl.statusSeverity,
            breached: lcl.isSlaBreached,
            quickSaveLabel: context.l10n.cargoShippingQuickSaveLcl,
            onQuickSave: _quickSaveLclMilestone,
          ),
          const SizedBox(height: 12),

          // Timeline
          _buildMilestoneTimelineProgress(
            stepIndex: lcl.progressStepIndex,
            labels: [
              context.l10n.cargoShippingLclMilestone1,
              context.l10n.cargoShippingLclMilestone2,
              context.l10n.cargoShippingLclMilestone3,
              context.l10n.cargoShippingLclMilestone4,
              context.l10n.cargoShippingLclMilestone5,
            ],
          ),
          const SizedBox(height: 14),

          // 5 LCL Interactive Pickers
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sched Date
              Expanded(
                child: _buildMilestonePickerBox(
                  stepNumber: '1',
                  stepTitle: context.l10n.cargoShippingLclMilestone1,
                  valueText: lcl.consolidationScheduledDate,
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: lcl.consolidationScheduledDate,
                      title: context.l10n.cargoShippingLclPickMilestone1,
                    );
                    if (dt != null) {
                      setState(() => _lclTracking = LclLoadingTrackingModel(
                            cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
                          consolidationScheduledDate: nowIso,
                          arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                          stuffingStartAt: lcl.stuffingStartAt,
                          stuffingEndAt: lcl.stuffingEndAt,
                          portGateInAt: lcl.portGateInAt,
                          trackingStatus: 'ASSIGNED',
                        ));
                  },
                  onClear: () {
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                child: _buildMilestonePickerBox(
                  stepNumber: '2',
                  stepTitle: context.l10n.cargoShippingLclMilestone2,
                  valueText: lcl.arrivalAtCfsAt,
                  noteText: null,
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: lcl.arrivalAtCfsAt,
                      minDate: schedDt,
                      title: context.l10n.cargoShippingLclPickMilestone2,
                    );
                    if (dt != null) {
                      setState(() => _lclTracking = LclLoadingTrackingModel(
                            cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
                          consolidationScheduledDate: lcl.consolidationScheduledDate,
                          arrivalAtCfsAt: DateTime.now().toIso8601String(),
                          stuffingStartAt: lcl.stuffingStartAt,
                          stuffingEndAt: lcl.stuffingEndAt,
                          portGateInAt: lcl.portGateInAt,
                          trackingStatus: 'ARRIVED_AT_CFS',
                        ));
                  },
                  onClear: () {
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                child: _buildMilestonePickerBox(
                  stepNumber: '3',
                  stepTitle: context.l10n.cargoShippingLclMilestone3,
                  valueText: lcl.stuffingStartAt,
                  noteText: null,
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: lcl.stuffingStartAt,
                      minDate: arrCfsDt,
                      title: context.l10n.cargoShippingLclPickMilestone3,
                    );
                    if (dt != null) {
                      setState(() => _lclTracking = LclLoadingTrackingModel(
                            cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
                          consolidationScheduledDate: lcl.consolidationScheduledDate,
                          arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                          stuffingStartAt: DateTime.now().toIso8601String(),
                          stuffingEndAt: lcl.stuffingEndAt,
                          portGateInAt: lcl.portGateInAt,
                          trackingStatus: 'LOADING_IN_PROGRESS',
                        ));
                  },
                  onClear: () {
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                child: _buildMilestonePickerBox(
                  stepNumber: '4',
                  stepTitle: context.l10n.cargoShippingLclMilestone4,
                  valueText: lcl.stuffingEndAt,
                  noteText: null,
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: lcl.stuffingEndAt,
                      minDate: stuffStartDt,
                      title: context.l10n.cargoShippingLclPickMilestone4,
                    );
                    if (dt != null) {
                      setState(() => _lclTracking = LclLoadingTrackingModel(
                            cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
                          consolidationScheduledDate: lcl.consolidationScheduledDate,
                          arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                          stuffingStartAt: lcl.stuffingStartAt,
                          stuffingEndAt: DateTime.now().toIso8601String(),
                          portGateInAt: lcl.portGateInAt,
                          trackingStatus: 'LOADING_COMPLETED',
                        ));
                  },
                  onClear: () {
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                child: _buildMilestonePickerBox(
                  stepNumber: '5',
                  stepTitle: context.l10n.cargoShippingLclMilestone5,
                  valueText: lcl.portGateInAt,
                  noteText: null,
                  onPick: () async {
                    final dt = await _pickDateTime(
                      context,
                      initialIso: lcl.portGateInAt,
                      minDate: stuffEndDt,
                      title: context.l10n.cargoShippingLclPickMilestone5,
                    );
                    if (dt != null) {
                      setState(() => _lclTracking = LclLoadingTrackingModel(
                            cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
                          consolidationScheduledDate: lcl.consolidationScheduledDate,
                          arrivalAtCfsAt: lcl.arrivalAtCfsAt,
                          stuffingStartAt: lcl.stuffingStartAt,
                          stuffingEndAt: lcl.stuffingEndAt,
                          portGateInAt: DateTime.now().toIso8601String(),
                          trackingStatus: 'GATED_IN_AT_PORT',
                        ));
                  },
                  onClear: () {
                    setState(() => _lclTracking = LclLoadingTrackingModel(
                          cfsWarehouseName: _cfsWarehouseCtrl.text.trim(),
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

  Widget _buildMilestoneTimelineProgress({required int stepIndex, required List<String> labels}) {
    return ShippingMilestoneTimeline(stepIndex: stepIndex, labels: labels);
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
          // Demo action: fabricates milestone timestamps, so it exists in debug builds only.
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
            onPressed: _refreshAllData,
          )),
          CcUi.fit(AppButton(
            label: l.cargoShippingClearStartNew,
            icon: Icons.cleaning_services_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: _resetForm,
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

  // ===========================================================================
  // TAB 2: SAVED SHIPPING & LOADING REGISTRY
  // ===========================================================================
  Widget _buildSavedShippingRegistryTab() {
    final recordsAsync = ref.watch(cargoShippingProvider);
    final l = context.l10n;
    final allRecords = recordsAsync.valueOrNull ?? const <CargoShippingModel>[];
    final breachedCount = allRecords
        .where((r) => r.containersLoadingData.any((c) => c.isSlaBreached) || (r.lclTrackingData?.isSlaBreached ?? false))
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MasterDataToolbarWidget(
            moduleEndpoint: 'cargo-shipping',
            title: 'Cargo_Shipping_Registry',
            onRefreshNeeded: _refreshAllData,
          ),
          const SizedBox(height: 12),

          // Registry metrics (values already loaded)
          MetricCardStrip(
            padding: EdgeInsets.zero,
            metrics: [
              MetricCardData(
                title: l.cshMetricRecords,
                value: '${allRecords.length}',
                icon: Icons.local_shipping_outlined,
                color: AppTheme.cobalt,
              ),
              MetricCardData(
                title: l.cshPdfMetaFcl,
                value: '${allRecords.where((r) => r.shipmentType == 'FCL').length}',
                icon: Icons.view_in_ar_outlined,
                color: AppTheme.emerald,
              ),
              MetricCardData(
                title: l.cshPdfMetaLcl,
                value: '${allRecords.where((r) => r.shipmentType == 'LCL').length}',
                icon: Icons.warehouse_outlined,
                color: AppTheme.orange,
              ),
              MetricCardData(
                title: l.cargoShippingMetricSlaBreached,
                value: '$breachedCount',
                icon: Icons.alarm_off,
                color: breachedCount > 0 ? AppTheme.crimson : AppTheme.textMutedOf(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Top Actions Toolbar (Task D, E, J)
          Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: AppTheme.toolbarDecorationOf(context),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CcUi.fit(AppButton(
                  key: const Key('createShippingBtn'),
                  label: l.cargoShippingCreateNewRecord,
                  icon: Icons.add_task,
                  size: AppButtonSize.small,
                  onPressed: () {
                    _resetForm();
                    _mainTabController.animateTo(0);
                  },
                )),
                CcUi.fit(AppButton(
                  key: const Key('searchAndCloneShippingBtn'),
                  label: l.searchAndCloneCargoShippingBtn,
                  icon: Icons.copy_all_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => _openSearchAndCloneShippingDialog(allRecords),
                )),
                CcUi.fit(AppButton(
                  key: const Key('copyShippingTableTsvBtn'),
                  label: l.customsDeclExportTsvButton,
                  icon: Icons.copy,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: () => _copyShippingTableTsv(allRecords, l),
                )),
                CcUi.fit(AppButton(
                  key: const Key('exportShippingExcelBtn'),
                  label: l.exportCargoShippingExcelTooltip,
                  icon: Icons.table_chart,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => _exportShippingExcel(allRecords, l),
                )),
                CcUi.fit(AppButton(
                  key: const Key('exportShippingPdfBtn'),
                  label: l.exportCargoShippingPdfTooltip,
                  icon: Icons.picture_as_pdf,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                  onPressed: () => _exportShippingPdf(allRecords, l),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filters Bar (Responsive LayoutBuilder for Task A)
          Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: AppTheme.cardDecorationOf(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final searchField = AppSearchField(
                  controller: _searchController,
                  hint: context.l10n.cargoShippingRegistrySearchHint,
                  onChanged: (_) => setState(() {}),
                );

                final statusDropdown = SearchableDropdownField<String>(
                  labelText: context.l10n.cargoShippingStatusFilterLabel,
                  value: _registryStatusFilter,
                  items: [
                    SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingStatusAll),
                    SearchableDropdownItem(value: 'Cargo Ready', label: context.l10n.cargoShippingStatusCargoReady),
                    SearchableDropdownItem(value: 'Completed', label: context.l10n.cargoShippingStatusCompleted),
                  ],
                  onChanged: (v) => setState(() => _registryStatusFilter = v ?? 'All'),
                );

                final slaDropdown = SearchableDropdownField<String>(
                  labelText: context.l10n.cargoShippingSlaFilterLabel,
                  value: _registrySlaFilter,
                  items: [
                    SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingSlaAll),
                    SearchableDropdownItem(value: 'OnTime', label: context.l10n.cargoShippingSlaOnTimeFilter),
                    SearchableDropdownItem(value: 'Breached', label: context.l10n.cargoShippingSlaBreachedFilter),
                  ],
                  onChanged: (v) => setState(() => _registrySlaFilter = v ?? 'All'),
                );

                final activeDropdown = SearchableDropdownField<String>(
                  labelText: context.l10n.cargoShippingActiveFilterLabel,
                  value: _registryActiveFilter,
                  items: [
                    SearchableDropdownItem(value: 'All', label: context.l10n.cargoShippingActiveAll),
                    SearchableDropdownItem(value: 'Active', label: context.l10n.cargoShippingActiveOnly),
                    SearchableDropdownItem(value: 'Deleted', label: context.l10n.cargoShippingDeletedOnly),
                  ],
                  onChanged: (v) => setState(() => _registryActiveFilter = v ?? 'Active'),
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: searchField),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: statusDropdown),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: slaDropdown),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: activeDropdown),
                    ],
                  );
                } else {
                  final halfWidth = (constraints.maxWidth - 10) / 2;
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: halfWidth.clamp(140.0, 300.0), child: statusDropdown),
                          SizedBox(width: halfWidth.clamp(140.0, 300.0), child: slaDropdown),
                          SizedBox(width: constraints.maxWidth, child: activeDropdown),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Registry list
          recordsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: AppLoadingState(),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: AppErrorState(
                message: '${context.l10n.error}: $err',
                onRetry: _refreshAllData,
              ),
            ),
            data: (list) {
              final filtered = list.where((item) {
                // Search query
                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  final matchCode = item.cargoShippingCode.toLowerCase().contains(query);
                  final matchFile = (item.importFileCode ?? '').toLowerCase().contains(query);
                  final matchCompany = (item.companyName ?? '').toLowerCase().contains(query);
                  final matchContainer = item.containersLoadingData.any((c) => c.containerNo.toLowerCase().contains(query) || c.sealNo.toLowerCase().contains(query));
                  if (!matchCode && !matchFile && !matchCompany && !matchContainer) return false;
                }

                // Status filter
                if (_registryStatusFilter != 'All' && item.status != _registryStatusFilter) return false;

                // SLA filter
                final hasBreach = item.containersLoadingData.any((c) => c.isSlaBreached) || (item.lclTrackingData?.isSlaBreached ?? false);
                if (_registrySlaFilter == 'Breached' && !hasBreach) return false;
                if (_registrySlaFilter == 'OnTime' && hasBreach) return false;

                // Active filter
                if (_registryActiveFilter == 'Active' && !item.isActive) return false;
                if (_registryActiveFilter == 'Deleted' && item.isActive) return false;

                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: AppEmptyState(
                    message: context.l10n.cargoShippingNoMatchingRecords,
                    icon: Icons.folder_open,
                    actionLabel: context.l10n.cargoShippingCreateNewRecord,
                    onAction: () => _mainTabController.animateTo(0),
                  ),
                );
              }

              final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
              final importFilesMap = {for (final f in importFiles) f.importFileId: f};

              final shippingNotifier = ref.read(cargoShippingProvider.notifier);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: AppTheme.cardDecorationOf(context),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderOf(context)),
                      itemBuilder: (ctx, idx) {
                        final rec = filtered[idx];
                        return _buildRegistryRow(rec, importFilesMap);
                      },
                    ),
                  ),
                  ListLoadMoreFooter(
                    loaded: list.length,
                    total: shippingNotifier.totalCount,
                    hasMore: shippingNotifier.hasMore,
                    onLoadMore: shippingNotifier.loadMore,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegistryRow(CargoShippingModel rec, Map<int, dynamic> importFilesMap) {
    final matchingFile = importFilesMap[rec.importFileId];
    final fileCode = matchingFile?.primaryNameWithCode ?? rec.importFileCode ?? 'IMP-${rec.importFileId}';
    final companyName = (matchingFile?.companyName.isNotEmpty == true && matchingFile?.companyName != 'N/A')
        ? matchingFile!.companyName
        : (rec.companyName != null && rec.companyName!.isNotEmpty && rec.companyName != 'N/A' ? rec.companyName! : context.l10n.importCompanies);
    final supplierName = (matchingFile?.supplierName.isNotEmpty == true && matchingFile?.supplierName != 'N/A') ? matchingFile!.supplierName : '';
    final displayName = fileCode.isNotEmpty ? '$fileCode - $companyName' : companyName;

    return ShippingRegistryRow(
      rec: rec,
      displayName: displayName,
      supplierName: supplierName,
      onOpen: () => _loadRecordForEditing(rec),
      onCopyRow: () => _copyShippingRowTsv(rec, context.l10n),
      onClone: () => _onCloneCargoShipping(rec),
      onRestore: () async {
        await ref.read(cargoShippingProvider.notifier).restoreRecord(rec.cargoShippingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.cargoShippingRestoreSuccess(rec.cargoShippingCode), severity: AppSeverity.success),
          );
        }
      },
      onDelete: () => _confirmDeleteRecord(rec),
    );
  }

  Future<void> _confirmDeleteRecord(CargoShippingModel rec) async {
    final l = context.l10n;
    final confirm = await AppConfirmDialog.show(
      context,
      title: l.cargoShippingDeleteConfirmTitle,
      message: l.cargoShippingDeleteConfirmMessage(rec.cargoShippingCode, rec.importFileCode ?? ''),
      confirmLabel: l.cargoShippingConfirmDeleteBtn,
      cancelLabel: l.cancel,
      confirmVariant: AppButtonVariant.danger,
      icon: Icons.delete_outline,
    );
    if (confirm) {
      await ref.read(cargoShippingProvider.notifier).softDeleteRecord(rec.cargoShippingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, l.cargoShippingDeleteSuccess(rec.cargoShippingCode), severity: AppSeverity.danger),
        );
      }
    }
  }
}
