import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/localization/stored_text.dart';
import '../../../../core/localization/system_messages/coded_item_text.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../models/import_documentation_model.dart';

/// Client-side text parsing and fallback extraction for PO & Packing Reconciliation.
class PoReconciliationClientExtractor {
  static const String sampleGIIndustrialInvoice = '''
G.I. INDUSTRIAL HOLDING SPA
Via G. Agnelli, 7 - 33053 Latisana (UD) - Italy
P.IVA IT01982510305
COMMERCIAL INVOICE Date 30/06/2026 Page 1
V1/ 2562
Client id. no. 801765
V.A.T. ID Number 200183044
Messrs
ECO ASSOCIATES
7 HOSNI OSMAN ST., SEFARAT DISTRICT
11471 NASR CITY, CAIRO
Egitto
Payment condition 100% AVV. MERCE PRONTA-PICK UP CONF.
Bank IT80Q0503412301USD100004026
SWIFT BAPPIT21682
Shipping - Delivery terms - As per INCOTERMS 2020
EX WORKS EXTRA UE

Your order ECO/049/2026/REV00
Our order confirmation M26 413 date 5/03/26
Commessa 27/360012
CYK4R6018210001 RTAXT/K/EC/MS 182 IM/RFM/RFL/PF/NS DOUBLE SKIN PACKAGED ROOF TOP 84158200 2,000 NR 18.602,37500 37.204,75 NI
QCR12026802R AG - RUBBER SHOCK ABSORBERS 2,000 NR 268,12500 536,25 NI

ACID NR. 2001830441013710010
IMPORTER TAX ID: 200183044
EXPORTER REGISTRATION NUMBER: 01982510305

Total goods 37.741,00
TOTAL INVOICE AMOUNT 37.741,00 EUR
Net weight kg 2.254,000
Gross weight kg 2.274,000
Packages 4
''';

  static const String sampleGIIndustrialPackingList = '''
Latisana, 30/06/2026
ECO ASSOCIATES
7 HOSNI OSMAN ST. SEFARAT DISTRICT
11471 NASR CITY, CAIRO
EGYPT

NOSTRO ORDINE / OUR ORDER M26 413
COMMESSA 27/360012
VOSTRO ORDINE / YOUR ORDER ECO/049/2026/REV00
ACID NUMBER 2001830441013710010

PACKING AND WEIGHT LIST
DESCRIZIONE / DESCRIPTION Q.TY (NO) LENGTH (mm.) WIDTH (mm.) HEIGHT (mm.) NET (KG) GROSS (KG) (NO) (TYPE)
RTAXT/K/EC/MS 182 IM/RFM/RFL/PF/NS 2 3950 2250 2250 2250 2270 2 PACKAGE
QCR12026802R 1 275 265 160 4 4 2 BOX
KG / COLLI 2254,0 2274,0 4,0 TOTAL
''';

