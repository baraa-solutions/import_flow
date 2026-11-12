import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/customs_tariff/widgets/screen/customs_tariff_table.dart';

/// Trello PeVs61Cj: tariff versions carry a decree validity window shown in the tariff table.
CustomsTariffModel _tariff(String from, [String? to]) => CustomsTariffModel.fromJson({
      'tariff_id': 1,
      'hs_code': '8536.41.00',
      'hs_description': 'Relays',
      'customs_duty_rate': 10,
      'vat_rate': 14,
      'requires_acid': true,
      'effective_from': from,
      'effective_to': to,
      'is_active': true,
      'created_at': '2026-01-01T00:00:00',
      'updated_at': '2026-01-01T00:00:00',
    });

void main() {
  final day = DateTime(2026, 6, 15);

  group('CustomsTariffModel.validityOn', () {
    test('open-ended version started before the day is active', () {
      expect(_tariff('2026-01-01').validityOn(day), TariffValidity.active);
    });

    test('both bounds are inclusive', () {
      expect(_tariff('2026-06-15').validityOn(day), TariffValidity.active);
      expect(_tariff('2026-01-01', '2026-06-15').validityOn(day), TariffValidity.active);
    });

    test('closed before the day is expired', () {
      expect(_tariff('2026-01-01', '2026-06-14').validityOn(day), TariffValidity.expired);
    });

    test('starting after the day is upcoming', () {
      expect(_tariff('2026-07-01').validityOn(day), TariffValidity.upcoming);
    });

    test('time of day does not matter', () {
      expect(_tariff('2026-06-15T23:59:00').validityOn(DateTime(2026, 6, 15, 0, 1)), TariffValidity.active);
    });
  });

  group('CustomsTariffTable.validityBadge', () {
    Future<void> pumpBadge(WidgetTester tester, Widget badge) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: badge)));

    testWidgets('shows the Arabic window label per state', (tester) async {
      const ar = AppLocalizationsAr();
      await pumpBadge(tester, CustomsTariffTable.validityBadge(ar, _tariff('2026-01-01'), day));
      expect(find.text('سارية من 01/01/2026'), findsOneWidget);

      await pumpBadge(tester, CustomsTariffTable.validityBadge(ar, _tariff('2025-01-01', '2026-06-14'), day));
      expect(find.text('منتهية في 14/06/2026'), findsOneWidget);

      await pumpBadge(tester, CustomsTariffTable.validityBadge(ar, _tariff('2026-07-01'), day));
      expect(find.text('تبدأ في 01/07/2026'), findsOneWidget);
    });

    testWidgets('English labels carry no Arabic text', (tester) async {
      const en = AppLocalizationsEn();
      await pumpBadge(tester, CustomsTariffTable.validityBadge(en, _tariff('2026-01-01'), day));
      expect(find.text('In force since 01/01/2026'), findsOneWidget);
    });
  });

  group('tariffValidityPayload', () {
    test('create sends both dates, empty Effective To as null', () {
      expect(tariffValidityPayload(from: '2026-01-01', to: ''),
          {'effective_from': '2026-01-01', 'effective_to': null});
    });

    test('edit with untouched dates sends neither date', () {
      expect(
        tariffValidityPayload(
            from: '2025-01-01', to: '', originalFrom: '2025-01-01', originalTo: ''),
        isEmpty,
      );
    });

    test('edit sends only the changed Effective From', () {
      expect(
        tariffValidityPayload(
            from: '2026-11-12', to: '2027-01-01', originalFrom: '2025-01-01', originalTo: '2027-01-01'),
        {'effective_from': '2026-11-12'},
      );
    });

    test('clearing Effective To on edit sends an explicit null', () {
      expect(
        tariffValidityPayload(
            from: '2025-01-01', to: '', originalFrom: '2025-01-01', originalTo: '2027-01-01'),
        {'effective_to': null},
      );
    });
  });

  group('shouldDefaultEffectiveFromToToday', () {
    final today = DateTime(2026, 11, 12, 15, 30);

    test('rate change on an in-force version with untouched start defaults to today', () {
      expect(
        shouldDefaultEffectiveFromToToday(
            rateChanged: true, currentFrom: '2025-01-01', originalFrom: '2025-01-01', today: today),
        isTrue,
      );
    });

    test('no rate change keeps the stored start', () {
      expect(
        shouldDefaultEffectiveFromToToday(
            rateChanged: false, currentFrom: '2025-01-01', originalFrom: '2025-01-01', today: today),
        isFalse,
      );
    });

    test('a start the user picked is never overridden', () {
      expect(
        shouldDefaultEffectiveFromToToday(
            rateChanged: true, currentFrom: '2027-01-01', originalFrom: '2025-01-01', today: today),
        isFalse,
      );
    });

    test('a version starting today or later is edited in place', () {
      expect(
        shouldDefaultEffectiveFromToToday(
            rateChanged: true, currentFrom: '2026-11-12', originalFrom: '2026-11-12', today: today),
        isFalse,
      );
      expect(
        shouldDefaultEffectiveFromToToday(
            rateChanged: true, currentFrom: '2027-02-01', originalFrom: '2027-02-01', today: today),
        isFalse,
      );
    });
  });
}
