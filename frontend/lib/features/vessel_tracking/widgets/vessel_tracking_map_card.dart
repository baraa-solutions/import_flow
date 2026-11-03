import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/vessel_tracking_model.dart';

/// 🗺️ Vessel Tracking Telemetry & Waypoints Map Card
///
/// Displays real-time navigational telemetry (coordinates, speed, heading, distance)
/// along with voyage progress and transit waypoint milestone status.
class VesselTrackingMapCard extends StatelessWidget {
  final ShipmentTrackingModel shipment;

  const VesselTrackingMapCard({
    super.key,
    required this.shipment,
  });

  static String translateMilestone(String milestone) {
    switch (milestone) {
      case 'In Transit':
      case 'In Transit (Ocean)':
        return 'في عرض البحر';
      case 'Approaching Port':
        return 'تقترب من الميناء';
      case 'In Port / Berthed':
        return 'راسي بالميناء';
      case 'Arrived':
        return 'وصلت للميناء';
      default:
        return milestone;
    }
  }

  static String translateWaypoint(String name) {
    if (name.contains('Shanghai')) return 'ميناء شنغهاي';
    if (name.contains('Ningbo')) return 'ميناء نينغبو';
    if (name.contains('Malacca')) return 'مضيق ملقا';
    if (name.contains('Mandeb')) return 'مضيق باب المندب';
    if (name.contains('Suez')) return 'عبور قناة السويس';
    if (name.contains('Approaches')) return 'الاقتراب من الإسكندرية';
    if (name.contains('Terminal')) return 'محطة حاويات الإسكندرية';
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final s = shipment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Navigational Telemetry Grid ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildTelemetryCell(
                'الإحداثيات الحية',
                s.currentLatitude != null && s.currentLongitude != null
                    ? '${s.currentLatitude!.toStringAsFixed(4)}°, ${s.currentLongitude!.toStringAsFixed(4)}°'
                    : 'غير متوفرة',
                Icons.my_location,
              ),
              _buildTelemetryCell(
                'السرعة الملاحية',
                s.currentSpeedKnots != null
                    ? '${s.currentSpeedKnots!.toStringAsFixed(1)} عقدة'
                    : 'غير متوفرة',
                Icons.speed,
              ),
              _buildTelemetryCell(
                'خط السير والاتجاه',
                s.currentCourseDegrees != null
                    ? '${s.currentCourseDegrees!.toStringAsFixed(0)}°'
                    : 'غير متوفرة',
                Icons.explore,
              ),
              _buildTelemetryCell(
                'المسافة المتبقية',
                s.distanceRemainingNm != null
                    ? '${s.distanceRemainingNm!.toStringAsFixed(1)} ميل بحري'
                    : 'غير متوفرة',
                Icons.route,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Waypoints Route Bar & Voyage Progress ────────────────────────────
        if (s.routeWaypoints.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المرحلة الملاحية: ${translateMilestone(s.trackingMilestone)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.flatCharcoal,
                ),
              ),
              Text(
                'نسبة التقدم: ${s.voyageProgressPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.flatCobalt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (s.voyageProgressPct / 100.0).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.flatCobalt),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          _buildWaypointsList(s.routeWaypoints),
        ],
      ],
    );
  }

  Widget _buildTelemetryCell(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.flatCharcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointsList(List<WaypointModel> waypoints) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: waypoints.asMap().entries.map((entry) {
          final index = entry.key;
          final wp = entry.value;
          final isPassed = wp.passed;
          final isLast = index == waypoints.length - 1;
          final wpName = translateWaypoint(wp.name);

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPassed
                      ? AppTheme.flatEmerald.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPassed ? AppTheme.flatEmerald : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 14,
                      color: isPassed ? AppTheme.flatEmerald : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      wpName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isPassed ? FontWeight.bold : FontWeight.normal,
                        color: isPassed ? AppTheme.flatEmerald : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 16,
                  height: 2,
                  color: isPassed ? AppTheme.flatEmerald : Colors.grey.shade300,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
