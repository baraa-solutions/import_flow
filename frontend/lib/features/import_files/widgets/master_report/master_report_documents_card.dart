import 'package:flutter/material.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_file_model.dart';
import '../sections/import_files_export_helper.dart';

/// Section 1: Master Operational & Documents Tracking Matrix.
class MasterReportDocumentsCard extends StatelessWidget {
  final List<ImportFileModel> displayFiles;
  final int totalFiles;
  final bool isDark;
  final ValueChanged<ImportFileModel> onFileTapped;
  final ValueChanged<int> onTimelineRadarTapped;

  const MasterReportDocumentsCard({
    super.key,
    required this.displayFiles,
    required this.totalFiles,
    required this.isDark,
    required this.onFileTapped,
    required this.onTimelineRadarTapped,
  });

  Future<void> _exportExcel(BuildContext context) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      l.responsiblePersonLabel,
      l.importFileIdLabel,
      l.foreignSupplier,
      l.projectsAndCostCenters,
      l.poInvoiceLabel,
      l.transportModeIncoterm,
      l.colIncoterms,
      l.totalCostMetric,
      l.targetEta,
      l.colPort,
      l.colWarehouse,
      l.colDirectTransit,
      l.colPickupDate,
      l.nextActionLabel,
    ];
    final rows = displayFiles.map((f) {
      final double piVal = f.invoicesData.isNotEmpty
          ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
          : (f.estimatedCost > 0 ? f.estimatedCost : 24500.0);
      final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
      final act = f.displayNextAction(context.l10n);
      return [
        f.owner,
        shipName,
        f.supplierName,
        f.projectNames ?? '-',
        '${piVal.toStringAsFixed(0)} \$',
        f.shipmentMode,
        f.incotermCode,
        '${f.estimatedCost.toStringAsFixed(0)} \$',
        f.requiredEta ?? '-',
        f.portOfLoading ?? '-',
        f.portOfDischarge ?? '-',
        f.serviceTypePreference ?? '-',
        f.cargoReadyDate ?? '-',
        act,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isAr ? 'مصفوفة المتابعة التشغيلية' : 'Operational Tracking Matrix',
      importFileNameOrCode: 'Master_Report_Section1',
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      l.responsiblePersonLabel,
      l.importFileIdLabel,
      l.foreignSupplier,
      l.poInvoiceLabel,
      l.transportModeIncoterm,
      l.totalCostMetric,
      l.targetEta,
      l.nextActionLabel,
    ];
    final rows = displayFiles.map((f) {
      final double piVal = f.invoicesData.isNotEmpty
          ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
          : (f.estimatedCost > 0 ? f.estimatedCost : 24500.0);
      final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
      final act = f.displayNextAction(context.l10n);
      return [
        f.owner,
        shipName,
        f.supplierName,
        '${piVal.toStringAsFixed(0)} \$',
        '${f.shipmentMode} (${f.incotermCode})',
        '${f.estimatedCost.toStringAsFixed(0)} \$',
        f.requiredEta ?? '-',
        act,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isAr ? 'مصفوفة المتابعة التشغيلية' : 'Operational Tracking Matrix',
      importFileNameOrCode: 'Master_Report_Section1',
      headerContext: TableExportHeaderContext(
        title: isAr ? 'مصفوفة المتابعة التشغيلية للشحنات' : 'Operational Tracking Matrix',
        subtitle: 'Sorour Logistics ERP',
        metadata: {
          isAr ? 'إجمالي الملفات' : 'Total Files': '$totalFiles',
          isAr ? 'التاريخ' : 'Date': DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  void _copyTable(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final headers = [
      l.responsiblePersonLabel,
      l.importFileIdLabel,
      l.foreignSupplier,
      l.projectsAndCostCenters,
      l.poInvoiceLabel,
      l.transportModeIncoterm,
      l.colIncoterms,
      l.totalCostMetric,
      l.colPickupDate,
      l.targetEta,
      l.colPort,
      l.colCarrier,
      l.customsDeclBlNumberLabel,
      l.nextActionLabel,
      l.colAcid,
      l.colForm4,
      l.colSwift,
      l.colForm46,
      l.finalDutyColReleasePermit,
      l.status,
    ];
    final rows = displayFiles.map((f) {
      final double piVal = f.invoicesData.isNotEmpty
          ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
          : f.estimatedCost;
      final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
      final stg = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
      final act = f.displayNextAction(context.l10n);
      final carrierVessel = f.vesselName != null
          ? '${f.vesselName} (${f.bookingNo ?? ""})'.trim()
          : (f.selectedScenario ?? '—');
      final bookingBl = f.blNumber ?? f.bookingNo ?? '—';
      return [
        f.owner,
        shipName,
        f.supplierName,
        f.projectNames ?? '—',
        '${piVal.toStringAsFixed(0)} \$',
        f.shipmentMode,
        f.incotermCode,
        '${f.estimatedCost.toStringAsFixed(0)} \$',
        f.cargoReadyDate ?? '—',
        f.requiredEta ?? '—',
        '${f.portOfLoading ?? "—"} → ${f.portOfDischarge ?? "—"}',
        carrierVessel,
        bookingBl,
        '$stg (${f.progressPercent.toInt()}%) - $act',
        f.acidNumber ?? '—',
        f.form4No ?? '—',
        f.swiftNo ?? '—',
        f.form46No ?? '—',
        f.customsReleasePermitNo ?? '—',
        ImportFilesExportHelper.getStatusLabel(f.status, l),
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: isAr ? 'تم نسخ بيانات مصفوفة المتابعة كجدول بنجاح' : 'Operational matrix table copied',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '📋 ${l.operationalTrackingMatrixSection}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                AppButton(
                  label: isAr ? 'تصدير إكسيل' : 'Export Excel',
                  icon: Icons.table_chart,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => _exportExcel(context),
                ),
                AppButton(
                  label: isAr ? 'تصدير PDF' : 'Export PDF',
                  icon: Icons.picture_as_pdf,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                  onPressed: () => _exportPdf(context),
                ),
                AppButton(
                  label: isAr ? 'نسخ الجدول' : 'Copy Table',
                  icon: Icons.content_copy,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: () => _copyTable(context),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        Card(
          elevation: isDark ? 0 : 2,
          color: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.06),
              ),
              headingTextStyle: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              dataRowMaxHeight: 52,
              columns: [
                DataColumn(label: Text(l.responsiblePersonLabel)),
                DataColumn(label: Text(l.importFileIdLabel)),
                DataColumn(label: Text(l.foreignSupplier)),
                DataColumn(label: Text(l.projectsAndCostCenters)),
                DataColumn(label: Text(l.poInvoiceLabel)),
                DataColumn(label: Text(l.transportModeIncoterm)),
                DataColumn(label: Text(l.colIncoterms)),
                DataColumn(label: Text(l.totalCostMetric)),
                DataColumn(label: Text(l.colPickupDate)),
                DataColumn(label: Text(l.targetEta)),
                DataColumn(label: Text(l.colPort)),
                DataColumn(label: Text(l.colCarrier)),
                DataColumn(label: Text(l.customsDeclBlNumberLabel)),
                DataColumn(label: Text(l.nextActionLabel)),
                DataColumn(label: Text(l.colAcid)),
                DataColumn(label: Text(l.colForm4)),
                DataColumn(label: Text(l.colSwift)),
                DataColumn(label: Text(l.colForm46)),
                DataColumn(label: Text(l.finalDutyColReleasePermit)),
                DataColumn(label: Text(l.status)),
                DataColumn(label: Text(isAr ? '⏱️ الرادار الزمني' : '⏱️ Timeline Radar')),
              ],
              rows: displayFiles.map((f) {
                final double piVal = f.invoicesData.isNotEmpty
                    ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
                    : f.estimatedCost;
                final ownerText = f.owner.contains('Broker') ? f.owner : l.customsBrokerLabel;
                final shipName = DisplayNameResolver.resolveShipmentName(f, isArabic: isAr);
                final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
                final resolvedAction = f.displayNextAction(l);
                final stageProgressText = '$resolvedStage (${f.progressPercent.toInt()}%) - $resolvedAction';
                final carrierVessel = f.vesselName != null
                    ? '${f.vesselName} (${f.bookingNo ?? ""})'.trim()
                    : (f.selectedScenario ?? '—');
                final bookingBl = f.blNumber ?? f.bookingNo ?? '—';
                final acidText = f.acidNumber ?? '—';
                final form4Text = f.form4No ?? '—';
                final swiftText = f.swiftNo ?? '—';
                final form46Text = f.form46No ?? '—';
                final releasePermitText = f.customsReleasePermitNo ?? '—';
                final routeText = '${f.portOfLoading ?? "—"} → ${f.portOfDischarge ?? "—"}';

                return DataRow(
                  cells: [
                    DataCell(CopyableTableCell(value: ownerText, child: Text(ownerText, style: const TextStyle(fontSize: 11)))),
                    DataCell(
                      CopyableTableCell(
                        value: f.primaryNameWithCode,
                        child: InkWell(
                          onTap: () => onFileTapped(f),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shipName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.cobalt,
                                  decoration: TextDecoration.underline,
                                  fontSize: 12,
                                ),
                              ),
                              LtrText(f.importFileCode, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DataCell(CopyableTableCell(value: f.supplierName, child: Text(f.supplierName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))),
                    DataCell(CopyableTableCell(value: f.projectNames ?? '—', child: Text(f.projectNames ?? '—', style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: '\$ ${piVal.toStringAsFixed(2)}', child: Text('\$ ${piVal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, fontSize: 11)))),
                    DataCell(CopyableTableCell(value: f.shipmentMode, child: Text(f.shipmentMode, style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: f.incotermCode, child: Text(f.incotermCode, style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: '\$ ${f.estimatedCost.toStringAsFixed(0)}', child: Text('\$ ${f.estimatedCost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                    DataCell(CopyableTableCell(value: f.cargoReadyDate ?? '—', child: Text(f.cargoReadyDate ?? '—', style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: f.requiredEta ?? '—', child: Text(f.requiredEta ?? '—', style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: routeText, child: Text(routeText, style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: carrierVessel, child: Text(carrierVessel, style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: bookingBl, child: Text(bookingBl, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))),
                    DataCell(
                      CopyableTableCell(
                        value: stageProgressText,
                        child: SizedBox(
                          width: 240,
                          child: Text(
                            stageProgressText,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    DataCell(CopyableTableCell(value: acidText, child: Text(acidText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                    DataCell(CopyableTableCell(value: form4Text, child: Text(form4Text, style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: swiftText, child: Text(swiftText, style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: form46Text, child: Text(form46Text, style: const TextStyle(fontSize: 11)))),
                    DataCell(CopyableTableCell(value: releasePermitText, child: Text(releasePermitText, style: const TextStyle(fontSize: 11)))),
                    DataCell(
                      CopyableTableCell(
                        value: ImportFilesExportHelper.getStatusLabel(f.status, l),
                        child: AppStatusBadge.fromStatus(
                          status: f.status,
                          label: ImportFilesExportHelper.getStatusLabel(f.status, l),
                          size: AppStatusBadgeSize.small,
                        ),
                      ),
                    ),
                    DataCell(
                      AppButton(
                        label: isAr ? '36 محطة' : '36 Steps',
                        icon: Icons.history_toggle_off_rounded,
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.small,
                        onPressed: () => onTimelineRadarTapped(f.importFileId),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
