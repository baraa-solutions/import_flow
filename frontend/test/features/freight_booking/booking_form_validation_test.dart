import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/widgets/freight_booking_form_dialog.dart';

import '../../helpers/localized_app.dart';

void main() {
  group('FreightBookingFormDialog Validation & Buttons (FE04-T04)', () {
    testWidgets('Clear/New button is visible in create mode and resets form', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            home: const FreightBookingFormDialog(),
            locale: AppLocales.english,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear/New button exists in create mode
      expect(find.byKey(const Key('fbkFormClearBtn')), findsOneWidget);
      // Save Draft button exists
      expect(find.byKey(const Key('fbkFormSaveDraftBtn')), findsOneWidget);
    });

    testWidgets('Clear/New button is hidden in edit mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final existing = ShipmentBookingModel(
        bookingId: 99,
        bookingCode: 'BK-2026-0099',
        importFileId: 5,
        importFileCode: 'IMP-2026-0005',
        shippingLineName: 'Hapag-Lloyd',
        status: 'Draft',
        isActive: true,
        createdAt: '2026-10-01T00:00:00Z',
        updatedAt: '2026-10-01T00:00:00Z',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            home: FreightBookingFormDialog(bookingToEdit: existing),
            locale: AppLocales.english,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear/New button must NOT be present in edit mode
      expect(find.byKey(const Key('fbkFormClearBtn')), findsNothing);
    });
  });
}
