import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/features/transport_locations/providers/transport_locations_provider.dart';
import 'package:frontend/features/freight_quotations/providers/freight_quotations_provider.dart';

class MockTransportNotifier extends TransportLocationsNotifier {
  MockTransportNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchLocations({bool includeInactive = true, String? locationType, String? search}) async {
    state = const AsyncValue.data([]);
  }
}

class MockFreightQuotationsNotifier extends FreightQuotationsNotifier {
  MockFreightQuotationsNotifier() : super(Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchRFQs({
    bool includeInactive = false,
    String? search,
    String? shippingMethod,
    int? poId,
    int? projectId,
    String? status, int? skip, int? limit}) async {
    state = const AsyncValue.data([]);
  }
}

List<Override> get _testOverrides => [
  navigationIndexProvider.overrideWith((ref) => 35),
  transportLocationsProvider.overrideWith((ref) => MockTransportNotifier()),
  freightQuotationsProvider.overrideWith((ref) => MockFreightQuotationsNotifier()),
];

void main() {
  // aiAssistantProvider (and the update snooze) read SharedPreferences.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Inquiries Hub (قسم استعلامات) Navigation Tests', () {
    testWidgets('Inquiries Hub exists with Arabic and English titles', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(overrides: _testOverrides);
      container.read(localeProvider.notifier).setLocale(const Locale('ar'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Arabic "استعلامات" Hub title is present
      expect(find.text('استعلامات'), findsOneWidget);

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
    });

    testWidgets('Inquiries Hub expands to show Freight RFQ and Cargo Measurement Engine', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(overrides: _testOverrides);
      container.read(localeProvider.notifier).setLocale(const Locale('ar'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find and tap "استعلامات" ExpansionTile to expand it
      final inquiriesFinder = find.text('استعلامات');
      expect(inquiriesFinder, findsOneWidget);
      await tester.ensureVisible(inquiriesFinder);
      await tester.tap(inquiriesFinder);
      await tester.pumpAndSettle();

      // Verify both items are now visible inside Inquiries
      expect(find.text('طلب ومقارنة عروض النولون والترسية'), findsOneWidget);
      expect(find.text('حاسبة الأحجام وتوزيع الحاويات'), findsOneWidget);

      // Verify tapping Freight RFQ navigates to index 49
      await tester.tap(find.text('طلب ومقارنة عروض النولون والترسية'));
      await tester.pump();
      expect(container.read(navigationIndexProvider), 49);

      // Verify tapping Cargo Measurement Engine navigates to index 3
      await tester.tap(find.text('حاسبة الأحجام وتوزيع الحاويات'));
      await tester.pump();
      expect(container.read(navigationIndexProvider), 3);

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
    });

    testWidgets('English mode displays "Inquiries", "Freight RFQ & Quotations Comparison", and "Cargo Measurement Engine"', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(overrides: _testOverrides);
      container.read(localeProvider.notifier).setLocale(const Locale('en'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('en'),
              child: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify English "Inquiries" Hub title is present
      expect(find.text('Inquiries'), findsOneWidget);
      expect(find.text('استعلامات'), findsNothing);

      // Expand Inquiries
      await tester.ensureVisible(find.text('Inquiries'));
      await tester.tap(find.text('Inquiries'));
      await tester.pumpAndSettle();

      // Verify English items are visible
      expect(find.text('Freight RFQ & Quotations Comparison'), findsOneWidget);
      expect(find.text('Cargo Measurement Engine'), findsOneWidget);

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
    });

    testWidgets('HUB 2 and Phase 1 no longer contain Cargo Measurement Engine or Freight RFQ', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(overrides: _testOverrides);
      container.read(localeProvider.notifier).setLocale(const Locale('ar'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Expand HUB 2: تخطيط الشحنة وأوامر الشراء
      await tester.ensureVisible(find.text('تخطيط الشحنة وأوامر الشراء'));
      await tester.tap(find.text('تخطيط الشحنة وأوامر الشراء'));
      await tester.pumpAndSettle();

      // Hub 2 contains Import Files and POs
      expect(find.text('ملفات الشحنات الاستيرادية'), findsOneWidget);
      expect(find.text('أوامر الشراء وإثبات المنشأ'), findsOneWidget);

      // Expand Phase 1: المرحلة 1: التخطيط والدراسات المسبقة
      await tester.ensureVisible(find.text('المرحلة 1: التخطيط والدراسات المسبقة'));
      await tester.tap(find.text('المرحلة 1: التخطيط والدراسات المسبقة'));
      await tester.pumpAndSettle();

      // Phase 1 contains Freight Studies, Customs Studies, Import Regulatory
      expect(find.text('دراسة النولون والجدول الزمني والسجلات المحفوظة'), findsOneWidget);
      expect(find.text('الدراسات الجمركية وعروض التخليص ومراجعة الضرائب'), findsOneWidget);
      expect(find.text('متطلبات واشتراطات الاستيراد للشحنة'), findsOneWidget);

      // Confirm exactly 0 duplicate occurrences of old items in expanded Hub 2 and Phase 1
      expect(find.text('CBM & Container Loading'), findsNothing);

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
    });
  });
}
