import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/dynamic_reporting/models/dynamic_report_models.dart';

/// Preset constants, catalog builder, and localized label resolvers
/// for ImportFlow Dynamic Report Builder.
class DynamicReportBuilderConstants {
  DynamicReportBuilderConstants._();

  /// ECO Radar preset: 15 milestone and document tracking columns in strict order.
  static const List<String> kEcoPresetColumnIds = [
    'scasProjectFileAcid',
    'scasExFactory',
    'scasOrderToOrigin',
    'scasPickUpDate',
    'scasDeparturePort',
    'scasArrivalAlexPort',
    'scasOrigInvoice',
    'scasOrigPackingList',
    'scasOrigCoo',
    'scasOrigBl',
    'scasOrigInsurance',
    'scasInsertNafeza',
    'scasBankForm4',
    'scasDeclare3A',
    'scasMaterialReceived',
  ];

  /// SCAS Tracker preset: 16 operational and SWIFT tracking columns in strict order.
  static const List<String> kScasPresetColumnIds = [
    'ecoBroker',
    'ecoShipmentNo',
    'ecoSupplier',
    'ecoProject',
    'ecoPiValue',
    'ecoShippingDate',
    'ecoArrivalPort',
    'ecoArrivalWarehouse',
    'ecoSara',
    'ecoMaro',
    'ecoReadyToPickUp',
    'ecoLatestUpdate',
    'ecoSwiftDate',
    'ecoSwiftAmount',
    'ecoShippingCompany',
    'ecoAcid',
  ];

