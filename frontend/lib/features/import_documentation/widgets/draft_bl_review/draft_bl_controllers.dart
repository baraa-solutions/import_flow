import 'package:flutter/material.dart';
import '../../models/import_documentation_model.dart';

/// Encapsulates all text editing controllers, field synchronization,
/// and payload construction for Draft B/L Review workflows.
class DraftBlControllers {
  final rawText = TextEditingController();
  final draftBlNumber = TextEditingController();
  final bookingNo = TextEditingController();
  final shipper = TextEditingController();
  final consignee = TextEditingController();
  final notifyParty = TextEditingController();
  final shippingLine = TextEditingController();
  final vesselName = TextEditingController();
  final voyage = TextEditingController();
  final pol = TextEditingController();
  final pod = TextEditingController();
  final freightTerms = TextEditingController();
  final placeOfDelivery = TextEditingController();
  final goodsDesc = TextEditingController();
  final grossWeight = TextEditingController();
  final netWeight = TextEditingController();
  final cbm = TextEditingController();
  final containerNo = TextEditingController();
  final sealNo = TextEditingController();
  final packagesCount = TextEditingController();
  final importerApprover = TextEditingController();
  final importerNotes = TextEditingController();
  final brokerApprover = TextEditingController();
  final brokerNotes = TextEditingController();

  void initUserApprover(String? fullName) {
    if (fullName != null && fullName.isNotEmpty) {
      brokerApprover.text = fullName;
      importerApprover.text = fullName;
    }
  }

  void clearInputs() {
    rawText.clear();
    draftBlNumber.clear();
    bookingNo.clear();
    shipper.clear();
    consignee.clear();
    notifyParty.clear();
    shippingLine.clear();
    vesselName.clear();
    voyage.clear();
    pol.clear();
    pod.clear();
    freightTerms.clear();
    placeOfDelivery.clear();
    goodsDesc.clear();
    grossWeight.clear();
    netWeight.clear();
    cbm.clear();
    packagesCount.clear();
    containerNo.clear();
    sealNo.clear();
  }

  void syncExtractedFields(Map<String, dynamic> d) {
    final extractedBl = d['draft_bl_number'] ?? d['bl_number'] ?? d['bl_no'] ?? d['bill_of_lading_no'] ?? d['bill_of_lading_number'];
    if (extractedBl != null && extractedBl.toString().trim().isNotEmpty) {
      draftBlNumber.text = extractedBl.toString().trim();
    }
    if (d['booking_no'] != null) bookingNo.text = d['booking_no'].toString();
    if (d['shipper'] != null) shipper.text = d['shipper'].toString();
    if (d['consignee'] != null) consignee.text = d['consignee'].toString();
    if (d['notify_party'] != null) notifyParty.text = d['notify_party'].toString();
    if (d['shipping_line'] != null) shippingLine.text = d['shipping_line'].toString();
    if (d['vessel_name'] != null) vesselName.text = d['vessel_name'].toString();
    if (d['voyage_number'] != null) voyage.text = d['voyage_number'].toString();
    if (d['pol'] != null) pol.text = d['pol'].toString();
    if (d['pod'] != null) pod.text = d['pod'].toString();
    if (d['freight_terms'] != null) freightTerms.text = d['freight_terms'].toString();
    if (d['place_of_delivery'] != null) placeOfDelivery.text = d['place_of_delivery'].toString();
    if (d['goods_description'] != null) goodsDesc.text = d['goods_description'].toString();
    if (d['total_gross_weight_kg'] != null) grossWeight.text = d['total_gross_weight_kg'].toString();
    if (d['total_net_weight_kg'] != null) netWeight.text = d['total_net_weight_kg'].toString();
    if (d['cbm'] != null) cbm.text = d['cbm'].toString();
    if (d['qty_pkg'] != null) packagesCount.text = d['qty_pkg'].toString();
    if (d['container_summary'] != null) containerNo.text = d['container_summary'].toString();
  }

