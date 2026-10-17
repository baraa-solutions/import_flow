import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/freight_booking_model.dart';
import 'freight_booking_ui.dart';

/// Callbacks of one registry row (kept together so the screen stays small).
class FbkRowActions {
  const FbkRowActions({
    required this.onView,
    required this.onEdit,
    required this.onClone,
    required this.onPrint,
    required this.onDelete,
    required this.onCopyRow,
    required this.onConfirmBooking,
    required this.onDeparture,
    required this.onReviewDraftBl,
  });

  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onClone;
  final VoidCallback onPrint;
  final VoidCallback onDelete;
  final VoidCallback onCopyRow;
  final VoidCallback onConfirmBooking;
  final VoidCallback onDeparture;
  final VoidCallback onReviewDraftBl;
}

/// One booking of the registry: code / status chips, route, the key facts
/// (confirmation no, carrier, vessel, dates, containers), the freight total and
/// the row actions. Wraps instead of overflowing on narrow windows.
class FbkRegistryRow extends StatelessWidget {
  const FbkRegistryRow({
    super.key,
    required this.booking,
    required this.fileName,
    required this.fileCode,
    required this.fileTitle,
    required this.actions,
  });

  final ShipmentBookingModel booking;
  final String fileName;
  final String fileCode;
  final String fileTitle;
  final FbkRowActions actions;

  bool get _isDone => booking.status == 'Confirmed' || booking.status == 'Sailed';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = booking;
    final st = FbkUi.status(l, b.status);
    final accent = !b.isActive
        ? AppTheme.severityForegroundOf(context, AppSeverity.danger)
        : AppTheme.severityForegroundOf(context, st.severity);

