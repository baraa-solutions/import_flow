import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../models/warehouse_receiving_model.dart';
import 'ops_ui_kit.dart';

/// Visual state of a GRN derived from its stored status string.
class GrnStatusView {
  const GrnStatusView(this.severity, this.label, this.icon);
  final AppSeverity severity;
  final String label;
  final IconData icon;

  static bool isDraftStatus(String status) => status.contains('Draft') || status.contains('Pending');

  static GrnStatusView of(AppLocalizations l, String status) {
    if (isDraftStatus(status)) {
      return GrnStatusView(AppSeverity.warning, l.warehouseReceivingStatusDraft, Icons.hourglass_top_rounded);
    }
    if (status == 'Discrepancy Reported') {
      return GrnStatusView(AppSeverity.danger, l.warehouseReceivingStatusDiscrepancy, Icons.report_problem_outlined);
    }
    if (status == 'Closed' || status == 'Goods Received') {
      return GrnStatusView(AppSeverity.success, l.warehouseReceivingStatusGoodsReceived, Icons.check_circle_outline);
    }
    return GrnStatusView(AppSeverity.info, status, Icons.info_outline);
  }
}

/// One GRN: header chips, aligned detail grid, quantity reconciliation strip
/// and the action bar. Pure presentation; every action is a callback.
class GrnRecordCard extends StatelessWidget {
  const GrnRecordCard({
    super.key,
    required this.record,
    required this.onView,
    required this.onEdit,
    required this.onPrint,
    required this.onDelete,
    required this.onConfirmReceipt,
    required this.onRecordDiscrepancy,
    required this.onOpenInspection,
    required this.onQuarantine,
    required this.onCopyRow,
    required this.onClone,
  });

