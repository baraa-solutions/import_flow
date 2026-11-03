import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../../shipping_scenarios/models/shipping_scenario_model.dart';
import '../../models/freight_booking_model.dart';
import '../../services/booking_charge_builder.dart';
import 'booking_quote_form_data.dart';

/// Form controller that manages state, controllers, and payload assembly for [FreightBookingFormDialog].
class BookingFormController {
  late final TextEditingController bookingConfirmNo;
  late final TextEditingController pol;
  late final TextEditingController pod;
  late final TextEditingController vesselName;
  late final TextEditingController voyageNo;
  late final TextEditingController releaseOrderNo;
  late final TextEditingController freeDemurrage;
  late final TextEditingController expectedWhDays;
  late final TextEditingController owner;
  late final TextEditingController notes;

  int? selectedImportFileId;
  int? selectedScenarioSessionId;
  int? selectedScenarioItemId;
  String? selectedScenarioProviderName;

  String shipmentType = 'Ocean FCL';
  String freightTerms = 'Collect';
  String status = 'Draft';
  String? shippingLineName;
  int? shippingLineId;
  String? freightForwarderName;
  int? freightForwarderId;
  int? polLocationId;
  int? podLocationId;
  int? rfqRequestId;

  DateTime? etd;
  DateTime? eta;
  DateTime? atd;
  String? containerMismatchReason;

  List<ContainerAllocationModel> containers = [];
  List<BookingChargeModel> charges = [];
  int quoteRevision = 0;
  bool has40ftMismatch = false;
  bool has20ftMismatch = false;

  final quoteData = BookingQuoteFormData();

  bool get hasQuoteMismatch => has40ftMismatch || has20ftMismatch;
  FbkQuoteState get currentQuoteState => quoteData.toQuoteState();

  void init(ShipmentBookingModel? b, bool isClone) {
    bookingConfirmNo = TextEditingController(text: isClone ? "" : (b?.bookingConfirmationNo ?? ""));
    pol = TextEditingController(text: b?.polName ?? '');
    pod = TextEditingController(text: b?.podName ?? '');
    vesselName = TextEditingController(text: isClone ? "" : (b?.vesselName ?? ""));
    voyageNo = TextEditingController(text: isClone ? "" : (b?.voyageNumber ?? ""));
    releaseOrderNo = TextEditingController(text: isClone ? "" : (b?.containerReleaseOrderNo ?? ""));
    freeDemurrage = TextEditingController(text: b?.freeDemurrageDays != null ? b!.freeDemurrageDays.toString() : '');
    expectedWhDays = TextEditingController(text: (b?.expectedWarehouseDays ?? 7).toString());
    owner = TextEditingController(text: isClone ? '' : (b?.owner ?? ''));
    notes = TextEditingController(text: b?.notes ?? '');

    selectedImportFileId = b?.importFileId;
    selectedScenarioSessionId = b?.scenarioSessionId;
    selectedScenarioItemId = b?.scenarioItemId;
    selectedScenarioProviderName = b?.scenarioProviderName;
    containerMismatchReason = b?.containerMismatchReason;

    shipmentType = b?.shipmentType ?? 'Ocean FCL';
    freightTerms = b?.freightTerms ?? 'Collect';
    status = isClone ? 'Draft' : (b?.status ?? 'Draft');
    shippingLineName = b?.shippingLineName;
    shippingLineId = b?.shippingLineId;
    freightForwarderName = b?.freightForwarderName;
    freightForwarderId = b?.freightForwarderId;
    polLocationId = b?.polLocationId;
    podLocationId = b?.podLocationId;
    rfqRequestId = b?.rfqRequestId;

    if (b?.etd != null) etd = DateTime.tryParse(b!.etd!);
    if (b?.eta != null) eta = DateTime.tryParse(b!.eta!);
    if (!isClone && b?.atd != null) atd = DateTime.tryParse(b!.atd!);

    if (b?.containersData != null && b!.containersData.isNotEmpty) {
      containers = List.from(b.containersData);
    }
    if (b?.costChargesData != null && b!.costChargesData.isNotEmpty) {
      charges = List.from(b.costChargesData);
    }
    if (b?.quotationDetailsData != null && b!.quotationDetailsData.isNotEmpty) {
      quoteData.loadFromMap(b.quotationDetailsData, fallbackOriginalQuoteTotalUsd: b.originalFreightCostUsd);
    }
  }

