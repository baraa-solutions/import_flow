import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/directional_icon.dart';
import '../models/vessel_tracking_model.dart';

/// ⏱️ Vessel ETA & Route Schedule Table
///
/// Displays origin (POL) and destination (POD) ports, scheduled departure,
/// dynamic estimated arrival time (ETA), and schedule variance status.
class VesselEtaTable extends StatelessWidget {
  final ShipmentTrackingModel shipment;

  const VesselEtaTable({
    super.key,
    required this.shipment,
  });

  static String formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final s = shipment;

    Color delayColor = AppTheme.flatEmerald;
    if (s.delaySeverity == 'CRITICAL_DELAY') {
      delayColor = AppTheme.flatCrimson;
    } else if (s.delaySeverity == 'MINOR_DELAY') {
      delayColor = AppTheme.flatOrange;
    }

    return Row(
      children: [
        // ── Origin Port (POL) ───────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ميناء الشحن',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                '${s.polPortName} (${s.polPortCode})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.flatCharcoal,
                ),
              ),
              if (s.scheduledDeparture != null)
                Text(
                  'المغادرة: ${formatDate(s.scheduledDeparture)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
        ),
        const DirectionalIcon(
          Icons.arrow_forward,
          color: Colors.black38,
          size: 20,
        ),
        // ── Destination Port (POD) ──────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'ميناء الوصول',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                '${s.podPortName} (${s.podPortCode})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.flatCharcoal,
                ),
              ),
              if (s.estimatedArrival != null)
                Text(
                  'الوصول المتوقع: ${formatDate(s.estimatedArrival)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: delayColor,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