  final WarehouseReceivingModel record;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;
  final VoidCallback onConfirmReceipt;
  final VoidCallback onRecordDiscrepancy;
  final VoidCallback onOpenInspection;
  final VoidCallback onQuarantine;
  final VoidCallback onCopyRow;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = record;
    final status = GrnStatusView.of(l, r.status);
    final accent = AppTheme.severityForegroundOf(context, status.severity);
    final isDraft = GrnStatusView.isDraftStatus(r.status);
    final arrival = r.arrivalDatetime.replaceFirst('T', ' ').split('.').first;
    final driverTruck = '${r.driverName ?? "-"} (${r.truckPlateNumber ?? "-"})';

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      decoration: AppTheme.cardDecorationOf(context),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, l, status),
                const SizedBox(height: 14),
                _details(context, l, driverTruck, arrival),
                const SizedBox(height: 14),
                _quantities(context, l),
                const SizedBox(height: 14),
                Divider(height: 1, color: AppTheme.borderOf(context)),
                const SizedBox(height: 12),
                _actions(context, l, isDraft),
              ],
            ),
          ),
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: accent),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l, GrnStatusView status) {
    final r = record;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: CopyableText(
                  r.grnCode,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.cobalt),
                ),
              ),
              CopyableText(
                r.warehouseName,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimaryOf(context)),
              ),
              OpsStatusChip(label: status.label, severity: status.severity, icon: status.icon),
              _sealChip(l),
              if (r.quarantineZoneAssigned)
                OpsStatusChip(
                  label: l.warehouseReceivingQuarantineLockBadge,
                  severity: AppSeverity.danger,
                  icon: Icons.lock,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        RowActionsPill(
          onView: onView,
          onEdit: onEdit,
          onPrint: onPrint,
          onDelete: onDelete,
          viewTooltip: l.warehouseReceivingViewTooltip,
          editTooltip: l.warehouseReceivingEditTooltip,
          printTooltip: l.warehouseReceivingPrintTooltip,
          deleteTooltip: l.warehouseReceivingDeleteTooltip,
        ),
      ],
    );
  }

  Widget _sealChip(AppLocalizations l) {
    final intact = record.sealIntact;
    final sealNo = record.sealNumber;
    final text = intact ? l.warehouseReceivingSealIntact : l.warehouseReceivingSealBroken;
    return OpsStatusChip(
      label: '$text ${sealNo != null ? "[$sealNo]" : ""}'.trim(),
      severity: intact ? AppSeverity.success : AppSeverity.danger,
      icon: intact ? Icons.verified_outlined : Icons.lock_open,
    );
  }

  Widget _details(BuildContext context, AppLocalizations l, String driverTruck, String arrival) {
    final r = record;
    final muted = AppTheme.textPrimaryOf(context);
    final valueStyle = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: muted);
    final noDiscrepancy = r.discrepancyType == 'None';
    final items = <Widget>[
      OpsLabeledValue(
        label: l.warehouseReceivingTruckAndDriver,
        value: driverTruck,
        valueWidget: CopyableText(driverTruck, style: valueStyle),
      ),
      OpsLabeledValue(
        label: l.warehouseReceivingArrivalDatetime,
        value: arrival,
        valueWidget: CopyableText(arrival, style: valueStyle),
      ),
      OpsLabeledValue(
        label: l.warehouseReceivingInspector,
        value: r.inspectorName,
        valueWidget: CopyableText(r.inspectorName, style: valueStyle),
      ),
      OpsLabeledValue(
        label: l.warehouseReceivingDiscrepancyStatus,
        value: r.discrepancyType,
        valueWidget: Text(
          r.discrepancyType,
          style: valueStyle.copyWith(
            color: noDiscrepancy ? AppTheme.severityForegroundOf(context, AppSeverity.success) : AppTheme.severityForegroundOf(context, AppSeverity.danger),
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        final columns = c.maxWidth >= 760 ? 4 : 2;
        final w = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 10,
          children: [for (final i in items) SizedBox(width: w, child: i)],
        );
      },
    );
  }

  Widget _quantities(BuildContext context, AppLocalizations l) {
    final r = record;
    final tiles = <_QtyTile>[
      _QtyTile(l.warehouseReceivingMetricInvoiced, '${r.totalInvoicedQty}', AppTheme.textPrimaryOf(context)),
      _QtyTile(l.warehouseReceivingMetricAccepted, '${r.totalAcceptedQty}', AppTheme.emerald),
      _QtyTile(
        l.warehouseReceivingMetricShortage,
        '${r.totalShortageQty}',
        r.totalShortageQty > 0 ? AppTheme.crimson : AppTheme.textMutedOf(context),
      ),
      _QtyTile(
        l.warehouseReceivingMetricDamaged,
        '${r.totalDamagedQty}',
        r.totalDamagedQty > 0 ? AppTheme.crimson : AppTheme.textMutedOf(context),
      ),
    ];
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: AppTheme.borderOf(context)),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, AppLocalizations l, bool isDraft) {
    final r = record;
    return OpsActionWrap(
      children: [
        if (isDraft)
          AppButton(
            label: l.warehouseReceivingConfirmFinalReceiptBtn,
            variant: AppButtonVariant.success,
            icon: Icons.check_circle,
            size: AppButtonSize.small,
            onPressed: onConfirmReceipt,
          ),
        if (r.discrepancyType == 'None' || !r.quarantineZoneAssigned)
          AppButton(
            label: l.warehouseReceivingRecordDiscrepancyBtn,
            variant: AppButtonVariant.warning,
            icon: Icons.warning_amber,
            size: AppButtonSize.small,
            onPressed: onRecordDiscrepancy,
          ),
        AppButton(
          key: Key('openInspectionProtocolBtn_${r.receivingId}'),
          label: l.wrInspectionProtocolBtn,
          icon: Icons.fact_check_rounded,
          size: AppButtonSize.small,
          onPressed: onOpenInspection,
        ),
        AppButton(
          label: r.quarantineZoneAssigned
              ? l.warehouseReceivingQuarantineStatusBlocked
              : l.warehouseReceivingQuarantineStatusCheck,
          variant: r.quarantineZoneAssigned ? AppButtonVariant.danger : AppButtonVariant.ghost,
          icon: r.quarantineZoneAssigned ? Icons.lock : Icons.verified_user_outlined,
          size: AppButtonSize.small,
          onPressed: onQuarantine,
        ),
        IconButton(
          key: Key('copyGrnRowBtn_${r.grnCode}'),
          icon: const Icon(Icons.copy_all, size: 18, color: AppTheme.cobalt),
          tooltip: l.copyWarehouseReceivingRowSuccess,
          onPressed: onCopyRow,
        ),
        AppButton(
          key: Key('cloneGrnBtn_${r.grnCode}'),
          label: l.cloneWarehouseReceivingTooltip,
          icon: Icons.difference_outlined,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.small,
          onPressed: onClone,
        ),
      ],
    );
  }
}

class _QtyTile extends StatelessWidget {
  const _QtyTile(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CopyableText(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context)),
        ),
      ],
    );
  }
}
