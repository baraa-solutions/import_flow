import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../cargo_shipping/widgets/cargo_shipping_ui.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../models/freight_booking_model.dart';
import 'freight_booking_ui.dart';

/// Search and Clone Previous Freight Booking Dialog (Screen 25 / UX-CLONE-025)
///
/// Allows operators to quickly search past freight bookings by code, confirmation number,
/// carrier, route (POL/POD), or vessel, and select one to clone into a new editable draft.
class SearchAndCloneFreightBookingDialog extends StatefulWidget {
  final List<ShipmentBookingModel> bookings;
  final ValueChanged<ShipmentBookingModel> onSelectBooking;

  const SearchAndCloneFreightBookingDialog({
    super.key,
    required this.bookings,
    required this.onSelectBooking,
  });

  @override
  State<SearchAndCloneFreightBookingDialog> createState() =>
      _SearchAndCloneFreightBookingDialogState();
}

class _SearchAndCloneFreightBookingDialogState
    extends State<SearchAndCloneFreightBookingDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';
  late List<ShipmentBookingModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.bookings;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.bookings.where((b) {
        final matchesStatus = _selectedStatus == 'All' || b.status == _selectedStatus;
        if (!matchesStatus) return false;

        if (q.isEmpty) return true;

        final code = b.bookingCode.toLowerCase();
        final confirmNo = (b.bookingConfirmationNo ?? '').toLowerCase();
        final file = (b.importFileCode ?? '').toLowerCase();
        final line = (b.shippingLineName ?? '').toLowerCase();
        final fwd = (b.freightForwarderName ?? '').toLowerCase();
        final pol = (b.polName ?? '').toLowerCase();
        final pod = (b.podName ?? '').toLowerCase();
        final vessel = (b.vesselName ?? '').toLowerCase();
        final voyage = (b.voyageNumber ?? '').toLowerCase();

        return code.contains(q) ||
            confirmNo.contains(q) ||
            file.contains(q) ||
            line.contains(q) ||
            fwd.contains(q) ||
            pol.contains(q) ||
            pod.contains(q) ||
            vessel.contains(q) ||
            voyage.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return SelectionArea(
      child: ShippingDialogFrame(
        title: l.cloneFreightBookingDialogTitle,
      subtitle: l.cloneFreightBookingDialogSubtitle,
      icon: Icons.copy_all_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('searchCloneBookingQueryField'),
            controller: _searchController,
            onChanged: (_) => _applyFilter(),
            decoration: InputDecoration(
              hintText: l.freightBookingSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilter();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceAltOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.borderOf(context)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _statusChip('All', l.freightBookingStatusAll),
              _statusChip('Draft', l.freightBookingStatusDraft),
              _statusChip('Booking Requested', l.freightBookingStatusRequested),
              _statusChip('Confirmed', l.freightBookingStatusConfirmed),
              _statusChip('Amended', l.fbkStatusAmended),
              _statusChip('Sailed', l.freightBookingStatusSailed),
              _statusChip('Cancelled', l.fbkStatusCancelled),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? AppEmptyState(message: l.freightBookingEmptyRecords, icon: Icons.search_off_rounded)
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderOf(context)),
                    itemBuilder: (context, index) => _bookingRow(context, _filtered[index], l),
                  ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _statusChip(String statusKey, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedStatus == statusKey,
      onSelected: (_) {
        setState(() => _selectedStatus = statusKey);
        _applyFilter();
      },
    );
  }

  Widget _bookingRow(BuildContext context, ShipmentBookingModel bkg, AppLocalizations l) {
    final st = FbkUi.status(l, bkg.status);
    final routeText = '${FbkFormat.orDash(bkg.polName)} → ${FbkFormat.orDash(bkg.podName)}';
    final carrierText = '${FbkFormat.orDash(bkg.shippingLineName)} / ${FbkFormat.orDash(bkg.freightForwarderName)}';
    void select() {
      Navigator.pop(context);
      widget.onSelectBooking(bkg);
    }

    return InkWell(
      onTap: select,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.cobalt.withValues(alpha: 0.12),
              child: const Icon(Icons.directions_boat_outlined, color: AppTheme.cobalt, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      LtrText(
                        bkg.bookingCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      if (bkg.bookingConfirmationNo != null && bkg.bookingConfirmationNo!.isNotEmpty)
                        Text(
                          '#${bkg.bookingConfirmationNo}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      AppStatusBadge(
                        label: st.label,
                        severity: st.severity,
                        size: AppStatusBadgeSize.small,
                        icon: st.icon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.cobalt),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          routeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Text(carrierText, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondaryOf(context))),
                      Text(
                        FbkFormat.containers(bkg),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                      ),
                      CcMoneyText(
                        bkg.totalFreightCostUsd,
                        currency: 'USD',
                        fontSize: 11.5,
                        color: AppTheme.severityForegroundOf(context, AppSeverity.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              key: Key('selectCloneBookingBtn_${bkg.bookingCode}'),
              label: l.cloneBookingRowTooltip,
              icon: Icons.copy_rounded,
              size: AppButtonSize.small,
              onPressed: select,
            ),
          ],
        ),
      ),
    );
  }
}
