import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../cargo_shipping/providers/cargo_shipping_provider.dart';
import '../../../freight_booking/providers/freight_booking_provider.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../models/cargo_insurance_model.dart';

class InsuranceFormControllers {
  String policyType = 'SPECIFIC';
  final TextEditingController insuredEntityCtrl = TextEditingController();
  final TextEditingController insuranceCompanyCtrl = TextEditingController();
  final TextEditingController policyNoCtrl = TextEditingController();

  String transportMode = 'OCEAN';
  final TextEditingController carrierCtrl = TextEditingController();
  final TextEditingController vesselFlightCtrl = TextEditingController();
  final TextEditingController voyageNoCtrl = TextEditingController();
  final TextEditingController trackingRefCtrl = TextEditingController();
  final TextEditingController polCtrl = TextEditingController();
  final TextEditingController podCtrl = TextEditingController();
  final TextEditingController finalDestCtrl = TextEditingController();

  String currency = 'USD';
  final TextEditingController exchangeRateCtrl = TextEditingController();
  final TextEditingController invoiceValueCtrl = TextEditingController(text: '0.0');
  final TextEditingController freightCostCtrl = TextEditingController(text: '0.0');
  final TextEditingController otherCostsCtrl = TextEditingController(text: '0.0');
  final TextEditingController markupCtrl = TextEditingController();

  String coverageClause = 'ICC_A';
  bool includeWarAndStrikes = true;
  final TextEditingController minPremiumCtrl = TextEditingController();
  final TextEditingController issuanceFeeCtrl = TextEditingController();
  final TextEditingController taxRateCtrl = TextEditingController();

  final TextEditingController goodsDescCtrl = TextEditingController();
  final TextEditingController packageCountCtrl = TextEditingController();
  final TextEditingController packageTypeCtrl = TextEditingController();
  final TextEditingController grossWeightCtrl = TextEditingController();
  final TextEditingController surveyAgentCtrl = TextEditingController();
  final TextEditingController claimsPayableAtCtrl = TextEditingController();
  final TextEditingController remarksCtrl = TextEditingController();

  void populateFromCertificate(CargoInsuranceModel c) {
    policyType = c.policyType;
    insuredEntityCtrl.text = c.insuredEntityName;
    insuranceCompanyCtrl.text = c.insuranceCompanyName ?? '';
    policyNoCtrl.text = c.policyNumber ?? '';
    transportMode = c.transportMode;
    carrierCtrl.text = c.carrierName ?? '';
    vesselFlightCtrl.text = c.vesselOrFlightNo ?? '';
    voyageNoCtrl.text = c.voyageNumber ?? '';
    trackingRefCtrl.text = c.trackingReference ?? '';
    polCtrl.text = c.portOfLoading;
    podCtrl.text = c.portOfDischarge;
    finalDestCtrl.text = c.finalDestination ?? '';
    currency = c.currency;
    exchangeRateCtrl.text = c.exchangeRate.toString();
    invoiceValueCtrl.text = c.invoiceValue.toString();
    freightCostCtrl.text = c.freightCost.toString();
    otherCostsCtrl.text = c.otherLogisticsCosts.toString();
    markupCtrl.text = c.markupPercentage.toString();
    coverageClause = c.coverageClause;
    includeWarAndStrikes = c.includeWarAndStrikes;
    minPremiumCtrl.text = c.minimumPremium.toString();
    issuanceFeeCtrl.text = c.issuanceFee.toString();
    taxRateCtrl.text = c.taxRate.toString();
    goodsDescCtrl.text = c.goodsDescription ?? '';
    packageCountCtrl.text = c.packageCount?.toString() ?? '';
    packageTypeCtrl.text = c.packageType ?? '';
    grossWeightCtrl.text = c.grossWeightKg?.toString() ?? '';
    surveyAgentCtrl.text = c.surveyAgentInDestination ?? '';
    claimsPayableAtCtrl.text = c.claimsPayableAt ?? '';
    remarksCtrl.text = c.remarks ?? '';
  }

