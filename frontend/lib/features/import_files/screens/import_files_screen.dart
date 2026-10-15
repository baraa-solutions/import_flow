// ignore_for_file: deprecated_member_use
import '../widgets/import_file_details_dialog.dart';
import '../widgets/import_file_form_dialog.dart';
import '../widgets/freight_rfq_dialog.dart';
import '../../smart_checklists/widgets/smart_checklist_dialog.dart';
import '../../import_documentation/widgets/smart_invoice_bl_extractor_dialog.dart';
import '../../simulation/widgets/what_if_simulator_dialog.dart';
import '../../lifecycle_board/widgets/skip_step_dialog_helper.dart';
import '../../../core/widgets/clone_entity_review_dialog.dart';
import '../../../core/widgets/compact_table_pagination_footer.dart';
import '../../../core/widgets/directional_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/network/dio_client.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/reopen_shipment_dialog.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/smart_upload_button.dart';
import '../../../core/widgets/stop_shipment_dialog.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/app_shimmer_skeleton.dart';
import '../models/import_file_model.dart';
import '../providers/import_files_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../../../core/performance/dispose_tracker.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../widgets/visual_container_load_planner_dialog.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/services/table_export_service.dart';
import '../../../core/utils/bidi_text.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class ImportFilesScreen extends ConsumerStatefulWidget {
  final String? initialSearchQuery;
  final int? highlightedFileId;

  const ImportFilesScreen({
    super.key,
    this.initialSearchQuery,
    this.highlightedFileId,
  });

  @override
  ConsumerState<ImportFilesScreen> createState() => _ImportFilesScreenState();
}