  void dispose() {
    bookingConfirmNo.dispose();
    pol.dispose();
    pod.dispose();
    vesselName.dispose();
    voyageNo.dispose();
    releaseOrderNo.dispose();
    freeDemurrage.dispose();
    expectedWhDays.dispose();
    owner.dispose();
    notes.dispose();
  }

  void reset() {
    selectedImportFileId = null;
    selectedScenarioSessionId = null;
    selectedScenarioItemId = null;
    selectedScenarioProviderName = null;
    bookingConfirmNo.clear();
    vesselName.clear();
    voyageNo.clear();
    notes.clear();
    releaseOrderNo.clear();
    shippingLineName = null;
    shippingLineId = null;
    freightForwarderName = null;
    freightForwarderId = null;
    polLocationId = null;
    pol.clear();
    podLocationId = null;
    pod.clear();
    etd = null;
    eta = null;
    atd = null;
    freeDemurrage.text = '14';
    expectedWhDays.text = '7';
    status = 'Draft';
    containers = [];
    charges = [];
    quoteData.reset();
  }

  void applyScenarioQuote(ShippingEvaluationModel session, ShippingScenarioItemModel item) {
    quoteRevision++;
    selectedScenarioSessionId = session.sessionId;
    selectedScenarioItemId = item.itemId;
    selectedScenarioProviderName = item.providerName;
    shippingLineName = item.providerName;
    freightForwarderName = item.providerName;
    vesselName.text = item.vesselName;
    if (item.voyageNumber?.isNotEmpty == true) voyageNo.text = item.voyageNumber!;
    if (item.polName?.isNotEmpty == true) pol.text = item.polName!;
    if (item.podName?.isNotEmpty == true) pod.text = item.podName!;
    final pEtd = DateTime.tryParse(item.sailingDate);
    if (pEtd != null) etd = pEtd;
    final pEta = DateTime.tryParse(item.estimatedArrivalDate);
    if (pEta != null) eta = pEta;
    freeDemurrage.text = item.freeTimeDays.toString();

    quoteData.applyScenarioItem(item);

    final newC = <ContainerAllocationModel>[];
    if (item.container40ftApplicable && item.container40ftQty > 0) {
      newC.add(ContainerAllocationModel(containerType: '40HC', quantity: item.container40ftQty));
    }
    if (item.container20ftApplicable && item.container20ftQty > 0) {
      newC.add(ContainerAllocationModel(containerType: '20GP', quantity: item.container20ftQty));
    }
    if (newC.isNotEmpty) {
      containers = newC;
      shipmentType = 'Ocean FCL';
    } else if (item.lclCbmApplicable && item.lclCbmQty > 0) {
      shipmentType = 'Ocean LCL';
    }
  }

  void updateContainerType(String val) {
    if (containers.isEmpty) {
      containers.add(ContainerAllocationModel(containerType: val, quantity: 1));
    } else {
      containers[0] = ContainerAllocationModel(
        containerType: val,
        quantity: containers[0].quantity,
        individualContainers: containers[0].individualContainers,
        vgmWeightKg: containers[0].vgmWeightKg,
      );
    }
  }

  void updateContainerQty(int q) {
    if (containers.isEmpty) {
      containers.add(ContainerAllocationModel(containerType: '40HC', quantity: q));
    } else {
      containers[0] = ContainerAllocationModel(
        containerType: containers[0].containerType,
        quantity: q,
        individualContainers: containers[0].individualContainers,
        vgmWeightKg: containers[0].vgmWeightKg,
      );
    }
  }

  String? getQuoteMismatchError(AppLocalizations l) {
    if (!hasQuoteMismatch) return null;
    if (has40ftMismatch && has20ftMismatch) return l.fbkQuoteEquipmentMismatchBoth;
    if (has40ftMismatch) return l.fbkQuoteEquipmentMismatch40ft;
    return l.fbkQuoteEquipmentMismatch20ft;
  }

  void rebuildCharges() {
    final result = BookingChargeBuilder.build(currentQuoteState, containers: containers);
    charges = result.charges;
    has40ftMismatch = result.has40ftMismatch;
    has20ftMismatch = result.has20ftMismatch;
  }

