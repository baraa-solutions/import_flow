import '../../external_service_providers/models/partner_model.dart';
import '../../freight_quotations/widgets/freight_quotations_extractor_dialog.dart';
import '../models/shipping_scenario_model.dart';

class ShippingQuoteSmartMapper {
  ShippingQuoteSmartMapper._();

  static dynamic matchPortSmart(String rawPortText, List portsList) {
    if (rawPortText.trim().isEmpty) return null;
    final raw = rawPortText.toLowerCase();

    // 1. Direct UN/LOCODE exact or substring match
    for (final p in portsList) {
      final unloc = (p.unLocode ?? '').toString().toLowerCase();
      if (unloc.isNotEmpty && (raw.contains(unloc) || unloc.contains(raw))) {
        return p;
      }
    }

    // 2. Tokenized word matching
    final portKeywords = [
      'ningbo', 'dekheila', 'dek', 'alexandria', 'alex', 'shanghai', 'sokhna', 'damietta',
      'port said', 'cairo', 'qingdao', 'shenzhen', 'guangzhou', 'xiamen',
      'tianjin', 'yantian', 'busan', 'rotterdam', 'hamburg', 'antwerp',
      'genoa', 'valencia', 'istanbul', 'mersin', 'jebel ali', 'jeddah', 'adabiya',
      'نينغبو', 'الدخيلة', 'الإسكندرية', 'السخنة', 'دمياط', 'بورسعيد', 'شنغهاي', 'القاهرة'
    ];

    for (final kw in portKeywords) {
      if (raw.contains(kw)) {
        for (final p in portsList) {
          final pName = (p.locationName ?? '').toString().toLowerCase();
          if (pName.contains(kw)) {
            return p;
          }
        }
      }
    }

    // 3. Fallback: pName contains raw or raw contains pName
    for (final p in portsList) {
      final pName = (p.locationName ?? '').toString().toLowerCase();
      if (pName.isNotEmpty && (raw.contains(pName) || pName.contains(raw))) {
        return p;
      }
    }

    return null;
  }