  void autoFillFromImportFile(WidgetRef ref, ImportFileModel file) {
    final bookings = ref.read(freightBookingProvider).value ?? [];
    final linkedBooking = bookings
        .where((b) => b.importFileId == file.importFileId && b.isActive)
        .firstOrNull;

    final shippingRecords = ref.read(cargoShippingProvider).value ?? [];
    final linkedShipping = shippingRecords
        .where((s) => s.importFileId == file.importFileId && s.isActive)
        .firstOrNull;

    final purchaseOrders = ref.read(purchaseOrdersProvider).purchaseOrders;
    final linkedPOs = purchaseOrders
        .where((po) => po.importFileId == file.importFileId && po.isActive)
        .toList();

    String mode = 'OCEAN';
    final bookingMode = (linkedBooking?.shipmentType ?? '').toLowerCase();
    final fileMode = file.shipmentMode.toLowerCase();
    if (bookingMode.contains('air') || fileMode.contains('air') || fileMode.contains('جوي')) {
      mode = 'AIR';
    } else if (bookingMode.contains('land') || bookingMode.contains('road') || fileMode.contains('land') || fileMode.contains('road') || fileMode.contains('بري')) {
      mode = 'ROAD';
    } else {
      mode = 'OCEAN';
    }

    String carrier = '';
    if (linkedBooking != null) {
      carrier = linkedBooking.shippingLineName ?? linkedBooking.freightForwarderName ?? linkedBooking.scenarioProviderName ?? '';
    }
    if (carrier.isEmpty) {
      carrier = file.brokerName ?? '';
    }

    String vessel = '';
    String voyage = '';
    if (linkedBooking != null) {
      if (linkedBooking.vesselName != null && linkedBooking.vesselName!.isNotEmpty) {
        vessel = linkedBooking.vesselName!;
      }
      if (linkedBooking.voyageNumber != null && linkedBooking.voyageNumber!.isNotEmpty) {
        voyage = linkedBooking.voyageNumber!;
      }
    }

    String pol = '';
    if (linkedBooking != null && linkedBooking.polName != null && linkedBooking.polName!.isNotEmpty) {
      pol = linkedBooking.polName!;
    } else if (file.portOfLoading != null && file.portOfLoading!.isNotEmpty) {
      pol = file.portOfLoading!;
    }

    String pod = '';
    if (linkedBooking != null && linkedBooking.podName != null && linkedBooking.podName!.isNotEmpty) {
      pod = linkedBooking.podName!;
    } else if (file.portOfDischarge != null && file.portOfDischarge!.isNotEmpty) {
      pod = file.portOfDischarge!;
    }

    String bl = '';
    if (linkedShipping != null && linkedShipping.courierTrackingData.trackingNumber != null && linkedShipping.courierTrackingData.trackingNumber!.isNotEmpty) {
      bl = linkedShipping.courierTrackingData.trackingNumber!;
    } else if (linkedBooking != null && linkedBooking.bookingConfirmationNo != null && linkedBooking.bookingConfirmationNo!.isNotEmpty) {
      bl = linkedBooking.bookingConfirmationNo!;
    } else if (linkedBooking != null && linkedBooking.containerReleaseOrderNo != null && linkedBooking.containerReleaseOrderNo!.isNotEmpty) {
      bl = linkedBooking.containerReleaseOrderNo!;
    } else if (file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      bl = file.customFileNumber!;
    }

    double invVal = 0.0;
    if (file.invoicesData.isNotEmpty) {
      invVal = file.invoicesData.fold<double>(0.0, (sum, item) => sum + item.amount);
    }
    if (invVal <= 0.0 && linkedPOs.isNotEmpty) {
      invVal = linkedPOs.fold<double>(0.0, (sum, po) => sum + po.totalAmountFob);
    }
    if (invVal <= 0.0 && file.estimatedCost > 0.0) {
      invVal = file.estimatedCost;
    }

    double freightCost = 0.0;
    final bookedFreight = linkedBooking?.totalFreightCostUsd;
    if (bookedFreight != null && bookedFreight > 0.0) {
      freightCost = bookedFreight;
    }

    String curr = 'USD';
    if (file.invoicesData.isNotEmpty && file.invoicesData.first.currency.isNotEmpty) {
      curr = file.invoicesData.first.currency.toUpperCase();
    } else if (linkedPOs.isNotEmpty && (linkedPOs.first.currencyCode ?? '').isNotEmpty) {
      curr = linkedPOs.first.currencyCode!.toUpperCase();
    } else if (file.estimatedCostCurrency.isNotEmpty) {
      curr = file.estimatedCostCurrency.toUpperCase();
    }

    int? pkgCount;
    double? grossWeight;
    String? goodsDesc;
    if (file.packingListsData.isNotEmpty) {
      final totalP = file.packingListsData.fold<int>(0, (sum, p) => sum + p.totalPackages);
      final totalW = file.packingListsData.fold<double>(0.0, (sum, p) => sum + p.grossWeightKg);
      if (totalP > 0) pkgCount = totalP;
      if (totalW > 0) grossWeight = totalW;
    }
    if (file.projectNames != null && file.projectNames!.isNotEmpty) {
      goodsDesc = file.projectNames;
    } else if (linkedPOs.isNotEmpty) {
      final descs = linkedPOs
          .map((po) => po.items
              .map((it) => it.itemDescription)
              .where((d) => d.isNotEmpty)
              .join(', '))
          .where((d) => d.isNotEmpty)
          .join('; ');
      if (descs.isNotEmpty) goodsDesc = descs;
    }

    insuredEntityCtrl.text = file.companyName;
    transportMode = mode;
    if (mode == 'AIR') {
      coverageClause = 'AIR_ALL_RISKS';
    } else if (coverageClause == 'AIR_ALL_RISKS') {
      coverageClause = 'ICC_A';
    }
    if (carrier.isNotEmpty) carrierCtrl.text = carrier;
    if (vessel.isNotEmpty) vesselFlightCtrl.text = vessel;
    if (voyage.isNotEmpty) voyageNoCtrl.text = voyage;
    if (pol.isNotEmpty) polCtrl.text = pol;
    if (pod.isNotEmpty) podCtrl.text = pod;
    if (bl.isNotEmpty) trackingRefCtrl.text = bl;
    invoiceValueCtrl.text = invVal > 0.0 ? invVal.toStringAsFixed(2) : '0.0';
    freightCostCtrl.text = freightCost > 0.0 ? freightCost.toStringAsFixed(2) : '0.0';
    currency = curr;

    if (pkgCount != null) packageCountCtrl.text = pkgCount.toString();
    if (grossWeight != null) grossWeightCtrl.text = grossWeight.toStringAsFixed(1);
    if (goodsDesc != null && goodsDesc.isNotEmpty) goodsDescCtrl.text = goodsDesc;
  }

