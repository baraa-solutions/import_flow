import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/freight_booking/models/freight_booking_model.dart';
import 'package:frontend/features/freight_booking/widgets/freight_booking_form_dialog.dart';

void main() {
  group('Freight Booking Charges Engine (FE04-T01)', () {
    test('2x40ft @2000 + 1x20ft @1000 produces correct units, quantities, and total 5000', () {
      const state = FbkQuoteState(
        container40ftApp: true,
        container40ftPrice: 2000.0,
        container40ftQty: 2,
        container40ftCur: 'USD',
        container20ftApp: true,
        container20ftPrice: 1000.0,
        container20ftQty: 1,
        container20ftCur: 'USD',
      );

      final charges = buildChargesFromQuote(state);
      expect(charges.length, 2);

      final c40 = charges.firstWhere((c) => c.chargeType == 'Sea Freight 40ft');
      expect(c40.unit, 'Per 40ft Container');
      expect(c40.quantity, 2);
      expect(c40.rate, 2000.0);
      expect(c40.total, 4000.0);
      expect(c40.currency, 'USD');

      final c20 = charges.firstWhere((c) => c.chargeType == 'Sea Freight 20ft');
      expect(c20.unit, 'Per 20ft Container');
      expect(c20.quantity, 1);
      expect(c20.rate, 1000.0);
      expect(c20.total, 1000.0);
      expect(c20.currency, 'USD');

      final sum = charges.fold<double>(0.0, (acc, c) => acc + c.total);
      expect(sum, 5000.0);
    });

    test('SOLAS/VGM and VGM notification retain Per Container unit', () {
      const state = FbkQuoteState(
        solasVgmApp: true,
        solasVgmPrice: 50.0,
        solasVgmCur: 'USD',
        vgmNotifApp: true,
        vgmNotifPrice: 25.0,
        vgmNotifCur: 'USD',
      );

      final charges = buildChargesFromQuote(state);
      expect(charges.length, 2);

      final solas = charges.firstWhere((c) => c.chargeType == 'SOLAS/VGM Fees');
      expect(solas.unit, 'Per Container');
      expect(solas.quantity, 1);
      expect(solas.rate, 50.0);
      expect(solas.total, 50.0);

      final vgm = charges.firstWhere((c) => c.chargeType == 'VGM Notification Fee');
      expect(vgm.unit, 'Per Container');
      expect(vgm.quantity, 1);
      expect(vgm.rate, 25.0);
      expect(vgm.total, 25.0);
    });

    test('Cancellation charge is present only when cancellationApp is true and price > 0', () {
      const stateWithCancel = FbkQuoteState(
        cancellationApp: true,
        cancellationPrice: 150.0,
        cancellationCur: 'USD',
      );

      final charges = buildChargesFromQuote(stateWithCancel);
      expect(charges.length, 1);

      final cancelCharge = charges.first;
      expect(cancelCharge.chargeType, 'Booking Cancellation');
      expect(cancelCharge.unit, 'Per Shipment');
      expect(cancelCharge.quantity, 1);
      expect(cancelCharge.currency, 'USD');
      expect(cancelCharge.rate, 150.0);
      expect(cancelCharge.total, 150.0);

      const stateWithoutCancel = FbkQuoteState(
        cancellationApp: false,
        cancellationPrice: 150.0,
        cancellationCur: 'USD',
      );
      expect(buildChargesFromQuote(stateWithoutCancel), isEmpty);

      const stateZeroPrice = FbkQuoteState(
        cancellationApp: true,
        cancellationPrice: 0.0,
        cancellationCur: 'USD',
      );
      expect(buildChargesFromQuote(stateZeroPrice), isEmpty);
    });

    test('Mixed-currency detector returns true for USD + EUR and false for uniform currency', () {
      const singleCurrency = FbkQuoteState(
        container40ftApp: true,
        container40ftPrice: 2000.0,
        container40ftCur: 'USD',
        dthcApp: true,
        dthcPrice: 300.0,
        dthcCur: 'USD',
      );
      expect(hasMixedCurrencies(singleCurrency), isFalse);
      expect(collectApplicableCurrencies(singleCurrency), {'USD'});

      const mixedCurrency = FbkQuoteState(
        container40ftApp: true,
        container40ftPrice: 2000.0,
        container40ftCur: 'USD',
        dthcApp: true,
        dthcPrice: 300.0,
        dthcCur: 'EUR',
      );
      expect(hasMixedCurrencies(mixedCurrency), isTrue);
      expect(collectApplicableCurrencies(mixedCurrency), {'USD', 'EUR'});

      // Inapplicable item with different currency does not trigger mixed currency
      const inapplicableDiffCur = FbkQuoteState(
        container40ftApp: true,
        container40ftPrice: 2000.0,
        container40ftCur: 'USD',
        dthcApp: false,
        dthcPrice: 300.0,
        dthcCur: 'EUR',
      );
      expect(hasMixedCurrencies(inapplicableDiffCur), isFalse);
      expect(collectApplicableCurrencies(inapplicableDiffCur), {'USD'});
    });

    test('Source-scan guard: units, cancellation, and mixed currencies guard in freight_booking_form_dialog', () {
      final candidates = [
        File('lib/features/freight_booking/widgets/freight_booking_form_dialog.dart'),
        File('frontend/lib/features/freight_booking/widgets/freight_booking_form_dialog.dart'),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => candidates.first,
      );
      expect(file.existsSync(), isTrue, reason: 'freight_booking_form_dialog.dart must exist');

      final content = file.readAsStringSync();

      // Units and the cancellation line live in the single charge builder.
      final builderFile = File(file.path.replaceFirst(
        'widgets/freight_booking_form_dialog.dart',
        'services/booking_charge_builder.dart',
      ));
      expect(builderFile.existsSync(), isTrue, reason: 'booking_charge_builder.dart must exist');
      final builder = builderFile.readAsStringSync();

      // Per-type container units
      expect(builder.contains("'Per 40ft Container'"), isTrue,
          reason: 'Must use Per 40ft Container unit');
      expect(builder.contains("'Per 20ft Container'"), isTrue,
          reason: 'Must use Per 20ft Container unit');

      // Cancellation charge
      expect(builder.contains("'Booking Cancellation'"), isTrue,
          reason: 'Must build Booking Cancellation charge');

      // The dialog builds its charges only through the shared builder.
      expect(content.contains('BookingChargeBuilder.build('), isTrue,
          reason: 'Dialog must build charges via BookingChargeBuilder');

      // Single source of truth calculation for executed freight
      expect(content.contains("buildChargesFromQuote(_currentQuoteState)"), isTrue,
          reason: 'Must compute executed freight from buildChargesFromQuote');

      // Mixed currency validation on submit
      expect(content.contains("hasMixedCurrencies"), isTrue,
          reason: 'Must check hasMixedCurrencies before submit');
      expect(content.contains("fbkMixedCurrencyError"), isTrue,
          reason: 'Must show fbkMixedCurrencyError when mixed currencies are present');
    });

    testWidgets('Submitting booking form with mixed currencies blocks save and shows danger SnackBar',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final bookingWithMixed = ShipmentBookingModel(
        bookingId: 42,
        bookingCode: 'BKG-2026-0042',
        importFileId: 10,
        polName: 'Shanghai',
        podName: 'Alexandria',
        createdAt: '2026-10-09T00:00:00Z',
        updatedAt: '2026-10-09T00:00:00Z',
        quotationDetailsData: {
          'container_40ft_app': true,
          'container_40ft_price': 2000.0,
          'container_40ft_cur': 'USD',
          'container_40ft_qty': 1,
          'cancellation_app': true,
          'cancellation_price': 100.0,
          'cancellation_cur': 'EUR',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: AppLocalizationsProvider(
            locale: const Locale('en'),
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => FreightBookingFormDialog(bookingToEdit: bookingWithMixed),
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final saveBtn = find.byKey(const Key('fbkFormSaveBtn'));
      expect(saveBtn, findsOneWidget);

      await tester.tap(saveBtn);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('All charges must use one currency until currency conversion is available'),
        findsOneWidget,
      );
    });
  });
}
