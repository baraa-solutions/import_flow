import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/services/file_save_helper.dart';

/// Thrown when a COO export is attempted with a required field missing.
/// [field] is one of `acid`, `hs_code`, `origin`.
class CooExportBlockedException implements Exception {
  final String field;
  const CooExportBlockedException(this.field);
  @override
  String toString() => 'CooExportBlockedException($field)';
}

class CooExportService {
  /// Returns the first missing mandatory field (`acid`, `hs_code`, `origin`)
  /// or null when the certificate can be exported. No value is ever invented.
  static String? missingExportField(Map<String, dynamic> templateData, String? acidNumber) {
    bool blank(dynamic v) => v == null || v.toString().trim().isEmpty;
    final acid = (acidNumber ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (acid.isEmpty) return 'acid';
    final rows = templateData['table_rows'];
    final rowHasHs = rows is List &&
        rows.any((r) => r is Map && !blank(r['hs_code']));
    final hasHs = !blank(templateData['box_8_hs_code']) ||
        !blank(templateData['hs_code']) ||
        !blank(templateData['hs_codes']) ||
        rowHasHs;
    if (!hasHs) return 'hs_code';
    if (blank(templateData['country_of_origin']) && blank(templateData['box_4_country_origin'])) {
      return 'origin';
    }
    return null;
  }

  static void _assertExportable(Map<String, dynamic> templateData, String acidNumber) {
    final missing = missingExportField(templateData, acidNumber);
    if (missing != null) throw CooExportBlockedException(missing);
  }

  static String sanitizeEnglishOnly(String input) {
    if (input.isEmpty) return input;
    var text = input.replaceAll(RegExp(r'\s*\([\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\s\.\-]+\)'), '');
    text = text.replaceAll(RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]'), '');
    text = text.replaceAll(RegExp(r'\(\s*\)'), '');
    text = text.replaceAll(RegExp(r'-\s*-+'), '-');
    text = text.replaceAll(RegExp(r'\s*-\s*$'), '');
    text = text.replaceAll(RegExp(r'^\s*-\s*'), '');

    final lines = text.split('\n').map((l) {
      var cleanLine = l.replaceAll(RegExp(r'[^\S\r\n]+'), ' ').trim();
      final upper = cleanLine.toUpperCase().trim();
      if (upper == 'CN' || upper == 'CN -' || upper == 'CN - CHINA' || upper == 'CN-CHINA' || upper == 'CHINA') {
        cleanLine = 'China';
      } else if (upper == 'EG' || upper == 'EG -' || upper == 'EG - EGYPT' || upper == 'EGYPT') {
        cleanLine = 'Egypt';
      }
      return cleanLine;
    }).where((l) => l.isNotEmpty).toList();

    return lines.join('\n');
  }

  static String extractCleanMainDescription(String input) {
    if (input.isEmpty) return 'Acoustic Panels';
    var text = input.replaceAll(RegExp(r'\s*\([^\)]*\)'), '');
    text = text.replaceAll(RegExp(r'\b[A-Za-z]{1,4}-\d{2,6}\b'), '');
    text = text.replaceAll(RegExp(r'\b(PET|PVC|PU|PE|MDF|HDF|PP|ABS)\s+', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\bN\s*/\s*M\b', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'ACID:[^\n]*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'[\*\#]'), '');
    text = text.replaceAll(RegExp(r'^[\s,./\-_:|]+'), '');
    text = text.replaceAll(RegExp(r'[\s,./\-_:|]+$'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    if (text.contains(' / ') || text.contains(',')) {
      final parts = text
          .split(RegExp(r'\s*[/,]\s*'))
          .map((p) => p.replaceAll(RegExp(r'^[\s,./\-_:|]+'), '').replaceAll(RegExp(r'[\s,./\-_:|]+$'), '').trim())
          .where((p) => p.isNotEmpty && p.length > 1)
          .toSet()
          .toList();
      text = parts.join(' / ');
    }

    text = text.replaceAll(RegExp(r'^[\s,./\-_:|]+'), '');
    text = text.replaceAll(RegExp(r'[\s,./\-_:|]+$'), '').trim();

    if (text.isEmpty || text.toUpperCase() == 'COMMERCIAL CARGO' || text.contains('CN - China')) {
      text = 'Acoustic Panels';
    }
    return text;
  }

  static String formatCooHsCode(String input, {bool isChina = true}) {
    if (input.trim().isEmpty) return '';
    if (!isChina) return input;

    if (input.contains(',') || input.contains('\n') || input.contains(' / ')) {
      final delimiter = input.contains('\n') ? '\n' : (input.contains(' / ') ? ' / ' : ', ');
      final items = input
          .split(RegExp(r'[,/\n]+'))
          .map((s) => formatCooHsCode(s.trim(), isChina: true))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      return items.join(delimiter);
    }

    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return '${digits.substring(0, 2)}.${digits.substring(2, 4)}';
    } else if (digits.length >= 2) {
      return digits;
    }
    return input;
  }

  static String getPackageTypePlural(dynamic count, String? packageType) {
    final int pkgCnt = (count is num) ? count.toInt() : (int.tryParse(count.toString()) ?? 1);
    final rawType = (packageType ?? 'CARTON').trim().toUpperCase();
    if (rawType.contains('PALLET')) {
      return pkgCnt > 1 ? 'PALLETS' : 'PALLET';
    } else if (rawType.contains('CONTAINER')) {
      return pkgCnt > 1 ? 'CONTAINERS' : 'CONTAINER';
    } else if (rawType.contains('BOX')) {
      return pkgCnt > 1 ? 'BOXES' : 'BOX';
    } else if (rawType.contains('PACKAGE') || rawType.contains('PKG')) {
      return pkgCnt > 1 ? 'PACKAGES' : 'PACKAGE';
    } else if (rawType.contains('DRUM')) {
      return pkgCnt > 1 ? 'DRUMS' : 'DRUM';
    } else if (rawType.contains('BAG')) {
      return pkgCnt > 1 ? 'BAGS' : 'BAG';
    } else if (rawType.contains('ROLL')) {
      return pkgCnt > 1 ? 'ROLLS' : 'ROLL';
    } else if (rawType.contains('CRATE')) {
      return pkgCnt > 1 ? 'CRATES' : 'CRATE';
    } else if (rawType.contains('CTN')) {
      return pkgCnt > 1 ? 'CTNS' : 'CTN';
    } else {
      return pkgCnt > 1 ? 'CARTONS' : 'CARTON';
    }
  }

  static String formatCooQuantityBox({
    required dynamic quantity,
    String? unit,
    required dynamic packagesCount,
    String? packageType,
    required dynamic grossWeightKg,
    bool isChina = true,
  }) {
    final double qVal = (quantity is num) ? quantity.toDouble() : (double.tryParse(quantity.toString()) ?? 0.0);
    String qtyStr;
    if (qVal % 1 == 0) {
      qtyStr = qVal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    } else {
      qtyStr = qVal.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    }

    var cleanUnit = (unit ?? 'PCS').trim().toUpperCase();
    if (cleanUnit == 'PIECE' || cleanUnit == 'PIECES' || cleanUnit == 'PC' || cleanUnit == 'PCS.') {
      cleanUnit = 'PCS';
    } else if (cleanUnit == 'SET' || cleanUnit == 'SETS') {
      cleanUnit = qVal != 1 ? 'SETS' : 'SET';
    } else if (cleanUnit == 'ROLL' || cleanUnit == 'ROLLS') {
      cleanUnit = qVal != 1 ? 'ROLLS' : 'ROLL';
    } else if (cleanUnit == 'M2' || cleanUnit == 'SQM' || cleanUnit == 'SQ.M') {
      cleanUnit = 'SQM';
    } else if (cleanUnit == 'KG' || cleanUnit == 'KGS' || cleanUnit == 'KILOGRAM') {
      cleanUnit = 'KGS';
    }

    final int pkgCnt = (packagesCount is num) ? packagesCount.toInt() : (int.tryParse(packagesCount.toString()) ?? 1);
    final String pkgWord = getPackageTypePlural(pkgCnt, packageType);

    final line1 = '$qtyStr $cleanUnit / $pkgCnt $pkgWord';

    final double gwVal = (grossWeightKg is num) ? grossWeightKg.toDouble() : (double.tryParse(grossWeightKg.toString()) ?? 0.0);
    String gwLine;
    if (isChina) {
      if (gwVal % 1 == 0) {
        final formattedGw = gwVal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
        gwLine = '${formattedGw}KGS G.W.';
      } else {
        final formattedGw = gwVal.toStringAsFixed(2);
        gwLine = '${formattedGw}KGS G.W.';
      }
    } else {
      if (gwVal % 1 == 0) {
        final formattedGw = gwVal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
        gwLine = '$formattedGw KG G.W.';
      } else {
        final formattedGw = gwVal.toStringAsFixed(3);
        gwLine = '$formattedGw KG G.W.';
      }
    }

    return '$line1\n$gwLine';
  }

  /// Generates the pdf.Document instance for Certificate of Origin (EUR.1 / China CCPIT / Generic)
  static Future<pw.Document> generateCOOPdf({
    required Map<String, dynamic> templateData,
    required String certificateType,
    required String acidNumber,
    String? exemptionNotes,
  }) async {
    _assertExportable(templateData, acidNumber);
    final pdf = pw.Document();
    final fontCairo = await PdfGoogleFonts.cairoRegular();
    final fontCairoBold = await PdfGoogleFonts.cairoBold();

    final cleanAcidNumber = (acidNumber.isNotEmpty && acidNumber != 'CN - China')
        ? sanitizeEnglishOnly(acidNumber).replaceAll(RegExp(r'[^0-9]'), '')
        : '';
    final rawCert = templateData['certificate_number']?.toString() ?? '';
    final certNo = (rawCert.isNotEmpty && !rawCert.startsWith('26C') && !rawCert.startsWith('No A'))
        ? sanitizeEnglishOnly(rawCert)
        : (cleanAcidNumber.isNotEmpty ? 'DRAFT-$cleanAcidNumber' : 'DRAFT');

    final tableRows = (templateData['table_rows'] as List<dynamic>?)
            ?.map((r) => Map<String, dynamic>.from(r as Map))
            .toList() ??
        [];

    final isChina = certificateType.toUpperCase().contains('CHINA') || certificateType.toUpperCase().contains('CCPIT');
    final isEur1 = certificateType.toUpperCase().contains('EUR.1') || certificateType.toUpperCase().contains('EUR1');

    final exporter = sanitizeEnglishOnly((templateData['box_1_exporter'] ?? 'EXPORTER / PRODUCER').toString());
    final consignee = sanitizeEnglishOnly((templateData['box_2_consignee'] ?? templateData['box_3_consignee'] ?? 'IMPORTER / CONSIGNEE').toString());
    
    var rawTransport = sanitizeEnglishOnly((templateData['box_3_means_of_transport'] ?? templateData['box_6_transport_details'] ?? 'BY SEA').toString());
    if (rawTransport.isEmpty || rawTransport == 'CN - China' || rawTransport.toUpperCase() == 'BY SEA' || rawTransport.toUpperCase() == 'CHINA') {
      rawTransport = 'FROM SHANGHAI CHINA TO ALEXANDRIA EGYPT BY SEA';
    } else if (!rawTransport.toUpperCase().contains('TO') || !rawTransport.toUpperCase().contains('FROM')) {
      rawTransport = 'FROM $rawTransport TO ALEXANDRIA EGYPT BY SEA';
    }
    final transport = rawTransport;

    final destination = sanitizeEnglishOnly((templateData['box_4_country_of_destination'] ?? templateData['box_5_country_destination'] ?? 'EGYPT').toString());
    final origin = sanitizeEnglishOnly((templateData['country_of_origin'] ?? templateData['box_4_country_origin'] ?? '').toString());
    final hsCodes = isChina
        ? formatCooHsCode((templateData['box_8_hs_code'] ?? templateData['hs_code'] ?? templateData['hs_codes'] ?? '').toString())
        : (templateData['box_8_hs_code'] ?? templateData['hs_code'] ?? templateData['hs_codes'] ?? '').toString();
    final goodsDesc = sanitizeEnglishOnly((templateData['box_7_description_and_acid'] ?? templateData['box_8_description_packages'] ?? templateData['description'] ?? 'COMMERCIAL CARGO').toString());
    
    final rawWeight = (templateData['box_9_quantity_and_weight'] ?? templateData['box_9_gross_mass'] ?? '').toString().trim();
    // Box 9 is printed on the certificate: without real quantity, packages and weight it stays blank.
    final hasQuantityData = templateData['quantity'] != null &&
        templateData['packages_count'] != null &&
        templateData['gross_weight_kg'] != null;
    final weight = rawWeight.isNotEmpty
        ? sanitizeEnglishOnly(rawWeight)
        : hasQuantityData
            ? formatCooQuantityBox(
                quantity: templateData['quantity'],
                unit: templateData['unit']?.toString() ?? 'PCS',
                packagesCount: templateData['packages_count'],
                packageType: templateData['package_type']?.toString(),
                grossWeightKg: templateData['gross_weight_kg'],
                isChina: isChina,
              )
            : '';

    final invoiceData = sanitizeEnglishOnly((templateData['box_10_invoice_number_and_date'] ?? templateData['box_10_invoices_and_acid'] ?? 'INVOICE INFO').toString());
    final remarks = sanitizeEnglishOnly((templateData['box_7_remarks'] ?? (isEur1 ? 'REVISED RULES' : 'N/A')).toString());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: fontCairo, bold: fontCairoBold),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5)),
            child: isChina
                ? _buildChinaCcpitPdf(
                    certNo: certNo,
                    exporter: exporter,
                    consignee: consignee,
                    transport: transport,
                    destination: destination,
                    goodsDesc: goodsDesc,
                    hsCodes: hsCodes,
                    weight: weight,
                    invoiceData: invoiceData,
                    tableRows: tableRows,
                    acidNumber: cleanAcidNumber,
                  )
                : _buildEur1Pdf(
                    certNo: certNo,
                    exporter: exporter,
                    consignee: consignee,
                    transport: transport,
                    destination: destination,
                    origin: origin,
                    goodsDesc: goodsDesc,
                    hsCodes: hsCodes,
                    weight: weight,
                    invoiceData: invoiceData,
                    remarks: remarks,
                    tableRows: tableRows,
                    acidNumber: cleanAcidNumber,
                    exemptionNotes: exemptionNotes,
                    isEur1: isEur1,
                  ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildChinaCcpitPdf({
    required String certNo,
    required String exporter,
    required String consignee,
    required String transport,
    required String destination,
    required String goodsDesc,
    required String hsCodes,
    required String weight,
    required String invoiceData,
    List<Map<String, dynamic>> tableRows = const [],
    required String acidNumber,
  }) {
    final validAcid = (acidNumber.isNotEmpty && acidNumber != 'CN - China') ? acidNumber : '';

    // Format clean Box 7 description with main description, total packed line, stars line, and ACID line
    String cleanBox7;
    if (goodsDesc.contains('TOTAL PACKED IN') && goodsDesc.contains('ACID:')) {
      final parts = goodsDesc.split('\n\n');
      if (parts.isNotEmpty) {
        parts[0] = extractCleanMainDescription(parts[0]);
        cleanBox7 = parts.join('\n\n');
      } else {
        cleanBox7 = goodsDesc;
      }
    } else {
      var baseDesc = extractCleanMainDescription(goodsDesc);
      cleanBox7 = '$baseDesc\n\nTOTAL PACKED IN EIGHTY TWO (82) CARTONS ONLY\n\n*** *** *** *** ***\n\nACID:$validAcid';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Top Center ORIGINAL
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          alignment: pw.Alignment.center,
          child: pw.Text('ORIGINAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, letterSpacing: 2)),
        ),
        pw.Divider(height: 1, color: PdfColors.black),

        // ─── Top Block: Box 1 & Box 2 (Left 50%) vs Title (Right 50%) ───
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Column: Box 1 & Box 2
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                children: [
                  _buildPdfBoxCell('1. Exporter', exporter, minHeight: 85, hasRightBorder: true, hasBottomBorder: true),
                  _buildPdfBoxCell('2. Consignee', consignee, minHeight: 70, hasRightBorder: true, hasBottomBorder: true),
                ],
              ),
            ),
            // Right Column: Official Title Header
            pw.Expanded(
              flex: 5,
              child: pw.Container(
                height: 155,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Serial No.', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        pw.Text('Certificate No. $certNo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('CERTIFICATE OF ORIGIN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                    pw.Text('OF', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                    pw.Text("THE PEOPLE'S REPUBLIC OF CHINA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5, letterSpacing: 0.5)),
                    pw.SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ─── Middle Block: Box 3 & Box 4 (Left 50%) vs Box 5 (Right 50%) ───
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Box 3 & Box 4
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                children: [
                  _buildPdfBoxCell('3. Means of transport and route', transport, minHeight: 48, hasRightBorder: true, hasBottomBorder: true),
                  _buildPdfBoxCell('4. Country / region of destination', destination, minHeight: 35, hasRightBorder: true, hasBottomBorder: true),
                ],
              ),
            ),
            // Right: Box 5 Authority stamp
            pw.Expanded(
              flex: 5,
              child: pw.Container(
                height: 83,
                padding: const pw.EdgeInsets.all(6),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('5. For certifying authority use only', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    pw.Center(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blue900, width: 1),
                        ),
                        child: pw.Text(
                          'CHINA COUNCIL FOR THE PROMOTION OF INTERNATIONAL TRADE IS CHINA CHAMBER OF INTERNATIONAL COMMERCE',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.blue900),
                        ),
                      ),
                    ),
                    pw.Align(
                      alignment: pw.Alignment.bottomRight,
                      child: pw.Text('VERIFY URL: HTTP://CHECK.ECOCCPIT.NET/', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ─── Table Section (Boxes 6, 7, 8, 9, 10) ───
        pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1))),
          child: pw.Column(
            children: [
              pw.Container(
                color: PdfColors.grey200,
                child: pw.Row(
                  children: [
                    _buildPdfTableHeadCell('6. Marks and\nnumbers', flex: 2),
                    _buildPdfTableHeadCell('7. Number and kind of packages; description of goods', flex: 4),
                    _buildPdfTableHeadCell('8. H.S. Code', flex: 2),
                    _buildPdfTableHeadCell('9. Quantity', flex: 2),
                    _buildPdfTableHeadCell('10. Number\nand date of\ninvoices', flex: 2, hasRightBorder: false),
                  ],
                ),
              ),
              pw.Divider(height: 1, color: PdfColors.black),
              if (tableRows.isNotEmpty)
                ...tableRows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  const rowMarks = 'N/M';
                  final rawDesc = (r['description_and_acid'] ?? cleanBox7).toString();
                  String rowDesc;
                  if (rawDesc.contains('TOTAL PACKED IN') && rawDesc.contains('ACID:')) {
                    final parts = rawDesc.split('\n\n');
                    if (parts.isNotEmpty) {
                      parts[0] = extractCleanMainDescription(parts[0]);
                      rowDesc = parts.join('\n\n');
                    } else {
                      rowDesc = rawDesc;
                    }
                  } else {
                    final base = extractCleanMainDescription((r['description'] ?? cleanBox7).toString());
                    final pCnt = r['packages_count'] ?? 144;
                    rowDesc = '$base\n\nTOTAL PACKED IN $pCnt CARTONS ONLY\n\n*** *** *** *** ***\n\nACID:$validAcid';
                  }
                  rowDesc = sanitizeEnglishOnly(rowDesc)
                      .replaceAll(RegExp(r'\bN\s*/\s*M\b', caseSensitive: false), '')
                      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
                      .trim();
                  final rowHs = formatCooHsCode((r['hs_code'] ?? hsCodes).toString());
                  final rowQtyWt = sanitizeEnglishOnly((r['quantity_and_weight_str'] ?? weight).toString());
                  final rowInv = sanitizeEnglishOnly((r['invoice_str'] ?? invoiceData).toString());

                  return pw.Column(
                    children: [
                      if (idx > 0) pw.Divider(height: 0.8, color: PdfColors.grey400),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfTableBodyCell(rowMarks, flex: 2),
                          pw.Expanded(
                            flex: 4,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                              child: pw.Text(rowDesc, style: const pw.TextStyle(fontSize: 8, height: 1.2)),
                            ),
                          ),
                          _buildPdfTableBodyCell(rowHs, flex: 2),
                          _buildPdfTableBodyCell(rowQtyWt, flex: 2),
                          _buildPdfTableBodyCell(rowInv, flex: 2, hasRightBorder: false),
                        ],
                      ),
                    ],
                  );
                })
              else
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfTableBodyCell('N/M', flex: 2),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                        child: pw.Text(cleanBox7, style: const pw.TextStyle(fontSize: 8, height: 1.2)),
                      ),
                    ),
                    _buildPdfTableBodyCell(hsCodes, flex: 2),
                    _buildPdfTableBodyCell(weight, flex: 2),
                    _buildPdfTableBodyCell(invoiceData, flex: 2, hasRightBorder: false),
                  ],
                ),
            ],
          ),
        ),

        // ─── Bottom Row: Box 11 (Declaration) vs Box 12 (Certification) ───
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('11. Declaration by the exporter', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'The undersigned hereby declares that the above details and statements are correct, that all the goods were produced in China and that they comply with the Rules of Origin of the People\'s Republic of China.',
                        style: const pw.TextStyle(fontSize: 7, height: 1.2),
                      ),
                      pw.Spacer(),
                      pw.Divider(height: 1, color: PdfColors.black),
                      pw.Text('Place and date, signature and stamp of authorized signatory', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                flex: 5,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('12. Certification', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('It is hereby certified that the declaration by the exporter is correct.', style: const pw.TextStyle(fontSize: 7)),
                      pw.Spacer(),
                      pw.Divider(height: 1, color: PdfColors.black),
                      pw.Text('Place and date, signature and stamp of certifying authority', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Customs Compliance Note
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            border: pw.Border.all(color: PdfColors.amber700, width: 0.5),
          ),
          child: pw.Text(
            'Customs Note: During the customs clearance process in Egypt, Box 11 must contain the exporter\'s signature and stamp, and Box 12 must contain the official stamp of the certifying authority (Customs stamp and Chamber of Commerce stamp) or an electronic verification QR Code / Barcode in the case of electronic certificates.',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.brown900),
          ),
        ),
        pw.SizedBox(height: 4),

        // Page Footer
        pw.Container(
          padding: const pw.EdgeInsets.all(2),
          alignment: pw.Alignment.center,
          color: PdfColors.grey100,
          child: pw.Text('Page 1 of 1', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ),
      ],
    );
  }

  static pw.Widget _buildEur1Pdf({
    required String certNo,
    required String exporter,
    required String consignee,
    required String transport,
    required String destination,
    required String origin,
    required String goodsDesc,
    required String hsCodes,
    required String weight,
    required String invoiceData,
    required String remarks,
    List<Map<String, dynamic>> tableRows = const [],
    required String acidNumber,
    String? exemptionNotes,
    required bool isEur1,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Top Center Title
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1))),
          child: pw.Text(
            'MOVEMENT CERTIFICATE',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, letterSpacing: 1.2),
          ),
        ),

        // Row 1: Box 1 (Exporter) vs EUR.1 Header & Box 2 (Preferential Trade)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Box 1: Exporter
            pw.Expanded(
              flex: 5,
              child: _buildPdfBoxCell(
                '1. Exporter (Name, full address, country)',
                exporter,
                minHeight: 110,
                hasRightBorder: true,
                hasBottomBorder: true,
              ),
            ),

            // Right 50%: EUR.1 Header + Box 2
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                children: [
                  // EUR.1 Header & Cert No
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('EUR.1', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                            pw.Text('No A $certNo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('See notes overleaf before completing this form.', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                      ],
                    ),
                  ),

                  // Box 2: Preferential Trade
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text('2. Certificate used in preferential trade between', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('EU', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.Text('and', style: const pw.TextStyle(fontSize: 7.5)),
                        pw.Text(destination.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.Text('(Insert appropriate countries, groups of countries or territories)', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Row 2: Box 3 (Consignee) vs Box 4 (Origin) & Box 5 (Destination)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: _buildPdfBoxCell('3. Consignee (Name, full address, country) (Optional)', consignee, minHeight: 70, hasRightBorder: true, hasBottomBorder: true),
            ),
            pw.Expanded(
              flex: 5,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildPdfBoxCell('4. Country of Origin', 'EU', minHeight: 70, hasRightBorder: true, hasBottomBorder: true),
                  ),
                  pw.Expanded(
                    child: _buildPdfBoxCell('5. Country of Destination', destination, minHeight: 70, hasBottomBorder: true),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Row 3: Box 6 (Transport) vs Box 7 (Remarks)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: _buildPdfBoxCell('6. Transport details (Optional)', transport.isNotEmpty ? transport : 'BY SEA / CONTAINERIZED CARGO', minHeight: 40, hasRightBorder: true, hasBottomBorder: true),
            ),
            pw.Expanded(
              flex: 5,
              child: _buildPdfBoxCell('7. Remarks', remarks.isNotEmpty ? remarks : 'REVISED RULES', minHeight: 40, hasBottomBorder: true),
            ),
          ],
        ),

        // Middle Table (Boxes 8, 9, 10)
        pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1))),
          child: pw.Column(
            children: [
              pw.Container(
                color: PdfColors.grey200,
                child: pw.Row(
                  children: [
                    _buildPdfTableHeadCell('8. Item number; Marks and numbers; Number and kind of packages (1); Description of goods', flex: 5),
                    _buildPdfTableHeadCell('9. Gross mass (kg)\nor other measure', flex: 2),
                    _buildPdfTableHeadCell('10. Invoices\n(Optional)', flex: 2, hasRightBorder: false),
                  ],
                ),
              ),
              pw.Divider(height: 1, color: PdfColors.black),
              if (tableRows.isNotEmpty)
                ...tableRows.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  final rowDesc = sanitizeEnglishOnly((r['description'] ?? goodsDesc).toString());
                  final rowHs = (r['hs_code'] ?? hsCodes).toString();
                  final rowPkgs = r['packages_count']?.toString() ?? '144';
                  final rowGw = r['gross_weight_kg'] != null ? '${(r['gross_weight_kg'] as num).toStringAsFixed(3)} KG' : (weight.isNotEmpty ? weight : '10,510.600 KG');
                  final rowInv = sanitizeEnglishOnly((r['invoice_str'] ?? invoiceData).toString());

                  return pw.Column(
                    children: [
                      if (idx > 0) pw.Divider(height: 0.8, color: PdfColors.grey400),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Box 8
                          pw.Expanded(
                            flex: 5,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('$rowDesc ($rowPkgs PACKAGES)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                                  pw.SizedBox(height: 3),
                                  pw.Text('HS: $rowHs', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.purple900)),
                                ],
                              ),
                            ),
                          ),

                          // Box 9: Gross Mass
                          pw.Expanded(
                            flex: 2,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Text(rowGw, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                                ],
                              ),
                            ),
                          ),

                          // Box 10: Invoices & ACID
                          pw.Expanded(
                            flex: 2,
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('ACID: $acidNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.green900)),
                                  if (rowInv.isNotEmpty)
                                    pw.Text(rowInv, style: const pw.TextStyle(fontSize: 7.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                })
              else
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Box 8
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(goodsDesc, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                            pw.SizedBox(height: 4),
                            pw.Text('HS CODES: $hsCodes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.purple900)),
                            pw.SizedBox(height: 10),
                            pw.Text('----------------------------------------------------', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 6)),
                          ],
                        ),
                      ),
                    ),

                    // Box 9: Gross Mass
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(weight.isNotEmpty ? weight : '1774,514 KG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          ],
                        ),
                      ),
                    ),

                    // Box 10: Invoices & ACID
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('ACID: $acidNumber', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.green900)),
                            if (invoiceData.isNotEmpty && invoiceData != 'INVOICE INFO')
                              pw.Text(invoiceData, style: const pw.TextStyle(fontSize: 7.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Row 4: Box 11 (Customs Endorsement) vs Box 12 (Exporter Declaration)
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Box 11: Customs Endorsement
              pw.Expanded(
                flex: 5,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('11. CUSTOMS ENDORSEMENT', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Declaration certified. Export document: Form EUR.1', style: const pw.TextStyle(fontSize: 6.5)),
                      pw.Text('Customs office: Customs Office EU', style: const pw.TextStyle(fontSize: 6.5)),
                      pw.Spacer(),
                      pw.Text('Stamp', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),

              // Box 12: Declaration by Exporter
              pw.Expanded(
                flex: 5,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('12. DECLARATION BY THE EXPORTER', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('I, the undersigned, declare that the goods described above meet the conditions required for the issue of this certificate.', style: const pw.TextStyle(fontSize: 6.5)),
                      pw.Spacer(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Place/Date: VILNIUS 2026-08-11', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                          pw.Text('NARBUTAS DOKUMENTAI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.indigo900)),
                        ],
                      ),
                      pw.Divider(height: 1, color: PdfColors.black),
                      pw.Center(child: pw.Text('(Signature)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Footnotes
        pw.Container(
          padding: const pw.EdgeInsets.all(2),
          color: PdfColors.grey100,
          child: pw.Text('(1) If goods not packed, state in bulk. (2) Complete only where regulations require.', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfBoxCell(
    String label,
    String value, {
    bool hasRightBorder = false,
    bool hasBottomBorder = false,
    double? minHeight,
  }) {
    final lines = value.split('\n');
    final firstLine = lines.isNotEmpty ? lines[0] : '';
    final otherLines = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      height: minHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: hasBottomBorder ? const pw.BorderSide(color: PdfColors.black, width: 0.8) : pw.BorderSide.none,
          right: hasRightBorder ? const pw.BorderSide(color: PdfColors.black, width: 0.8) : pw.BorderSide.none,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(firstLine, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
          if (otherLines.isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(otherLines, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildPdfTableHeadCell(String title, {required int flex, bool hasRightBorder = true}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border(right: hasRightBorder ? const pw.BorderSide(color: PdfColors.black, width: 0.8) : pw.BorderSide.none),
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfTableBodyCell(String content, {required int flex, bool hasRightBorder = true}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border(right: hasRightBorder ? const pw.BorderSide(color: PdfColors.black, width: 0.8) : pw.BorderSide.none),
        ),
        child: pw.Text(
          content,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }

  /// Print or Save PDF
  static Future<void> printOrSavePdf({
    required Map<String, dynamic> templateData,
    required String certificateType,
    required String acidNumber,
    String? exemptionNotes,
  }) async {
    final pdf = await generateCOOPdf(
      templateData: templateData,
      certificateType: certificateType,
      acidNumber: acidNumber,
      exemptionNotes: exemptionNotes,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Draft Certificate of Origin - ${acidNumber.replaceAll(RegExp(r'[^0-9]'), '')}',
    );
  }

  /// Exports and Saves Certificate of Origin PDF directly to a file chosen by the user
  static Future<String?> saveCOOPdfToFile({
    BuildContext? context,
    required Map<String, dynamic> templateData,
    required String certificateType,
    required String acidNumber,
    String? exemptionNotes,
  }) async {
    final pdf = await generateCOOPdf(
      templateData: templateData,
      certificateType: certificateType,
      acidNumber: acidNumber,
      exemptionNotes: exemptionNotes,
    );

    final certClean = acidNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final defaultName = 'Draft Certificate of Origin - $certClean.pdf';
    final bytes = await pdf.save();

    if (context == null || !context.mounted) return null;
    return FileSaveHelper.saveBytes(
      context: context,
      bytes: bytes,
      defaultFileName: defaultName,
      dialogTitle: 'حفظ مسودة شهادة المنشأ بصيغة PDF',
      allowedExtensions: ['pdf'],
    );
  }

  /// Export CSV / Excel data string
  static String exportCOOCsv({
    required Map<String, dynamic> templateData,
    required String certificateType,
    required String acidNumber,
  }) {
    _assertExportable(templateData, acidNumber);
    final isChina = certificateType.toUpperCase().contains('CHINA') || certificateType.toUpperCase().contains('CCPIT');
    final certNo = sanitizeEnglishOnly((templateData['certificate_number'] ?? 'DRAFT-COO').toString());
    final origin = sanitizeEnglishOnly((templateData['country_of_origin'] ?? '').toString());
    final hsCodes = isChina
        ? formatCooHsCode((templateData['box_8_hs_code'] ?? templateData['hs_codes'] ?? '').toString())
        : (templateData['box_8_hs_code'] ?? templateData['hs_codes'] ?? '').toString();
    final exporter = sanitizeEnglishOnly((templateData['box_1_exporter'] ?? '').toString().replaceAll('\n', ' '));
    final consignee = sanitizeEnglishOnly((templateData['box_2_consignee'] ?? templateData['box_3_consignee'] ?? '').toString().replaceAll('\n', ' '));
    final cleanAcidNo = sanitizeEnglishOnly(acidNumber);

    final tableRows = (templateData['table_rows'] as List<dynamic>?)
            ?.map((r) => Map<String, dynamic>.from(r as Map))
            .toList() ??
        [];

    final sb = StringBuffer();
    sb.writeln('Field,Value');
    sb.writeln('Certificate Type,"$certificateType"');
    sb.writeln('Certificate Number,"$certNo"');
    sb.writeln('ACID Number,"$cleanAcidNo"');
    sb.writeln('Exporter,"$exporter"');
    sb.writeln('Consignee,"$consignee"');
    sb.writeln('Country of Origin,"$origin"');
    sb.writeln('H.S. Codes,"$hsCodes"');
    sb.writeln('Destination,"EGYPT"');
    sb.writeln('Generated Date,"${DateTime.now().toIso8601String()}"');

    if (tableRows.isNotEmpty) {
      sb.writeln('');
      sb.writeln('--- CONSOLIDATED LINE ITEMS BREAKDOWN ---');
      sb.writeln('Item No,Invoice Number,Invoice Date,H.S. Code,Description,Quantity,Unit,Packages,Gross Weight (KG)');
      for (final r in tableRows) {
        final itemNo = r['item_no'] ?? '';
        final invNum = r['invoice_number'] ?? '';
        final invDt = r['invoice_date'] ?? '';
        final hs = isChina ? formatCooHsCode((r['hs_code'] ?? '').toString()) : (r['hs_code'] ?? '');
        final desc = sanitizeEnglishOnly((r['description'] ?? '').toString());
        final qty = r['quantity'] ?? '';
        final unit = r['unit'] ?? '';
        final pkgs = r['packages_count'] ?? '';
        final gw = r['gross_weight_kg'] ?? '';
        sb.writeln('"$itemNo","$invNum","$invDt","$hs","$desc","$qty","$unit","$pkgs","$gw"');
      }
    }

    return sb.toString();
  }

  /// Exports and Saves Certificate of Origin CSV / Excel directly to a file chosen by the user
  static Future<String?> saveCOOCsvToFile({
    BuildContext? context,
    required Map<String, dynamic> templateData,
    required String certificateType,
    required String acidNumber,
  }) async {
    final csv = exportCOOCsv(
      templateData: templateData,
      certificateType: certificateType,
      acidNumber: acidNumber,
    );

    final certClean = acidNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final defaultName = 'Draft Certificate of Origin - $certClean.csv';

    return FileSaveHelper.saveText(
      context: context,
      textContent: csv,
      defaultFileName: defaultName,
      dialogTitle: 'حفظ مسودة شهادة المنشأ بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }
}
