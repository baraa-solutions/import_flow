import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../lifecycle_board/widgets/skip_step_dialog_helper.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../../smart_checklists/widgets/smart_checklist_dialog.dart';
import '../../models/import_file_model.dart';
import '../../providers/import_files_provider.dart';
import '../freight_rfq_dialog.dart';
import 'import_files_export_helper.dart';

/// Builds the 13 EnterpriseDataTable columns for the Import Files screen.
List<EnterpriseColumn<ImportFileModel>> buildImportFilesTableColumns({
  required BuildContext context,
  required WidgetRef ref,
  required AppLocalizations l,
  required bool isDark,
  required bool isAr,
  required dynamic density,
  required dynamic paginatedState,
  required Map<int, List<PurchaseOrderModel>> linkedPOsCache,
  required List<PurchaseOrderModel> allPOs,
  required ValueChanged<ImportFileModel> onViewDetails,
  required ValueChanged<ImportFileModel> onEdit,
  required ValueChanged<ImportFileModel> onClone,
  required ValueChanged<ImportFileModel> onSmartReference,
}) {
  const double colActionsWidth = 215.0;
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

  return [
    EnterpriseColumn<ImportFileModel>(
      id: 'actions',
      title: l.actions,
      width: colActionsWidth,
      isSortable: false,
      isSearchable: false,
      cellBuilder: (context, file, index) {
        final resolvedStage = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr);
        return SingleChildScrollView(
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
                onPressed: () => onClone(file),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.auto_awesome, color: AppTheme.cobalt, size: 18),
                tooltip: Localizations.localeOf(context).languageCode == 'ar'
                    ? 'المرجع الذكي للشحنة (Smart Reference)'
                    : 'Shipment Smart Reference',
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => onSmartReference(file),
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
                key: Key('openComprehensiveReportBtn_${file.importFileId}'),
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
              IconButton(
                icon: const Icon(Icons.rate_review_outlined, color: AppTheme.cobalt, size: 18),
                tooltip: 'ملاحظات ومرفقات الشحنة',
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => StageNotesCard.showAsDialog(
                  context,
                  screenCode: 'import_files',
                  recordId: file.importFileId,
                  stageCode: file.currentStage,
                  title: 'ملاحظات ومرفقات الشحنة',
                ),
              ),
              const SizedBox(width: 4),
              RowActionsPill(
                onView: () => onViewDetails(file),
                onEdit: () => onEdit(file),
                onClone: () => onClone(file),
                onPrint: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    AppTheme.snackBar(
                      context,
                      '${l.printFileHistoryTooltip}: ${file.customFileNumber ?? file.importFileCode}',
                      severity: AppSeverity.info,
                    ),
                  );
                },
                onDelete: () async {
                  final confirm = await AppConfirmDialog.showDelete(
                    context,
                    title: l.confirmDeleteImportFileTitle,
                    message: l.confirmDeleteImportFilePrompt(file.customFileNumber ?? file.importFileCode),
                  );
                  if (confirm) {
                    await ref.read(importFilesProvider.notifier).softDeleteImportFile(file.importFileId);
                    ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page);
                  }
                },
              ),
            ],
          ),
        );
      },
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'file_id',
      title: l.importFileIdLabel,
      width: colFileIdWidth,
      isSortable: true,
      searchValue: (file) => '${DisplayNameResolver.resolveShipmentName(file, isArabic: isAr)} ${file.importFileCode} ${file.clonedFromCode ?? ""} ${file.parentFileCode ?? ""}',
      exportValue: (file) => DisplayNameResolver.resolveShipmentName(file, isArabic: isAr),
      cellBuilder: (context, file, index) {
        final shipDisplayName = DisplayNameResolver.resolveShipmentName(file, isArabic: isAr);
        return InkWell(
          onTap: () => onViewDetails(file),
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
              if (file.isChildPartial && file.parentFileCode != null)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade700, width: 0.8),
                  ),
                  child: Text(
                    'دفعة جزئية من ${file.parentFileCode}',
                    style: TextStyle(
                      fontSize: density.tableCellSecondaryFontSize - 1,
                      color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (file.isParentPartial)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade700, width: 0.8),
                  ),
                  child: Text(
                    'شحنة مجزأة (رئيسية)',
                    style: TextStyle(
                      fontSize: density.tableCellSecondaryFontSize - 1,
                      color: isDark ? Colors.lightBlueAccent : Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'company',
      title: l.importingCompany,
      width: colCompanyWidth,
      isSortable: true,
      searchValue: (file) => file.companyName,
      exportValue: (file) => file.companyName,
      cellBuilder: (context, file, index) => Text(file.companyName, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'po_invoice',
      title: l.poInvoiceLabel,
      width: colPoWidth,
      isSortable: true,
      searchValue: (file) {
        String poDisplay;
        if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
          poDisplay = file.poNumber!.trim();
        } else {
          final linkedPOs = linkedPOsCache.putIfAbsent(file.importFileId, () => ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs));
          poDisplay = linkedPOs.isNotEmpty ? linkedPOs.map((p) => p.poNumber).join(', ') : '-';
        }
        final piDisplay = file.piNumber != null && file.piNumber!.trim().isNotEmpty ? file.piNumber!.trim() : '-';
        return '$poDisplay $piDisplay';
      },
      exportValue: (file) {
        String poDisplay;
        if (file.poNumber != null && file.poNumber!.trim().isNotEmpty) {
          poDisplay = file.poNumber!.trim();
        } else {
          final linkedPOs = linkedPOsCache.putIfAbsent(file.importFileId, () => ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs));
          poDisplay = linkedPOs.isNotEmpty ? linkedPOs.map((p) => p.poNumber).join(', ') : '-';
        }
        final piDisplay = file.piNumber != null && file.piNumber!.trim().isNotEmpty ? file.piNumber!.trim() : '-';
        return '$poDisplay | $piDisplay';
      },
      cellBuilder: (context, file, index) {
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
        return Column(
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
        );
      },
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'supplier',
      title: l.foreignSupplier,
      width: colSupplierWidth,
      isSortable: true,
      searchValue: (file) => file.supplierName,
      exportValue: (file) => file.supplierName,
      cellBuilder: (context, file, index) => Text(file.supplierName),
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'transport',
      title: l.transportModeIncoterm,
      width: colTransportWidth,
      isSortable: true,
      searchValue: (file) => '${file.shipmentMode} (${file.incotermCode})',
      exportValue: (file) => '${file.shipmentMode} (${file.incotermCode})',
      cellBuilder: (context, file, index) => Text('${file.shipmentMode} (${file.incotermCode})'),
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'priority',
      title: l.priorityType,
      width: colPriorityWidth,
      isSortable: true,
      searchValue: (file) => file.priority,
      exportValue: (file) => ImportFilesExportHelper.getPriorityLabel(file.priority, l),
      cellBuilder: (context, file, index) {
        final priorityText = ImportFilesExportHelper.getPriorityLabel(file.priority, l);
        return AppStatusBadge(
          label: priorityText,
          severity: file.priority == 'High' || file.priority == 'Critical' ? AppSeverity.danger : AppSeverity.warning,
          size: AppStatusBadgeSize.small,
        );
      },
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'eta',
      title: l.targetEta,
      width: colEtaWidth,
      isSortable: true,
      searchValue: (file) => file.requiredEta ?? '',
      exportValue: (file) => file.requiredEta ?? '-',
      cellBuilder: (context, file, index) => Text(file.requiredEta ?? '-'),
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'stage',
      title: l.currentPhaseStage,
      width: colStageWidth,
      isSortable: true,
      searchValue: (file) => DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr),
      exportValue: (file) => DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr),
      cellBuilder: (context, file, index) {
        final resolvedStage = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr);
        return Text(resolvedStage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold));
      },
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'progress',
      title: l.progressPercentLabel,
      width: colProgressWidth,
      isSortable: true,
      sortComparator: (a, b) => a.progressPercent.compareTo(b.progressPercent),
      exportValue: (file) => '${file.progressPercent.toInt()}%',
      cellBuilder: (context, file, index) => SizedBox(
        width: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LinearProgressIndicator(
              value: file.progressPercent / 100,
              backgroundColor: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              color: AppTheme.wcagEmerald,
            ),
            const SizedBox(height: 2),
            Text('${file.progressPercent.toInt()}%', style: TextStyle(fontSize: density.tableCellSecondaryFontSize, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'next_action',
      title: l.nextActionLabel,
      width: colNextActionWidth,
      isSortable: false,
      exportValue: (file) => file.displayNextAction(context.l10n),
      cellBuilder: (context, file, index) {
        final resolvedAction = file.displayNextAction(context.l10n);
        return Text(resolvedAction, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal));
      },
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'owner',
      title: l.responsiblePersonLabel,
      width: colOwnerWidth,
      isSortable: true,
      searchValue: (file) => file.owner,
      exportValue: (file) => file.owner,
      cellBuilder: (context, file, index) => Text(file.owner, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
    EnterpriseColumn<ImportFileModel>(
      id: 'status',
      title: l.status,
      width: colStatusWidth,
      isSortable: true,
      searchValue: (file) => ImportFilesExportHelper.getStatusLabel(file.status, l),
      exportValue: (file) => ImportFilesExportHelper.getStatusLabel(file.status, l),
      cellBuilder: (context, file, index) {
        final statusText = ImportFilesExportHelper.getStatusLabel(file.status, l);
        return AppStatusBadge.fromStatus(
          status: file.status,
          label: statusText,
          size: AppStatusBadgeSize.small,
        );
      },
    ),
  ];
}
