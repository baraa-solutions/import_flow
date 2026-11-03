import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import 'smart_extractor_actions_bar.dart';
import 'smart_extractor_dropzone.dart';
import 'smart_extractor_field_chip.dart';
import 'smart_extractor_invoice_items_table.dart';

export 'smart_extractor_invoice_items_table.dart';

/// Full tab card for Commercial Invoice extraction, reviewing items, and file linking.
class SmartExtractorInvoiceCard extends StatelessWidget {
  final TextEditingController textController;
  final PlatformFile? pickedFile;
  final VoidCallback onPickFile;
  final VoidCallback onClearFile;
  final VoidCallback onExtract;
  final bool isExtracting;
  final Map<String, dynamic>? extractedInvoice;
  final List<dynamic> invoiceItems;
  final int? selectedImportFileId;
  final ValueChanged<int?> onFileChanged;
  final VoidCallback onApply;
  final bool isApplying;

  const SmartExtractorInvoiceCard({
    super.key,
    required this.textController,
    required this.pickedFile,
    required this.onPickFile,
    required this.onClearFile,
    required this.onExtract,
    required this.isExtracting,
    required this.extractedInvoice,
    required this.invoiceItems,
    required this.selectedImportFileId,
    required this.onFileChanged,
    required this.onApply,
    required this.isApplying,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartExtractorDropzone(
            title: l.smartExtractorInvoiceCardTitle,
            hint: l.smartExtractorInvoiceCardHint,
            textController: textController,
            pickedFile: pickedFile,
            onPickFile: onPickFile,
            onClearFile: onClearFile,
            onExtract: onExtract,
            isLoading: isExtracting,
            extractButtonLabel: l.smartExtractorExtractInvoiceButton,
          ),
          if (extractedInvoice != null) ...[
            const SizedBox(height: 16),
            SmartExtractorInvoiceSummaryCard(invoice: extractedInvoice!),
            const SizedBox(height: 16),
            SmartExtractorInvoiceItemsTable(invoiceItems: invoiceItems),
            const SizedBox(height: 16),
            SmartExtractorInvoiceActionBar(
              selectedImportFileId: selectedImportFileId,
              onFileChanged: onFileChanged,
              onApply: onApply,
              isApplying: isApplying,
            ),
          ],
        ],
      ),
    );
  }
}

/// Extracted invoice summary card displaying parsed metadata and origin information.
class SmartExtractorInvoiceSummaryCard extends StatelessWidget {
  final Map<String, dynamic> invoice;

  const SmartExtractorInvoiceSummaryCard({
    super.key,
    required this.invoice,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currency = (invoice['currency'] ?? 'USD').toString();
    final origin = (invoice['origin_country'] ?? '').toString().trim();
    final hsCode = (invoice['hs_code'] ?? '').toString().trim();
    final isPreferential = invoice['is_preferential_origin'] == true;
    final prefAgreement =
        (invoice['preferential_origin_agreement'] ?? '').toString().trim();
    final isFOC = invoice['is_free_of_charge'] == true;
    final pallets = invoice['pallets_count'];
    final packages = invoice['packages_count'];
    final containerNo = (invoice['container_number'] ?? '').toString().trim();
    final sealNo = (invoice['seal_number'] ?? '').toString().trim();
    final poNo = (invoice['purchase_order'] ?? '').toString().trim();
    final freightAmt = invoice['freight_amount'];

    final packagingValue = isArabic
        ? '${packages != null ? "$packages طرد" : ""}${packages != null && pallets != null ? " / " : ""}${pallets != null ? "$pallets بالتة" : ""}'
        : '${packages != null ? "$packages pkgs" : ""}${packages != null && pallets != null ? " / " : ""}${pallets != null ? "$pallets pallets" : ""}';

    final sealText = isArabic ? 'ختم' : 'Seal';
    final containerDisplay = containerNo.isNotEmpty
        ? '$containerNo${sealNo.isNotEmpty ? " ($sealText: $sealNo)" : ""}'
        : '';

    return Card(
      elevation: 0,
      color: AppTheme.cobaltLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.cobaltBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.smartExtractorExtractedInvoiceTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.charcoal,
                  ),
                ),
                const Spacer(),
                AppStatusBadge(
                  label: l.smartExtractorCurrency(currency),
                  severity: AppSeverity.success,
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldInvoiceNo,
                  value: '${invoice['invoice_number'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldInvoiceDate,
                  value: '${invoice['invoice_date'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldAcidNo,
                  value: '${invoice['acid_number'] ?? '-'}',
                  isHighlight: true,
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldImporterTaxId,
                  value: '${invoice['importer_tax_id'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldSupplier,
                  value: '${invoice['supplier_name'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldImporter,
                  value: '${invoice['importer_name'] ?? '-'}',
                ),
                if (origin.isNotEmpty)
                  SmartExtractorFieldChip(
                    label: isArabic ? 'بلد المنشأ' : 'Country of Origin',
                    value: origin,
                    isHighlight: true,
                  ),
                if (hsCode.isNotEmpty)
                  SmartExtractorFieldChip(
                    label: isArabic ? 'البند الجمركي' : 'HS Code',
                    value: hsCode,
                    isHighlight: true,
                  ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldIncoterms,
                  value: '${invoice['incoterms'] ?? '-'}',
                ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldTotalAmount,
                  value: '${invoice['invoice_value'] ?? 0} $currency',
                  isHighlight: true,
                ),
                if (freightAmt != null && (freightAmt is num) && freightAmt > 0)
                  SmartExtractorFieldChip(
                    label: isArabic ? 'النولون' : 'Freight',
                    value: '$freightAmt $currency',
                  ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldTotalGrossWeight,
                  value: '${invoice['total_gross_weight_kg'] ?? '-'} KG',
                ),
                if (invoice['total_net_weight_kg'] != null)
                  SmartExtractorFieldChip(
                    label: isArabic ? 'الوزن الصافي' : 'Net Weight',
                    value: '${invoice['total_net_weight_kg']} KG',
                  ),
                if (packages != null || pallets != null)
                  SmartExtractorFieldChip(
                    label: isArabic ? 'التعبئة والتغليف' : 'Packaging',
                    value: packagingValue,
                  ),
                SmartExtractorFieldChip(
                  label: l.smartExtractorFieldPorts,
                  value:
                      'POL: ${invoice['loading_port'] ?? '-'} | POD: ${invoice['discharge_port'] ?? '-'}',
                ),
                if (containerNo.isNotEmpty)
                  SmartExtractorFieldChip(
                    label: isArabic ? 'الحاوية' : 'Container',
                    value: containerDisplay,
                  ),
                if (poNo.isNotEmpty)
                  SmartExtractorFieldChip(
                    label: isArabic ? 'أمر التوريد' : 'Purchase Order',
                    value: poNo,
                  ),
                if (isPreferential && prefAgreement.isNotEmpty)
                  SmartExtractorFieldChip(
                    label: isArabic
                        ? 'اتفاقية المنشأ التفضيلي'
                        : 'Preferential Origin Agreement',
                    value: prefAgreement,
                    isHighlight: true,
                  ),
                if (isFOC)
                  SmartExtractorFieldChip(
                    label: isArabic ? 'الحالة الجمركية' : 'Customs Status',
                    value: isArabic
                        ? 'قيمة إحصائية / عينات مجانية'
                        : 'Statistical Value / Free Samples',
                    isHighlight: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
