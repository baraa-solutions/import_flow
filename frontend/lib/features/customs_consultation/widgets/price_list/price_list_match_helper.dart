import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';

/// Localized category label helper with pure language separation.
String getCategoryLabel(String category, BuildContext context) {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final clean = category.split('(').first.trim();
  switch (clean) {
    case 'Clearance Fees':
      return context.l10n.ccClearanceFees;
    case 'Procedures & Approvals':
      return context.l10n.ccProceduresApprovals;
    case 'Inland Transport':
      return context.l10n.ccInlandTransport;
    case 'Port & Handling':
      return context.l10n.ccPortHandling;
    case 'Other Fees':
      return context.l10n.othersFeeItem;
    default:
      if (isAr) {
        final match = RegExp(r'\(([\u0600-\u06FF\s]+)\)').firstMatch(category);
        if (match != null) return match.group(1)!.trim();
        return clean;
      } else {
        return clean;
      }
  }
}

/// Localized unit label helper with pure language separation.
String getUnitLabel(String unit, BuildContext context) {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final clean = unit.split('(').first.trim().toLowerCase().replaceAll(' ', '_');
  switch (clean) {
    case 'fixed':
      return context.l10n.ccFixedAmount;
    case 'per_container':
      return context.l10n.ccPerContainer;
    case 'per_invoice':
      return context.l10n.ccPerInvoice;
    case 'per_ton':
      return context.l10n.ccPerTon;
    case 'per_truck':
    case 'per_vehicle':
      return context.l10n.ccPerTruck;
    case 'per_day':
      return context.l10n.ccPerDay;
    case 'per_night':
      return context.l10n.ccPerNight;
    case 'per_inspection':
      return context.l10n.ccPerInspection;
    case 'per_shipment':
      return context.l10n.ccPerShipment;
    case 'per_declaration':
      return context.l10n.ccPerDeclaration;
    case 'per_bl':
      return context.l10n.ccPerBillOfLading;
    case 'per_sample':
      return context.l10n.ccPerSample;
    case 'per_certificate':
      return context.l10n.ccPerCertificate;
    default:
      if (isAr) {
        final match = RegExp(r'\(([\u0600-\u06FF\s]+)\)').firstMatch(unit);
        if (match != null) return match.group(1)!.trim();
        final arabicOnly = unit.replaceAll(RegExp(r'[a-zA-Z\(\)]'), '').trim();
        return arabicOnly.isNotEmpty ? arabicOnly : unit.split('(').first.trim();
      } else {
        return unit.split('(').first.trim();
      }
  }
}

/// Standard benchmark rates mapping for customs expenses.
const standardRatesMap = <String, double>{
  'أتعاب تخليص LCL': 1250.0,
  'واحد طن LCL مصاريف تخليص': 4750.0,
  'لكل طن زيادة LCL': 1000.0,
  'أتعاب تخليص حاوية 20 قدم': 2500.0,
  'مصاريف تخليص أول حاوية 20 قدم': 7500.0,
  'مصاريف تخليص كل حاوية 20 قدم زيادة': 1500.0,
  'أتعاب تخليص حاوية 40 قدم': 2500.0,
  'مصاريف تخليص أول حاوية 40 قدم': 7500.0,
  'مصاريف تخليص كل حاوية 40 قدم زيادة': 2000.0,
  'بريد - دمغات': 250.0,
  'عرض الواردات + اعتماد الإيباك': 3500.0,
  'عرض الواردات + اعتماد الإيلاك': 3000.0,
  'ACID رسوم استخراج وإصدار': 1000.0,
  'زراعة ومهمل وسيل': 1150.0,
  'أمن عام + مندوب الأمن العام + سحب العينات': 1500.0,
  'عرض أمن عام للقاهرة': 5000.0,
  'وثيقة تأمين': 500.0,
  'عرض أشعة إكس راي': 250.0,
  'تطبيق الاتفاقيات التفضيلية': 1000.0,
  'الإفراج تحت التحفظ': 350.0,
  'غسيل جمركي': 250.0,
  'مطافئ': 1000.0,
  'دمغة وموازين': 1000.0,
  'مفرقعات': 1000.0,
  'إفراج نهائي': 500.0,
  'إشعاع': 1000.0,
  'عرض زراعة مشمول': 1500.0,
  'عرض مصلحة الكيمياء': 1500.0,
  'سحب إذن / تصوير / تعديل منافستو': 750.0,
  'مصاريف وزن قماش': 1500.0,
  'إنهاء إجراءات زيادة الوزن': 750.0,
  'سيارة 1 طن دبابة إسكندرية - قاهرة': 6150.0,
  'سيارة جامبو حتى 4 طن إسكندرية - قاهرة': 8200.0,
  'سيارة فرداني حتى 7 طن إسكندرية - قاهرة': 14150.0,
  'حاوية 20 قدم حتى 10 طن إسكندرية - قاهرة': 14800.0,
  'حاوية 20 قدم أكثر من 10 طن إسكندرية - قاهرة': 18400.0,
  'حاويتين 20*2 قدم إسكندرية - قاهرة': 23300.0,
  'حاوية 40 قدم إسكندرية - قاهرة': 18400.0,
  'بياتة شاحنة 20*2': 4200.0,
  'بياتة شاحنة 40*1': 3600.0,
  'بياتة شاحنة 20*1': 3000.0,
  'تعتيق ميناء أبوقير': 4250.0,
  'نقل الحاوية للوزن داخل الميناء': 3500.0,
  'كشف عمال وكلارك': 1250.0,
};

