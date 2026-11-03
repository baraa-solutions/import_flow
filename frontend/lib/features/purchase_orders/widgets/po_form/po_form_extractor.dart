import '../../../currencies/models/currency_model.dart';
import '../../../customs_tariff/models/customs_tariff_model.dart';
import '../../../import_companies/models/import_company_model.dart';
import '../../../incoterms/models/incoterm_model.dart';
import '../../../suppliers/models/supplier_model.dart';
import '../../models/purchase_order_model.dart';
import '../../utils/po_hs_tariff_matcher.dart';
import '../../utils/po_payment_terms.dart';

/// Data class holding extracted fields from invoice / packing list.
class PoExtractionResult {
  final String? piNumber;
  final String? poReference;
  final DateTime? orderDate;
  final int? companyId;
  final int? supplierId;
  final int? incotermId;
  final int? currencyId;
  final String? countryOfOrigin;
  final String? paymentTerms;
  final List<POLineItemModel>? items;
  final List<PackingListItemModel>? packingItems;

  const PoExtractionResult({
    this.piNumber,
    this.poReference,
    this.orderDate,
    this.companyId,
    this.supplierId,
    this.incotermId,
    this.currencyId,
    this.countryOfOrigin,
    this.paymentTerms,
    this.items,
    this.packingItems,
  });
}

