import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../comprehensive_report/widgets/shipment_audit_timeline_dialog.dart';
import '../../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../providers/import_files_provider.dart';
import '../master_report/master_report.dart';
import '../sections/timeline_matrix_section.dart';

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
            return SelectionArea(
              child: AlertDialog(
                backgroundColor: isDarkPrompt ? AppTheme.darkSurface : null,
                title: Row(
                  children: [
                    const Icon(Icons.summarize, color: AppTheme.cobalt, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      l.evaluateMasterReportTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📌 ${l.selectShipmentForReport}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDarkPrompt ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                      ),
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
                  AppButton(
                    label: l.cancel,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                  AppButton(
                    label: l.createAndDisplayReport,
                    icon: Icons.print,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      showMasterReportDialog(context, ref, selectedFileId);
                    },
                  ),
                ],
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

/// Displays the full Master Import Report Dialog Coordinator.
Future<void> showMasterReportDialog(BuildContext context, WidgetRef ref, [int? initialFileId]) async {
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
            final isAr = Localizations.localeOf(ctx).languageCode == 'ar';
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
              child: SelectionArea(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.90,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MasterReportHeader(
                        selectedFileId: selectedFileId,
                        displayFiles: displayFiles,
                        allFiles: report.files,
                        allPOs: allPOs,
                        totalFiles: totalFiles,
                        openFiles: openFiles,
                        inProgressFiles: inProgressFiles,
                        totalCost: totalCost,
                        isDark: isDarkDialog,
                        onShipmentChanged: (val) => setDialogState(() => selectedFileId = val),
                        onClose: () => Navigator.pop(dialogCtx),
                        onTimelineRadar: selectedFileId != null
                            ? () => showShipmentAuditTimelineDialog(context, importFileId: selectedFileId!)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      MasterReportSummaryCards(
                        totalFiles: totalFiles,
                        openFiles: openFiles,
                        inProgressFiles: inProgressFiles,
                        totalCost: totalCost,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MasterReportDocumentsCard(
                                displayFiles: displayFiles,
                                totalFiles: totalFiles,
                                isDark: isDarkDialog,
                                onFileTapped: (f) {
                                  Navigator.pop(dialogCtx);
                                  MasterReportDialogHelpers.showImportFileDetails(context, ref, f);
                                },
                                onTimelineRadarTapped: (fileId) {
                                  showShipmentAuditTimelineDialog(context, importFileId: fileId);
                                },
                              ),
                              const SizedBox(height: 24),
                              MasterReportFinancialsCard(
                                displayFiles: displayFiles,
                                allPOs: allPOs,
                                isDark: isDarkDialog,
                                onSmartReference: (f, pos) =>
                                    MasterReportDialogHelpers.showSmartReference(context, ref, f, pos),
                                onVisualLoadPlan: (f, pos, cbm, wt) =>
                                    MasterReportDialogHelpers.showVisualLoadPlan(context, f, pos, cbm, wt),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  const Icon(Icons.timeline_outlined, color: AppTheme.cobalt, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    isAr
                                        ? '⏱️ 3. الجدول الزمني ومراحل دورة حياة الشحنة - 25 مرحلة'
                                        : '⏱️ 3. Shipment 25-Stage Lifecycle Timeline (Planned vs Actual & Notes)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                    ),
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
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      MasterReportActionsBar(
                        reportFiles: report.files,
                        onClose: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
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