  static ShippingScenarioItemModel mapExtractedOptionToScenarioItem({
    required ExtractedQuotationOption opt,
    required DateTime crd,
    required List<PartnerModel> partners,
    required List portsList,
    required bool isRecommended,
  }) {
    final rawCarrier = opt.carrierName;
    final cntrType = opt.containerType;
    final rate = opt.oceanFreight;
    final localCharges = opt.localCharges;
    final cancelFee = opt.exwCharges;
    final freeDays = opt.freeTimeDays ?? 21;
    final transitDays = opt.transitDays ?? 28;
    final isDirect = opt.isDirect;
    final notes = opt.notes;
    final curr = opt.currency;

    // 1. Match Shipping Line
    final shippingLines = partners.where((p) => p.partnerType.contains('Shipping Line') || p.partnerType.contains('Carrier')).toList();
    final matchedLine = shippingLines.where((p) =>
      p.partnerName.toLowerCase().contains(rawCarrier.toLowerCase()) ||
      rawCarrier.toLowerCase().contains(p.partnerName.toLowerCase()) ||
      (p.scacCode != null && rawCarrier.toLowerCase().contains(p.scacCode!.toLowerCase())) ||
      (rawCarrier.toLowerCase().contains('whl') && (p.partnerName.toLowerCase().contains('wan hai') || (p.scacCode ?? '').toLowerCase() == 'whl')) ||
      (rawCarrier.toLowerCase().contains('yml') && (p.partnerName.toLowerCase().contains('yang ming') || (p.scacCode ?? '').toLowerCase() == 'yml')) ||
      (rawCarrier.toLowerCase().contains('msc') && (p.partnerName.toLowerCase().contains('msc') || (p.scacCode ?? '').toLowerCase() == 'msc')) ||
      (rawCarrier.toLowerCase().contains('msk') && (p.partnerName.toLowerCase().contains('maersk') || (p.scacCode ?? '').toLowerCase() == 'msk')) ||
      (rawCarrier.toLowerCase().contains('cma') && (p.partnerName.toLowerCase().contains('cma') || (p.scacCode ?? '').toLowerCase() == 'cma')) ||
      (rawCarrier.toLowerCase().contains('cosco') && (p.partnerName.toLowerCase().contains('cosco') || (p.scacCode ?? '').toLowerCase() == 'cosco')) ||
      (rawCarrier.toLowerCase().contains('emc') && (p.partnerName.toLowerCase().contains('evergreen') || (p.scacCode ?? '').toLowerCase() == 'emc')) ||
      (rawCarrier.toLowerCase().contains('one') && (p.partnerName.toLowerCase().contains('ocean network') || (p.scacCode ?? '').toLowerCase() == 'one')) ||
      (rawCarrier.toLowerCase().contains('hapag') && (p.partnerName.toLowerCase().contains('hapag') || (p.scacCode ?? '').toLowerCase() == 'hapag'))
    ).firstOrNull;
    final effectiveCarrierName = matchedLine != null ? matchedLine.partnerName : rawCarrier;

    // 2. Match Freight Forwarder
    final freightForwarders = partners.where((p) => p.partnerType.contains('Freight Forwarder') || p.partnerType.contains('Carrier')).toList();
    final rawForwarder = opt.forwarderName ?? '';
    final matchedForwarder = rawForwarder.isNotEmpty
        ? freightForwarders.where((p) =>
            p.partnerName.toLowerCase().contains(rawForwarder.toLowerCase()) ||
            rawForwarder.toLowerCase().contains(p.partnerName.toLowerCase())).firstOrNull
        : null;

    // 3. Match Port of Loading POL
    final rawPol = (opt.originPort ?? '').toLowerCase();
    final dynamic matchedPol = matchPortSmart(rawPol, portsList);

    // 4. Match Port of Discharge POD
    final rawPod = (opt.destinationPort ?? '').toLowerCase();
    final dynamic matchedPod = matchPortSmart(rawPod, portsList);

    // 5. Vessel & Voyage
    final effectiveVessel = (opt.vesselName != null && opt.vesselName!.isNotEmpty)
        ? opt.vesselName!
        : (isDirect ? 'Direct Line Service' : 'Transshipment Service');
    final effectiveVoyage = opt.voyageNumber ?? '';

    // 6. Sailing Date ETD & Estimated Arrival ETA
    DateTime sDate = crd.add(const Duration(days: 2));
    if (opt.etdDate != null && opt.etdDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(opt.etdDate!);
      if (parsed != null) sDate = parsed;
    }

    DateTime arrDate = sDate.add(Duration(days: transitDays));
    if (opt.etaDate != null && opt.etaDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(opt.etaDate!);
      if (parsed != null) arrDate = parsed;
    }

    final is40 = cntrType.contains('40');
    final is20 = cntrType.contains('20');

    double extraFeeAmount = (localCharges != null && localCharges > 0) ? localCharges : 0.0;
    if (notes != null && notes.isNotEmpty) {
      final m = RegExp(r'(?:USD|\$|EUR|EGP)\s*([0-9,]+(?:\.\d+)?)', caseSensitive: false).firstMatch(notes);
      if (m != null) {
        final parsed = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (parsed != null && parsed > 0 && extraFeeAmount == 0.0) {
          extraFeeAmount = parsed;
        }
      }
    }

    return ShippingScenarioItemModel(
      providerId: matchedForwarder?.providerId,
      providerName: effectiveCarrierName,
      vesselName: effectiveVessel,
      voyageNumber: effectiveVoyage,
      portOfLoadingId: matchedPol?.locationId,
      polName: matchedPol != null ? matchedPol.locationName : opt.originPort,
      portOfDischargeId: matchedPod?.locationId,
      podName: matchedPod != null ? matchedPod.locationName : opt.destinationPort,
      sailingDate: sDate.toString().substring(0, 10),
      estimatedArrivalDate: arrDate.toString().substring(0, 10),
      expectedLineDelayDays: isDirect ? 2 : 5,
      isRecommended: isRecommended,
      riskLevel: isDirect ? 'Low' : 'Medium',
      quotationCurrency: curr,
      freeTimeDays: freeDays,
      container40ftApplicable: is40,
      container40ftPrice: is40 ? rate : 0.0,
      container40ftQty: is40 ? 1 : 0,
      container40ftCurrency: curr,
      container20ftApplicable: is20,
      container20ftPrice: is20 ? rate : 0.0,
      container20ftQty: is20 ? 1 : 0,
      container20ftCurrency: curr,
      bookingCancellationApplicable: cancelFee != null && cancelFee > 0,
      bookingCancellationPrice: cancelFee ?? 0.0,
      bookingCancellationCurrency: curr,
      othersFeeApplicable: extraFeeAmount > 0,
      othersFeePrice: extraFeeAmount,
      othersFeeCurrency: curr,
      notes: [
        if (!isDirect) 'رحلة غير مباشرة',
        if (notes != null && notes.isNotEmpty) notes,
        if (localCharges != null && localCharges > 0) 'مصاريف محلية / EXW: \$$localCharges',
      ].join(' — '),
    );
  }
}
