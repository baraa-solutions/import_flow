import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../audit_logs/widgets/row_history_dialog.dart';
import '../../../cargo_shipping/widgets/cargo_shipping_ui.dart';
import '../../models/freight_booking_model.dart';

/// Header actions and step switcher navigation for [FreightBookingFormDialog].
class BookingFormHeader {
  BookingFormHeader._();

  /// Builds the top dialog header action buttons (e.g. audit history log).
  static List<Widget> buildHeaderActions(
    BuildContext context, {
    required bool isEdit,
    ShipmentBookingModel? bookingToEdit,
  }) {
    if (!isEdit || bookingToEdit == null) return const [];
    final l = AppLocalizations.of(context);
    return [
      IconButton(
        key: const Key('fbkFormAuditBtn'),
        icon: Icon(Icons.history_rounded, color: AppTheme.white.withValues(alpha: 0.78)),
        tooltip: l.fbkAuditLogBtn,
        onPressed: () {
          RowHistoryDialog.show(
            context,
            entityType: 'ShipmentBooking',
            entityId: bookingToEdit.bookingId,
            entityTitle: l.fbkAuditEntityTitle(bookingToEdit.bookingCode),
          );
        },
      ),
    ];
  }
}

/// Navigation step switcher for switching between Booking Details and Cost Breakdown.
class BookingFormStepSwitcher extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const BookingFormStepSwitcher({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ShippingStepSwitcher(
      selectedIndex: selectedIndex,
      titles: [l.freightBookingTabBookingDetails, l.freightBookingTabCostBreakdown],
      icons: const [Icons.description, Icons.attach_money],
      onSelected: onSelected,
    );
  }
}
