import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../models/freight_booking_model.dart';

class FreightBookingMetrics extends StatelessWidget {
  final List<ShipmentBookingModel> bookings;

  const FreightBookingMetrics({
    super.key,
    required this.bookings,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final delayed = bookings.where((b) => b.departureDelayDays > 0).length;

    return CcUi.metrics([
      MetricCardData(
        title: l.fbkMetricBookings,
        value: '${bookings.length}',
        icon: Icons.directions_boat_outlined,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: l.freightBookingStatusConfirmed,
        value: '${bookings.where((b) => b.status == 'Confirmed' || b.status == 'Amended').length}',
        icon: Icons.verified_outlined,
        color: AppTheme.emerald,
      ),
      MetricCardData(
        title: l.freightBookingStatusSailed,
        value: '${bookings.where((b) => b.status == 'Sailed').length}',
        icon: Icons.sailing_rounded,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: l.fbkMetricDelayed,
        value: '$delayed',
        icon: Icons.alarm_off,
        color: delayed > 0 ? AppTheme.crimson : AppTheme.textMutedOf(context),
      ),
    ]);
  }
}
