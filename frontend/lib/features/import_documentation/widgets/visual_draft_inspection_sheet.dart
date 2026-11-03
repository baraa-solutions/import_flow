import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/buttons/app_button.dart';
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

  bool _acidBlocked() {
    if (widget.acidNumber.trim().isNotEmpty) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.idocBExportBlockedAcid, severity: AppSeverity.danger),
    );
    return true;
  }

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
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
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
                  AppButton(label: l10n.exportTsvBtn, onPressed: () {
                      if (_acidBlocked()) return;
                      InspectionExportService.saveInspectionTsvToFile(
                      context: context,
                      templateData: t,
                      agency: widget.agency,
                      certType: widget.certType,
                      acidNumber: widget.acidNumber,
                      standards: widget.standards,
                    );
                    }, variant: AppButtonVariant.secondary, icon: Icons.table_chart_outlined),
                  const SizedBox(width: 8),
                  // 2. Export Excel (CSV) Button
                  AppButton(label: l10n.saveExcelCsvBtn, onPressed: () {
                      if (_acidBlocked()) return;
                      InspectionExportService.saveInspectionCsvToFile(
                      context: context,
                      templateData: t,
                      agency: widget.agency,
                      certType: widget.certType,
                      acidNumber: widget.acidNumber,
                      standards: widget.standards,
                    );
                    }, variant: AppButtonVariant.secondary, icon: Icons.file_download_outlined),
                  const SizedBox(width: 8),
                  // 3. Print / Save PDF Button
                  AppButton(label: l10n.savePrintPdfBtn, onPressed: _isExporting
                        ? null
                        : () async {
                            if (_acidBlocked()) return;
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
                          }, variant: AppButtonVariant.danger, icon: Icons.picture_as_pdf, isLoading: _isExporting),
                  const SizedBox(width: 8),
                  // 4. Copy Full Dossier Button
                  AppButton(label: l10n.copyDossierBtn, onPressed: () {
                      if (_acidBlocked()) return;
                      InspectionExportService.copyDossierToClipboard(
                      context,
                      templateData: t,
                      agency: widget.agency,
                      certType: widget.certType,
                      acidNumber: widget.acidNumber,
                      standards: widget.standards,
                    );
                    }, variant: AppButtonVariant.secondary, icon: Icons.copy_all_outlined),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Official Visual Document Container
          Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.textPrimary, width: 1.5),
              boxShadow: const [BoxShadow(color: AppTheme.border, blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 1.2)),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.black),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.black),
                            copyMessage: l10n.copiedToClipboardGeneric,
                          ),
                          CopyableText(
                            isAr ? l10n.acidNoPrefix(widget.acidNumber.isEmpty ? l10n.idocBMissing : widget.acidNumber) : 'ACID NO: ${widget.acidNumber.isEmpty ? l10n.idocBMissing : widget.acidNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.emerald),
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
                  border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.countryOfOriginHeader, style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
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
                                  decoration: BoxDecoration(color: AppTheme.infoBackground, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.cobaltBorder)),
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
                          Text(l10n.hsCodesHeader, style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
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
                                  decoration: BoxDecoration(color: AppTheme.infoBackground, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.cobaltBorder)),
                                  child: Text('🔖 $hs', style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
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
                  color: AppTheme.surfaceAlt,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.commercialInvoicesHeader,
                        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Table(
                        border: TableBorder.all(color: AppTheme.border),
                        columnWidths: const {
                          0: FlexColumnWidth(1.5),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.2),
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: AppTheme.border),
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
                const Divider(height: 1, color: AppTheme.textPrimary),
              ],

              // Transport & Entry Details Row
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Text(l10n.methodOfShipmentLabel(t['method_of_shipment'] ?? 'Sea'), style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text(l10n.countryOfShipmentLabel(origin), style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                    Text(l10n.pointOfEntryLabel(portOfEntry), style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
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
                        style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Table(
                        border: TableBorder.all(color: AppTheme.border),
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
                            decoration: const BoxDecoration(color: AppTheme.border),
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
                                  child: Padding(padding: const EdgeInsets.all(3), child: Text('${itm['adopted_standard'] ?? ''}', style: const TextStyle(fontSize: 11.0, color: AppTheme.emerald, fontWeight: FontWeight.bold))),
                                ),
                              ],
                            );
                          })),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.textPrimary),
              ],

              // Inspection Office & Remarks Row
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(l10n.placeOfInspectionLabel(t['place_of_inspection'] ?? origin), style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                    Text(l10n.dateOfInspectionLabel(dateInsp), style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary)),
                    Text(l10n.issuingOfficeLabel(t['issuing_office'] ?? '${widget.agency} Office'), style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
              ),

              // Egyptian Standards List Box
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.textPrimary, width: 0.8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.egyptianMandatoryStandardsHeader, style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    ...widget.standards.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppTheme.emerald, size: 14),
                              const SizedBox(width: 6),
                              Expanded(child: Text(s, style: const TextStyle(fontSize: 11.0, color: AppTheme.textPrimary))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppTheme.successBackground, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.emerald)),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, color: AppTheme.emerald, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(l10n.conformityAssessmentResultConforming, style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11)),
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
                color: AppTheme.surfaceAlt,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(l10n.authorizedAgencyLabel(widget.agency), style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
                    Text(l10n.egyptianCustomsComplianceHeader, style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
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
            bottom: const BorderSide(color: AppTheme.textPrimary, width: 0.8),
            right: hasRightBorder ? const BorderSide(color: AppTheme.textPrimary, width: 0.8) : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.0, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            CopyableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary),
              copyMessage: context.l10n.copiedToClipboardGeneric,
            ),
          ],
        ),
      ),
    );
  }
}

