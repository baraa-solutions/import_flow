import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/display_name_resolver.dart';
import 'package:frontend/core/utils/import_file_po_linker.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/dynamic_reporting/models/dynamic_report_models.dart';
import 'dynamic_report_builder_constants.dart';

/// Resolves table cell values, row summaries, and dataset filtering
/// for Dynamic Report Builder.
class DynamicReportCellResolver {
  DynamicReportCellResolver._();

  /// Resolves the formatted string value for any column dimension.
  static String getCellValue({
    required BuildContext context,
    required WidgetRef ref,
    required ImportFileModel file,
    required String colId,
  }) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    switch (colId) {
      // File & Project
      case 'importFileCode':
        return file.displayName;
      case 'customFileNumber':
        return file.displayName;
      case 'companyName':
        return file.companyName;
      case 'supplierName':
        return file.supplierName;
      case 'brokerName':
        return file.brokerName ?? '-';
      case 'projectNames':
        return file.projectNames ?? '-';
      case 'owner':
        return file.owner;
      case 'status':
        return file.status;
      case 'currentStage':
        return DisplayNameResolver.resolveStepName(file.currentStage, isArabic: isAr);
      case 'progressPercent':
        return '${file.progressPercent.toInt()}%';
      case 'priority':
        return file.priority;
      case 'nextAction':
        return file.displayNextAction(context.l10n);
      case 'fileOpeningDate':
        return file.fileOpeningDate ?? '-';
      case 'notes':
        return file.notes ?? '-';
      case 'updatedAt':
        return file.updatedAt.length >= 16 ? file.updatedAt.substring(0, 16) : file.updatedAt;

      // Commercial & PO
      case 'poNumber':
        if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
          return file.poNumber!.trim();
        }
        final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
        final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
        if (linkedPOs.isNotEmpty) {
          return linkedPOs
              .map((p) => (p.poReference != null &&
                      p.poReference!.trim().isNotEmpty &&
                      p.poReference != file.customFileNumber &&
                      p.poReference != file.importFileCode)
                  ? p.poReference!
                  : p.poNumber)
              .join(', ');
        }
        return (file.poIds != null && file.poIds!.isNotEmpty ? file.poIds!.join(', ') : '-');
      case 'piNumber':
        if (file.piNumber != null && file.piNumber!.trim().isNotEmpty) {
          return file.piNumber!.trim();
        }
        return file.invoicesData.isNotEmpty ? file.invoicesData.first.invoiceNo : '-';
      case 'piValue':
        return file.invoicesData.isNotEmpty
            ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'
            : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}';
      case 'incotermCode':
        return file.incotermCode;
      case 'estimatedCost':
        return '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}';

      // Shipping & Logistics
      case 'shipmentMode':
        return file.shipmentMode;
      case 'shippingLine':
        return file.selectedScenario ?? (file.shippingInstructionsNotes ?? '-');
      case 'portOfLoading':
        return file.portOfLoading ?? '-';
      case 'portOfDischarge':
        return file.portOfDischarge ?? '-';
      case 'cargoReadyDate':
        return file.cargoReadyDate ?? '-';
      case 'requiredEta':
        return file.requiredEta ?? '-';
      case 'targetFreeDays':
        return file.targetFreeDays != null ? l.dynDaysCount(file.targetFreeDays!) : '-';

      // Packages & CBM
      case 'totalPackages':
        return file.packingListsData.isNotEmpty
            ? file.packingListsData.fold<int>(0, (sum, p) => sum + p.totalPackages).toString()
            : '-';
      case 'grossWeightKg':
        return file.packingListsData.isNotEmpty
            ? l.dynGrossWeightKg(file.packingListsData.fold<double>(0.0, (sum, p) => sum + p.grossWeightKg).toStringAsFixed(1))
            : '-';
      case 'totalCbm':
        return file.packingListsData.isNotEmpty
            ? l.dynTotalCbm(file.packingListsData.fold<double>(0.0, (sum, p) => sum + p.cbm).toStringAsFixed(2))
            : '-';

      // Customs & Nafeza
      case 'acidNumber':
        return file.acidNumber ?? '-';
      case 'acidIssueDate':
        return file.acidIssueDate ?? '-';
      case 'acidExpiryDate':
        return file.acidExpiryDate ?? '-';
      case 'form46No':
        return file.form46No ?? '-';
      case 'customsReleaseStatus':
        return file.isCustomsReleased
            ? l.dynCustomsReleased
            : (file.status == 'Under Clearance' ? l.dynCustomsUnderClearance : file.status);
      case 'customsReleasedAt':
        return file.customsReleasedAt ?? '-';

      // Banking & Swift
      case 'form4No':
        return file.form4No ?? '-';
      case 'form4ReceivedDate':
        return file.form4ReceivedDate ?? '-';
      case 'swiftNo':
        return file.swiftNo ?? '-';
      case 'swiftDate':
        return file.swiftNo != null ? (file.form4ReceivedDate ?? file.fileOpeningDate ?? '-') : '-';
      case 'swiftAmount':
        return file.swiftNo != null
            ? (file.invoicesData.isNotEmpty
                ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'
                : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}')
            : '-';

      // ECO Specific
      case 'ecoBroker':
        return file.brokerName ?? '-';
      case 'ecoShipmentNo':
        return file.displayName;
      case 'ecoSupplier':
        return file.supplierName;
      case 'ecoProject':
        return file.projectNames ?? '-';
      case 'ecoPiValue':
        return file.invoicesData.isNotEmpty
            ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'
            : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}';
      case 'ecoShippingDate':
        return file.cargoReadyDate != null
            ? '${file.cargoReadyDate} ${file.portOfLoading ?? ""}'.trim()
            : (file.portOfLoading ?? '-');
      case 'ecoArrivalPort':
        return file.requiredEta != null
            ? '${file.requiredEta} ${file.portOfDischarge ?? ""}'.trim()
            : (file.portOfDischarge ?? '-');
      case 'ecoArrivalWarehouse':
        if (file.inlandActualArrivalDate != null && file.inlandActualArrivalDate!.isNotEmpty) {
          return file.inlandActualArrivalDate!;
        }
        return file.customsReleasedAt ?? (file.updatedAt.length >= 10 ? file.updatedAt.substring(0, 10) : '-');
      case 'ecoSara':
        if (file.owner.isNotEmpty && file.owner != file.companyName) {
          return file.owner;
        }
        if (file.projectIds.isNotEmpty) {
          final projectsState = ref.read(projectsProvider);
          final pList = projectsState.value ?? [];
          for (final pid in file.projectIds) {
            final proj = pList.where((p) => p.projectId == pid).firstOrNull;
            if (proj != null && proj.projectOwner.isNotEmpty) {
              return proj.projectOwner;
            }
          }
        }
        return file.owner.isNotEmpty ? file.owner : '-';
      case 'ecoMaro':
        if (file.companyName.isNotEmpty) {
          return file.companyName;
        }
        return file.projectNames ?? '-';
      case 'ecoReadyToPickUp':
        return file.cargoReadyDate ?? '-';
      case 'ecoLatestUpdate':
        if (file.holdReason != null && file.holdReason!.isNotEmpty) {
          return '${l.dynStatusHeld}: ${file.holdReason}';
        }
        return DisplayNameResolver.resolveStepName(file.currentStage, isArabic: isAr);
      case 'ecoSwiftDate':
        return file.swiftNo != null ? (file.form4ReceivedDate ?? '-') : '-';
      case 'ecoSwiftAmount':
        return file.swiftNo != null
            ? (file.invoicesData.isNotEmpty
                ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'
                : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}')
            : '-';
      case 'ecoShippingCompany':
        return file.selectedScenario ?? file.shipmentMode;
      case 'ecoAcid':
        return file.acidNumber != null ? file.acidNumber! : '-';

      // Express Courier & Air Cargo
      case 'courierOperator':
        return file.courierOperator ?? '-';
      case 'courierTrackingNo':
        return file.courierTrackingNo ?? '-';
      case 'shipmentSubMode':
        return file.shipmentSubMode ?? file.shipmentMode;
      case 'chargeableDivisor':
        return file.chargeableDivisor != null ? '${file.chargeableDivisor}' : '-';
      case 'acidRequirement':
        return file.isAcidExempt ? l.dynFilterAcidReqExempt : l.dynFilterAcidReqMandatory;
      case 'acidExemptionReason':
        return file.acidExemptionReason ?? '-';

      // Container Lifecycle & Demurrage
      case 'blNumber':
        return file.blNumber ?? '-';
      case 'bookingNo':
        return file.bookingNo ?? '-';
      case 'vesselName':
        return file.vesselName ?? '-';
      case 'deliveryOrderNo':
        return file.deliveryOrderNo ?? '-';
      case 'deliveryOrderExpiryDate':
        return file.deliveryOrderExpiryDate ?? '-';
      case 'emptyContainersReturnedAt':
        return file.emptyContainersReturnedAt ?? '-';
      case 'emptyContainersReturnStatus':
        return file.emptyContainersReturnStatus ?? '-';
      case 'emptyContainersEirNumbers':
        return file.emptyContainersEirNumbers ?? '-';
      case 'emptyContainersDepotName':
        return file.emptyContainersDepotName ?? '-';

      // Customs Release & Duties
      case 'customsReleasePermitNo':
        return file.customsReleasePermitNo ?? '-';
      case 'customsReleaseType':
        return file.customsReleaseType ?? '-';
      case 'customsReleaseOfficer':
        return file.customsReleaseOfficer ?? '-';
      case 'customsGatePassNo':
        return file.customsGatePassNo ?? '-';
      case 'customsDutyPaidAmount':
        return file.customsDutyPaidAmount > 0
            ? 'EGP ${file.customsDutyPaidAmount.toStringAsFixed(2)}'
            : '-';
      case 'customsDutyReceiptNo':
        return file.customsDutyReceiptNo ?? '-';
      case 'customsDutySadadNo':
        return file.customsDutySadadNo ?? '-';
      case 'customsDutyPaymentDate':
        return file.customsDutyPaymentDate ?? '-';
      case 'customsBrokerDelegationNo':
        return file.customsBrokerDelegationNo ?? '-';

      // Inland Haulage & Warehouse Transport
      case 'inlandTransportStatus':
        return file.inlandTransportStatus.isNotEmpty ? file.inlandTransportStatus : '-';
      case 'inlandCarrierName':
        return file.inlandCarrierName ?? '-';
      case 'inlandTruckPlateNo':
        return file.inlandTruckPlateNo ?? '-';
      case 'inlandDriverName':
        return file.inlandDriverName ?? '-';
      case 'inlandDriverPhone':
        return file.inlandDriverPhone ?? '-';
      case 'inlandTransportCostEgp':
        return file.inlandTransportCostEgp > 0
            ? 'EGP ${file.inlandTransportCostEgp.toStringAsFixed(2)}'
            : '-';
      case 'inlandDepartureDate':
        return file.inlandDepartureDate ?? '-';
      case 'inlandActualArrivalDate':
        return file.inlandActualArrivalDate ?? '-';

      // Actual Landed Cost & Settlement
      case 'totalClearanceExpensesEgp':
        return file.totalClearanceExpensesEgp > 0
            ? 'EGP ${file.totalClearanceExpensesEgp.toStringAsFixed(2)}'
            : '-';
      case 'actualLandedCostTotalEgp':
        return file.actualLandedCostTotalEgp > 0
            ? 'EGP ${file.actualLandedCostTotalEgp.toStringAsFixed(2)}'
            : '-';
      case 'actualLandedCostMarkupFactor':
        return file.actualLandedCostMarkupFactor > 0
            ? file.actualLandedCostMarkupFactor.toStringAsFixed(4)
            : '-';
      case 'actualLandedCostVarianceEgp':
        return file.actualLandedCostVarianceEgp != 0
            ? 'EGP ${file.actualLandedCostVarianceEgp.toStringAsFixed(2)}'
            : '-';
      case 'actualLandedCostVariancePct':
        return file.actualLandedCostVariancePct != 0
            ? '${file.actualLandedCostVariancePct.toStringAsFixed(2)}%'
            : '-';
      case 'financialSettlementStatus':
        return file.financialSettlementStatus ?? '-';

      // CargoX & Digital Documents Courier
      case 'cargoxEnvelopeCode':
        return file.cargoxEnvelopeCode ?? '-';
      case 'cargoxEnvelopeStatus':
        return file.cargoxEnvelopeStatus ?? '-';
      case 'cargoxTransferredAt':
        return file.cargoxTransferredAt ?? '-';
      case 'originalDocumentsCourierNo':
        return file.originalDocumentsCourierNo ?? '-';
      case 'originalDocumentsStatus':
        return file.originalDocumentsStatus ?? '-';
      case 'originalDocumentsReceivedAt':
        return file.originalDocumentsReceivedAt ?? '-';

      // Partial Shipments & Hierarchy
      case 'isPartialShipment':
        return file.isPartialShipment ? l.dynYes : l.dynNo;
      case 'parentFileCode':
        return file.parentFileCode ??
            (file.parentImportFileId != null ? 'ID: ${file.parentImportFileId}' : '-');

      // Operational Notes & Hold Status
      case 'holdReason':
        return file.holdReason ?? '-';
      case 'holdDate':
        return file.holdDate ?? '-';
      case 'hsCode':
        return file.hsCode ?? '-';
      case 'productCategory':
        return file.productCategory ?? '-';

      // ECO Radar / Document & Milestone Specific
      case 'scasProjectFileAcid':
        final proj = file.projectNames != null
            ? '${isAr ? "المشروع" : "Project"}: ${file.projectNames}'
            : (file.companyName.isNotEmpty
                ? '${isAr ? "المشروع" : "Project"}: ${file.companyName}'
                : (isAr ? "المشروع: عام" : "Project: General"));
        final fCode = '${isAr ? "الملف" : "File"}: ${file.displayName}';
        final acid = file.acidNumber != null
            ? '${isAr ? "القيد الجمركي" : "ACID"}: ${file.acidNumber}'
            : (isAr ? "القيد الجمركي: -" : "ACID: -");
        return '$proj\n$fCode\n$acid'.trim();
      case 'scasExFactory':
        final dateVal = file.cargoReadyDate ?? file.fileOpeningDate ?? '-';
        final valStr = file.invoicesData.isNotEmpty
            ? '${file.invoicesData.first.currency} ${file.invoicesData.first.amount.toStringAsFixed(2)}'
            : '${file.estimatedCostCurrency} ${file.estimatedCost.toStringAsFixed(2)}';
        return '$dateVal\n$valStr';
      case 'scasOrderToOrigin':
        final stage = file.currentStage.toLowerCase();
        return (stage.contains('feasibility') || stage.contains('planning'))
            ? l.dynStatusPending
            : l.dynStatusDone;
      case 'scasPickUpDate':
        return file.cargoReadyDate ?? file.fileOpeningDate ?? '-';
      case 'scasDeparturePort':
        return file.cargoReadyDate ?? file.fileOpeningDate ?? '-';
      case 'scasArrivalAlexPort':
        return file.requiredEta ?? '-';
      case 'scasOrigInvoice':
        return file.invoicesData.isNotEmpty
            ? '${l.dynStatusReceived}\n${file.invoicesData.first.date ?? file.invoicesData.first.invoiceNo}'
            : l.dynStatusReceived;
      case 'scasOrigPackingList':
        return file.packingListsData.isNotEmpty
            ? '${l.dynStatusReceived}\n${file.packingListsData.first.date ?? file.packingListsData.first.plNo}'
            : l.dynStatusReceived;
      case 'scasOrigCoo':
        return file.supplierName.isNotEmpty
            ? '${l.dynStatusReceived}\n${l.dynCellOriginOk}'
            : l.dynStatusReceived;
      case 'scasOrigBl':
        if (file.blNumber != null && file.blNumber!.trim().isNotEmpty) {
          return '${l.dynStatusReceived}\n${file.blNumber!.trim()}';
        }
        return file.selectedScenario != null && file.selectedScenario!.isNotEmpty
            ? '${l.dynStatusReceived}\n${file.selectedScenario}'
            : '${l.dynStatusReceived} ${l.dynCellExpressBl}';
      case 'scasOrigInsurance':
        final inc = file.incotermCode.toUpperCase();
        return (inc == 'CIF' || inc == 'CIP') ? l.dynCellOriginCovered : l.dynCellIssuedReceived;
      case 'scasInsertNafeza':
        return file.acidNumber != null
            ? '${l.dynStatusDone}\n(${file.acidIssueDate ?? (isAr ? "سارٍ" : "Active")})'
            : l.dynCellPendingAcid;
      case 'scasBankForm4':
        return file.form4No != null
            ? '${l.dynStatusReceived}\n${isAr ? "رقم" : "No"}: ${file.form4No}'
            : l.dynCellPendingBank;
      case 'scasDeclare3A':
        return file.form46No != null
            ? '${l.dynStatusDone}\n${isAr ? "رقم" : "No"}: ${file.form46No}'
            : l.dynCellPending46;
      case 'scasMaterialReceived':
        if (file.inlandActualArrivalDate != null && file.inlandActualArrivalDate!.isNotEmpty) {
          return '${l.dynCellDeliveredWarehouse}\n${file.inlandActualArrivalDate}';
        }
        return file.isCustomsReleased
            ? '${l.dynCellDeliveredWarehouse}\n(${file.customsReleasedAt ?? l.dynCustomsReleased})'
            : (file.status == 'Under Clearance' ? l.dynCellInClearancePort : file.status);

      default:
        return '-';
    }
  }

  /// Builds a complete text representation of a single shipment row for clipboard copying.
  static String buildRowSummary({
    required BuildContext context,
    required WidgetRef ref,
    required ImportFileModel file,
    required List<DynamicReportColumn> cols,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('${file.displayName} — ${file.companyName}');
    for (final col in cols) {
      final label = DynamicReportBuilderConstants.getColumnLabel(context, col.id);
      final val = getCellValue(
        context: context,
        ref: ref,
        file: file,
        colId: col.id,
      ).replaceAll('\n', ' ');
      buffer.writeln('$label: $val');
    }
    return buffer.toString().trim();
  }

  /// Filters shipments based on active template, shipment mode, priority, status, and query.
  static List<ImportFileModel> filterFiles({
    required List<ImportFileModel> files,
    required ReportTemplateMode templateMode,
    required String filterMode,
    required String filterPriority,
    required String filterStatus,
    required String searchQuery,
    String filterCustomsRelease = 'All',
    String filterAcidReq = 'All',
  }) {
    return files.where((f) {
      if (filterMode != 'All' && f.shipmentMode != filterMode) return false;
      if (filterPriority != 'All' && f.priority != filterPriority) return false;
      if (filterStatus != 'All' && f.status != filterStatus) return false;

      // Filter by Customs Release
      if (filterCustomsRelease == 'Released' && !f.isCustomsReleased) return false;
      if (filterCustomsRelease == 'Pending' && f.isCustomsReleased) return false;

      // Filter by ACID / Postal Exemption
      if (filterAcidReq == 'Mandatory' && f.isAcidExempt) return false;
      if (filterAcidReq == 'Exempt' && !f.isAcidExempt) return false;

      // Filter by Template Mode
      if (templateMode == ReportTemplateMode.eco) {
        final comp = f.companyName.toLowerCase();
        final proj = (f.projectNames ?? '').toLowerCase();
        final owner = f.owner.toLowerCase();
        final notes = (f.notes ?? '').toLowerCase();
        final isEco = comp.contains('eco') ||
            comp.contains('إيكو') ||
            comp.contains('ايكو') ||
            proj.contains('eco') ||
            proj.contains('إيكو') ||
            proj.contains('ايكو') ||
            owner.contains('eco') ||
            owner.contains('إيكو') ||
            owner.contains('ايكو') ||
            notes.contains('eco') ||
            notes.contains('إيكو') ||
            notes.contains('ايكو');
        if (!isEco) return false;
      } else if (templateMode == ReportTemplateMode.scas) {
        final comp = f.companyName.toLowerCase();
        final proj = (f.projectNames ?? '').toLowerCase();
        final owner = f.owner.toLowerCase();
        final notes = (f.notes ?? '').toLowerCase();
        final isScasOrArchi = comp.contains('scas') ||
            comp.contains('سكاس') ||
            comp.contains('archi') ||
            comp.contains('أركي') ||
            comp.contains('اركي') ||
            proj.contains('scas') ||
            proj.contains('سكاس') ||
            proj.contains('archi') ||
            proj.contains('أركي') ||
            proj.contains('اركي') ||
            owner.contains('scas') ||
            owner.contains('archi') ||
            notes.contains('scas') ||
            notes.contains('archi');
        if (!isScasOrArchi) return false;
      }

      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchCode = f.importFileCode.toLowerCase().contains(q) ||
            (f.customFileNumber?.toLowerCase().contains(q) ?? false);
        final matchComp = f.companyName.toLowerCase().contains(q);
        final matchSup = f.supplierName.toLowerCase().contains(q);
        final matchProj = f.projectNames?.toLowerCase().contains(q) ?? false;
        final matchAcid = f.acidNumber?.toLowerCase().contains(q) ?? false;
        final matchBroker = f.brokerName?.toLowerCase().contains(q) ?? false;
        final matchCourier = f.courierTrackingNo?.toLowerCase().contains(q) ?? false;
        final matchBl = f.blNumber?.toLowerCase().contains(q) ?? false;
        final matchDo = f.deliveryOrderNo?.toLowerCase().contains(q) ?? false;
        final matchCargox = f.cargoxEnvelopeCode?.toLowerCase().contains(q) ?? false;
        if (!matchCode &&
            !matchComp &&
            !matchSup &&
            !matchProj &&
            !matchAcid &&
            !matchBroker &&
            !matchCourier &&
            !matchBl &&
            !matchDo &&
            !matchCargox) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}
