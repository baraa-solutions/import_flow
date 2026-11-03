import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/cc_dialog_shell.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../models/shipment_update_model.dart';
import '../../providers/shipment_updates_provider.dart';
import '../shipment_update_dialog.dart';
import '../su_ui.dart';

class SuLogsTableCard extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isAr;
  final ShipmentUpdatesState updatesState;
  final VoidCallback onReload;
  final void Function(ShipmentUpdateLogModel) onDeleteLog;
  final String Function(AppLocalizations, String) getPhaseName;
  final String Function(AppLocalizations, String) getStatusName;
  final String Function(AppLocalizations, String) getCategoryLabel;

  const SuLogsTableCard({
    super.key,
    required this.l10n,
    required this.isAr,
    required this.updatesState,
    required this.onReload,
    required this.onDeleteLog,
    required this.getPhaseName,
    required this.getStatusName,
    required this.getCategoryLabel,
  });

  String _buildRowSummary(BuildContext context, ShipmentUpdateLogModel log) {
    final b = StringBuffer();
    b.writeln('${l10n.shipmentUpdatesTsvHeaderCode}: ${log.updateCode}');
    b.writeln('${l10n.shipmentUpdatesTsvHeaderDate}: ${log.logDate}');
    b.writeln('${l10n.shipmentUpdatesTsvHeaderCategory}: ${getCategoryLabel(l10n, log.updateCategory)}');
    b.writeln('${l10n.shipmentUpdatesTsvHeaderPhase}: ${getPhaseName(l10n, log.targetPhase)}');
    if (log.updateCategory == 'Phase Cost Adjustment') {
      b.writeln('${l10n.shipmentUpdatesTsvHeaderCostItem}: ${log.adjustedCostItem ?? l10n.shipmentUpdateCostLabel}');
      b.writeln('${l10n.shipmentUpdatesTsvHeaderPrevCost}: ${log.previousCost.toStringAsFixed(2)}');
      b.writeln('${l10n.shipmentUpdatesTsvHeaderNewCost}: ${log.newCost.toStringAsFixed(2)}');
    }
    b.writeln('${l10n.shipmentUpdatesTsvHeaderPriority}: ${log.alertPriority}');
    b.writeln('${l10n.shipmentUpdatesTsvHeaderAssignedUser}: ${log.assignedUser}');
    b.writeln('${l10n.shipmentUpdatesTsvHeaderNotes}: ${log.note}');
    return b.toString().trim();
  }

  void _showLogViewDialog(BuildContext context, ShipmentUpdateLogModel log) {
    showDialog(
      context: context,
      builder: (c) => SelectionArea(
        child: CcStageDialogShell(
          title: l10n.shipmentUpdateViewDialogTitle(log.updateCode),
          icon: Icons.visibility_rounded,
          maxWidth: 560,
          chips: [CcHeaderChip(Icons.confirmation_number_outlined, log.updateCode, ltr: true)],
          showCancel: false,
          confirmLabel: l10n.shipmentUpdateViewCloseBtn,
          confirmIcon: Icons.close,
          confirmVariant: AppButtonVariant.secondary,
          isSubmitting: false,
          onConfirm: () => Navigator.pop(c),
          body: CcFormSection(
            title: l10n.shipmentUpdateViewDialogTitle(log.updateCode),
            icon: Icons.notes_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shipmentUpdateViewStage(getPhaseName(l10n, log.targetPhase)),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(l10n.shipmentUpdateViewDate(log.logDate)),
                const SizedBox(height: 4),
                Text(l10n.shipmentUpdateViewUser(log.assignedUser)),
                const SizedBox(height: 10),
                Text('${l10n.shipmentUpdateViewNotes}\n${log.note}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (updatesState.isLoading) {
      content = const SizedBox(height: 160, child: CcStateView.loading());
    } else if (updatesState.error != null) {
      content = CcStateView.error(
        message: l10n.shipmentUpdateLogsFetchError(updatesState.error.toString()),
        actionLabel: l10n.retry,
        onAction: onReload,
      );
    } else if (updatesState.logs.isEmpty) {
      content = CcStateView.empty(
        message: l10n.shipmentUpdateLogsEmptyMessage,
        icon: Icons.history_toggle_off_rounded,
      );
    } else {
      content = EnterpriseDataTable<ShipmentUpdateLogModel>(
        storageKey: 'shipment_updates_logs_table',
        data: updatesState.logs,
        rowHeight: 52,
        emptyMessage: l10n.shipmentUpdateLogsEmptyMessage,
        columns: [
          EnterpriseColumn<ShipmentUpdateLogModel>(
            id: 'actions',
            title: l10n.shipmentUpdateColActions,
            width: 200,
            isSortable: false,
            isSearchable: false,
            cellBuilder: (ctx, log, index) {
              final rowSummary = _buildRowSummary(ctx, log);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RowActionsPill(
                    onView: () => _showLogViewDialog(ctx, log),
                    onEdit: () {
                      ShipmentUpdateDialog.show(
                        ctx,
                        initialFileId: log.importFileId,
                        initialTargetPhase: log.targetPhase,
                        defaultCategory: log.updateCategory,
                      );
                    },
                    onPrint: () => MasterDataExportService.printOrSaveShipmentUpdateSlipPdf(log, isAr: isAr),
                    onDelete: () => onDeleteLog(log),
                    viewTooltip: l10n.shipmentUpdateActionViewTooltip,
                    editTooltip: l10n.shipmentUpdateActionEditTooltip,
                    printTooltip: l10n.shipmentUpdateActionPrintTooltip,
                    deleteTooltip: l10n.shipmentUpdateActionDeleteTooltip,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.cobalt),
                    tooltip: l10n.shipmentUpdateCopySummaryBtn,
                    onPressed: () => CopyHelper.copy(
                      ctx,
                      rowSummary,
                      customMessage: l10n.shipmentUpdateCopySummarySuccess,
                    ),
                  ),
                ],
              );
            },
          ),
          EnterpriseColumn<ShipmentUpdateLogModel>(
            id: 'code',
            title: l10n.shipmentUpdateColCode,
            width: 130,
            exportValue: (log) => log.updateCode,
            searchValue: (log) => log.updateCode,
            cellBuilder: (ctx, log, index) {
              final rowSummary = _buildRowSummary(ctx, log);
              return CopyableTableCell(
                value: log.updateCode,
                rowSummary: rowSummary,
                child: SuCodeBadge(code: log.updateCode, copiedMessage: l10n.shipmentUpdateCodeBadgeLabel, fontSize: 12),
              );
            },
          ),
          EnterpriseColumn<ShipmentUpdateLogModel>(
            id: 'date',
            title: l10n.shipmentUpdateColDate,
            width: 120,
            exportValue: (log) => log.logDate,
            searchValue: (log) => log.logDate,
            cellBuilder: (ctx, log, index) {
              final rowSummary = _buildRowSummary(ctx, log);
              return CopyableTableCell(
                value: log.logDate,
                rowSummary: rowSummary,
                child: LtrText(log.logDate),
              );
            },
          ),
          EnterpriseColumn<ShipmentUpdateLogModel>(
            id: 'type',
            title: l10n.shipmentUpdateColType,
            width: 160,
            exportValue: (log) => getCategoryLabel(l10n, log.updateCategory),
            searchValue: (log) => getCategoryLabel(l10n, log.updateCategory),
            cellBuilder: (ctx, log, index) {
              final categoryLabel = getCategoryLabel(l10n, log.updateCategory);
              final rowSummary = _buildRowSummary(ctx, log);
              return CopyableTableCell(
                value: categoryLabel,
                rowSummary: rowSummary,
                child: CcStatusChip(label: categoryLabel, severity: SuUi.categorySeverity(log.updateCategory)),
              );
            },
          ),
          EnterpriseColumn<ShipmentUpdateLogModel>(
            id: 'targetStage',
            title: l10n.shipmentUpdateColTargetStage,
            width: 140,
            exportValue: (log) => getPhaseName(l10n, log.targetPhase),
            searchValue: (log) => getPhaseName(l10n, log.targetPhase),
            cellBuilder: (ctx, log, index) {
              final rowSummary = _buildRowSummary(ctx, log);
              return CopyableTableCell(
                value: getPhaseName(l10n, log.targetPhase),
                rowSummary: rowSummary,
                child: Text(getPhaseName(l10n, log.targetPhase), style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          ),
          EnterpriseColumn<ShipmentUpdateLogModel>(
            id: 'notes',
            title: l10n.shipmentUpdateColNotes,
            flex: 2,
            exportValue: (log) => log.note,
            searchValue: (log) => log.note,
            cellBuilder: (ctx, log, index) {
              final rowSummary = _buildRowSummary(ctx, log);
              return CopyableTableCell(
                value: log.note,
                rowSummary: rowSummary,
                child: Text(log.note, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              );
            },
          ),
          EnterpriseColumn<ShipmentUpdateLogModel>(
            id: 'costAdjustment',
            title: l10n.shipmentUpdateColCostAdjustment,
            width: 160,
            exportValue: (log) => log.updateCategory == 'Phase Cost Adjustment'
                ? '${log.adjustedCostItem ?? l10n.shipmentUpdateCostLabel}: ${log.previousCost} -> ${log.newCost} ${l10n.shipmentUpdateCostCurrencyUsd}'
                : '-',
            cellBuilder: (ctx, log, index) {
              final isCostAdj = log.updateCategory == 'Phase Cost Adjustment';
              final costText = '${log.adjustedCostItem ?? l10n.shipmentUpdateCostLabel}: ${log.previousCost} -> ${log.newCost} ${l10n.shipmentUpdateCostCurrencyUsd}';
              final rowSummary = _buildRowSummary(ctx, log);
              return CopyableTableCell(
                value: isCostAdj ? costText : '-',
                rowSummary: rowSummary,
                child: isCostAdj
                    ? Text(
                        costText,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson, fontSize: 11),
                      )
                    : const Text('-'),
              );
            },
          ),
          EnterpriseColumn<ShipmentUpdateLogModel>(
            id: 'assignedUser',
            title: l10n.shipmentUpdateColAssignedUser,
            width: 130,
            exportValue: (log) => log.assignedUser,
            searchValue: (log) => log.assignedUser,
            cellBuilder: (ctx, log, index) {
              final rowSummary = _buildRowSummary(ctx, log);
              return CopyableTableCell(
                value: log.assignedUser,
                rowSummary: rowSummary,
                child: Text(log.assignedUser),
              );
            },
          ),
        ],
      );
    }

    return Container(
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
