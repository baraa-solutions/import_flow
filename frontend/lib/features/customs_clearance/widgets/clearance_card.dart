import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_clearance_model.dart';
import 'customs_ui.dart';

/// Callbacks of the per-record actions shown on a [ClearanceCard].
class ClearanceCardActions {
  const ClearanceCardActions({
    required this.onEdit,
    required this.onCopyRow,
    required this.onClone,
    required this.onUnderBond,
    required this.onPayDuty,
    required this.onRelease,
    required this.onExpenses,
  });

  final VoidCallback onEdit;
  final VoidCallback onCopyRow;
  final VoidCallback onClone;
  final VoidCallback onUnderBond;
  final VoidCallback onPayDuty;
  final VoidCallback onRelease;
  final VoidCallback onExpenses;
}

/// One customs-clearance record: identity + status chips on top, shipment /
/// declaration facts in the middle, right-aligned money block, action row.
class ClearanceCard extends ConsumerWidget {
  const ClearanceCard({super.key, required this.record, required this.actions});

  final CustomsClearanceModel record;
  final ClearanceCardActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final rawFileCode = 'IMP-${record.importFileId}';
    final shipName = DisplayNameResolver.resolveShipmentNameByCode(
      rawFileCode,
      shipments: allFiles,
      isArabic: l.isArabic,
    );

    final status = CcUi.statusStyle(l, record.status);
    final channel = CcUi.channelStyle(l, record.channelType);
    final isPaid = record.paymentStatus == 'Paid & Verified';
    final assessed =
        record.effectiveDutyTotal;
    final varianceWarn = (record.dutyVarianceAmount ?? 0).abs() > 500;

    final primary = AppTheme.textPrimaryOf(context);
    final secondary = AppTheme.textSecondaryOf(context);

    final codeBadge = Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: CopyableText(
        record.clearanceCode,
        textDirection: TextDirection.ltr,
        style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 13),
      ),
    );

    final chips = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        codeBadge,
        CcStatusChip(label: channel.label, severity: channel.severity, icon: channel.icon),
        CcStatusChip(label: status.label, severity: status.severity),
      ],
    );

    final facts = Wrap(
      spacing: 24,
      runSpacing: 10,
      children: [
        _factBox(
          CcFact(label: l.customsClearanceOfficeLabel, value: record.customsOfficeName),
        ),
        _factBox(
          CcFact(label: l.customsClearanceFileRefLabel, value: shipName),
          width: 240,
        ),
        _factBox(
          CcFact(label: l.importFile, value: rawFileCode, mono: true),
          width: 110,
        ),
        if (record.declaration46No != null && record.declaration46No!.isNotEmpty)
          _factBox(
            CcFact(
              label: l.customsClearanceDeclaration46Label,
              value: record.declaration46No!,
              mono: true,
            ),
            width: 150,
          ),
        if (record.deliveryOrderNumber != null && record.deliveryOrderNumber!.isNotEmpty)
          _factBox(
            CcFact(
              label: l.customsClearanceDeliveryOrderLabel,
              value: record.deliveryOrderNumber!,
              mono: true,
            ),
            width: 150,
          ),
        if (record.freeDaysAllowed > 0)
          _factBox(
            CcFact(
              label: l.customsClearanceFreeDaysInputLabel,
              value: l.ccCloneDaysValue(record.freeDaysAllowed),
            ),
            width: 110,
          ),
      ],
    );

    final money = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.customsClearanceTotalDutiesCard,
          style: TextStyle(fontSize: 11, color: secondary),
        ),
        const SizedBox(height: 2),
        CcMoneyText(assessed,
            fontSize: 15, color: AppTheme.successForeground, textAlign: TextAlign.end),
        if ((record.estimatedDutyTotal ?? 0) > 0) ...[
          const SizedBox(height: 4),
          Text(
            l.customsClearanceColEstimatedDuty,
            style: TextStyle(fontSize: 11, color: secondary),
          ),
          CcMoneyText(record.estimatedDutyTotal,
              fontSize: 12, color: secondary, textAlign: TextAlign.end),
          const SizedBox(height: 2),
          CcMoneyText(
            record.dutyVarianceAmount,
            signed: true,
            fontSize: 11.5,
            color: varianceWarn ? AppTheme.warningForeground : secondary,
            textAlign: TextAlign.end,
          ),
        ],
        const SizedBox(height: 6),
        CcStatusChip(
          label: isPaid
              ? l.customsClearanceStatusPaid
              : l.customsClearanceStatusPendingPayment,
          severity: isPaid ? AppSeverity.success : AppSeverity.danger,
        ),
      ],
    );

    final actionButtons = Wrap(
      spacing: 0,
      runSpacing: 0,
      children: [
        _icon(Key('editClearanceBtn_${record.clearanceCode}'), Icons.edit_outlined,
            AppTheme.cobalt, l.customsClearanceEditTooltip, actions.onEdit),
        _icon(Key('copyClearanceRowBtn_${record.clearanceCode}'), Icons.copy_rounded,
            AppTheme.cobalt, l.copyCustomsClearanceRowSuccess, actions.onCopyRow),
        _icon(Key('cloneClearanceBtn_${record.clearanceCode}'), Icons.difference_outlined,
            AppTheme.cobalt, l.cloneCustomsClearanceTooltip, actions.onClone),
        _icon(Key('underBondBtn_${record.clearanceCode}'), Icons.lock_clock_outlined,
            AppTheme.orange, l.customsClearanceUnderBondTooltip, actions.onUnderBond),
        _icon(Key('payDutyBtn_${record.clearanceCode}'), Icons.payments_outlined,
            AppTheme.emerald, l.customsClearancePayTooltip, actions.onPayDuty),
        _icon(Key('finalReleaseBtn_${record.clearanceCode}'),
            Icons.assignment_turned_in_outlined, AppTheme.wcagCobalt,
            l.customsClearanceReleaseTooltip, actions.onRelease),
        _icon(Key('clearanceExpensesBtn_${record.clearanceCode}'),
            Icons.receipt_long_outlined, AppTheme.charcoal, l.ccExpensesTooltip,
            actions.onExpenses),
      ],
    );

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: AppTheme.cardDecorationOf(context),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 700;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chips,
                const SizedBox(height: 10),
                facts,
                const SizedBox(height: 10),
                Align(alignment: AlignmentDirectional.centerEnd, child: money),
                Divider(height: 18, color: AppTheme.borderOf(context)),
                actionButtons,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: chips),
                  actionButtons,
                ],
              ),
              Divider(height: 18, color: AppTheme.borderOf(context)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: facts),
                  const SizedBox(width: 16),
                  SizedBox(width: 190, child: money),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _factBox(Widget child, {double width = 170}) =>
      SizedBox(width: width, child: child);

  static Widget _icon(Key key, IconData icon, Color color, String tooltip, VoidCallback onTap) =>
      IconButton(
        key: key,
        icon: Icon(icon, color: color, size: 20),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      );
}
