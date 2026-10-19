import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/widgets/departure_confirmation_dialog.dart';

import '../../helpers/localized_app.dart';

void main() {
  group('DepartureConfirmationDialog Mode & Payload (FE04-T03)', () {
    const l = AppLocalizationsEn();

    final sailedBooking = ShipmentBookingModel(
      bookingId: 42,
      bookingCode: 'BK-2026-0042',
      bookingConfirmationNo: 'CONF-42',
      importFileId: 10,
      importFileCode: 'IMP-2026-0010',
      shippingLineName: 'Maersk',
      polName: 'Shanghai',
      podName: 'Alexandria',
      etd: '2026-10-01T00:00:00Z',
      eta: null,
      atd: '2026-10-02T00:00:00Z',
      status: 'Sailed',
      billOfLadingNo: 'MSK987654321',
      vesselName: 'Emma Maersk',
      voyageNumber: '2601W',
      transitTimeDays: 20,
      departureDelayDays: 1,
      isActive: true,
      createdAt: '2026-09-20T00:00:00Z',
      updatedAt: '2026-10-02T00:00:00Z',
    );

    final confirmedBooking = ShipmentBookingModel(
      bookingId: 43,
      bookingCode: 'BK-2026-0043',
      bookingConfirmationNo: 'CONF-43',
      importFileId: 11,
      importFileCode: 'IMP-2026-0011',
      shippingLineName: 'CMA CGM',
      polName: 'Ningbo',
      podName: 'Damietta',
      etd: '2026-10-10T00:00:00Z',
      eta: '2026-10-30T00:00:00Z',
      atd: null,
      status: 'Confirmed',
      transitTimeDays: 20,
      departureDelayDays: 0,
      isActive: true,
      createdAt: '2026-09-25T00:00:00Z',
      updatedAt: '2026-09-25T00:00:00Z',
    );

    testWidgets('renders editSailed mode when booking is Sailed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            home: DepartureConfirmationDialog(
              booking: sailedBooking,
              mode: DepartureDialogMode.editSailed,
            ),
            locale: AppLocales.english,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title for editSailed
      expect(find.text(l.fbkEditBlTitle), findsOneWidget);
      // Confirm button has key fbkEditBlConfirmBtn
      expect(find.byKey(const Key('fbkEditBlConfirmBtn')), findsOneWidget);
      // Pre-filled B/L number
      expect(find.text('MSK987654321'), findsOneWidget);
    });

    testWidgets('renders depart mode when booking is Confirmed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            home: DepartureConfirmationDialog(
              booking: confirmedBooking,
              mode: DepartureDialogMode.depart,
            ),
            locale: AppLocales.english,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title for normal departure confirmation
      expect(find.text(l.fbkDepTitle), findsOneWidget);
      expect(find.byKey(const Key('fbkDepartureConfirmBtn')), findsOneWidget);
    });
  });
}
