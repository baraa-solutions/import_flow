import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../services/draft_bl_export_service.dart';

class VisualDraftBLSheet extends StatelessWidget {
  final Map<String, dynamic> systemData;
  final Map<String, dynamic> draftData;
  final String? draftBlNumber;
  final String? bookingNumber;
  final String? title;
  final String? subtitle;
  final bool isReferenceOnly;
  final VoidCallback? onRefresh;

  const VisualDraftBLSheet({
    super.key,
    required this.systemData,
    required this.draftData,
    this.draftBlNumber,
    this.bookingNumber,
    this.title,
    this.subtitle,
    this.isReferenceOnly = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Printed-document replica: always left-to-right, whatever the UI language.
    return Directionality(textDirection: TextDirection.ltr, child: _buildSheet(context));
  }

  Widget _buildSheet(BuildContext context) {
    final blNo = (draftData['draft_bl_number'] ?? draftBlNumber ?? systemData['draft_bl_number'] ?? 'DRAFT-BL').toString();
    final bkgNo = (draftData['booking_no'] ?? bookingNumber ?? systemData['booking_no'] ?? 'BKG-REF').toString();
    final shipper = (draftData['shipper'] ?? systemData['shipper'] ?? 'EXPORTER / SUPPLIER').toString();
    final consignee = (draftData['consignee'] ?? systemData['consignee'] ?? 'IMPORTER / CONSIGNEE').toString();
    final notifyParty = (draftData['notify_party'] ?? systemData['notify_party'] ?? consignee).toString();
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
    final countryCode = (draftData['shipper_country_code'] ?? systemData['shipper_country_code'] ?? '').toString();

    final goodsDesc = (draftData['goods_description'] ?? systemData['goods_description'] ?? 'GENERAL MERCHANDISE & IMPORT GOODS').toString();
    String formatWeight(dynamic val) {
      if (val == null) return '0.00';
      final d = val is num ? val.toDouble() : double.tryParse(val.toString());
      if (d == null) return val.toString();
      return (d % 1 == 0) ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
    }

    final grossWeight = formatWeight(draftData['total_gross_weight_kg'] ?? systemData['total_gross_weight_kg']);
    final netWeight = formatWeight(draftData['total_net_weight_kg'] ?? systemData['total_net_weight_kg']);
    final cbm = (draftData['cbm'] ?? systemData['cbm'] ?? '0.00').toString();
    final pkgCount = (draftData['qty_pkg'] ?? systemData['packages_count'] ?? '0').toString();
    final containerSummary = (draftData['container_summary'] ?? systemData['container_summary'] ?? 'N/A').toString();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Toolbar: Actions & Download Buttons
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isReferenceOnly ? Icons.hub_rounded : Icons.description_rounded, color: isReferenceOnly ? AppTheme.cobalt : AppTheme.charcoal, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title ?? (isReferenceOnly
                                  ? context.l10n.draftBlReferenceVisualSheetTitle
                                  : context.l10n.draftBlExtractedVisualSheetTitle),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                            ),
                            Text(
                              subtitle ?? (isReferenceOnly
                                  ? context.l10n.draftBlReferenceVisualSheetSub
                                  : context.l10n.draftBlExtractedVisualSheetSub),
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textStrong),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (onRefresh != null)
                      AppButton(label: context.l10n.refresh, onPressed: onRefresh, variant: AppButtonVariant.secondary, icon: Icons.refresh),
                    // 1. PRINT BUTTON (طباعة البوليصة)
                    AppButton(label: context.l10n.draftBlPrintButton, onPressed: () async {
                        try {
                          await DraftBLExportService.printDraftBL(
                            systemData: systemData,
                            draftData: draftData,
                            draftBlNumber: draftBlNumber,
                            bookingNumber: bookingNumber,
                            documentTitle: isReferenceOnly
                                ? 'SYSTEM REFERENCE BILL OF LADING — NOT NEGOTIABLE'
                                : 'BILL OF LADING (DRAFT — NOT NEGOTIABLE)',
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.draftBlPrintError(e)), backgroundColor: AppTheme.crimson),
                            );
                          }
                        }
                      }, icon: Icons.print),
                    // 2. PDF BUTTON (تنزيل PDF)
                    AppButton(label: context.l10n.draftBlDownloadPdfButton, onPressed: () async {
                        try {
                          await DraftBLExportService.exportDraftBLToPdf(
                            context: context,
                            systemData: systemData,
                            draftData: draftData,
                            draftBlNumber: draftBlNumber,
                            bookingNumber: bookingNumber,
                            documentTitle: isReferenceOnly
                                ? 'SYSTEM REFERENCE BILL OF LADING — NOT NEGOTIABLE'
                                : 'BILL OF LADING (DRAFT — NOT NEGOTIABLE)',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.draftBlPdfExportSuccess), backgroundColor: AppTheme.emerald),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.draftBlPdfExportError(e)), backgroundColor: AppTheme.crimson),
                            );
                          }
                        }
                      }, variant: AppButtonVariant.danger, icon: Icons.picture_as_pdf),
                    // 3. EXCEL BUTTON (تنزيل Excel / CSV)
                    AppButton(label: context.l10n.draftBlDownloadExcelButton, onPressed: () async {
                        try {
                          final res = await DraftBLExportService.exportDraftBLToExcel(
                            systemData: systemData,
                            draftData: draftData,
                            draftBlNumber: draftBlNumber,
                            bookingNumber: bookingNumber,
                          );
                          if (context.mounted && res != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.excelExportSuccess(res)), backgroundColor: AppTheme.emerald),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.excelExportError(e)), backgroundColor: AppTheme.crimson),
                            );
                          }
                        }
                      }, variant: AppButtonVariant.success, icon: Icons.table_chart),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Authentic B/L Container Sheet
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 850),
                child: Container(
                  width: 850,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    border: Border.all(color: AppTheme.textPrimary, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: AppTheme.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header Banner
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: AppTheme.surfaceAlt,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BILL OF LADING (DRAFT)',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.8, color: AppTheme.charcoal),
                                  ),
                                  Text(
                                    'NON-NEGOTIABLE — FOR DRAFT & REFERENCE REVIEW ONLY',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                CopyableText('B/L NO: $blNo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                CopyableText('BOOKING REF: $bkgNo', style: const TextStyle(fontSize: 11, color: AppTheme.charcoal)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1.2, color: AppTheme.textPrimary),

                      // 2. Shipper & Carrier Agent Row
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Shipper
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SHIPPER / EXPORTER:', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textStrong)),
                                    const SizedBox(height: 4),
                                    CopyableText(shipper, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                            // Carrier Endorsement
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("CARRIER'S AGENTS ENDORSEMENTS:", style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textStrong)),
                                    SizedBox(height: 4),
                                    Text("SHIPPER'S LOAD, STOW AND COUNT; FCL/FCL; SAID TO CONTAIN", style: TextStyle(fontSize: 11.0)),
                                    Text("Standard International Maritime Carrier Endorsement", style: TextStyle(fontSize: 11.0)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppTheme.textPrimary),

                      // 3. Consignee & POD Agent Row
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Consignee
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CONSIGNEE:', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textStrong)),
                                    const SizedBox(height: 4),
                                    CopyableText(consignee, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                            // POD Agent
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PORT OF DISCHARGE AGENT:', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textStrong)),
                                    const SizedBox(height: 4),
                                    CopyableText(pod, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppTheme.textPrimary),

                      // 4. Notify Party
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NOTIFY PARTY:', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textStrong)),
                            const SizedBox(height: 4),
                            CopyableText(notifyParty, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppTheme.textPrimary),

                      // 5. Transit Details Row
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            _buildCell('VESSEL AND VOYAGE NO', '$vessel — $voyage', flex: 2),
                            _buildCell('PORT OF LOADING (POL)', pol, flex: 2),
                            _buildCell('PORT OF DISCHARGE (POD)', pod, flex: 2),
                            _buildCell('PLACE OF DELIVERY', placeOfDelivery, flex: 2),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1.2, color: AppTheme.textPrimary),

                      // 6. Section Banner
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        color: AppTheme.border,
                        child: const Text(
                          'PARTICULARS FURNISHED BY THE SHIPPER — NOT CHECKED BY CARRIER — CARRIER NOT RESPONSIBLE',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppTheme.textPrimary),

                      // 7. Table Header
                      Container(
                        color: AppTheme.surfaceAlt,
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              _buildTableHead('Container Numbers, Seal Numbers', flex: 2),
                              _buildTableHead('Description of Packages and Goods (Egyptian ACID Block)', flex: 4),
                              _buildTableHead('Gross Cargo Weight', flex: 2),
                              _buildTableHead('Measurement', flex: 1),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppTheme.textPrimary),

                      // 8. Particulars Body
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Container & Seals
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CopyableText(containerSummary, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    const Text('Marks & Numbers: N/A', style: TextStyle(fontSize: 11.0, color: AppTheme.textStrong)),
                                    const Text('FCL / FCL', style: TextStyle(fontSize: 11.0, color: AppTheme.textStrong)),
                                  ],
                                ),
                              ),
                            ),
                            // Description & ACID Block
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CopyableText('$pkgCount Packages / $goodsDesc', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),

                                    // Egyptian Customs ACID Box
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.infoBackground,
                                        border: Border.all(color: AppTheme.cobaltBorder),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.verified, size: 14, color: AppTheme.cobalt),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'EGYPTIAN CUSTOMS ADVANCED INFORMATION (ACID BLOCK):',
                                                  style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          SelectableText('ACID: $acid', style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                          SelectableText('EGYPTIAN IMPORTER TAX ID: $taxId', style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                          SelectableText('SHIPPER REGISTRATION TYPE: $regType', style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                                          SelectableText('SHIPPER ID: $regId', style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                                          SelectableText('SHIPPER COUNTRY: $country (CODE: $countryCode)', style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    CopyableText(
                                      freightTerms,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Gross Weight
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    CopyableText('$grossWeight KGS', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    CopyableText('Net: $netWeight KGS', style: const TextStyle(fontSize: 11.0, color: AppTheme.textStrong)),
                                  ],
                                ),
                              ),
                            ),
                            // Measurement
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    CopyableText('$cbm CBM', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1.2, color: AppTheme.textPrimary),

                      // 9. Total Summary Row
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: AppTheme.surfaceAlt,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            CopyableText('Total Items: $pkgCount Packages', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            CopyableText('Total Gross Weight: $grossWeight KGS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            CopyableText('Total Measurement: $cbm CBM', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            CopyableText('Freight: $freightTerms', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson)),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppTheme.textPrimary),

                      // 10. Footer Signatures & Date
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sorour Logistics ERP Draft B/L Certification Engine', style: TextStyle(fontSize: 11.0, color: AppTheme.textMuted)),
                                Text('Generated: ${DateTime.now().toLocal().toString().substring(0, 19)}', style: const TextStyle(fontSize: 11.0, color: AppTheme.textMuted)),
                              ],
                            ),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('SIGNED FOR THE CARRIER / AGENT:', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text('OCEAN CARRIER / Authorized Agent', style: TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String title, String val, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textStrong)),
            const SizedBox(height: 2),
            CopyableText(val, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHead(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          border: BorderDirectional(end: BorderSide(color: AppTheme.textPrimary, width: 1)),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
