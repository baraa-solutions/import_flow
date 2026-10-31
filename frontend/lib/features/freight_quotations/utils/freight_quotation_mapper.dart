import '../models/freight_quotation_model.dart';
import '../widgets/freight_quotations_extractor_dialog.dart';

class FreightQuotationMapper {
  static List<FreightQuotationItemModel> mapExtractedOptions({
    required List<ExtractedQuotationOption> selectedOptions,
    required List<dynamic> partners,
    required DateTime defaultSailingDate,
  }) {
    final list = <FreightQuotationItemModel>[];
    for (final opt in selectedOptions) {
      int providerId = 0;
      String providerName = opt.carrierName;
      final matchedPartner = partners.cast<dynamic>().firstWhere(
        (p) {
          final name = (p.name ?? '').toString().toLowerCase();
          final optName = opt.carrierName.toLowerCase();
          return name.contains(optName) || optName.contains(name);
        },
        orElse: () => null,
      );
      if (matchedPartner != null) {
        providerId = matchedPartner.id as int? ?? 0;
        providerName = matchedPartner.name as String? ?? opt.carrierName;
      }
      final transitDays = opt.transitDays ?? 28;
      final arrivalDate = defaultSailingDate.add(Duration(days: transitDays));
      list.add(FreightQuotationItemModel(
        providerId: providerId,
        providerName: providerName,
        voyageNumber: opt.containerType,
        oceanFreightCost: opt.oceanFreight,
        localChargesCost: opt.localCharges ?? 0.0,
        inlandCost: opt.exwCharges ?? 0.0,
        totalCost: opt.totalEstimatedCost,
        sailingDate: defaultSailingDate.toString().substring(0, 10),
        estimatedArrivalDate: arrivalDate.toString().substring(0, 10),
        transitDays: transitDays,
        freeDaysAtPod: opt.freeTimeDays ?? 14,
        remarks: [
          if (opt.notes != null && opt.notes!.isNotEmpty) opt.notes,
          if (opt.containerType.isNotEmpty) 'نوع الحاوية: ${opt.containerType}',
          if (!opt.isDirect) 'خط سير غير مباشر (ترانزيت)',
        ].join(' | '),
      ));
    }
    return list;
  }
}
