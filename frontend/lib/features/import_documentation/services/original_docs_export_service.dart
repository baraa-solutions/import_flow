import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/original_documents_collection_model.dart';

/// Dedicated export and printing service for Screen 57:
/// Original Documents Collection & Courier Tracking.
class OriginalDocsExportService {
  static String _cleanTsv(String val) {
    return val.replaceAll('\t', ' ').replaceAll('\r', '').replaceAll('\n', ' ').trim();
  }

  static String _csvQuote(String val) {
    final cleaned = val.replaceAll('\r', '').trim();
    if (cleaned.contains(',') || cleaned.contains('"') || cleaned.contains('\n')) {
      return '"${cleaned.replaceAll('"', '""')}"';
    }
    return cleaned;
  }

  static String getCourierCompanyLabel(BuildContext context, String company) {
    final l = context.l10n;
    switch (company) {
      case 'DHL':
        return l.courierCompanyDhl;
      case 'FedEx':
        return l.courierCompanyFedex;
      case 'Aramex':
        return l.courierCompanyAramex;
      case 'UPS':
        return l.courierCompanyUps;
      case 'Naqel':
        return l.courierCompanyNaqel;
      case 'SMSA':
        return l.courierCompanySmsa;
      case 'Hand Delivery':
        return l.courierCompanyHandDelivery;
      case 'Other':
        return l.courierCompanyOther;
      default:
        return company;
    }
  }

  static String getDocCategoryLabel(BuildContext context, String category) {
    final l = context.l10n;
    switch (category) {
      case 'Commercial':
        return l.docCatCommercial;
      case 'Certificate':
        return l.docCatCertificate;
      case 'Shipping':
        return l.docCatShipping;
      case 'Egypt Import':
        return l.docCatEgyptImport;
      case 'Banking':
        return l.docCatBanking;
      case 'Regulatory':
        return l.docCatRegulatory;
      case 'Other':
        return l.docCatOther;
      default:
        return category;
    }
  }

  static String getResponsiblePartyLabel(BuildContext context, String party) {
    final l = context.l10n;
    switch (party) {
      case 'Supplier':
        return l.partySupplier;
      case 'Freight Forwarder':
        return l.partyFreightForwarder;
      case 'Customs Broker':
        return l.partyCustomsBroker;
      case 'Bank':
        return l.partyBank;
      case 'Importer':
        return l.partyImporter;
      case 'Carrier':
      case 'Shipping Line':
        return l.partyCarrier;
      default:
        return party;
    }
  }

  static String getStatusLabel(BuildContext context, String status) {
    final l = context.l10n;
    switch (status) {
      case 'Verified':
        return l.statusBadgeVerified;
      case 'Received':
        return l.statusBadgeReceived;
      case 'In Transit':
        return l.statusBadgeInTransit;
      case 'Discrepant':
        return l.statusBadgeDiscrepant;
      case 'DRAFT':
        return l.filterStatusDraft;
      case 'PARTIALLY_RECEIVED':
        return l.filterStatusPartiallyReceived;
      case 'FULLY_RECEIVED':
        return l.filterStatusFullyReceived;
      case 'FULLY_VERIFIED':
        return l.filterStatusFullyVerified;
      case 'Pending':
      default:
        return l.statusBadgePending;
    }
  }

  static String getRequirementLabel(BuildContext context, String req) {
    final l = context.l10n;
    switch (req) {
      case 'Yes':
        return l.reqBadgeYes;
      case 'Conditional':
        return l.reqBadgeConditional;
      case 'No':
      default:
        return l.reqBadgeNo;
    }
  }

  // ===========================================================================
  // ACTIVE COLLECTION SESSION EXPORTS
  // ===========================================================================