  /// Master column catalog encompassing all 60+ configurable report dimensions.
  static List<DynamicReportColumn> buildMasterColumnCatalog() {
    return [
      // File & Project
      DynamicReportColumn(id: 'importFileCode', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'customFileNumber', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'companyName', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'supplierName', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'brokerName', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'projectNames', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'owner', categoryId: 'file_project', isVisible: false),
      DynamicReportColumn(id: 'status', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'currentStage', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'progressPercent', categoryId: 'file_project', isVisible: true),
      DynamicReportColumn(id: 'priority', categoryId: 'file_project', isVisible: false),
      DynamicReportColumn(id: 'nextAction', categoryId: 'file_project', isVisible: false),
      DynamicReportColumn(id: 'fileOpeningDate', categoryId: 'file_project', isVisible: false),
      DynamicReportColumn(id: 'notes', categoryId: 'file_project', isVisible: false),
      DynamicReportColumn(id: 'updatedAt', categoryId: 'file_project', isVisible: false),

      // Commercial & PO
      DynamicReportColumn(id: 'poNumber', categoryId: 'commercial_po', isVisible: false),
      DynamicReportColumn(id: 'piNumber', categoryId: 'commercial_po', isVisible: false),
      DynamicReportColumn(id: 'piValue', categoryId: 'commercial_po', isVisible: true),
      DynamicReportColumn(id: 'incotermCode', categoryId: 'commercial_po', isVisible: true),
      DynamicReportColumn(id: 'estimatedCost', categoryId: 'commercial_po', isVisible: false),

      // Shipping & Logistics
      DynamicReportColumn(id: 'shipmentMode', categoryId: 'shipping_logistics', isVisible: true),
      DynamicReportColumn(id: 'shippingLine', categoryId: 'shipping_logistics', isVisible: false),
      DynamicReportColumn(id: 'portOfLoading', categoryId: 'shipping_logistics', isVisible: false),
      DynamicReportColumn(id: 'portOfDischarge', categoryId: 'shipping_logistics', isVisible: false),
      DynamicReportColumn(id: 'cargoReadyDate', categoryId: 'shipping_logistics', isVisible: false),
      DynamicReportColumn(id: 'requiredEta', categoryId: 'shipping_logistics', isVisible: true),
      DynamicReportColumn(id: 'targetFreeDays', categoryId: 'shipping_logistics', isVisible: false),

      // Packages & CBM
      DynamicReportColumn(id: 'totalPackages', categoryId: 'packages_cbm', isVisible: false),
      DynamicReportColumn(id: 'grossWeightKg', categoryId: 'packages_cbm', isVisible: false),
      DynamicReportColumn(id: 'totalCbm', categoryId: 'packages_cbm', isVisible: false),

      // Customs & Nafeza
      DynamicReportColumn(id: 'acidNumber', categoryId: 'customs_nafeza', isVisible: true),
      DynamicReportColumn(id: 'acidIssueDate', categoryId: 'customs_nafeza', isVisible: false),
      DynamicReportColumn(id: 'acidExpiryDate', categoryId: 'customs_nafeza', isVisible: false),
      DynamicReportColumn(id: 'form46No', categoryId: 'customs_nafeza', isVisible: false),
      DynamicReportColumn(id: 'customsReleaseStatus', categoryId: 'customs_nafeza', isVisible: false),
      DynamicReportColumn(id: 'customsReleasedAt', categoryId: 'customs_nafeza', isVisible: false),

      // Banking & Swift
      DynamicReportColumn(id: 'form4No', categoryId: 'banking_swift', isVisible: true),
      DynamicReportColumn(id: 'form4ReceivedDate', categoryId: 'banking_swift', isVisible: false),
      DynamicReportColumn(id: 'swiftNo', categoryId: 'banking_swift', isVisible: false),
      DynamicReportColumn(id: 'swiftDate', categoryId: 'banking_swift', isVisible: false),
      DynamicReportColumn(id: 'swiftAmount', categoryId: 'banking_swift', isVisible: false),

      // ECO Radar (Milestone & Document Tracking - 15 Columns)
      DynamicReportColumn(id: 'scasProjectFileAcid', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasExFactory', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasOrderToOrigin', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasPickUpDate', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasDeparturePort', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasArrivalAlexPort', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasOrigInvoice', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasOrigPackingList', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasOrigCoo', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasOrigBl', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasOrigInsurance', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasInsertNafeza', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasBankForm4', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasDeclare3A', categoryId: 'eco_radar', isVisible: false),
      DynamicReportColumn(id: 'scasMaterialReceived', categoryId: 'eco_radar', isVisible: false),

      // SCAS Tracker (Operational & Swift Tracking - 16 Columns)
      DynamicReportColumn(id: 'ecoBroker', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoShipmentNo', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoSupplier', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoProject', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoPiValue', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoShippingDate', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoArrivalPort', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoArrivalWarehouse', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoSara', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoMaro', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoReadyToPickUp', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoLatestUpdate', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoSwiftDate', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoSwiftAmount', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoShippingCompany', categoryId: 'scas_tracker', isVisible: false),
      DynamicReportColumn(id: 'ecoAcid', categoryId: 'scas_tracker', isVisible: false),

      // Express Courier & Air Cargo
      DynamicReportColumn(id: 'courierOperator', categoryId: 'courier_air', isVisible: false),
      DynamicReportColumn(id: 'courierTrackingNo', categoryId: 'courier_air', isVisible: false),
      DynamicReportColumn(id: 'shipmentSubMode', categoryId: 'courier_air', isVisible: false),
      DynamicReportColumn(id: 'chargeableDivisor', categoryId: 'courier_air', isVisible: false),
      DynamicReportColumn(id: 'acidRequirement', categoryId: 'courier_air', isVisible: false),
      DynamicReportColumn(id: 'acidExemptionReason', categoryId: 'courier_air', isVisible: false),

      // Container Lifecycle & Demurrage
      DynamicReportColumn(id: 'blNumber', categoryId: 'containers_demurrage', isVisible: false),
      DynamicReportColumn(id: 'bookingNo', categoryId: 'containers_demurrage', isVisible: false),
      DynamicReportColumn(id: 'vesselName', categoryId: 'containers_demurrage', isVisible: false),
      DynamicReportColumn(id: 'deliveryOrderNo', categoryId: 'containers_demurrage', isVisible: false),
      DynamicReportColumn(id: 'deliveryOrderExpiryDate', categoryId: 'containers_demurrage', isVisible: false),
      DynamicReportColumn(id: 'emptyContainersReturnedAt', categoryId: 'containers_demurrage', isVisible: false),
      DynamicReportColumn(id: 'emptyContainersReturnStatus', categoryId: 'containers_demurrage', isVisible: false),
      DynamicReportColumn(id: 'emptyContainersEirNumbers', categoryId: 'containers_demurrage', isVisible: false),
      DynamicReportColumn(id: 'emptyContainersDepotName', categoryId: 'containers_demurrage', isVisible: false),

      // Customs Release & Duties
      DynamicReportColumn(id: 'customsReleasePermitNo', categoryId: 'customs_release_duties', isVisible: false),
      DynamicReportColumn(id: 'customsReleaseType', categoryId: 'customs_release_duties', isVisible: false),
      DynamicReportColumn(id: 'customsReleaseOfficer', categoryId: 'customs_release_duties', isVisible: false),
      DynamicReportColumn(id: 'customsGatePassNo', categoryId: 'customs_release_duties', isVisible: false),
      DynamicReportColumn(id: 'customsDutyPaidAmount', categoryId: 'customs_release_duties', isVisible: false),
      DynamicReportColumn(id: 'customsDutyReceiptNo', categoryId: 'customs_release_duties', isVisible: false),
      DynamicReportColumn(id: 'customsDutySadadNo', categoryId: 'customs_release_duties', isVisible: false),
      DynamicReportColumn(id: 'customsDutyPaymentDate', categoryId: 'customs_release_duties', isVisible: false),
      DynamicReportColumn(id: 'customsBrokerDelegationNo', categoryId: 'customs_release_duties', isVisible: false),

      // Inland Haulage & Warehouse Transport
      DynamicReportColumn(id: 'inlandTransportStatus', categoryId: 'inland_haulage', isVisible: false),
      DynamicReportColumn(id: 'inlandCarrierName', categoryId: 'inland_haulage', isVisible: false),
      DynamicReportColumn(id: 'inlandTruckPlateNo', categoryId: 'inland_haulage', isVisible: false),
      DynamicReportColumn(id: 'inlandDriverName', categoryId: 'inland_haulage', isVisible: false),
      DynamicReportColumn(id: 'inlandDriverPhone', categoryId: 'inland_haulage', isVisible: false),
      DynamicReportColumn(id: 'inlandTransportCostEgp', categoryId: 'inland_haulage', isVisible: false),
      DynamicReportColumn(id: 'inlandDepartureDate', categoryId: 'inland_haulage', isVisible: false),
      DynamicReportColumn(id: 'inlandActualArrivalDate', categoryId: 'inland_haulage', isVisible: false),

      // Actual Landed Cost & Settlement
      DynamicReportColumn(id: 'totalClearanceExpensesEgp', categoryId: 'landed_cost_settlement', isVisible: false),
      DynamicReportColumn(id: 'actualLandedCostTotalEgp', categoryId: 'landed_cost_settlement', isVisible: false),
      DynamicReportColumn(id: 'actualLandedCostMarkupFactor', categoryId: 'landed_cost_settlement', isVisible: false),
      DynamicReportColumn(id: 'actualLandedCostVarianceEgp', categoryId: 'landed_cost_settlement', isVisible: false),
      DynamicReportColumn(id: 'actualLandedCostVariancePct', categoryId: 'landed_cost_settlement', isVisible: false),
      DynamicReportColumn(id: 'financialSettlementStatus', categoryId: 'landed_cost_settlement', isVisible: false),

      // CargoX & Digital Documents Courier
      DynamicReportColumn(id: 'cargoxEnvelopeCode', categoryId: 'cargox_digital_docs', isVisible: false),
      DynamicReportColumn(id: 'cargoxEnvelopeStatus', categoryId: 'cargox_digital_docs', isVisible: false),
      DynamicReportColumn(id: 'cargoxTransferredAt', categoryId: 'cargox_digital_docs', isVisible: false),
      DynamicReportColumn(id: 'originalDocumentsCourierNo', categoryId: 'cargox_digital_docs', isVisible: false),
      DynamicReportColumn(id: 'originalDocumentsStatus', categoryId: 'cargox_digital_docs', isVisible: false),
      DynamicReportColumn(id: 'originalDocumentsReceivedAt', categoryId: 'cargox_digital_docs', isVisible: false),

      // Partial Shipments & Hierarchy
      DynamicReportColumn(id: 'isPartialShipment', categoryId: 'partial_shipments', isVisible: false),
      DynamicReportColumn(id: 'parentFileCode', categoryId: 'partial_shipments', isVisible: false),

      // Operational Notes & Hold Status
      DynamicReportColumn(id: 'holdReason', categoryId: 'holds_notes', isVisible: false),
      DynamicReportColumn(id: 'holdDate', categoryId: 'holds_notes', isVisible: false),
      DynamicReportColumn(id: 'hsCode', categoryId: 'holds_notes', isVisible: false),
      DynamicReportColumn(id: 'productCategory', categoryId: 'holds_notes', isVisible: false),
    ];
  }

  /// Resolves localized category title from category identifier.
  static String getCategoryTitle(BuildContext context, String catId) {
    final l = context.l10n;
    switch (catId) {
      case 'file_project':
        return l.dynCatFileAndProject;
      case 'commercial_po':
        return l.dynCatCommercialAndPo;
      case 'shipping_logistics':
        return l.dynCatShippingAndLogistics;
      case 'packages_cbm':
        return l.dynCatPackagesAndCbm;
      case 'customs_nafeza':
        return l.dynCatCustomsAndNafeza;
      case 'banking_swift':
        return l.dynCatBankingAndSwift;
      case 'scas_tracker':
        return l.dynCatScasTracking;
      case 'eco_radar':
        return l.dynCatEcoTracking;
      case 'courier_air':
        return l.dynCatCourierAir;
      case 'containers_demurrage':
        return l.dynCatContainersDemurrage;
      case 'customs_release_duties':
        return l.dynCatCustomsReleaseDuties;
      case 'inland_haulage':
        return l.dynCatInlandHaulage;
      case 'landed_cost_settlement':
        return l.dynCatLandedCostSettlement;
      case 'cargox_digital_docs':
        return l.dynCatCargoXDigitalDocs;
      case 'partial_shipments':
        return l.dynCatPartialShipments;
      case 'holds_notes':
        return l.dynCatHoldsNotes;
      default:
        return catId;
    }
  }

  /// Resolves localized column title from column identifier.
  static String getColumnLabel(BuildContext context, String colId) {
    final l = context.l10n;
    switch (colId) {
      case 'importFileCode':
        return l.dynColImportFileCode;
      case 'customFileNumber':
        return l.dynColCustomFileNumber;
      case 'companyName':
        return l.dynColCompanyName;
      case 'supplierName':
        return l.dynColSupplierName;
      case 'brokerName':
        return l.dynColBrokerName;
      case 'projectNames':
        return l.dynColProjectNames;
      case 'owner':
        return l.dynColOwner;
      case 'status':
        return l.dynColStatus;
      case 'currentStage':
        return l.dynColCurrentStage;
      case 'progressPercent':
        return l.dynColProgressPercent;
      case 'priority':
        return l.dynColPriority;
      case 'nextAction':
        return l.dynColNextAction;
      case 'fileOpeningDate':
        return l.dynColFileOpeningDate;
      case 'notes':
        return l.dynColNotes;
      case 'updatedAt':
        return l.dynColUpdatedAt;
      case 'poNumber':
        return l.dynColPoNumber;
      case 'piNumber':
        return l.dynColPiNumber;
      case 'piValue':
        return l.dynColPiValue;
      case 'incotermCode':
        return l.dynColIncotermCode;
      case 'estimatedCost':
        return l.dynColEstimatedCost;
      case 'shipmentMode':
        return l.dynColShipmentMode;
      case 'shippingLine':
        return l.dynColShippingLine;
      case 'portOfLoading':
        return l.dynColPortOfLoading;
      case 'portOfDischarge':
        return l.dynColPortOfDischarge;
      case 'cargoReadyDate':
        return l.dynColCargoReadyDate;
      case 'requiredEta':
        return l.dynColRequiredEta;
      case 'targetFreeDays':
        return l.dynColTargetFreeDays;
      case 'totalPackages':
        return l.dynColTotalPackages;
      case 'grossWeightKg':
        return l.dynColGrossWeightKg;
      case 'totalCbm':
        return l.dynColTotalCbm;
      case 'acidNumber':
        return l.dynColAcidNumber;
      case 'acidIssueDate':
        return l.dynColAcidIssueDate;
      case 'acidExpiryDate':
        return l.dynColAcidExpiryDate;
      case 'form46No':
        return l.dynColForm46No;
      case 'customsReleaseStatus':
        return l.dynColCustomsReleaseStatus;
      case 'customsReleasedAt':
        return l.dynColCustomsReleasedAt;
      case 'form4No':
        return l.dynColForm4No;
      case 'form4ReceivedDate':
        return l.dynColForm4ReceivedDate;
      case 'swiftNo':
        return l.dynColSwiftNo;
      case 'swiftDate':
        return l.dynColSwiftDate;
      case 'swiftAmount':
        return l.dynColSwiftAmount;
      case 'ecoBroker':
        return l.dynColEcoBroker;
      case 'ecoShipmentNo':
        return l.dynColEcoShipmentNo;
      case 'ecoSupplier':
        return l.dynColEcoSupplier;
      case 'ecoProject':
        return l.dynColEcoProject;
      case 'ecoPiValue':
        return l.dynColEcoPiValue;
      case 'ecoShippingDate':
        return l.dynColEcoShippingDate;
      case 'ecoArrivalPort':
        return l.dynColEcoArrivalPort;
      case 'ecoArrivalWarehouse':
        return l.dynColEcoArrivalWarehouse;
      case 'ecoSara':
        return l.dynColEcoSara;
      case 'ecoMaro':
        return l.dynColEcoMaro;
      case 'ecoReadyToPickUp':
        return l.dynColEcoReadyToPickUp;
      case 'ecoLatestUpdate':
        return l.dynColEcoLatestUpdate;
      case 'ecoSwiftDate':
        return l.dynColEcoSwiftDate;
      case 'ecoSwiftAmount':
        return l.dynColEcoSwiftAmount;
      case 'ecoShippingCompany':
        return l.dynColEcoShippingCompany;
      case 'ecoAcid':
        return l.dynColEcoAcid;
      case 'scasProjectFileAcid':
        return l.dynColScasProjectFileAcid;
      case 'scasExFactory':
        return l.dynColScasExFactory;
      case 'scasOrderToOrigin':
        return l.dynColScasOrderToOrigin;
      case 'scasPickUpDate':
        return l.dynColScasPickUpDate;
      case 'scasDeparturePort':
        return l.dynColScasDeparturePort;
      case 'scasArrivalAlexPort':
        return l.dynColScasArrivalAlexPort;
      case 'scasOrigInvoice':
        return l.dynColScasOrigInvoice;
      case 'scasOrigPackingList':
        return l.dynColScasOrigPackingList;
      case 'scasOrigCoo':
        return l.dynColScasOrigCoo;
      case 'scasOrigBl':
        return l.dynColScasOrigBl;
      case 'scasOrigInsurance':
        return l.dynColScasOrigInsurance;
      case 'scasInsertNafeza':
        return l.dynColScasInsertNafeza;
      case 'scasBankForm4':
        return l.dynColScasBankForm4;
      case 'scasDeclare3A':
        return l.dynColScasDeclare3A;
      case 'scasMaterialReceived':
        return l.dynColScasMaterialReceived;
      case 'courierOperator':
        return l.dynColCourierOperator;
      case 'courierTrackingNo':
        return l.dynColCourierTrackingNo;
      case 'shipmentSubMode':
        return l.dynColShipmentSubMode;
      case 'chargeableDivisor':
        return l.dynColChargeableDivisor;
      case 'acidRequirement':
        return l.dynColAcidRequirement;
      case 'acidExemptionReason':
        return l.dynColAcidExemptionReason;
      case 'blNumber':
        return l.dynColBlNumber;
      case 'bookingNo':
        return l.dynColBookingNo;
      case 'vesselName':
        return l.dynColVesselName;
      case 'deliveryOrderNo':
        return l.dynColDeliveryOrderNo;
      case 'deliveryOrderExpiryDate':
        return l.dynColDeliveryOrderExpiryDate;
      case 'emptyContainersReturnedAt':
        return l.dynColEmptyContainersReturnedAt;
      case 'emptyContainersReturnStatus':
        return l.dynColEmptyContainersReturnStatus;
      case 'emptyContainersEirNumbers':
        return l.dynColEmptyContainersEirNumbers;
      case 'emptyContainersDepotName':
        return l.dynColEmptyContainersDepotName;
      case 'customsReleasePermitNo':
        return l.dynColCustomsReleasePermitNo;
      case 'customsReleaseType':
        return l.dynColCustomsReleaseType;
      case 'customsReleaseOfficer':
        return l.dynColCustomsReleaseOfficer;
      case 'customsGatePassNo':
        return l.dynColCustomsGatePassNo;
      case 'customsDutyPaidAmount':
        return l.dynColCustomsDutyPaidAmount;
      case 'customsDutyReceiptNo':
        return l.dynColCustomsDutyReceiptNo;
      case 'customsDutySadadNo':
        return l.dynColCustomsDutySadadNo;
      case 'customsDutyPaymentDate':
        return l.dynColCustomsDutyPaymentDate;
      case 'customsBrokerDelegationNo':
        return l.dynColCustomsBrokerDelegationNo;
      case 'inlandTransportStatus':
        return l.dynColInlandTransportStatus;
      case 'inlandCarrierName':
        return l.dynColInlandCarrierName;
      case 'inlandTruckPlateNo':
        return l.dynColInlandTruckPlateNo;
      case 'inlandDriverName':
        return l.dynColInlandDriverName;
      case 'inlandDriverPhone':
        return l.dynColInlandDriverPhone;
      case 'inlandTransportCostEgp':
        return l.dynColInlandTransportCostEgp;
      case 'inlandDepartureDate':
        return l.dynColInlandDepartureDate;
      case 'inlandActualArrivalDate':
        return l.dynColInlandActualArrivalDate;
      case 'totalClearanceExpensesEgp':
        return l.dynColTotalClearanceExpensesEgp;
      case 'actualLandedCostTotalEgp':
        return l.dynColActualLandedCostTotalEgp;
      case 'actualLandedCostMarkupFactor':
        return l.dynColActualLandedCostMarkupFactor;
      case 'actualLandedCostVarianceEgp':
        return l.dynColActualLandedCostVarianceEgp;
      case 'actualLandedCostVariancePct':
        return l.dynColActualLandedCostVariancePct;
      case 'financialSettlementStatus':
        return l.dynColFinancialSettlementStatus;
      case 'cargoxEnvelopeCode':
        return l.dynColCargoxEnvelopeCode;
      case 'cargoxEnvelopeStatus':
        return l.dynColCargoxEnvelopeStatus;
      case 'cargoxTransferredAt':
        return l.dynColCargoxTransferredAt;
      case 'originalDocumentsCourierNo':
        return l.dynColOriginalDocumentsCourierNo;
      case 'originalDocumentsStatus':
        return l.dynColOriginalDocumentsStatus;
      case 'originalDocumentsReceivedAt':
        return l.dynColOriginalDocumentsReceivedAt;
      case 'isPartialShipment':
        return l.dynColIsPartialShipment;
      case 'parentFileCode':
        return l.dynColParentFileCode;
      case 'holdReason':
        return l.dynColHoldReason;
      case 'holdDate':
        return l.dynColHoldDate;
      case 'hsCode':
        return l.dynColHsCode;
      case 'productCategory':
        return l.dynColProductCategory;
      default:
        return colId;
    }
  }

  /// Resolves localized template mode title.
  static String getTemplateTitle(BuildContext context, ReportTemplateMode mode) {
    final l = context.l10n;
    switch (mode) {
      case ReportTemplateMode.eco:
        return l.dynTemplateEco;
      case ReportTemplateMode.scas:
        return l.dynTemplateScas;
      case ReportTemplateMode.custom:
        return l.dynTemplateCustom;
    }
  }

  /// Formats date-time string as yyyy-MM-dd HH:mm:ss
  static String formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }
}