  Map<String, dynamic> buildPayload({ShipmentBookingModel? bookingToEdit}) {
    final ownerText = owner.text.trim();
    return {
      if (bookingConfirmNo.text.trim().isNotEmpty)
        'booking_confirmation_no': bookingConfirmNo.text.trim(),
      'import_file_id': selectedImportFileId,
      if (rfqRequestId != null) 'rfq_request_id': rfqRequestId,
      'scenario_session_id': selectedScenarioSessionId,
      'scenario_item_id': selectedScenarioItemId,
      'scenario_provider_name': selectedScenarioProviderName,
      if (freightForwarderId != null) 'freight_forwarder_id': freightForwarderId,
      'freight_forwarder_name': freightForwarderName,
      if (shippingLineId != null) 'shipping_line_id': shippingLineId,
      'shipping_line_name': shippingLineName,
      'shipment_type': shipmentType,
      'transport_mode': shipmentType == 'Air' ? 'AIR_FREIGHT' : (shipmentType == 'Ocean LCL' ? 'SEA_LCL' : 'SEA_FCL'),
      if (bookingToEdit?.masterAirWaybill != null) 'master_air_waybill': bookingToEdit!.masterAirWaybill,
      if (bookingToEdit?.houseAirWaybill != null) 'house_air_waybill': bookingToEdit!.houseAirWaybill,
      if (bookingToEdit?.flightNumber != null) 'flight_number': bookingToEdit!.flightNumber,
      if (bookingToEdit?.airlineCode != null) 'airline_code': bookingToEdit!.airlineCode,
      if (bookingToEdit?.airportTerminalName != null) 'airport_terminal_name': bookingToEdit!.airportTerminalName,
      if (bookingToEdit?.cfsTerminalName != null) 'cfs_terminal_name': bookingToEdit!.cfsTerminalName,
      if (bookingToEdit?.strippingFeesEgp != null) 'stripping_fees_egp': bookingToEdit!.strippingFeesEgp,
      if (bookingToEdit?.chargeableWeightKg != null) 'chargeable_weight_kg': bookingToEdit!.chargeableWeightKg,
      if (polLocationId != null) 'pol_location_id': polLocationId,
      'pol_name': pol.text.trim(),
      if (podLocationId != null) 'pod_location_id': podLocationId,
      'pod_name': pod.text.trim(),
      'etd': etd?.toIso8601String(),
      'eta': eta?.toIso8601String(),
      'atd': atd?.toIso8601String(),
      'free_demurrage_days': freeDemurrage.text.trim().isNotEmpty ? int.tryParse(freeDemurrage.text.trim()) : null,
      'expected_warehouse_days': int.parse(expectedWhDays.text.trim()),
      'vessel_name': vesselName.text.trim(),
      'voyage_number': voyageNo.text.trim(),
      'container_release_order_no': releaseOrderNo.text.trim(),
      'freight_terms': freightTerms,
      'container_mismatch_reason': containerMismatchReason,
      'containers_data': containers.map((c) => c.toJson()).toList(),
      'cost_charges_data': charges.map((c) => c.toJson()).toList(),
      'quotation_details_data': quoteData.toMap(),
      'original_freight_cost_usd': quoteData.originalQuoteTotalUsd,
      'status': status,
      if (ownerText.isNotEmpty) 'owner': ownerText,
      'notes': notes.text.trim(),
    };
  }

  static ContainerRecommendationResult? calculateCargoMetrics({
    required int? selectedImportFileId,
    required List<dynamic> importFiles,
    required List<dynamic> poList,
    required bool isStackable,
  }) {
    if (selectedImportFileId == null) return null;
    final curFile = importFiles.where((f) => f.importFileId == selectedImportFileId).firstOrNull;
    if (curFile == null) return null;

    double totalCargoCbm = 0.0;
    double totalCargoWeightKg = 0.0;
    for (var pl in curFile.packingListsData) {
      totalCargoCbm += pl.cbm;
      totalCargoWeightKg += pl.grossWeightKg;
    }
    final filePos = poList.where((p) => (curFile.poIds ?? []).contains(p.poId)).toList();
    for (var po in filePos) {
      for (var pl in po.packingListItems) {
        totalCargoCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
        totalCargoWeightKg += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
      }
    }

    if (totalCargoCbm <= 0 && totalCargoWeightKg <= 0) return null;
    final dual = ContainerRequirementEngine.calculateBoth(totalCbm: totalCargoCbm, totalWeightKg: totalCargoWeightKg);
    return isStackable ? dual.stackableResult : dual.nonStackableResult;
  }
}