/// Normalizes Arabic text for flexible matching.
String normalizeArabic(String s) {
  var str = s.toLowerCase().trim();
  str = str.replaceAll(RegExp(r'[أإآ]'), 'ا');
  str = str.replaceAll('ة', 'ه');
  str = str.replaceAll('ى', 'ي');
  str = str.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ');
  return str.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Calculates similarity matching score between item names.
int calculateMatchScore(String name, String extName) {
  final n1 = normalizeArabic(name);
  final n2 = normalizeArabic(extName);
  if (n1 == n2) return 100;
  if (n1.isEmpty || n2.isEmpty) return 0;
  if (n1.contains(n2) || n2.contains(n1)) return 80;

  // LCL items
  if (n1.contains('lcl') && n2.contains('lcl')) {
    if ((n1.contains('فاتوره') && n2.contains('فاتوره')) || (n1.contains('اتعاب') && n2.contains('اتعاب'))) {
      return 95;
    }
    if (n1.contains('واحد طن') && n2.contains('واحد طن')) return 95;
    if ((n1.contains('زياده') || n1.contains('اضافي')) && (n2.contains('زياده') || n2.contains('اضافي'))) {
      return 95;
    }
  }

  // 20FT vs 40FT
  final has20_1 = n1.contains('20');
  final has20_2 = n2.contains('20');
  final has40_1 = n1.contains('40');
  final has40_2 = n2.contains('40');

  // Prevent 20ft matching 40ft
  if ((has20_1 && has40_2 && !has20_2) || (has40_1 && has20_2 && !has40_2)) {
    return 0;
  }

  // 20ft 2x20 dual
  final isDual_1 = n1.contains('20 2') || n1.contains('20*2') || n1.contains('حاويتين');
  final isDual_2 = n2.contains('20 2') || n2.contains('20*2') || n2.contains('حاويتين');
  if (isDual_1 && isDual_2) {
    if (n1.contains('بياته') && n2.contains('بياته')) return 95;
    if (n1.contains('نقل') && n2.contains('نقل')) return 95;
  }
  if (isDual_1 != isDual_2 && (isDual_1 || isDual_2)) {
    return 0;
  }

  // 20ft single
  if (has20_1 && has20_2) {
    if (n1.contains('بياته') && n2.contains('بياته')) return 90;
    if (n1.contains('اول حاويه') && (n2.contains('اول حاويه') || n2.contains('1 حاويه'))) return 95;
    if (n1.contains('زياده') && n2.contains('زياده')) return 95;
    if ((n1.contains('فاتوره') && n2.contains('فاتوره')) || (n1.contains('اتعاب') && n2.contains('اتعاب'))) return 95;
    if (n2.contains('اكبر') || n1.contains('اكثر')) {
      if ((n2.contains('اكبر') || n2.contains('اكثر')) && (n1.contains('اكبر') || n1.contains('اكثر'))) return 95;
    } else if ((n2.contains('اقل') || n1.contains('حتي') || n1.contains('اقل')) && (!n2.contains('اكبر') && !n2.contains('اكثر'))) {
      return 95;
    }
  }

  // 40ft
  if (has40_1 && has40_2) {
    if (n1.contains('بياته') && n2.contains('بياته')) return 95;
    if (n1.contains('اول حاويه') && (n2.contains('اول حاويه') || n2.contains('1 حاويه'))) return 95;
    if (n1.contains('زياده') && n2.contains('زياده')) return 95;
    if ((n1.contains('فاتوره') && n2.contains('فاتوره')) || (n1.contains('اتعاب') && n2.contains('اتعاب'))) return 95;
    if (n1.contains('نقل') && n2.contains('نقل')) return 90;
  }

  // Inland transport trucks
  if (n1.contains('دبابه') && n2.contains('دبابه')) return 95;
  if (n1.contains('جامبو') && n2.contains('جامبو')) return 95;
  if (n1.contains('فرداني') && n2.contains('فرداني')) return 95;

  // Procedures & approvals
  if (n1.contains('acid') && n2.contains('acid')) return 95;
  if (n1.contains('بريد') && n2.contains('بريد')) return 95;
  if ((n1.contains('واردات') || n1.contains('ايلاك') || n1.contains('ايباك')) &&
      (n2.contains('واردات') || n2.contains('ايلاك') || n2.contains('ايباك'))) {
    return 90;
  }
  if (n1.contains('امن عام') && n2.contains('امن عام')) {
    if (n1.contains('قاهره') && n2.contains('قاهره')) return 95;
    if (!n1.contains('قاهره') && !n2.contains('قاهره')) return 90;
  }
  if (n1.contains('تامين') && n2.contains('تامين')) return 95;
  if (n1.contains('اكس راي') && n2.contains('اكس راي')) return 95;
  if (n1.contains('اتفاقيات') && n2.contains('اتفاقيات')) return 95;
  if (n1.contains('تحفظ') && n2.contains('تحفظ')) return 95;
  if (!n1.contains('غسيل') && !n2.contains('غسيل')) {
    if ((n1.contains('سيل') || n1.contains('ترصيص')) && (n2.contains('سيل') || n2.contains('ترصيص'))) return 95;
  }
  if (n1.contains('غسيل') && n2.contains('غسيل')) return 95;
  if (n1.contains('ابوقير') && n2.contains('ابوقير')) return 95;
  if (n1.contains('وزن') && n2.contains('وزن') && n1.contains('ميناء') && n2.contains('ميناء')) return 95;
  if ((n1.contains('سحب') || n1.contains('اذن')) && (n2.contains('سحب') || n2.contains('اذن'))) return 90;

  return 0;
}

/// Applies extracted expenses into the items state list.
void applyExtractedExpenses(
  Map<String, dynamic> extracted,
  List<Map<String, dynamic>> itemsState, {
  required bool isInitial,
}) {
  final expensesCatalog = (extracted['expenses_catalog'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ??
      [];
  final cFee = (extracted['clearance_fee'] as num?)?.toDouble();
  final inlandFee = (extracted['inland_transport_fee'] as num?)?.toDouble();
  final inspFee = (extracted['inspection_fee'] as num?)?.toDouble();
  final portFee = (extracted['port_expenses'] as num?)?.toDouble();
  final miscFee = (extracted['miscellaneous_fee'] as num?)?.toDouble();

  final matchedExtractedIndices = <int>{};

  for (var itm in itemsState) {
    final name = (itm['expense_name'] as String? ?? '').trim();
    double? foundPrice;
    double? minP;
    double? maxP;
    String? notes;

    int bestScore = 0;
    int bestExtIdx = -1;
    Map<String, dynamic>? bestExtItem;

    for (int i = 0; i < expensesCatalog.length; i++) {
      final extItem = expensesCatalog[i];
      final extName = ((extItem['item_name'] ?? extItem['expense_name']) as String? ?? '').trim();
      final extPrice = ((extItem['price'] ?? extItem['amount']) as num?)?.toDouble() ?? 0.0;
      if (extPrice > 0) {
        final score = calculateMatchScore(name, extName);
        if (score > bestScore) {
          bestScore = score;
          bestExtIdx = i;
          bestExtItem = extItem;
        }
      }
    }

    if (bestScore >= 80 && bestExtItem != null) {
      foundPrice = ((bestExtItem['price'] ?? bestExtItem['amount']) as num?)?.toDouble();
      minP = (bestExtItem['min_price'] as num?)?.toDouble();
      maxP = (bestExtItem['max_price'] as num?)?.toDouble();
      notes = bestExtItem['notes']?.toString();
      if (bestExtItem['code'] != null) {
        itm['code'] = bestExtItem['code'];
        itm['is_uncoded'] = bestExtItem['is_uncoded'] == true;
      }
      itm['confidence'] = (bestExtItem['confidence'] as num?)?.toDouble() ?? bestScore.toDouble();
      itm['raw_extracted_text'] = ((bestExtItem['item_name'] ?? bestExtItem['expense_name']) as String? ?? '').trim();
      matchedExtractedIndices.add(bestExtIdx);
    }

    // High-level fee bucket fallback
    if (foundPrice == null || foundPrice == 0.0) {
      if (cFee != null && cFee > 0 && name.contains('تخليص') && (name.contains('40') || name.contains('20')) && !name.contains('LCL')) {
        foundPrice = cFee;
        itm['confidence'] = 90.0;
        itm['raw_extracted_text'] = 'أتعاب تخليص جمركي';
      } else if (inlandFee != null && inlandFee > 0 && (name.contains('نقل') || name.contains('شاحنة')) && name.contains('40')) {
        foundPrice = inlandFee;
        itm['confidence'] = 90.0;
        itm['raw_extracted_text'] = 'نقل داخلي 40 قدم';
      } else if (inlandFee != null && inlandFee > 0 && (name.contains('نقل') || name.contains('شاحنة')) && name.contains('20') && !name.contains('20*2')) {
        foundPrice = inlandFee * 0.8;
        itm['confidence'] = 85.0;
        itm['raw_extracted_text'] = 'نقل داخلي 20 قدم';
      } else if (inspFee != null && inspFee > 0 && (name.contains('فحص') || name.contains('واردات') || name.contains('إيباك'))) {
        foundPrice = inspFee;
        itm['confidence'] = 90.0;
        itm['raw_extracted_text'] = 'فحص وإجراءات جمركية';
      } else if (portFee != null && portFee > 0 && name.contains('أول حاوية')) {
        foundPrice = portFee;
        itm['confidence'] = 88.0;
        itm['raw_extracted_text'] = 'مصاريف ميناء';
      } else if (miscFee != null && miscFee > 0 && (name.contains('بريد') || name.contains('دمغات') || name.contains('نثريات'))) {
        foundPrice = miscFee;
        itm['confidence'] = 85.0;
        itm['raw_extracted_text'] = 'رسوم ودمغات إدارية';
      }
    }

    // Benchmark rates fallback
    if ((foundPrice == null || foundPrice == 0.0) && isInitial) {
      for (var entry in standardRatesMap.entries) {
        if (calculateMatchScore(name, entry.key) >= 80) {
          foundPrice = entry.value;
          break;
        }
      }
    }

    if (foundPrice != null && foundPrice > 0) {
      itm['standard_price'] = foundPrice;
      if (minP != null) itm['min_price'] = minP;
      if (maxP != null) itm['max_price'] = maxP;
      if (notes != null && notes.isNotEmpty) itm['notes'] = notes;
    }
  }

  // Custom items that were not in default catalog
  for (int i = expensesCatalog.length - 1; i >= 0; i--) {
    if (matchedExtractedIndices.contains(i)) continue;
    final extItem = expensesCatalog[i];
    final extName = ((extItem['item_name'] ?? extItem['expense_name']) as String? ?? '').trim();
    final extPrice = ((extItem['price'] ?? extItem['amount']) as num?)?.toDouble() ?? 0.0;
    if (extPrice > 0) {
      final alreadyInItems = itemsState.any((itm) {
        final existingName = (itm['expense_name'] as String? ?? '').trim();
        return calculateMatchScore(existingName, extName) >= 80;
      });
      if (!alreadyInItems) {
        final isUncoded = extItem['is_uncoded'] == true || extItem['code'] == null;
        final conf = (extItem['confidence'] as num?)?.toDouble() ?? (isUncoded ? 50.0 : 75.0);
        itemsState.insert(0, {
          'expense_type_id': null,
          'code': extItem['code'],
          'is_uncoded': isUncoded,
          'confidence': conf,
          'raw_extracted_text': extName,
          'expense_name': extName,
          'category': (extItem['category']?.toString() ?? 'Other Fees').split('(').first.trim(),
          'unit_type': (((extItem['pricing_unit'] ?? extItem['unit_type'])?.toString()) ?? 'Per Shipment').split('(').first.trim(),
          'standard_price': extPrice,
          'currency': extItem['currency']?.toString() ?? 'EGP',
          'min_price': (extItem['min_price'] as num?)?.toDouble(),
          'max_price': (extItem['max_price'] as num?)?.toDouble(),
          'notes': extItem['notes']?.toString() ?? '',
          'is_active': true,
        });
      }
    }
  }
}
