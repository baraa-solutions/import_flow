class WaypointModel {
  final String name;
  final double latitude;
  final double longitude;
  final bool passed;
  final DateTime? estimatedPassAt;

  WaypointModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.passed,
    this.estimatedPassAt,
  });

  factory WaypointModel.fromJson(Map<String, dynamic> json) {
    return WaypointModel(
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      passed: json['passed'] as bool? ?? false,
      estimatedPassAt: json['estimated_pass_at'] != null
          ? DateTime.tryParse(json['estimated_pass_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'passed': passed,
        'estimated_pass_at': estimatedPassAt?.toIso8601String(),
      };
}

class ShipmentTrackingModel {
  final int trackingId;
  final String trackingCode;
  final int importFileId;
  final int? bookingId;
  final int vesselId;
  final String? vesselName;
  final String? vesselImo;
  final String? shippingLineName;
  final String? voyageNumber;
  final String polPortCode;
  final String polPortName;
  final String podPortCode;
  final String podPortName;
  final DateTime? scheduledDeparture;
  final DateTime? actualDeparture;
  final DateTime? scheduledArrival;
  final DateTime? estimatedArrival;
  final DateTime? actualArrival;
  final String trackingMilestone;
  final double voyageProgressPct;
  final double delayHours;
  final String delaySeverity;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? currentSpeedKnots;
  final double? currentCourseDegrees;
  final String? currentNavStatus;
  final String? currentZone;
  final double? distanceRemainingNm;
  final List<WaypointModel> routeWaypoints;
  final DateTime? lastPolledAt;
  final int? demurrageTrackingId;
  final String? demurrageTrackingCode;
  final String? demurrageStatus;
  final String? demurrageDischargeDate;
  final bool demurrageClockStarted;

  ShipmentTrackingModel({
    required this.trackingId,
    required this.trackingCode,
    required this.importFileId,
    this.bookingId,
    required this.vesselId,
    this.vesselName,
    this.vesselImo,
    this.shippingLineName,
    this.voyageNumber,
    required this.polPortCode,
    required this.polPortName,
    required this.podPortCode,
    required this.podPortName,
    this.scheduledDeparture,
    this.actualDeparture,
    this.scheduledArrival,
    this.estimatedArrival,
    this.actualArrival,
    required this.trackingMilestone,
    required this.voyageProgressPct,
    required this.delayHours,
    required this.delaySeverity,
    this.currentLatitude,
    this.currentLongitude,
    this.currentSpeedKnots,
    this.currentCourseDegrees,
    this.currentNavStatus,
    this.currentZone,
    this.distanceRemainingNm,
    required this.routeWaypoints,
    this.lastPolledAt,
    this.demurrageTrackingId,
    this.demurrageTrackingCode,
    this.demurrageStatus,
    this.demurrageDischargeDate,
    this.demurrageClockStarted = false,
  });

  factory ShipmentTrackingModel.fromJson(Map<String, dynamic> json) {
    var rawWaypoints = json['route_waypoints'];
    List<WaypointModel> waypoints = [];
    if (rawWaypoints is List) {
      waypoints = rawWaypoints
          .whereType<Map<String, dynamic>>()
          .map((w) => WaypointModel.fromJson(w))
          .toList();
    }

    return ShipmentTrackingModel(
      trackingId: json['tracking_id'] as int? ?? 0,
      trackingCode: json['tracking_code'] as String? ?? '',
      importFileId: json['import_file_id'] as int? ?? 0,
      bookingId: json['booking_id'] as int?,
      vesselId: json['vessel_id'] as int? ?? 0,
      vesselName: json['vessel_name'] as String?,
      vesselImo: json['vessel_imo'] as String?,
      shippingLineName: json['shipping_line_name'] as String?,
      voyageNumber: json['voyage_number'] as String?,
      polPortCode: json['pol_port_code'] as String? ?? 'CNSHA',
      polPortName: json['pol_port_name'] as String? ?? 'Shanghai',
      podPortCode: json['pod_port_code'] as String? ?? 'EGALY',
      podPortName: json['pod_port_name'] as String? ?? 'Alexandria',
      scheduledDeparture: json['scheduled_departure'] != null
          ? DateTime.tryParse(json['scheduled_departure'] as String)
          : null,
      actualDeparture: json['actual_departure'] != null
          ? DateTime.tryParse(json['actual_departure'] as String)
          : null,
      scheduledArrival: json['scheduled_arrival'] != null
          ? DateTime.tryParse(json['scheduled_arrival'] as String)
          : null,
      estimatedArrival: json['estimated_arrival'] != null
          ? DateTime.tryParse(json['estimated_arrival'] as String)
          : null,
      actualArrival: json['actual_arrival'] != null
          ? DateTime.tryParse(json['actual_arrival'] as String)
          : null,
      trackingMilestone: json['tracking_milestone'] as String? ?? 'In Transit',
      voyageProgressPct: (json['voyage_progress_pct'] as num?)?.toDouble() ?? 0.0,
      delayHours: (json['delay_hours'] as num?)?.toDouble() ?? 0.0,
      delaySeverity: json['delay_severity'] as String? ?? 'ON_TIME',
      currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
      currentSpeedKnots: (json['current_speed_knots'] as num?)?.toDouble(),
      currentCourseDegrees: (json['current_course_degrees'] as num?)?.toDouble(),
      currentNavStatus: json['current_nav_status'] as String?,
      currentZone: json['current_zone'] as String?,
      distanceRemainingNm: (json['distance_remaining_nm'] as num?)?.toDouble(),
      routeWaypoints: waypoints,
      lastPolledAt: json['last_polled_at'] != null
          ? DateTime.tryParse(json['last_polled_at'] as String)
          : null,
      demurrageTrackingId: json['demurrage_tracking_id'] as int?,
      demurrageTrackingCode: json['demurrage_tracking_code'] as String?,
      demurrageStatus: json['demurrage_status'] as String?,
      demurrageDischargeDate: json['demurrage_discharge_date'] as String?,
      demurrageClockStarted: json['demurrage_clock_started'] as bool? ?? false,
    );
  }
}

class LiveRadarOverviewModel {
  final int totalActiveShipments;
  final int underwayCount;
  final int approachingPortCount;
  final int inPortCount;
  final int delayedCount;
  final int onTimeCount;
  final List<ShipmentTrackingModel> shipments;

  LiveRadarOverviewModel({
    required this.totalActiveShipments,
    required this.underwayCount,
    required this.approachingPortCount,
    required this.inPortCount,
    required this.delayedCount,
    required this.onTimeCount,
    required this.shipments,
  });

  factory LiveRadarOverviewModel.fromJson(Map<String, dynamic> json) {
    var rawShipments = json['shipments'];
    List<ShipmentTrackingModel> list = [];
    if (rawShipments is List) {
      list = rawShipments
          .whereType<Map<String, dynamic>>()
          .map((s) => ShipmentTrackingModel.fromJson(s))
          .toList();
    }

    return LiveRadarOverviewModel(
      totalActiveShipments: json['total_active_shipments'] as int? ?? 0,
      underwayCount: json['underway_count'] as int? ?? 0,
      approachingPortCount: json['approaching_port_count'] as int? ?? 0,
      inPortCount: json['in_port_count'] as int? ?? 0,
      delayedCount: json['delayed_count'] as int? ?? 0,
      onTimeCount: json['on_time_count'] as int? ?? 0,
      shipments: list,
    );
  }
}