  void syncComparisonDraftData(Map<String, dynamic> d) {
    if (d.isEmpty) return;
    if (d['draft_bl_number'] != null && draftBlNumber.text.isEmpty) draftBlNumber.text = d['draft_bl_number'].toString();
    if (d['booking_no'] != null && bookingNo.text.isEmpty) bookingNo.text = d['booking_no'].toString();
    if (d['vessel_name'] != null && vesselName.text.isEmpty) vesselName.text = d['vessel_name'].toString();
    if (d['voyage_number'] != null && voyage.text.isEmpty) voyage.text = d['voyage_number'].toString();
    if (d['pol'] != null && pol.text.isEmpty) pol.text = d['pol'].toString();
    if (d['pod'] != null && pod.text.isEmpty) pod.text = d['pod'].toString();
    if (d['freight_terms'] != null && freightTerms.text.isEmpty) freightTerms.text = d['freight_terms'].toString();
    if (d['total_gross_weight_kg'] != null && grossWeight.text.isEmpty) grossWeight.text = d['total_gross_weight_kg'].toString();
    if (d['cbm'] != null && cbm.text.isEmpty) cbm.text = d['cbm'].toString();
    if (d['qty_pkg'] != null && packagesCount.text.isEmpty) packagesCount.text = d['qty_pkg'].toString();
  }

  void loadFromSession(DraftBLReviewModel session) {
    draftBlNumber.text = session.draftBlNumber;
    shippingLine.text = session.shippingLine ?? '';
    vesselName.text = session.vesselName ?? '';
    voyage.text = session.voyageNumber ?? '';
    bookingNo.text = session.bookingNumber ?? '';
    pol.text = session.polName ?? '';
    pod.text = session.podName ?? '';
    freightTerms.text = session.freightTerms ?? '';
    placeOfDelivery.text = session.placeOfDelivery ?? '';
    grossWeight.text = session.systemDataSnapshot?['total_gross_weight_kg']?.toString() ?? '';
    netWeight.text = session.netWeightKg > 0 ? session.netWeightKg.toString() : '';
    cbm.text = session.measurementCbm > 0 ? session.measurementCbm.toString() : '';
    packagesCount.text = session.packagesCount > 0 ? session.packagesCount.toString() : '';
    containerNo.text = session.containerSummary ?? '';
  }

  Map<String, dynamic> toDraftFields() {
    final fields = <String, dynamic>{};
    if (draftBlNumber.text.isNotEmpty) fields['draft_bl_number'] = draftBlNumber.text.trim();
    if (bookingNo.text.isNotEmpty) fields['booking_no'] = bookingNo.text.trim();
    if (shipper.text.isNotEmpty) fields['shipper'] = shipper.text.trim();
    if (consignee.text.isNotEmpty) fields['consignee'] = consignee.text.trim();
    if (notifyParty.text.isNotEmpty) fields['notify_party'] = notifyParty.text.trim();
    if (shippingLine.text.isNotEmpty) fields['shipping_line'] = shippingLine.text.trim();
    if (vesselName.text.isNotEmpty) fields['vessel_name'] = vesselName.text.trim();
    if (voyage.text.isNotEmpty) fields['voyage_number'] = voyage.text.trim();
    if (pol.text.isNotEmpty) fields['pol'] = pol.text.trim();
    if (pod.text.isNotEmpty) fields['pod'] = pod.text.trim();
    if (freightTerms.text.isNotEmpty) fields['freight_terms'] = freightTerms.text.trim();
    if (placeOfDelivery.text.isNotEmpty) fields['place_of_delivery'] = placeOfDelivery.text.trim();
    if (goodsDesc.text.isNotEmpty) fields['goods_description'] = goodsDesc.text.trim();
    if (grossWeight.text.isNotEmpty) fields['total_gross_weight_kg'] = double.tryParse(grossWeight.text);
    if (netWeight.text.isNotEmpty) fields['total_net_weight_kg'] = double.tryParse(netWeight.text);
    if (cbm.text.isNotEmpty) fields['cbm'] = double.tryParse(cbm.text);
    if (packagesCount.text.isNotEmpty) fields['qty_pkg'] = int.tryParse(packagesCount.text);
    if (containerNo.text.isNotEmpty) {
      fields['container_summary'] = '${containerNo.text.trim()} / Seal: ${sealNo.text.trim()}';
      fields['containers'] = [{'container_no': containerNo.text.trim(), 'seal_no': sealNo.text.trim()}];
    }
    return fields;
  }

