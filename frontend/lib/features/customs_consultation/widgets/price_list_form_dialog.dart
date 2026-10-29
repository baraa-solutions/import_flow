import '../../../core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/customs_consultation_model.dart';
import '../providers/customs_consultation_provider.dart';
import '../../../core/localization/api_error_text.dart';
import '../utils/customs_expense_group_helper.dart';
import 'quick_expense_coding_dialog.dart';
import 'extraction_confidence_indicator.dart';
import 'extraction_summary_dialog.dart';

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

void showPriceListFormDialog(
  BuildContext context,
  WidgetRef ref, {
  BrokerPriceListModel? existingPriceList,
  required List<dynamic> brokersList,
  Map<String, dynamic>? initialExtractedData,
}) {
  final l = context.l10n;
  if (brokersList.isEmpty && existingPriceList == null) {
    ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.noBrokersRegistered, severity: AppSeverity.warning));
    return;
  }

  final isEditing = existingPriceList != null;
  int? selectedBroker = existingPriceList?.brokerId;
  final titleCtrl = TextEditingController(text: existingPriceList?.title ?? (initialExtractedData?['title'] ?? ''));
  final portCtrl = TextEditingController(text: existingPriceList?.portName ?? (initialExtractedData?['port_name'] ?? ''));
  final notesCtrl = TextEditingController(text: existingPriceList?.notes ?? (initialExtractedData?['notes'] ?? ''));
  final dateCtrl = TextEditingController(text: existingPriceList?.effectiveFrom ?? (initialExtractedData?['effective_from'] ?? DateTime.now().toIso8601String().split('T').first));
  int version = existingPriceList?.version ?? 1;

  // Standard benchmark mapping
  final standardRatesMap = <String, double>{
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
    '(X-Ray) عرض إكس راي': 250.0,
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
    'سيارة 1 طن (دبابة) إسكندرية - قاهرة': 6150.0,
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

  // Load items either from existing price list or from master expense catalog
  if (!ref.read(expenseCatalogProvider).isLoading && ref.read(expenseCatalogProvider).valueOrNull == null) {
    Future.microtask(() => ref.read(expenseCatalogProvider.notifier).fetchCatalog());
  }
  final catalog = ref.read(clearanceExpenseTypesProvider).valueOrNull ?? [];
  final List<Map<String, dynamic>> itemsState = [];

  String normalizeArabic(String s) {
    var str = s.toLowerCase().trim();
    str = str.replaceAll(RegExp(r'[أإآ]'), 'ا');
    str = str.replaceAll('ة', 'ه');
    str = str.replaceAll('ى', 'ي');
    str = str.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ');
    return str.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

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
      return 0; // Don't confuse dual 20ft with single 20ft
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

  void applyExtractedExpenses(Map<String, dynamic> extracted, {required bool isInitial}) {
    final expensesCatalog = (extracted['expenses_catalog'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
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

      // 1. Match against expenses_catalog from AI extractor with score >= 80
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

      // 2. Match against high-level extracted fee buckets ONLY if not matched above
      if (foundPrice == null || foundPrice == 0.0) {
        // IMPORTANT: NEVER overwrite LCL with cFee (2500)!
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

      // 3. Fallback to standard benchmark rates map if still 0.0
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

    // 4. Any custom line items from expenses_catalog that were NOT matched to standard catalog:
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

  if (isEditing) {
    for (final itm in existingPriceList.items) {
      itemsState.add({
        'item_id': itm.itemId,
        'expense_type_id': itm.expenseTypeId,
        'code': itm.code,
        'is_uncoded': itm.isUncoded,
        'price_type': itm.priceType,
        'expense_name': itm.expenseName,
        'category': itm.category,
        'unit_type': itm.unitType,
        'standard_price': itm.standardPrice,
        'currency': itm.currency,
        'min_price': itm.minPrice,
        'max_price': itm.maxPrice,
        'notes': itm.notes ?? '',
        'is_active': itm.isActive,
        'confidence': itm.confidence,
        'raw_extracted_text': itm.rawExtractedText,
      });
    }
  } else {
    for (final exp in catalog) {
      itemsState.add({
        'expense_type_id': exp.expenseId,
        'code': exp.expenseCode,
        'is_uncoded': false,
        'price_type': 'fixed',
        'expense_name': exp.nameAr,
        'category': exp.category,
        'unit_type': exp.defaultUnit,
        'standard_price': 0.0,
        'currency': exp.defaultCurrency,
        'min_price': null,
        'max_price': null,
        'notes': '',
        'is_active': true,
      });
    }

    if (initialExtractedData != null) {
      applyExtractedExpenses(initialExtractedData, isInitial: true);
    } else {
      for (var itm in itemsState) {
        final name = itm['expense_name'] as String;
        for (var entry in standardRatesMap.entries) {
          if (name.contains(entry.key) || entry.key.contains(name)) {
            itm['standard_price'] = entry.value;
            break;
          }
        }
      }
    }
  }

  for (var itm in itemsState) {
    if (itm['price_type'] == null) {
      final stdP = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
      final minP = (itm['min_price'] as num?)?.toDouble();
      final maxP = (itm['max_price'] as num?)?.toDouble();
      if (minP != null || maxP != null) {
        itm['price_type'] = 'range';
      } else if (stdP == 0.0) {
        itm['price_type'] = 'negotiable';
      } else {
        itm['price_type'] = 'fixed';
      }
    }
  }

  // Pre-fill broker from initialExtractedData if provided
  if (initialExtractedData != null && !isEditing) {
    final bName = (initialExtractedData['broker_name'] as String?)?.toLowerCase() ?? '';
    if (bName.isNotEmpty) {
      for (final b in brokersList) {
        final pName = (b.partnerName as String).toLowerCase();
        if (bName.contains(pName) || pName.contains(bName) || (bName.contains('acc') && pName.contains('acc')) || (bName.contains('اسكندرية') && pName.contains('اسكندرية')) || (bName.contains('أهرام') && pName.contains('أهرام')) || (bName.contains('اهرام') && pName.contains('اهرام'))) {
          selectedBroker = b.providerId;
          break;
        }
      }
    }
  }

  final usdRateCtrl = TextEditingController();
  final Set<CustomsExpenseGroup> expandedGroups = {...CustomsExpenseGroup.values};
  String itemSearchQuery = '';
  String selectedCategoryFilter = 'All';
  String quickFilterChip = 'all';
  bool isSaving = false;
  String? dialogErrorMessage;
  int? activeRowIndex;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlgState) {
        // AI Extractor Function
        Future<void> extractFromDocument() async {
          try {
            final result = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'docx', 'doc', 'png', 'jpg', 'jpeg', 'webp', 'xlsx', 'xls', 'txt'],
              withData: true,
            );

            if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
            final file = result.files.first;

            final fileSizeFormatted = file.size > 1024 * 1024
                ? '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB'
                : '${(file.size / 1024).toStringAsFixed(1)} KB';

            final progressCtrl = ExtractionProgressController();
            progressCtrl.update(
              percent: 0.20,
              status: 'جاري قراءة وتصنيف مقايسة التخليص بالذكاء الاصطناعي...',
              stepLabel: 'المرحلة 1 من 3: فحص المستند',
              currentStep: 1,
            );

            if (!ctx.mounted) return;
            ExtractionProgressDialog.show(
              context: ctx,
              title: 'استخراج وتصنيف مقايسة التخليص الجمركي',
              fileName: file.name,
              fileSize: fileSizeFormatted,
              controller: progressCtrl,
            );

            final dio = ref.read(uploadDioProvider);
            final multipartFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
            final formData = FormData.fromMap({
              'file': multipartFile,
              'module_name': 'clearance-quotation',
              'save_session': false,
            });

            final response = await dio.post(
              '${ApiConstants.baseUrl}/smart-upload/upload',
              data: formData,
              options: Options(receiveTimeout: const Duration(seconds: 120)),
              onSendProgress: (sent, total) {
                if (total > 0) {
                  final ratio = sent / total;
                  progressCtrl.update(
                    percent: 0.20 + (ratio * 0.40),
                    status: 'جاري رفع الملف (${(ratio * 100).round()}%)...',
                    stepLabel: 'المرحلة 2 من 4: معالجة البيانات',
                    currentStep: 2,
                  );
                  if (ratio >= 0.99) {
                    progressCtrl.startAutoAdvance(
                      targetPercent: 0.92,
                      duration: const Duration(seconds: 4),
                      step4Status: 'جاري استخراج أتعاب ومصروفات مقايسة التخليص والنقل وتنسيق البيانات...',
                    );
                  }
                }
              },
            );

            progressCtrl.complete();
            await Future.delayed(const Duration(milliseconds: 300));
            if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();

            if (response.data != null) {
              final extracted = (response.data['extracted_fields'] as Map<String, dynamic>?) ?? {};

              // Prepare summary items list for ExtractionSummaryDialog (M1-6)
              final expensesCatalog = (extracted['expenses_catalog'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
              final List<ExtractedSummaryItem> summaryItems = [];

              for (final extItem in expensesCatalog) {
                final rawName = ((extItem['item_name'] ?? extItem['expense_name']) as String? ?? '').trim();
                final price = ((extItem['price'] ?? extItem['amount']) as num?)?.toDouble() ?? 0.0;
                if (price <= 0 && rawName.isEmpty) continue;

                int bestScore = 0;
                String? matchedCanonical;
                String? matchedCode = extItem['code']?.toString();

                for (final itm in itemsState) {
                  final name = (itm['expense_name'] as String? ?? '').trim();
                  final score = calculateMatchScore(name, rawName);
                  if (score > bestScore) {
                    bestScore = score;
                    matchedCanonical = name;
                    if (itm['code'] != null && (matchedCode == null || matchedCode.isEmpty)) {
                      matchedCode = itm['code']?.toString();
                    }
                  }
                }

                final double conf = (extItem['confidence'] as num?)?.toDouble() ?? (bestScore > 0 ? bestScore.toDouble() : 50.0);
                final bool isUncoded = extItem['is_uncoded'] == true || (matchedCode == null && conf < 60);

                summaryItems.add(ExtractedSummaryItem(
                  rawName: rawName,
                  matchedCanonicalName: bestScore >= 80 ? matchedCanonical : null,
                  code: matchedCode,
                  category: (extItem['category']?.toString() ?? 'Other Fees').split('(').first.trim(),
                  unitType: (((extItem['pricing_unit'] ?? extItem['unit_type'])?.toString()) ?? 'Per Shipment').split('(').first.trim(),
                  price: price,
                  currency: extItem['currency']?.toString() ?? 'EGP',
                  confidence: conf,
                  isUncoded: isUncoded,
                  notes: extItem['notes']?.toString(),
                ));
              }

              // Also include high-level fees if extracted and not in expenses_catalog
              final cFee = (extracted['clearance_fee'] as num?)?.toDouble();
              if (cFee != null && cFee > 0 && !summaryItems.any((s) => s.rawName.contains('تخليص'))) {
                summaryItems.add(ExtractedSummaryItem(
                  rawName: 'أتعاب تخليص جمركي',
                  matchedCanonicalName: 'أتعاب تخليص حاوية 40 قدم',
                  code: 'CLR-40FT-FEE',
                  category: 'Clearance Fees',
                  unitType: 'Per Shipment',
                  price: cFee,
                  currency: 'EGP',
                  confidence: 90.0,
                  isUncoded: false,
                ));
              }
              final inlandFee = (extracted['inland_transport_fee'] as num?)?.toDouble();
              if (inlandFee != null && inlandFee > 0 && !summaryItems.any((s) => s.rawName.contains('نقل') || s.rawName.contains('شاحنة'))) {
                summaryItems.add(ExtractedSummaryItem(
                  rawName: 'نقل داخلي',
                  matchedCanonicalName: 'حاوية 40 قدم إسكندرية - قاهرة',
                  code: 'INL-40FT-CAI',
                  category: 'Inland Transport',
                  unitType: 'Per Truck',
                  price: inlandFee,
                  currency: 'EGP',
                  confidence: 90.0,
                  isUncoded: false,
                ));
              }

              if (!ctx.mounted) return;

              // Display ExtractionSummaryDialog (M1-6)
              final bool? shouldApply = await ExtractionSummaryDialog.show(
                context: ctx,
                fileName: file.name,
                brokerName: extracted['broker_name']?.toString(),
                portName: extracted['port_name']?.toString(),
                title: extracted['title']?.toString(),
                items: summaryItems,
              );

              if (shouldApply != true) {
                return; // User cancelled
              }

              setDlgState(() {
                if (extracted['title'] != null && (extracted['title'] as String).isNotEmpty) {
                  titleCtrl.text = extracted['title'] as String;
                }
                if (extracted['port_name'] != null && (extracted['port_name'] as String).isNotEmpty) {
                  portCtrl.text = extracted['port_name'] as String;
                }
                if (extracted['effective_from'] != null && (extracted['effective_from'] as String).isNotEmpty) {
                  dateCtrl.text = extracted['effective_from'] as String;
                }
                if (extracted['notes'] != null && (extracted['notes'] as String).isNotEmpty) {
                  notesCtrl.text = extracted['notes'] as String;
                }

                // Match Broker
                final bName = (extracted['broker_name'] as String?)?.toLowerCase() ?? '';
                if (bName.isNotEmpty) {
                  for (final b in brokersList) {
                    final pName = (b.partnerName as String).toLowerCase();
                    if (bName.contains(pName) || pName.contains(bName) || (bName.contains('acc') && pName.contains('acc')) || (bName.contains('اسكندرية') && pName.contains('اسكندرية')) || (bName.contains('أهرام') && pName.contains('أهرام')) || (bName.contains('اهرام') && pName.contains('اهرام'))) {
                      selectedBroker = b.providerId;
                      break;
                    }
                  }
                }

                // Apply extracted items and dynamic fees
                applyExtractedExpenses(extracted, isInitial: false);
              });

              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(AppTheme.snackBar(ctx, 'تم استخراج وتصنيف بنود المقايسة وتعبئة النموذج بنجاح', severity: AppSeverity.success));
              }
            }
          } catch (e) {
            if (ctx.mounted) {
              try { Navigator.of(ctx, rootNavigator: true).pop(); } catch (_) {}
              ScaffoldMessenger.of(ctx).showSnackBar(AppTheme.snackBar(ctx, 'خطأ أثناء الاستخراج: ${ApiErrorText.of(ctx.l10n, e)}', severity: AppSeverity.danger));
            }
          }
        }

        // Coded Item Registration / Alias Mapping Dialog (AI-EXPENSE-CATALOG-002)
        Future<void> showAddCustomItemDialog({String? initialName, String? initialCategory, double? initialPrice, Map<String, dynamic>? targetItem}) async {
          final formKey = GlobalKey<FormState>();
          int activeMode = 0; // 0 = Map as alias to existing code, 1 = Create new permanent code

          final catalogItems = ref.read(expenseCatalogProvider).valueOrNull ?? [];
          String? selectedCanonicalCode = catalogItems.isNotEmpty ? catalogItems.first.code : null;

          final aliasPatternCtrl = TextEditingController(text: initialName ?? '');
          final customPriceCtrl = TextEditingController(text: initialPrice != null && initialPrice > 0 ? initialPrice.toStringAsFixed(0) : '');
          final customNotesCtrl = TextEditingController();

          // For mode 1 (new code or standard reference code)
          final customCodeCtrl = TextEditingController();
          final newNameArCtrl = TextEditingController(text: initialName ?? '');
          final newNameEnCtrl = TextEditingController();

          // Determine intelligent default reference code based on initialName
          String selectedReferenceCode = 'OTHER-CLIENT-PAID';
          String newCategory = initialCategory ?? 'Other Fees';
          String newUnit = 'fixed';
          String customCurrency = 'EGP';
          bool isSubmitting = false;

          final initialLower = (initialName ?? '').toLowerCase();
          if (initialLower.contains('نقل') || initialLower.contains('شاحن') || initialLower.contains('سيارة') || initialLower.contains('تريلا')) {
            selectedReferenceCode = 'INL-CUSTOM-TRK';
            newCategory = 'Inland Transport';
            newUnit = 'per_truck';
          } else if (initialLower.contains('أتعاب') || initialLower.contains('اتعاب') || initialLower.contains('تخليص')) {
            selectedReferenceCode = 'CLR-CUSTOM-FEE';
            newCategory = 'Clearance Fees';
            newUnit = 'per_shipment';
          } else if (initialLower.contains('أرضيات') || initialLower.contains('ارضيات') || initialLower.contains('حراسة') || initialLower.contains('غرامات') || initialLower.contains('تأخير')) {
            selectedReferenceCode = 'OTHER-STORAGE';
            newCategory = 'Other Fees';
            newUnit = 'per_day';
          } else if (initialLower.contains('عمال') || initialLower.contains('كلارك') || initialLower.contains('تعتيق')) {
            selectedReferenceCode = 'OTHER-LABOR';
            newCategory = 'Port & Handling';
            newUnit = 'fixed';
          } else if (initialLower.contains('موانئ') || initialLower.contains('ابوقير') || initialLower.contains('محطة') || initialLower.contains('تفريغ') || initialLower.contains('ساحة')) {
            selectedReferenceCode = 'PORT-CUSTOM-EXP';
            newCategory = 'Port & Handling';
            newUnit = 'per_container';
          } else if (initialLower.contains('موافقة') || initialLower.contains('إجراء') || initialLower.contains('فحص') || initialLower.contains('زراعة') || initialLower.contains('واردات')) {
            selectedReferenceCode = 'PROC-CUSTOM-DOC';
            newCategory = 'Procedures & Approvals';
            newUnit = 'fixed';
          } else if (initialLower.contains('عمول') || initialLower.contains('نثريات') || initialLower.contains('إكرام')) {
            selectedReferenceCode = 'OTHER-COMMISSION';
            newCategory = 'Other Fees';
            newUnit = 'fixed';
          }

          await showDialog(
            context: ctx,
            builder: (c) => StatefulBuilder(
              builder: (c, setInnerState) {
                final isAr = Localizations.localeOf(c).languageCode == 'ar';

                // Prepare reference codes for searchable dropdown
                final referenceCodeItems = <SearchableDropdownItem<String>>[
                  SearchableDropdownItem(
                    value: 'OTHER-CLIENT-PAID',
                    label: 'OTHER-CLIENT-PAID — ${context.l10n.ccClientPaidExpenses}',
                    subtitle: '${getCategoryLabel("Other Fees", c)} | ${getUnitLabel("fixed", c)}',
                    icon: Icons.person_pin_outlined,
                  ),
                  SearchableDropdownItem(
                    value: 'OTHER-FEES',
                    label: 'OTHER-FEES — ${context.l10n.ccGeneralOtherFees}',
                    subtitle: '${getCategoryLabel("Other Fees", c)} | ${getUnitLabel("fixed", c)}',
                    icon: Icons.attach_money_rounded,
                  ),
                  SearchableDropdownItem(
                    value: 'OTHER-STORAGE',
                    label: 'OTHER-STORAGE — ${context.l10n.ccStorageDemurrage}',
                    subtitle: '${getCategoryLabel("Other Fees", c)} | ${getUnitLabel("per_day", c)}',
                    icon: Icons.warehouse_rounded,
                  ),
                  SearchableDropdownItem(
                    value: 'OTHER-LABOR',
                    label: 'OTHER-LABOR — ${context.l10n.ccLaborHandling}',
                    subtitle: '${getCategoryLabel("Port & Handling", c)} | ${getUnitLabel("fixed", c)}',
                    icon: Icons.handyman_rounded,
                  ),
                  SearchableDropdownItem(
                    value: 'OTHER-COMMISSION',
                    label: 'OTHER-COMMISSION — ${context.l10n.ccCommissionsTips}',
                    subtitle: '${getCategoryLabel("Other Fees", c)} | ${getUnitLabel("fixed", c)}',
                    icon: Icons.local_activity_rounded,
                  ),
                  SearchableDropdownItem(
                    value: 'CLR-CUSTOM-FEE',
                    label: 'CLR-CUSTOM-FEE — ${context.l10n.ccExceptionalClearanceFee}',
                    subtitle: '${getCategoryLabel("Clearance Fees", c)} | ${getUnitLabel("per_shipment", c)}',
                    icon: Icons.receipt_long_rounded,
                  ),
                  SearchableDropdownItem(
                    value: 'INL-CUSTOM-TRK',
                    label: 'INL-CUSTOM-TRK — ${context.l10n.ccInlandTransportCustom}',
                    subtitle: '${getCategoryLabel("Inland Transport", c)} | ${getUnitLabel("per_truck", c)}',
                    icon: Icons.local_shipping_rounded,
                  ),
                  SearchableDropdownItem(
                    value: 'PROC-CUSTOM-DOC',
                    label: 'PROC-CUSTOM-DOC — ${context.l10n.ccAdditionalApprovals}',
                    subtitle: '${getCategoryLabel("Procedures & Approvals", c)} | ${getUnitLabel("fixed", c)}',
                    icon: Icons.verified_user_rounded,
                  ),
                  SearchableDropdownItem(
                    value: 'PORT-CUSTOM-EXP',
                    label: 'PORT-CUSTOM-EXP — ${context.l10n.ccPortTerminalExpenses}',
                    subtitle: '${getCategoryLabel("Port & Handling", c)} | ${getUnitLabel("per_container", c)}',
                    icon: Icons.anchor_rounded,
                  ),
                  ...catalogItems.map((ci) => SearchableDropdownItem<String>(
                    value: ci.code,
                    label: '${ci.code} — ${isAr ? ci.canonicalNameAr : (ci.canonicalNameEn?.isNotEmpty == true ? ci.canonicalNameEn! : ci.canonicalNameAr)}',
                    subtitle: '${getCategoryLabel(ci.category, c)} | ${getUnitLabel(ci.unitType, c)}',
                    icon: Icons.qr_code_rounded,
                  )),
                  SearchableDropdownItem(
                    value: 'CUSTOM',
                    label: context.l10n.ccNewCustomReferenceCode,
                    subtitle: context.l10n.ccEnterCustomCodeManually,
                    icon: Icons.edit_note_rounded,
                  ),
                ];

                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Row(
                    children: [
                      const Icon(Icons.qr_code_2, color: AppTheme.cobalt, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.customsExpenseCodingTitle,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  content: SelectionArea(
                    child: SizedBox(
                      width: 530,
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mode selector tabs
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.charcoalSurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setInnerState(() => activeMode = 0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: activeMode == 0 ? AppTheme.cobalt : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              l.linkAsAliasTab,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: activeMode == 0 ? AppTheme.white : AppTheme.charcoal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setInnerState(() => activeMode = 1),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: activeMode == 1 ? AppTheme.cobalt : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              l.registerNewCatalogCodeTab,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: activeMode == 1 ? AppTheme.white : AppTheme.charcoal,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (activeMode == 0) ...[
                                // Mode 0: Alias mapping
                                SearchableDropdownField<String?>(
                                  value: selectedCanonicalCode,
                                  labelText: l.approvedCatalogItemLabel,
                                  searchHintText: l.searchApprovedCatalogHint,
                                  items: catalogItems.map((ci) => SearchableDropdownItem<String?>(
                                    value: ci.code,
                                    label: '${ci.code} — ${isAr ? ci.canonicalNameAr : (ci.canonicalNameEn?.isNotEmpty == true ? ci.canonicalNameEn! : ci.canonicalNameAr)}',
                                    subtitle: '${getCategoryLabel(ci.category, c)} | ${getUnitLabel(ci.unitType, c)}',
                                  )).toList(),
                                  onChanged: (v) => setInnerState(() => selectedCanonicalCode = v),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: aliasPatternCtrl,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? l.documentAliasLabel : null,
                                  decoration: InputDecoration(
                                    labelText: l.documentAliasLabel,
                                    hintText: l.documentAliasHint,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ] else ...[
                                // Mode 1: Searchable Reference Code Dropdown
                                SearchableDropdownField<String>(
                                  value: selectedReferenceCode,
                                  labelText: l.referenceItemCodeLabel,
                                  searchHintText: l.searchReferenceCodeHint,
                                  items: referenceCodeItems,
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setInnerState(() {
                                      selectedReferenceCode = v;
                                      // Intelligently auto-populate category, unit and default name
                                      if (v == 'OTHER-CLIENT-PAID') {
                                        newCategory = 'Other Fees';
                                        newUnit = 'fixed';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'مصاريف مؤداة بمعرفة العميل';
                                        if (newNameEnCtrl.text.isEmpty) newNameEnCtrl.text = 'Client-Paid Expenses';
                                      } else if (v == 'OTHER-FEES') {
                                        newCategory = 'Other Fees';
                                        newUnit = 'fixed';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'مصاريف ورسوم إضافية';
                                      } else if (v == 'OTHER-STORAGE') {
                                        newCategory = 'Other Fees';
                                        newUnit = 'per_day';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'أرضيات وحراسات وتخزين';
                                      } else if (v == 'OTHER-LABOR') {
                                        newCategory = 'Port & Handling';
                                        newUnit = 'fixed';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'عمالة وتعتيق وكلارك';
                                      } else if (v == 'OTHER-COMMISSION') {
                                        newCategory = 'Other Fees';
                                        newUnit = 'fixed';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'عمولات ونثريات وإكراميات';
                                      } else if (v == 'CLR-CUSTOM-FEE') {
                                        newCategory = 'Clearance Fees';
                                        newUnit = 'per_shipment';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'أتعاب تخليص إضافية استثنائية';
                                      } else if (v == 'INL-CUSTOM-TRK') {
                                        newCategory = 'Inland Transport';
                                        newUnit = 'per_truck';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'نقل داخلي وشاحنة إضافية';
                                      } else if (v == 'PROC-CUSTOM-DOC') {
                                        newCategory = 'Procedures & Approvals';
                                        newUnit = 'fixed';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'إجراءات وموافقات رقابية إضافية';
                                      } else if (v == 'PORT-CUSTOM-EXP') {
                                        newCategory = 'Port & Handling';
                                        newUnit = 'per_container';
                                        if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = 'مصاريف موانئ ومحطات إضافية';
                                      } else {
                                        final matched = catalogItems.where((ci) => ci.code == v).firstOrNull;
                                        if (matched != null) {
                                          newCategory = matched.category;
                                          newUnit = matched.unitType;
                                          if (newNameArCtrl.text.isEmpty) newNameArCtrl.text = matched.canonicalNameAr;
                                          if (newNameEnCtrl.text.isEmpty && matched.canonicalNameEn != null) newNameEnCtrl.text = matched.canonicalNameEn!;
                                        }
                                      }
                                    });
                                  },
                                ),
                                if (selectedReferenceCode == 'CUSTOM') ...[
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: customCodeCtrl,
                                    textCapitalization: TextCapitalization.characters,
                                    validator: (v) {
                                      if (selectedReferenceCode != 'CUSTOM') return null;
                                      if (v == null || v.trim().isEmpty) return l.selectReferenceCodeRequired;
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      labelText: l.referenceItemCodeLabel,
                                      hintText: 'OTHER-SPECIAL-01',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: SearchableDropdownField<String>(
                                        value: newCategory,
                                        labelText: l.officialCategoryLabel,
                                        items: [
                                          SearchableDropdownItem(value: 'Clearance Fees', label: getCategoryLabel('Clearance Fees', c)),
                                          SearchableDropdownItem(value: 'Procedures & Approvals', label: getCategoryLabel('Procedures & Approvals', c)),
                                          SearchableDropdownItem(value: 'Inland Transport', label: getCategoryLabel('Inland Transport', c)),
                                          SearchableDropdownItem(value: 'Port & Handling', label: getCategoryLabel('Port & Handling', c)),
                                          SearchableDropdownItem(value: 'Other Fees', label: getCategoryLabel('Other Fees', c)),
                                        ],
                                        onChanged: (v) => setInnerState(() => newCategory = v ?? newCategory),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: SearchableDropdownField<String>(
                                        value: newUnit,
                                        labelText: l.unitTypeLabel,
                                        items: [
                                          SearchableDropdownItem(value: 'fixed', label: getUnitLabel('fixed', c)),
                                          SearchableDropdownItem(value: 'per_container', label: getUnitLabel('per_container', c)),
                                          SearchableDropdownItem(value: 'per_invoice', label: getUnitLabel('per_invoice', c)),
                                          SearchableDropdownItem(value: 'per_ton', label: getUnitLabel('per_ton', c)),
                                          SearchableDropdownItem(value: 'per_truck', label: getUnitLabel('per_truck', c)),
                                          SearchableDropdownItem(value: 'per_day', label: getUnitLabel('per_day', c)),
                                          SearchableDropdownItem(value: 'per_shipment', label: getUnitLabel('per_shipment', c)),
                                          SearchableDropdownItem(value: 'per_declaration', label: getUnitLabel('per_declaration', c)),
                                          SearchableDropdownItem(value: 'per_bl', label: getUnitLabel('per_bl', c)),
                                        ],
                                        onChanged: (v) => setInnerState(() => newUnit = v ?? newUnit),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: newNameArCtrl,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? l.fillApprovedArabicNameRequired : null,
                                  decoration: InputDecoration(
                                    labelText: l.canonicalArabicNameLabel,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: newNameEnCtrl,
                                  decoration: InputDecoration(
                                    labelText: l.canonicalEnglishNameOptionalLabel,
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: customPriceCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return l.pleaseEnterItemPrice;
                                        if (double.tryParse(v.trim()) == null) return l.invalidItemPrice;
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        labelText: l.approvedPriceLabel,
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: SearchableDropdownField<String>(
                                      value: customCurrency,
                                      items: const [
                                        SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                                        SearchableDropdownItem(value: 'USD', label: 'USD'),
                                        SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                      ],
                                      onChanged: (v) => setInnerState(() => customCurrency = v ?? 'EGP'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: customNotesCtrl,
                                decoration: InputDecoration(
                                  labelText: l.itemNotesAndConditionsLabel,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    AppButton(
                      label: l.cancel,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: () => Navigator.pop(c),
                    ),
                    AppButton(
                      label: activeMode == 0 ? l.saveAndMapAliasBtn : l.registerCodeInCatalogBtn,
                      icon: Icons.check,
                      variant: AppButtonVariant.success,
                      isLoading: isSubmitting,
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setInnerState(() => isSubmitting = true);
                              final price = double.tryParse(customPriceCtrl.text.trim()) ?? 0.0;

                              if (activeMode == 0) {
                                
                                final code = selectedCanonicalCode;
                                final alias = aliasPatternCtrl.text.trim();
                                if (code != null && alias.isNotEmpty) {
                                  try {
                                    await ref.read(expenseCatalogProvider.notifier).addPattern(code, alias);
                                    final matchedCatItem = catalogItems.where((it) => it.code == code).firstOrNull ?? (catalogItems.isNotEmpty ? catalogItems.first : null);

                                    setDlgState(() {
                                      selectedCategoryFilter = 'All';
                                      itemSearchQuery = '';
                                      if (targetItem != null) {
                                        targetItem['code'] = code;
                                        targetItem['is_uncoded'] = false;
                                        if (matchedCatItem != null) targetItem['canonical_name_ar'] = matchedCatItem.canonicalNameAr;
                                        if (price > 0) targetItem['standard_price'] = price;
                                      } else {
                                        itemsState.insert(0, {
                                          'expense_type_id': null,
                                          'code': code,
                                          'expense_name': alias,
                                          'canonical_name_ar': matchedCatItem?.canonicalNameAr ?? alias,
                                          'category': matchedCatItem?.category ?? 'Other Fees',
                                          'unit_type': matchedCatItem?.unitType ?? 'fixed',
                                          'standard_price': price,
                                          'currency': customCurrency,
                                          'min_price': null,
                                          'max_price': null,
                                          'notes': customNotesCtrl.text.trim(),
                                          'is_uncoded': false,
                                          'is_active': true,
                                        });
                                      }
                                    });

                                    if (c.mounted) Navigator.pop(c);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(AppTheme.snackBar(ctx, l.itemCodedSuccessfullyToast(alias, code), severity: AppSeverity.success, duration: const Duration(seconds: 3)));
                                    }
                                  } catch (e) {
                                    if (c.mounted) {
                                      ScaffoldMessenger.of(c).showSnackBar(AppTheme.snackBar(c, ApiErrorText.of(context.l10n, e), severity: AppSeverity.danger));
                                    }
                                  }
                                }
                              } else {
                                
                                final finalCode = selectedReferenceCode == 'CUSTOM'
                                    ? customCodeCtrl.text.trim().toUpperCase()
                                    : selectedReferenceCode.trim().toUpperCase();

                                if (finalCode.isEmpty) {
                                  if (c.mounted) {
                                    ScaffoldMessenger.of(c).showSnackBar(AppTheme.snackBar(c, l.selectReferenceCodeRequired, severity: AppSeverity.danger));
                                  }
                                  setInnerState(() => isSubmitting = false);
                                  return;
                                }

                                final nameAr = newNameArCtrl.text.trim();
                                final nameEn = newNameEnCtrl.text.trim();

                                final isAlreadyInCatalog = catalogItems.any((ci) => ci.code.toUpperCase() == finalCode);

                                try {
                                  if (isAlreadyInCatalog) {
                                    
                                    if (nameAr.isNotEmpty) {
                                      await ref.read(expenseCatalogProvider.notifier).addPattern(finalCode, nameAr);
                                    }
                                  } else {
                                    await ref.read(expenseCatalogProvider.notifier).createItem({
                                      'code': finalCode,
                                      'canonical_name_ar': nameAr,
                                      if (nameEn.isNotEmpty) 'canonical_name_en': nameEn,
                                      'category': newCategory,
                                      'unit_type': newUnit,
                                      'allow_composite': false,
                                      'recognition_patterns': [nameAr],
                                    });
                                  }

                                  setDlgState(() {
                                    selectedCategoryFilter = 'All';
                                    itemSearchQuery = '';
                                    if (targetItem != null) {
                                      targetItem['code'] = finalCode;
                                      targetItem['is_uncoded'] = false;
                                      targetItem['canonical_name_ar'] = nameAr;
                                      targetItem['category'] = newCategory;
                                      targetItem['unit_type'] = newUnit;
                                      if (price > 0) targetItem['standard_price'] = price;
                                    } else {
                                      itemsState.insert(0, {
                                        'expense_type_id': null,
                                        'code': finalCode,
                                        'expense_name': nameAr,
                                        'canonical_name_ar': nameAr,
                                        'category': newCategory,
                                        'unit_type': newUnit,
                                        'standard_price': price,
                                        'currency': customCurrency,
                                        'min_price': null,
                                        'max_price': null,
                                        'notes': customNotesCtrl.text.trim(),
                                        'is_uncoded': false,
                                        'is_active': true,
                                      });
                                    }
                                  });

                                  if (c.mounted) Navigator.pop(c);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(AppTheme.snackBar(ctx, l.itemRegisteredInCatalogToast(finalCode), severity: AppSeverity.success, duration: const Duration(seconds: 3)));
                                  }
                                } catch (e) {
                                  String errStr = e.toString();
                                  if (e is DioException) {
                                    final d = e.response?.data;
                                    if (d is Map && d.containsKey('detail')) {
                                      errStr = d['detail'].toString();
                                    }
                                  }
                                  if (c.mounted) {
                                    ScaffoldMessenger.of(c).showSnackBar(AppTheme.snackBar(c, errStr, severity: AppSeverity.danger));
                                  }
                                }
                              }
                              if (c.mounted) {
                                setInnerState(() => isSubmitting = false);
                              }
                            },
                    ),
                  ],
                );
              },
            ),
          );
        }
        final q = itemSearchQuery.trim().toLowerCase();
        final filteredItems = itemsState.where((itm) {
          final name = (itm['expense_name']?.toString() ?? '').toLowerCase();
          final code = (itm['code']?.toString() ?? '').toLowerCase();
          final notes = (itm['notes']?.toString() ?? '').toLowerCase();
          final cat = (itm['category']?.toString() ?? '').toLowerCase();

          final matchSearch = q.isEmpty ||
              name.contains(q) ||
              code.contains(q) ||
              notes.contains(q) ||
              cat.contains(q);

          final matchCat = selectedCategoryFilter == 'All' ||
              cat == selectedCategoryFilter.toLowerCase() ||
              cat.contains(selectedCategoryFilter.toLowerCase()) ||
              selectedCategoryFilter.toLowerCase().contains(cat);

          final stdPrice = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
          final minP = (itm['min_price'] as num?)?.toDouble();
          final maxP = (itm['max_price'] as num?)?.toDouble();
          final pType = itm['price_type']?.toString() ?? '';
          final isNegotiable = pType == 'negotiable' || (stdPrice == 0.0 && minP == null && maxP == null);
          final isPriced = (stdPrice > 0) || (minP != null && minP > 0) || (maxP != null && maxP > 0);
          final isForeign = (itm['currency']?.toString() ?? 'EGP').toUpperCase() != 'EGP';
          final isUncoded = itm['is_uncoded'] == true || (itm['code'] == null || itm['code'].toString().trim().isEmpty);

          bool matchChip = true;
          switch (quickFilterChip) {
            case 'priced':
              matchChip = isPriced && !isNegotiable;
              break;
            case 'negotiable':
              matchChip = isNegotiable;
              break;
            case 'foreign':
              matchChip = isForeign;
              break;
            case 'uncoded':
              matchChip = isUncoded;
              break;
            case 'all':
            default:
              matchChip = true;
              break;
          }

          return matchSearch && matchCat && matchChip;
        }).toList();

        final countPriced = itemsState.where((itm) {
          final stdP = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
          final minP = (itm['min_price'] as num?)?.toDouble();
          final maxP = (itm['max_price'] as num?)?.toDouble();
          final pType = itm['price_type']?.toString() ?? '';
          return (stdP > 0 || (minP != null && minP > 0) || (maxP != null && maxP > 0)) && pType != 'negotiable';
        }).length;

        final countNegotiable = itemsState.where((itm) {
          final stdP = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
          final minP = (itm['min_price'] as num?)?.toDouble();
          final maxP = (itm['max_price'] as num?)?.toDouble();
          final pType = itm['price_type']?.toString() ?? '';
          return pType == 'negotiable' || (stdP == 0.0 && minP == null && maxP == null);
        }).length;

        final countForeign = itemsState.where((itm) {
          return (itm['currency']?.toString() ?? 'EGP').toUpperCase() != 'EGP';
        }).length;

        final countUncoded = itemsState.where((itm) {
          final c = itm['code']?.toString() ?? '';
          return itm['is_uncoded'] == true || c.trim().isEmpty;
        }).length;

        Widget buildQuickFilterChip({
          required String label,
          required int count,
          required bool isSelected,
          required Color activeColor,
          required IconData icon,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.12) : AppTheme.charcoalSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? activeColor : AppTheme.cloudWhite,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: isSelected ? activeColor : AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? activeColor : AppTheme.charcoal,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor : AppTheme.cloudWhite,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        void cloneRowAt(int realIdx) {
          if (realIdx < 0 || realIdx >= itemsState.length) return;
          final orig = itemsState[realIdx];
          final cloned = Map<String, dynamic>.from(orig);
          cloned['item_id'] = null;
          cloned['expense_type_id'] = null;
          cloned['expense_name'] = '${orig['expense_name']}${TableRowCloneHelper.copySuffix}';
          cloned['notes'] = orig['notes'] != null && orig['notes'].toString().isNotEmpty
              ? '${orig['notes']} | Cloned'
              : 'Cloned';
          setDlgState(() {
            itemsState.insert(realIdx + 1, cloned);
            activeRowIndex = realIdx + 1;
          });
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(AppTheme.snackBar(ctx, context.l10n.ccRowClonedSuccessfullyCtrlD, severity: AppSeverity.info, duration: const Duration(seconds: 2)));
          }
        }

        final mediaQuery = MediaQuery.of(ctx);
        final dialogWidth = (mediaQuery.size.width * 0.92).clamp(750.0, 1050.0);
        final dialogHeight = (mediaQuery.size.height * 0.88).clamp(420.0, 750.0);
        final isAr = Localizations.localeOf(ctx).languageCode == 'ar';

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
              if (activeRowIndex != null) {
                cloneRowAt(activeRowIndex!);
              } else if (filteredItems.isNotEmpty) {
                final firstIdx = itemsState.indexOf(filteredItems.first);
                cloneRowAt(firstIdx);
              }
            },
          },
          child: Focus(
            autofocus: true,
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SelectionArea(
                child: Container(
                  width: dialogWidth,
                  height: dialogHeight,
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Header & AI Extract Button
                      Row(
                        children: [
                          Icon(isEditing ? Icons.edit_note : Icons.add_circle, color: AppTheme.cobalt, size: 26),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isEditing ? l.editPriceListTitle(existingPriceList.title) : l.createPriceListTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                            ),
                          ),
                          AppButton(
                            label: l.smartFileExtractionBtn,
                            icon: Icons.auto_awesome,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.small,
                            onPressed: extractFromDocument,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const Divider(height: 16),

                      if (dialogErrorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.crimsonLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.crimson),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.crimson, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dialogErrorMessage!,
                                  style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
                                onPressed: () => setDlgState(() => dialogErrorMessage = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Header Form Inputs (Broker, Title, Port, Effective Date, Notes)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoal.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cloudWhite),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                if (!isEditing)
                                  Expanded(
                                    flex: 2,
                                    child: SearchableDropdownField<int?>(
                                      value: selectedBroker,
                                      labelText: '${l.responsibleCustomsBroker} *',
                                      searchHintText: l.searchBrokerHint,
                                      items: brokersList.map((b) => SearchableDropdownItem<int?>(value: b.providerId, label: b.partnerName)).toList(),
                                      onChanged: (v) => setDlgState(() => selectedBroker = v),
                                    ),
                                  )
                                else
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(color: AppTheme.charcoalSurface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.cloudWhite)),
                                      child: Text('${l.responsibleCustomsBroker}: ${existingPriceList.brokerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: titleCtrl,
                                    decoration: InputDecoration(labelText: l.priceListTitleField, isDense: true, border: const OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: portCtrl,
                                    decoration: InputDecoration(labelText: l.targetPortField, isDense: true, border: const OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: dateCtrl,
                                    decoration: InputDecoration(
                                      labelText: '${l.effectiveDateField} 📅',
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.calendar_month, size: 18),
                                        tooltip: l.selectDateTooltip,
                                        onPressed: () async {
                                          final cur = DateTime.tryParse(dateCtrl.text.trim()) ?? DateTime.now();
                                          final picked = await showDatePicker(
                                            context: ctx,
                                            initialDate: cur,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2035),
                                          );
                                          if (picked != null) {
                                            final f = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                            setDlgState(() => dateCtrl.text = f);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: notesCtrl,
                                    decoration: InputDecoration(
                                      labelText: l.generalTermsAndNotesField,
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: usdRateCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: isAr ? 'سعر الصرف المرجعي (\$)' : 'Ref USD Rate',
                                      hintText: '48.50',
                                      prefixIcon: const Icon(Icons.currency_exchange_rounded, size: 16, color: AppTheme.cobalt),
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Table Toolbar: Search, Category Filter & Quick Actions
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: dialogWidth - 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Search Box
                                      SizedBox(
                                        width: 200,
                                        child: TextField(
                                          decoration: InputDecoration(
                                            hintText: isAr ? 'بحث بالاسم، الكود، الملاحظات...' : 'Search name, code, notes...',
                                            prefixIcon: const Icon(Icons.search, size: 16),
                                            isDense: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          onChanged: (v) => setDlgState(() => itemSearchQuery = v),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Category Filter
                                      SizedBox(
                                        width: 200,
                                        child: SearchableDropdownField<String>(
                                          value: selectedCategoryFilter,
                                          labelText: l.filterCategoryLabel,
                                          items: [
                                            SearchableDropdownItem(value: 'All', label: l.allCategoriesItem),
                                            SearchableDropdownItem(value: 'Clearance Fees', label: getCategoryLabel('Clearance Fees', ctx)),
                                            SearchableDropdownItem(value: 'Procedures & Approvals', label: getCategoryLabel('Procedures & Approvals', ctx)),
                                            SearchableDropdownItem(value: 'Inland Transport', label: getCategoryLabel('Inland Transport', ctx)),
                                            SearchableDropdownItem(value: 'Port & Handling', label: getCategoryLabel('Port & Handling', ctx)),
                                            SearchableDropdownItem(value: 'Other Fees', label: getCategoryLabel('Other Fees', ctx)),
                                          ],
                                          onChanged: (v) => setDlgState(() => selectedCategoryFilter = v ?? 'All'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Expand All Button (M3-1)
                                      AppButton(
                                        label: isAr ? 'توسيع الكل' : 'Expand All',
                                        icon: Icons.unfold_more_rounded,
                                        variant: AppButtonVariant.secondary,
                                        size: AppButtonSize.small,
                                        onPressed: () => setDlgState(() => expandedGroups.addAll(CustomsExpenseGroup.values)),
                                      ),
                                      const SizedBox(width: 6),
                                      // Collapse All Button (M3-1)
                                      AppButton(
                                        label: isAr ? 'طي الكل' : 'Collapse All',
                                        icon: Icons.unfold_less_rounded,
                                        variant: AppButtonVariant.secondary,
                                        size: AppButtonSize.small,
                                        onPressed: () => setDlgState(() => expandedGroups.clear()),
                                      ),
                                      const SizedBox(width: 6),
                                      // Add Custom Item Button
                                      AppButton(
                                        label: l.addCustomItemOrAliasBtn,
                                        icon: Icons.qr_code_2,
                                        variant: AppButtonVariant.primary,
                                        size: AppButtonSize.small,
                                        onPressed: () => showAddCustomItemDialog(),
                                      ),
                                      const SizedBox(width: 6),
                                      // Quick Fill Button
                                      AppButton(
                                        label: l.fillStandardRatesBtn,
                                        icon: Icons.flash_on,
                                        variant: AppButtonVariant.secondary,
                                        size: AppButtonSize.small,
                                        onPressed: () {
                                          setDlgState(() {
                                            for (var itm in itemsState) {
                                              final name = itm['expense_name'] as String;
                                              for (var entry in standardRatesMap.entries) {
                                                if (name.contains(entry.key) || entry.key.contains(name)) {
                                                  itm['standard_price'] = entry.value;
                                                  itm['price_type'] = 'fixed';
                                                  break;
                                                }
                                              }
                                            }
                                          });
                                          ScaffoldMessenger.of(ctx).showSnackBar(AppTheme.snackBar(ctx, l.standardRatesFilledToast, severity: AppSeverity.info));
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      // Zero Out Button
                                      AppButton(
                                        label: l.zeroOutRatesBtn,
                                        icon: Icons.clear_all,
                                        variant: AppButtonVariant.danger,
                                        size: AppButtonSize.small,
                                        onPressed: () {
                                          setDlgState(() {
                                            for (var itm in itemsState) {
                                              itm['standard_price'] = 0.0;
                                              itm['min_price'] = null;
                                              itm['max_price'] = null;
                                              itm['price_type'] = 'negotiable';
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Row 2: Advanced Filter Chips & Match Count Badge (M3-2)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Filter Chip: All
                                      buildQuickFilterChip(
                                        label: isAr ? 'الكل' : 'All',
                                        count: itemsState.length,
                                        isSelected: quickFilterChip == 'all',
                                        activeColor: AppTheme.cobalt,
                                        icon: Icons.list_alt_rounded,
                                        onTap: () => setDlgState(() => quickFilterChip = 'all'),
                                      ),
                                      const SizedBox(width: 6),
                                      // Filter Chip: Priced
                                      buildQuickFilterChip(
                                        label: isAr ? 'مسعر فقط' : 'Priced Only',
                                        count: countPriced,
                                        isSelected: quickFilterChip == 'priced',
                                        activeColor: AppTheme.emerald,
                                        icon: Icons.monetization_on_outlined,
                                        onTap: () => setDlgState(() => quickFilterChip = 'priced'),
                                      ),
                                      const SizedBox(width: 6),
                                      // Filter Chip: Negotiable
                                      buildQuickFilterChip(
                                        label: isAr ? 'تفاوضي فقط' : 'Negotiable Only',
                                        count: countNegotiable,
                                        isSelected: quickFilterChip == 'negotiable',
                                        activeColor: AppTheme.wcagOrange,
                                        icon: Icons.handshake_outlined,
                                        onTap: () => setDlgState(() => quickFilterChip = 'negotiable'),
                                      ),
                                      const SizedBox(width: 6),
                                      // Filter Chip: Foreign Currency
                                      buildQuickFilterChip(
                                        label: isAr ? 'عملات أجنبية' : 'Foreign Currency',
                                        count: countForeign,
                                        isSelected: quickFilterChip == 'foreign',
                                        activeColor: AppTheme.cobalt,
                                        icon: Icons.currency_exchange_rounded,
                                        onTap: () => setDlgState(() => quickFilterChip = 'foreign'),
                                      ),
                                      const SizedBox(width: 6),
                                      // Filter Chip: Uncoded
                                      buildQuickFilterChip(
                                        label: isAr ? 'بحاجة لتكويد' : 'Uncoded Only',
                                        count: countUncoded,
                                        isSelected: quickFilterChip == 'uncoded',
                                        activeColor: AppTheme.crimson,
                                        icon: Icons.warning_amber_rounded,
                                        onTap: () => setDlgState(() => quickFilterChip = 'uncoded'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Result count badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.filter_list_rounded, size: 13, color: AppTheme.cobalt),
                                        const SizedBox(width: 4),
                                        Text(
                                          isAr
                                              ? '${filteredItems.length} بند مطابق من إجمالي ${itemsState.length}'
                                              : '${filteredItems.length} matching of ${itemsState.length}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                const SizedBox(height: 8),

                // Interactive Grouped Items Table (M3-1, M2-1, M2-2, M1-3)
                Expanded(
                  child: Builder(
                    builder: (tableCtx) {
                      final double? usdRefRate = double.tryParse(usdRateCtrl.text.trim());

                      // Group filteredItems into 7 categories
                      final groupedMap = <CustomsExpenseGroup, List<Map<String, dynamic>>>{};
                      for (final grp in CustomsExpenseGroup.values) {
                        groupedMap[grp] = [];
                      }
                      for (final itm in filteredItems) {
                        final grp = CustomsExpenseGroup.classify(
                          name: itm['expense_name']?.toString() ?? '',
                          category: itm['category']?.toString(),
                          currency: itm['currency']?.toString(),
                          code: itm['code']?.toString(),
                        );
                        groupedMap[grp]!.add(itm);
                      }

                      final activeGroups = CustomsExpenseGroup.values.where((g) => groupedMap[g]!.isNotEmpty).toList();

                      if (activeGroups.isEmpty) {
                        return Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            isAr ? 'لم يتم العثور على بنود مطابقة للبحث أو الفلتر' : 'No items match filter',
                            style: const TextStyle(color: AppTheme.textMuted),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: activeGroups.length,
                        itemBuilder: (ctx, gIdx) {
                          final grp = activeGroups[gIdx];
                          final grpItems = groupedMap[grp]!;
                          final isGrpExpanded = itemSearchQuery.isNotEmpty || expandedGroups.contains(grp);

                          // Calculate group priced counter
                          final pricedCount = grpItems.where((i) {
                            final pType = i['price_type']?.toString() ?? '';
                            final stdP = (i['standard_price'] as num?)?.toDouble() ?? 0.0;
                            final minP = (i['min_price'] as num?)?.toDouble();
                            return pType == 'negotiable' || stdP > 0 || (minP != null && minP > 0);
                          }).length;

                          final egpSubtotal = grpItems
                              .where((i) => (i['currency']?.toString() ?? 'EGP') == 'EGP')
                              .fold(0.0, (sum, i) => sum + ((i['standard_price'] as num?)?.toDouble() ?? 0.0));
                          final usdSubtotal = grpItems
                              .where((i) => (i['currency']?.toString() ?? 'EGP') == 'USD')
                              .fold(0.0, (sum, i) => sum + ((i['standard_price'] as num?)?.toDouble() ?? 0.0));

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: grp.badgeColor.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Category Header Card (M3-1)
                                InkWell(
                                  onTap: () {
                                    setDlgState(() {
                                      if (expandedGroups.contains(grp)) {
                                        expandedGroups.remove(grp);
                                      } else {
                                        expandedGroups.add(grp);
                                      }
                                    });
                                  },
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: grp.badgeColor.withValues(alpha: 0.08),
                                      borderRadius: isGrpExpanded
                                          ? const BorderRadius.vertical(top: Radius.circular(7))
                                          : BorderRadius.circular(7),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(grp.icon, size: 18, color: grp.badgeColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  grp.localizedTitle(isAr),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: grp.badgeColor,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.white,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: grp.badgeColor.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  '${grpItems.length} بند • $pricedCount مسعر',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: grp.badgeColor),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (egpSubtotal > 0) ...[
                                          Text(
                                            '${egpSubtotal.toStringAsFixed(0)} ج.م',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        if (usdSubtotal > 0) ...[
                                          Text(
                                            '\$${usdSubtotal.toStringAsFixed(0)} USD',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Icon(
                                          isGrpExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                          color: grp.badgeColor,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Category Items
                                if (isGrpExpanded) ...[
                                  const Divider(height: 1, color: AppTheme.cloudWhite),
                                  ...grpItems.asMap().entries.map((entry) {
                                    final itemIdxInGrp = entry.key;
                                    final itm = entry.value;
                                    final realIdx = itemsState.indexOf(itm);
                                    final standardPrice = (itm['standard_price'] as num?)?.toDouble() ?? 0.0;
                                    final minPrice = (itm['min_price'] as num?)?.toDouble();
                                    final maxPrice = (itm['max_price'] as num?)?.toDouble();
                                    final isCustomItem = itm['expense_type_id'] == null;
                                    final isForeign = (itm['currency']?.toString() ?? 'EGP').toUpperCase() != 'EGP';
                                    final pType = itm['price_type']?.toString() ??
                                        (minPrice != null || maxPrice != null
                                            ? 'range'
                                            : (standardPrice == 0.0 ? 'negotiable' : 'fixed'));
                                    final isNegotiable = pType == 'negotiable' ||
                                        (standardPrice == 0.0 && minPrice == null && maxPrice == null);
                                    final isRange = pType == 'range';

                                    return Container(
                                      color: isCustomItem
                                          ? AppTheme.orangeLight
                                          : (itemIdxInGrp.isEven ? AppTheme.white : AppTheme.charcoalSurface),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Row(
                                        children: [
                                          // ── Title, Badges & Coding (M1-3, M2-2) ───────
                                          Expanded(
                                            flex: 4,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    // Code chip if coded
                                                    if (itm['code'] != null && itm['code'].toString().isNotEmpty) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.cobalt,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          itm['code'].toString(),
                                                          style: const TextStyle(color: AppTheme.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],

                                                    // AI/OCR Confidence indicator or uncoded badge (M1-5)
                                                    if (itm['confidence'] != null || itm['raw_extracted_text'] != null || itm['is_uncoded'] == true) ...[
                                                      ExtractionConfidenceIndicator(
                                                        confidence: (itm['confidence'] as num?)?.toDouble(),
                                                        rawExtractedText: itm['raw_extracted_text']?.toString(),
                                                        isUncoded: itm['is_uncoded'] == true,
                                                        onUncodedTap: () {
                                                          QuickExpenseCodingDialog.show(
                                                            context: ctx,
                                                            ref: ref,
                                                            currentExpenseName: itm['expense_name'],
                                                            currentCategory: itm['category'],
                                                            onSelected: (sel) {
                                                              setDlgState(() {
                                                                itm['code'] = sel.code;
                                                                itm['expense_name'] = sel.canonicalNameAr;
                                                                itm['category'] = sel.category;
                                                                itm['unit_type'] = sel.unitType;
                                                                itm['is_uncoded'] = false;
                                                              });
                                                            },
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ] else if (isCustomItem) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.wcagOrange,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          l.customItemBadge,
                                                          style: const TextStyle(color: AppTheme.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],

                                                    // Foreign currency indicator badge (M2-2)
                                                    if (isForeign) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.orangeLight,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: AppTheme.wcagOrange.withValues(alpha: 0.6)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.monetization_on_outlined, size: 10, color: AppTheme.wcagOrange),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              itm['currency']?.toString() ?? 'USD',
                                                              style: const TextStyle(color: AppTheme.wcagOrange, fontSize: 9, fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],

                                                    // Name
                                                    Expanded(
                                                      child: Text(
                                                        itm['expense_name'] ?? '',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),

                                                    // Note indicator 💬 icon with preview Tooltip (M2-3)
                                                    if (itm['notes'] != null && itm['notes'].toString().trim().isNotEmpty) ...[
                                                      Tooltip(
                                                        message: '${isAr ? "ملاحظات البند:" : "Item Notes:"}\n${itm['notes'].toString().trim()}',
                                                        triggerMode: TooltipTriggerMode.tap,
                                                        child: Container(
                                                          margin: const EdgeInsetsDirectional.only(start: 4),
                                                          padding: const EdgeInsets.all(2),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.cobalt.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: AppTheme.cobalt),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],

                                                    // Quick coding button
                                                    if (itm['is_uncoded'] == true || itm['code'] == null) ...[
                                                      IconButton(
                                                        icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppTheme.cobalt),
                                                        tooltip: isAr ? 'تكويد سريع من الدليل' : 'Quick Code from Catalog',
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () {
                                                          QuickExpenseCodingDialog.show(
                                                            context: ctx,
                                                            ref: ref,
                                                            currentExpenseName: itm['expense_name'],
                                                            currentCategory: itm['category'],
                                                            onSelected: (sel) {
                                                              setDlgState(() {
                                                                itm['code'] = sel.code;
                                                                itm['expense_name'] = sel.canonicalNameAr;
                                                                itm['category'] = sel.category;
                                                                itm['unit_type'] = sel.unitType;
                                                                itm['is_uncoded'] = false;
                                                              });
                                                            },
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(width: 4),
                                                    ],
                                                  ],
                                                ),
                                                Text(
                                                  '${getCategoryLabel(itm['category']?.toString() ?? '', ctx)} | ${getUnitLabel(itm['unit_type']?.toString() ?? '', ctx)}',
                                                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // ── Price Type Selector (M2-1) ───────────────
                                          PopupMenuButton<String>(
                                            tooltip: isAr ? 'تغيير نوع السعر (ثابت / نطاق / تفاوضي)' : 'Change price type',
                                            icon: Icon(
                                              isNegotiable
                                                  ? Icons.handshake_outlined
                                                  : (isRange ? Icons.linear_scale_rounded : Icons.price_check_rounded),
                                              size: 18,
                                              color: isNegotiable ? AppTheme.wcagOrange : AppTheme.cobalt,
                                            ),
                                            onSelected: (type) {
                                              setDlgState(() {
                                                itm['price_type'] = type;
                                                if (type == 'negotiable') {
                                                  itm['standard_price'] = 0.0;
                                                }
                                              });
                                            },
                                            itemBuilder: (c) => [
                                              PopupMenuItem(
                                                value: 'fixed',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.price_check_rounded, size: 16, color: AppTheme.cobalt),
                                                    const SizedBox(width: 8),
                                                    Text(isAr ? 'سعر ثابت' : 'Fixed Price', style: const TextStyle(fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'range',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.linear_scale_rounded, size: 16, color: AppTheme.cobalt),
                                                    const SizedBox(width: 8),
                                                    Text(isAr ? 'نطاق سعري (حد أدنى / أقصى)' : 'Price Range', style: const TextStyle(fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'negotiable',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.handshake_outlined, size: 16, color: AppTheme.wcagOrange),
                                                    const SizedBox(width: 8),
                                                    Text(isAr ? 'سعر تفاوضي' : 'Negotiable', style: const TextStyle(fontSize: 12, color: AppTheme.wcagOrange)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 4),

                                          // ── Price Input Field / Range / Negotiable ────
                                          SizedBox(
                                            width: 140,
                                            child: isNegotiable
                                                ? InkWell(
                                                    onTap: () => setDlgState(() => itm['price_type'] = 'fixed'),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.orangeLight,
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: AppTheme.wcagOrange.withValues(alpha: 0.6)),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          const Icon(Icons.handshake_outlined, size: 13, color: AppTheme.wcagOrange),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            isAr ? 'تفاوضي' : 'Negotiable',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppTheme.wcagOrange,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : isRange
                                                    ? Row(
                                                        children: [
                                                          Expanded(
                                                            child: TextFormField(
                                                              key: ValueKey('dlg_min_${itm["expense_type_id"] ?? itm["expense_name"]}_$minPrice'),
                                                              initialValue: minPrice != null && minPrice > 0
                                                                  ? (minPrice % 1 == 0 ? minPrice.toInt().toString() : minPrice.toString())
                                                                  : '',
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              decoration: InputDecoration(
                                                                labelText: isAr ? 'أدنى' : 'Min',
                                                                isDense: true,
                                                                border: const OutlineInputBorder(),
                                                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                                              ),
                                                              onChanged: (v) {
                                                                itm['min_price'] = double.tryParse(v);
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: TextFormField(
                                                              key: ValueKey('dlg_max_${itm["expense_type_id"] ?? itm["expense_name"]}_$maxPrice'),
                                                              initialValue: maxPrice != null && maxPrice > 0
                                                                  ? (maxPrice % 1 == 0 ? maxPrice.toInt().toString() : maxPrice.toString())
                                                                  : '',
                                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                              decoration: InputDecoration(
                                                                labelText: isAr ? 'أقصى' : 'Max',
                                                                isDense: true,
                                                                border: const OutlineInputBorder(),
                                                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                                              ),
                                                              onChanged: (v) {
                                                                itm['max_price'] = double.tryParse(v);
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    : Column(
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: [
                                                          TextFormField(
                                                            key: ValueKey('dlg_price_${itm["expense_type_id"] ?? itm["expense_name"]}_$standardPrice'),
                                                            initialValue: standardPrice == 0.0
                                                                ? ''
                                                                : (standardPrice % 1 == 0 ? standardPrice.toInt().toString() : standardPrice.toString()),
                                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                            decoration: InputDecoration(
                                                              labelText: l.approvedPriceField,
                                                              isDense: true,
                                                              border: const OutlineInputBorder(),
                                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                            ),
                                                            onChanged: (v) {
                                                              final p = double.tryParse(v) ?? 0.0;
                                                              itm['standard_price'] = p;
                                                              itm['price_type'] = p > 0 ? 'fixed' : 'negotiable';
                                                            },
                                                          ),
                                                          if (isForeign && usdRefRate != null && usdRefRate > 0 && standardPrice > 0) ...[
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              '≈ ${(standardPrice * usdRefRate).toStringAsFixed(0)} ج.م',
                                                              style: const TextStyle(color: AppTheme.cobalt, fontSize: 9, fontWeight: FontWeight.bold),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                          ),
                                          const SizedBox(width: 8),

                                          // ── Currency Dropdown (M2-2) ─────────────────
                                          SizedBox(
                                            width: 100,
                                            child: SearchableDropdownField<String>(
                                              value: itm['currency'] ?? 'EGP',
                                              items: const [
                                                SearchableDropdownItem(value: 'EGP', label: 'EGP'),
                                                SearchableDropdownItem(value: 'USD', label: 'USD'),
                                                SearchableDropdownItem(value: 'EUR', label: 'EUR'),
                                              ],
                                              onChanged: (v) => setDlgState(() => itemsState[realIdx]['currency'] = v ?? 'EGP'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // ── Notes / Conditions Input & Templates (M2-3) ──
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    key: ValueKey('dlg_notes_${itm['expense_type_id'] ?? itm['expense_name']}_${itm['notes']}'),
                                                    initialValue: itm['notes'] ?? '',
                                                    decoration: InputDecoration(
                                                      labelText: l.notesPriceRangeField,
                                                      isDense: true,
                                                      border: const OutlineInputBorder(),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                    ),
                                                    onChanged: (v) => itemsState[realIdx]['notes'] = v,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                PopupMenuButton<String>(
                                                  tooltip: isAr ? 'قوالب ملاحظات جاهزة' : 'Note templates',
                                                  icon: const Icon(Icons.playlist_add_rounded, size: 18, color: AppTheme.cobalt),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onSelected: (template) {
                                                    setDlgState(() {
                                                      final currentNotes = (itemsState[realIdx]['notes']?.toString() ?? '').trim();
                                                      final newNotes = currentNotes.isEmpty
                                                          ? template
                                                          : (currentNotes.contains(template) ? currentNotes : '$currentNotes • $template');
                                                      itemsState[realIdx]['notes'] = newNotes;
                                                    });
                                                  },
                                                  itemBuilder: (c) => const [
                                                    'يُضاف عند الحاجة فقط',
                                                    'يشمل الضريبة',
                                                    'يتغير حسب سعر الصرف',
                                                    'يُحسب على الوزن الفعلي',
                                                    'لا يشمل الغرامات والأرضيات',
                                                    'شامل الروافع والكلارك',
                                                  ].map((t) => PopupMenuItem(
                                                    value: t,
                                                    child: Text(t, style: const TextStyle(fontSize: 12)),
                                                  )).toList(),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Clone Row Action
                                          IconButton(
                                            icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 18),
                                            tooltip: l.cloneRowTooltip,
                                            onPressed: () => cloneRowAt(realIdx),
                                          ),

                                          // Delete Custom Item Action
                                          if (isCustomItem)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: AppTheme.crimson, size: 18),
                                              tooltip: l.deleteCustomItemTooltip,
                                              onPressed: () => setDlgState(() => itemsState.removeAt(realIdx)),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Actions Footer with Multi-Currency & Reference Rate Summary
                Builder(
                  builder: (ctx) {
                    final double? usdRefRate = double.tryParse(usdRateCtrl.text.trim());
                    final egpTotal = itemsState
                        .where((i) => (i['currency']?.toString() ?? 'EGP') == 'EGP')
                        .fold(0.0, (sum, i) => sum + ((i['standard_price'] as num?)?.toDouble() ?? 0.0));
                    final usdTotal = itemsState
                        .where((i) => (i['currency']?.toString() ?? 'EGP') == 'USD')
                        .fold(0.0, (sum, i) => sum + ((i['standard_price'] as num?)?.toDouble() ?? 0.0));
                    final totalPriced = itemsState.where((i) {
                      final pType = i['price_type']?.toString() ?? '';
                      final stdP = (i['standard_price'] as num?)?.toDouble() ?? 0.0;
                      final minP = (i['min_price'] as num?)?.toDouble();
                      return pType == 'negotiable' || stdP > 0 || (minP != null && minP > 0);
                    }).length;

                    return Container(
                      padding: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppTheme.cloudWhite)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${l.totalExpensesCountSummary(itemsState.length, totalPriced)}  |  ${egpTotal.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                              ),
                              if (usdTotal > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '|  \$${usdTotal.toStringAsFixed(0)} USD',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.wcagOrange),
                                ),
                                if (usdRefRate != null && usdRefRate > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(إجمالي تقديري: ${(egpTotal + (usdTotal * usdRefRate)).toStringAsFixed(0)} ج.م)',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                  ),
                                ],
                              ],
                            ],
                          ),
                    Row(
                      children: [
                        AppButton(
                          label: l.cancel,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.small,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: isSaving
                                ? l.saving
                                : (isEditing ? l.savePriceListEditsBtn : l.createAndSavePriceListBtn),
                          icon: Icons.save,
                          variant: AppButtonVariant.success,
                          size: AppButtonSize.small,
                          isLoading: isSaving,
                          onPressed: isSaving ? null : () async {
                            setDlgState(() => dialogErrorMessage = null);

                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              setDlgState(() => dialogErrorMessage = l.priceListTitleRequired);
                              return;
                            }

                            if (selectedBroker == null) {
                              setDlgState(() => dialogErrorMessage = l.selectBrokerRequired);
                              return;
                            }

                            setDlgState(() => isSaving = true);

                            try {
                              dynamic matchedBroker;
                              for (final b in brokersList) {
                                if (b.providerId == selectedBroker) {
                                  matchedBroker = b;
                                  break;
                                }
                              }
                              final brokerName = matchedBroker?.partnerName ?? (existingPriceList?.brokerName ?? (context.l10n.ccCustomsBroker2));

                              String cleanDate(String input) {
                                if (input.trim().isEmpty) {
                                  final now = DateTime.now();
                                  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                                }
                                var s = input.trim();
                                const arDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
                                for (int i = 0; i < 10; i++) {
                                  s = s.replaceAll(arDigits[i], '$i');
                                }
                                s = s.replaceAll('/', '-');
                                return s;
                              }
                              final effDate = cleanDate(dateCtrl.text);

                              double parseDouble(dynamic val) {
                                if (val == null) return 0.0;
                                if (val is num) return val.toDouble();
                                return double.tryParse(val.toString()) ?? 0.0;
                              }

                              double? parseNullableDouble(dynamic val) {
                                if (val == null) return null;
                                if (val is num) return val.toDouble();
                                return double.tryParse(val.toString());
                              }

                              final List<Map<String, dynamic>> itemsPayload = [];
                              for (var itm in itemsState) {
                                final expName = (itm['expense_name']?.toString() ?? '').trim();
                                if (expName.isEmpty) continue;

                                var cat = (itm['category']?.toString() ?? 'Other Fees').trim();
                                if (cat.contains('(')) {
                                  cat = cat.split('(').first.trim();
                                }
                                if (cat.isEmpty) cat = 'Other Fees';

                                var unit = (itm['unit_type']?.toString() ?? 'Per Shipment').trim();
                                if (unit.contains('(')) {
                                  unit = unit.split('(').first.trim();
                                }
                                if (unit.isEmpty) unit = 'Per Shipment';

                                final stdPrice = parseDouble(itm['standard_price']);

                                itemsPayload.add({
                                  if (isEditing && itm['item_id'] != null) 'item_id': itm['item_id'],
                                  'expense_type_id': itm['expense_type_id'],
                                  if (itm['code'] != null && itm['code'].toString().isNotEmpty) 'code': itm['code'].toString(),
                                  'is_uncoded': itm['is_uncoded'] == true,
                                  'price_type': itm['price_type']?.toString() ?? (stdPrice == 0 ? 'negotiable' : 'fixed'),
                                  'expense_name': expName,
                                  'category': cat,
                                  'unit_type': unit,
                                  'standard_price': stdPrice,
                                  'currency': itm['currency']?.toString() ?? 'EGP',
                                  'min_price': parseNullableDouble(itm['min_price']),
                                  'max_price': parseNullableDouble(itm['max_price']),
                                  'notes': itm['notes']?.toString() ?? '',
                                  'is_active': itm['is_active'] ?? true,
                                  if (itm['confidence'] != null) 'confidence': parseNullableDouble(itm['confidence']),
                                  if (itm['raw_extracted_text'] != null && itm['raw_extracted_text'].toString().isNotEmpty)
                                    'raw_extracted_text': itm['raw_extracted_text'].toString(),
                                });
                              }

                              final payload = {
                                'title': title,
                                'broker_id': selectedBroker,
                                'broker_name': brokerName,
                                'port_name': portCtrl.text.trim().isNotEmpty ? portCtrl.text.trim() : null,
                                'effective_from': effDate,
                                'version': isEditing ? version : 1,
                                'is_active': isEditing ? existingPriceList.isActive : true,
                                'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                'items': itemsPayload,
                              };

                              if (isEditing) {
                                await ref.read(brokerPriceListsProvider.notifier).updatePriceList(
                                  existingPriceList.priceListId,
                                  payload,
                                );
                              } else {
                                await ref.read(brokerPriceListsProvider.notifier).createPriceList(payload);
                              }

                              if (ctx.mounted) {
                                Navigator.of(ctx, rootNavigator: true).pop();
                              }

                              ref.invalidate(brokerPriceListsProvider);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, isEditing ? l.priceListUpdatedSuccess : l.priceListCreatedSuccess, severity: AppSeverity.success, duration: const Duration(seconds: 4)));
                              }
                            } catch (e) {
                              String errorMsg = e.toString();
                              if (e is DioException) {
                                final resData = e.response?.data;
                                if (resData is Map && resData.containsKey('detail')) {
                                  errorMsg = resData['detail'].toString();
                                } else if (resData != null) {
                                  errorMsg = resData.toString();
                                } else {
                                  errorMsg = e.message ?? l.ccServerConnectionFailed;
                                }
                              }
                              if (ctx.mounted) {
                                setDlgState(() => dialogErrorMessage = '❌ ${l.ccFailedToSave}: $errorMsg');
                              }
                            } finally {
                              if (ctx.mounted) {
                                setDlgState(() => isSaving = false);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  ),
),
),
);
},
),
);
}