  /// Builds a plain-text structured dossier for the active collection session
  static String buildDocumentsDossier({
    required BuildContext context,
    required ImportFileModel file,
    required List<OriginalDocumentItemModel> documents,
    required List<CourierEntryModel> couriers,
    OriginalDocumentsCollectionSessionModel? session,
    String notes = '',
    String overrideReason = '',
  }) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final acidLabel = isAr ? 'الرقم المبدئي' : 'ACID';
    final buf = StringBuffer();

    final totalDocs = documents.length;
    final receivedDocs = documents.where((d) => d.isReceived).length;
    final verifiedDocs = documents.where((d) => d.isVerified).length;
    final pendingDocs = totalDocs - receivedDocs;
    final completionPct = totalDocs > 0 ? (verifiedDocs / totalDocs * 100).toStringAsFixed(1) : '0.0';

    buf.writeln('================================================================');
    buf.writeln('${l.originalDocsDossierTitle} — [${file.importFileCode}]');
    buf.writeln('================================================================');
    buf.writeln('${l.colImportFile}: ${file.importFileCode} (${file.primaryNameWithCode})');
    buf.writeln('${l.partyImporter}: ${file.companyName}');
    buf.writeln('${l.partySupplier}: ${file.supplierName}');
    buf.writeln('$acidLabel: ${file.acidNumber ?? "N/A"}');
    if (session != null) {
      buf.writeln('${l.colSessionCode}: ${session.collectionCode}');
      buf.writeln('${l.colDocStatus}: ${getStatusLabel(context, session.status)}');
    }
    buf.writeln('');
    buf.writeln('--- ${l.statReadinessRate}: $completionPct% ---');
    buf.writeln('${l.statTotalRequiredDocs}: $totalDocs | ${l.statReceivedOriginals}: $receivedDocs | ${l.statVerifiedDocs}: $verifiedDocs | ${l.statPendingDocs}: $pendingDocs');
    buf.writeln('');

    // Couriers
    buf.writeln('--- ${l.courierDispatchPackagesHeader} (${couriers.length}) ---');
    if (couriers.isEmpty) {
      buf.writeln(l.noCouriersRegisteredMsg);
    } else {
      for (var i = 0; i < couriers.length; i++) {
        final c = couriers[i];
        final comp = getCourierCompanyLabel(context, c.courierCompany);
        final recStatus = c.isReceived ? l.statusBadgeReceived : l.statusBadgeInTransit;
        buf.writeln('${i + 1}. [$comp] ${c.courierNo} | ${l.dispatchDateField}: ${c.dispatchDate ?? "—"} | $recStatus | ${l.receivedByNameField}: ${c.receivedBy ?? "—"}');
      }
    }
    buf.writeln('');

    // Documents Matrix
    buf.writeln('--- ${l.physicalDocsVerificationMatrixHeader} (${documents.length}) ---');
    for (var i = 0; i < documents.length; i++) {
      final d = documents[i];
      final cat = getDocCategoryLabel(context, d.category);
      final req = getRequirementLabel(context, d.isRequired);
      final party = getResponsiblePartyLabel(context, d.responsibleParty);
      final status = getStatusLabel(context, d.status);
      final awb = (d.courierNo != null && d.courierNo!.isNotEmpty) ? d.courierNo! : '—';
      buf.writeln('${i + 1}. ${d.documentName} [$cat - $req]');
      buf.writeln('   ${l.colResponsibleParty}: $party | ${l.colCourierNo}: $awb | ${l.colDocStatus}: $status');
      buf.writeln('   ${l.colPhysicalReceived}: ${d.isReceived ? "Yes" : "No"} (${d.receivedDate ?? "—"}) | ${l.colVerified}: ${d.isVerified ? "Yes" : "No"} (${d.verificationDate ?? "—"} - ${d.verifiedBy ?? "—"})');
      if (d.remarks != null && d.remarks!.isNotEmpty) {
        buf.writeln('   ${l.colRemarks}: ${d.remarks}');
      }
    }
    buf.writeln('');

