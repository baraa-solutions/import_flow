import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/services/file_save_helper.dart';

class DraftBLExportService {
  /// Generates the pdf.Document instance for Maritime Draft B/L
  static Future<pw.Document> generateDraftBLPdf({
    required Map<String, dynamic> systemData,
    required Map<String, dynamic> draftData,
    String? draftBlNumber,
    String? bookingNumber,
    String? documentTitle,
  }) async {
    final pdf = pw.Document();
    final fontCairo = await PdfGoogleFonts.cairoRegular();
    final fontCairoBold = await PdfGoogleFonts.cairoBold();

    final blNo = (draftData['draft_bl_number'] ?? draftBlNumber ?? systemData['draft_bl_number'] ?? 'DRAFT-BL').toString();
    final bkgNo = (draftData['booking_no'] ?? bookingNumber ?? systemData['booking_no'] ?? 'BKG-REF').toString();
    final shipper = (draftData['shipper'] ?? systemData['shipper'] ?? 'EXPORTER / SUPPLIER').toString();
    final consignee = (draftData['consignee'] ?? systemData['consignee'] ?? 'IMPORTER / CONSIGNEE').toString();
    final notifyParty = (draftData['notify_party'] ?? systemData['notify_party'] ?? 'SAME AS CONSIGNEE').toString();
    final rawVessel = (draftData['vessel_name'] ?? systemData['vessel_name'] ?? '').toString().trim();
    final vessel = rawVessel.isNotEmpty ? rawVessel : 'OCEAN VESSEL';
    final rawVoyage = (draftData['voyage_number'] ?? systemData['voyage_number'] ?? '').toString().trim();
    final voyage = rawVoyage.isNotEmpty ? rawVoyage : 'VOY-01';
    final pol = (draftData['pol'] ?? systemData['pol'] ?? 'PORT OF LOADING').toString();
    final pod = (draftData['pod'] ?? systemData['pod'] ?? 'PORT OF DISCHARGE').toString();
    final placeOfDelivery = (draftData['place_of_delivery'] ?? systemData['place_of_delivery'] ?? pod).toString();
    final freightTerms = (draftData['freight_terms'] ?? systemData['freight_terms'] ?? 'FREIGHT PREPAID').toString().toUpperCase();

    final acid = (draftData['acid_number'] ?? systemData['acid_number'] ?? 'N/A').toString();
    final taxId = (draftData['importer_tax_id'] ?? systemData['importer_tax_id'] ?? 'N/A').toString();
    final regType = (draftData['shipper_reg_type'] ?? systemData['shipper_reg_type'] ?? 'VAT NUMBER').toString();
    final regId = (draftData['shipper_reg_id'] ?? systemData['shipper_reg_id'] ?? 'N/A').toString();
    final country = (draftData['shipper_country'] ?? systemData['shipper_country'] ?? 'N/A').toString();
    final countryCode = (draftData['shipper_country_code'] ?? systemData['shipper_country_code'] ?? 'EG').toString();

    final goodsDesc = (draftData['goods_description'] ?? systemData['goods_description'] ?? 'GENERAL CARGO').toString();
    final grossWeight = (draftData['total_gross_weight_kg'] ?? systemData['total_gross_weight_kg'] ?? 0.0).toString();
    final netWeight = (draftData['total_net_weight_kg'] ?? systemData['total_net_weight_kg'] ?? 0.0).toString();
    final cbm = (draftData['cbm'] ?? systemData['cbm'] ?? 0.0).toString();
    final pkgCount = (draftData['qty_pkg'] ?? systemData['packages_count'] ?? 1).toString();
    final containerSummary = (draftData['container_summary'] ?? systemData['container_summary'] ?? 'N/A').toString();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: fontCairo, bold: fontCairoBold),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.5)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header Top
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BILL OF LADING (DRAFT)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                          pw.Text(documentTitle ?? 'NON-NEGOTIABLE — FOR DRAFT REVIEW ONLY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red900)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('B/L NO: $blNo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Text('BOOKING REF: $bkgNo', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Row 1: Shipper & Carrier Agent
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Shipper Box
                    pw.Expanded(
                      flex: 3,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        height: 70,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                            right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('SHIPPER / EXPORTER:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                            pw.SizedBox(height: 2),
                            pw.Text(shipper, style: const pw.TextStyle(fontSize: 9), maxLines: 4),
                          ],
                        ),
                      ),
                    ),
                    // Carrier Agent Endorsements
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        height: 70,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("CARRIER'S AGENTS ENDORSEMENTS:", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                            pw.SizedBox(height: 2),
                            pw.Text('SHIPPER’S LOAD, STOW & COUNT / FCL / FCL', style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('Standard Maritime Carrier Endorsement', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Row 2: Consignee & POD Agent
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Consignee Box
                    pw.Expanded(
                      flex: 3,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        height: 70,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                            right: pw.BorderSide(color: PdfColors.black, width: 0.8),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('CONSIGNEE:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                            pw.SizedBox(height: 2),
                            pw.Text(consignee, style: const pw.TextStyle(fontSize: 9), maxLines: 4),
                          ],
                        ),
                      ),
                    ),
                    // POD Agent
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        height: 70,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('PORT OF DISCHARGE AGENT:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                            pw.SizedBox(height: 2),
                            pw.Text(pod, style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Row 3: Notify Party
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  height: 55,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('NOTIFY PARTY:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(notifyParty, style: const pw.TextStyle(fontSize: 8.5), maxLines: 3),
                    ],
                  ),
                ),

                // Row 4: Transit Details
                pw.Row(
                  children: [
                    _buildCell('VESSEL & VOYAGE NO', '$vessel - $voyage', flex: 2),
                    _buildCell('PORT OF LOADING (POL)', pol, flex: 2),
                    _buildCell('PORT OF DISCHARGE (POD)', pod, flex: 2),
                    _buildCell('PLACE OF DELIVERY', placeOfDelivery, flex: 2),
                  ],
                ),

                // Row 5: Table Header (PARTICULARS FURNISHED BY SHIPPER)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  child: pw.Text(
                    'PARTICULARS FURNISHED BY THE SHIPPER — NOT CHECKED BY CARRIER — CARRIER NOT RESPONSIBLE',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                // Table Columns Header
                pw.Row(
                  children: [
                    _buildTableHead('Container Nos, Seal Nos', flex: 2),
                    _buildTableHead('Description of Packages and Goods (Nafeza ACID Block)', flex: 4),
                    _buildTableHead('Gross Cargo Weight', flex: 2),
                    _buildTableHead('Measurement (CBM)', flex: 1),
                  ],
                ),

                // Table Content Area
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Containers & Seals
                      pw.Expanded(
                        flex: 2,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(containerSummary, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 6),
                              pw.Text('Marks & Numbers: N/M', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                              pw.Text('FCL/FCL Cargo', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                      ),
                      // Description of Goods & ACID Block
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('$pkgCount Packages / $goodsDesc', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 8),
                              // ACID Block
                              pw.Container(
                                padding: const pw.EdgeInsets.all(6),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('EGYPTIAN CUSTOMS ADVANCED INFORMATION (ACID BLOCK):', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                                    pw.SizedBox(height: 3),
                                    pw.Text('ACID: $acid', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                    pw.Text('EGYPTIAN IMPORTER TAX ID: $taxId', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                    pw.Text('SHIPPER REGISTRATION TYPE: $regType', style: const pw.TextStyle(fontSize: 8)),
                                    pw.Text('SHIPPER ID: $regId', style: const pw.TextStyle(fontSize: 8)),
                                    pw.Text('SHIPPER COUNTRY: $country (CODE: $countryCode)', style: const pw.TextStyle(fontSize: 8)),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 8),
                              pw.Text(freightTerms, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                            ],
                          ),
                        ),
                      ),
                      // Gross Weight
                      pw.Expanded(
                        flex: 2,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('$grossWeight KGS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 4),
                              pw.Text('Net: $netWeight KGS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                      ),
                      // Measurement CBM
                      pw.Expanded(
                        flex: 1,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('$cbm CBM', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Summary Bottom Row
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Items: $pkgCount Packages', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total Gross Weight: $grossWeight KGS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total Measurement: $cbm CBM', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Freight: $freightTerms', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    ],
                  ),
                ),

                // Footer Stamp & Signatures
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Sorour Logistics ERP Draft B/L Certification Engine', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                          pw.Text('Generated: ${DateTime.now().toIso8601String().substring(0, 19)}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('SIGNED FOR THE CARRIER / AGENT:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 12),
                          pw.Text('___________________________________', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  /// Generates and downloads standard Maritime Draft B/L as PDF
  static Future<void> exportDraftBLToPdf({
    BuildContext? context,
    required Map<String, dynamic> systemData,
    required Map<String, dynamic> draftData,
    String? draftBlNumber,
    String? bookingNumber,
    String? documentTitle,
  }) async {
    final pdf = await generateDraftBLPdf(
      systemData: systemData,
      draftData: draftData,
      draftBlNumber: draftBlNumber,
      bookingNumber: bookingNumber,
      documentTitle: documentTitle,
    );

    final blNo = (draftData['draft_bl_number'] ?? draftBlNumber ?? systemData['draft_bl_number'] ?? 'DRAFT-BL').toString();
    final pdfBytes = await pdf.save();
    if (context != null && !context.mounted) return;
    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: pdfBytes,
      stageName: 'Draft Bill of Lading',
      importFileNameOrCode: blNo.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_'),
      extension: 'pdf',
      customDialogTitle: 'حفظ مسودة البوليصة بصيغة PDF',
    );
  }

  /// Interactively prints or opens the Print Preview dialog for Maritime Draft B/L
  static Future<void> printDraftBL({
    required Map<String, dynamic> systemData,
    required Map<String, dynamic> draftData,
    String? draftBlNumber,
    String? bookingNumber,
    String? documentTitle,
  }) async {
    final pdf = await generateDraftBLPdf(
      systemData: systemData,
      draftData: draftData,
      draftBlNumber: draftBlNumber,
      bookingNumber: bookingNumber,
      documentTitle: documentTitle,
    );

    final blNo = (draftData['draft_bl_number'] ?? draftBlNumber ?? systemData['draft_bl_number'] ?? 'DRAFT-BL').toString();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Phase3_Draft_BL_${blNo.replaceAll('/', '_')}',
    );
  }

  /// Generates and downloads structured Draft B/L as Excel / CSV
  static Future<String?> exportDraftBLToExcel({
    BuildContext? context,
    required Map<String, dynamic> systemData,
    required Map<String, dynamic> draftData,
    String? draftBlNumber,
    String? bookingNumber,
  }) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM for Excel

    final blNo = draftData['draft_bl_number'] ?? draftBlNumber ?? systemData['draft_bl_number'] ?? 'DRAFT-BL';
    final bkgNo = draftData['booking_no'] ?? bookingNumber ?? systemData['booking_no'] ?? 'BKG-REF';
    final rawLine = (draftData['shipping_line'] ?? systemData['shipping_line'] ?? '').toString().trim();
    final shippingLine = rawLine.isNotEmpty ? rawLine : 'OCEAN CARRIER / FREIGHT LINE';

    buffer.writeln('Sorour Logistics ERP — مسودة بوليصة الشحن البحرية (Draft Bill of Lading)');
    buffer.writeln('رقم المسودة (B/L No.),$blNo');
    buffer.writeln('رقم الحجز (Booking Ref.),$bkgNo');
    buffer.writeln('الخط الملاحي (Shipping Line),$shippingLine');
    buffer.writeln('');

    buffer.writeln('1. بيانات الأطراف والرحلة');
    buffer.writeln('البند,بيانات المسودة (Draft Value),بيانات النظام (System Reference)');
    buffer.writeln('المصدر / الشاحن (Shipper),"${(draftData['shipper'] ?? '').replaceAll('"', '""')}","${(systemData['shipper'] ?? '').replaceAll('"', '""')}"');
    buffer.writeln('المستورد (Consignee),"${(draftData['consignee'] ?? '').replaceAll('"', '""')}","${(systemData['consignee'] ?? '').replaceAll('"', '""')}"');
    buffer.writeln('جهة الإخطار (Notify Party),"${(draftData['notify_party'] ?? '').replaceAll('"', '""')}","${(systemData['notify_party'] ?? '').replaceAll('"', '""')}"');
    buffer.writeln('الباخرة والرحلة (Vessel & Voyage),"${draftData['vessel_name'] ?? ''} - ${draftData['voyage_number'] ?? ''}","${systemData['vessel_name'] ?? ''} - ${systemData['voyage_number'] ?? ''}"');
    buffer.writeln('ميناء الشحن (POL),"${draftData['pol'] ?? ''}","${systemData['pol'] ?? ''}"');
    buffer.writeln('ميناء التفريغ (POD),"${draftData['pod'] ?? ''}","${systemData['pod'] ?? ''}"');
    buffer.writeln('مكان التسليم (Place of Delivery),"${draftData['place_of_delivery'] ?? ''}","${systemData['place_of_delivery'] ?? ''}"');
    buffer.writeln('شروط النولون (Freight Terms),"${draftData['freight_terms'] ?? 'Freight Prepaid'}","${systemData['freight_terms'] ?? 'Freight Prepaid'}"');
    buffer.writeln('');

    buffer.writeln('2. بيانات التسجيل المسبق ونافذة (Egyptian Customs ACID Block)');
    buffer.writeln('بند نافذة,القيمة');
    buffer.writeln('رقم القيد الجمركي (ACID Number),${draftData['acid_number'] ?? systemData['acid_number'] ?? ''}');
    buffer.writeln('البطاقة الضريبية للمستورد (Importer Tax ID),${draftData['importer_tax_id'] ?? systemData['importer_tax_id'] ?? ''}');
    buffer.writeln('نوع تسجيل المصدر (Shipper Reg Type),${draftData['shipper_reg_type'] ?? systemData['shipper_reg_type'] ?? 'VAT NUMBER'}');
    buffer.writeln('رقم تسجيل المصدر (Shipper ID),${draftData['shipper_reg_id'] ?? systemData['shipper_reg_id'] ?? ''}');
    buffer.writeln('دولة المصدر (Shipper Country),${draftData['shipper_country'] ?? systemData['shipper_country'] ?? ''} (كود: ${draftData['shipper_country_code'] ?? systemData['shipper_country_code'] ?? ''})');
    buffer.writeln('');

    buffer.writeln('3. الحاويات والطرود والأوزان (Containers, Packages & Weights)');
    buffer.writeln('بيان الحاويات والرصاص (Container & Seal),"${draftData['container_summary'] ?? systemData['container_summary'] ?? ''}"');
    buffer.writeln('عدد ونوع الطرود,"${draftData['qty_pkg'] ?? systemData['packages_count'] ?? ''} طرد"');
    buffer.writeln('وصف البضاعة (Goods Description),"${(draftData['goods_description'] ?? systemData['goods_description'] ?? '').replaceAll('"', '""')}"');
    buffer.writeln('الوزن القائم الإجمالي (Gross Weight KG),${draftData['total_gross_weight_kg'] ?? systemData['total_gross_weight_kg'] ?? 0.0}');
    buffer.writeln('الوزن الصافي الإجمالي (Net Weight KG),${draftData['total_net_weight_kg'] ?? systemData['total_net_weight_kg'] ?? 0.0}');
    buffer.writeln('الحجم الإجمالي (Measurement CBM),${draftData['cbm'] ?? systemData['cbm'] ?? 0.0}');
    buffer.writeln('');

    buffer.writeln('تاريخ التصدير,${DateTime.now().toIso8601String()}');

    final filename = 'Draft Bill of Lading - ${blNo.toString().replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_')}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'حفظ مسودة البوليصة بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  /// Exports and Saves Draft B/L PDF directly to a file chosen by the user
  static Future<String?> saveDraftBLPdfToFile({
    BuildContext? context,
    required Map<String, dynamic> systemData,
    required Map<String, dynamic> draftData,
    String? draftBlNumber,
    String? bookingNumber,
    String? documentTitle,
  }) async {
    final pdf = await generateDraftBLPdf(
      systemData: systemData,
      draftData: draftData,
      draftBlNumber: draftBlNumber,
      bookingNumber: bookingNumber,
      documentTitle: documentTitle,
    );

    final blNo = (draftData['draft_bl_number'] ?? draftBlNumber ?? systemData['draft_bl_number'] ?? 'DRAFT_BL')
        .toString()
        .replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_');
    final bytes = await pdf.save();

    if (context == null || !context.mounted) return null;
    return FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: bytes,
      stageName: 'Draft Bill of Lading',
      importFileNameOrCode: blNo,
      extension: 'pdf',
      customDialogTitle: 'حفظ مسودة البوليصة بصيغة PDF',
    );
  }

  static pw.Widget _buildCell(String title, String val, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(4),
        height: 38,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            right: pw.BorderSide(color: PdfColors.black, width: 0.8),
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(val, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTableHead(String title, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            right: pw.BorderSide(color: PdfColors.black, width: 0.8),
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
          ),
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
  }
}
