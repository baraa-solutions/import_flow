import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/vessel_tracking/models/vessel_tracking_model.dart';
import 'package:frontend/features/vessel_tracking/providers/vessel_tracking_provider.dart';
import 'package:frontend/features/vessel_tracking/screens/vessel_tracking_radar_screen.dart';

void main() {
  group('Vessel Tracking Model Tests', () {
    test('ShipmentTrackingModel parses JSON correctly', () {
      final json = {
        'tracking_id': 101,
        'tracking_code': 'TRK-2026-001',
        'import_file_id': 55,
        'booking_id': 12,
        'vessel_id': 7,
        'vessel_name': 'CMA CGM ANTOINE',
        'vessel_imo': '9776432',
        'shipping_line_name': 'CMA CGM',
        'voyage_number': '0MEH4W1MA',
        'pol_port_code': 'CNSHA',
        'pol_port_name': 'Shanghai Port',
        'pod_port_code': 'EGALY',
        'pod_port_name': 'Alexandria Port',
        'tracking_milestone': 'In Transit (Ocean)',
        'voyage_progress_pct': 88.5,
        'delay_hours': 0.0,
        'delay_severity': 'ON_TIME',
        'current_latitude': 33.5,
        'current_longitude': 26.8,
        'current_speed_knots': 15.2,
        'current_course_degrees': 115.0,
        'current_nav_status': 'Underway Using Engine',
        'current_zone': 'Eastern Mediterranean Basin',
        'distance_remaining_nm': 124.5,
        'route_waypoints': [
          {'name': 'Shanghai Port (POL)', 'latitude': 31.23, 'longitude': 121.47, 'passed': true},
          {'name': 'Alexandria Approaches', 'latitude': 31.50, 'longitude': 29.50, 'passed': false},
        ],
      };

      final model = ShipmentTrackingModel.fromJson(json);
      expect(model.trackingId, 101);
      expect(model.trackingCode, 'TRK-2026-001');
      expect(model.vesselName, 'CMA CGM ANTOINE');
      expect(model.vesselImo, '9776432');
      expect(model.voyageProgressPct, 88.5);
      expect(model.delaySeverity, 'ON_TIME');
      expect(model.routeWaypoints.length, 2);
      expect(model.routeWaypoints.first.passed, isTrue);
      expect(model.routeWaypoints.last.passed, isFalse);
    });

    test('LiveRadarOverviewModel parses JSON correctly', () {
      final json = {
        'total_active_shipments': 3,
        'underway_count': 2,
        'approaching_port_count': 1,
        'in_port_count': 0,
        'delayed_count': 1,
        'on_time_count': 2,
        'shipments': [],
      };

      final overview = LiveRadarOverviewModel.fromJson(json);
      expect(overview.totalActiveShipments, 3);
      expect(overview.underwayCount, 2);
      expect(overview.approachingPortCount, 1);
      expect(overview.delayedCount, 1);
      expect(overview.onTimeCount, 2);
    });
  });

  group('VesselTrackingRadarScreen Widget Tests', () {
    testWidgets('Renders radar screen with SelectionArea and KPI metrics', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyOverview = LiveRadarOverviewModel(
        totalActiveShipments: 1,
        underwayCount: 1,
        approachingPortCount: 0,
        inPortCount: 0,
        delayedCount: 0,
        onTimeCount: 1,
        shipments: [
          ShipmentTrackingModel(
            trackingId: 1,
            trackingCode: 'TRK-EGALY-001',
            importFileId: 10,
            vesselId: 5,
            vesselName: 'EVER GIVEN',
            vesselImo: '9811000',
            shippingLineName: 'Evergreen Marine',
            polPortCode: 'CNNGB',
            polPortName: 'Ningbo Port',
            podPortCode: 'EGALY',
            podPortName: 'Alexandria Port',
            trackingMilestone: 'In Transit',
            voyageProgressPct: 75.0,
            delayHours: 0.0,
            delaySeverity: 'ON_TIME',
            currentLatitude: 31.8,
            currentLongitude: 28.5,
            currentSpeedKnots: 16.0,
            currentCourseDegrees: 110.0,
            distanceRemainingNm: 150.0,
            routeWaypoints: [
              WaypointModel(name: 'Ningbo Port', latitude: 29.8, longitude: 121.5, passed: true),
              WaypointModel(name: 'Alexandria Port', latitude: 31.2, longitude: 29.9, passed: false),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vesselTrackingRadarProvider.overrideWith((ref) => _FakeRadarNotifier(dummyOverview)),
          ],
          child: const MaterialApp(
            home: VesselTrackingRadarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify SelectionArea wraps the screen for mouse selection
      expect(find.byType(SelectionArea), findsOneWidget);

      // 2. Verify title and KPI cards
      expect(find.text('رادار التتبع الحي لخطوط الملاحة والسفن'), findsOneWidget);
      expect(find.text('إجمالي الأسطول'), findsOneWidget);
      expect(find.text('في عرض البحر'), findsOneWidget);

      // 3. Verify Vessel Card details
      expect(find.text('EVER GIVEN'), findsOneWidget);
      expect(find.text('Evergreen Marine'), findsOneWidget);
      expect(find.text('كود التتبع: TRK-EGALY-001'), findsOneWidget);
      expect(find.text('IMO: 9811000'), findsOneWidget);
      expect(find.text('في الموعد المحدد'), findsWidgets);

      // 4. Verify Arrival Confirmation Button is rendered when in transit
      expect(find.text('تأكيد رسو السفينة وتفعيل إجراءات الوصول'), findsOneWidget);
    });

    testWidgets('Renders berthed state and clearance navigation button when arrived', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final berthedOverview = LiveRadarOverviewModel(
        totalActiveShipments: 1,
        underwayCount: 0,
        approachingPortCount: 0,
        inPortCount: 1,
        delayedCount: 0,
        onTimeCount: 1,
        shipments: [
          ShipmentTrackingModel(
            trackingId: 2,
            trackingCode: 'TRK-EGALY-002',
            importFileId: 11,
            vesselId: 5,
            vesselName: 'EVER GIVEN',
            vesselImo: '9811000',
            shippingLineName: 'Evergreen Marine',
            polPortCode: 'CNNGB',
            polPortName: 'Ningbo Port',
            podPortCode: 'EGALY',
            podPortName: 'Alexandria Port',
            trackingMilestone: 'In Port / Berthed',
            voyageProgressPct: 100.0,
            delayHours: 0.0,
            delaySeverity: 'ON_TIME',
            routeWaypoints: [],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vesselTrackingRadarProvider.overrideWith((ref) => _FakeRadarNotifier(berthedOverview)),
          ],
          child: const MaterialApp(
            home: VesselTrackingRadarScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify berthed state pill and clearance navigation button
      expect(find.text('السفينة راسية بالميناء - الإجراءات مفعلة'), findsOneWidget);
      expect(find.text('الانتقال للتخليص الجمركي وإذن التسليم'), findsOneWidget);
    });
  });
}

class _FakeRadarNotifier extends StateNotifier<AsyncValue<LiveRadarOverviewModel>>
    implements VesselTrackingRadarNotifier {
  _FakeRadarNotifier(LiveRadarOverviewModel data) : super(AsyncValue.data(data));

  @override
  Future<void> fetchRadarOverview() async {}

  @override
  Future<ShipmentTrackingModel?> simulateStep({required int importFileId, double hoursAdvance = 4.0}) async {
    return null;
  }

  @override
  Future<ShipmentTrackingModel?> confirmArrival({required int importFileId, DateTime? actualArrivalDate}) async {
    return null;
  }

  @override
  Future<ShipmentTrackingModel?> syncDemurrageClock({required int importFileId}) async {
    return null;
  }
}