/// Helper extraction, normalization, and entity matching methods for the PO Form.
class PoFormExtractor {
  static const List<Map<String, String>> countryOptions = [
    {'code': 'CN', 'nameAr': 'CN - الصين', 'nameEn': 'CN - China', 'name': 'CN - الصين (China)'},
    {'code': 'DE', 'nameAr': 'DE - ألمانيا', 'nameEn': 'DE - Germany', 'name': 'DE - ألمانيا (Germany)'},
    {'code': 'IT', 'nameAr': 'IT - إيطاليا', 'nameEn': 'IT - Italy', 'name': 'IT - إيطاليا (Italy)'},
    {'code': 'LT', 'nameAr': 'LT - ليتوانيا', 'nameEn': 'LT - Lithuania', 'name': 'LT - ليتوانيا (Lithuania)'},
    {'code': 'TW', 'nameAr': 'TW - تايوان', 'nameEn': 'TW - Taiwan', 'name': 'TW - تايوان (Taiwan)'},
    {'code': 'TR', 'nameAr': 'TR - تركيا', 'nameEn': 'TR - Turkey', 'name': 'TR - تركيا (Turkey)'},
    {'code': 'FR', 'nameAr': 'FR - فرنسا', 'nameEn': 'FR - France', 'name': 'FR - فرنسا (France)'},
    {'code': 'ES', 'nameAr': 'ES - إسبانيا', 'nameEn': 'ES - Spain', 'name': 'ES - إسبانيا (Spain)'},
    {'code': 'GB', 'nameAr': 'GB - المملكة المتحدة', 'nameEn': 'GB - United Kingdom', 'name': 'GB - المملكة المتحدة (United Kingdom)'},
    {'code': 'US', 'nameAr': 'US - الولايات المتحدة', 'nameEn': 'US - USA', 'name': 'US - الولايات المتحدة الأمريكية (USA)'},
    {'code': 'BR', 'nameAr': 'BR - البرازيل', 'nameEn': 'BR - Brazil', 'name': 'BR - البرازيل (Brazil)'},
    {'code': 'AR', 'nameAr': 'AR - الأرجنتين', 'nameEn': 'AR - Argentina', 'name': 'AR - الأرجنتين (Argentina)'},
    {'code': 'IN', 'nameAr': 'IN - الهند', 'nameEn': 'IN - India', 'name': 'IN - الهند (India)'},
    {'code': 'JP', 'nameAr': 'JP - اليابان', 'nameEn': 'JP - Japan', 'name': 'JP - اليابان (Japan)'},
    {'code': 'KR', 'nameAr': 'KR - كوريا الجنوبية', 'nameEn': 'KR - South Korea', 'name': 'KR - كوريا الجنوبية (South Korea)'},
    {'code': 'SA', 'nameAr': 'SA - السعودية', 'nameEn': 'SA - Saudi Arabia', 'name': 'SA - المملكة العربية السعودية (Saudi Arabia)'},
    {'code': 'AE', 'nameAr': 'AE - الإمارات', 'nameEn': 'AE - UAE', 'name': 'AE - الإمارات العربية المتحدة (UAE)'},
    {'code': 'JO', 'nameAr': 'JO - الأردن', 'nameEn': 'JO - Jordan', 'name': 'JO - الأردن (Jordan)'},
    {'code': 'MA', 'nameAr': 'MA - المغرب', 'nameEn': 'MA - Morocco', 'name': 'MA - المغرب (Morocco)'},
    {'code': 'TN', 'nameAr': 'TN - تونس', 'nameEn': 'TN - Tunisia', 'name': 'TN - تونس (Tunisia)'},
    {'code': 'LB', 'nameAr': 'LB - لبنان', 'nameEn': 'LB - Lebanon', 'name': 'LB - لبنان (Lebanon)'},
    {'code': 'NL', 'nameAr': 'NL - هولندا', 'nameEn': 'NL - Netherlands', 'name': 'NL - هولندا (Netherlands)'},
    {'code': 'BE', 'nameAr': 'BE - بلجيكا', 'nameEn': 'BE - Belgium', 'name': 'BE - بلجيكا (Belgium)'},
    {'code': 'AT', 'nameAr': 'AT - النمسا', 'nameEn': 'AT - Austria', 'name': 'AT - النمسا (Austria)'},
    {'code': 'PL', 'nameAr': 'PL - بولندا', 'nameEn': 'PL - Poland', 'name': 'PL - بولندا (Poland)'},
    {'code': 'SE', 'nameAr': 'SE - السويد', 'nameEn': 'SE - Sweden', 'name': 'SE - السويد (Sweden)'},
    {'code': 'CH', 'nameAr': 'CH - سويسرا', 'nameEn': 'CH - Switzerland', 'name': 'CH - سويسرا (Switzerland)'},
    {'code': 'RU', 'nameAr': 'RU - روسيا', 'nameEn': 'RU - Russia', 'name': 'RU - روسيا (Russia)'},
    {'code': 'VN', 'nameAr': 'VN - فيتنام', 'nameEn': 'VN - Vietnam', 'name': 'VN - فيتنام (Vietnam)'},
    {'code': 'TH', 'nameAr': 'TH - تايلاند', 'nameEn': 'TH - Thailand', 'name': 'TH - تايلاند (Thailand)'},
    {'code': 'MY', 'nameAr': 'MY - ماليزيا', 'nameEn': 'MY - Malaysia', 'name': 'MY - ماليزيا (Malaysia)'},
    {'code': 'ID', 'nameAr': 'ID - إندونيسيا', 'nameEn': 'ID - Indonesia', 'name': 'ID - إندونيسيا (Indonesia)'},
    {'code': 'EG', 'nameAr': 'EG - مصر', 'nameEn': 'EG - Egypt', 'name': 'EG - مصر (Egypt)'},
  ];