  static Map<String, dynamic> parseInvoiceClientSide(String text) {
    String? invNum;
    String? acid;
    double? totalAmt;
    String? currency;

    final invMatch = RegExp(
      r'(?:COMMERCIAL\s+INVOICE|INV(?:OICE)?\.?\s*(?:NO|NR|NUMBER)?:?)[\s\S]*?([A-Z0-9]+[/-][A-Z0-9-]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (invMatch != null) invNum = invMatch.group(1)?.replaceAll(RegExp(r'\s+'), '');

    final acidMatch = RegExp(
      r'(?:ACID|A\.C\.I\.D)[\s\S]*?(\d{19})',
      caseSensitive: false,
    ).firstMatch(text);
    if (acidMatch != null) acid = acidMatch.group(1);

    final amtMatch = RegExp(
      r'(?:TOTAL\s+INVOICE\s+AMOUNT|TOTAL\s+AMOUNT|SAY\s+TOTAL\s+(?:USD|EUR)|TOTAL)[\s:]*([A-Z]{3})?\s*([\d.,]+)\s*([A-Z]{3})?',
      caseSensitive: false,
    ).firstMatch(text);
    if (amtMatch != null) {
      String rawVal = (amtMatch.group(2) ?? amtMatch.group(1) ?? '').replaceAll(',', '');
      totalAmt = double.tryParse(rawVal);
      if (amtMatch.group(3) != null) {
        currency = amtMatch.group(3)!;
      } else if (amtMatch.group(1) != null && amtMatch.group(1)!.length == 3) {
        currency = amtMatch.group(1)!;
      }
    }

    if (currency == null) {
      if (text.contains('USD') || text.contains(r'$')) {
        currency = 'USD';
      } else if (text.contains('EUR') || text.contains('€')) {
        currency = 'EUR';
      }
    }

    return {
      if (invNum != null) 'invoice_number': invNum,
      if (acid != null) 'acid_number': acid,
      if (totalAmt != null) 'total_amount': totalAmt,
      if (currency != null) 'currency': currency,
      'items': [],
    };
  }

  static Map<String, dynamic> parsePackingClientSide(String text) {
    String? acid;
    double? netW;
    double? grossW;
    double? pkgs;

    final acidMatch = RegExp(
      r'(?:ACID|A\.C\.I\.D)[\s\S]*?(\d{19})',
      caseSensitive: false,
    ).firstMatch(text);
    if (acidMatch != null) acid = acidMatch.group(1);

    final netMatch = RegExp(
      r'(?:Net\s+weight|TOTAL\s+NET)[\s\w]*?([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (netMatch != null) netW = double.tryParse(netMatch.group(1)!.replaceAll(',', ''));

    final grossMatch = RegExp(
      r'(?:Gross\s+weight|TOTAL\s+GROSS)[\s\w]*?([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (grossMatch != null) grossW = double.tryParse(grossMatch.group(1)!.replaceAll(',', ''));

    final pkgMatch = RegExp(
      r'(?:Packages|TOTAL(?:\s+PKG|\s+PACKAGES)?)[\s\w]*?([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (pkgMatch != null) pkgs = double.tryParse(pkgMatch.group(1)!.replaceAll(',', ''));

    return {
      if (acid != null) 'acid_number': acid,
      if (netW != null) 'total_net_weight_kg': netW,
      if (grossW != null) 'total_gross_weight_kg': grossW,
      if (pkgs != null) 'total_packages': pkgs,
      'items': [],
    };
  }

  static Map<String, dynamic> performClientSideFallbackExtraction({
    required String invText,
    required String plText,
    required ImportFileModel? currentFile,
    required PurchaseOrderModel? linkedPO,
    required String? finalInvoiceNumber,
    required List<POReconciliationItemModel> invoiceItems,
    required List<POReconciliationItemModel> packingItems,
  }) {
    final invData = parseInvoiceClientSide(invText);
    final plData = parsePackingClientSide(plText);

    String? nonEmpty(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    num? asNum(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');

    final String? sysInvNum = nonEmpty(finalInvoiceNumber) ?? nonEmpty(linkedPO?.poNumber);
    final String? sysAcid = nonEmpty(currentFile?.acidNumber);
    final double sysTotalAmt = linkedPO?.totalAmountFob ?? 0.0;
    final String sysCurrency = linkedPO?.currencyCode ?? currentFile?.estimatedCostCurrency ?? 'USD';
    final double sysTotalPkgs = (linkedPO != null && linkedPO.totalPackagesCount > 0)
        ? linkedPO.totalPackagesCount.toDouble()
        : packingItems.fold(0.0, (s, i) => s + i.initialPackagesCount);
    final double sysGrossWt = (linkedPO != null && linkedPO.totalGrossWeightKg > 0)
        ? linkedPO.totalGrossWeightKg
        : packingItems.fold(0.0, (s, i) => s + i.initialGrossWeightKg);

    final List<Map<String, dynamic>> headerDiscrepancies = [];
    Object orPlaceholder(String? v, String placeholder) => v ?? CodedPlaceholder(placeholder);
    final notSetText = DomainEnums.label(storedText, DomainEnumType.valuePlaceholder, 'NOT_SET');

    void addCheck({
      required String field,
      required String fieldAr,
      required String status,
      required Object system,
      required Object extracted,
      Object? systemInvoice,
      Object? systemPacking,
      Object? uploadedInvoice,
      Object? uploadedPacking,
      required Map<String, dynamic> details,
    }) {
      headerDiscrepancies.add(CodedItemText.finalize({
        'field_name': field,
        'field_name_ar': fieldAr,
        'system_value': system,
        'extracted_value': extracted,
        'system_invoice_value': systemInvoice ?? system,
        'system_packing_value': systemPacking ?? system,
        'uploaded_invoice_value': uploadedInvoice ?? extracted,
        'uploaded_packing_value': uploadedPacking ?? extracted,
        'status': status,
        ...details,
      }));
    }

    Map<String, dynamic> unreadable(String english) => {'details': english};
    bool contains(String a, String b) => a.toLowerCase().contains(b.toLowerCase());

    // Check Invoice Number
    final extractedInvNum = nonEmpty(invData['invoice_number'] as String?);
    final bool invNumMatched = extractedInvNum != null &&
        sysInvNum != null &&
        (extractedInvNum.toLowerCase() == sysInvNum.toLowerCase() ||
            contains(sysInvNum, extractedInvNum) ||
            contains(extractedInvNum, sysInvNum));
    addCheck(
      field: 'invoice_number',
      fieldAr: 'رقم الفاتورة التجارية النهائية',
      status: extractedInvNum == null ? 'WARNING' : (invNumMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysInvNum, 'NOT_SET'),
      extracted: orPlaceholder(extractedInvNum, 'NOT_IN_DOCUMENT'),
      uploadedPacking: orPlaceholder(nonEmpty(plData['invoice_number'] as String?), 'NOT_IN_DOCUMENT'),
      details: extractedInvNum == null
          ? unreadable('Could not read the invoice number from the uploaded file')
          : CodedItemText.coded(
              'details',
              invNumMatched ? 'DOC_CHK_INVOICE_NO_MATCH' : 'DOC_CHK_INVOICE_NO_MISMATCH',
              invNumMatched ? const {} : {'document_value': extractedInvNum, 'system_value': sysInvNum ?? notSetText}),
    );

    // Check ACID
    final extractedAcid = nonEmpty(plData['acid_number'] as String?) ?? nonEmpty(invData['acid_number'] as String?);
    final bool acidMatched = extractedAcid != null && sysAcid != null && extractedAcid == sysAcid;
    addCheck(
      field: 'acid_number',
      fieldAr: 'رقم القيد الجمركي المبدئي (ACID)',
      status: extractedAcid == null ? 'WARNING' : (acidMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysAcid, 'NOT_SET'),
      extracted: orPlaceholder(extractedAcid, 'NOT_IN_DOCUMENT'),
      uploadedInvoice: orPlaceholder(nonEmpty(invData['acid_number'] as String?), 'NOT_IN_DOCUMENT'),
      uploadedPacking: orPlaceholder(nonEmpty(plData['acid_number'] as String?), 'NOT_IN_DOCUMENT'),
      details: extractedAcid == null
          ? unreadable('Could not read the ACID number from the uploaded documents')
          : CodedItemText.coded('details', acidMatched ? 'DOC_CHK_ACID_MATCH' : 'DOC_CHK_ACID_MISMATCH'),
    );

    // Check Currency & Total Amount
    final double? totalInvAmt = (invData['total_amount'] as num?)?.toDouble();
    final String extCurr = (invData['currency'] as String?) ?? sysCurrency;
    final bool currencyMatched = extCurr.toUpperCase() == sysCurrency.toUpperCase();
    final bool amtMatched = totalInvAmt != null && (totalInvAmt - sysTotalAmt).abs() < 1.0 && currencyMatched;
    final double amtDiff = totalInvAmt == null ? 0 : (totalInvAmt - sysTotalAmt).abs();
    final String sysAmountText = '${CodedItemText.formatGrouped(sysTotalAmt, 2)} $sysCurrency';
    final String? extAmountText =
        totalInvAmt == null ? null : '${CodedItemText.formatGrouped(totalInvAmt, 2)} $extCurr';
    addCheck(
      field: 'total_amount',
      fieldAr: 'إجمالي قيمة الفاتورة التجارية',
      status: totalInvAmt == null ? 'WARNING' : (amtMatched ? 'MATCH' : 'DISCREPANCY'),
      system: sysAmountText,
      extracted: orPlaceholder(extAmountText, 'NOT_IN_DOCUMENT'),
      systemPacking: const CodedPlaceholder('NOT_IN_PACKING_LIST'),
      uploadedPacking: '—',
      details: totalInvAmt == null
          ? unreadable('Could not read the total amount from the document')
          : (amtMatched
              ? CodedItemText.coded('details', 'DOC_CHK_AMOUNT_MATCH')
              : (!currencyMatched
                  ? CodedItemText.coded('details', 'DOC_CHK_CURRENCY_MISMATCH',
                      {'system_currency': sysCurrency, 'document_currency': extCurr})
                  : CodedItemText.coded('details', 'DOC_CHK_AMOUNT_VARIANCE', {
                      'variance_amount': double.parse(amtDiff.toStringAsFixed(2)),
                      'currency': sysCurrency,
                      'variance_pct': sysTotalAmt > 0 ? double.parse((amtDiff / sysTotalAmt * 100).toStringAsFixed(2)) : 0,
                    }))),
    );

    // Check Total Packages
    final double? totalPlPkgs = (plData['total_packages'] as num?)?.toDouble();
    final bool pkgsMatched = totalPlPkgs != null && (totalPlPkgs - sysTotalPkgs).abs() < 0.01;
    final num? invQtyPkg = asNum(invData['qty_pkg']);
    addCheck(
      field: 'total_packages',
      fieldAr: 'إجمالي عدد الطرود',
      status: totalPlPkgs == null ? 'WARNING' : (pkgsMatched ? 'MATCH' : 'DISCREPANCY'),
      system: CodedMeasure(sysTotalPkgs.toInt(), 'PACKAGES', decimals: null),
      extracted: totalPlPkgs == null
          ? const CodedPlaceholder('NOT_IN_DOCUMENT')
          : CodedMeasure(totalPlPkgs.toInt(), 'PACKAGES', decimals: null),
      uploadedInvoice: invQtyPkg == null
          ? const CodedPlaceholder('NOT_IN_INVOICE')
          : CodedMeasure(invQtyPkg, 'PACKAGES', decimals: null),
      details: totalPlPkgs == null
          ? unreadable('Could not read the package count from the packing list')
          : (pkgsMatched
              ? CodedItemText.coded('details', 'DOC_CHK_PACKAGES_MATCH')
              : CodedItemText.coded('details', 'DOC_CHK_PACKAGES_VARIANCE', {
                  'difference_count': (totalPlPkgs - sysTotalPkgs).abs().toInt(),
                })),
    );

    // Check Gross Weight
    final double? totalPlGross = (plData['total_gross_weight_kg'] as num?)?.toDouble();
    final bool grossMatched = totalPlGross != null && (totalPlGross - sysGrossWt).abs() < 1.0;
    final num? invGross = asNum(invData['total_gross_weight_kg']);
    final double grossDiff = totalPlGross == null ? 0 : (totalPlGross - sysGrossWt).abs();
    addCheck(
      field: 'gross_weight',
      fieldAr: 'الوزن الإجمالي القائم',
      status: totalPlGross == null ? 'WARNING' : (grossMatched ? 'MATCH' : 'DISCREPANCY'),
      system: CodedMeasure(sysGrossWt, 'KG'),
      extracted: totalPlGross == null ? const CodedPlaceholder('NOT_IN_DOCUMENT') : CodedMeasure(totalPlGross, 'KG'),
      uploadedInvoice: invGross == null ? const CodedPlaceholder('NOT_IN_INVOICE') : CodedMeasure(invGross, 'KG'),
      details: totalPlGross == null
          ? unreadable('Could not read the gross weight from the packing list')
          : (grossMatched
              ? CodedItemText.coded('details', 'DOC_CHK_GROSS_WEIGHT_MATCH')
              : CodedItemText.coded('details', 'DOC_CHK_GROSS_WEIGHT_VARIANCE', {
                  'difference_qty': double.parse(grossDiff.toStringAsFixed(2)),
                  'difference_pct': sysGrossWt > 0 ? double.parse((grossDiff / sysGrossWt * 100).toStringAsFixed(2)) : 0,
                })),
    );

    // Check Supplier Name
    final String? extractedSupplier =
        nonEmpty(invData['supplier_name'] as String?) ?? nonEmpty(invData['shipper_name'] as String?);
    final String? sysSupplier = nonEmpty(linkedPO?.supplierName);
    final bool supplierMatched = extractedSupplier != null && sysSupplier != null
        ? contains(extractedSupplier, sysSupplier) || contains(sysSupplier, extractedSupplier)
        : true;
    addCheck(
      field: 'supplier_name',
      fieldAr: 'اسم المورد الأجنبي',
      status: extractedSupplier == null ? 'WARNING' : (supplierMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysSupplier, 'NOT_SET'),
      extracted: orPlaceholder(extractedSupplier, 'NOT_IN_DOCUMENT'),
      uploadedPacking:
          orPlaceholder(nonEmpty((plData['supplier_name'] ?? plData['shipper_name']) as String?), 'NOT_IN_DOCUMENT'),
      details: extractedSupplier == null
          ? unreadable('Could not read the supplier name from the document')
          : CodedItemText.coded(
              'details',
              supplierMatched ? 'DOC_CHK_SUPPLIER_MATCH' : 'DOC_CHK_SUPPLIER_MISMATCH',
              supplierMatched ? const {} : {'document_value': extractedSupplier, 'system_value': sysSupplier}),
    );

    // Check Importer Name
    final String? extractedImporter =
        nonEmpty(invData['importer_name'] as String?) ?? nonEmpty(invData['consignee_name'] as String?);
    final String? sysImporter = nonEmpty(currentFile?.companyName);
    final bool importerMatched = extractedImporter != null && sysImporter != null
        ? contains(extractedImporter, sysImporter) || contains(sysImporter, extractedImporter)
        : true;
    addCheck(
      field: 'importer_name',
      fieldAr: 'اسم الشركة المستوردة',
      status: extractedImporter == null ? 'WARNING' : (importerMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysImporter, 'NOT_SET'),
      extracted: orPlaceholder(extractedImporter, 'NOT_IN_DOCUMENT'),
      uploadedPacking:
          orPlaceholder(nonEmpty((plData['importer_name'] ?? plData['consignee_name']) as String?), 'NOT_IN_DOCUMENT'),
      details: extractedImporter == null
          ? unreadable('Could not read the importer name from the document')
          : CodedItemText.coded(
              'details',
              importerMatched ? 'DOC_CHK_IMPORTER_MATCH' : 'DOC_CHK_IMPORTER_MISMATCH',
              importerMatched ? const {} : {'document_value': extractedImporter, 'system_value': sysImporter}),
    );

    // Check HS Code
    final String? extractedHs = nonEmpty(invData['hs_code'] as String?);
    final String? sysHs = packingItems.isNotEmpty ? nonEmpty(packingItems.first.hsCode) : null;
    final bool hsMatched = extractedHs != null && sysHs != null
        ? extractedHs.replaceAll('.', '') == sysHs.replaceAll('.', '') ||
            extractedHs.contains(sysHs) ||
            sysHs.contains(extractedHs)
        : true;
    addCheck(
      field: 'hs_code',
      fieldAr: 'البند الجمركي (HS Code)',
      status: extractedHs == null ? 'WARNING' : (hsMatched ? 'MATCH' : 'DISCREPANCY'),
      system: orPlaceholder(sysHs, 'NOT_SET'),
      extracted: orPlaceholder(extractedHs, 'NOT_IN_DOCUMENT'),
      uploadedPacking: orPlaceholder(nonEmpty(plData['hs_code'] as String?), 'NOT_IN_DOCUMENT'),
      details: extractedHs == null
          ? unreadable('Could not read the HS code from the document')
          : CodedItemText.coded(
              'details',
              hsMatched ? 'DOC_CHK_HS_CODE_MATCH' : 'DOC_CHK_HS_CODE_MISMATCH',
              hsMatched ? const {} : {'document_value': extractedHs, 'system_value': sysHs}),
    );

    final List<Map<String, dynamic>> reconciledInvItems = invoiceItems.map((i) => i.toJson()).toList();
    final List<Map<String, dynamic>> reconciledPackingItems = packingItems.map((i) => i.toJson()).toList();

    final int critCount = headerDiscrepancies.where((d) => d['status'] == 'DISCREPANCY').length;
    final int warnCount = headerDiscrepancies.where((d) => d['status'] == 'WARNING').length;
    final String overallStatus = critCount > 0
        ? 'CRITICAL_DISCREPANCY'
        : (warnCount > 0 ? 'ACCEPTED_WITH_WARNINGS' : 'FULLY_MATCHED');

    return {
      'overall_status': overallStatus,
      'is_safe_for_certification': critCount == 0,
      'critical_discrepancies_count': critCount,
      'warning_discrepancies_count': warnCount,
      'header_discrepancies': headerDiscrepancies,
      'reconciled_invoice_items': reconciledInvItems,
      'reconciled_packing_items': reconciledPackingItems,
      'extracted_invoice_data': invData,
      'extracted_packing_data': plData,
    };
  }
}
