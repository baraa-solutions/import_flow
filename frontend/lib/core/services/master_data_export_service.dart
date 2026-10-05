import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'file_save_helper.dart';

import '../../features/import_companies/models/import_company_model.dart';
import '../../features/suppliers/models/supplier_model.dart';
import '../../features/external_service_providers/models/partner_model.dart';
import '../../features/incoterms/models/incoterm_model.dart';
import '../../features/customs_tariff/models/customs_tariff_model.dart';
import '../../features/transport_locations/models/transport_location_model.dart';
import '../../features/currencies/models/currency_model.dart';
import '../../features/audit_logs/models/audit_log_model.dart';
import '../../features/smart_tasks/models/smart_task_model.dart';
import '../../features/import_files/models/import_file_model.dart';
import '../../features/shipment_updates/models/shipment_update_model.dart';
import '../../features/import_requirements/models/import_requirement_model.dart';
import '../../features/demurrage_detention/models/demurrage_model.dart';

class MasterDataExportService {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. EGYPTIAN IMPORT COMPANIES (الشركات المستوردة)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> printOrSaveImporterPdf(ImportCompanyModel company) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final vatStatus = company.daysUntilVatExpiry > 0 ? 'سارية (${company.daysUntilVatExpiry} يوم)' : 'منتهية الصلاحية';
    final regStatus = company.daysUntilRegExpiry > 0 ? 'سارٍ (${company.daysUntilRegExpiry} يوم)' : 'منتهي الصلاحية';
    final impStatus = company.daysUntilImporterIdExpiry > 0 ? 'سارية (${company.daysUntilImporterIdExpiry} يوم)' : 'منتهية الصلاحية';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP — بطاقة بيانات الشركة المستوردة',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'وثيقة رسمية ببيانات التسجيل والقيد التجاري والضريبي',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: company.isActive ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#C0392B'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          company.isActive ? 'سجل نشط (Active)' : 'غير مفعّل (Inactive)',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Main Details Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        company.importerName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('#2C3E50')),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('الدولة: ${company.country.isNotEmpty ? company.country : "جمهورية مصر العربية"}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('العنوان: ${company.address}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                      if (company.phone != null || company.email != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Expanded(child: pw.Text('الهاتف: ${company.phone ?? "-"}', style: const pw.TextStyle(fontSize: 10))),
                            pw.Expanded(child: pw.Text('البريد الإلكتروني: ${company.email ?? "-"}', style: const pw.TextStyle(fontSize: 10))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Registration & Expiry Table
                pw.Text('بيانات القيد والتراخيص الرسمية والرقابية:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#2C3E50'))),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#3498DB')),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('البيان / المستند الرقابي', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('رقم القيد / التسجيل', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('تاريخ الانتهاء', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('حالة السريان', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('البطاقة الاستيرادية (Importer Card)', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(company.importerId, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(company.importerIdExpiry.toIso8601String().split('T')[0], style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(impStatus, style: pw.TextStyle(fontSize: 9, color: company.daysUntilImporterIdExpiry > 0 ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#C0392B'), fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('البطاقة الضريبية (VAT / Tax ID)', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(company.vatId, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(company.vatIdExpiry.toIso8601String().split('T')[0], style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(vatStatus, style: pw.TextStyle(fontSize: 9, color: company.daysUntilVatExpiry > 0 ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#C0392B'), fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('السجل التجاري (Commercial Register)', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(company.registrationNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(company.registrationExpiry.toIso8601String().split('T')[0], style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(regStatus, style: pw.TextStyle(fontSize: 9, color: company.daysUntilRegExpiry > 0 ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#C0392B'), fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                  ],
                ),

                if (company.notes != null && company.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text('ملاحظات الشركة: ${company.notes}', style: const pw.TextStyle(fontSize: 9)),
                  ),
                ],

                pw.Spacer(),

                // Sign-off
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 19)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Sorour Logistics ERP Enterprise System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'MasterData_Import_Companies_${company.importerId}',
    );
  }

  static Future<String?> exportImporterToExcel(BuildContext context, ImportCompanyModel company) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM

    buffer.writeln('Sorour Logistics ERP — بطاقة بيانات الشركة المستوردة');
    buffer.writeln('اسم الشركة المستوردة,"${company.importerName.replaceAll('"', '""')}"');
    buffer.writeln('حالة السجل,${company.isActive ? "نشط" : "غير نشط"}');
    buffer.writeln('الدولة,${company.country}');
    buffer.writeln('العنوان,"${company.address.replaceAll('"', '""')}"');
    buffer.writeln('الهاتف,${company.phone ?? "-"}');
    buffer.writeln('البريد الإلكتروني,${company.email ?? "-"}');
    buffer.writeln('');

    buffer.writeln('--- بيانات القيد والتسجيلات الرسمية ---');
    buffer.writeln('المستند,رقم القيد,تاريخ الانتهاء,الأيام المتبقية,الحالة');
    buffer.writeln('البطاقة الاستيرادية,${company.importerId},${company.importerIdExpiry.toIso8601String().split('T')[0]},${company.daysUntilImporterIdExpiry},${company.daysUntilImporterIdExpiry > 0 ? "سارية" : "منتهية"}');
    buffer.writeln('البطاقة الضريبية,${company.vatId},${company.vatIdExpiry.toIso8601String().split('T')[0]},${company.daysUntilVatExpiry},${company.daysUntilVatExpiry > 0 ? "سارية" : "منتهية"}');
    buffer.writeln('السجل التجاري,${company.registrationNumber},${company.registrationExpiry.toIso8601String().split('T')[0]},${company.daysUntilRegExpiry},${company.daysUntilRegExpiry > 0 ? "سارٍ" : "منتهٍ"}');

    if (company.notes != null && company.notes!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('الملاحظات,"${company.notes!.replaceAll('"', '""')}"');
    }

    final filename = 'MasterData_Import_Companies_${company.importerId}_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'حفظ بيانات الشركة المستوردة بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generateImporterWhatsAppText(ImportCompanyModel comp) {
    return '''
*Sorour Logistics ERP — بطاقة الشركة المستوردة*
🏢 *اسم الشركة:* ${comp.importerName}
📍 *العنوان:* ${comp.address}
🇪🇬 *الدولة:* ${comp.country.isNotEmpty ? comp.country : "مصر"}
📞 *الهاتف:* ${comp.phone ?? "-"}
📧 *الإيميل:* ${comp.email ?? "-"}

*📋 بيانات القيد والتراخيص:*
• *البطاقة الاستيرادية:* ${comp.importerId} (انتهاء: ${comp.importerIdExpiry.toIso8601String().split('T')[0]})
• *البطاقة الضريبية:* ${comp.vatId} (انتهاء: ${comp.vatIdExpiry.toIso8601String().split('T')[0]})
• *السجل التجاري:* ${comp.registrationNumber} (انتهاء: ${comp.registrationExpiry.toIso8601String().split('T')[0]})
• *الحالة:* ${comp.isActive ? "✅ نشط" : "❌ غير نشط"}
${comp.notes != null && comp.notes!.isNotEmpty ? "📝 *ملاحظات:* ${comp.notes}\n" : ""}
_تم الإنشاء عبر Sorour Logistics ERP_
'''.trim();
  }

  static String generateImporterEmailSubject(ImportCompanyModel comp) {
    return 'بيانات الشركة المستوردة [${comp.importerId}] - ${comp.importerName}';
  }

  static String generateImporterEmailBody(ImportCompanyModel comp) {
    return '''
تحية طيبة وبعد،،،

مرفق لسيادتكم بيان ببيانات الشركة المستوردة والتراخيص الرقابية المسجلة على النظام:

- اسم الشركة: ${comp.importerName}
- الدولة: ${comp.country.isNotEmpty ? comp.country : "مصر"}
- العنوان: ${comp.address}
- الهاتف: ${comp.phone ?? "-"}
- البريد الإلكتروني: ${comp.email ?? "-"}

بيانات التسجيل والقيد:
- رقم البطاقة الاستيرادية: ${comp.importerId} (تاريخ الانتهاء: ${comp.importerIdExpiry.toIso8601String().split('T')[0]})
- رقم البطاقة الضريبية: ${comp.vatId} (تاريخ الانتهاء: ${comp.vatIdExpiry.toIso8601String().split('T')[0]})
- رقم السجل التجاري: ${comp.registrationNumber} (تاريخ الانتهاء: ${comp.registrationExpiry.toIso8601String().split('T')[0]})
- حالة السجل: ${comp.isActive ? "نشط ومفعّل" : "غير مفعّل"}

شاكرين حسن تعاونكم،،،
فريق العمليات وإدارة الاستيراد
Sorour Logistics ERP
'''.trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. FOREIGN SUPPLIERS (الموردون الأجانب)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> printOrSaveSupplierPdf(SupplierModel supplier) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP — بطاقة تعريف المورد الأجنبي',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Foreign Exporter Profile & Nafeza/CargoX Registration',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#3498DB'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          supplier.supplierCode,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Main Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(supplier.companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('دولة المصدر: ${supplier.foreignExporterCountry} (${supplier.foreignExporterCountryCode.toUpperCase()})', style: const pw.TextStyle(fontSize: 9))),
                          pw.Expanded(child: pw.Text('نوع المورد: ${supplier.supplierType} (${supplier.registrationType})', style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('العنوان: ${supplier.address}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Platforms & Registrations
                pw.Text('بيانات التسجيل في منصات نافذة وكارجو إكس (Nafeza & CargoX):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#2C3E50'))),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E67E22')),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('المنصة / المعرّف الرقابي', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('القيمة / الكود المسجل', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('معرّف المصدر الأجنبي (Foreign Exporter ID)', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(supplier.foreignExporterId, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('معرّف منصة كارجو إكس (CargoX Platform ID)', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(supplier.cargoxPlatformId ?? "غير مسجل", style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('التسجيل بالقرار 43 / القائمة البيضاء', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${supplier.registeredDecree43 ? "مسجل بقرار 43" : "غير مسجل"} | ${supplier.whiteListRegistered ? "قائمة بيضاء" : "عادي"} | ${supplier.hasIso ? "حاصل على ISO" : "بدون ISO"}', style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Bank Details
                pw.Text('بيانات التحويل البنكي والسويفت (Beneficiary Bank & SWIFT):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#2C3E50'))),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F9F9'),
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('اسم البنك: ${supplier.bankName ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                          pw.Expanded(child: pw.Text('كود السويفت: ${supplier.swiftCode ?? "-"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#2980B9')))),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('رقم الحساب: ${supplier.accountNumber ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                          pw.Expanded(child: pw.Text('IBAN: ${supplier.iban ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Contact & Brands
                pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text('الهاتف: ${supplier.phone ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                    pw.Expanded(child: pw.Text('البريد الإلكتروني: ${supplier.email ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                  ],
                ),
                if (supplier.brands != null && supplier.brands!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('العلامات التجارية والمنتجات: ${supplier.brands}', style: const pw.TextStyle(fontSize: 9)),
                ],

                pw.Spacer(),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 19)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Sorour Logistics ERP Enterprise System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'MasterData_Suppliers_${supplier.supplierCode}',
    );
  }

  static Future<String?> exportSupplierToExcel(BuildContext context, SupplierModel supplier) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln('Sorour Logistics ERP — بطاقة تعريف وبيانات المورد الأجنبي');
    buffer.writeln('كود المورد,${supplier.supplierCode}');
    buffer.writeln('اسم المورد الأجنبي,"${supplier.companyName.replaceAll('"', '""')}"');
    buffer.writeln('دولة المصدر,${supplier.foreignExporterCountry}');
    buffer.writeln('كود الدولة,${supplier.foreignExporterCountryCode}');
    buffer.writeln('نوع المورد,${supplier.supplierType}');
    buffer.writeln('نوع التسجيل,${supplier.registrationType}');
    buffer.writeln('معرّف المصدر (Foreign Exporter ID),${supplier.foreignExporterId}');
    buffer.writeln('معرّف منصة CargoX,${supplier.cargoxPlatformId ?? "-"}');
    buffer.writeln('حالة السجل,${supplier.isActive ? "نشط" : "غير نشط"}');
    buffer.writeln('العنوان,"${supplier.address.replaceAll('"', '""')}"');
    buffer.writeln('الهاتف,${supplier.phone ?? "-"}');
    buffer.writeln('الموبايل,${supplier.mobile ?? "-"}');
    buffer.writeln('البريد الإلكتروني,${supplier.email ?? "-"}');
    buffer.writeln('الموقع الإلكتروني,${supplier.website ?? "-"}');
    buffer.writeln('');

    buffer.writeln('--- بيانات التحويل البنكي والسويفت ---');
    buffer.writeln('اسم البنك,"${(supplier.bankName ?? "-").replaceAll('"', '""')}"');
    buffer.writeln('كود السويفت (SWIFT),${supplier.swiftCode ?? "-"}');
    buffer.writeln('رقم الحساب,${supplier.accountNumber ?? "-"}');
    buffer.writeln('IBAN,${supplier.iban ?? "-"}');
    buffer.writeln('');

    buffer.writeln('--- الامتثال والعلامات التجارية ---');
    buffer.writeln('شهادة ISO,${supplier.hasIso ? "نعم" : "لا"}');
    buffer.writeln('مسجل بقرار 43,${supplier.registeredDecree43 ? "نعم" : "لا"}');
    buffer.writeln('قائمة بيضاء,${supplier.whiteListRegistered ? "نعم" : "لا"}');
    buffer.writeln('العلامات والبراندات,"${(supplier.brands ?? "-").replaceAll('"', '""')}"');

    final filename = 'MasterData_Suppliers_${supplier.supplierCode}_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'حفظ بيانات المورد الأجنبي بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generateSupplierWhatsAppText(SupplierModel sup) {
    return '''
*Sorour Logistics ERP — بطاقة المورد الأجنبي*
🏢 *كود المورد:* ${sup.supplierCode}
🌐 *اسم الشركة:* ${sup.companyName}
🌍 *الدولة:* ${sup.foreignExporterCountry} (${sup.foreignExporterCountryCode.toUpperCase()})
🔖 *النوع:* ${sup.supplierType} (${sup.registrationType})
🆔 *معرف المصدر (نافذة):* ${sup.foreignExporterId}
${sup.cargoxPlatformId != null && sup.cargoxPlatformId!.isNotEmpty ? "📦 *CargoX ID:* ${sup.cargoxPlatformId}\n" : ""}
*🏦 بيانات البنك والتحويل:*
• *البنك:* ${sup.bankName ?? "-"}
• *SWIFT:* ${sup.swiftCode ?? "-"}
• *Account / IBAN:* ${sup.iban ?? sup.accountNumber ?? "-"}

*📞 التواصل:*
• *الهاتف:* ${sup.phone ?? sup.mobile ?? "-"}
• *الإيميل:* ${sup.email ?? "-"}
${sup.brands != null && sup.brands!.isNotEmpty ? "🏷️ *البراندات:* ${sup.brands}\n" : ""}
_تم الإنشاء عبر Sorour Logistics ERP_
'''.trim();
  }

  static String generateSupplierEmailSubject(SupplierModel sup) {
    return 'بيانات المورد الأجنبي [${sup.supplierCode}] - ${sup.companyName}';
  }

  static String generateSupplierEmailBody(SupplierModel sup) {
    return '''
تحية طيبة وبعد،،،

مرفق لسيادتكم بطاقة تعريف وبيانات المورد الأجنبي المسجلة على النظام:

- كود المورد: ${sup.supplierCode}
- اسم الشركة: ${sup.companyName}
- الدولة: ${sup.foreignExporterCountry} (${sup.foreignExporterCountryCode})
- نوع المورد: ${sup.supplierType} (${sup.registrationType})
- العنوان: ${sup.address}

بيانات نافذة وكارجو إكس:
- Foreign Exporter ID: ${sup.foreignExporterId}
- CargoX ID: ${sup.cargoxPlatformId ?? "غير مسجل"}

بيانات البنك والتحويلات المالية:
- اسم البنك: ${sup.bankName ?? "-"}
- كود السويفت (SWIFT): ${sup.swiftCode ?? "-"}
- رقم الحساب / IBAN: ${sup.iban ?? sup.accountNumber ?? "-"}

بيانات الاتصال:
- الهاتف: ${sup.phone ?? sup.mobile ?? "-"}
- البريد الإلكتروني: ${sup.email ?? "-"}
- الموقع الإلكتروني: ${sup.website ?? "-"}

شاكرين حسن تعاونكم،،،
فريق العمليات وإدارة الاستيراد
Sorour Logistics ERP
'''.trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. PARTNERS & SERVICE PROVIDERS & BANKS (الشركاء والبنوك ومقدمو الخدمات)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> printOrSavePartnerPdf(PartnerModel partner) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP — بطاقة الشريك ومقدم الخدمات اللوجستية',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'وثيقة رسمية ببيانات الشريك ومقدم الخدمات اللوجستية',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#27AE60'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          partner.partnerCode,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Main Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(partner.partnerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('التصنيف والخدمات: ${partner.partnerType}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2980B9'), fontSize: 9))),
                          pw.Expanded(child: pw.Text('الدولة: ${partner.country}', style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('العنوان: ${partner.address ?? "-"}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Professional Identifiers
                pw.Text('الرخص والأكواد والبيانات المهنية:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#2C3E50'))),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#3498DB')),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('البيان الرقابي / المهني', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('القيمة / الكود', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      ],
                    ),
                    if (partner.swiftCode != null && partner.swiftCode!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('كود السويفت البنكي', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(partner.swiftCode!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        ],
                      ),
                    if (partner.scacCode != null && partner.scacCode!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('كود الناقل الملاحي', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(partner.scacCode!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        ],
                      ),
                    if (partner.clearanceLicenseNumber != null && partner.clearanceLicenseNumber!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('رقم رخصة التخليص الجمركي', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(partner.clearanceLicenseNumber!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        ],
                      ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('السجل التجاري والبطاقة الضريبية', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('س.ت: ${partner.commercialRegister ?? "-"} | ضريبي: ${partner.taxId ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('شروط السداد والحد الائتماني', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('نوع السداد: ${partner.paymentType} | الحد: ${partner.creditLimit} ج.م', style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Contact Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('بيانات التواصل ومسؤول الحساب:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('المسؤول: ${partner.contactPerson ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                          pw.Expanded(child: pw.Text('الهاتف: ${partner.phone ?? partner.mobile ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('البريد الإلكتروني: ${partner.email ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                          pw.Expanded(child: pw.Text('الموقع الإلكتروني: ${partner.website ?? "-"}', style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 19)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Sorour Logistics ERP Enterprise System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'MasterData_Partners_${partner.partnerCode}',
    );
  }

  static Future<String?> exportPartnerToExcel(BuildContext context, PartnerModel partner) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln('Sorour Logistics ERP — بطاقة بيانات الشريك ومقدم الخدمات');
    buffer.writeln('كود الشريك,${partner.partnerCode}');
    buffer.writeln('اسم الشريك / البنك,"${partner.partnerName.replaceAll('"', '""')}"');
    buffer.writeln('تصنيف الخدمات,"${partner.partnerType.replaceAll('"', '""')}"');
    buffer.writeln('الدولة,${partner.country}');
    buffer.writeln('كود السويفت (SWIFT),${partner.swiftCode ?? "-"}');
    buffer.writeln('كود الناقل الملاحي,${partner.scacCode ?? "-"}');
    buffer.writeln('رقم رخصة التخليص,${partner.clearanceLicenseNumber ?? "-"}');
    buffer.writeln('السجل التجاري,${partner.commercialRegister ?? "-"}');
    buffer.writeln('البطاقة الضريبية,${partner.taxId ?? "-"}');
    buffer.writeln('نوع السداد,${partner.paymentType}');
    buffer.writeln('الحد الائتماني,${partner.creditLimit}');
    buffer.writeln('المسؤول الاتصال,${partner.contactPerson ?? "-"}');
    buffer.writeln('الهاتف,${partner.phone ?? "-"}');
    buffer.writeln('الموبايل,${partner.mobile ?? "-"}');
    buffer.writeln('البريد الإلكتروني,${partner.email ?? "-"}');
    buffer.writeln('الموقع الإلكتروني,${partner.website ?? "-"}');
    buffer.writeln('العنوان,"${(partner.address ?? "-").replaceAll('"', '""')}"');
    buffer.writeln('حالة السجل,${partner.isActive ? "نشط" : "غير نشط"}');

    final filename = 'MasterData_Partners_${partner.partnerCode}_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'حفظ بيانات الشريك بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generatePartnerWhatsAppText(PartnerModel p) {
    return '''
*Sorour Logistics ERP — بطاقة الشريك ومقدم الخدمات*
🤝 *كود الشريك:* ${p.partnerCode}
🏢 *اسم الشريك:* ${p.partnerName}
📋 *التصنيف:* ${p.partnerType}
🌍 *الدولة:* ${p.country}
${p.swiftCode != null && p.swiftCode!.isNotEmpty ? "🏦 *السويفت:* ${p.swiftCode}\n" : ""}${p.scacCode != null && p.scacCode!.isNotEmpty ? "🚢 *كود الناقل:* ${p.scacCode}\n" : ""}${p.clearanceLicenseNumber != null && p.clearanceLicenseNumber!.isNotEmpty ? "📜 *رخصة التخليص:* ${p.clearanceLicenseNumber}\n" : ""}
*📞 بيانات التواصل:*
• *المسؤول:* ${p.contactPerson ?? "-"}
• *الهاتف:* ${p.phone ?? p.mobile ?? "-"}
• *الإيميل:* ${p.email ?? "-"}
• *نوع السداد:* ${p.paymentType} (الحد: ${p.creditLimit} ج.م)
• *الحالة:* ${p.isActive ? "✅ نشط" : "❌ غير نشط"}
_تم الإنشاء عبر Sorour Logistics ERP_
'''.trim();
  }

  static String generatePartnerEmailSubject(PartnerModel p) {
    return 'بيانات الشريك أو البنك [${p.partnerCode}] - ${p.partnerName}';
  }

  static String generatePartnerEmailBody(PartnerModel p) {
    return '''
تحية طيبة وبعد،،،

مرفق لسيادتكم بطاقة تعريف وبيانات الشريك ومقدم الخدمة المسجل على النظام:

- كود الشريك: ${p.partnerCode}
- اسم الشريك: ${p.partnerName}
- التصنيف: ${p.partnerType}
- الدولة: ${p.country}
- العنوان: ${p.address ?? "-"}

الأكواد والتراخيص:
- كود السويفت: ${p.swiftCode ?? "-"}
- كود الخط الملاحي: ${p.scacCode ?? "-"}
- ترخيص التخليص: ${p.clearanceLicenseNumber ?? "-"}
- السجل التجاري: ${p.commercialRegister ?? "-"}
- البطاقة الضريبية: ${p.taxId ?? "-"}

بيانات التواصل والائتمان:
- مسؤول الحساب: ${p.contactPerson ?? "-"}
- الهاتف: ${p.phone ?? p.mobile ?? "-"}
- البريد الإلكتروني: ${p.email ?? "-"}
- نوع السداد: ${p.paymentType} (الحد الائتماني: ${p.creditLimit} ج.م)

شاكرين حسن تعاونكم،،،
فريق العمليات وإدارة الاستيراد
Sorour Logistics ERP
'''.trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. INCOTERMS RULES & RESPONSIBILITY MATRIX (MD-006)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> printOrSaveIncotermPdf(
    IncotermModel incoterm,
    List<IncotermResponsibilityModel> responsibilities,
  ) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final termResponsibilities = responsibilities
        .where((r) => r.incotermId == incoterm.incotermId || r.incotermCode == incoterm.incotermCode)
        .toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP — بطاقة تعريف شرط التجارة الدولي',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'معيار الغرفة التجارية الدولية وتوزيع التكاليف والمخاطر',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#3498DB'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          incoterm.incotermCode,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Main Info Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            incoterm.incotermName,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('#2C3E50')),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: incoterm.isActive ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#C0392B'),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              incoterm.isActive ? 'مفعّل ونشط' : 'متوقف وغير مفعّل',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('الإصدار المعتمد: ${incoterm.version}', style: const pw.TextStyle(fontSize: 10)),
                      if (incoterm.description != null && incoterm.description!.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('نقطة انتقال المخاطر والمسؤولية: ${incoterm.description}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Responsibilities Table
                pw.Text(
                  'مصفوفة توزيع بنود التكلفة والمسؤوليات التعاقدية:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#2C3E50')),
                ),
                pw.SizedBox(height: 6),
                if (termResponsibilities.isEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text('لا توجد بنود تكلفة محددة مسجلة لهذا الشرط.', style: const pw.TextStyle(fontSize: 9)),
                  )
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#3498DB')),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('بند التكلفة', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('التصنيف', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('الجهة المسؤولة', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('مدرج بسعر الفاتورة', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('ملاحظات', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        ],
                      ),
                      ...termResponsibilities.map((r) {
                        String partyLabel;
                        switch (r.responsibleParty) {
                          case 'Importer':
                            partyLabel = 'المشتري (المستورد)';
                            break;
                          case 'Exporter':
                            partyLabel = 'البائع (المورد)';
                            break;
                          default:
                            partyLabel = 'مشترك بين الطرفين';
                        }
                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r.costItemName ?? '—', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r.costCategory ?? '—', style: const pw.TextStyle(fontSize: 8))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(partyLabel, style: const pw.TextStyle(fontSize: 8))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r.includedInIncoterm ? 'نعم (مدرج)' : 'لا (غير مدرج)', style: const pw.TextStyle(fontSize: 8))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r.notes ?? '—', style: const pw.TextStyle(fontSize: 8))),
                          ],
                        );
                      }),
                    ],
                  ),

                pw.Spacer(),

                // Sign-off
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تاريخ الطباعة: ${DateTime.now().toString().substring(0, 19)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('Sorour Logistics ERP Enterprise System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'MasterData_Incoterm_${incoterm.incotermCode}',
    );
  }

  static Future<String?> exportIncotermToExcel(
    BuildContext context,
    IncotermModel incoterm,
    List<IncotermResponsibilityModel> responsibilities,
  ) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln('Sorour Logistics ERP — بطاقة تعريف وتفاصيل شرط التجارة الدولي');
    buffer.writeln('كود الشرط,${incoterm.incotermCode}');
    buffer.writeln('اسم الشرط الكامل,"${incoterm.incotermName.replaceAll('"', '""')}"');
    buffer.writeln('الإصدار المعتمد,${incoterm.version}');
    buffer.writeln('حالة السجل,${incoterm.isActive ? "نشط ومفعّل" : "غير نشط"}');
    buffer.writeln('نقطة انتقال المخاطر,"${(incoterm.description ?? "-").replaceAll('"', '""')}"');
    buffer.writeln('');

    buffer.writeln('--- مصفوفة توزيع بنود التكلفة والمسؤوليات التعاقدية ---');
    buffer.writeln('بند التكلفة,التصنيف,الجهة المسؤولة,مدرج بسعر الفاتورة,ملاحظات');

    final termResponsibilities = responsibilities
        .where((r) => r.incotermId == incoterm.incotermId || r.incotermCode == incoterm.incotermCode)
        .toList();

    for (final r in termResponsibilities) {
      String party;
      switch (r.responsibleParty) {
        case 'Importer':
          party = 'المشتري (المستورد)';
          break;
        case 'Exporter':
          party = 'البائع (المورد)';
          break;
        default:
          party = 'مشترك';
      }
      buffer.writeln('"${(r.costItemName ?? "-").replaceAll('"', '""')}","${r.costCategory ?? "-"}","$party",${r.includedInIncoterm ? "نعم" : "لا"},"${(r.notes ?? "-").replaceAll('"', '""')}"');
    }

    final filename = 'MasterData_Incoterm_${incoterm.incotermCode}_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'حفظ بيانات شرط التجارة بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generateIncotermWhatsAppText(
    IncotermModel incoterm,
    List<IncotermResponsibilityModel> responsibilities,
  ) {
    final termResponsibilities = responsibilities
        .where((r) => r.incotermId == incoterm.incotermId || r.incotermCode == incoterm.incotermCode)
        .toList();

    final b = StringBuffer();
    b.writeln('*Sorour Logistics ERP — بطاقة شرط التجارة الدولي*');
    b.writeln('📦 *كود الشرط:* ${incoterm.incotermCode}');
    b.writeln('📝 *الاسم الكامل:* ${incoterm.incotermName}');
    b.writeln('🏛️ *الإصدار:* ${incoterm.version}');
    b.writeln('⚡ *الحالة:* ${incoterm.isActive ? "✅ مفعّل" : "❌ متوقف"}');
    if (incoterm.description != null && incoterm.description!.isNotEmpty) {
      b.writeln('📍 *انتقال المخاطر:* ${incoterm.description}');
    }

    if (termResponsibilities.isNotEmpty) {
      b.writeln('\n*📋 مصفوفة توزيع التكاليف والمسؤوليات:*');
      for (final r in termResponsibilities) {
        String party = r.responsibleParty == 'Importer'
            ? 'المشتري (المستورد)'
            : (r.responsibleParty == 'Exporter' ? 'البائع (المورد)' : 'مشترك');
        String inc = r.includedInIncoterm ? 'مدرج بالسعر' : 'غير مدرج';
        b.writeln('• *${r.costItemName}:* $party ($inc)');
      }
    }

    b.writeln('\n_تم الإنشاء عبر Sorour Logistics ERP_');
    return b.toString().trim();
  }

  static String generateIncotermEmailSubject(IncotermModel incoterm) {
    return 'بيان شرط التجارة ومصفوفة المسؤوليات [${incoterm.incotermCode}] - ${incoterm.incotermName}';
  }

  static String generateIncotermEmailBody(
    IncotermModel incoterm,
    List<IncotermResponsibilityModel> responsibilities,
  ) {
    final termResponsibilities = responsibilities
        .where((r) => r.incotermId == incoterm.incotermId || r.incotermCode == incoterm.incotermCode)
        .toList();

    final b = StringBuffer();
    b.writeln('تحية طيبة وبعد،،،\n');
    b.writeln('مرفق لسيادتكم بيان بمحددات وتفاصيل شرط التجارة الدولي ومصفوفة المسؤوليات المسجلة على النظام:\n');
    b.writeln('- كود الشرط: ${incoterm.incotermCode}');
    b.writeln('- الاسم الكامل: ${incoterm.incotermName}');
    b.writeln('- الإصدار المعتمد: ${incoterm.version}');
    b.writeln('- حالة السجل: ${incoterm.isActive ? "مفعّل ونشط" : "متوقف وغير مفعّل"}');
    if (incoterm.description != null && incoterm.description!.isNotEmpty) {
      b.writeln('- نقطة انتقال المخاطر والمسؤولية: ${incoterm.description}');
    }

    if (termResponsibilities.isNotEmpty) {
      b.writeln('\nمصفوفة توزيع بنود التكلفة والمسؤوليات:');
      for (final r in termResponsibilities) {
        String party = r.responsibleParty == 'Importer'
            ? 'المشتري (المستورد)'
            : (r.responsibleParty == 'Exporter' ? 'البائع (المورد)' : 'مشترك');
        String inc = r.includedInIncoterm ? 'نعم (مدرج بالسعر)' : 'لا (غير مدرج)';
        b.writeln('• ${r.costItemName} (${r.costCategory ?? "-"}): $party — مدرج بالسعر: $inc');
      }
    }

    b.writeln('\nشاكرين حسن تعاونكم،،،');
    b.writeln('فريق العمليات وإدارة الاستيراد');
    b.writeln('Sorour Logistics ERP');
    return b.toString().trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. CUSTOMS TARIFF SCHEDULE & HS CODES (MD-008)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> printOrSaveTariffPdf(
    CustomsTariffModel tariff,
    List<Map<String, dynamic>> agreements,
  ) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP — بطاقة بند التعريفة الجمركية',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'بيان بالضرائب، الرسوم، والاشتراطات الاستيرادية (منصة نافذة)',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: tariff.isActive ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#C0392B'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          tariff.isActive ? 'بند مفعّل' : 'بند متوقف',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // HS Code & Description Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'بند التعريفة الجمركية: ${tariff.hsCode}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColor.fromHex('#3498DB')),
                          ),
                          if (tariff.customsCategory != null)
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('#ECF0F1'),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Text(
                                tariff.categoryLabelArabic ?? tariff.customsCategory!,
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50')),
                              ),
                            ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'وصف البند: ${tariff.hsDescription}',
                        style: const pw.TextStyle(fontSize: 11, height: 1.4),
                      ),
                      if (tariff.regulatoryAuthority != null) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'الجهة الرقابية: ${tariff.regulatoryAuthority}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7F8C8D')),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Tax & Duty Rates Table
                pw.Text('نسب الضرائب والرسوم الجمركية المقررة:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: ['ضريبة الوارد', 'ضريبة القيمة المضافة', 'ضريبة الجدول', 'رسم التنمية', 'رسم الوارد'],
                  data: [
                    [
                      '${tariff.customsDutyRate}%',
                      '${tariff.vatRate}%',
                      '${tariff.scheduleTaxRate}%',
                      '${tariff.developmentFeeRate}%',
                      '${tariff.importFeeRate}%',
                    ]
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                  cellAlignment: pw.Alignment.center,
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                ),
                pw.SizedBox(height: 12),

                // Regulatory Requirements
                pw.Text('الاشتراطات المستندية والإفراج الرقابي:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F9FA'),
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('• التسجيل المسبق للشحنات: ${tariff.requiresAcid ? "مطلوب" : "غير مطلوب"}', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(width: 16),
                          pw.Text('• شهادة المنشأ: ${tariff.requiresCoo ? "مطلوبة" : "غير مطلوبة"}', style: const pw.TextStyle(fontSize: 10)),
                          pw.SizedBox(width: 16),
                          pw.Text('• فحص المطابقة: ${tariff.requiresInspection ? "مطلوب" : "غير مطلوب"}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      if (tariff.priorApprovalNote != null && tariff.priorApprovalNote!.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text('الموافقات المسبقة: ${tariff.priorApprovalNote}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                      if (tariff.notes != null && tariff.notes!.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text('ملاحظات: ${tariff.notes}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Preferential Agreements
                if (agreements.isNotEmpty) ...[
                  pw.Text('الاتفاقيات التفضيلية المتاحة:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 6),
                  pw.TableHelper.fromTextArray(
                    headers: ['اسم الاتفاقية', 'دول المنشأ', 'نسبة التخفيض', 'الشروط والملاحظات'],
                    data: agreements.map((ag) {
                      final red = ag['reduction_percentage'] is num
                          ? (ag['reduction_percentage'] as num).toDouble()
                          : (double.tryParse(ag['reduction_percentage']?.toString() ?? '1') ?? 1.0);
                      final pctStr = '${(red * 100).toStringAsFixed(0)}%';
                      return [
                        ag['agreement_name'] ?? '—',
                        ag['origin_countries'] ?? '—',
                        pctStr,
                        ag['conditions_note'] ?? '—',
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                    headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#27AE60')),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Customs_Tariff_${tariff.hsCode.replaceAll(".", "_")}.pdf',
    );
  }

  static Future<String?> exportTariffsToExcel(
    BuildContext context,
    List<CustomsTariffModel> tariffs,
  ) async {
    final buffer = StringBuffer();
    // UTF-8 BOM
    buffer.write('\uFEFF');
    buffer.writeln('"كود البند الجمركي","وصف البند","التصنيف","ضريبة الوارد %","ضريبة القيمة المضافة %","ضريبة الجدول %","رسم التنمية %","رسم الوارد %","الجهة الرقابية","يتطلب تسجيل مسبق","يتطلب شهادة منشأ","يتطلب فحص نوعي","الحالة","ملاحظات"');

    for (final t in tariffs) {
      buffer.writeln(
        '"${t.hsCode}","${t.hsDescription.replaceAll('"', '""')}","${(t.categoryLabelArabic ?? "").replaceAll('"', '""')}",${t.customsDutyRate},${t.vatRate},${t.scheduleTaxRate},${t.developmentFeeRate},${t.importFeeRate},"${(t.regulatoryAuthority ?? "").replaceAll('"', '""')}",${t.requiresAcid ? "نعم" : "لا"},${t.requiresCoo ? "نعم" : "لا"},${t.requiresInspection ? "نعم" : "لا"},"${t.isActive ? "نشط" : "متوقف"}","${(t.notes ?? "").replaceAll('"', '""')}"',
      );
    }

    final filename = 'Customs_Tariffs_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'تصدير جدول التعريفة الجمركية بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generateTariffWhatsAppText(
    CustomsTariffModel tariff,
    List<Map<String, dynamic>> agreements,
  ) {
    final b = StringBuffer();
    b.writeln('*Sorour Logistics ERP — بطاقة بند التعريفة الجمركية*');
    b.writeln('🏷️ *كود البند:* ${tariff.hsCode}');
    b.writeln('📝 *الوصف:* ${tariff.hsDescription}');
    if (tariff.customsCategory != null) b.writeln('📂 *التصنيف:* ${tariff.categoryLabelArabic}');
    b.writeln('⚡ *الحالة:* ${tariff.isActive ? "✅ مفعّل" : "❌ متوقف"}');
    b.writeln('\n*📊 نسب الضرائب والرسوم:*');
    b.writeln('• ضريبة الوارد: ${tariff.customsDutyRate}%');
    b.writeln('• ضريبة القيمة المضافة: ${tariff.vatRate}%');
    if (tariff.scheduleTaxRate > 0) b.writeln('• ضريبة الجدول: ${tariff.scheduleTaxRate}%');
    if (tariff.developmentFeeRate > 0) b.writeln('• رسم التنمية: ${tariff.developmentFeeRate}%');
    if (tariff.importFeeRate > 0) b.writeln('• رسم الوارد: ${tariff.importFeeRate}%');
    if (tariff.regulatoryAuthority != null) b.writeln('🏛️ *الجهة الرقابية:* ${tariff.regulatoryAuthority}');
    if (tariff.priorApprovalNote != null && tariff.priorApprovalNote!.isNotEmpty) {
      b.writeln('⚠️ *الموافقات المسبقة:* ${tariff.priorApprovalNote}');
    }
    if (agreements.isNotEmpty) {
      b.writeln('\n*🤝 الاتفاقيات التفضيلية:*');
      for (final ag in agreements) {
        final name = ag['agreement_name'] ?? 'اتفاقية';
        final red = (ag['reduction_percentage'] is num) ? ((ag['reduction_percentage'] as num) * 100).toStringAsFixed(0) : '100';
        b.writeln('• $name (تخفيض $red%)');
      }
    }
    b.writeln('\n_تم الإنشاء عبر Sorour Logistics ERP_');
    return b.toString().trim();
  }

  static String generateTariffEmailSubject(CustomsTariffModel tariff) {
    return 'بيان البند الجمركي والضرائب والرسوم [${tariff.hsCode}]';
  }

  static String generateTariffEmailBody(
    CustomsTariffModel tariff,
    List<Map<String, dynamic>> agreements,
  ) {
    final b = StringBuffer();
    b.writeln('تحية طيبة وبعد،،،\n');
    b.writeln('مرفق لسيادتكم بيان بنسب الضرائب والرسوم والاشتراطات الرقابية لبند التعريفة الجمركية:\n');
    b.writeln('- كود البند: ${tariff.hsCode}');
    b.writeln('- الوصف: ${tariff.hsDescription}');
    if (tariff.customsCategory != null) b.writeln('- التصنيف الجمركي: ${tariff.categoryLabelArabic}');
    b.writeln('- ضريبة الوارد: ${tariff.customsDutyRate}%');
    b.writeln('- ضريبة القيمة المضافة: ${tariff.vatRate}%');
    if (tariff.scheduleTaxRate > 0) b.writeln('- ضريبة الجدول: ${tariff.scheduleTaxRate}%');
    if (tariff.developmentFeeRate > 0) b.writeln('- رسم التنمية: ${tariff.developmentFeeRate}%');
    if (tariff.importFeeRate > 0) b.writeln('- رسم الوارد: ${tariff.importFeeRate}%');
    if (tariff.regulatoryAuthority != null) b.writeln('- الجهة الرقابية المختصة: ${tariff.regulatoryAuthority}');
    if (tariff.priorApprovalNote != null && tariff.priorApprovalNote!.isNotEmpty) {
      b.writeln('- الاشتراطات والموافقات المسبقة: ${tariff.priorApprovalNote}');
    }
    if (agreements.isNotEmpty) {
      b.writeln('\nالاتفاقيات التفضيلية والإعفاءات المتاحة:');
      for (final ag in agreements) {
        final name = ag['agreement_name'] ?? 'اتفاقية';
        final red = (ag['reduction_percentage'] is num) ? ((ag['reduction_percentage'] as num) * 100).toStringAsFixed(0) : '100';
        b.writeln('• $name - نسبة التخفيض: $red% - دول المنشأ: ${ag['origin_countries'] ?? "-"}');
      }
    }
    b.writeln('\nشاكرين حسن تعاونكم،،،');
    b.writeln('إدارة التخليص والعمليات الجمركية');
    b.writeln('Sorour Logistics ERP');
    return b.toString().trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. PORTS & TRANSPORT LOCATIONS (الموانئ والمنافذ الجمركية)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> printOrSaveLocationPdf(TransportLocationModel location) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP — بطاقة بيانات المنفذ والميناء',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'دليل الموانئ والمواقع اللوجستية والمنافذ الجمركية المعتمدة',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: location.isActive ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#C0392B'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          location.isActive ? 'مفعّل (Active)' : 'متوقف (Inactive)',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Main Details Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            location.locationName,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColor.fromHex('#2C3E50')),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#3498DB'),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              location.unLocode,
                              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('نوع المنفذ: ${location.locationType}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('الدولة: ${location.country}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('المدينة: ${location.city}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                      if (location.notes != null && location.notes!.isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        pw.Text('ملاحظات وتفاصيل إضافية:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(location.notes!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Footer
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تم استخراج هذه الوثيقة من نظام Sorour Logistics ERP', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                    pw.Text('تاريخ الطباعة: ${DateTime.now().toString().split(".")[0]}', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Location_${location.unLocode}.pdf',
    );
  }

  static Future<String?> exportLocationsToExcel(
    BuildContext context,
    List<TransportLocationModel> locations,
  ) async {
    final buffer = StringBuffer();
    // UTF-8 BOM for Arabic support
    buffer.write('\uFEFF');

    // Headers in plain CSV format
    buffer.writeln(
      'UN/LOCODE,Location Name,Type,Country,City,Status,Notes',
    );

    for (final loc in locations) {
      final code = '"${loc.unLocode.replaceAll('"', '""')}"';
      final name = '"${loc.locationName.replaceAll('"', '""')}"';
      final type = '"${loc.locationType.replaceAll('"', '""')}"';
      final country = '"${loc.country.replaceAll('"', '""')}"';
      final city = '"${loc.city.replaceAll('"', '""')}"';
      final status = loc.isActive ? 'Active' : 'Inactive';
      final notes = '"${(loc.notes ?? '').replaceAll('"', '""')}"';

      buffer.writeln('$code,$name,$type,$country,$city,$status,$notes');
    }

    final filename = 'Transport_Locations_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'تصدير دليل الموانئ والمنافذ بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generateLocationWhatsAppText(TransportLocationModel location) {
    final b = StringBuffer();
    b.writeln('*Sorour Logistics ERP — بطاقة بيانات المنفذ أو الميناء*');
    b.writeln('📍 *كود المنفذ الدولي:* ${location.unLocode}');
    b.writeln('🏛️ *اسم المنفذ:* ${location.locationName}');
    b.writeln('🚢 *النوع:* ${location.locationType}');
    b.writeln('🌍 *الدولة:* ${location.country}');
    b.writeln('🏙️ *المدينة:* ${location.city}');
    b.writeln('⚡ *الحالة:* ${location.isActive ? "✅ مفعّل" : "❌ متوقف"}');
    if (location.notes != null && location.notes!.isNotEmpty) {
      b.writeln('📝 *ملاحظات:* ${location.notes}');
    }
    b.writeln('\n_تم الإنشاء عبر Sorour Logistics ERP_');
    return b.toString().trim();
  }

  static String generateLocationEmailSubject(TransportLocationModel location) {
    return 'بيان المنفذ والميناء [${location.unLocode}] - ${location.locationName}';
  }

  static String generateLocationEmailBody(TransportLocationModel location) {
    final b = StringBuffer();
    b.writeln('تحية طيبة وبعد،،،\n');
    b.writeln('مرفق لسيادتكم بيان المنفذ والميناء اللوجستي المعتمد:\n');
    b.writeln('- كود المنفذ الدولي: ${location.unLocode}');
    b.writeln('- اسم المنفذ: ${location.locationName}');
    b.writeln('- نوع المنفذ: ${location.locationType}');
    b.writeln('- الدولة: ${location.country}');
    b.writeln('- المدينة: ${location.city}');
    b.writeln('- الحالة: ${location.isActive ? "مفعّل" : "غير مفعّل"}');
    if (location.notes != null && location.notes!.isNotEmpty) {
      b.writeln('- ملاحظات وتفاصيل إضافية: ${location.notes}');
    }
    b.writeln('\nشاكرين حسن تعاونكم،،،');
    b.writeln('إدارة النقل والشحن والعمليات اللوجستية');
    b.writeln('Sorour Logistics ERP');
    return b.toString().trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. CURRENCIES & EXCHANGE RATES (العملات وأسعار الصرف)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> printOrSaveCurrencyPdf(CurrencyModel currency) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP — بطاقة تعريف العملة وأسعار الصرف',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'دليل العملات الرسمية، أسعار البنوك التجارية وأسعار الصرف الجمركية',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: currency.isActive ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#C0392B'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          currency.isActive ? 'مفعّلة (Active)' : 'متوقفة (Inactive)',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Main Details Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            currency.currencyName,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColor.fromHex('#2C3E50')),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: (currency.isBaseCurrency ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#3498DB')),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              '${currency.currencyCode} (${currency.currencySymbol})',
                              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              'عملة الأساس: ${currency.isBaseCurrency ? "نعم (الجنيه المصري)" : "لا"}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              'الكسور العشرية: ${currency.decimalPlaces}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              'كود العملة القياسي: ${currency.currencyCode}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Rates Summary Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8F9F9'),
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'أسعار الصرف الحالية المعتمدة:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50')),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('سعر البنك التجاري:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                pw.Text(
                                  currency.isBaseCurrency
                                      ? '1.0000 جنيه (أساس)'
                                      : (currency.latestCommercialRate != null
                                          ? '${currency.latestCommercialRate!.toStringAsFixed(4)} جنيه'
                                          : 'غير محدد'),
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#3498DB')),
                                ),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('سعر الصرف الجمركي الرسمي:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                pw.Text(
                                  currency.isBaseCurrency
                                      ? '1.0000 جنيه (أساس)'
                                      : (currency.latestCustomsRate != null
                                          ? '${currency.latestCustomsRate!.toStringAsFixed(4)} جنيه'
                                          : 'غير محدد'),
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#E67E22')),
                                ),
                              ],
                            ),
                          ),
                          if (!currency.isBaseCurrency && currency.latestCommercialRate != null && currency.latestCustomsRate != null)
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('الفارق بين السعرين:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                  pw.Text(
                                    '${(currency.latestCommercialRate! - currency.latestCustomsRate!).toStringAsFixed(4)} جنيه',
                                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#27AE60')),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Rates Timeline Table (if available)
                if (currency.exchangeRates != null && currency.exchangeRates!.isNotEmpty) ...[
                  pw.Text(
                    'السجل التاريخي لأسعار الصرف السابقة:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50')),
                  ),
                  pw.SizedBox(height: 6),
                  pw.TableHelper.fromTextArray(
                    headers: ['تاريخ السريان', 'سعر البنك التجاري', 'سعر الجمارك الرسمي', 'الفارق', 'المصدر'],
                    data: currency.exchangeRates!.take(10).map((r) {
                      final diff = r.commercialRate - r.customsRate;
                      return [
                        r.effectiveDate,
                        '${r.commercialRate.toStringAsFixed(4)} جنيه',
                        '${r.customsRate.toStringAsFixed(4)} جنيه',
                        '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(4)}',
                        r.createdBy ?? 'النظام',
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  ),
                ],

                // Footer
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تم استخراج هذه الوثيقة من نظام Sorour Logistics ERP', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                    pw.Text('تاريخ الطباعة: ${DateTime.now().toString().split(".")[0]}', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Currency_${currency.currencyCode}.pdf',
    );
  }

  static Future<String?> exportCurrenciesToExcel(
    BuildContext context,
    List<CurrencyModel> currencies,
  ) async {
    final buffer = StringBuffer();
    // UTF-8 BOM for Arabic support
    buffer.write('\uFEFF');

    // Headers in plain CSV format
    buffer.writeln(
      'ISO Code,Currency Name,Symbol,Base Currency,Commercial Rate (EGP),Customs Rate (EGP),Decimal Places,Status',
    );

    for (final c in currencies) {
      final code = '"${c.currencyCode.replaceAll('"', '""')}"';
      final name = '"${c.currencyName.replaceAll('"', '""')}"';
      final symbol = '"${c.currencySymbol.replaceAll('"', '""')}"';
      final isBase = c.isBaseCurrency ? 'Yes' : 'No';
      final commRate = c.isBaseCurrency ? '1.0000' : (c.latestCommercialRate?.toStringAsFixed(4) ?? '');
      final custRate = c.isBaseCurrency ? '1.0000' : (c.latestCustomsRate?.toStringAsFixed(4) ?? '');
      final decimals = c.decimalPlaces.toString();
      final status = c.isActive ? 'Active' : 'Inactive';

      buffer.writeln('$code,$name,$symbol,$isBase,$commRate,$custRate,$decimals,$status');
    }

    final filename = 'Currencies_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'تصدير جدول العملات وأسعار الصرف بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generateCurrencyWhatsAppText(CurrencyModel currency) {
    final b = StringBuffer();
    b.writeln('*Sorour Logistics ERP — بيان العملة وأسعار الصرف*');
    b.writeln('💱 *كود العملة:* ${currency.currencyCode} (${currency.currencySymbol})');
    b.writeln('🏷️ *الاسم:* ${currency.currencyName}');
    b.writeln('🏦 *سعر البنك التجاري:* ${currency.isBaseCurrency ? "1.0000 جنيه" : (currency.latestCommercialRate != null ? "${currency.latestCommercialRate!.toStringAsFixed(4)} جنيه" : "غير محدد")}');
    b.writeln('🏛️ *سعر الصرف الجمركي:* ${currency.isBaseCurrency ? "1.0000 جنيه" : (currency.latestCustomsRate != null ? "${currency.latestCustomsRate!.toStringAsFixed(4)} جنيه" : "غير محدد")}');
    if (!currency.isBaseCurrency && currency.latestCommercialRate != null && currency.latestCustomsRate != null) {
      final spread = (currency.latestCommercialRate! - currency.latestCustomsRate!).toStringAsFixed(4);
      b.writeln('📊 *الفارق بين السعرين:* $spread جنيه');
    }
    b.writeln('⚡ *الحالة:* ${currency.isActive ? "✅ مفعّلة" : "❌ متوقفة"}');
    b.writeln('\n_تم الإنشاء عبر Sorour Logistics ERP_');
    return b.toString().trim();
  }

  static String generateCurrencyEmailSubject(CurrencyModel currency) {
    return 'بيان أسعار صرف عملة [${currency.currencyCode}] - ${currency.currencyName}';
  }

  static String generateCurrencyEmailBody(CurrencyModel currency) {
    final b = StringBuffer();
    b.writeln('تحية طيبة وبعد،،،\n');
    b.writeln('مرفق لسيادتكم بيان أسعار الصرف الرسمية لعملة (${currency.currencyName}):\n');
    b.writeln('- كود العملة القياسي: ${currency.currencyCode}');
    b.writeln('- رمز العملة: ${currency.currencySymbol}');
    b.writeln('- سعر البنك التجاري: ${currency.isBaseCurrency ? "1.0000 جنيه" : (currency.latestCommercialRate != null ? "${currency.latestCommercialRate!.toStringAsFixed(4)} جنيه" : "غير محدد")}');
    b.writeln('- سعر الصرف الجمركي الرسمي: ${currency.isBaseCurrency ? "1.0000 جنيه" : (currency.latestCustomsRate != null ? "${currency.latestCustomsRate!.toStringAsFixed(4)} جنيه" : "غير محدد")}');
    if (!currency.isBaseCurrency && currency.latestCommercialRate != null && currency.latestCustomsRate != null) {
      final spread = (currency.latestCommercialRate! - currency.latestCustomsRate!).toStringAsFixed(4);
      b.writeln('- الفارق المالي بين السعرين: $spread جنيه');
    }
    b.writeln('- الحالة: ${currency.isActive ? "مفعّلة" : "غير مفعّلة"}');
    b.writeln('\nشاكرين حسن تعاونكم،،،');
    b.writeln('إدارة الحسابات والعمليات المالية');
    b.writeln('Sorour Logistics ERP');
    return b.toString().trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. AUDIT LOGS & OPERATIONAL HISTORY (سجلات التدقيق وتتبع العمليات)
  // ═══════════════════════════════════════════════════════════════════════════

  static PdfColor _getAuditPdfActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return PdfColor.fromHex('#27AE60');
      case 'UPDATE':
        return PdfColor.fromHex('#3498DB');
      case 'DELETE':
        return PdfColor.fromHex('#C0392B');
      case 'RESTORE':
        return PdfColor.fromHex('#E67E22');
      default:
        return PdfColor.fromHex('#2C3E50');
    }
  }

  static Future<void> printOrSaveAuditLogPdf(AuditLogModel log) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'إشعار وبيان حركة تدقيق نظام — System Audit Log',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: _getAuditPdfActionColor(log.action),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          log.action.toUpperCase(),
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                // Details Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('معرف الحركة:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text('#${log.logId}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey200),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('الكيان المتأثر:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text('${log.entityType} (${log.entityCode ?? log.entityId.toString()})', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey200),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('نوع الإجراء:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(log.action.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _getAuditPdfActionColor(log.action))),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey200),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('المستخدم المنفذ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(log.performedBy, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey200),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('التاريخ والتوقيت:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.Text(log.performedAt.toLocal().toString().split('.').first, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // Changes Summary
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ملخص وبيان التغيير:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 6),
                      pw.Text(log.changesSummary ?? 'تم تنفيذ حركة تعديل بالنظام', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),

                if (log.oldValues != null || log.newValues != null) ...[
                  pw.SizedBox(height: 16),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (log.oldValues != null)
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.red50,
                              border: pw.Border.all(color: PdfColors.red200),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('القيم السابقة (Old Values):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red800)),
                                pw.SizedBox(height: 4),
                                pw.Text(log.oldValues!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.red900)),
                              ],
                            ),
                          ),
                        ),
                      if (log.oldValues != null && log.newValues != null) pw.SizedBox(width: 10),
                      if (log.newValues != null)
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.green50,
                              border: pw.Border.all(color: PdfColors.green200),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('القيم الجديدة (New Values):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.green800)),
                                pw.SizedBox(height: 4),
                                pw.Text(log.newValues!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.green900)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تم استخراج هذه الوثيقة من نظام Sorour Logistics ERP', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                    pw.Text('تاريخ الطباعة: ${DateTime.now().toString().split(".")[0]}', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'AuditLog_${log.logId}_${log.action}.pdf',
    );
  }

  static Future<void> printOrSaveAuditLogsListPdf(
    List<AuditLogModel> logs, {
    String title = 'سجل تتبع العمليات وتدقيق النظام',
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#2C3E50'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Sorour Logistics ERP', style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(title, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                          ],
                        ),
                        pw.Text('إجمالي الحركات: ${logs.length}', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),

                  // Table
                  pw.TableHelper.fromTextArray(
                    headers: ['#', 'النوع', 'الكيان', 'كود الكيان', 'ملخص التغيير', 'المستخدم', 'التاريخ والوقت'],
                    data: logs.take(100).map((l) {
                      return [
                        '#${l.logId}',
                        l.action.toUpperCase(),
                        l.entityType,
                        l.entityCode ?? l.entityId.toString(),
                        l.changesSummary ?? 'تعديل',
                        l.performedBy,
                        l.performedAt.toLocal().toString().split('.').first,
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('تم استخراج هذه الوثيقة من نظام Sorour Logistics ERP', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                      pw.Text('تاريخ الطباعة: ${DateTime.now().toString().split(".")[0]}', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'AuditLogs_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<String?> exportAuditLogsToExcel(
    BuildContext context,
    List<AuditLogModel> logs,
  ) async {
    final buffer = StringBuffer();
    // UTF-8 BOM for Arabic support
    buffer.write('\uFEFF');

    // Headers in plain CSV format
    buffer.writeln(
      'Log ID,Action,Entity Type,Entity Code,Changes Summary,Performed By,Date & Time',
    );

    for (final l in logs) {
      final id = l.logId.toString();
      final act = '"${l.action.replaceAll('"', '""')}"';
      final entity = '"${l.entityType.replaceAll('"', '""')}"';
      final code = '"${(l.entityCode ?? l.entityId.toString()).replaceAll('"', '""')}"';
      final summary = '"${(l.changesSummary ?? "").replaceAll('"', '""')}"';
      final by = '"${l.performedBy.replaceAll('"', '""')}"';
      final time = '"${l.performedAt.toLocal().toString().split('.').first}"';

      buffer.writeln('$id,$act,$entity,$code,$summary,$by,$time');
    }

    final filename = 'AuditLogs_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'تصدير سجلات التدقيق والمراجعة بصيغة Excel / CSV',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generateAuditLogWhatsAppText(AuditLogModel log) {
    final b = StringBuffer();
    b.writeln('*Sorour Logistics ERP — بيان حركة تدقيق نظام*');
    b.writeln('🆔 *رقم الحركة:* #${log.logId}');
    b.writeln('⚡ *الإجراء:* ${log.action.toUpperCase()}');
    b.writeln('📦 *الكيان:* ${log.entityType} (#${log.entityCode ?? log.entityId})');
    b.writeln('📝 *ملخص التعديل:* ${log.changesSummary ?? "تم تسجيل حركة بالنظام"}');
    b.writeln('👤 *المستخدم:* ${log.performedBy}');
    b.writeln('⏰ *التوقيت:* ${log.performedAt.toLocal().toString().split(".")[0]}');
    b.writeln('\n_تم الإنشاء عبر Sorour Logistics ERP_');
    return b.toString().trim();
  }

  static String generateAuditLogEmailSubject(AuditLogModel log) {
    return 'إشعار حركة تدقيق نظام [#${log.logId}] - ${log.entityType} (${log.action})';
  }

  static String generateAuditLogEmailBody(AuditLogModel log) {
    final b = StringBuffer();
    b.writeln('تحية طيبة وبعد،،،\n');
    b.writeln('مرفق لسيادتكم بيان حركة التدقيق المسجلة بالنظام:\n');
    b.writeln('- رقم الحركة: #${log.logId}');
    b.writeln('- نوع الإجراء: ${log.action.toUpperCase()}');
    b.writeln('- الكيان المتأثر: ${log.entityType}');
    b.writeln('- كود/معرف الكيان: ${log.entityCode ?? log.entityId.toString()}');
    b.writeln('- تفاصيل التعديل: ${log.changesSummary ?? "تم تسجيل حركة بالنظام"}');
    b.writeln('- المنفذ: ${log.performedBy}');
    b.writeln('- التوقيت: ${log.performedAt.toLocal().toString().split(".")[0]}');
    b.writeln('\nشاكرين حسن تعاونكم،،،');
    b.writeln('إدارة أمن وتدقيق النظام');
    b.writeln('Sorour Logistics ERP');
    return b.toString().trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. SMART TASKS & PRIORITY REMINDERS (المهام الذكية ومحرك التذكيرات)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> printOrSaveSmartTaskPdf(SmartTaskModel task) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    PdfColor priorityColor;
    switch (task.priority.toLowerCase()) {
      case 'critical':
      case 'high':
        priorityColor = PdfColor.fromHex('#C0392B');
        break;
      case 'medium':
        priorityColor = PdfColor.fromHex('#E67E22');
        break;
      default:
        priorityColor = PdfColor.fromHex('#27AE60');
    }

    PdfColor statusColor;
    switch (task.status.toLowerCase()) {
      case 'completed':
        statusColor = PdfColor.fromHex('#27AE60');
        break;
      case 'in progress':
        statusColor = PdfColor.fromHex('#3498DB');
        break;
      default:
        statusColor = PdfColor.fromHex('#7F8C8D');
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Sorour Logistics ERP — بطاقة مهمة تشغيلية ومحرك تذكيرات',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'وثيقة رسمية ببيانات المهمة والمتابعة اللوجستية',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: priorityColor,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              task.priority,
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: statusColor,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              task.status,
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Main Info Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('كود المهمة: ${task.taskCode}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromHex('#3498DB'))),
                          pw.Text('نوع المهمة: ${task.taskType}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('عنوان المهمة: ${task.title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('#2C3E50'))),
                      if (task.description != null && task.description!.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text('الوصف والمتطلبات: ${task.description}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Details Grid Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('البند التشغيلي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('البيان والقيمة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الشحنة / ملف الاستيراد المرتبط', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(task.importFileCode ?? 'مهمة عامة غير مرتبطة بملف استيراد', style: pw.TextStyle(fontSize: 9, fontWeight: task.importFileCode != null ? pw.FontWeight.bold : pw.FontWeight.normal))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('المرحلة التشغيلية', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(task.phaseName ?? '-', style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('نوع محرك التذكير', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(task.reminderType, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('تاريخ الاستحقاق والإنجاز', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(task.dueDate ?? '-', style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('تاريخ إطلاق التنبيه والتذكير', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(task.reminderDate ?? '-', style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('المستخدم المكلف بالمتابعة', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(task.assignedUser, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('ملاحظات تشغيلية إضافية', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(task.notes!, style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 14),

                // Audit metadata
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.grey200),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('تاريخ الإنشاء: ${task.createdAt}', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8)),
                      pw.Text('أنشئت بواسطة: ${task.createdBy}', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8)),
                    ],
                  ),
                ),
                pw.Spacer(),

                // Footer
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تم استخراج هذه الوثيقة من نظام Sorour Logistics ERP', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                    pw.Text('تاريخ الطباعة: ${DateTime.now().toString().split(".")[0]}', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'SmartTask_${task.taskCode}.pdf',
    );
  }

  static Future<void> printOrSaveSmartTasksListPdf(
    List<SmartTaskModel> tasks, {
    String title = 'تقرير قائمة المهام الذكية والتذكيرات التشغيلية',
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#2C3E50'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Sorour Logistics ERP', style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text(title, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                          ],
                        ),
                        pw.Text('إجمالي المهام: ${tasks.length}', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 14),

                  // Table
                  pw.TableHelper.fromTextArray(
                    headers: ['كود المهمة', 'النوع', 'عنوان المهمة', 'الشحنة', 'الأولوية', 'محرك التذكير', 'الاستحقاق', 'الحالة', 'المسؤول'],
                    data: tasks.take(150).map((t) {
                      return [
                        t.taskCode,
                        t.taskType == 'System Generated' ? 'آلية' : 'يدوية',
                        t.title,
                        t.importFileCode ?? 'عام',
                        t.priority,
                        t.reminderType,
                        t.dueDate ?? '-',
                        t.status,
                        t.assignedUser,
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('تم استخراج هذا التقرير من نظام Sorour Logistics ERP', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                      pw.Text('تاريخ الطباعة: ${DateTime.now().toString().split(".")[0]}', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'SmartTasks_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<String?> exportSmartTasksToExcel(
    BuildContext context,
    List<SmartTaskModel> tasks,
  ) async {
    final buffer = StringBuffer();
    // UTF-8 BOM for Arabic support in Excel
    buffer.write('\uFEFF');

    // CSV Headers
    buffer.writeln(
      'كود المهمة,نوع المهمة,عنوان المهمة,الوصف,الشحنة المرتبطة,المرحلة,الأولوية,نوع التذكير,تاريخ الاستحقاق,تاريخ التنبيه,الحالة,المستخدم المسؤول,ملاحظات,تاريخ الإنشاء,منشئ المهمة',
    );

    for (final t in tasks) {
      final code = '"${t.taskCode.replaceAll('"', '""')}"';
      final type = '"${t.taskType.replaceAll('"', '""')}"';
      final title = '"${t.title.replaceAll('"', '""')}"';
      final desc = '"${(t.description ?? "").replaceAll('"', '""')}"';
      final fileCode = '"${(t.importFileCode ?? "").replaceAll('"', '""')}"';
      final phase = '"${(t.phaseName ?? "").replaceAll('"', '""')}"';
      final priority = '"${t.priority.replaceAll('"', '""')}"';
      final reminder = '"${t.reminderType.replaceAll('"', '""')}"';
      final due = '"${(t.dueDate ?? "").replaceAll('"', '""')}"';
      final alertDate = '"${(t.reminderDate ?? "").replaceAll('"', '""')}"';
      final status = '"${t.status.replaceAll('"', '""')}"';
      final user = '"${t.assignedUser.replaceAll('"', '""')}"';
      final notes = '"${(t.notes ?? "").replaceAll('"', '""')}"';
      final createdAt = '"${t.createdAt.replaceAll('"', '""')}"';
      final createdBy = '"${t.createdBy.replaceAll('"', '""')}"';

      buffer.writeln('$code,$type,$title,$desc,$fileCode,$phase,$priority,$reminder,$due,$alertDate,$status,$user,$notes,$createdAt,$createdBy');
    }

    final filename = 'SmartTasks_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: 'تصدير قائمة المهام الذكية والتذكيرات بصيغة إكسيل',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static String generateSmartTaskWhatsAppText(SmartTaskModel task) {
    final b = StringBuffer();
    b.writeln('*Sorour Logistics ERP — بطاقة مهمة ذكية*');
    b.writeln('📋 *كود المهمة:* ${task.taskCode}');
    b.writeln('🏷️ *النوع:* ${task.taskType}');
    b.writeln('📌 *العنوان:* ${task.title}');
    if (task.description != null && task.description!.isNotEmpty) {
      b.writeln('📝 *التفاصيل:* ${task.description}');
    }
    if (task.importFileCode != null) {
      b.writeln('📦 *الشحنة:* ${task.importFileCode}');
    }
    b.writeln('⚡ *الأولوية:* ${task.priority}');
    b.writeln('🔔 *محرك التذكير:* ${task.reminderType}');
    if (task.dueDate != null) {
      b.writeln('📅 *تاريخ الاستحقاق:* ${task.dueDate}');
    }
    b.writeln('🚦 *الحالة:* ${task.status}');
    b.writeln('👤 *المسؤول:* ${task.assignedUser}');
    b.writeln('\n_تم الإنشاء عبر Sorour Logistics ERP_');
    return b.toString().trim();
  }

  static String generateSmartTaskEmailSubject(SmartTaskModel task) {
    return 'مهمة تشغيلية وتذكير [${task.taskCode}] - ${task.title}';
  }

  static String generateSmartTaskEmailBody(SmartTaskModel task) {
    final b = StringBuffer();
    b.writeln('تحية طيبة وبعد،،،\n');
    b.writeln('مرفق لسيادتكم بيان المهمة التشغيلية والتذكير المطلوب متابعته:\n');
    b.writeln('- كود المهمة: ${task.taskCode}');
    b.writeln('- نوع المهمة: ${task.taskType}');
    b.writeln('- عنوان المهمة: ${task.title}');
    if (task.description != null && task.description!.isNotEmpty) {
      b.writeln('- التفاصيل والمتطلبات: ${task.description}');
    }
    if (task.importFileCode != null) {
      b.writeln('- الشحنة / ملف الاستيراد: ${task.importFileCode}');
    }
    b.writeln('- الأولوية: ${task.priority}');
    b.writeln('- محرك التذكير: ${task.reminderType}');
    if (task.dueDate != null) {
      b.writeln('- تاريخ الاستحقاق: ${task.dueDate}');
    }
    b.writeln('- الحالة الحالية: ${task.status}');
    b.writeln('- المستخدم المكلف: ${task.assignedUser}');
    if (task.notes != null && task.notes!.isNotEmpty) {
      b.writeln('- ملاحظات إضافية: ${task.notes}');
    }
    b.writeln('\nيرجى التكرم باتخاذ اللازم والمتابعة لإنجاز المطلوب.');
    b.writeln('\nشاكرين حسن تعاونكم،،،');
    b.writeln('فريق العمليات واللوجستيات');
    b.writeln('Sorour Logistics ERP');
    return b.toString().trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. DYNAMIC REPORT BUILDER (التقارير الديناميكية والمخصصة)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> exportDynamicReportToExcel({
    required BuildContext context,
    required List<ImportFileModel> files,
    required List<String> visibleColumnIds,
    required Map<String, String> columnLabels,
    required String Function(ImportFileModel, String) cellValueGetter,
    required String templateTitle,
    required String timestamp,
    String? dialogTitle,
    String? fileNamePrefix,
  }) async {
    const bom = '\uFEFF';
    final headerMeta = '# $templateTitle | $timestamp | Records: ${files.length}';
    final headerRow = visibleColumnIds.map((id) => columnLabels[id] ?? id).join(',');

    final rows = files.map((f) {
      return visibleColumnIds.map((id) {
        final val = cellValueGetter(f, id).replaceAll('\n', ' / ');
        return '"${val.replaceAll('"', '""')}"';
      }).join(',');
    }).toList();

    final csvContent = '$bom$headerMeta\n$headerRow\n${rows.join('\n')}';
    final prefix = fileNamePrefix ?? 'DynamicReport';
    final filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: csvContent,
      defaultFileName: filename,
      dialogTitle: dialogTitle ?? 'تصدير التقرير بصيغة جدول بيانات',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static Future<void> printOrSaveDynamicReportPdf({
    required BuildContext context,
    required List<ImportFileModel> files,
    required List<String> visibleColumnIds,
    required Map<String, String> columnLabels,
    required String Function(ImportFileModel, String) cellValueGetter,
    required String templateTitle,
    required String timestamp,
    required bool isAr,
    String? reportTitle,
    String? confidentialText,
    String? dialogTitle,
    String? fileNamePrefix,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final headers = visibleColumnIds.map((id) => columnLabels[id] ?? id).toList();
    final tableData = files.map((f) {
      return visibleColumnIds.map((id) => cellValueGetter(f, id).replaceAll('\n', ' ')).toList();
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context pdfContext) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 2)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            reportTitle ?? (isAr ? 'نظام Sorour Logistics ERP — تقرير الشحنات الديناميكي' : 'Sorour Logistics ERP — Dynamic Shipment Report'),
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey800,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '$templateTitle | $timestamp | ${files.length} ${isAr ? "سجل" : "records"}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
                  columnWidths: {
                    for (int i = 0; i < headers.length; i++)
                      i: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                      children: headers.map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
                        ),
                      )).toList(),
                    ),
                    ...tableData.asMap().entries.map((entry) {
                      final isEven = entry.key.isEven;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: isEven ? PdfColors.blueGrey50 : PdfColors.white,
                        ),
                        children: entry.value.map((cell) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: pw.Text(
                            cell,
                            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.blueGrey900),
                            textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
                          ),
                        )).toList(),
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      confidentialText ?? (isAr ? 'سري ومخصص للاستخدام الداخلي' : 'Confidential — Internal Use Only'),
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      '${files.length} ${isAr ? "سجل" : "records"}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final prefix = fileNamePrefix ?? 'DynamicReport';
    final filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    if (!context.mounted) return;
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: bytes,
      defaultFileName: filename,
      dialogTitle: dialogTitle ?? (isAr ? 'تصدير التقرير بصيغة ملف بي دي إف' : 'Export Report as PDF'),
      allowedExtensions: ['pdf'],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. OPERATIONAL & DAILY SHIPMENT UPDATES (سجلات التحديث اليومي ومتابعة الشحنات)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> exportShipmentUpdatesToExcel(
    BuildContext context,
    List<ShipmentUpdateLogModel> logs, {
    String? shipmentCode,
    bool isAr = true,
  }) async {
    const bom = '\uFEFF';
    final timestamp = DateTime.now().toString().split('.')[0];
    final title = isAr
        ? (shipmentCode != null ? 'سجل متابعة وتحديثات الشحنة ($shipmentCode)' : 'سجل التحديثات التشغيلية واليومية')
        : (shipmentCode != null ? 'Shipment Updates Log ($shipmentCode)' : 'Operational & Daily Shipment Updates Log');

    final metaHeader = '# $title | $timestamp | ${logs.length} ${isAr ? "سجل" : "records"}';

    final headers = isAr
        ? [
            'كود التحديث',
            'رقم الشحنة',
            'التاريخ',
            'نوع التحديث',
            'المرحلة المستهدفة',
            'حالة المرحلة',
            'الملاحظات والتفاصيل',
            'بند التكلفة المعدل',
            'التكلفة السابقة',
            'التكلفة الجديدة',
            'مستوى الأولوية',
            'المستخدم المسؤول',
          ]
        : [
            'Update Code',
            'Shipment Code',
            'Date',
            'Category',
            'Target Phase',
            'Phase Status',
            'Notes & Details',
            'Adjusted Cost Item',
            'Previous Cost',
            'New Cost',
            'Priority',
            'Assigned User',
          ];

    final headerRow = headers.join(',');

    final rows = logs.map((log) {
      final cells = [
        log.updateCode,
        log.importFileCode,
        log.logDate,
        log.updateCategory,
        log.targetPhase,
        log.phaseStatus,
        log.note.replaceAll('\n', ' / '),
        log.adjustedCostItem ?? '-',
        log.previousCost.toStringAsFixed(2),
        log.newCost.toStringAsFixed(2),
        log.alertPriority,
        log.assignedUser,
      ];
      return cells.map((c) => '"${c.replaceAll('"', '""')}"').join(',');
    }).toList();

    final csvContent = '$bom$metaHeader\n$headerRow\n${rows.join('\n')}';
    final prefix = shipmentCode != null && shipmentCode.isNotEmpty
        ? 'ShipmentUpdates_${shipmentCode.replaceAll(RegExp(r'[^\w\-]'), '_')}'
        : 'ShipmentUpdates';
    final filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv';

    if (!context.mounted) return;
    await FileSaveHelper.saveText(
      context: context,
      textContent: csvContent,
      defaultFileName: filename,
      dialogTitle: isAr ? 'تصدير سجلات التحديثات إلى ملف إكسيل' : 'Export Shipment Updates to Excel',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static Future<void> printOrSaveShipmentUpdatesListPdf(
    BuildContext context,
    List<ShipmentUpdateLogModel> logs, {
    String? shipmentCode,
    bool isAr = true,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final title = isAr
        ? (shipmentCode != null ? 'سجل متابعة وتحديثات الشحنة ($shipmentCode)' : 'سجل متابعة وتحديثات الشحنات التشغيلية')
        : (shipmentCode != null ? 'Shipment Operational Updates Log ($shipmentCode)' : 'Shipment Operational Updates Log');

    final headers = isAr
        ? ['كود التحديث', 'التاريخ', 'النوع', 'المرحلة', 'الملاحظات', 'التكلفة المعدلة', 'المسؤول']
        : ['Code', 'Date', 'Type', 'Phase', 'Notes', 'Cost Adj.', 'User'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        header: (pw.Context ctx) {
          return pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Sorour Logistics ERP',
                        style: pw.TextStyle(color: PdfColors.blueGrey800, fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        title,
                        style: pw.TextStyle(color: PdfColor.fromHex('#3498DB'), fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateTime.now().toString().split('.')[0],
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          );
        },
        build: (pw.Context ctx) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.4),
                    1: const pw.FlexColumnWidth(1.2),
                    2: const pw.FlexColumnWidth(1.6),
                    3: const pw.FlexColumnWidth(1.3),
                    4: const pw.FlexColumnWidth(3.4),
                    5: const pw.FlexColumnWidth(1.8),
                    6: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                      children: headers.map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                        child: pw.Text(
                          h,
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
                        ),
                      )).toList(),
                    ),
                    ...logs.asMap().entries.map((entry) {
                      final isEven = entry.key.isEven;
                      final log = entry.value;
                      final costText = log.updateCategory == 'Phase Cost Adjustment'
                          ? '${log.previousCost.toStringAsFixed(0)} ➔ ${log.newCost.toStringAsFixed(0)}'
                          : '-';

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: isEven ? PdfColors.blueGrey50 : PdfColors.white),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            child: pw.Text(log.updateCode, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50')), textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            child: pw.Text(log.logDate, style: const pw.TextStyle(fontSize: 7.5), textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            child: pw.Text(log.updateCategory, style: const pw.TextStyle(fontSize: 7.5), textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            child: pw.Text(log.targetPhase, style: const pw.TextStyle(fontSize: 7.5), textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            child: pw.Text(log.note.replaceAll('\n', ' '), style: const pw.TextStyle(fontSize: 7), textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            child: pw.Text(costText, style: const pw.TextStyle(fontSize: 7.5), textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                            child: pw.Text(log.assignedUser, style: const pw.TextStyle(fontSize: 7.5), textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isAr ? 'وثيقة تشغيلية رسمية — سرية ومخصصة للاستخدام الداخلي' : 'Official operational document — Confidential, internal use only',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      '${logs.length} ${isAr ? "تحديث" : "updates"}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final prefix = shipmentCode != null && shipmentCode.isNotEmpty
        ? 'ShipmentUpdates_${shipmentCode.replaceAll(RegExp(r'[^\w\-]'), '_')}'
        : 'ShipmentUpdates';
    final filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    if (!context.mounted) return;
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: bytes,
      defaultFileName: filename,
      dialogTitle: isAr ? 'تصدير سجل التحديثات بصيغة بي دي إف' : 'Export Updates as PDF',
      allowedExtensions: ['pdf'],
    );
  }

  static Future<void> printOrSaveShipmentUpdateSlipPdf(ShipmentUpdateLogModel log, {bool isAr = true}) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isAr ? 'Sorour Logistics ERP — إشعار تحديث تشغيلي للشحنة' : 'Sorour Logistics ERP — Shipment Operational Update',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            isAr ? 'بطاقة توثيق الإجراء التشغيلي والمتابعة اليومية' : 'Daily Operational Update & Follow-up Slip',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#3498DB'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          log.updateCode,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Details Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "رقم ملف الشحنة" : "Shipment Code"}: ${log.importFileCode}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('${isAr ? "التاريخ" : "Date"}: ${log.logDate}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "نوع التحديث" : "Category"}: ${log.updateCategory}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('${isAr ? "المرحلة المستهدفة" : "Target Phase"}: ${log.targetPhase}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "مستوى الأولوية" : "Priority"}: ${log.alertPriority}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('${isAr ? "المستخدم المسؤول" : "Assigned User"}: ${log.assignedUser}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                      if (log.updateCategory == 'Phase Cost Adjustment') ...[
                        pw.SizedBox(height: 8),
                        pw.Text(
                          '${isAr ? "بند التكلفة المعدل" : "Adjusted Cost"}: ${log.adjustedCostItem ?? (isAr ? "التكلفة" : "Cost")} (${log.previousCost.toStringAsFixed(2)} ➔ ${log.newCost.toStringAsFixed(2)})',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C0392B')),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Notes Box
                pw.Text(isAr ? 'ملاحظات وتفاصيل التحديث:' : 'Notes & Details:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(log.note, style: const pw.TextStyle(fontSize: 9.5)),
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(isAr ? 'وثيقة صادرة عن نظام سرور للخدمات اللوجستية' : 'Issued by Sorour Logistics ERP System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text('${isAr ? "تاريخ الطباعة" : "Printed"}: ${DateTime.now().toString().split(".")[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ShipmentUpdate_${log.updateCode}.pdf',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. IMPORT REQUIREMENTS & REGULATORY ENGINE (تقييم متطلبات الاستيراد)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _pdfReqHeaderCell(String text, bool isAr) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
        textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _pdfReqDataCell(String text, bool isAr) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7.5),
        textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static Future<String?> exportImportRequirementsToExcel(BuildContext context, List<ImportRequirementModel> reqs, {bool isAr = true}) async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM

    if (isAr) {
      buffer.writeln('كود التقييم,رقم ملف الشحنة,بند التعريفة,وصف السلعة,القيمة,العملة,بلد المنشأ,المورد,قرار ٤٣,شهادة المنشأ,فحص ما قبل الشحن,الموافقات الرقابية,الشهادات الفنية,حالة الإبحار,الحالة العامة,مستوى المخاطر,المقيّم,الملاحظات');
    } else {
      buffer.writeln('Assessment Code,Import File,HS Code,Commodity,Value,Currency,Origin,Supplier,Decree 43,COO,Inspection,Permits,Tech Certs,Sailing Status,Overall Status,Risk Level,Assessed By,Notes');
    }

    for (final r in reqs) {
      final decreeText = r.decree43Applicable
          ? (r.whiteListVerified ? (isAr ? 'مسجل ومعتمد' : 'Verified') : (r.decree43Justification ?? (isAr ? 'غير مسجل' : 'Not Registered')))
          : (isAr ? 'غير خاضع' : 'Not Applicable');
      final cooText = r.cooRequired ? '${r.cooType ?? "COO"}: ${r.cooStatus}' : (isAr ? 'غير مطلوب' : 'Not Required');
      final inspText = r.inspectionRequired ? '${r.inspectionBody ?? "Body"}: ${r.inspectionStatus}' : (isAr ? 'غير مطلوب' : 'Not Required');
      final permitText = r.importPermitRequired ? '${r.permitIssuingAuthority ?? "Authority"}: ${r.permitStatus}' : (isAr ? 'غير مطلوب' : 'Not Required');
      final techText = [
        if (r.msdsRequired) 'MSDS: ${r.msdsStatus}',
        if (r.halalCertRequired) 'Halal: ${r.halalCertStatus}',
        if (r.coaRequired) 'COA: ${r.coaStatus}',
      ].join('; ');

      buffer.writeln([
        '"${r.assessmentCode.replaceAll('"', '""')}"',
        '"${(r.importFileCode ?? '').replaceAll('"', '""')}"',
        '"${(r.hsCode ?? '').replaceAll('"', '""')}"',
        '"${(r.commodityDescription ?? '').replaceAll('"', '""')}"',
        r.shipmentValue.toStringAsFixed(2),
        r.currency,
        '"${(r.countryOfOrigin ?? '').replaceAll('"', '""')}"',
        '"${(r.supplierName ?? '').replaceAll('"', '""')}"',
        '"${decreeText.replaceAll('"', '""')}"',
        '"${cooText.replaceAll('"', '""')}"',
        '"${inspText.replaceAll('"', '""')}"',
        '"${permitText.replaceAll('"', '""')}"',
        '"${techText.replaceAll('"', '""')}"',
        '"${r.sailingStatus.replaceAll('"', '""')}"',
        '"${r.overallStatus.replaceAll('"', '""')}"',
        '"${r.riskLevel.replaceAll('"', '""')}"',
        '"${r.assessedBy.replaceAll('"', '""')}"',
        '"${(r.assessmentNotes ?? '').replaceAll('"', '""')}"',
      ].join(','));
    }

    final filename = 'Import_Requirements_${DateTime.now().millisecondsSinceEpoch}.csv';
    return FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: isAr ? 'تصدير دراسات المتطلبات الرقابية بصيغة إكسيل' : 'Export Regulatory Requirements to Excel',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static Future<void> printOrSaveImportRequirementsListPdf(BuildContext context, List<ImportRequirementModel> reqs, {bool isAr = true}) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context ctx) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isAr ? 'نظام سرور للخدمات اللوجستية — سجل تقييمات المتطلبات والموافقات التنظيمية' : 'Sorour Logistics ERP — Regulatory Requirements & Pre-Shipment Compliance Registry',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            isAr ? 'تقرير شامل بالمتطلبات الرقابية، قرار ٤٣، الفحص المسبق، والتصريح بالإبحار' : 'Comprehensive regulatory compliance, Decree 43, inspection, and sailing clearance report',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8),
                          ),
                        ],
                      ),
                      pw.Text(
                        '${reqs.length} ${isAr ? "تقييم مسجل" : "Records"}',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.0),
                    1: const pw.FlexColumnWidth(2.2),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(2.0),
                    4: const pw.FlexColumnWidth(2.2),
                    5: const pw.FlexColumnWidth(2.2),
                    6: const pw.FlexColumnWidth(2.2),
                    7: const pw.FlexColumnWidth(1.8),
                    8: const pw.FlexColumnWidth(1.6),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#3498DB')),
                      children: [
                        _pdfReqHeaderCell(isAr ? 'كود التقييم' : 'Assessment', isAr),
                        _pdfReqHeaderCell(isAr ? 'ملف الشحنة' : 'Import File', isAr),
                        _pdfReqHeaderCell(isAr ? 'بند التعريفة' : 'HS Code', isAr),
                        _pdfReqHeaderCell(isAr ? 'قرار ٤٣' : 'Decree 43', isAr),
                        _pdfReqHeaderCell(isAr ? 'شهادة المنشأ' : 'COO', isAr),
                        _pdfReqHeaderCell(isAr ? 'فحص ما قبل الشحن' : 'Inspection', isAr),
                        _pdfReqHeaderCell(isAr ? 'الموافقات' : 'Permits', isAr),
                        _pdfReqHeaderCell(isAr ? 'الإبحار' : 'Sailing', isAr),
                        _pdfReqHeaderCell(isAr ? 'الحالة' : 'Status', isAr),
                      ],
                    ),
                    ...reqs.map((r) {
                      final decreeText = r.decree43Applicable
                          ? (r.whiteListVerified ? (isAr ? 'معتمد' : 'Verified') : (isAr ? 'غير مسجل' : 'Not Reg'))
                          : (isAr ? 'معفى' : 'N/A');
                      return pw.TableRow(
                        children: [
                          _pdfReqDataCell(r.assessmentCode, isAr),
                          _pdfReqDataCell(r.importFileCode ?? '-', isAr),
                          _pdfReqDataCell(r.hsCode ?? '-', isAr),
                          _pdfReqDataCell(decreeText, isAr),
                          _pdfReqDataCell(r.cooRequired ? r.cooStatus : (isAr ? 'معفى' : 'N/A'), isAr),
                          _pdfReqDataCell(r.inspectionRequired ? r.inspectionStatus : (isAr ? 'معفى' : 'N/A'), isAr),
                          _pdfReqDataCell(r.importPermitRequired ? r.permitStatus : (isAr ? 'معفى' : 'N/A'), isAr),
                          _pdfReqDataCell(r.sailingStatus, isAr),
                          _pdfReqDataCell(r.overallStatus, isAr),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isAr ? 'وثيقة تنظيمية رسمية — معتمدة من إدارة الالتزام الجمركي والاستيراد' : 'Official regulatory document — Approved by Customs & Import Compliance Dept',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      '${isAr ? "تاريخ الطباعة" : "Printed"}: ${DateTime.now().toString().split(".")[0]}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename = 'Import_Requirements_Registry_${DateTime.now().millisecondsSinceEpoch}.pdf';
    if (!context.mounted) return;
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: bytes,
      defaultFileName: filename,
      dialogTitle: isAr ? 'تصدير سجل المتطلبات بصيغة بي دي إف' : 'Export Requirements as PDF',
      allowedExtensions: ['pdf'],
    );
  }

  static Future<void> printOrSaveImportRequirementSlipPdf(BuildContext context, ImportRequirementModel req, {bool isAr = true}) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context ctx) {
          return pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isAr ? 'Sorour Logistics ERP — إشعار استيفاء المتطلبات التنظيمية وما قبل الشحن' : 'Sorour Logistics ERP — Pre-Shipment Regulatory Compliance Slip',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            isAr ? 'وثيقة رسمية توثق مطابقة المحاور الرقابية الخمسة والتصريح بالإبحار' : 'Official compliance slip verifying 5 regulatory pillars and sailing readiness',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#3498DB'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          req.assessmentCode,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Shipment Dossier Metadata
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "ملف الشحنة" : "Import File"}: ${req.importFileCode ?? "-"}', style: const pw.TextStyle(fontSize: 9.5))),
                          pw.Expanded(child: pw.Text('${isAr ? "رقم القيد المسبق" : "ACID No"}: ${req.acidNumber ?? (isAr ? "لم يصدر بعد" : "Not Issued")}', style: const pw.TextStyle(fontSize: 9.5))),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "بند التعريفة الجمركية" : "HS Code"}: ${req.hsCode ?? "-"}', style: const pw.TextStyle(fontSize: 9.5))),
                          pw.Expanded(child: pw.Text('${isAr ? "القيمة المصرحة" : "Value"}: ${req.shipmentValue.toStringAsFixed(2)} ${req.currency}', style: const pw.TextStyle(fontSize: 9.5))),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "المورد الخارجي" : "Supplier"}: ${req.supplierName ?? "-"}', style: const pw.TextStyle(fontSize: 9.5))),
                          pw.Expanded(child: pw.Text('${isAr ? "بلد المنشأ والتصدير" : "Origin"}: ${req.countryOfOrigin ?? "-"}', style: const pw.TextStyle(fontSize: 9.5))),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // 5 Pillars Checklist Table
                pw.Text(
                  isAr ? 'مصفوفة استيفاء ومطابقة المحاور الرقابية الخمسة:' : '5 Regulatory Pillars Compliance Matrix:',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(2.0),
                    3: const pw.FlexColumnWidth(3.0),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#27AE60')),
                      children: [
                        _pdfReqHeaderCell(isAr ? 'المحور الرقابي' : 'Regulatory Pillar', isAr),
                        _pdfReqHeaderCell(isAr ? 'الاشتراط / الجهة' : 'Requirement / Authority', isAr),
                        _pdfReqHeaderCell(isAr ? 'حالة الاستيفاء' : 'Compliance Status', isAr),
                        _pdfReqHeaderCell(isAr ? 'البيان / المستند المرجعي' : 'Reference / Notes', isAr),
                      ],
                    ),
                    // Pillar 1: Decree 43
                    pw.TableRow(
                      children: [
                        _pdfReqDataCell(isAr ? '١. قرار ٤٣ تسجيل المصانع' : '1. Decree 43 Whitelist', isAr),
                        _pdfReqDataCell(req.decree43Applicable ? (isAr ? 'خاضع لقرار ٤٣' : 'Decree 43 Applicable') : (isAr ? 'معفى / غير خاضع' : 'Exempted'), isAr),
                        _pdfReqDataCell(req.decree43Applicable ? (req.whiteListVerified ? (isAr ? 'مسجل ومعتمد' : 'Verified') : (isAr ? 'قيد المتابعة / مستثنى' : 'Pending / Justified')) : (isAr ? 'معفى' : 'N/A'), isAr),
                        _pdfReqDataCell(req.factoryRegistrationNo ?? req.decree43Justification ?? '-', isAr),
                      ],
                    ),
                    // Pillar 2: COO
                    pw.TableRow(
                      children: [
                        _pdfReqDataCell(isAr ? '٢. شهادة المنشأ والاتفاقيات' : '2. Certificate of Origin', isAr),
                        _pdfReqDataCell(req.cooRequired ? (req.cooType ?? "COO") : (isAr ? 'غير مطلوبة' : 'Not Required'), isAr),
                        _pdfReqDataCell(req.cooRequired ? req.cooStatus : (isAr ? 'معفى' : 'N/A'), isAr),
                        _pdfReqDataCell(req.cooNotes ?? '-', isAr),
                      ],
                    ),
                    // Pillar 3: Inspection
                    pw.TableRow(
                      children: [
                        _pdfReqDataCell(isAr ? '٣. فحص ما قبل الشحن' : '3. Pre-Shipment Inspection', isAr),
                        _pdfReqDataCell(req.inspectionRequired ? (req.inspectionBody ?? "SGS") : (isAr ? 'غير مطلوب' : 'Not Required'), isAr),
                        _pdfReqDataCell(req.inspectionRequired ? req.inspectionStatus : (isAr ? 'معفى' : 'N/A'), isAr),
                        _pdfReqDataCell(req.inspectionReportNo ?? req.inspectionNotes ?? '-', isAr),
                      ],
                    ),
                    // Pillar 4: Permits
                    pw.TableRow(
                      children: [
                        _pdfReqDataCell(isAr ? '٤. الموافقات والتصاريح' : '4. Regulatory Permits', isAr),
                        _pdfReqDataCell(req.importPermitRequired ? (req.permitIssuingAuthority ?? "Authority") : (isAr ? 'غير مطلوب' : 'Not Required'), isAr),
                        _pdfReqDataCell(req.importPermitRequired ? req.permitStatus : (isAr ? 'معفى' : 'N/A'), isAr),
                        _pdfReqDataCell(req.permitNumber ?? req.permitNotes ?? '-', isAr),
                      ],
                    ),
                    // Pillar 5: Tech Certs & Sailing
                    pw.TableRow(
                      children: [
                        _pdfReqDataCell(isAr ? '٥. الشهادات الفنية والإبحار' : '5. Tech Certs & Sailing', isAr),
                        _pdfReqDataCell('${isAr ? "الإبحار" : "Sailing"}: ${req.sailingStatus}', isAr),
                        _pdfReqDataCell(req.overallStatus, isAr),
                        _pdfReqDataCell('${isAr ? "تقييم المخاطر" : "Risk"}: ${req.riskLevel}', isAr),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Notes & Assessment Sign-off
                if (req.assessmentNotes != null && req.assessmentNotes!.isNotEmpty) ...[
                  pw.Text(isAr ? 'ملاحظات وتوصيات التقييم:' : 'Assessment Notes & Recommendations:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(req.assessmentNotes!, style: const pw.TextStyle(fontSize: 8.5)),
                  ),
                  pw.SizedBox(height: 10),
                ],

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${isAr ? "المقيّم المسؤول" : "Assessed By"}: ${req.assessedBy}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50'))),
                    pw.Text('${isAr ? "تاريخ التقييم" : "Date"}: ${req.createdAt.toString().split(".")[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    pw.Text(isAr ? 'سرور للخدمات اللوجستية — نظام الالتزام الاستيرادي' : 'Sorour Logistics ERP System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'RequirementSlip_${req.assessmentCode}.pdf',
    );
  }

  static String generateImportRequirementWhatsAppText(ImportRequirementModel req, {bool isAr = true}) {
    if (isAr) {
      return '''
*نظام إدارة الاستيراد واللوجستيات — إشعار دراسة المتطلبات الرقابية*
📋 *كود التقييم:* ${req.assessmentCode}
📁 *ملف الشحنة:* ${req.importFileCode ?? "-"}
🔢 *بند التعريفة:* ${req.hsCode ?? "-"} (${req.commodityDescription ?? "-"})
💰 *القيمة:* ${req.shipmentValue.toStringAsFixed(2)} ${req.currency}
🚢 *حالة الإبحار:* ${req.sailingStatus}
🛡️ *مستوى المخاطر:* ${req.riskLevel}
📊 *الحالة العامة:* ${req.overallStatus}
_تم الإنشاء عبر نظام سرور للخدمات اللوجستية_
'''.trim();
    } else {
      return '''
*Sorour Logistics ERP — Pre-Shipment Regulatory Compliance Summary*
📋 *Assessment Code:* ${req.assessmentCode}
📁 *Import File:* ${req.importFileCode ?? "-"}
🔢 *HS Code:* ${req.hsCode ?? "-"} (${req.commodityDescription ?? "-"})
💰 *Value:* ${req.shipmentValue.toStringAsFixed(2)} ${req.currency}
🚢 *Sailing Status:* ${req.sailingStatus}
🛡️ *Risk Level:* ${req.riskLevel}
📊 *Overall Status:* ${req.overallStatus}
_Generated via Sorour Logistics ERP_
'''.trim();
    }
  }

  static String generateImportRequirementEmailSubject(ImportRequirementModel req, {bool isAr = true}) {
    return isAr
        ? 'دراسة المتطلبات الرقابية للشحنة [${req.assessmentCode}] — ${req.importFileCode ?? ""}'
        : 'Regulatory Compliance Assessment [${req.assessmentCode}] — ${req.importFileCode ?? ""}';
  }

  static String generateImportRequirementEmailBody(ImportRequirementModel req, {bool isAr = true}) {
    return generateImportRequirementWhatsAppText(req, isAr: isAr);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. DEMURRAGE, DETENTION & PORT STORAGE (غرامات الحاويات وأرضيات الموانئ)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> exportDemurrageTrackingsToExcel(
    BuildContext context,
    List<DemurrageTrackingModel> trackings, {
    bool isAr = true,
  }) async {
    final headers = [
      isAr ? 'كود التتبع' : 'Tracking Code',
      isAr ? 'رقم بوليصة الشحن' : 'Bill of Lading No',
      isAr ? 'الخط الملاحي' : 'Shipping Line',
      isAr ? 'ميناء الوصول' : 'Arrival Port',
      isAr ? 'تاريخ التفريغ' : 'Discharge Date',
      isAr ? 'تاريخ خروج البوابة' : 'Gate-Out Date',
      isAr ? 'تاريخ إرجاع الفارغ' : 'Empty Return Date',
      isAr ? 'عدد الحاويات' : 'Containers Count',
      isAr ? 'غرامات الخط (عملة أجنبية)' : 'Demurrage Fee (FX)',
      isAr ? 'غرامات التأخير (عملة أجنبية)' : 'Detention Fee (FX)',
      isAr ? 'أرضيات الميناء (جنيه)' : 'Port Storage (EGP)',
      isAr ? 'العملة' : 'Currency',
      isAr ? 'سعر الصرف' : 'Exchange Rate',
      isAr ? 'إجمالي التكلفة التقديرية (جنيه)' : 'Total Cost (EGP)',
      isAr ? 'حالة التتبع' : 'Status',
      isAr ? 'مرحل للتسوية' : 'Pushed to Settlement',
    ];

    final rows = trackings.map((t) {
      return [
        t.trackingCode,
        t.billOfLadingNo,
        t.carrierName,
        t.portName,
        t.dischargeDate,
        t.gateOutDate ?? (isAr ? 'لم تخرج بعد' : 'Not Gated Out'),
        t.emptyReturnDate ?? (isAr ? 'لم تُعد بعد' : 'Not Returned'),
        t.containers.length.toString(),
        t.totalDemurrageFx.toStringAsFixed(2),
        t.totalDetentionFx.toStringAsFixed(2),
        t.totalStorageEgp.toStringAsFixed(2),
        t.currency,
        t.exchangeRate.toStringAsFixed(2),
        t.totalCostEgp.toStringAsFixed(2),
        t.status,
        t.isPushedToSettlement ? (isAr ? 'نعم' : 'Yes') : (isAr ? 'لا' : 'No'),
      ];
    }).toList();

    final csvContent = StringBuffer();
    csvContent.writeln('\uFEFF${headers.map((h) => '"$h"').join(',')}');
    for (final r in rows) {
      csvContent.writeln(r.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }

    final filename = 'Demurrage_Trackings_${DateTime.now().millisecondsSinceEpoch}.csv';
    if (!context.mounted) return;
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: csvContent.toString().codeUnits,
      defaultFileName: filename,
      dialogTitle: isAr ? 'تصدير جلسات تتبع الحاويات' : 'Export Container Trackings',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static Future<void> printOrSaveDemurrageTrackingsListPdf(
    BuildContext context,
    List<DemurrageTrackingModel> trackings, {
    bool isAr = true,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final totalCost = trackings.fold<double>(0.0, (sum, t) => sum + t.totalCostEgp);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context ctx) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isAr ? 'نظام سرور للخدمات اللوجستية — كشف ومتابعة غرامات الحاويات وأرضيات الموانئ' : 'Sorour Logistics ERP — Demurrage, Detention & Port Storage Registry',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            isAr ? 'تقرير حي بفترات السماح، تواريخ خروج البوابة، إرجاع الفارغ، والتكلفة التقديرية بالجنيه' : 'Live tracking report for container free-time, gate-out milestones, and accrued charges in EGP',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8),
                          ),
                        ],
                      ),
                      pw.Text(
                        '${trackings.length} ${isAr ? "جلسة تتبع" : "Trackings"}  •  ${isAr ? "الإجمالي" : "Total"}: ${totalCost.toStringAsFixed(0)} ${isAr ? "ج.م" : "EGP"}',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.6),
                    1: const pw.FlexColumnWidth(1.8),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.6),
                    4: const pw.FlexColumnWidth(1.3),
                    5: const pw.FlexColumnWidth(1.3),
                    6: const pw.FlexColumnWidth(1.3),
                    7: const pw.FlexColumnWidth(0.9),
                    8: const pw.FlexColumnWidth(1.8),
                    9: const pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#3498DB')),
                      children: [
                        _pdfDemHeaderCell(isAr ? 'كود التتبع' : 'Tracking Code', isAr),
                        _pdfDemHeaderCell(isAr ? 'البوليصة' : 'B/L No', isAr),
                        _pdfDemHeaderCell(isAr ? 'الخط الملاحي' : 'Carrier', isAr),
                        _pdfDemHeaderCell(isAr ? 'ميناء الوصول' : 'Port', isAr),
                        _pdfDemHeaderCell(isAr ? 'التفريغ' : 'Discharge', isAr),
                        _pdfDemHeaderCell(isAr ? 'الخروج' : 'Gate-Out', isAr),
                        _pdfDemHeaderCell(isAr ? 'إعادة الفارغ' : 'Return', isAr),
                        _pdfDemHeaderCell(isAr ? 'العدد' : 'Qty', isAr),
                        _pdfDemHeaderCell(isAr ? 'إجمالي التكلفة' : 'Total Cost', isAr),
                        _pdfDemHeaderCell(isAr ? 'الحالة' : 'Status', isAr),
                      ],
                    ),
                    ...trackings.map((t) {
                      return pw.TableRow(
                        children: [
                          _pdfDemDataCell(t.trackingCode, isAr),
                          _pdfDemDataCell(t.billOfLadingNo, isAr),
                          _pdfDemDataCell(t.carrierName, isAr),
                          _pdfDemDataCell(t.portName, isAr),
                          _pdfDemDataCell(t.dischargeDate, isAr),
                          _pdfDemDataCell(t.gateOutDate ?? '-', isAr),
                          _pdfDemDataCell(t.emptyReturnDate ?? '-', isAr),
                          _pdfDemDataCell(t.containers.length.toString(), isAr),
                          _pdfDemDataCell('${t.totalCostEgp.toStringAsFixed(2)} ${isAr ? "ج.م" : "EGP"}', isAr, color: t.totalCostEgp > 0 ? PdfColor.fromHex('#C0392B') : PdfColor.fromHex('#27AE60')),
                          _pdfDemDataCell(t.status, isAr),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isAr ? 'كشف معتمد من إدارة العمليات اللوجستية والحسابات' : 'Certified operational demurrage report — Sorour Logistics ERP',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      '${isAr ? "تاريخ الطباعة" : "Printed"}: ${DateTime.now().toString().split(".")[0]}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final filename = 'Demurrage_Trackings_${DateTime.now().millisecondsSinceEpoch}.pdf';
    if (!context.mounted) return;
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: bytes,
      defaultFileName: filename,
      dialogTitle: isAr ? 'تصدير كشف المتابعة بصيغة بي دي إف' : 'Export Demurrage List as PDF',
      allowedExtensions: ['pdf'],
    );
  }

  static Future<void> printOrSaveDemurrageTrackingSlipPdf(
    BuildContext context,
    DemurrageTrackingModel tracking, {
    bool isAr = true,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        build: (pw.Context ctx) {
          return pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            isAr ? 'Sorour Logistics ERP — إذن احتساب غرامات وأرضيات الحاويات' : 'Sorour Logistics ERP — Demurrage & Port Storage Slip',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            isAr ? 'وثيقة احتساب معتمدة ومطابقة لسياسات الخط الملاحي وهيئة الميناء' : 'Official calculation slip verified against carrier tariffs and port storage tiers',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#3498DB'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          tracking.trackingCode,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Shipment Metadata Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "رقم بوليصة الشحن" : "Bill of Lading"}: ${tracking.billOfLadingNo}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(child: pw.Text('${isAr ? "الخط الملاحي" : "Shipping Line"}: ${tracking.carrierName}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "ميناء الوصول" : "Arrival Port"}: ${tracking.portName}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('${isAr ? "تاريخ التفريغ" : "Discharge Date"}: ${tracking.dischargeDate}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "خروج البوابة" : "Gate-Out"}: ${tracking.gateOutDate ?? (isAr ? "لم تخرج بعد" : "Not Gated Out")}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('${isAr ? "إعادة الفارغ" : "Empty Return"}: ${tracking.emptyReturnDate ?? (isAr ? "لم تُعد بعد" : "Not Returned")}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text('${isAr ? "عدد الحاويات" : "Containers Count"}: ${tracking.containers.length}', style: const pw.TextStyle(fontSize: 10))),
                          pw.Expanded(child: pw.Text('${isAr ? "سعر الصرف المعتمد" : "Exchange Rate"}: ${tracking.exchangeRate.toStringAsFixed(2)} ${isAr ? "ج.م/\$" : "EGP/\$"}', style: const pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // Containers Breakdown Table
                pw.Text(
                  isAr ? 'بيان تفصيلي للحاويات المسجلة والغرامات المحتسبة:' : 'Registered Containers & Accrued Demurrage Breakdown:',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(2.0),
                    2: const pw.FlexColumnWidth(1.8),
                    3: const pw.FlexColumnWidth(1.8),
                    4: const pw.FlexColumnWidth(2.0),
                    5: const pw.FlexColumnWidth(2.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#27AE60')),
                      children: [
                        _pdfDemHeaderCell(isAr ? 'رقم الحاوية' : 'Container No', isAr),
                        _pdfDemHeaderCell(isAr ? 'النوع' : 'Type', isAr),
                        _pdfDemHeaderCell(isAr ? 'أيام الأرضيات' : 'Demurrage', isAr),
                        _pdfDemHeaderCell(isAr ? 'أيام الفارغ' : 'Detention', isAr),
                        _pdfDemHeaderCell(isAr ? 'أيام التخزين' : 'Storage', isAr),
                        _pdfDemHeaderCell(isAr ? 'إجمالي الحاوية' : 'Container Total', isAr),
                      ],
                    ),
                    ...tracking.containers.map((c) {
                      final cNo = c is Map ? (c['container_no'] ?? '-') : '-';
                      final cType = c is Map ? (c['container_type'] ?? '-') : '-';
                      final demDays = c is Map ? (c['demurrage_days'] ?? 0) : 0;
                      final detDays = c is Map ? (c['detention_days'] ?? 0) : 0;
                      final storDays = c is Map ? (c['storage_days'] ?? 0) : 0;
                      final totalEgp = c is Map ? (c['total_egp'] ?? 0.0) : 0.0;
                      return pw.TableRow(
                        children: [
                          _pdfDemDataCell(cNo.toString(), isAr),
                          _pdfDemDataCell(cType.toString(), isAr),
                          _pdfDemDataCell('$demDays ${isAr ? "يوم" : "days"}', isAr),
                          _pdfDemDataCell('$detDays ${isAr ? "يوم" : "days"}', isAr),
                          _pdfDemDataCell('$storDays ${isAr ? "يوم" : "days"}', isAr),
                          _pdfDemDataCell('${(totalEgp as num).toStringAsFixed(2)} ${isAr ? "ج.م" : "EGP"}', isAr),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 14),

                // Cost Summary Breakdown
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(isAr ? 'غرامات أرضيات الخط الملاحي:' : 'Carrier Demurrage Fee:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${tracking.totalDemurrageFx.toStringAsFixed(2)} ${tracking.currency}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(isAr ? 'غرامات تأخير إعادة الفارغ:' : 'Carrier Detention Fee:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${tracking.totalDetentionFx.toStringAsFixed(2)} ${tracking.currency}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(isAr ? 'أرضيات ساحات هيئة الميناء:' : 'Port Storage Charges:', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${tracking.totalStorageEgp.toStringAsFixed(2)} ${isAr ? "ج.م" : "EGP"}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey400),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            isAr ? 'إجمالي التكلفة الشاملة المستحقة:' : 'Grand Total Payable Cost:',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C0392B')),
                          ),
                          pw.Text(
                            '${tracking.totalCostEgp.toStringAsFixed(2)} ${isAr ? "جنيه مصري" : "EGP"}',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C0392B')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Settlement status note
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: tracking.isPushedToSettlement ? PdfColor.fromHex('#E8F8F5') : PdfColor.fromHex('#FEF9E7'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: tracking.isPushedToSettlement ? PdfColor.fromHex('#27AE60') : PdfColor.fromHex('#F39C12')),
                  ),
                  child: pw.Text(
                    tracking.isPushedToSettlement
                        ? (isAr ? 'تم ترحيل هذا المصروف تلقائياً إلى تسوية التكلفة الإجمالية للشحنة (Landed Cost Settlement).' : 'This expense has been automatically pushed to Landed Cost Financial Settlement.')
                        : (isAr ? 'جلسة التتبع قيد المراجعة والمتابعة التشغيلية — لم يتم الترحيل النهائي للتسوية المالية بعد.' : 'Tracking session is in active review — Not yet pushed to Landed Cost Settlement.'),
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                  ),
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isAr ? 'قسم اللوجستيات وحسابات الشحن — اعتماد المحاسب المسؤول' : 'Logistics & Freight Accounting — Verified by Operations',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50')),
                    ),
                    pw.Text(
                      '${isAr ? "تاريخ الإصدار" : "Issued"}: ${DateTime.now().toString().split(".")[0]}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Sorour Logistics ERP System',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'DemurrageSlip_${tracking.trackingCode}.pdf',
    );
  }

  static String generateDemurrageTrackingWhatsAppText(DemurrageTrackingModel tracking, {bool isAr = true}) {
    if (isAr) {
      return '''
*نظام إدارة الاستيراد واللوجستيات — إشعار غرامات وأرضيات الحاويات*
📋 *كود التتبع:* ${tracking.trackingCode}
📦 *بوليصة الشحن:* ${tracking.billOfLadingNo}
🚢 *الخط الملاحي:* ${tracking.carrierName}
⚓ *ميناء الوصول:* ${tracking.portName}
📅 *تاريخ التفريغ:* ${tracking.dischargeDate}
🚚 *خروج البوابة:* ${tracking.gateOutDate ?? "لم تخرج بعد"}
🔄 *إعادة الفارغ:* ${tracking.emptyReturnDate ?? "لم تُعد بعد"}
🔢 *عدد الحاويات:* ${tracking.containers.length}
💰 *إجمالي الغرامات:* ${tracking.totalCostEgp.toStringAsFixed(2)} جنيه مصري
📊 *الحالة التشغيلية:* ${tracking.status}
_تم الإنشاء عبر نظام سرور للخدمات اللوجستية_
'''.trim();
    } else {
      return '''
*Sorour Logistics ERP — Demurrage & Port Storage Status Notice*
📋 *Tracking Code:* ${tracking.trackingCode}
📦 *Bill of Lading:* ${tracking.billOfLadingNo}
🚢 *Shipping Line:* ${tracking.carrierName}
⚓ *Arrival Port:* ${tracking.portName}
📅 *Discharge Date:* ${tracking.dischargeDate}
🚚 *Gate-Out:* ${tracking.gateOutDate ?? "Not Gated Out"}
🔄 *Empty Return:* ${tracking.emptyReturnDate ?? "Not Returned"}
🔢 *Containers Count:* ${tracking.containers.length}
💰 *Total Accrued Cost:* ${tracking.totalCostEgp.toStringAsFixed(2)} EGP
📊 *Status:* ${tracking.status}
_Generated via Sorour Logistics ERP_
'''.trim();
    }
  }

  static String generateDemurrageTrackingEmailSubject(DemurrageTrackingModel tracking, {bool isAr = true}) {
    return isAr
        ? 'تقرير غرامات وأرضيات الشحنة [${tracking.trackingCode}] — بوليصة: ${tracking.billOfLadingNo}'
        : 'Demurrage & Storage Calculation [${tracking.trackingCode}] — B/L: ${tracking.billOfLadingNo}';
  }

  static String generateDemurrageTrackingEmailBody(DemurrageTrackingModel tracking, {bool isAr = true}) {
    return generateDemurrageTrackingWhatsAppText(tracking, isAr: isAr);
  }

  static Future<void> exportDemurragePoliciesToExcel(
    BuildContext context,
    List<DemurragePolicyModel> policies, {
    bool isAr = true,
  }) async {
    final headers = [
      isAr ? 'الخط الملاحي' : 'Shipping Line',
      isAr ? 'نوع الحاوية' : 'Container Type',
      isAr ? 'سماح الأرضيات (يوم)' : 'Demurrage Free Days',
      isAr ? 'سماح الفارغ (يوم)' : 'Detention Free Days',
      isAr ? 'سماح تخزين الميناء (يوم)' : 'Port Storage Free Days',
      isAr ? 'رسم التخزين اليومي (جنيه)' : 'Daily Storage Rate (EGP)',
      isAr ? 'العملة' : 'Currency',
    ];

    final rows = policies.map((p) {
      return [
        p.carrierName,
        p.containerType,
        p.demurrageFreeDays.toString(),
        p.detentionFreeDays.toString(),
        p.portStorageFreeDays.toString(),
        p.portStorageDailyRateEgp.toStringAsFixed(2),
        p.currency,
      ];
    }).toList();

    final csvContent = StringBuffer();
    csvContent.writeln('\uFEFF${headers.map((h) => '"$h"').join(',')}');
    for (final r in rows) {
      csvContent.writeln(r.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }

    final filename = 'Carrier_Demurrage_Policies_${DateTime.now().millisecondsSinceEpoch}.csv';
    if (!context.mounted) return;
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: csvContent.toString().codeUnits,
      defaultFileName: filename,
      dialogTitle: isAr ? 'تصدير سياسات الخطوط الملاحية' : 'Export Carrier Policies',
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  static pw.Widget _pdfDemHeaderCell(String text, bool isAr) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      alignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
      ),
    );
  }

  static pw.Widget _pdfDemDataCell(String text, bool isAr, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      alignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7.5, color: color ?? PdfColors.black),
      ),
    );
  }
}

