// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../comprehensive_report/widgets/shipment_audit_timeline_dialog.dart';
import '../../../experience_guide/widgets/smart_shipment_reference_card.dart';
import '../../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../models/import_file_model.dart';
import '../../providers/import_files_provider.dart';
import '../sections/timeline_matrix_section.dart';
import '../visual_container_load_planner_dialog.dart';
import '../import_file_details_dialog.dart';
import 'add_edit_import_file_dialog.dart';

/// Shows the prompt selection dialog first, then displays the Master Import Report.
Future<void> promptAndShowMasterReport(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  try {
    final report = await ref.read(importFilesProvider.notifier).fetchMasterReport();
    if (!context.mounted) return;

    int? selectedFileId;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setPromptState) {
            final isDarkPrompt = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDarkPrompt ? AppTheme.darkSurface : null,
              title: Row(
                children: [
                  const Icon(Icons.summarize, color: AppTheme.cobalt, size: 26),
                  const SizedBox(width: 10),
                  Text(l.evaluateMasterReportTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📌 ${l.selectShipmentForReport}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkPrompt ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  ),
                  const SizedBox(height: 12),
                  SearchableDropdownField<int?>(
                    value: selectedFileId,
                    labelText: l.importFileIdLabel,
                    items: [
                      SearchableDropdownItem<int?>(
                        value: null,
                        label: '🌐 ${l.allShipmentFiles}',
                      ),
                      ...report.files.map((f) => SearchableDropdownItem<int?>(
                            value: f.importFileId,
                            label: '📦 ${f.primaryNameWithCode} - ${f.supplierName} (${f.companyName})',
                          )),
                    ],
                    onChanged: (val) => setPromptState(() => selectedFileId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(l.cancel)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                  icon: const Icon(Icons.print, size: 16),
                  label: Text(l.createAndDisplayReport, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    showMasterReportDialog(context, ref, selectedFileId);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, '❌ Error: $e', severity: AppSeverity.danger),
      );
    }
  }
}

/// Displays the full Master Import Report Dialog.
Future<void> showMasterReportDialog(BuildContext context, WidgetRef ref, [int? initialFileId]) async {
  final l = context.l10n;
  try {
    final report = await ref.read(importFilesProvider.notifier).fetchMasterReport();
    var poState = ref.read(purchaseOrdersProvider);
    if (poState.purchaseOrders.isEmpty) {
      await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      poState = ref.read(purchaseOrdersProvider);
    }
    final allPOs = poState.purchaseOrders;

    if (!context.mounted) return;

    int? selectedFileId = initialFileId;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDarkDialog = Theme.of(ctx).brightness == Brightness.dark;
            final displayFiles = selectedFileId == null
                ? report.files
                : report.files.where((f) => f.importFileId == selectedFileId).toList();

            final totalFiles = displayFiles.length;
            final openFiles = displayFiles.where((f) => f.status == 'Open').length;
            final inProgressFiles = displayFiles.where((f) => f.status != 'Open' && f.status != 'Closed').length;
            final totalCost = displayFiles.fold(0.0, (sum, f) => sum + f.estimatedCost);

            return Dialog(
              backgroundColor: isDarkDialog ? AppTheme.darkCardBackground : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDarkDialog ? AppTheme.darkBorder : Colors.transparent),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.90,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dialog Header with Print & Export Actions
                    Row(
                      children: [
                        const Icon(Icons.summarize, color: AppTheme.cobalt, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.masterImportReportTitle,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                              if (selectedFileId != null && displayFiles.isNotEmpty)
                                Text(
                                  '${l.filteredForShipment} ${DisplayNameResolver.resolveShipmentTitle(displayFiles.first, isArabic: Localizations.localeOf(context).languageCode == 'ar')}',
                                  style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () {
                            final isAr = Localizations.localeOf(context).languageCode == 'ar';
                            final buffer = StringBuffer();
                            if (isAr) {
                              buffer.writeln('=====================================================');
                              buffer.writeln('نظام إدارة العمليات اللوجستية - سرور للخدمات اللوجستية');
                              buffer.writeln('التقرير الشامل الرئيسي لملفات الشحنات الاستيرادية');
                              buffer.writeln('التاريخ: ${DateTime.now().toString().substring(0, 10)}');
                              buffer.writeln('إجمالي الملفات: $totalFiles | قيد التشغيل: $openFiles | جارية: $inProgressFiles | التكلفة التقديرية: \$$totalCost');
                              buffer.writeln('=====================================================\n');

                              buffer.writeln('--- 1. مصفوفة المتابعة التشغيلية للشحنات ---');
                              buffer.writeln('المسؤول,رقم الملف,اسم الشحنة,المورد الأجنبي,المشروع,قيمة الفاتورة,طريقة الشحن,شرط التسليم,التكلفة التقديرية,تاريخ الجاهزية,موعد الوصول المستهدف,ميناء الشحن,ميناء الوصول,الخط الملاحي والسفينة,رقم الحجز / البوليصة,المرحلة التشغيلية,الإجراء التالي,رقم ACID,نموذج 4,سويفت,إقرار 46,تصريح الإفراج,حالة الملف');
                            } else {
                              buffer.writeln('=====================================================');
                              buffer.writeln('Sorour Logistics ERP - Master Import Report');
                              buffer.writeln('Date: ${DateTime.now().toString().substring(0, 10)}');
                              buffer.writeln('Total Import Files: $totalFiles | Open: $openFiles | In Progress: $inProgressFiles | Total Cost: \$$totalCost');
                              buffer.writeln('=====================================================\n');

                              buffer.writeln('--- 1. OPERATIONAL TRACKING MATRIX ---');
                              buffer.writeln('Owner,File Code,Shipment Title,Supplier Name,Project,PI Value,Shipping Mode,Incoterm,Estimated Cost,Cargo Ready Date,Target ETA,Port of Loading,Port of Discharge,Carrier & Vessel,Booking / B/L No,Operational Stage,Next Action,ACID Number,Form 4,SWIFT,Form 46,Release Permit,Status');
                            }

                            for (final f in displayFiles) {
                              final double piVal = f.invoicesData.isNotEmpty
                                  ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
                                  : f.estimatedCost;

                              final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
                              final stg = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
                              final act = f.displayNextAction(context.l10n, forExport: true);
                              final carrierVessel = f.vesselName != null ? '${f.vesselName} (${f.bookingNo ?? ""})'.trim() : (f.selectedScenario ?? '—');
                              final bookingBl = f.blNumber ?? f.bookingNo ?? '—';
                              final acid = f.acidNumber ?? '—';
                              final f4 = f.form4No ?? '—';
                              final swift = f.swiftNo ?? '—';
                              final f46 = f.form46No ?? '—';
                              final rel = f.customsReleasePermitNo ?? '—';

                              buffer.writeln('"${f.owner}","${f.importFileCode}","$shipName","${f.supplierName}","${f.projectNames ?? '—'}",$piVal,"${f.shipmentMode}","${f.incotermCode}",${f.estimatedCost},"${f.cargoReadyDate ?? '—'}","${f.requiredEta ?? '—'}","${f.portOfLoading ?? '—'}","${f.portOfDischarge ?? '—'}","$carrierVessel","$bookingBl","$stg (${f.progressPercent.toInt()}%)","$act","$acid","$f4","$swift","$f46","$rel","${f.status}"');
                            }

                            if (isAr) {
                              buffer.writeln('\n--- 2. التفاصيل الحجمية والطرود لأوامر الشراء المرتبطة ---');
                            } else {
                              buffer.writeln('\n--- 2. DETAILED POs & CARGO VOLUMES BREAKDOWN ---');
                            }
                            for (final f in displayFiles) {
                              final linkedPOs = allPOs.where((p) => p.importFileId == f.importFileId || (p.importFileCode != null && p.importFileCode == f.importFileCode)).toList();
                              double fileCbm = 0.0;
                              double fileWt = 0.0;
                              for (var po in linkedPOs) {
                                final double palletCbm = po.palletPlanItems.isNotEmpty
                                    ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount))
                                    : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
                                        ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
                                        : 0.0);
                                final double palletGross = po.palletPlanItems.isNotEmpty
                                    ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.grossWeightPerPalletKg * p.palletCount))
                                    : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);

                                if (palletCbm > 0) {
                                  fileCbm += palletCbm;
                                  fileWt += palletGross > 0 ? palletGross : (po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                                } else if (po.totalCbm > 0 && po.packingListItems.isEmpty) {
                                  fileCbm += po.totalCbm;
                                  fileWt += po.totalGrossWeightKg;
                                } else if (po.packingListItems.isNotEmpty) {
                                  for (var pl in po.packingListItems) {
                                    fileCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
                                    fileWt += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
                                  }
                                } else {
                                  fileCbm += po.totalCbm;
                                  fileWt += po.totalGrossWeightKg;
                                }
                              }
                              if (isAr) {
                                buffer.writeln('الملف: ${f.customFileNumber ?? f.importFileCode} | الشركة: ${f.companyName} | إجمالي CBM: ${fileCbm.toStringAsFixed(3)} م³ | الوزن القائم: ${fileWt.toStringAsFixed(0)} كجم | أوامر الشراء: ${linkedPOs.length}');
                                for (var po in linkedPOs) {
                                  buffer.writeln('   - أمر شراء: ${po.poNumber} | فاتورة مبدئية: ${po.proformaInvoiceNumber ?? "-"} | المورد: ${po.supplierName} | القيمة: ${po.currencyCode ?? "USD"} ${po.totalAmountFob} | الحجم: ${po.totalCbm} م³ | الحالة: ${po.statusLabel(context.l10n)}');
                                }
                              } else {
                                buffer.writeln('File: ${f.customFileNumber ?? f.importFileCode} | Company: ${f.companyName} | Total CBM: ${fileCbm.toStringAsFixed(3)} m3 | Total Wt: ${fileWt.toStringAsFixed(0)} kg | POs Count: ${linkedPOs.length}');
                                for (var po in linkedPOs) {
                                  buffer.writeln('   - PO: ${po.poNumber} | PI: ${po.proformaInvoiceNumber ?? "-"} | Supplier: ${po.supplierName} | Amount: ${po.currencyCode ?? "USD"} ${po.totalAmountFob} | CBM: ${po.totalCbm} m3 | Status: ${po.statusLabel(context.l10n)}');
                                }
                              }
                            }

                            CopyHelper.copy(context, buffer.toString(), customMessage: l.reportCopiedToClipboard);
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: Text(l.printReport),
                        ),
                        if (selectedFileId != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E), // Deep Teal
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.history_toggle_off_rounded, size: 16),
                            label: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'رادار التتبع الزمني (36 محطة)' : 'Timeline Radar (36)'),
                            onPressed: () {
                              showShipmentAuditTimelineDialog(context, importFileId: selectedFileId!);
                            },
                          ),
                        ],
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter Bar inside Dialog Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt, color: AppTheme.cobalt, size: 20),
                          const SizedBox(width: 8),
                          Text(l.filterReportByShipment, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SearchableDropdownField<int?>(
                              value: selectedFileId,
                              labelText: '',
                              items: [
                                SearchableDropdownItem<int?>(
                                  value: null,
                                  label: '🌐 ${l.allShipmentFiles}',
                                ),
                                ...report.files.map((f) => SearchableDropdownItem<int?>(
                                      value: f.importFileId,
                                      label: '📦 ${f.primaryNameWithCode} - ${f.supplierName} (${f.companyName})',
                                    )),
                              ],
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedFileId = val;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Top Header Cards (Calculated on displayFiles)
                    Row(
                      children: [
                        _buildMetricCard(l.totalFilesMetric, '$totalFiles', AppTheme.charcoal),
                        const SizedBox(width: 12),
                        _buildMetricCard(l.openFilesMetric, '$openFiles', AppTheme.cobalt),
                        const SizedBox(width: 12),
                        _buildMetricCard(l.inProgressMetric, '$inProgressFiles', AppTheme.orange),
                        const SizedBox(width: 12),
                        _buildMetricCard(l.totalCostMetric, '${totalCost.toStringAsFixed(0)} \$', AppTheme.emerald),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main Scrollable Area containing BOTH Section 1 AND Section 2
                    Expanded(
                      child: SelectionArea(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SECTION 1: MASTER OPERATIONAL TRACKING MATRIX
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '📋 ${l.operationalTrackingMatrixSection}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.emerald,
                                          side: const BorderSide(color: AppTheme.emerald),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.table_chart, size: 14),
                                        label: Text(
                                          Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير إكسيل' : 'Export Excel',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                        onPressed: () async {
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
                                            context: dialogCtx,
                                            headers: headers,
                                            rows: rows,
                                            stageName: isAr ? 'مصفوفة المتابعة التشغيلية' : 'Operational Tracking Matrix',
                                            importFileNameOrCode: 'Master_Report_Section1',
                                          );
                                        },
                                      ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.crimson,
                                          side: const BorderSide(color: AppTheme.crimson),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.picture_as_pdf, size: 14),
                                        label: Text(
                                          Localizations.localeOf(context).languageCode == 'ar' ? 'تصدير PDF' : 'Export PDF',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                        onPressed: () async {
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
                                            context: dialogCtx,
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
                                        },
                                      ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.cobalt,
                                          side: const BorderSide(color: AppTheme.cobalt),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        icon: const Icon(Icons.content_copy, size: 14),
                                        label: Text(
                                          Localizations.localeOf(context).languageCode == 'ar' ? 'نسخ الجدول' : 'Copy Table',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                        onPressed: () {
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
                                            final carrierVessel = f.vesselName != null ? '${f.vesselName} (${f.bookingNo ?? ""})'.trim() : (f.selectedScenario ?? '—');
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
                                              _getStatusLabel(f.status, l),
                                            ];
                                          }).toList();
                                          TableCopyHelper.copyTable(
                                            dialogCtx,
                                            headers,
                                            rows,
                                            customMessage: isAr ? 'تم نسخ بيانات المصفوفة كجدول بنجاح' : 'Operational matrix table copied',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Card(
                                elevation: isDarkDialog ? 0 : 2,
                                color: isDarkDialog ? AppTheme.darkSurface : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: isDarkDialog ? AppTheme.darkBorder : Colors.transparent),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(isDarkDialog ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.06)),
                                    headingTextStyle: TextStyle(color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 11),
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
                                      DataColumn(label: Text(Localizations.localeOf(context).languageCode == 'ar' ? '⏱️ الرادار الزمني' : '⏱️ Timeline Radar')),
                                    ],
                                    rows: displayFiles.map((f) {
                                      final double piVal = f.invoicesData.isNotEmpty
                                          ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
                                          : f.estimatedCost;
                                      final ownerText = f.owner.contains('Broker') ? f.owner : l.customsBrokerLabel;
                                      final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                      final shipName = DisplayNameResolver.resolveShipmentName(f, isArabic: isAr);
                                      final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
                                      final resolvedAction = f.displayNextAction(context.l10n);
                                      final stageProgressText = '$resolvedStage (${f.progressPercent.toInt()}%) - $resolvedAction';
                                      final carrierVessel = f.vesselName != null ? '${f.vesselName} (${f.bookingNo ?? ""})'.trim() : (f.selectedScenario ?? '—');
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
                                                onTap: () {
                                                  Navigator.pop(dialogCtx);
                                                  _showImportFileDetails(context, ref, f);
                                                },
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(shipName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, decoration: TextDecoration.underline, fontSize: 12)),
                                                    LtrText(f.importFileCode, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(CopyableTableCell(value: f.supplierName, child: Text(f.supplierName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))),
                                          DataCell(CopyableTableCell(value: f.projectNames ?? '—', child: Text(f.projectNames ?? '—', style: const TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: '\$ ${piVal.toStringAsFixed(2)}', child: Text('\$ ${piVal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 11)))),
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
                                              value: _getStatusLabel(f.status, l),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: f.status == 'Open' ? AppTheme.emerald.withValues(alpha: 0.15) : Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: f.status == 'Open' ? AppTheme.emerald : Colors.grey),
                                                ),
                                                child: Text(_getStatusLabel(f.status, l), style: TextStyle(fontWeight: FontWeight.bold, color: f.status == 'Open' ? AppTheme.emerald : Colors.grey, fontSize: 11)),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0F766E),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.history_toggle_off_rounded, size: 14),
                                              label: Text(
                                                Localizations.localeOf(context).languageCode == 'ar' ? '36 محطة' : '36 Steps',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () {
                                                showShipmentAuditTimelineDialog(context, importFileId: f.importFileId);
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // SECTION 2: MERGED CARGO VOLUMES & LINKED POs BREAKDOWN
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    '📦 ${l.cargoAndLinkedPosSection}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              ...displayFiles.map((file) {
                                final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
                                final metrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);
                                final fileTotalCbm = metrics.cbm;
                                final fileTotalWeight = metrics.weightKg;
                                final totalPlCount = metrics.plCount;
                                final invoiceNumbers = metrics.invoices;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDarkDialog ? AppTheme.darkCardBackground : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDarkDialog ? AppTheme.darkBorder : AppTheme.cobalt.withValues(alpha: 0.3)),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDarkDialog ? 0.2 : 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // File Header & Summary Bar
                                      Row(
                                        children: [
                                          Text('${l.importFileIdLabel}: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                          CopyableText(
                                            '${DisplayNameResolver.resolveShipmentTitle(file, isArabic: Localizations.localeOf(context).languageCode == 'ar')} (${file.companyName})',
                                            showIcon: false,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: file.status == 'Open' ? AppTheme.emerald.withValues(alpha: 0.15) : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: file.status == 'Open' ? AppTheme.emerald : Colors.grey),
                                            ),
                                            child: Text(_getStatusLabel(file.status, l), style: TextStyle(fontWeight: FontWeight.bold, color: file.status == 'Open' ? AppTheme.emerald : Colors.grey, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Summary Metric Cards
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDarkDialog ? AppTheme.darkSurface : Colors.blue.shade50.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isDarkDialog ? AppTheme.darkBorder : Colors.blue.shade100),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _buildMetricMiniCard(
                                                '${l.invoicesCountAndNumbers} 📄',
                                                '${invoiceNumbers.length} ${l.invoicesUnit}',
                                                invoiceNumbers.isNotEmpty ? invoiceNumbers.join(', ') : '-',
                                                AppTheme.cobalt,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildMetricMiniCard(
                                                '${l.totalCbmFromPackingList} 📐',
                                                fileTotalCbm > 0 ? '${fileTotalCbm.toStringAsFixed(3)} m³' : '—',
                                                l.cbmSumDescription,
                                                Colors.orange.shade800,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildMetricMiniCard(
                                                '${l.totalGrossWeightFromPl} 🏋️',
                                                fileTotalWeight > 0 ? '${fileTotalWeight.toStringAsFixed(0)} kg' : '—',
                                                l.grossWeightSumDescription,
                                                AppTheme.emerald,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildMetricMiniCard(
                                                '${l.linkedPurchaseOrdersTitle} 🛍️',
                                                '${linkedPOs.length} ${l.posUnit}',
                                                '(${totalPlCount > 0 ? totalPlCount : linkedPOs.length} ${l.packingListsUnit})',
                                                Colors.purple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Linked Purchase Orders Matrix
                                      if (linkedPOs.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(l.noLinkedPosForFile, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                        )
                                      else
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(isDarkDialog ? AppTheme.darkCardBackground : AppTheme.charcoal.withValues(alpha: 0.08)),
                                            headingTextStyle: TextStyle(color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal, fontWeight: FontWeight.bold, fontSize: 12),
                                            columns: [
                                              DataColumn(label: Text(l.purchaseOrder)),
                                              DataColumn(label: Text(l.poInvoiceLabel)),
                                              DataColumn(label: Text(l.foreignSupplier)),
                                              DataColumn(label: Text(l.paymentTermsLabel)),
                                              DataColumn(label: Text(l.totalCostMetric)),
                                              DataColumn(label: Text(l.packingListItemsCol)),
                                              DataColumn(label: Text(l.weightCbmCol)),
                                              DataColumn(label: Text(l.status)),
                                            ],
                                            rows: linkedPOs.map((po) {
                                              final double poPalletCbm = po.palletPlanItems.isNotEmpty
                                                  ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount))
                                                  : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
                                                      ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
                                                      : 0.0);
                                              final double poPalletGross = po.palletPlanItems.isNotEmpty
                                                  ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.grossWeightPerPalletKg * p.palletCount))
                                                  : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                                              final int poPalletCount = po.palletPlanItems.isNotEmpty
                                                  ? po.palletPlanItems.fold<int>(0, (s, p) => s + p.palletCount)
                                                  : po.palletCount;

                                              double poCbm = 0;
                                              double poWt = 0;
                                              if (poPalletCbm > 0) {
                                                poCbm = poPalletCbm;
                                                poWt = poPalletGross > 0 ? poPalletGross : (po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                                              } else if (po.totalCbm > 0 && po.packingListItems.isEmpty) {
                                                poCbm = po.totalCbm;
                                                poWt = po.totalGrossWeightKg;
                                              } else if (po.packingListItems.isNotEmpty) {
                                                for (var pl in po.packingListItems) {
                                                  poCbm += (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm);
                                                  poWt += (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg));
                                                }
                                              } else {
                                                poCbm = po.totalCbm;
                                                poWt = po.totalGrossWeightKg;
                                              }

                                              final String plText = poPalletCount > 0
                                                  ? '$poPalletCount ${l.palletsShippingPlan}'
                                                  : '${po.packingListItems.length} ${l.packingItemsCount}';

                                              final poRowSummary = '${po.poNumber}\t${po.proformaInvoiceNumber ?? "-"}\t${po.supplierName ?? file.supplierName}\t${po.paymentTerms ?? "-"}\t${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}\t$plText\t${poCbm.toStringAsFixed(3)} m³ / ${poWt.toStringAsFixed(0)} kg\t${po.status}';

                                              return DataRow(
                                                cells: [
                                                  DataCell(CopyableTableCell(value: po.poNumber, rowSummary: poRowSummary, child: LtrText(po.poNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                                                  DataCell(CopyableTableCell(value: po.proformaInvoiceNumber ?? '-', rowSummary: poRowSummary, child: Text(po.proformaInvoiceNumber ?? '-'))),
                                                  DataCell(CopyableTableCell(value: po.supplierName ?? file.supplierName, rowSummary: poRowSummary, child: Text(po.supplierName ?? file.supplierName))),
                                                  DataCell(CopyableTableCell(
                                                    value: po.paymentTerms ?? '-',
                                                    rowSummary: poRowSummary,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber.shade200)),
                                                      child: Text(po.paymentTerms ?? '-', style: TextStyle(fontSize: 11, color: Colors.brown.shade800, fontWeight: FontWeight.bold)),
                                                    ),
                                                  )),
                                                  DataCell(CopyableTableCell(value: '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}', rowSummary: poRowSummary, child: Text('${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)))),
                                                  DataCell(CopyableTableCell(value: plText, rowSummary: poRowSummary, child: Text(plText))),
                                                  DataCell(CopyableTableCell(value: '${poCbm.toStringAsFixed(3)} m³ / ${poWt.toStringAsFixed(0)} kg', rowSummary: poRowSummary, child: Text('${poCbm.toStringAsFixed(3)} m³ / ${poWt.toStringAsFixed(0)} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)))),
                                                  DataCell(CopyableTableCell(value: po.statusLabel(context.l10n), rowSummary: poRowSummary, child: Text(po.statusLabel(context.l10n), style: TextStyle(color: po.status == 'APPROVED' ? AppTheme.emerald : Colors.blue, fontWeight: FontWeight.bold)))),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.cobalt,
                                              side: const BorderSide(color: AppTheme.cobalt),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.auto_awesome, size: 14, color: AppTheme.cobalt),
                                            label: Text(
                                              Localizations.localeOf(context).languageCode == 'ar'
                                                  ? 'المرجع الذكي للشحنة'
                                                  : 'Smart Reference',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () => _showSmartReference(context, ref, file, linkedPOs),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.emerald,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.view_in_ar, size: 14, color: Colors.white),
                                            label: Text(
                                              l.containerLoadPlanButton,
                                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () {
                                              _showVisualLoadPlan(
                                                context,
                                                file,
                                                linkedPOs,
                                                fileTotalCbm,
                                                fileTotalWeight,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              const SizedBox(height: 24),

                              // SECTION 3: 25-STAGE LIFECYCLE TIMELINE COMPARISON
                              Builder(
                                builder: (ctx) {
                                  final isAr = Localizations.localeOf(ctx).languageCode == 'ar';
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.timeline_outlined, color: AppTheme.cobalt, size: 22),
                                          const SizedBox(width: 8),
                                          Text(
                                            isAr
                                                ? '⏱️ 3. الجدول الزمني ومراحل دورة حياة الشحنة (25 مرحلة) — مقارنة المخطط بالفعلي والملاحظات الإلزامية'
                                                : '⏱️ 3. Shipment 25-Stage Lifecycle Timeline (Planned vs Actual & Notes)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TimelineMatrixSection(
                                        files: displayFiles,
                                        isDarkDialog: isDarkDialog,
                                        isAr: isAr,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dialog Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text(l.close, style: const TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final isAr = Localizations.localeOf(context).languageCode == 'ar';
                            final buffer = StringBuffer();
                            buffer.write('\uFEFF');
                            if (isAr) {
                              buffer.writeln('المسؤول,كود الملف,اسم الشحنة,المورد الأجنبي,المشروع,قيمة الفاتورة المبدئية,طريقة الشحن,شرط التسليم,التكلفة التقديرية,تاريخ الجاهزية,موعد الوصول المستهدف,ميناء الشحن,ميناء الوصول,الخط الملاحي والسفينة,رقم الحجز / بوليصة الشحن,المرحلة التشغيلية,نسبة الإنجاز,الإجراء التالي,رقم ACID,نموذج 4,سويفت,إقرار 46,تصريح الإفراج,حالة الملف');
                            } else {
                              buffer.writeln('Owner,File Code,Shipment Title,Supplier Name,Project,PI Value,Shipping Mode,Incoterm,Estimated Cost,Cargo Ready Date,Target ETA,Port of Loading,Port of Discharge,Carrier & Vessel,Booking / B/L No,Operational Stage,Progress %,Next Action,ACID Number,Form 4,SWIFT,Form 46,Release Permit,Status');
                            }

                            for (final f in report.files) {
                              final double piVal = f.invoicesData.isNotEmpty
                                  ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
                                  : f.estimatedCost;
                              final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
                              final stg = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
                              final act = f.displayNextAction(context.l10n, forExport: true);
                              final carrierVessel = f.vesselName != null ? '${f.vesselName} (${f.bookingNo ?? ""})'.trim() : (f.selectedScenario ?? '—');
                              final bookingBl = f.blNumber ?? f.bookingNo ?? '—';
                              final acid = f.acidNumber ?? '—';
                              final f4 = f.form4No ?? '—';
                              final swift = f.swiftNo ?? '—';
                              final f46 = f.form46No ?? '—';
                              final rel = f.customsReleasePermitNo ?? '—';

                              buffer.writeln('"${f.owner}","${f.importFileCode}","$shipName","${f.supplierName}","${f.projectNames ?? '—'}",$piVal,"${f.shipmentMode}","${f.incotermCode}",${f.estimatedCost},"${f.cargoReadyDate ?? '—'}","${f.requiredEta ?? '—'}","${f.portOfLoading ?? '—'}","${f.portOfDischarge ?? '—'}","$carrierVessel","$bookingBl","$stg",${f.progressPercent.toInt()}," $act","$acid","$f4","$swift","$f46","$rel","${f.status}"');
                            }

                            final filename = 'Reports_Import_Files_Master_Summary_${DateTime.now().millisecondsSinceEpoch}.csv';
                            Navigator.pop(dialogCtx);
                            await FileSaveHelper.saveText(
                              context: context,
                              textContent: buffer.toString(),
                              defaultFileName: filename,
                              dialogTitle: l.saveComprehensiveReportDialogTitle,
                              allowedExtensions: ['csv', 'xlsx'],
                            );
                          },
                          icon: const Icon(Icons.download, color: Colors.white, size: 18),
                          label: Text(l.exportReportExcelPdf, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, '❌ Error: $e', severity: AppSeverity.danger),
      );
    }
  }
}

String _getStatusLabel(String status, AppLocalizations l) {
  switch (status.toLowerCase()) {
    case 'open':
      return l.statusOpen;
    case 'closed':
      return l.statusClosed;
    case 'in progress':
    case 'inprogress':
      return l.statusInProgress;
    case 'draft':
      return l.filterStatusDraft;
    default:
      return status;
  }
}

Widget _buildMetricCard(String title, String value, Color color) {
  return Expanded(
    child: MetricCard(
      data: MetricCardData(
        title: title,
        value: value,
        icon: Icons.insights,
        color: color,
      ),
    ),
  );
}

Widget _buildMetricMiniCard(String title, String value, String sub, Color color) {
  return MetricCard(
    data: MetricCardData(
      title: title,
      value: value,
      tooltip: sub,
      icon: Icons.analytics_outlined,
      color: color,
    ),
  );
}

void _showVisualLoadPlan(
  BuildContext context,
  ImportFileModel file,
  List<PurchaseOrderModel> pos,
  double totalCbm,
  double totalWeight,
) {
  showDialog(
    context: context,
    builder: (context) => VisualContainerLoadPlannerDialog(
      file: file,
      linkedPOs: pos,
      fallbackCbm: totalCbm,
      fallbackWeight: totalWeight,
    ),
  );
}

void _showSmartReference(
  BuildContext context,
  WidgetRef ref,
  ImportFileModel file, [
  List<PurchaseOrderModel>? linkedPOs,
]) {
  final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
  final effectivePOs = linkedPOs ?? ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'المرجع الذكي للشحنة (Smart Reference)' : 'Shipment Smart Reference',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.cobalt),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: SmartShipmentReferenceCard(
                    importFileId: file.importFileId,
                    initialHsCode: file.hsCode,
                    initialCategory: file.productCategory,
                    initialPod: file.portOfDischarge,
                    initialSupplier: file.supplierName,
                    initialCarrier: file.selectedScenario,
                    linkedPOs: effectivePOs,
                    file: file,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showImportFileDetails(BuildContext context, WidgetRef ref, ImportFileModel file) async {
  var poState = ref.read(purchaseOrdersProvider);
  if (poState.purchaseOrders.isEmpty) {
    await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    poState = ref.read(purchaseOrdersProvider);
  }
  final allPOs = poState.purchaseOrders;
  final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
  final metrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);
  final currentLocale = ref.read(localeProvider);
  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      return Directionality(
        textDirection: currentLocale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: ImportFileDetailsDialog(
          file: file,
          linkedPOs: linkedPOs,
          invoiceNumbers: metrics.invoices,
          totalPackingListCbm: metrics.cbm,
          totalPackingListWeight: metrics.weightKg,
          totalPackingListsCount: metrics.plCount,
          onEditPressed: () => AddEditImportFileDialog.show(context, ref, fileToEdit: file),
        ),
      );
    },
  );
}