    return InkWell(
      onTap: actions.onView,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, l, st),
                const SizedBox(height: 8),
                _route(context),
                const SizedBox(height: 10),
                _facts(context, l),
                const SizedBox(height: 10),
                _footer(context, l),
              ],
            ),
          ),
          PositionedDirectional(start: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: accent)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l, ({AppSeverity severity, String label, IconData icon}) st) {
    final b = booking;
    final tip = b.status == 'Confirmed'
        ? l.fbkStatusTipConfirmed
        : (b.status == 'Sailed' ? l.fbkStatusTipSailed(b.billOfLadingNo ?? '-') : l.fbkStatusTipPending);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!b.isActive)
                const Padding(
                  padding: EdgeInsetsDirectional.only(end: 4),
                  child: Icon(Icons.block, size: 12, color: AppTheme.crimson),
                ),
              LtrText(
                b.bookingCode,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: b.isActive ? AppTheme.cobalt : AppTheme.crimson,
                  decoration: b.isActive ? TextDecoration.none : TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: tip,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _isDone ? actions.onDeparture : actions.onConfirmBooking,
            child: AppStatusBadge(
              label: st.label,
              severity: st.severity,
              size: AppStatusBadgeSize.small,
              icon: _isDone ? st.icon : Icons.touch_app,
            ),
          ),
        ),
        if (b.billOfLadingNo != null)
          AppStatusBadge(
            label: 'B/L: ${b.billOfLadingNo}',
            severity: AppSeverity.success,
            size: AppStatusBadgeSize.small,
            icon: Icons.receipt_long,
          ),
        if (b.scenarioProviderName != null)
          AppStatusBadge(
            label: l.freightBookingApprovedQuoteLabel(b.scenarioProviderName!),
            severity: AppSeverity.success,
            size: AppStatusBadgeSize.small,
            icon: Icons.verified,
          ),
        if (b.atd != null && b.departureDelayDays > 0)
          AppStatusBadge(
            label: '+${b.departureDelayDays}d',
            severity: AppSeverity.danger,
            size: AppStatusBadgeSize.small,
            icon: Icons.alarm_off,
          ),
        if (!b.isActive)
          AppStatusBadge(
            label: l.fbkInactiveBadge,
            severity: AppSeverity.danger,
            size: AppStatusBadgeSize.small,
            icon: Icons.delete_outline,
          ),
      ],
    );
  }

  Widget _route(BuildContext context) {
    final b = booking;
    final style = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.bold,
      color: AppTheme.textPrimaryOf(context),
    );
    return CopyableTableCell(
      value: '${FbkFormat.orDash(b.polName)} → ${FbkFormat.orDash(b.podName)}',
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.cobalt),
          const SizedBox(width: 4),
          Flexible(
            child: Text(FbkFormat.orDash(b.polName), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, size: 14, color: AppTheme.cobalt),
          ),
          Flexible(
            child: Text(FbkFormat.orDash(b.podName), style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _facts(BuildContext context, AppLocalizations l) {
    final b = booking;
    final etd = l.freightBookingEtdPrefixLabel(FbkFormat.isoDate(b.etd));
    final departure = b.atd != null ? '$etd\n${l.freightBookingAtdPrefixLabel(FbkFormat.isoDate(b.atd))}' : etd;
    final eta = l.freightBookingEtaPrefixLabel(FbkFormat.isoDate(b.eta));
    final arrival = b.expectedWarehouseArrivalDate != null
        ? '$eta\n${l.freightBookingWhArrivalLabel(FbkFormat.isoDate(b.expectedWarehouseArrivalDate))}'
        : eta;
    final fileValue = fileCode.isNotEmpty && fileCode != fileName ? '$fileName\n$fileCode' : fileName;

    Widget fact(String label, String value, {bool mono = false, double width = 170, String? copy}) {
      return SizedBox(
        width: width,
        child: CopyableTableCell(
          value: copy ?? value,
          child: CcFact(label: label, value: value, mono: mono),
        ),
      );
    }

    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        if (fileValue.isNotEmpty) fact(l.freightBookingColImportFile, fileValue, width: 210, copy: fileTitle),
        fact(
          l.freightBookingColConfirmationNo,
          b.bookingConfirmationNo ?? l.freightBookingDraftPendingLabel,
          mono: b.bookingConfirmationNo != null,
        ),
        fact(l.freightBookingShippingLineLabel, FbkFormat.orDash(b.shippingLineName)),
        fact(l.freightBookingForwarderLabel, FbkFormat.orDash(b.freightForwarderName)),
        fact(
          l.freightBookingColVesselVoyage,
          '${FbkFormat.orDash(b.vesselName)} (${FbkFormat.orDash(b.voyageNumber)})',
        ),
        fact(l.freightBookingColDeparture, departure),
        fact(l.freightBookingColArrival, arrival),
        fact(l.freightBookingColContainers, FbkFormat.containers(b)),
      ],
    );
  }

  Widget _footer(BuildContext context, AppLocalizations l) {
    final b = booking;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${l.freightBookingColTotalFreight}: ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                ),
              ),
              Flexible(
                child: CcMoneyText(b.totalFreightCostUsd, currency: 'USD', color: AppTheme.severityForegroundOf(context, AppSeverity.success)),
              ),
            ],
          ),
        ),
        _actionIcons(context, l),
      ],
    );
  }

  Widget _icon(Key? key, IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return IconButton(
      key: key,
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Widget _actionIcons(BuildContext context, AppLocalizations l) {
    final b = booking;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 4,
      children: [
        RowActionsPill(
          onView: actions.onView,
          onEdit: actions.onEdit,
          onPrint: actions.onPrint,
          onDelete: actions.onDelete,
          viewTooltip: l.freightBookingViewTooltip,
          editTooltip: l.freightBookingEditTooltip,
          printTooltip: l.freightBookingPrintTooltip,
          deleteTooltip: l.freightBookingDeleteTooltip,
        ),
        _icon(Key('copyBookingRowBtn_${b.bookingCode}'), Icons.copy, l.fbkTipCopyRow, actions.onCopyRow,
            color: AppTheme.textSecondaryOf(context)),
        _icon(Key('cloneBookingRowBtn_${b.bookingCode}'), Icons.copy_all_rounded, l.cloneBookingRowTooltip,
            actions.onClone,
            color: AppTheme.cobalt),
        if (b.status != 'Confirmed' && b.status != 'Sailed')
          _icon(Key('confirmBookingRowBtn_${b.bookingCode}'), Icons.verified_outlined, l.fbkTipConfirmBooking,
              actions.onConfirmBooking,
              color: AppTheme.emerald),
        if (b.status == 'Confirmed')
          _icon(Key('confirmDepartureRowBtn_${b.bookingCode}'), Icons.sailing_rounded, l.fbkTipConfirmDeparture,
              actions.onDeparture,
              color: AppTheme.cobalt),
        if (b.status == 'Sailed') ...[
          _icon(Key('viewDepartureRowBtn_${b.bookingCode}'), Icons.receipt_long, l.fbkTipUpdateBl,
              actions.onDeparture,
              color: AppTheme.emerald),
          _icon(Key('reviewDraftBlRowBtn_${b.bookingCode}'), Icons.fact_check_rounded, l.fbkTipReviewDraftBl,
              actions.onReviewDraftBl,
              color: AppTheme.emerald),
        ],
      ],
    );
  }
}