class _ImportFilesScreenState extends ConsumerState<ImportFilesScreen> with DisposeTrackerMixin<ImportFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _screenFocusNode = FocusNode();
  final ScrollController _horizontalTableScrollController = ScrollController();
  final ScrollController _verticalTableScrollController = ScrollController();
  String? _selectedStatusFilter = 'All';
  int? _highlightedFileId;

  String _getPriorityLabel(String priority, AppLocalizations l) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return l.priorityCritical;
      case 'high':
        return l.priorityHigh;
      case 'medium':
        return l.priorityMedium;
      case 'low':
        return l.priorityLow;
      default:
        return priority;
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


  void _showVisualLoadPlanDialogForReport(
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
  void _showAddEditFileDialog([ImportFileModel? fileToEdit]) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImportFileFormDialog(fileToEdit: fileToEdit),
    );
    if (!mounted) return;
    ref.read(paginatedImportFilesProvider.notifier).fetchPage(
          ref.read(paginatedImportFilesProvider).page,
          search: _searchController.text,
          status: _selectedStatusFilter,
        );
    ref.read(importFilesProvider.notifier).fetchImportFiles();
  }

  void _promptAndShowMasterReport() async {
    final l = context.l10n;
    try {
      final report = await ref.read(importFilesProvider.notifier).fetchMasterReport();
      if (!mounted) return;

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
                      _showMasterReportDialog(selectedFileId);
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showMasterReportDialog([int? initialFileId]) async {
    final l = context.l10n;
    try {
      final report = await ref.read(importFilesProvider.notifier).fetchMasterReport();
      var poState = ref.read(purchaseOrdersProvider);
      if (poState.purchaseOrders.isEmpty) {
        await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
        poState = ref.read(purchaseOrdersProvider);
      }
      final allPOs = poState.purchaseOrders;

      if (!mounted) return;

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
                                buffer.writeln('المخلص الجمركي,رقم الشحنة,اسم المورد,اسم المشروع,قيمة الفاتورة,طريقة الشحن,شرط التسليم,إجمالي التكلفة,تاريخ الشحن,ميناء الوصول,مخزن الوصول,التسليم المباشر,تاريخ الجاهزية,آخر تحديث للشحنة,تاريخ المستندات,سويفت,الخط الملاحي,رقم ACID,نموذج 4,إقرار 46');
                              } else {
                                buffer.writeln('=====================================================');
                                buffer.writeln('Sorour Logistics ERP - Master Import Report');
                                buffer.writeln('Date: ${DateTime.now().toString().substring(0, 10)}');
                                buffer.writeln('Total Import Files: $totalFiles | Open: $openFiles | In Progress: $inProgressFiles | Total Cost: \$$totalCost');
                                buffer.writeln('=====================================================\n');

                                buffer.writeln('--- 1. OPERATIONAL TRACKING MATRIX ---');
                                buffer.writeln('Customs Broker,Shipment No,Supplier Name,Project Name,PI Value,Shipping Mode,Incoterm,Total Cost,Shipping Date,Arrival Port,Arrival Warehouse,Direct Over,Cargo Ready Date,Latest Update,Doc Date,SWIFT,Carrier,ACID,Form 4,Form 46');
                              }

                              for (final f in displayFiles) {
                                final double piVal = f.invoicesData.isNotEmpty
                                    ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
                                    : (f.estimatedCost > 0 ? f.estimatedCost : 24500.0);

                                final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
                                final stg = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
                                final act = f.displayNextAction(context.l10n);

                                buffer.writeln('"${f.owner.contains('Broker') ? f.owner : (isAr ? 'المخلص الجمركي' : 'Customs Broker')}","$shipName","${f.supplierName}","${f.projectNames ?? (isAr ? 'المبنى الرئيسي للمشروع' : 'Main Site Building')}",$piVal,${f.shipmentMode},${f.incotermCode},${f.estimatedCost},"${f.createdAt.length >= 10 ? f.createdAt.substring(0, 10) : '4/6/2026'}","${f.requiredEta ?? '15-8-2026'}","31-8-2026","X","${f.requiredEta ?? '15-8-2026'}","$stg (${f.progressPercent.toInt()}%) - $act","10-8-2026","${f.swiftNo ?? 'Vertex'}","${f.selectedScenario ?? 'MSC / COSCO'}","${f.piNumber != null ? 'ACID-19876543210987' : '1987654321098765432'}","${f.form4No ?? 'FORM4-2026-001'}","${f.form46No ?? 'DEC46-2026-001'}"');
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

                              Clipboard.setData(ClipboardData(text: stripBidiIsolates(buffer.toString())));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.reportCopiedToClipboard),
                                  backgroundColor: AppTheme.cobalt,
                                ),
                              );
                            },
                            icon: const Icon(Icons.print, size: 16),
                            label: Text(l.printReport),
                          ),
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
                          color: AppTheme.cobalt.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
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
                                child: SelectionArea(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(isDarkDialog ? AppTheme.darkCardBackground : AppTheme.charcoal.withOpacity(0.06)),
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
                                      DataColumn(label: Text(l.targetEta)),
                                      DataColumn(label: Text(l.colPort)),
                                      DataColumn(label: Text(l.colWarehouse)),
                                      DataColumn(label: Text(l.colDirectTransit)),
                                      DataColumn(label: Text(l.colPickupDate)),
                                      DataColumn(label: Text(l.nextActionLabel)),
                                      DataColumn(label: Text(l.colDocDate)),
                                      DataColumn(label: Text(l.colSwift)),
                                      DataColumn(label: Text(l.colCarrier)),
                                      DataColumn(label: Text(l.colAcid)),
                                      DataColumn(label: Text(l.colForm4)),
                                      DataColumn(label: Text(l.colForm46)),
                                      DataColumn(label: Text(l.status)),
                                    ],
                                    rows: displayFiles.map((f) {
                                      final double piVal = f.invoicesData.isNotEmpty
                                          ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
                                          : (f.estimatedCost > 0 ? f.estimatedCost : 24500.0);
                                      final ownerText = f.owner.contains('Broker') ? f.owner : l.customsBrokerLabel;
                                      final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                      final shipName = DisplayNameResolver.resolveShipmentName(f, isArabic: isAr);
                                      final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
                                      final resolvedAction = f.displayNextAction(context.l10n);
                                      final stageProgressText = '$resolvedStage (${f.progressPercent.toInt()}%) - $resolvedAction';

                                      return DataRow(
                                        cells: [
                                          DataCell(CopyableTableCell(value: ownerText, child: Text(ownerText, style: const TextStyle(fontSize: 11)))),
                                          DataCell(
                                            CopyableTableCell(
                                              value: f.primaryNameWithCode,
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.pop(dialogCtx);
                                                  _showImportFileDetailsDialog(context, f);
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
                                          DataCell(CopyableTableCell(value: f.projectNames ?? 'Main Site Building', child: Text(f.projectNames ?? 'Main Site Building', style: const TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: '\$ ${piVal.toStringAsFixed(2)}', child: Text('\$ ${piVal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: f.shipmentMode, child: Text(f.shipmentMode, style: const TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: f.incotermCode, child: Text(f.incotermCode, style: const TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: '\$ ${f.estimatedCost.toStringAsFixed(0)}', child: Text('\$ ${f.estimatedCost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: f.createdAt.length >= 10 ? f.createdAt.substring(0, 10) : '4/6/2026', child: Text(f.createdAt.length >= 10 ? f.createdAt.substring(0, 10) : '4/6/2026', style: const TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: f.requiredEta ?? '15-8-2026', child: Text(f.requiredEta ?? '15-8-2026', style: const TextStyle(fontSize: 11)))),
                                          const DataCell(CopyableTableCell(value: '31-8-2026', child: Text('31-8-2026', style: TextStyle(fontSize: 11)))),
                                          const DataCell(CopyableTableCell(value: 'X', child: Center(child: Text('X', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))))),
                                          DataCell(CopyableTableCell(value: f.requiredEta ?? '15-8-2026', child: Text(f.requiredEta ?? '15-8-2026', style: const TextStyle(fontSize: 11)))),
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
                                          const DataCell(CopyableTableCell(value: '10-8-2026', child: Text('10-8-2026', style: TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: f.swiftNo ?? 'Vertex', child: Text(f.swiftNo ?? 'Vertex', style: const TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: f.selectedScenario ?? 'MSC / COCOS', child: Text(f.selectedScenario ?? 'MSC / COCOS', style: const TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: f.piNumber != null ? 'ACID-19876543210987' : '1987654321098765432', child: Text(f.piNumber != null ? 'ACID-19876543210987' : '1987654321098765432', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)))),
                                          DataCell(CopyableTableCell(value: f.form4No ?? 'FORM4-2026-001', child: Text(f.form4No ?? 'FORM4-2026-001', style: const TextStyle(fontSize: 11)))),
                                          DataCell(CopyableTableCell(value: f.form46No ?? 'DEC46-2026-001', child: Text(f.form46No ?? 'DEC46-2026-001', style: const TextStyle(fontSize: 11)))),
                                          DataCell(
                                            CopyableTableCell(
                                              value: _getStatusLabel(f.status, l),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: f.status == 'Open' ? AppTheme.emerald.withOpacity(0.15) : Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: f.status == 'Open' ? AppTheme.emerald : Colors.grey),
                                                ),
                                                child: Text(_getStatusLabel(f.status, l), style: TextStyle(fontWeight: FontWeight.bold, color: f.status == 'Open' ? AppTheme.emerald : Colors.grey, fontSize: 11)),
                                              ),
                                            ),
                                          ),
                                        ],
                                       );
                                      }).toList(),
                                   ),
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
                                border: Border.all(color: isDarkDialog ? AppTheme.darkBorder : AppTheme.cobalt.withOpacity(0.3)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkDialog ? 0.2 : 0.03), blurRadius: 4, offset: const Offset(0, 2))],
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
                                          color: file.status == 'Open' ? AppTheme.emerald.withOpacity(0.15) : Colors.grey.shade200,
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
                                      color: isDarkDialog ? AppTheme.darkSurface : Colors.blue.shade50.withOpacity(0.5),
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
                                            '${fileTotalCbm > 0 ? fileTotalCbm.toStringAsFixed(3) : "15.060"} m³',
                                            l.cbmSumDescription,
                                            Colors.orange.shade800,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildMetricMiniCard(
                                            '${l.totalGrossWeightFromPl} 🏋️',
                                            '${fileTotalWeight > 0 ? fileTotalWeight.toStringAsFixed(0) : "4250"} kg',
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
                                        headingRowColor: WidgetStateProperty.all(isDarkDialog ? AppTheme.darkCardBackground : AppTheme.charcoal.withOpacity(0.08)),
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
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: ElevatedButton.icon(
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
                                          _showVisualLoadPlanDialogForReport(
                                            context,
                                            file,
                                            linkedPOs,
                                            fileTotalCbm,
                                            fileTotalWeight,
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
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
                            buffer.writeln('المخلص الجمركي,رقم الشحنة,اسم المورد,اسم المشروع,قيمة الفاتورة,طريقة الشحن,شرط التسليم,إجمالي التكلفة,تاريخ الشحن,ميناء الوصول,مخزن الوصول,التسليم المباشر,تاريخ الجاهزية,آخر تحديث للشحنة,تاريخ المستندات,سويفت,الخط الملاحي,رقم ACID,نموذج 4,إقرار 46');
                          } else {
                            buffer.writeln('Customs Broker,Shipment No,Supplier Name,Project Name,PI Value,Shipping Mode,Incoterm,Total Cost,Shipping Date,Arrival Port,Arrival Warehouse,Direct Over,Cargo Ready Date,Latest Update,Doc Date,SWIFT,Carrier,ACID,Form 4,Form 46');
                          }

                          for (final f in report.files) {
                            final double piVal = f.invoicesData.isNotEmpty
                                ? f.invoicesData.fold(0.0, (sum, i) => sum + i.amount)
                                : (f.estimatedCost > 0 ? f.estimatedCost : 24500.0);
                            final shipName = DisplayNameResolver.resolveShipmentTitle(f, isArabic: isAr);
                            final stg = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isAr);
                            final act = f.displayNextAction(context.l10n);
                            buffer.writeln('"${f.owner.contains('Broker') ? f.owner : (isAr ? 'المخلص الجمركي' : 'Customs Broker')}","$shipName","${f.supplierName}","${f.projectNames ?? (isAr ? 'المبنى الرئيسي للمشروع' : 'Main Site Building')}",$piVal,${f.shipmentMode},${f.incotermCode},${f.estimatedCost},"${f.createdAt.length >= 10 ? f.createdAt.substring(0, 10) : '4/6/2026'}","${f.requiredEta ?? '15-8-2026'}","31-8-2026","X","${f.requiredEta ?? '15-8-2026'}","$stg (${f.progressPercent.toInt()}%) - $act","10-8-2026","${f.swiftNo ?? 'Vertex'}","${f.selectedScenario ?? 'MSC / COSCO'}","${f.piNumber != null ? 'ACID-19876543210987' : '1987654321098765432'}","${f.form4No ?? 'FORM4-2026-001'}","${f.form46No ?? 'DEC46-2026-001'}"');
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildMetricMiniCard(String title, String value, String sub, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppTheme.darkBorder : color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          CopyableText(value, showIcon: false, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            CopyableText(value, showIcon: false, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
    }
    _highlightedFileId = widget.highlightedFileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _screenFocusNode.requestFocus();
    });
    Future.microtask(() {
      final paginatedState = ref.read(paginatedImportFilesProvider);
      if (!paginatedState.isLoading) {
        ref.read(paginatedImportFilesProvider.notifier).fetchPage(1);
      }
      final companiesState = ref.read(importCompaniesProvider);
      if (companiesState is! AsyncLoading && (companiesState.value == null || companiesState.value!.isEmpty)) {
        ref.read(importCompaniesProvider.notifier).fetchCompanies();
      }
      final posState = ref.read(purchaseOrdersProvider);
      if (!posState.isLoading && posState.purchaseOrders.isEmpty) {
        ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
      }
      final scenariosState = ref.read(shippingScenariosProvider);
      if (!scenariosState.isLoading && scenariosState.sessions.isEmpty) {
        ref.read(shippingScenariosProvider.notifier).fetchSessions();
      }
    });
  }

  @override
  void dispose() {
    _horizontalTableScrollController.dispose();
    _verticalTableScrollController.dispose();
    _screenFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openSearchAndCloneDialog() {
    final allFiles = ref.read(importFilesProvider).value ?? ref.read(paginatedImportFilesProvider).items;
    final textDirection = Directionality.of(context);
    final locale = Localizations.localeOf(context);
    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: textDirection,
          child: _SearchAndCloneImportFileDialog(
            files: allFiles,
            onSelectFile: (file) {
              Navigator.of(ctx).pop();
              _showCloneDialog(file);
            },
          ),
        ),
      ),
    );
  }

  void _showCloneDialog(ImportFileModel file) {
    final l = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final arrowSymbol = DirectionalArrow.symbolForArabic(isAr);
    CloneEntityReviewDialog.show(
      context,
      entityType: l.cloneImportFileDialogTitle,
      sourceCode: file.importFileCode,
      suggestedNewCode: '${file.importFileCode}-CLONE',
      sourceTitle: file.customFileNumber ?? file.companyName,
      copiedFieldsSummary: {
        l.importingCompany: file.companyName.isNotEmpty ? file.companyName : '-',
        l.foreignSupplier: file.supplierName.isNotEmpty ? file.supplierName : '-',
        l.portsOfLoadingAndDischarge: '${file.portOfLoading ?? '-'} $arrowSymbol ${file.portOfDischarge ?? '-'}',
        l.transportModeIncoterm: '${file.shipmentMode} (${file.incotermCode})',
      },
      mandatorilyResetFields: [
        l.cloneFieldStatusDraftBadge,
        l.cloneFieldCustomsClearedReset,
        l.cloneFieldFinancialReset,
        l.cloneFieldAcidReset,
        l.cloneFieldPoReset,
      ],
      allowCopyLineItems: true,
      allowCopyAttachments: false,
      initialCopyLineItems: true,
      initialCopyAttachments: false,
      onConfirm: ({
        required String newCode,
        required String newTitle,
        required bool copyLineItems,
        required bool copyAttachments,
        String? notes,
      }) async {
        try {
          final cloned = await ref.read(importFilesProvider.notifier).cloneImportFile(
            file.importFileId,
            {
              'target_import_file_code': newCode.trim(),
              'new_import_file_code': newCode.trim(),
              'target_custom_file_number': newTitle.trim().isNotEmpty ? newTitle.trim() : null,
              'copy_invoices_data': copyLineItems,
              'copy_packing_lists': copyLineItems,
              'copy_items': copyLineItems,
              'copy_attachments': copyAttachments,
              if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.clonedSuccessfullyToast(cloned?.importFileCode ?? newCode)),
                backgroundColor: AppTheme.emerald,
              ),
            );
          }
          final paginatedState = ref.read(paginatedImportFilesProvider);
          ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${l.errorPrefix}: $e'),
                backgroundColor: AppTheme.crimson,
              ),
            );
          }
          rethrow;
        }
      },
    );
  }

  void _showImportFileDetailsDialog(BuildContext context, ImportFileModel file) async {
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
            onEditPressed: () => _showAddEditFileDialog(file),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paginatedState = ref.watch(paginatedImportFilesProvider);
    final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final Map<int, List<PurchaseOrderModel>> linkedPOsCache = {};

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          final items = ref.read(paginatedImportFilesProvider).items;
          if (items.isEmpty) return;
          if (_highlightedFileId != null) {
            final selected = items.firstWhere(
              (f) => f.importFileId == _highlightedFileId,
              orElse: () => items.first,
            );
            _showCloneDialog(selected);
          } else {
            _openSearchAndCloneDialog();
          }
        },
      },
      child: Focus(
        focusNode: _screenFocusNode,
        autofocus: true,
        child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PageHeader(
        icon: Icons.folder_special,
        title: l.importFilesManagementTitle,
        actions: [
          Builder(
            builder: (ctx) {
              final isNarrow = MediaQuery.sizeOf(ctx).width < 768;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isNarrow)
                    SmartUploadButton(
                      module: SmartUploadModule.importFile,
                      label: l.uploadImportDocument,
                      onDataExtracted: (result) {
                        final fields = result.extractedFields;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${fields['commodity_description'] ?? fields['invoice_number'] ?? 'Extracted successfully'}',
                            ),
                            backgroundColor: AppTheme.emerald,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      },
                    ),
                  if (!isNarrow) const SizedBox(width: 8),
                  if (!isNarrow) const BackToDashboardButton(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(1),
                  ),
                  const SizedBox(width: 10),
                ],
              );
            },
          ),
        ],
      ),
      body: SelectionArea(
        child: LayoutBuilder(
        builder: (context, screenConstraints) {
          final isMobile = screenConstraints.maxWidth < AppTheme.tabletBreakpoint;
          return Padding(
            padding: EdgeInsetsDirectional.only(
              start: isMobile ? 8 : 16,
              end: isMobile ? 8 : 16,
              top: isMobile ? 4 : 6,
              bottom: 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Single Compact Toolbar (One Row, Max 40px tall)
                if (isMobile)
                  _buildMobileToolbar(context, isDark, l)
                else
                  _buildDesktopCompactToolbar(context, isDark, l),
                const SizedBox(height: 6),

                // Files Data Table
            Expanded(
              child: paginatedState.isLoading 
                ? const ImportFilesTableShimmerSkeleton()
                : paginatedState.error != null
                  ? Center(child: Text('❌ Error: ${paginatedState.error}', style: const TextStyle(color: Colors.red)))
                  : paginatedState.items.isEmpty
                    ? Center(child: Text(l.noImportFilesFound, style: const TextStyle(fontSize: 16)))
                    : Card(
                      elevation: isDark ? 0 : 2,
                      margin: EdgeInsets.zero,
                      color: isDark ? AppTheme.darkCardBackground : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                          if (constraints.maxWidth < 768) {
                            return _buildMobileStackedCardsList(
                              context,
                              paginatedState.items,
                              l,
                              isDark,
                              linkedPOsCache,
                              allPOs,
                              paginatedState,
                            );
                          }
                          final ambientDirection = Directionality.of(context);
                          final density = ref.watch(displayDensityProvider);
                          // Column widths for 1:1 pixel-perfect alignment between sticky header and scrolling body
                          const double colActionsWidth = 300.0;
                          const double colFileIdWidth = 160.0;
                          const double colCompanyWidth = 180.0;
                          const double colPoWidth = 180.0;
                          const double colSupplierWidth = 190.0;
                          const double colTransportWidth = 150.0;
                          const double colPriorityWidth = 105.0;
                          const double colEtaWidth = 110.0;
                          const double colStageWidth = 160.0;
                          const double colProgressWidth = 110.0;
                          const double colNextActionWidth = 170.0;
                          const double colOwnerWidth = 140.0;
                          const double colStatusWidth = 110.0;

                          const double tableTotalWidth = colActionsWidth +
                              colFileIdWidth +
                              colCompanyWidth +
                              colPoWidth +
                              colSupplierWidth +
                              colTransportWidth +
                              colPriorityWidth +
                              colEtaWidth +
                              colStageWidth +
                              colProgressWidth +
                              colNextActionWidth +
                              colOwnerWidth +
                              colStatusWidth +
                              (18.0 * 12) +
                              32.0;

                          final headerColumns = [
                            DataColumn(label: SizedBox(width: colActionsWidth, child: Text(l.actions, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colFileIdWidth, child: Text(l.importFileIdLabel, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colCompanyWidth, child: Text(l.importingCompany, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colPoWidth, child: Text(l.poInvoiceLabel, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colSupplierWidth, child: Text(l.foreignSupplier, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colTransportWidth, child: Text(l.transportModeIncoterm, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colPriorityWidth, child: Text(l.priorityType, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colEtaWidth, child: Text(l.targetEta, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colStageWidth, child: Text(l.currentPhaseStage, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colProgressWidth, child: Text(l.progressPercentLabel, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colNextActionWidth, child: Text(l.nextActionLabel, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colOwnerWidth, child: Text(l.responsiblePersonLabel, style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataColumn(label: SizedBox(width: colStatusWidth, child: Text(l.status, style: const TextStyle(fontWeight: FontWeight.bold)))),
                          ];

                          final dummyBodyColumns = [
                            const DataColumn(label: SizedBox(width: colActionsWidth)),
                            const DataColumn(label: SizedBox(width: colFileIdWidth)),
                            const DataColumn(label: SizedBox(width: colCompanyWidth)),
                            const DataColumn(label: SizedBox(width: colPoWidth)),
                            const DataColumn(label: SizedBox(width: colSupplierWidth)),
                            const DataColumn(label: SizedBox(width: colTransportWidth)),
                            const DataColumn(label: SizedBox(width: colPriorityWidth)),
                            const DataColumn(label: SizedBox(width: colEtaWidth)),
                            const DataColumn(label: SizedBox(width: colStageWidth)),
                            const DataColumn(label: SizedBox(width: colProgressWidth)),
                            const DataColumn(label: SizedBox(width: colNextActionWidth)),
                            const DataColumn(label: SizedBox(width: colOwnerWidth)),
                            const DataColumn(label: SizedBox(width: colStatusWidth)),
                          ];

                          return Scrollbar(
                            controller: _horizontalTableScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            thickness: 10,
                            radius: const Radius.circular(5),
                            child: SingleChildScrollView(
                              controller: _horizontalTableScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableTotalWidth,
                                height: constraints.maxHeight,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // ── Sticky Header Row (Pinned at Top) ──────────────
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1),
                                            width: 1.5,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(isDark ? 0.35 : 0.07),
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: DataTable(
                                        columnSpacing: 18,
                                        horizontalMargin: 16,
                                        headingRowHeight: density.headerHeight,
                                        dataRowMinHeight: 0,
                                        dataRowMaxHeight: 0,
                                        headingRowColor: WidgetStateProperty.all(
                                          isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
                                        ),
                                        headingTextStyle: TextStyle(
                                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                          fontWeight: FontWeight.bold,
                                          fontSize: density.tableHeaderFontSize,
                                        ),
                                        columns: headerColumns,
                                        rows: const [],
                                      ),
                                    ),

                                     // ── Dedicated Scrollable Table Body (Vertical Scrollbar Flipped to Left via RTL Direction Trick) ──
                                     Expanded(
                                       child: Directionality(
                                         textDirection: ambientDirection == TextDirection.ltr ? TextDirection.rtl : ambientDirection, // LTR keeps the scrollbar on the left; RTL uses the native side
                                         child: Scrollbar(
                                           controller: _verticalTableScrollController,
                                           thumbVisibility: true,
                                           child: Directionality(
                                             textDirection: ambientDirection,
                                             child: SingleChildScrollView(
                                               controller: _verticalTableScrollController,
                                               child: DataTable(
                                            columnSpacing: 18,
                                            horizontalMargin: 16,
                                            headingRowHeight: 0,
                                            dataRowMinHeight: density.rowHeight,
                                            dataRowMaxHeight: density.rowHeight + 16,
                                            dataTextStyle: TextStyle(
                                              fontSize: density.tableCellPrimaryFontSize,
                                              color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                                            ),
                                            columns: dummyBodyColumns,
                                            rows: paginatedState.items.map((file) {
                               final priorityText = _getPriorityLabel(file.priority, l);
                               final statusText = _getStatusLabel(file.status, l);

                               String poDisplay;
                               if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
                                 poDisplay = file.poNumber!.trim();
                               } else {
                                 final linkedPOs = linkedPOsCache.putIfAbsent(file.importFileId, () => ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs));
                                 if (linkedPOs.isNotEmpty) {
                                   poDisplay = linkedPOs.map((p) => (p.poReference != null && p.poReference!.trim().isNotEmpty && p.poReference != file.customFileNumber && p.poReference != file.importFileCode) ? p.poReference! : p.poNumber).join(', ');
                                 } else {
                                   poDisplay = '-';
                                 }
                               }
                               final piDisplay = file.piNumber != null && file.piNumber!.trim().isNotEmpty ? file.piNumber!.trim() : '-';
                               final isAr = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
                               final resolvedStage = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr);
                               final resolvedAction = file.displayNextAction(context.l10n);
                               final shipDisplayName = DisplayNameResolver.resolveShipmentName(file, isArabic: isAr);
                               final rowSummary = '$shipDisplayName\t${file.companyName}\t${l.poNumberShortPrefix}$poDisplay, ${l.piNumberShortPrefix}$piDisplay\t${file.supplierName}\t${file.shipmentMode} (${file.incotermCode})\t$priorityText\t${file.requiredEta ?? "-"}\t$resolvedStage\t${file.progressPercent.toInt()}%\t$resolvedAction\t${file.owner}\t$statusText';

                               return DataRow(
                                 selected: _highlightedFileId == file.importFileId,
                                 onSelectChanged: (selected) {
                                   setState(() {
                                     _highlightedFileId = (selected == true) ? file.importFileId : null;
                                   });
                                 },
                                 cells: [
                                   DataCell(
                                     SizedBox(
                                       width: colActionsWidth,
                                       child: SingleChildScrollView(
                                         scrollDirection: Axis.horizontal,
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                         if (file.status != 'Closed')
                                           IconButton(
                                             icon: const Icon(Icons.cancel_outlined, color: AppTheme.crimson, size: 18),
                                             tooltip: l.stopShipmentTooltip,
                                             onPressed: () {
                                               StopShipmentDialog.show(
                                                 context,
                                                 importFile: file,
                                                 currentPhaseName: file.currentModule,
                                                 onSuccess: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page),
                                               );
                                             },
                                           )
                                         else
                                           IconButton(
                                             icon: const Icon(Icons.play_arrow, color: AppTheme.emerald, size: 18),
                                             tooltip: l.reopenShipmentTooltip,
                                             onPressed: () {
                                               ReopenShipmentDialog.show(
                                                 context,
                                                 importFile: file,
                                                 onSuccess: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page),
                                               );
                                             },
                                           ),
                                         IconButton(
                                           icon: const Icon(Icons.mark_email_unread_outlined, color: AppTheme.cobalt, size: 18),
                                           tooltip: l.freightRfqTooltip,
                                           onPressed: () {
                                             FreightRfqDialog.show(
                                               context,
                                               importFileId: file.importFileId,
                                               importFileCode: file.importFileCode,
                                               customFileNumber: file.customFileNumber,
                                             );
                                           },
                                         ),
                                         if (file.status != 'Closed')
                                           IconButton(
                                             icon: const Icon(Icons.fast_forward_rounded, color: AppTheme.orange, size: 18),
                                             tooltip: '${l.skipStepBtn}: $resolvedStage',
                                             onPressed: () => SkipStepDialogHelper.show(
                                               context: context,
                                               ref: ref,
                                               importFileCode: file.importFileCode,
                                               currentStepCode: file.currentStage,
                                               currentStepName: file.currentModule,
                                               onSuccess: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page),
                                             ),
                                           ),
                                         IconButton(
                                           icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 18),
                                           tooltip: l.cloneImportFileDialogTitle,
                                           onPressed: () => _showCloneDialog(file),
                                         ),
                                           const SizedBox(width: 4),
                                           IconButton(
                                             icon: const Icon(Icons.playlist_add_check_circle, color: AppTheme.cobalt, size: 20),
                                             tooltip: l.smartChecklistTooltip,
                                             splashRadius: 18,
                                             padding: EdgeInsets.zero,
                                             constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                             onPressed: () => SmartChecklistDialog.show(context, file),
                                           ),
                                           const SizedBox(width: 4),
                                           IconButton(
                                             icon: const Icon(Icons.summarize_outlined, color: AppTheme.cobalt, size: 18),
                                             tooltip: 'تقرير الشحنة الشامل المدمج (Screen 47)',
                                             splashRadius: 18,
                                             padding: EdgeInsets.zero,
                                             constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                             onPressed: () {
                                               ref.read(selectedComprehensiveReportFileIdProvider.notifier).state = file.importFileId;
                                               selectNavigationIndex(ref, 47, tabTitle: 'تقرير الشحنة الشامل المدمج');
                                             },
                                           ),
                                           const SizedBox(width: 4),
                                           RowActionsPill(
                                           onView: () => _showImportFileDetailsDialog(context, file),
                                           onEdit: () => _showAddEditFileDialog(file),
                                           onClone: () => _showCloneDialog(file),
                                           onPrint: () {
                                             ScaffoldMessenger.of(context).showSnackBar(
                                               SnackBar(
                                                 content: Text('${l.printFileHistoryTooltip}: ${file.customFileNumber ?? file.importFileCode}'),
                                                 backgroundColor: AppTheme.charcoal,
                                                 duration: const Duration(seconds: 2),
                                               ),
                                             );
                                           },
                                           onDelete: () async {
                                             final confirm = await showDialog<bool>(
                                               context: context,
                                               builder: (c) => AlertDialog(
                                                 title: Text(l.confirmDeleteImportFileTitle),
                                                 content: Text(l.confirmDeleteImportFilePrompt(file.customFileNumber ?? file.importFileCode)),
                                                 actions: [
                                                   TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                                                   ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson, foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
                                                 ],
                                               ),
                                             );
                                             if (confirm == true) {
                                               await ref.read(importFilesProvider.notifier).softDeleteImportFile(file.importFileId);
                                               ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page);
                                             }
                                           },
                                         ),
                                        ],
                                      ),
                                     ),
                                   ),
                                  ),
                                   DataCell(
                                     SizedBox(
                                       width: colFileIdWidth,
                                       child: CopyableTableCell(
                                         value: shipDisplayName,
                                         rowSummary: rowSummary,
                                         child: InkWell(
                                           onTap: () => _showImportFileDetailsDialog(context, file),
                                           child: Column(
                                             mainAxisSize: MainAxisSize.min,
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               Text(
                                                 shipDisplayName,
                                                 style: TextStyle(
                                                   fontWeight: FontWeight.bold,
                                                   fontSize: density.tableCellPrimaryFontSize,
                                                   color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                                                   decoration: TextDecoration.underline,
                                                 ),
                                               ),
                                               if (shipDisplayName != file.importFileCode)
                                                 LtrText(
                                                   file.importFileCode,
                                                   style: TextStyle(
                                                     fontSize: density.tableCellSecondaryFontSize,
                                                     color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                                                     fontWeight: FontWeight.w600,
                                                   ),
                                                 ),
                                               if (file.clonedFromCode != null && file.clonedFromCode!.isNotEmpty)
                                                 Text(
                                                   l.clonedFromBadge(file.clonedFromCode!),
                                                   style: TextStyle(
                                                     fontSize: density.tableCellSecondaryFontSize,
                                                     color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                 ),
                                             ],
                                           ),
                                         ),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colCompanyWidth,
                                       child: CopyableTableCell(
                                         value: file.companyName,
                                         rowSummary: rowSummary,
                                         child: Text(file.companyName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colPoWidth,
                                       child: CopyableTableCell(
                                         value: '${l.poNumberShortPrefix}$poDisplay | ${l.piNumberShortPrefix}$piDisplay',
                                         rowSummary: rowSummary,
                                         child: Column(
                                           mainAxisSize: MainAxisSize.min,
                                           mainAxisAlignment: MainAxisAlignment.center,
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                             Text('${l.poNumberShortPrefix}$poDisplay', style: const TextStyle(fontWeight: FontWeight.w600)),
                                             Text(
                                               '${l.piNumberShortPrefix}$piDisplay',
                                               style: TextStyle(
                                                 fontSize: 11,
                                                 color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                                               ),
                                             ),
                                           ],
                                         ),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colSupplierWidth,
                                       child: CopyableTableCell(
                                         value: file.supplierName,
                                         rowSummary: rowSummary,
                                         child: Text(file.supplierName),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colTransportWidth,
                                       child: CopyableTableCell(
                                         value: '${file.shipmentMode} (${file.incotermCode})',
                                         rowSummary: rowSummary,
                                         child: Text('${file.shipmentMode} (${file.incotermCode})'),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colPriorityWidth,
                                       child: CopyableTableCell(
                                         value: priorityText,
                                         rowSummary: rowSummary,
                                         child: Chip(
                                           label: Text(priorityText, style: TextStyle(fontSize: density.tableCellSecondaryFontSize, color: Colors.white, fontWeight: FontWeight.bold)),
                                           backgroundColor: file.priority == 'High' || file.priority == 'Critical' ? AppTheme.wcagCrimson : AppTheme.wcagOrange,
                                         ),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colEtaWidth,
                                       child: CopyableTableCell(
                                         value: file.requiredEta ?? '-',
                                         rowSummary: rowSummary,
                                         child: Text(file.requiredEta ?? '-'),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colStageWidth,
                                       child: CopyableTableCell(
                                         value: resolvedStage,
                                         rowSummary: rowSummary,
                                         child: Text(resolvedStage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colProgressWidth,
                                       child: CopyableTableCell(
                                         value: '${file.progressPercent.toInt()}%',
                                         rowSummary: rowSummary,
                                         child: SizedBox(
                                           width: 100,
                                           child: Column(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: [
                                               LinearProgressIndicator(value: file.progressPercent / 100, backgroundColor: isDark ? AppTheme.darkBorder : Colors.grey.shade200, color: AppTheme.wcagEmerald),
                                               const SizedBox(height: 2),
                                               Text('${file.progressPercent.toInt()}%', style: TextStyle(fontSize: density.tableCellSecondaryFontSize, fontWeight: FontWeight.bold)),
                                             ],
                                           ),
                                         ),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colNextActionWidth,
                                       child: CopyableTableCell(
                                         value: resolvedAction,
                                         rowSummary: rowSummary,
                                         child: Text(resolvedAction, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colOwnerWidth,
                                       child: CopyableTableCell(
                                         value: file.owner,
                                         rowSummary: rowSummary,
                                         child: Text(file.owner, style: const TextStyle(fontWeight: FontWeight.bold)),
                                       ),
                                     ),
                                   ),
                                   DataCell(
                                     SizedBox(
                                       width: colStatusWidth,
                                       child: CopyableTableCell(
                                         value: statusText,
                                         rowSummary: rowSummary,
                                         child: Chip(
                                           padding: EdgeInsets.zero,
                                           materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                           label: Text(statusText, style: TextStyle(fontSize: density.tableCellSecondaryFontSize, color: Colors.white, fontWeight: FontWeight.bold)),
                                           backgroundColor: file.status == 'Open' ? AppTheme.wcagEmerald : (isDark ? const Color(0xFF475569) : Colors.grey.shade600),
                                         ),
                                       ),
                                     ),
                                   ),
                               ],
                             );
                           }).toList(),
                         ),
                       ),
                     ),
                   ),
                 ),
               ),
                 ],
               ),
             ),
           ),
         );
                  },
                ),
              ),
                // Seamless Integrated Compact Pagination Footer
                if (!paginatedState.isLoading && paginatedState.items.isNotEmpty)
                  CompactTablePaginationFooter(
                    currentPage: paginatedState.page,
                    totalPages: paginatedState.totalPages,
                    totalCount: paginatedState.total,
                    pageSize: paginatedState.pageSize,
                    isMobile: isMobile,
                    onPageChanged: (newPage) => ref.read(paginatedImportFilesProvider.notifier).fetchPage(
                      newPage,
                      search: _searchController.text,
                      status: _selectedStatusFilter,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
},
),
),
),
),
);
}


  // ─── Mobile Stacked Cards Layout (<768px Viewport) ─────────────────────────

  Widget _buildMobileStackedCardsList(
    BuildContext context,
    List<ImportFileModel> items,
    AppLocalizations l,
    bool isDark,
    Map<int, List<PurchaseOrderModel>> linkedPOsCache,
    List<PurchaseOrderModel> allPOs,
    dynamic paginatedState,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final file = items[index];
        final priorityText = _getPriorityLabel(file.priority, l);
        final statusText = _getStatusLabel(file.status, l);
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        final resolvedStage = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr);
        final shipDisplayName = DisplayNameResolver.resolveShipmentName(file, isArabic: isAr);

        String poDisplay;
        if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
          poDisplay = file.poNumber!.trim();
        } else {
          final linkedPOs = linkedPOsCache.putIfAbsent(file.importFileId, () => ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs));
          if (linkedPOs.isNotEmpty) {
            poDisplay = linkedPOs.map((p) => (p.poReference != null && p.poReference!.trim().isNotEmpty && p.poReference != file.customFileNumber && p.poReference != file.importFileCode) ? p.poReference! : p.poNumber).join(', ');
          } else {
            poDisplay = '-';
          }
        }
        final piDisplay = file.piNumber != null && file.piNumber!.trim().isNotEmpty ? file.piNumber!.trim() : '-';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _highlightedFileId == file.importFileId
                  ? AppTheme.cobalt
                  : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              width: _highlightedFileId == file.importFileId ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Shipment Name & Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showImportFileDetailsDialog(context, file),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shipDisplayName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(height: 2),
                          LtrText(
                            file.importFileCode,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Chip(
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(priorityText, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: file.priority == 'High' || file.priority == 'Critical' ? AppTheme.wcagCrimson : AppTheme.wcagOrange,
                      ),
                      Chip(
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: Text(statusText, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: file.status == 'Open' ? AppTheme.wcagEmerald : (isDark ? const Color(0xFF475569) : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),
              // Importer & Supplier
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.importingCompany, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                        Text(file.companyName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.foreignSupplier, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                        Text(file.supplierName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // PO & Mode
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.poInvoiceLabel, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                        Text('${l.poNumberShortPrefix}$poDisplay │ ${l.piNumberShortPrefix}$piDisplay', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.transportModeIncoterm, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                        Text('${file.shipmentMode} (${file.incotermCode})', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Stage & Progress
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.currentPhaseStage, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                        Text(resolvedStage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${file.progressPercent.toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        LinearProgressIndicator(value: file.progressPercent / 100, color: AppTheme.wcagEmerald, backgroundColor: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Actions row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.summarize_outlined, color: AppTheme.cobalt, size: 18),
                    tooltip: 'تقرير الشحنة الشامل المدمج (Screen 47)',
                    onPressed: () {
                      ref.read(selectedComprehensiveReportFileIdProvider.notifier).state = file.importFileId;
                      selectNavigationIndex(ref, 47, tabTitle: 'تقرير الشحنة الشامل المدمج');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 18),
                    tooltip: l.viewDetails,
                    onPressed: () => _showImportFileDetailsDialog(context, file),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: l.edit,
                    onPressed: () => _showAddEditFileDialog(file),
                  ),
                  IconButton(
                    icon: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 18),
                    tooltip: l.cloneImportFileDialogTitle,
                    onPressed: () => _showCloneDialog(file),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_add_check_circle, color: AppTheme.cobalt, size: 18),
                    tooltip: l.smartChecklistTooltip,
                    onPressed: () => SmartChecklistDialog.show(context, file),
                  ),
                  if (file.status != 'Closed')
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppTheme.wcagCrimson, size: 18),
                      tooltip: l.stopShipmentTooltip,
                      onPressed: () {
                        StopShipmentDialog.show(
                          context,
                          importFile: file,
                          currentPhaseName: file.currentModule,
                          onSuccess: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page),
                        );
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.play_arrow, color: AppTheme.wcagEmerald, size: 18),
                      tooltip: l.reopenShipmentTooltip,
                      onPressed: () {
                        ReopenShipmentDialog.show(
                          context,
                          importFile: file,
                          onSuccess: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportImportFilesToExcel(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
    final files = ref.read(paginatedImportFilesProvider).items;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'لا توجد شحنات للتصدير' : 'No import files to export'), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    final headers = [
      isArabic ? 'رقم ملف الشحنة' : 'File Number',
      isArabic ? 'الشركة المستوردة' : 'Importing Company',
      isArabic ? 'أمر الشراء / الفاتورة' : 'PO / PI',
      isArabic ? 'المورد الأجنبي' : 'Supplier',
      isArabic ? 'طريقة الشحن / الشرط' : 'Transport / Incoterm',
      isArabic ? 'الأولوية' : 'Priority',
      isArabic ? 'تاريخ الوصول المتوقع' : 'Target ETA',
      isArabic ? 'المرحلة الحالية' : 'Current Stage',
      isArabic ? 'نسبة الإنجاز' : 'Progress %',
      isArabic ? 'الإجراء التالي' : 'Next Action',
      isArabic ? 'المسؤول' : 'Owner',
      isArabic ? 'الحالة' : 'Status',
    ];

    final rows = files.map((f) {
      final priorityText = _getPriorityLabel(f.priority, l);
      final statusText = _getStatusLabel(f.status, l);
      final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isArabic);
      final resolvedAction = f.displayNextAction(context.l10n);
      final fileDisplay = f.customFileNumber ?? f.importFileCode;
      final poDisplay = (f.poNumber != null && f.poNumber!.isNotEmpty) ? f.poNumber! : '-';
      final piDisplay = (f.piNumber != null && f.piNumber!.isNotEmpty) ? f.piNumber! : '-';
      return [
        fileDisplay,
        f.companyName,
        'PO: $poDisplay | PI: $piDisplay',
        f.supplierName,
        '${f.shipmentMode} (${f.incotermCode})',
        priorityText,
        f.requiredEta ?? '-',
        resolvedStage,
        '${f.progressPercent.toInt()}%',
        resolvedAction,
        f.owner,
        statusText,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isArabic ? 'ملفات الشحنات الاستيرادية' : 'Import Files',
      importFileNameOrCode: 'Import_Files_Registry',
    );
  }

  Future<void> _exportImportFilesToPdf(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
    final files = ref.read(paginatedImportFilesProvider).items;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'لا توجد شحنات للتصدير' : 'No import files to export'), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    final headers = [
      isArabic ? 'رقم الملف' : 'File No',
      isArabic ? 'الشركة' : 'Company',
      isArabic ? 'أمر الشراء' : 'PO/PI',
      isArabic ? 'المورد' : 'Supplier',
      isArabic ? 'الشحن/الشرط' : 'Mode/Inco',
      isArabic ? 'المرحلة' : 'Stage',
      isArabic ? 'الإنجاز' : 'Progress',
      isArabic ? 'الحالة' : 'Status',
    ];

    final rows = files.map((f) {
      final statusText = _getStatusLabel(f.status, l);
      final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isArabic);
      final fileDisplay = f.customFileNumber ?? f.importFileCode;
      final poDisplay = (f.poNumber != null && f.poNumber!.isNotEmpty) ? f.poNumber! : '-';
      return [
        fileDisplay,
        f.companyName,
        poDisplay,
        f.supplierName,
        '${f.shipmentMode} (${f.incotermCode})',
        resolvedStage,
        '${f.progressPercent.toInt()}%',
        statusText,
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: isArabic ? 'ملفات الشحنات الاستيرادية' : 'Import Files',
      importFileNameOrCode: 'Import_Files_Registry',
      headerContext: TableExportHeaderContext(
        title: isArabic ? 'سجل ملفات الشحنات الاستيرادية' : 'Import Files Master Registry',
        subtitle: 'Sorour Logistics ERP',
        metadata: {
          isArabic ? 'إجمالي الملفات' : 'Total Files': '${files.length}',
          isArabic ? 'تاريخ التقرير' : 'Report Date': DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  void _copyImportFilesTableAsTsv(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
    final files = ref.read(paginatedImportFilesProvider).items;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'لا توجد شحنات للنسخ' : 'No import files to copy'), backgroundColor: AppTheme.crimson),
      );
      return;
    }

    final headers = [
      isArabic ? 'رقم ملف الشحنة' : 'File Number',
      isArabic ? 'الشركة المستوردة' : 'Importing Company',
      isArabic ? 'أمر الشراء / الفاتورة' : 'PO / PI',
      isArabic ? 'المورد الأجنبي' : 'Supplier',
      isArabic ? 'طريقة الشحن / الشرط' : 'Transport / Incoterm',
      isArabic ? 'الأولوية' : 'Priority',
      isArabic ? 'تاريخ الوصول المتوقع' : 'Target ETA',
      isArabic ? 'المرحلة الحالية' : 'Current Stage',
      isArabic ? 'نسبة الإنجاز' : 'Progress %',
      isArabic ? 'الإجراء التالي' : 'Next Action',
      isArabic ? 'المسؤول' : 'Owner',
      isArabic ? 'الحالة' : 'Status',
    ];

    final rows = files.map((f) {
      final priorityText = _getPriorityLabel(f.priority, l);
      final statusText = _getStatusLabel(f.status, l);
      final resolvedStage = DisplayNameResolver.resolveStepName(f.displayStepKey, isArabic: isArabic);
      final resolvedAction = f.displayNextAction(context.l10n);
      final fileDisplay = f.customFileNumber ?? f.importFileCode;
      final poDisplay = (f.poNumber != null && f.poNumber!.isNotEmpty) ? f.poNumber! : '-';
      final piDisplay = (f.piNumber != null && f.piNumber!.isNotEmpty) ? f.piNumber! : '-';
      return [
        fileDisplay,
        f.companyName,
        'PO: $poDisplay | PI: $piDisplay',
        f.supplierName,
        '${f.shipmentMode} (${f.incotermCode})',
        priorityText,
        f.requiredEta ?? '-',
        resolvedStage,
        '${f.progressPercent.toInt()}%',
        resolvedAction,
        f.owner,
        statusText,
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: isArabic ? 'تم نسخ بيانات الشحنات كجدول بنجاح' : 'Import files table copied to clipboard',
    );
  }

  Widget _buildDesktopCompactToolbar(BuildContext context, bool isDark, AppLocalizations l) {
    final density = ref.watch(displayDensityProvider);
    return ActionToolbar(
      primaryActions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.wcagCobalt,
            foregroundColor: Colors.white,
            minimumSize: Size(0, density.buttonHeight),
            padding: density.buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: () => _showAddEditFileDialog(),
          icon: Icon(Icons.add_box, size: density.buttonIconSize, color: Colors.white),
          label: Text(
            l.addNewImportFile,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
            side: BorderSide(color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
            minimumSize: Size(0, density.buttonHeight),
            padding: density.buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: _openSearchAndCloneDialog,
          icon: Icon(Icons.control_point_duplicate_rounded, size: density.buttonIconSize),
          label: Text(
            l.searchAndCloneImportFileBtn,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
        ),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMoreActionsMenu(context, isDark, l),
          const SizedBox(width: 6),
          _buildQuickDataActions(context, isDark, l),
        ],
      ),
      searchController: _searchController,
      searchHint: l.searchByShipmentOrCompany,
      onSearchChanged: (val) {
        ref.read(paginatedImportFilesProvider.notifier).fetchPage(1, search: val, status: _selectedStatusFilter);
      },
      filters: [
        SizedBox(
          width: 125,
          height: density.buttonHeight,
          child: SearchableDropdownField<String>(
            value: _selectedStatusFilter,
            labelText: '',
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
            ),
            items: [
              SearchableDropdownItem(value: 'All', label: l.statusAll),
              SearchableDropdownItem(value: 'Open', label: l.statusOpen),
              SearchableDropdownItem(value: 'In Progress', label: l.statusInProgress),
              SearchableDropdownItem(value: 'Closed', label: l.statusClosed),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedStatusFilter = val);
                ref.read(paginatedImportFilesProvider.notifier).fetchPage(1, search: _searchController.text, status: val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileToolbar(BuildContext context, bool isDark, AppLocalizations l) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.wcagCobalt,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: () => _showAddEditFileDialog(),
          icon: const Icon(Icons.add_box, size: 16, color: Colors.white),
          label: Text(l.addNewImportFile, style: const TextStyle(fontSize: 12)),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
            side: BorderSide(color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt),
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: _openSearchAndCloneDialog,
          icon: const Icon(Icons.control_point_duplicate_rounded, size: 16),
          label: Text(l.searchAndCloneImportFileBtn, style: const TextStyle(fontSize: 12)),
        ),
        _buildMoreActionsMenu(context, isDark, l),
        _buildQuickDataActions(context, isDark, l),
        SizedBox(
          width: 170,
          height: 32,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: l.searchByShipmentOrCompany,
              hintStyle: const TextStyle(fontSize: 11),
              prefixIcon: const Icon(Icons.search, size: 16),
              prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onChanged: (val) {
              ref.read(paginatedImportFilesProvider.notifier).fetchPage(1, search: val, status: _selectedStatusFilter);
            },
          ),
        ),
        SizedBox(
          width: 115,
          height: 32,
          child: SearchableDropdownField<String>(
            value: _selectedStatusFilter,
            labelText: '',
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              filled: true,
              fillColor: isDark ? AppTheme.darkInputBackground : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            items: [
              SearchableDropdownItem(value: 'All', label: l.statusAll),
              SearchableDropdownItem(value: 'Open', label: l.statusOpen),
              SearchableDropdownItem(value: 'In Progress', label: l.statusInProgress),
              SearchableDropdownItem(value: 'Closed', label: l.statusClosed),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedStatusFilter = val);
                ref.read(paginatedImportFilesProvider.notifier).fetchPage(1, search: _searchController.text, status: val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMoreActionsMenu(BuildContext context, bool isDark, AppLocalizations l) {
    final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
    return PopupMenuButton<int>(
      tooltip: l.moreToolsTooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      elevation: 6,
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 320),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
      ),
      onSelected: (val) {
        if (val == 1) _promptAndShowMasterReport();
        if (val == 2) showDialog(context: context, builder: (_) => const SmartInvoiceBLExtractorDialog());
        if (val == 3) showDialog(context: context, builder: (_) => const WhatIfSimulatorDialog());
        if (val == 4) _handleImportExcel();
        if (val == 5) _copyImportFilesTableAsTsv(context);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 1,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.summarize, size: 18, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.generateComprehensiveReport,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.smartInvoiceBlExtractorButton,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 3,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.charcoal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.whatIfSimulatorButton,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 4,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.upload_file, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'استيراد من إكسل' : 'Import Excel',
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 5,
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.content_copy, size: 18, color: AppTheme.cobalt),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'نسخ الجدول (TSV)' : 'Copy Table (TSV)',
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isArabic ? 'إجراءات إضافية' : 'More actions',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.more_vert,
              size: 16,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDataActions(BuildContext context, bool isDark, AppLocalizations l) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.refresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.refresh, size: 17, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
            onPressed: () => ref.read(paginatedImportFilesProvider.notifier).fetchPage(1),
          ),
          VerticalDivider(width: 1, thickness: 1, indent: 6, endIndent: 6, color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          IconButton(
            tooltip: 'تصدير إكسل (Excel)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(Icons.table_chart, size: 17, color: Colors.green.shade700),
            onPressed: () => _exportImportFilesToExcel(context),
          ),
          VerticalDivider(width: 1, thickness: 1, indent: 6, endIndent: 6, color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          IconButton(
            tooltip: 'تصدير بي دي إف (PDF)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.picture_as_pdf, size: 17, color: AppTheme.crimson),
            onPressed: () => _exportImportFilesToPdf(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImportExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read file bytes'),
              backgroundColor: AppTheme.crimson,
            ),
          );
        }
        return;
      }

      final dio = ref.read(uploadDioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
      });

      final response = await dio.post(
        '/import-files/import-excel',
        data: formData,
      );

      if (!mounted) return;
      final isArabic = Directionality.of(context) == TextDirection.rtl || ref.watch(localeProvider).languageCode == 'ar';
      final message = response.data['message'] ?? (isArabic ? 'تم استيراد البيانات بنجاح' : 'Import successful');
      final List errors = response.data['errors'] ?? [];

      ref.read(paginatedImportFilesProvider.notifier).fetchPage(1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.isEmpty ? message : '$message (${errors.length} errors)'),
          backgroundColor: errors.isEmpty ? AppTheme.emerald : AppTheme.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }
}

/// Dedicated Search & Clone Dialog for Import Files (UX-CLONE-011).
/// Allows searching through shipments by code, client, supplier, or PO,
/// and instantly cloning the selected shipment as a new template.
class _SearchAndCloneImportFileDialog extends StatefulWidget {
  final List<ImportFileModel> files;
  final ValueChanged<ImportFileModel> onSelectFile;

  const _SearchAndCloneImportFileDialog({
    required this.files,
    required this.onSelectFile,
  });

  @override
  State<_SearchAndCloneImportFileDialog> createState() => _SearchAndCloneImportFileDialogState();
}

class _SearchAndCloneImportFileDialogState extends State<_SearchAndCloneImportFileDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<ImportFileModel> _filteredFiles;

  @override
  void initState() {
    super.initState();
    _filteredFiles = widget.files;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _queryController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFiles = widget.files;
      } else {
        _filteredFiles = widget.files.where((f) {
          final code = f.importFileCode.toLowerCase();
          final customNum = (f.customFileNumber ?? '').toLowerCase();
          final comp = f.companyName.toLowerCase();
          final supp = f.supplierName.toLowerCase();
          final po = (f.poNumber ?? '').toLowerCase();
          return code.contains(query) ||
              customNum.contains(query) ||
              comp.contains(query) ||
              supp.contains(query) ||
              po.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.searchAndCloneImportFileDialogTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.searchAndCloneImportFileSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: l.searchAndCloneImportFileHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _queryController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppTheme.darkInputBackground : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Results count
            Text(
              l.resultsWithCount(_filteredFiles.length),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            // Results List
            Expanded(
              child: _filteredFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 48, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            l.noMatchingShipmentsFound,
                            style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final file = _filteredFiles[idx];
                        final shipName = DisplayNameResolver.resolveShipmentName(file, isArabic: isAr);
                        final stageName = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          shipName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                                          ),
                                        ),
                                        if (shipName != file.importFileCode) ...[
                                          const SizedBox(width: 8),
                                          LtrText(
                                            file.importFileCode,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 8),
                                        Chip(
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          label: Text(file.status, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                          backgroundColor: file.status == 'Open' ? AppTheme.wcagEmerald : (isDark ? const Color(0xFF475569) : Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${file.companyName} │ ${file.supplierName} │ ${file.shipmentMode} (${file.incotermCode})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${l.currentPhaseStage}: $stageName │ ${file.progressPercent.toInt()}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.wcagCobalt,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.control_point_duplicate_rounded, size: 16, color: Colors.white),
                                label: Text(
                                  l.cloneBtn,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                onPressed: () => widget.onSelectFile(file),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