  double? _optionalNumber(TextEditingController c) => double.tryParse(c.text.trim());

  Map<String, dynamic> toCalculationPayload() {
    return {
      'invoice_value': double.tryParse(invoiceValueCtrl.text) ?? 0.0,
      'freight_cost': double.tryParse(freightCostCtrl.text) ?? 0.0,
      'other_costs': double.tryParse(otherCostsCtrl.text) ?? 0.0,
      'coverage_clause': coverageClause,
      'transport_mode': transportMode,
      'include_war_and_strikes': includeWarAndStrikes,
      'currency': currency,
      if (_optionalNumber(markupCtrl) != null) 'markup_percentage': _optionalNumber(markupCtrl),
      if (_optionalNumber(minPremiumCtrl) != null) 'minimum_premium': _optionalNumber(minPremiumCtrl),
      if (_optionalNumber(issuanceFeeCtrl) != null) 'issuance_fee': _optionalNumber(issuanceFeeCtrl),
      if (_optionalNumber(taxRateCtrl) != null) 'tax_rate': _optionalNumber(taxRateCtrl),
    };
  }

  Map<String, dynamic> toSavePayload(int? selectedImportFileId) {
    return {
      'import_file_id': selectedImportFileId,
      'policy_type': policyType,
      'insured_entity_name': insuredEntityCtrl.text.trim(),
      'insurance_company_name': insuranceCompanyCtrl.text.trim().isNotEmpty ? insuranceCompanyCtrl.text.trim() : null,
      'policy_number': policyNoCtrl.text.trim().isNotEmpty ? policyNoCtrl.text.trim() : null,
      'transport_mode': transportMode,
      'carrier_name': carrierCtrl.text.trim().isNotEmpty ? carrierCtrl.text.trim() : null,
      'vessel_or_flight_no': vesselFlightCtrl.text.trim().isNotEmpty ? vesselFlightCtrl.text.trim() : null,
      'voyage_number': voyageNoCtrl.text.trim().isNotEmpty ? voyageNoCtrl.text.trim() : null,
      'tracking_reference': trackingRefCtrl.text.trim().isNotEmpty ? trackingRefCtrl.text.trim() : null,
      'port_of_loading': polCtrl.text.trim(),
      'port_of_discharge': podCtrl.text.trim(),
      'final_destination': finalDestCtrl.text.trim().isNotEmpty ? finalDestCtrl.text.trim() : null,
      'currency': currency,
      if (_optionalNumber(exchangeRateCtrl) != null) 'exchange_rate': _optionalNumber(exchangeRateCtrl),
      'invoice_value': double.tryParse(invoiceValueCtrl.text) ?? 0.0,
      'freight_cost': double.tryParse(freightCostCtrl.text) ?? 0.0,
      'other_logistics_costs': double.tryParse(otherCostsCtrl.text) ?? 0.0,
      if (_optionalNumber(markupCtrl) != null) 'markup_percentage': _optionalNumber(markupCtrl),
      'coverage_clause': coverageClause,
      'include_war_and_strikes': includeWarAndStrikes,
      if (_optionalNumber(minPremiumCtrl) != null) 'minimum_premium': _optionalNumber(minPremiumCtrl),
      if (_optionalNumber(issuanceFeeCtrl) != null) 'issuance_fee': _optionalNumber(issuanceFeeCtrl),
      if (_optionalNumber(taxRateCtrl) != null) 'tax_rate': _optionalNumber(taxRateCtrl),
      'goods_description': goodsDescCtrl.text.trim().isNotEmpty ? goodsDescCtrl.text.trim() : null,
      'package_count': int.tryParse(packageCountCtrl.text),
      'package_type': packageTypeCtrl.text.trim().isNotEmpty ? packageTypeCtrl.text.trim() : null,
      'gross_weight_kg': double.tryParse(grossWeightCtrl.text),
      'survey_agent_in_destination': surveyAgentCtrl.text.trim().isNotEmpty ? surveyAgentCtrl.text.trim() : null,
      'claims_payable_at': claimsPayableAtCtrl.text.trim().isNotEmpty ? claimsPayableAtCtrl.text.trim() : null,
      'remarks': remarksCtrl.text.trim().isNotEmpty ? remarksCtrl.text.trim() : null,
    };
  }

  void dispose() {
    insuredEntityCtrl.dispose();
    insuranceCompanyCtrl.dispose();
    policyNoCtrl.dispose();
    carrierCtrl.dispose();
    vesselFlightCtrl.dispose();
    voyageNoCtrl.dispose();
    trackingRefCtrl.dispose();
    polCtrl.dispose();
    podCtrl.dispose();
    finalDestCtrl.dispose();
    exchangeRateCtrl.dispose();
    invoiceValueCtrl.dispose();
    freightCostCtrl.dispose();
    otherCostsCtrl.dispose();
    markupCtrl.dispose();
    minPremiumCtrl.dispose();
    issuanceFeeCtrl.dispose();
    taxRateCtrl.dispose();
    goodsDescCtrl.dispose();
    packageCountCtrl.dispose();
    packageTypeCtrl.dispose();
    grossWeightCtrl.dispose();
    surveyAgentCtrl.dispose();
    claimsPayableAtCtrl.dispose();
    remarksCtrl.dispose();
  }
}
