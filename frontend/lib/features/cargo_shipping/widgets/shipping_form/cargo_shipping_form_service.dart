import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../../freight_booking/models/freight_booking_model.dart';
import '../../../freight_booking/providers/freight_booking_provider.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../models/cargo_container_defaults.dart';
import '../../models/cargo_shipping_model.dart';
import '../../providers/cargo_shipping_provider.dart';

class CargoShippingFileSelectionResult {
  final CargoShippingModel? existingRecord;
  final String shipmentType;
  final List<ContainerLoadingModel> containers;

  CargoShippingFileSelectionResult({
    this.existingRecord,
    required this.shipmentType,
    required this.containers,
  });
}

/// Service handling API mutations and submissions for cargo shipping form tab.
class CargoShippingFormService {
  static String cleanError(dynamic e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['detail'] != null) return d['detail'].toString();
      return e.message ?? 'Server error';
    }
    return e.toString().replaceAll('Exception:', '').trim();
  }

  static ({double cbm, double weightKg, dynamic activeRec}) computeCargoMetrics({
    required ImportFileModel? curFile,
    required List<PurchaseOrderModel> allPOs,
    required bool isStackable,
  }) {
    if (curFile == null) return (cbm: 0.0, weightKg: 0.0, activeRec: null);
    final filePos = ImportFilePoLinker.getLinkedPOs(file: curFile, allPOs: allPOs);
    final metrics = ImportFilePoLinker.computeMetrics(file: curFile, linkedPOs: filePos);
    final dualRec = dualRecommendationOrNull(totalCbm: metrics.cbm, totalWeightKg: metrics.weightKg);
    final activeRec = dualRec == null ? null : (isStackable ? dualRec.stackableResult : dualRec.nonStackableResult);
    return (cbm: metrics.cbm, weightKg: metrics.weightKg, activeRec: activeRec);
  }

  static int countBookingContainers(ShipmentBookingModel? b) {
    if (b == null || b.containersData.isEmpty) return 0;
    int count = 0;
    for (final alloc in b.containersData) {
      count += alloc.quantity > 0 ? alloc.quantity : math.max(1, alloc.individualContainers.length);
    }
    return count;
  }

  static int countRegisteredContainers(List<ContainerLoadingModel> containers) {
    int count = 0;
    for (final c in containers) {
      count += c.quantity > 0 ? c.quantity : math.max(1, c.individualUnits.length);
    }
    return count;
  }

  static String formatBookingContainersSummary(ShipmentBookingModel? b) {
    if (b == null || b.containersData.isEmpty) return '';
    return b.containersData.map((c) => '${c.quantity}x ${c.containerType}').join(', ');
  }

  static List<ContainerLoadingModel> duplicateContainer(List<ContainerLoadingModel> list, int index) {
    if (index < 0 || index >= list.length) return list;
    final item = list[index];
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
      individualUnits: blankUnits(item.individualUnits.length),
    );
    final res = List<ContainerLoadingModel>.from(list);
    res.insert(index + 1, dup);
    return res;
  }

  static ({List<ContainerLoadingModel> containers, LclLoadingTrackingModel? lclTracking}) simulateTracking({
    required String shipmentType,
    required List<ContainerLoadingModel> currentContainers,
    required String cfsWarehouse,
  }) {
    final now = DateTime.now();
    final isoNow = now.toIso8601String();
    if (shipmentType == 'FCL') {
      final updated = <ContainerLoadingModel>[];
      for (final c in currentContainers) {
        updated.add(c.copyWith(
          vgmStatus: 'Submitted',
          vgmRefNo: c.vgmRefNo ?? 'VGM-${now.millisecondsSinceEpoch.toString().substring(8)}',
          containerAssignmentDate: c.containerAssignmentDate ?? now.subtract(const Duration(hours: 40)).toIso8601String(),
          arrivalAtSupplierAt: c.arrivalAtSupplierAt ?? now.subtract(const Duration(hours: 30)).toIso8601String(),
          loadingStartAt: c.loadingStartAt ?? now.subtract(const Duration(hours: 24)).toIso8601String(),
          loadingEndAt: c.loadingEndAt ?? now.subtract(const Duration(hours: 12)).toIso8601String(),
          portGateInAt: c.portGateInAt ?? isoNow,
          trackingStatus: 'GATED_IN_AT_PORT',
          isSlaBreached: false,
        ));
      }
      return (containers: updated, lclTracking: null);
    } else {
      return (
        containers: currentContainers,
        lclTracking: LclLoadingTrackingModel(
          shipmentType: 'LCL',
          cfsWarehouseName: cfsWarehouse.trim(),
          consolidationScheduledDate: now.subtract(const Duration(hours: 40)).toIso8601String(),
          arrivalAtCfsAt: now.subtract(const Duration(hours: 30)).toIso8601String(),
          stuffingStartAt: now.subtract(const Duration(hours: 24)).toIso8601String(),
          stuffingEndAt: now.subtract(const Duration(hours: 12)).toIso8601String(),
          portGateInAt: isoNow,
          trackingStatus: 'GATED_IN_AT_PORT',
          isSlaBreached: false,
        ),
      );
    }
  }

  static Future<CargoShippingFileSelectionResult> resolveFileSelection({
    required WidgetRef ref,
    required int fileId,
  }) async {
    var existingRecords = ref.read(cargoShippingProvider).valueOrNull ?? [];
    if (existingRecords.isEmpty) {
      await ref.read(cargoShippingProvider.notifier).fetchRecords(includeInactive: true);
      existingRecords = ref.read(cargoShippingProvider).valueOrNull ?? [];
    }

    final existingRec = existingRecords.where((r) => r.importFileId == fileId && r.isActive).firstOrNull;
    if (existingRec != null) {
      return CargoShippingFileSelectionResult(
        existingRecord: existingRec,
        shipmentType: existingRec.shipmentType,
        containers: existingRec.containersLoadingData,
      );
    }

    final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
    final linked = bookings.where((b) => b.importFileId == fileId && b.isActive).firstOrNull;

    if (linked != null) {
      final shipmentType = linked.shipmentType == 'LCL' ? 'LCL' : 'FCL';
      if (shipmentType == 'FCL' && linked.containersData.isNotEmpty) {
        final nowIso = DateTime.now().toIso8601String();
        final List<ContainerLoadingModel> loaded = [];
        for (final alloc in linked.containersData) {
          final count = alloc.quantity > 0 ? alloc.quantity : math.max(1, alloc.individualContainers.length);
          for (int uIdx = 0; uIdx < count; uIdx++) {
            final indiv = uIdx < alloc.individualContainers.length ? alloc.individualContainers[uIdx] : null;
            final cNo = indiv?.containerNumber ?? '';
            final sNo = indiv?.sealNumber ?? '';
            final vgm = (indiv != null && indiv.vgmWeightKg > 0) ? indiv.vgmWeightKg : 0.0;
            loaded.add(
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
        return CargoShippingFileSelectionResult(
          shipmentType: 'FCL',
          containers: loaded.isNotEmpty ? loaded : [blankContainer(assignmentDateIso: DateTime.now().toIso8601String())],
        );
      }
      return CargoShippingFileSelectionResult(
        shipmentType: shipmentType,
        containers: [blankContainer(assignmentDateIso: DateTime.now().toIso8601String())],
      );
    }

    return CargoShippingFileSelectionResult(
      shipmentType: 'FCL',
      containers: [blankContainer(assignmentDateIso: DateTime.now().toIso8601String())],
    );
  }

  static Future<CargoShippingModel?> quickSaveContainerMilestone({
    required BuildContext context,
    required WidgetRef ref,
    required int? selectedImportFileId,
    required int? editingRecordId,
    required ContainerLoadingModel container,
    required void Function(bool saving) onSetSaving,
  }) async {
    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cargoShippingSelectFileFirstForContainer, severity: AppSeverity.warning),
      );
      return null;
    }

    if (editingRecordId == null) return null;

    onSetSaving(true);
    try {
      final payload = {
        'container_assignment_date': container.containerAssignmentDate,
        'arrival_at_supplier_at': container.arrivalAtSupplierAt,
        'loading_start_at': container.loadingStartAt,
        'loading_end_at': container.loadingEndAt,
        'port_gate_in_at': container.portGateInAt,
        'milestone_notes': container.milestoneNotes,
      };
      final updated = await ref.read(cargoShippingProvider.notifier).updateContainerTracking(
        editingRecordId,
        container.containerNo,
        payload,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cargoShippingSaveContainerMilestoneSuccess(
              container.containerNo,
              container.getLocalizedStatus(context.l10n),
            ),
            severity: AppSeverity.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return updated;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.cargoShippingQuickSaveError(cleanError(e)), severity: AppSeverity.danger),
        );
      }
      return null;
    } finally {
      onSetSaving(false);
    }
  }

  static Future<CargoShippingModel?> quickSaveLclMilestone({
    required BuildContext context,
    required WidgetRef ref,
    required int? selectedImportFileId,
    required int? editingRecordId,
    required LclLoadingTrackingModel? lclTracking,
    required void Function(bool saving) onSetSaving,
  }) async {
    if (selectedImportFileId == null || lclTracking == null) return null;
    if (editingRecordId == null) return null;

    onSetSaving(true);
    try {
      final updated = await ref.read(cargoShippingProvider.notifier).updateLclTracking(
        editingRecordId,
        lclTracking.toJson(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cargoShippingSaveLclMilestoneSuccess(lclTracking.getLocalizedStatus(context.l10n)),
            severity: AppSeverity.success,
          ),
        );
      }
      return updated;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, context.l10n.cargoShippingLclSaveError(cleanError(e)), severity: AppSeverity.danger),
        );
      }
      return null;
    } finally {
      onSetSaving(false);
    }
  }

  static Future<CargoShippingModel?> submitCargoShippingForm({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required int? selectedImportFileId,
    required int? editingRecordId,
    required String shipmentType,
    required List<ContainerLoadingModel> containers,
    required LclLoadingTrackingModel? lclTracking,
    required int? linkedBookingId,
    required dynamic linkedBooking,
    required int totalBookingContainersCount,
    required int totalRegisteredContainersCount,
    required bool isDraftProgressive,
    required void Function(bool saving) onSetSaving,
    required void Function(CargoShippingModel result) onSuccess,
    required VoidCallback? onSwitchToRegistry,
  }) async {
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cargoShippingFillRequiredFields, severity: AppSeverity.danger),
      );
      return null;
    }

    if (selectedImportFileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, context.l10n.cargoShippingSelectLinkedFilePrompt, severity: AppSeverity.warning),
      );
      return null;
    }

    if (shipmentType == 'FCL' && linkedBooking != null && totalBookingContainersCount > 0) {
      if (totalRegisteredContainersCount != totalBookingContainersCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cargoShippingBookingMatchRequired(totalRegisteredContainersCount, totalBookingContainersCount),
            severity: AppSeverity.danger,
          ),
        );
        return null;
      }
    }

    onSetSaving(true);

    final payload = buildCargoShippingPayload(
      importFileId: selectedImportFileId,
      shipmentType: shipmentType,
      containers: containers,
      lclTracking: lclTracking,
      isEdit: editingRecordId != null,
      bookingId: linkedBookingId,
    );

    try {
      final notifier = ref.read(cargoShippingProvider.notifier);
      final resultRecord = editingRecordId != null
          ? await notifier.updateRecord(editingRecordId, payload)
          : await notifier.createRecord(payload);

      if (context.mounted && resultRecord != null) {
        onSuccess(resultRecord);
        if (isDraftProgressive) {
          notifier.fetchRecords(includeInactive: true);
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, context.l10n.cargoShippingDraftSaveSuccess, severity: AppSeverity.success),
          );
        } else {
          notifier.fetchRecords(includeInactive: true);
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              context.l10n.cargoShippingStudySaveSuccess(resultRecord.cargoShippingCode),
              severity: AppSeverity.success,
            ),
          );
          onSwitchToRegistry?.call();
        }
      }
      return resultRecord;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, cleanError(e), severity: AppSeverity.danger),
        );
      }
      return null;
    } finally {
      onSetSaving(false);
    }
  }
}
