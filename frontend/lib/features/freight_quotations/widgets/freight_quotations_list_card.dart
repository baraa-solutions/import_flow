import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/freight_quotation_model.dart';
import '../services/freight_quotations_export_service.dart';

class FreightQuotationsListCard extends StatelessWidget {
  final List<FreightQuotationItemModel> quotations;
  final String? rfqCode;
  final String supplierName;
  final VoidCallback onShowExtractorDialog;
  final VoidCallback onAddQuotation;
  final ValueChanged<int> onDeleteQuotation;

  const FreightQuotationsListCard({
    super.key,
    required this.quotations,
    required this.rfqCode,
    required this.supplierName,
    required this.onShowExtractorDialog,
    required this.onAddQuotation,
    required this.onDeleteQuotation,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final l10n = context.l10n;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              spacing: 10,
              children: [
                Text(
                  isArabic
                      ? 'عروض أسعار الخطوط الملاحية والشركات المنافسة'
                      : 'Shipping Lines & Carriers Quotations',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (quotations.isNotEmpty) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.cobalt,
                          side: const BorderSide(color: AppTheme.cobalt),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.table_chart_outlined, size: 14),
                        label: Text(l10n.freightQuotationsExportTsvBtn,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => FreightQuotationsExportService.exportToTsv(
                          context: context,
                          quotations: quotations,
                          importFileCode: rfqCode,
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.emerald,
                          side: const BorderSide(color: AppTheme.emerald),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 14),
                        label: Text(l10n.freightQuotationsExportExcelBtn,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => FreightQuotationsExportService.exportToExcel(
                          context: context,
                          quotations: quotations,
                          importFileCode: rfqCode,
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: const BorderSide(color: Colors.deepPurple),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                        label: Text(l10n.freightQuotationsPrintPdfBtn,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => FreightQuotationsExportService.printOrSavePdf(
                          context: context,
                          quotations: quotations,
                          importFileCode: rfqCode,
                          supplierName: supplierName,
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.charcoal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.copy_all_outlined, size: 14),
                        label: Text(l10n.freightQuotationsCopyDossierBtn,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final text = FreightQuotationsExportService.buildDossierText(
                            context: context,
                            quotations: quotations,
                            importFileCode: rfqCode,
                            supplierName: supplierName,
                          );
                          CopyHelper.copy(context, text,
                              customMessage: l10n.freightQuotationsCopyDossierSuccess);
                        },
                      ),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.cobalt,
                        side: const BorderSide(color: AppTheme.cobalt),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: onShowExtractorDialog,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(isArabic
                          ? 'استخراج عروض الأسعار الذكي'
                          : 'Extract Freight Quotes (AI & OCR)'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt),
                      onPressed: onAddQuotation,
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                      label: Text(
                          isArabic ? 'إضافة عرض سعر ناقل' : 'Add Carrier Quotation',
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: quotations.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final q = quotations[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => CopyHelper.copy(context, q.providerName),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                      child: Text(q.providerName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 13))),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy_rounded,
                                      size: 12, color: AppTheme.cobalt),
                                ],
                              ),
                            ),
                            if (q.vesselName != null)
                              Text(
                                '${isArabic ? "السفينة:" : "Vessel:"} ${q.vesselName} | ${isArabic ? "الرحلة:" : "Voyage:"} ${q.voyageNumber ?? "-"}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${isArabic ? "نولون:" : "Freight:"} \$${q.oceanFreightCost} + \$${q.localChargesCost}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => CopyHelper.copy(context, '${q.totalCost}'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${isArabic ? "الإجمالي:" : "Total:"} \$${q.totalCost}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy_rounded, size: 12, color: Colors.green),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${isArabic ? "ترانزيت:" : "Transit:"} ${q.transitDays} ${isArabic ? "يوم" : "d"} (${q.freeDaysAtPod} ${isArabic ? "يوم سماح" : "Free Days"})',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      RowActionsPill(
                        deleteTooltip: isArabic ? 'حذف هذا العرض' : 'Delete quote',
                        onDelete: () async {
                          final ok = await AppConfirmDialog.showDelete(
                            context,
                            entityName: q.providerName,
                            title: isArabic ? 'حذف عرض السعر' : 'Delete Quotation',
                            message: isArabic
                                ? 'هل أنت متأكد من حذف عرض سعر ${q.providerName}؟'
                                : 'Are you sure you want to delete quotation for ${q.providerName}?',
                          );
                          if (ok) onDeleteQuotation(index);
                        },
                        confirmDelete: false,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
