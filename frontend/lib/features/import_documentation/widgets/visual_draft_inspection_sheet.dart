import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../services/inspection_export_service.dart';

class VisualDraftInspectionSheet extends StatefulWidget {
  final Map<String, dynamic> templateData;
  final String agency;
  final String certType;
  final String acidNumber;
  final List<String> standards;
  final VoidCallback? onRefresh;

  const VisualDraftInspectionSheet({
    super.key,
    required this.templateData,
    required this.agency,
    required this.certType,
    required this.acidNumber,
    required this.standards,
    this.onRefresh,
  });

  @override
  State<VisualDraftInspectionSheet> createState() => _VisualDraftInspectionSheetState();
}

class _VisualDraftInspectionSheetState extends State<VisualDraftInspectionSheet> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    // Printed-document replica: always left-to-right, whatever the UI language.
    return Directionality(textDirection: TextDirection.ltr, child: _buildSheet(context));
  }

  Widget _buildSheet(BuildContext context) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final t = widget.templateData;
    final cocNo = (t['coc_number'] ?? 'DRAFT-COC').toString();
    final importer = (t['importer_name_and_address'] ?? 'IMPORTER INFO').toString();
    final exporter = (t['exporter_name_and_address'] ?? 'EXPORTER INFO').toString();
    final origin = (t['country_of_origin'] ?? 'UNKNOWN').toString();
    final originsList = (t['countries_of_origin_list'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [origin];
    final hsCodes = (t['hs_code'] ?? '560229').toString();
    final hsCodesList = (t['hs_codes_list'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [hsCodes];
    final totalValue = (t['total_value'] ?? 'N/A').toString();
    final portOfEntry = (t['port_of_entry'] ?? 'Alexandria').toString();
    final dateInsp = (t['date_of_inspection'] ?? DateTime.now().toString().split(' ')[0]).toString();

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.security, color: AppTheme.cobalt, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.visualDraftInspectionToolbarTitle(widget.agency, widget.certType),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                  ),
                  const SizedBox(width: 16),
                  if (widget.onRefresh != null)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: AppTheme.cobalt),
                      tooltip: l10n.liveRefreshTooltip,
                      onPressed: widget.onRefresh,
                    ),
                  // 1. Export TSV Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppTheme.charcoal,
                    ),
                    icon: const Icon(Icons.table_chart_outlined, size: 14),
                    label: Text(l10n.exportTsvBtn, style: const TextStyle(fontSize: 11)),
                    onPressed: () => InspectionExportService.saveInspectionTsvToFile(
                      context: context,
                      templateData: t,
                      agency: widget.agency,
                      certType: widget.certType,
                      acidNumber: widget.acidNumber,
                      standards: widget.standards,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 2. Export Excel (CSV) Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.green.shade800,
                      side: BorderSide(color: Colors.green.shade600),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 14, color: Colors.green),
                    label: Text(l10n.saveExcelCsvBtn, style: const TextStyle(fontSize: 11)),
                    onPressed: () => InspectionExportService.saveInspectionCsvToFile(
                      context: context,
                      templateData: t,
                      agency: widget.agency,
                      certType: widget.certType,
                      acidNumber: widget.acidNumber,
                      standards: widget.standards,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 3. Print / Save PDF Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.crimson,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _isExporting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf, size: 14, color: Colors.white),
                    label: Text(l10n.savePrintPdfBtn, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: _isExporting
                        ? null
                        : () async {
                            setState(() => _isExporting = true);
                            try {
                              await InspectionExportService.printOrSavePdf(
                                context: context,
                                templateData: t,
                                agency: widget.agency,
                                certType: widget.certType,
                                acidNumber: widget.acidNumber,
                                standards: widget.standards,
                              );
                            } finally {
                              if (mounted) setState(() => _isExporting = false);
                            }
                          },
                  ),
                  const SizedBox(width: 8),
                  // 4. Copy Full Dossier Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppTheme.cobalt,
                      side: const BorderSide(color: AppTheme.cobalt),
                    ),
                    icon: const Icon(Icons.copy_all_outlined, size: 14, color: AppTheme.cobalt),
                    label: Text(l10n.copyDossierBtn, style: const TextStyle(fontSize: 11)),
                    onPressed: () => InspectionExportService.copyDossierToClipboard(
                      context,
                      templateData: t,
                      agency: widget.agency,
                      certType: widget.certType,
                      acidNumber: widget.acidNumber,
                      standards: widget.standards,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Official Visual Document Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black87, width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: const Border(bottom: BorderSide(color: Colors.black87, width: 1.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr
                                  ? 'شهادة المطابقة النوعية والتفتيش الفني — ${widget.agency}'
                                  : '${widget.agency.toUpperCase()} — CERTIFICATE OF CONFORMITY (COC / VOC)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.egyptVerificationOfConformityHeader,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.0, color: AppTheme.cobalt),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: isAr ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: [
                          CopyableText(
                            isAr ? l10n.cocNoPrefix(cocNo) : 'COC NO: $cocNo',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                            copyMessage: l10n.copiedToClipboardGeneric,
                          ),
                          CopyableText(
                            isAr ? l10n.acidNoPrefix(widget.acidNumber) : 'ACID NO: ${widget.acidNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green),
                            copyMessage: l10n.copiedToClipboardGeneric,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Parties Grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildBoxCell(
                        l10n.importerCellLabel,
                        importer,
                        hasRightBorder: true,
                      ),
                    ),
                    Expanded(
                      child: _buildBoxCell(
                        l10n.exporterCellLabel,
                        exporter,
                      ),
                    ),
                  ],
                ),


              // Meta Row with multi-origin and multi-HS codes
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black87, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.countryOfOriginHeader, style: const TextStyle(fontSize: 11.0, color: Colors.black54)),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: originsList.map((c) {
                              return InkWell(
                                onTap: () => CopyHelper.copy(context, c, customMessage: l10n.copiedToClipboardGeneric),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade300)),
                                  child: Text('🌍 $c', style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.hsCodesHeader, style: const TextStyle(fontSize: 11.0, color: Colors.black54)),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: hsCodesList.map((hs) {
                              return InkWell(
                                onTap: () => CopyHelper.copy(context, hs, customMessage: l10n.copiedToClipboardGeneric),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.purple.shade200)),
                                  child: Text('🔖 $hs', style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.purple)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Commercial Invoices Table
              if ((t['commercial_invoices'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.commercialInvoicesHeader,
                        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columnWidths: const {
                          0: FlexColumnWidth(1.5),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade200),
                            children: [
                              Padding(padding: const EdgeInsets.all(4), child: Text(l10n.colInvoiceAmountCurrency, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(4), child: Text(l10n.colInvoiceNo, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(4), child: Text(l10n.colInvoiceDate, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(4), child: Text(l10n.colIncoterm, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          ...((t['commercial_invoices'] as List<dynamic>).map((inv) {
                            final i = inv as Map<String, dynamic>;
                            final amt = (i['amount'] is num) ? (i['amount'] as num).toStringAsFixed(2) : (i['amount'] ?? '').toString();
                            final curr = (i['currency'] ?? 'EUR').toString();
                            final numStr = (i['invoice_number'] ?? '').toString();
                            final dtStr = (i['invoice_date'] ?? '').toString();
                            final incoStr = (i['incoterm'] ?? 'EXW').toString();
                            final invSummary = '$numStr | $amt $curr | $dtStr | $incoStr';
                            return TableRow(
                              children: [
                                CopyableTableCell(
                                  value: '$amt $curr',
                                  rowSummary: invSummary,
                                  child: Padding(padding: const EdgeInsets.all(4), child: Text('$amt $curr', style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                                ),
                                CopyableTableCell(
                                  value: numStr,
                                  rowSummary: invSummary,
                                  child: Padding(padding: const EdgeInsets.all(4), child: Text(numStr, style: const TextStyle(fontSize: 11.0, color: AppTheme.cobalt, fontWeight: FontWeight.bold))),
                                ),
                                CopyableTableCell(
                                  value: dtStr,
                                  rowSummary: invSummary,
                                  child: Padding(padding: const EdgeInsets.all(4), child: Text(dtStr, style: const TextStyle(fontSize: 11.0))),
                                ),
                                CopyableTableCell(
                                  value: incoStr,
                                  rowSummary: invSummary,
                                  child: Padding(padding: const EdgeInsets.all(4), child: Text(incoStr, style: const TextStyle(fontSize: 11.0))),
                                ),
                              ],
                            );
                          })),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.black87),
              ],

              // Transport & Entry Details Row
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black87, width: 0.8)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Text(l10n.methodOfShipmentLabel(t['method_of_shipment'] ?? 'Sea'), style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text(l10n.countryOfShipmentLabel(origin), style: const TextStyle(fontSize: 11.0, color: Colors.black87)),
                    Text(l10n.pointOfEntryLabel(portOfEntry), style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text(l10n.totalDeclaredValueLabel(totalValue), style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                  ],
                ),
              ),

              // Inspected Line Items Table
              if ((t['inspected_items'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.inspectedItemsHeader,
                        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columnWidths: const {
                          0: FixedColumnWidth(35),
                          1: FlexColumnWidth(1.1),
                          2: FlexColumnWidth(0.9),
                          3: FlexColumnWidth(1.2),
                          4: FlexColumnWidth(2.5),
                          5: FlexColumnWidth(2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade200),
                            children: [
                              Padding(padding: const EdgeInsets.all(3), child: Text(l10n.colItemNo, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(3), child: Text(l10n.colQuantity, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(3), child: Text(l10n.colOrigin, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(3), child: Text(l10n.colProductType, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(3), child: Text(l10n.colDescriptionBrandModel, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(3), child: Text(l10n.colAdoptedStandard, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          ...((t['inspected_items'] as List<dynamic>).map((item) {
                            final itm = item as Map<String, dynamic>;
                            final itmSummary = '#${itm['item_no']} | ${itm['quantity']} | ${itm['country_of_origin']} | ${itm['product_type']} | ${itm['description']} | ${itm['adopted_standard']}';
                            return TableRow(
                              children: [
                                CopyableTableCell(
                                  value: '${itm['item_no'] ?? ''}',
                                  rowSummary: itmSummary,
                                  child: Padding(padding: const EdgeInsets.all(3), child: Text('${itm['item_no'] ?? ''}', style: const TextStyle(fontSize: 11.0))),
                                ),
                                CopyableTableCell(
                                  value: '${itm['quantity'] ?? ''}',
                                  rowSummary: itmSummary,
                                  child: Padding(padding: const EdgeInsets.all(3), child: Text('${itm['quantity'] ?? ''}', style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold))),
                                ),
                                CopyableTableCell(
                                  value: '${itm['country_of_origin'] ?? ''}',
                                  rowSummary: itmSummary,
                                  child: Padding(padding: const EdgeInsets.all(3), child: Text('${itm['country_of_origin'] ?? ''}', style: const TextStyle(fontSize: 11.0))),
                                ),
                                CopyableTableCell(
                                  value: '${itm['product_type'] ?? ''}',
                                  rowSummary: itmSummary,
                                  child: Padding(padding: const EdgeInsets.all(3), child: Text('${itm['product_type'] ?? ''}', style: const TextStyle(fontSize: 11.0))),
                                ),
                                CopyableTableCell(
                                  value: '${itm['description'] ?? ''}',
                                  rowSummary: itmSummary,
                                  child: Padding(padding: const EdgeInsets.all(3), child: Text('${itm['description'] ?? ''}', style: const TextStyle(fontSize: 11.0))),
                                ),
                                CopyableTableCell(
                                  value: '${itm['adopted_standard'] ?? ''}',
                                  rowSummary: itmSummary,
                                  child: Padding(padding: const EdgeInsets.all(3), child: Text('${itm['adopted_standard'] ?? ''}', style: const TextStyle(fontSize: 11.0, color: Colors.green, fontWeight: FontWeight.bold))),
                                ),
                              ],
                            );
                          })),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.black87),
              ],

              // Inspection Office & Remarks Row
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black87, width: 0.8)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(l10n.placeOfInspectionLabel(t['place_of_inspection'] ?? origin), style: const TextStyle(fontSize: 11.0, color: Colors.black87)),
                    Text(l10n.dateOfInspectionLabel(dateInsp), style: const TextStyle(fontSize: 11.0, color: Colors.black87)),
                    Text(l10n.issuingOfficeLabel(t['issuing_office'] ?? '${widget.agency} Office'), style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),

              // Egyptian Standards List Box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black87, width: 0.8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.egyptianMandatoryStandardsHeader, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 6),
                    ...widget.standards.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 14),
                              const SizedBox(width: 6),
                              Expanded(child: Text(s, style: const TextStyle(fontSize: 11.0, color: Colors.black87))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade600)),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(l10n.conformityAssessmentResultConforming, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey.shade50,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(l10n.authorizedAgencyLabel(widget.agency), style: const TextStyle(fontSize: 11.0, color: Colors.black54)),
                    Text(l10n.egyptianCustomsComplianceHeader, style: const TextStyle(fontSize: 11.0, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildBoxCell(String label, String value, {bool hasRightBorder = false}) {
    return InkWell(
      onTap: () => CopyHelper.copy(context, value, customMessage: context.l10n.copiedToClipboardGeneric),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(
            bottom: const BorderSide(color: Colors.black87, width: 0.8),
            right: hasRightBorder ? const BorderSide(color: Colors.black87, width: 0.8) : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.0, color: Colors.black54)),
            const SizedBox(height: 2),
            CopyableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
              copyMessage: context.l10n.copiedToClipboardGeneric,
            ),
          ],
        ),
      ),
    );
  }
}

