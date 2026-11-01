import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../models/cargo_shipping_model.dart';

/// Bottom action toolbar for cargo shipping form tab.
///
/// Provides buttons for smart simulation (debug), export manifest, live reload,
/// clear/reset, save draft, and complete save/update.
class CargoShippingActionsBar extends StatelessWidget {
  final bool isSaving;
  final bool isEditing;
  final VoidCallback? onSmartSim;
  final VoidCallback? onExportManifest;
  final VoidCallback? onRefresh;
  final VoidCallback? onClear;
  final VoidCallback? onSaveDraft;
  final VoidCallback? onSaveComplete;

  const CargoShippingActionsBar({
    super.key,
    required this.isSaving,
    required this.isEditing,
    this.onSmartSim,
    this.onExportManifest,
    this.onRefresh,
    this.onClear,
    this.onSaveDraft,
    this.onSaveComplete,
  });

  @override
  Widget build(BuildContext context) {
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
                onPressed: onSmartSim,
              )),
            ),
          CcUi.fit(AppButton(
            label: l.cargoShippingExportManifestBtn,
            icon: Icons.table_chart_outlined,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: onExportManifest,
          )),
          CcUi.fit(AppButton(
            label: l.liveReload,
            icon: Icons.refresh,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: onRefresh,
          )),
          CcUi.fit(AppButton(
            label: l.cargoShippingClearStartNew,
            icon: Icons.cleaning_services_outlined,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: onClear,
          )),
          CcUi.fit(AppButton(
            label: l.cargoShippingSaveDraft,
            icon: Icons.save_outlined,
            variant: AppButtonVariant.saveDraft,
            size: AppButtonSize.small,
            onPressed: isSaving ? null : onSaveDraft,
          )),
          CcUi.fit(AppButton(
            label: isEditing ? l.cshUpdateCompleteBtn : l.cshSaveCompleteBtn,
            icon: Icons.verified_outlined,
            variant: AppButtonVariant.success,
            isLoading: isSaving,
            onPressed: isSaving ? null : onSaveComplete,
          )),
        ],
      ),
    );
  }
}

/// Helper for exporting sanitized TSV manifests of container allocations.
class CargoShippingManifestHelper {
  CargoShippingManifestHelper._();

  static void copyContainerAllocationsManifest(
    BuildContext context, {
    required dynamic curFile,
    required String shipmentType,
    required List<ContainerLoadingModel> containers,
    required LclLoadingTrackingModel? lclTracking,
    required String cfsWarehouse,
  }) {
    final buffer = StringBuffer();
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

    if (shipmentType == 'FCL') {
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
      for (final c in containers) {
        final statusLabel = c.getLocalizedStatus(context.l10n);
        if (c.individualUnits.isNotEmpty) {
          for (final u in c.individualUnits) {
            final cNo = u['container_no'] ?? c.containerNo;
            final sNo = u['seal_no'] ?? c.sealNo;
            buffer.writeln(
                '$unitCounter\t$cNo\t${c.containerType}\t$sNo\t${c.grossWeightKg.toStringAsFixed(0)}\t${c.vgmStatus}\t${c.vgmRefNo ?? ""}\t$statusLabel');
            unitCounter++;
          }
        } else {
          buffer.writeln(
              '$unitCounter\t${c.containerNo}\t${c.containerType}\t${c.sealNo}\t${c.grossWeightKg.toStringAsFixed(0)}\t${c.vgmStatus}\t${c.vgmRefNo ?? ""}\t$statusLabel');
          unitCounter++;
        }
      }
    } else {
      final warehouseLabel = context.l10n.cargoShippingCfsWarehouseLabel;
      final statusLabel =
          lclTracking?.getLocalizedStatus(context.l10n) ?? context.l10n.cargoShippingStatusAssigned;
      buffer.writeln(
          '${context.l10n.cargoShippingShipmentTypeLabel}\t$warehouseLabel\t${context.l10n.cargoShippingColTrackingStatus}');
      buffer.writeln('LCL\t$cfsWarehouse\t$statusLabel');
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: context.l10n.cargoShippingManifestCopySuccess,
    );
  }
}

/// Helper for smart milestone simulation in debug mode.
class CargoShippingSimHelper {
  CargoShippingSimHelper._();

  static List<ContainerLoadingModel> simulateFcl(List<ContainerLoadingModel> containers) {
    final now = DateTime.now();
    final isoNow = now.toIso8601String();
    return [
      for (int i = 0; i < containers.length; i++)
        containers[i].copyWith(
          vgmStatus: 'Submitted',
          vgmRefNo: containers[i].vgmRefNo ?? 'VGM-${now.millisecondsSinceEpoch.toString().substring(8)}',
          containerAssignmentDate: containers[i].containerAssignmentDate ??
              now.subtract(const Duration(hours: 40)).toIso8601String(),
          arrivalAtSupplierAt: containers[i].arrivalAtSupplierAt ??
              now.subtract(const Duration(hours: 30)).toIso8601String(),
          loadingStartAt: containers[i].loadingStartAt ??
              now.subtract(const Duration(hours: 24)).toIso8601String(),
          loadingEndAt: containers[i].loadingEndAt ??
              now.subtract(const Duration(hours: 12)).toIso8601String(),
          portGateInAt: containers[i].portGateInAt ?? isoNow,
          trackingStatus: 'GATED_IN_AT_PORT',
          isSlaBreached: false,
        ),
    ];
  }

  static LclLoadingTrackingModel simulateLcl(String cfsWarehouse) {
    final now = DateTime.now();
    return LclLoadingTrackingModel(
      shipmentType: 'LCL',
      cfsWarehouseName: cfsWarehouse.trim(),
      consolidationScheduledDate: now.subtract(const Duration(hours: 40)).toIso8601String(),
      arrivalAtCfsAt: now.subtract(const Duration(hours: 30)).toIso8601String(),
      stuffingStartAt: now.subtract(const Duration(hours: 24)).toIso8601String(),
      stuffingEndAt: now.subtract(const Duration(hours: 12)).toIso8601String(),
      portGateInAt: now.toIso8601String(),
      trackingStatus: 'GATED_IN_AT_PORT',
      isSlaBreached: false,
    );
  }
}