  Map<String, dynamic> buildSavePayload({
    required int importFileId,
    required DraftBLComparisonResultModel? comparisonResult,
    required bool isDraft,
  }) {
    final draftData = comparisonResult?.draftData ?? {};
    final sysData = comparisonResult?.systemData ?? {};

    return {
      'import_file_id': importFileId,
      'draft_bl_number': draftBlNumber.text.trim().isNotEmpty
          ? draftBlNumber.text.trim()
          : (draftData['draft_bl_number']?.toString() ?? 'DRAFT-BL-${DateTime.now().millisecondsSinceEpoch}'),
      'shipping_line': shippingLine.text.trim().isNotEmpty ? shippingLine.text.trim() : (draftData['shipping_line']?.toString() ?? ''),
      'vessel_name': vesselName.text.trim().isNotEmpty ? vesselName.text.trim() : (draftData['vessel_name']?.toString() ?? ''),
      'voyage_number': voyage.text.trim().isNotEmpty ? voyage.text.trim() : (draftData['voyage_number']?.toString() ?? ''),
      'booking_no': bookingNo.text.trim().isNotEmpty ? bookingNo.text.trim() : (draftData['booking_no']?.toString() ?? ''),
      'freight_terms': freightTerms.text.trim().isNotEmpty ? freightTerms.text.trim() : (draftData['freight_terms']?.toString() ?? 'Prepaid'),
      'place_of_delivery': placeOfDelivery.text.trim().isNotEmpty ? placeOfDelivery.text.trim() : (draftData['place_of_delivery']?.toString() ?? ''),
      'importer_tax_id': sysData['importer_tax_id']?.toString() ?? '',
      'shipper_reg_id': sysData['shipper_reg_id']?.toString() ?? '',
      'measurement_cbm': double.tryParse(cbm.text) ?? ((draftData['cbm'] as num?)?.toDouble() ?? 0.0),
      'net_weight_kg': double.tryParse(netWeight.text) ?? ((draftData['total_net_weight_kg'] as num?)?.toDouble() ?? 0.0),
      'packages_count': int.tryParse(packagesCount.text) ?? ((draftData['qty_pkg'] as num?)?.toInt() ?? 0),
      'container_summary': containerNo.text.trim().isNotEmpty ? containerNo.text.trim() : (draftData['container_summary']?.toString() ?? ''),
      'system_snapshot_data': sysData,
      'draft_input_data': draftData,
      'comparison_matrix': comparisonResult?.matrix.map((m) => m.toJson()).toList() ?? [],
      'checklist_data': comparisonResult?.checklist.map((c) => c.toJson()).toList() ?? [],
      'revision_report_data': comparisonResult?.revisionReport.map((r) => r.toJson()).toList() ?? [],
      'has_blocking_mismatch': comparisonResult?.hasBlockingMismatch ?? false,
      'open_discrepancies_count': comparisonResult?.openDiscrepanciesCount ?? 0,
      'blocking_reasons': comparisonResult?.blockingReasons ?? [],
      'blocking_reasons_coded': comparisonResult?.blockingReasonsCoded ?? [],
      'is_draft': isDraft,
      'correction_request_letter': comparisonResult?.correctionRequestLetter,
    };
  }

  void dispose() {
    rawText.dispose();
    draftBlNumber.dispose();
    bookingNo.dispose();
    shipper.dispose();
    consignee.dispose();
    notifyParty.dispose();
    shippingLine.dispose();
    vesselName.dispose();
    voyage.dispose();
    pol.dispose();
    pod.dispose();
    freightTerms.dispose();
    placeOfDelivery.dispose();
    goodsDesc.dispose();
    grossWeight.dispose();
    netWeight.dispose();
    cbm.dispose();
    containerNo.dispose();
    sealNo.dispose();
    packagesCount.dispose();
    importerApprover.dispose();
    importerNotes.dispose();
    brokerApprover.dispose();
    brokerNotes.dispose();
  }
}