  static String? normalizeCountryName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final clean = raw.trim().toUpperCase();
    final match = countryOptions.where((c) {
      final code = c['code']!.toUpperCase();
      final name = c['name']!.toUpperCase();
      return code == clean ||
          name.contains(clean) ||
          clean.contains(code) ||
          (clean == 'LITHUANIA' && (code == 'LT' || name.contains('LITHUANIA') || name.contains('ليتوانيا'))) ||
          (clean == 'ITALY' && (code == 'IT' || name.contains('ITALY') || name.contains('إيطاليا'))) ||
          (clean == 'CHINA' && (code == 'CN' || name.contains('CHINA') || name.contains('الصين')));
    }).firstOrNull;
    return match != null ? match['name'] : raw;
  }

  static String formatDecimalInput(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toString().replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static int numToInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static double numToDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? fallback;
    return fallback;
  }

  static DateTime parseFlexDate(String? rawStr) {
    if (rawStr == null || rawStr.trim().isEmpty) return DateTime.now();
    final s = rawStr.trim();
    final parsedIso = DateTime.tryParse(s);
    if (parsedIso != null) return parsedIso;

    final parts = s.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      final p0 = int.tryParse(parts[0]) ?? 1;
      final p1 = int.tryParse(parts[1]) ?? 1;
      final p2 = int.tryParse(parts[2]) ?? DateTime.now().year;
      if (p2 > 1000) {
        return DateTime(p2, p1, p0);
      } else if (p0 > 1000) {
        return DateTime(p0, p1, p2);
      }
    }
    return DateTime.now();
  }

  static dynamic getExt(Map<String, dynamic> ext, List<String> candidateKeys) {
    for (final ck in candidateKeys) {
      if (ext.containsKey(ck) && ext[ck] != null && ext[ck].toString().trim().isNotEmpty) {
        return ext[ck];
      }
    }
    final normExt = ext.map((k, v) => MapEntry(k.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), ''), v));
    for (final ck in candidateKeys) {
      final normCk = ck.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
      if (normExt.containsKey(normCk) && normExt[normCk] != null && normExt[normCk].toString().trim().isNotEmpty) {
        return normExt[normCk];
      }
    }
    return null;
  }

  static int? matchCompanyId(Map<String, dynamic> ext, List<ImportCompanyModel> companies) {
    final rawComp = getExt(ext, ['importer_name', 'importer name', 'company_name', 'company name', 'importer', 'company', 'consignee', 'client_name'])?.toString().trim().toLowerCase();
    final rawCompTax = getExt(ext, ['importer_tax_id', 'importer tax id', 'tax_id', 'vat_id'])?.toString().trim();
    if (rawComp == null || rawComp.isEmpty) return null;

    final matchedComp = companies.where((c) {
      final cName = c.importerName.toLowerCase();
      final cTax = c.vatId.trim();
      if (rawCompTax != null && rawCompTax.isNotEmpty && (cTax == rawCompTax || cTax.replaceAll(RegExp(r'[^\d]'), '') == rawCompTax.replaceAll(RegExp(r'[^\d]'), ''))) return true;
      if (cName.contains(rawComp) || rawComp.contains(cName)) return true;
      final noise = {'trading', 'contracting', 'for', 'and', 'co', 'ltd', 'llc', 'corp', 'spa', 'gmbh', 'sae', 's.a.e', 'group', 'the', '&'};
      final rawTokens = rawComp.toLowerCase().split(RegExp(r'[\s,\.\-_]+')).where((w) => w.length > 2 && !noise.contains(w)).toSet();
      final cTokens = cName.toLowerCase().split(RegExp(r'[\s,\.\-_]+')).where((w) => w.length > 2 && !noise.contains(w)).toSet();
      final intersection = rawTokens.intersection(cTokens);
      return intersection.isNotEmpty && (intersection.length >= 2 || intersection.length == rawTokens.length || intersection.length == cTokens.length);
    }).firstOrNull;

    return matchedComp?.companyId;
  }

  static int? matchSupplierId(Map<String, dynamic> ext, List<SupplierModel> suppliers) {
    final rawSupp = getExt(ext, ['supplier_name', 'supplier name', 'supplier', 'vendor_name', 'vendor name', 'vendor', 'shipper', 'exporter_name', 'exporter name', 'exporter'])?.toString().trim().toLowerCase();
    final rawSuppTax = getExt(ext, ['supplier_tax_id', 'supplier tax id', 'exporter_id', 'vat_number', 'tax_id'])?.toString().trim();
    final rawSuppEmail = getExt(ext, ['supplier_email', 'supplier email', 'email'])?.toString().trim().toLowerCase();
    if (rawSupp == null || rawSupp.length < 3) return null;

    final matchedSupp = suppliers.where((s) {
      final sName = s.companyName.toLowerCase();
      final sTax = s.foreignExporterId.trim();
      final sEmail = s.email?.trim().toLowerCase();
      if (rawSuppTax != null && rawSuppTax.isNotEmpty && (sTax == rawSuppTax || sTax.replaceAll(RegExp(r'[^\d]'), '') == rawSuppTax.replaceAll(RegExp(r'[^\d]'), ''))) return true;
      if (rawSuppEmail != null && rawSuppEmail.isNotEmpty && sEmail == rawSuppEmail) return true;
      if (sName.contains(rawSupp) || rawSupp.contains(sName)) return true;
      final noise = {'ltd', 'inc', 'corp', 'spa', 'gmbh', 'international', 'co.', 'co', 'the', '&', 'group', 'uab'};
      final rawTokens = rawSupp.toLowerCase().split(RegExp(r'[\s,\.\-_]+')).where((w) => w.length > 2 && !noise.contains(w)).toSet();
      final sTokens = sName.toLowerCase().split(RegExp(r'[\s,\.\-_]+')).where((w) => w.length > 2 && !noise.contains(w)).toSet();
      if (rawTokens.isEmpty || sTokens.isEmpty) return false;
      final intersection = rawTokens.intersection(sTokens);
      return intersection.length >= 2 || intersection.length == rawTokens.length || intersection.length == sTokens.length;
    }).firstOrNull;

    return matchedSupp?.supplierId;
  }

  static int? matchIncotermId(dynamic extOrRaw, List<IncotermModel> incoterms) {
    if (incoterms.isEmpty) return null;
    String raw = '';
    if (extOrRaw is Map<String, dynamic>) {
      final val = getExt(extOrRaw, ['incoterms', 'incoterm', 'trade_terms', 'terms', 'delivery_terms', 'shipment_terms']);
      if (val != null) raw = val.toString().trim().toUpperCase();
    } else if (extOrRaw != null) {
      raw = extOrRaw.toString().trim().toUpperCase();
    }
    if (raw.isEmpty) return null;

    final numId = int.tryParse(raw);
    if (numId != null && incoterms.any((i) => i.incotermId == numId)) {
      return numId;
    }

    for (final i in incoterms) {
      final code = i.incotermCode.toUpperCase().trim();
      if (code == raw) return i.incotermId;
      if (raw.contains(code) || code.contains(raw)) return i.incotermId;
    }
    return null;
  }

  static int? matchCurrencyId(dynamic extOrRaw, List<CurrencyModel> currencies) {
    if (currencies.isEmpty) return null;
    String raw = '';
    if (extOrRaw is Map<String, dynamic>) {
      final val = getExt(extOrRaw, ['currency', 'currency_code', 'currency_symbol', 'valuta', 'curr']);
      if (val != null) raw = val.toString().trim().toUpperCase();
    } else if (extOrRaw != null) {
      raw = extOrRaw.toString().trim().toUpperCase();
    }
    if (raw.isEmpty) return null;

    final numId = int.tryParse(raw);
    if (numId != null && currencies.any((c) => c.currencyId == numId)) {
      return numId;
    }

    if (raw.contains('\$') || raw == 'USD') {
      return currencies.where((c) => c.currencyCode.toUpperCase() == 'USD').firstOrNull?.currencyId;
    }
    if (raw.contains('€') || raw == 'EUR') {
      return currencies.where((c) => c.currencyCode.toUpperCase() == 'EUR').firstOrNull?.currencyId;
    }
    if (raw.contains('£') || raw == 'GBP') {
      return currencies.where((c) => c.currencyCode.toUpperCase() == 'GBP').firstOrNull?.currencyId;
    }
    if (raw.contains('¥') || raw == 'CNY' || raw == 'RMB') {
      return currencies.where((c) => c.currencyCode.toUpperCase() == 'CNY').firstOrNull?.currencyId;
    }

    for (final c in currencies) {
      final code = c.currencyCode.toUpperCase().trim();
      if (code == raw) return c.currencyId;
      if (c.currencySymbol.trim() == raw) return c.currencyId;
    }
    return null;
  }

  static PoExtractionResult extract({
    required Map<String, dynamic> ext,
    required String targetTab,
    required List<ImportCompanyModel> companies,
    required List<SupplierModel> suppliers,
    required List<IncotermModel> incoterms,
    required List<CurrencyModel> currencies,
    required List<CustomsTariffModel> tariffs,
    required List<POLineItemModel> existingItems,
  }) {
    String? piNum;
    String? poRef;
    DateTime? orderDate;
    int? compId;
    int? suppId;
    int? incoId;
    int? currId;
    String? countryOfOrigin;
    String? paymentTerms;
    List<POLineItemModel>? lineItems;
    List<PackingListItemModel>? packingItems;

    if (targetTab == 'invoice' || targetTab == 'all') {
      piNum = (ext['invoice_number'] ?? ext['po_number'] ?? ext['proforma_invoice_number'])?.toString();
      poRef = (ext['po_reference'] ?? ext['reference'] ?? ext['order_title'])?.toString();
      final dStr = (ext['order_date'] ?? ext['invoice_date'] ?? ext['date'])?.toString();
      if (dStr != null && dStr.isNotEmpty) orderDate = parseFlexDate(dStr);

      compId = matchCompanyId(ext, companies);
      suppId = matchSupplierId(ext, suppliers);
      incoId = matchIncotermId(ext, incoterms);
      currId = matchCurrencyId(ext, currencies);

      final rawCty = getExt(ext, ['country_of_origin', 'country', 'origin_country'])?.toString().trim();
      if (rawCty != null) countryOfOrigin = normalizeCountryName(rawCty);

      paymentTerms = PoPaymentTerms.fromText((ext['payment_terms'] ?? ext['terms'])?.toString());

      if (ext['items'] is List && (ext['items'] as List).isNotEmpty) {
        lineItems = (ext['items'] as List).asMap().entries.map((e) {
          final rawHs = (e.value['hs_code'] ?? ext['hs_code'])?.toString().trim();
          final matched = matchTariffForPrintedHs(rawHs, tariffs, (t) => t.hsCode);
          return POLineItemModel(
            itemCode: (e.value['item_code'] ?? 'ITEM-${(e.key + 1).toString().padLeft(3, "0")}').toString(),
            mainDescription: e.value['main_description']?.toString(),
            descriptionAr: (e.value['description'] ?? e.value['item_name'] ?? 'بند استيرادي').toString(),
            tariffId: matched?.tariffId,
            hsCode: rawHs,
            quantity: (e.value['quantity'] as num?)?.toDouble() ?? 100.0,
            unitPrice: (e.value['unit_price'] as num?)?.toDouble() ?? 10.0,
          );
        }).toList();
      }
    }

    if (targetTab == 'packing' || targetTab == 'all') {
      final packingList = (ext['packing_items'] is List ? ext['packing_items'] : ext['items']) as List?;
      if (packingList != null && packingList.isNotEmpty) {
        packingItems = packingList.asMap().entries.map((e) {
          final idx = e.key;
          final p = Map<String, dynamic>.from(e.value as Map);
          return PackingListItemModel(
            hsCode: (p['hs_code'] ?? (idx < existingItems.length ? existingItems[idx].hsCode : "")).toString(),
            itemCode: (p['item_code'] ?? 'ITEM-${(idx + 1).toString().padLeft(3, "0")}').toString(),
            mainDescription: p['main_description']?.toString(),
            description: (p['description'] ?? p['item_name'] ?? (idx < existingItems.length ? existingItems[idx].descriptionAr : "")).toString(),
            qtyPcs: (p['qty_pcs'] ?? p['quantity'] as num?)?.toDouble() ?? 10.0,
            qtyPkg: (p['qty_pkg'] as num?)?.toDouble() ?? 1.0,
            packageType: p['package_type']?.toString() ?? 'Carton',
            unit: PackingListItemModel.normalizeLengthUnit(p['unit']?.toString()),
            lengthCm: (p['length_cm'] as num?)?.toDouble() ?? 50.0,
            widthCm: (p['width_cm'] as num?)?.toDouble() ?? 40.0,
            heightCm: (p['height_cm'] as num?)?.toDouble() ?? 30.0,
            grossWeightUnitKg: (p['gross_weight_unit_kg'] ?? p['gross_weight_kg'] as num?)?.toDouble() ?? 6.0,
          );
        }).toList();
      }
    }

    return PoExtractionResult(
      piNumber: piNum,
      poReference: poRef,
      orderDate: orderDate,
      companyId: compId,
      supplierId: suppId,
      incotermId: incoId,
      currencyId: currId,
      countryOfOrigin: countryOfOrigin,
      paymentTerms: paymentTerms,
      items: lineItems,
      packingItems: packingItems,
    );
  }
}
