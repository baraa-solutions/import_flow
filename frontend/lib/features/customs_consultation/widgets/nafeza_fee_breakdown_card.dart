import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/customs_consultation_model.dart';
import '../services/customs_export_service.dart';
import 'package:printing/printing.dart';
import '../services/customs_consultation_pdf_service.dart';
import '../../../core/widgets/copyable_data_helper.dart';

class NafezaFeeBreakdownCard extends StatelessWidget {
  final List<CustomsItemCalcRow> calcLines;
  final double totalDutyEgp;
  final double totalVatEgp;
  final double totalServiceFeeEgp;
  final double totalScheduleTaxEgp;
  final double totalFreightEgp;
  final double totalInsuranceEgp;
  final double exchangeRate;
  
  // State variables passed in
  final int? editingConsultationId;
  final String? editingConsultationCode;
  final int? selectedBrokerId;
  final String selectedBrokerName;
  final String title;
  final List<CustomsChecklistItemModel> checklist;
  final List<CustomsBrokerQuoteItemModel> brokerQuoteItems;
  final int? selectedImportFileId;
  final String customsCurrency;

  const NafezaFeeBreakdownCard({
    super.key,
    required this.calcLines,
    required this.totalDutyEgp,
    required this.totalVatEgp,
    required this.totalServiceFeeEgp,
    required this.totalScheduleTaxEgp,
    required this.totalFreightEgp,
    required this.totalInsuranceEgp,
    required this.exchangeRate,
    this.editingConsultationId,
    this.editingConsultationCode,
    this.selectedBrokerId,
    required this.selectedBrokerName,
    required this.title,
    required this.checklist,
    required this.brokerQuoteItems,
    this.selectedImportFileId,
    required this.customsCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final egpLabel = isArabic ? 'ج.م' : 'EGP';
    final nafezaResult = CustomsExportService.computeNafezaFeeBreakdown(
      totalDutyEgp: totalDutyEgp,
      totalVatEgp: totalVatEgp,
      totalServiceFeeEgp: totalServiceFeeEgp,
      totalScheduleTaxEgp: totalScheduleTaxEgp,
    );

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cobalt.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withOpacity(isDark ? 0.18 : 0.08),
                borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(9), topEnd: Radius.circular(9)),
                border: Border(bottom: BorderSide(color: AppTheme.cobalt.withOpacity(0.2))),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long, color: AppTheme.cobalt, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l.nafezaDeclarationBreakdown,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${nafezaResult.grandTotal.toStringAsFixed(2)} $egpLabel',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // 1. TSV Export Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          CustomsExportService.exportCustomsLinesTsv(
                            context: context,
                            calcLines: calcLines,
                            currency: customsCurrency,
                          );
                        },
                        icon: const Icon(Icons.table_view_outlined, color: Colors.white, size: 14),
                        label: Text(l.customsTaxExportTsvBtn, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      // 2. Excel Export Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () async {
                          try {
                            final savedFile = await CustomsExportService.exportCustomsStudyToExcel(
                              context: context,
                              title: title.isNotEmpty ? title : 'Customs Consultation',
                              importFileCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : null,
                              brokerName: selectedBrokerName.isNotEmpty ? selectedBrokerName : 'Customs Broker',
                              currency: customsCurrency,
                              exchangeRate: exchangeRate,
                              totalFreightEgp: totalFreightEgp,
                              totalInsuranceEgp: totalInsuranceEgp,
                              calcLines: calcLines,
                              nafezaResult: nafezaResult,
                              brokerQuoteItems: brokerQuoteItems,
                            );
                            if (savedFile != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('✅ $savedFile'), backgroundColor: AppTheme.emerald),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.table_chart, color: Colors.white, size: 14),
                        label: Text(l.customsTaxExportExcelBtn, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      // 3. PDF Export Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () async {
                          final session = CustomsConsultationModel(
                            consultationId: editingConsultationId ?? 0,
                            consultationCode: editingConsultationCode ?? 'DRAFT-STMT',
                            brokerId: selectedBrokerId ?? 0,
                            brokerName: selectedBrokerName.isNotEmpty ? selectedBrokerName : 'Customs Broker',
                            title: title.isNotEmpty ? title : 'Customs Consultation',
                            overallStatus: 'Pending Review',
                            estimatedDutiesEgp: nafezaResult.grandTotal,
                            totalBrokerFeesEgp: brokerQuoteItems.fold(0.0, (s, i) => s + (i.isApplicable ? i.totalAmount : 0.0)),
                            checklistItems: checklist,
                            brokerQuoteItems: brokerQuoteItems,
                            createdAt: DateTime.now().toIso8601String(),
                            updatedAt: DateTime.now().toIso8601String(),
                          );
                          await Printing.layoutPdf(
                            onLayout: (format) => CustomsConsultationPdfService.generateConsultationPdf(session),
                            name: 'Nafeza_Statement_${DateTime.now().millisecondsSinceEpoch}',
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 14),
                        label: Text(l.customsTaxPrintPdfBtn, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      // 4. Dossier Copy Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          CustomsExportService.copyCustomsDutyDossier(
                            context: context,
                            title: title.isNotEmpty ? title : 'Customs Consultation',
                            importFileCode: selectedImportFileId != null ? 'IMP-$selectedImportFileId' : null,
                            brokerName: selectedBrokerName.isNotEmpty ? selectedBrokerName : 'Customs Broker',
                            currency: customsCurrency,
                            exchangeRate: exchangeRate,
                            totalFreightEgp: totalFreightEgp,
                            totalInsuranceEgp: totalInsuranceEgp,
                            calcLines: calcLines,
                            nafezaResult: nafezaResult,
                          );
                        },
                        icon: const Icon(Icons.copy_all, color: Colors.white, size: 14),
                        label: Text(l.customsTaxCopyDossierBtn, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Grouped Fee Items Matching Image 2
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: nafezaResult.groups.map((group) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        // Group Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardBackground : Colors.blueGrey.shade100.withOpacity(0.4),
                            borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(5), topEnd: Radius.circular(5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${l.nafezaCollectionPrefix} ${group.groupName}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                              Text(
                                '${group.totalAmount.toStringAsFixed(2)} $egpLabel',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                            ],
                          ),
                        ),
                        // Items inside group
                        ...group.items.map((item) {
                          final typeLabel = item.calculationType == 'flat'
                              ? l.nafezaCalculationFlat
                              : (item.calculationType == 'reference' ? l.nafezaCalculationReference : l.nafezaCalculationDerived);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                // Code Badge (Clickable to copy)
                                Tooltip(
                                  message: l.copyTooltip,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => CopyHelper.copy(context, item.code),
                                    child: Container(
                                      width: 44,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.darkCardBackground : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        '[${item.code}]',
                                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.cobalt : Colors.blueGrey, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Item Name
                                Expanded(
                                  child: Text(
                                    item.nameAr,
                                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                // Calculation Type
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.calculationType == 'flat'
                                        ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50)
                                        : (isDark ? Colors.teal.withOpacity(0.2) : Colors.teal.shade50),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    typeLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: item.calculationType == 'flat'
                                          ? (isDark ? Colors.blue.shade300 : Colors.blue.shade800)
                                          : (isDark ? Colors.teal.shade300 : Colors.teal.shade800),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Amount
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    '${item.calculatedAmount.toStringAsFixed(2)} $egpLabel',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