    if (notes.isNotEmpty) {
      buf.writeln('--- ${l.sessionNotesLabel} ---');
      buf.writeln(notes);
      buf.writeln('');
    }
    if (overrideReason.isNotEmpty) {
      buf.writeln('--- ${l.overrideReasonLabel} ---');
      buf.writeln(overrideReason);
      buf.writeln('');
    }

    buf.writeln('================================================================');
    buf.writeln('IMPORTFLOW ERP — Phase 4: Original Documents & Courier Hub');
    buf.writeln('================================================================');

    return buf.toString();
  }

  /// Copies structured plain-text dossier of active session to clipboard
  static Future<void> copyDocumentsDossier({
    required BuildContext context,
    required ImportFileModel file,
    required List<OriginalDocumentItemModel> documents,
    required List<CourierEntryModel> couriers,
    OriginalDocumentsCollectionSessionModel? session,
    String notes = '',
    String overrideReason = '',
  }) async {
    final l = context.l10n;
    final text = buildDocumentsDossier(
      context: context,
      file: file,
      documents: documents,
      couriers: couriers,
      session: session,
      notes: notes,
      overrideReason: overrideReason,
    );
    await CopyHelper.copy(context, text, customMessage: l.originalDocsCopiedDossierSuccess);
  }

  /// Exports documents verification matrix as TSV with UTF-8 BOM
  static Future<void> exportDocumentsTsv({
    required BuildContext context,
    required ImportFileModel file,
    required List<OriginalDocumentItemModel> documents,
    required List<CourierEntryModel> couriers,
  }) async {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    // Headers
    buf.writeln([
      l.colCourierNo,
      l.colDocCategory,
      l.colDocName,
      l.colRequirement,
      l.colResponsibleParty,
      l.colPhysicalReceived,
      l.colReceivedDate,
      l.colVerified,
      l.colAuditor,
      l.colDocStatus,
      l.colRemarks,
    ].join('\t'));

    for (final d in documents) {
      buf.writeln([
        _cleanTsv(d.courierNo ?? ''),
        _cleanTsv(getDocCategoryLabel(context, d.category)),
        _cleanTsv(d.documentName),
        _cleanTsv(getRequirementLabel(context, d.isRequired)),
        _cleanTsv(getResponsiblePartyLabel(context, d.responsibleParty)),
        d.isReceived ? 'Yes' : 'No',
        _cleanTsv(d.receivedDate ?? ''),
        d.isVerified ? 'Yes' : 'No',
        _cleanTsv(d.verifiedBy ?? ''),
        _cleanTsv(getStatusLabel(context, d.status)),
        _cleanTsv(d.remarks ?? ''),
      ].join('\t'));
    }

    final tsvContent = buf.toString();
    await CopyHelper.copy(context, tsvContent, customMessage: l.originalDocsCopiedTsvSuccess);
    if (!context.mounted) return;

    final safeCode = file.importFileCode.replaceAll(RegExp(r'[^\w\-]'), '_');
    final filename = 'Original_Docs_${safeCode}_${DateTime.now().millisecondsSinceEpoch}.tsv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: tsvContent,
      defaultFileName: filename,
      dialogTitle: l.originalDocsExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Exports documents verification matrix as unmerged clean CSV with UTF-8 BOM
  static Future<void> exportDocumentsExcel({
    required BuildContext context,
    required ImportFileModel file,
    required List<OriginalDocumentItemModel> documents,
    required List<CourierEntryModel> couriers,
  }) async {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    // Headers
    buf.writeln([
      _csvQuote(l.colCourierNo),
      _csvQuote(l.colDocCategory),
      _csvQuote(l.colDocName),
      _csvQuote(l.colRequirement),
      _csvQuote(l.colResponsibleParty),
      _csvQuote(l.colPhysicalReceived),
      _csvQuote(l.colReceivedDate),
      _csvQuote(l.colVerified),
      _csvQuote(l.colAuditor),
      _csvQuote(l.colDocStatus),
      _csvQuote(l.colRemarks),
    ].join(','));

    for (final d in documents) {
      buf.writeln([
        _csvQuote(d.courierNo ?? ''),
        _csvQuote(getDocCategoryLabel(context, d.category)),
        _csvQuote(d.documentName),
        _csvQuote(getRequirementLabel(context, d.isRequired)),
        _csvQuote(getResponsiblePartyLabel(context, d.responsibleParty)),
        _csvQuote(d.isReceived ? 'Yes' : 'No'),
        _csvQuote(d.receivedDate ?? ''),
        _csvQuote(d.isVerified ? 'Yes' : 'No'),
        _csvQuote(d.verifiedBy ?? ''),
        _csvQuote(getStatusLabel(context, d.status)),
        _csvQuote(d.remarks ?? ''),
      ].join(','));
    }

    final safeCode = file.importFileCode.replaceAll(RegExp(r'[^\w\-]'), '_');
    final filename = 'Original_Docs_${safeCode}_${DateTime.now().millisecondsSinceEpoch}.csv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: buf.toString(),
      defaultFileName: filename,
      dialogTitle: l.originalDocsExportExcelDialogTitle,
      allowedExtensions: ['csv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Generates Vector A4 Landscape PDF with Cairo font and opens print/preview dialog
  static Future<void> printDocumentsPdf({
    required BuildContext context,
    required ImportFileModel file,
    required List<OriginalDocumentItemModel> documents,
    required List<CourierEntryModel> couriers,
    OriginalDocumentsCollectionSessionModel? session,
    String notes = '',
    String overrideReason = '',
  }) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final acidLabel = isAr ? 'الرقم المبدئي' : 'ACID';
    final textDir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final totalDocs = documents.length;
    final verifiedDocs = documents.where((d) => d.isVerified).length;
    final completionPct = totalDocs > 0 ? (verifiedDocs / totalDocs * 100).toStringAsFixed(1) : '0.0';

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        textDirection: textDir,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context ctx) => [
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'IMPORTFLOW ERP — SOROUR LOGISTICS',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      l.originalDocsDossierTitle,
                      style: pw.TextStyle(color: PdfColors.amber300, fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${l.colImportFile}: ${file.primaryNameWithCode}',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    if (session != null)
                      pw.Text(
                        '${l.colSessionCode}: ${session.collectionCode}',
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // File Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${l.partyImporter}: ${file.companyName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('${l.partySupplier}: ${file.supplierName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$acidLabel: ${file.acidNumber ?? "N/A"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey800)),
                      pw.SizedBox(height: 2),
                      pw.Text('${l.statReadinessRate}: $completionPct% ($verifiedDocs / $totalDocs)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.blue300),
                  ),
                  child: pw.Text(
                    session != null ? getStatusLabel(context, session.status) : l.filterStatusDraft,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // Courier Packages Table (if any)
          if (couriers.isNotEmpty) ...[
            pw.Text(
              l.courierDispatchPackagesHeader,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                  children: [
                    _pdfCell(l.courierTrackingNoField, isHeader: true),
                    _pdfCell(l.courierCompanyField, isHeader: true),
                    _pdfCell(l.dispatchDateField, isHeader: true),
                    _pdfCell(l.isReceivedCheckbox, isHeader: true),
                    _pdfCell(l.receivedByNameField, isHeader: true),
                  ],
                ),
                ...couriers.map((c) => pw.TableRow(
                      children: [
                        _pdfCell(c.courierNo),
                        _pdfCell(getCourierCompanyLabel(context, c.courierCompany)),
                        _pdfCell(c.dispatchDate ?? '—'),
                        _pdfCell(c.isReceived ? 'Yes' : 'No'),
                        _pdfCell(c.receivedBy ?? '—'),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 10),
          ],

          // Documents Verification Matrix
          pw.Text(
            l.physicalDocsVerificationMatrixHeader,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(5),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(3),
              5: const pw.FlexColumnWidth(2),
              6: const pw.FlexColumnWidth(2),
              7: const pw.FlexColumnWidth(2),
              8: const pw.FlexColumnWidth(3),
              9: const pw.FlexColumnWidth(4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _pdfCell(l.colCourierNo, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colDocCategory, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colDocName, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colRequirement, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colResponsibleParty, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colPhysicalReceived, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colVerified, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colDocStatus, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colAuditor, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colRemarks, isHeader: true, headerColor: PdfColors.white),
                ],
              ),
              ...documents.map((d) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: d.isVerified ? PdfColors.green50 : PdfColors.white,
                    ),
                    children: [
                      _pdfCell(d.courierNo ?? '—'),
                      _pdfCell(getDocCategoryLabel(context, d.category)),
                      _pdfCell(d.documentName, isBold: true),
                      _pdfCell(getRequirementLabel(context, d.isRequired)),
                      _pdfCell(getResponsiblePartyLabel(context, d.responsibleParty)),
                      _pdfCell(d.isReceived ? 'Yes' : 'No'),
                      _pdfCell(d.isVerified ? 'Yes' : 'No'),
                      _pdfCell(getStatusLabel(context, d.status)),
                      _pdfCell(d.verifiedBy ?? '—'),
                      _pdfCell(d.remarks ?? '—'),
                    ],
                  )),
            ],
          ),

          if (notes.isNotEmpty || overrideReason.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            if (notes.isNotEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text('${l.sessionNotesLabel}: $notes', style: const pw.TextStyle(fontSize: 8)),
              ),
            if (overrideReason.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text('${l.overrideReasonLabel}: $overrideReason', style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Original_Docs_Statement_${file.importFileCode}.pdf',
    );
  }

  static pw.Widget _pdfCell(String text, {bool isHeader = false, bool isBold = false, PdfColor? headerColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: headerColor ?? (isHeader ? PdfColors.blueGrey900 : PdfColors.black),
        ),
      ),
    );
  }

  // ===========================================================================
  // SESSIONS REGISTRY EXPORTS
  // ===========================================================================

  /// Builds a plain-text dossier of all visible sessions in registry
  static String buildRegistryDossier({
    required BuildContext context,
    required List<OriginalDocumentsCollectionSessionModel> sessions,
    List<ImportFileModel>? shipments,
  }) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final acidLabel = isAr ? 'الرقم المبدئي' : 'ACID';
    final buf = StringBuffer();

    buf.writeln('================================================================');
    buf.writeln('${l.originalDocsRegistryDossierTitle} (${sessions.length})');
    buf.writeln('================================================================');
    buf.writeln('');

    for (var i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      final status = getStatusLabel(context, s.status);
      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        s.importFileCode,
        shipments: shipments,
        isArabic: isAr,
      );
      buf.writeln('${i + 1}. [${s.collectionCode}] — $shipmentTitle ($status)');
      buf.writeln('   $acidLabel: ${s.acidNumber ?? "—"} | ${l.partySupplier}: ${s.supplierName ?? "—"}');
      buf.writeln('   ${l.colTotalDocs}: ${s.totalDocumentsCount} | ${l.colReceivedDocs}: ${s.receivedDocumentsCount} | ${l.colVerifiedDocs}: ${s.verifiedDocumentsCount} | ${l.colCompletionPercentage}: ${s.completionPercentage}%');
      buf.writeln('   ${l.colUpdatedAt}: ${s.updatedAt.toIso8601String().substring(0, 16).replaceAll("T", " ")}');
      buf.writeln('');
    }

    buf.writeln('================================================================');
    buf.writeln('IMPORTFLOW ERP — Originals Collection Sessions Registry');
    buf.writeln('================================================================');

    return buf.toString();
  }

  /// Copies registry dossier to clipboard
  static Future<void> copyRegistryDossier({
    required BuildContext context,
    required List<OriginalDocumentsCollectionSessionModel> sessions,
    List<ImportFileModel>? shipments,
  }) async {
    final l = context.l10n;
    final text = buildRegistryDossier(context: context, sessions: sessions, shipments: shipments);
    await CopyHelper.copy(context, text, customMessage: l.originalDocsRegistryCopiedSuccess);
  }

  /// Exports sessions registry as TSV with UTF-8 BOM
  static Future<void> exportRegistryTsv({
    required BuildContext context,
    required List<OriginalDocumentsCollectionSessionModel> sessions,
    List<ImportFileModel>? shipments,
  }) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    // Headers
    buf.writeln([
      l.colSessionCode,
      l.colImportFile,
      l.colAcidNumber,
      l.colSupplierName,
      l.colTotalDocs,
      l.colReceivedDocs,
      l.colVerifiedDocs,
      l.colCompletionPercentage,
      l.colDocStatus,
      l.colUpdatedAt,
    ].join('\t'));

    for (final s in sessions) {
      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        s.importFileCode,
        shipments: shipments,
        isArabic: isAr,
      );
      buf.writeln([
        _cleanTsv(s.collectionCode),
        _cleanTsv(shipmentTitle),
        _cleanTsv(s.acidNumber ?? ''),
        _cleanTsv(s.supplierName ?? ''),
        s.totalDocumentsCount.toString(),
        s.receivedDocumentsCount.toString(),
        s.verifiedDocumentsCount.toString(),
        '${s.completionPercentage}%',
        _cleanTsv(getStatusLabel(context, s.status)),
        s.updatedAt.toIso8601String().substring(0, 16).replaceAll('T', ' '),
      ].join('\t'));
    }

    final tsvContent = buf.toString();
    await CopyHelper.copy(context, tsvContent, customMessage: l.originalDocsCopiedTsvSuccess);
    if (!context.mounted) return;

    final filename = 'Original_Docs_Registry_${DateTime.now().millisecondsSinceEpoch}.tsv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: tsvContent,
      defaultFileName: filename,
      dialogTitle: l.originalDocsExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Exports sessions registry as unmerged clean CSV with UTF-8 BOM
  static Future<void> exportRegistryExcel({
    required BuildContext context,
    required List<OriginalDocumentsCollectionSessionModel> sessions,
    List<ImportFileModel>? shipments,
  }) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    // Headers
    buf.writeln([
      _csvQuote(l.colSessionCode),
      _csvQuote(l.colImportFile),
      _csvQuote(l.colAcidNumber),
      _csvQuote(l.colSupplierName),
      _csvQuote(l.colTotalDocs),
      _csvQuote(l.colReceivedDocs),
      _csvQuote(l.colVerifiedDocs),
      _csvQuote(l.colCompletionPercentage),
      _csvQuote(l.colDocStatus),
      _csvQuote(l.colUpdatedAt),
    ].join(','));

    for (final s in sessions) {
      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        s.importFileCode,
        shipments: shipments,
        isArabic: isAr,
      );
      buf.writeln([
        _csvQuote(s.collectionCode),
        _csvQuote(shipmentTitle),
        _csvQuote(s.acidNumber ?? ''),
        _csvQuote(s.supplierName ?? ''),
        s.totalDocumentsCount.toString(),
        s.receivedDocumentsCount.toString(),
        s.verifiedDocumentsCount.toString(),
        '${s.completionPercentage}%',
        _csvQuote(getStatusLabel(context, s.status)),
        s.updatedAt.toIso8601String().substring(0, 16).replaceAll('T', ' '),
      ].join(','));
    }

    final filename = 'Original_Docs_Registry_${DateTime.now().millisecondsSinceEpoch}.csv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: buf.toString(),
      defaultFileName: filename,
      dialogTitle: l.originalDocsExportExcelDialogTitle,
      allowedExtensions: ['csv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Generates vector A4 landscape PDF of sessions registry
  static Future<void> printRegistryPdf({
    required BuildContext context,
    required List<OriginalDocumentsCollectionSessionModel> sessions,
    List<ImportFileModel>? shipments,
  }) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final acidLabel = isAr ? 'الرقم المبدئي' : 'ACID';
    final textDir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        textDirection: textDir,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context ctx) => [
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'IMPORTFLOW ERP — SOROUR LOGISTICS',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      l.originalDocsRegistryDossierTitle,
                      style: pw.TextStyle(color: PdfColors.amber300, fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Text(
                  '${sessions.length} ${l.colSessionCode}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Registry Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _pdfCell(l.colSessionCode, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colImportFile, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(acidLabel, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.partySupplier, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colTotalDocs, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colReceivedDocs, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colVerifiedDocs, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colCompletionPercentage, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colDocStatus, isHeader: true, headerColor: PdfColors.white),
                  _pdfCell(l.colUpdatedAt, isHeader: true, headerColor: PdfColors.white),
                ],
              ),
              ...sessions.map((s) {
                final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
                  s.importFileCode,
                  shipments: shipments,
                  isArabic: isAr,
                );
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: s.completionPercentage == 100 ? PdfColors.green50 : PdfColors.white,
                  ),
                  children: [
                    _pdfCell(s.collectionCode, isBold: true),
                    _pdfCell(shipmentTitle),
                    _pdfCell(s.acidNumber ?? '—'),
                    _pdfCell(s.supplierName ?? '—'),
                    _pdfCell('${s.totalDocumentsCount}'),
                    _pdfCell('${s.receivedDocumentsCount}'),
                    _pdfCell('${s.verifiedDocumentsCount}'),
                    _pdfCell('${s.completionPercentage}%'),
                    _pdfCell(getStatusLabel(context, s.status)),
                    _pdfCell(s.updatedAt.toIso8601String().substring(0, 16).replaceAll('T', ' ')),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Original_Docs_Registry_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Returns [raw] as a [Uri] only when it is an absolute http/https URL.
  /// Anything else (other schemes, relative, malformed) yields null.
  static Uri? safeHttpUri(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    return uri;
  }

  /// Builds the carrier tracking URL. Company and AWB are user input, so they
  /// are always percent-encoded before being placed in the query/URL.
  static String buildCarrierTrackingUrl(String company, String awb) {
    final cleanAwb = Uri.encodeQueryComponent(awb.trim());
    final c = company.toUpperCase();
    if (c.contains('DHL')) {
      return 'https://www.dhl.com/en/express/tracking.html?AWB=$cleanAwb';
    } else if (c.contains('FEDEX')) {
      return 'https://www.fedex.com/fedextrack/?trknbr=$cleanAwb';
    } else if (c.contains('ARAMEX')) {
      return 'https://www.aramex.com/track/results?mode=0&ShipmentNumber=$cleanAwb';
    } else if (c.contains('UPS')) {
      return 'https://www.ups.com/track?tracknum=$cleanAwb';
    } else if (c.contains('NAQEL')) {
      return 'https://www.naqelexpress.com/tracking?trackNumbers=$cleanAwb';
    } else if (c.contains('SMSA')) {
      return 'https://www.smsaexpress.com/track?trackNumber=$cleanAwb';
    }
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent('${company.trim()} ${awb.trim()} tracking')}';
  }

  /// Opens [url] in the default browser. Only validated http/https URIs are
  /// launched, without a shell (no command injection). Returns false when the
  /// URL was rejected or the launch failed.
  static Future<bool> openExternalUrl(String url) async {
    final uri = safeHttpUri(url);
    if (uri == null) return false;
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [uri.toString()], runInShell: false);
        return true;
      }
    } catch (e) {
      debugPrint('Error launching external URL: $e');
    }
    return false;
  }

  static Future<bool> launchCarrierTracking(String company, String awb) {
    return openExternalUrl(buildCarrierTrackingUrl(company, awb));
  }
}
