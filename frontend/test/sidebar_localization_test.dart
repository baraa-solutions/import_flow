import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // aiAssistantProvider (and the update snooze) read SharedPreferences.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Sidebar & Navigation Single-Language Presentation Tests', () {
    testWidgets('Sidebar in Arabic mode displays pure Arabic titles and zero English subtitles', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          navigationIndexProvider.overrideWith((ref) => 35),
        ],
      );
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

      // Verify Arabic hub titles are displayed
      expect(find.text('البيانات والجداول الأساسية'), findsOneWidget);
      expect(find.text('تخطيط الشحنة وأوامر الشراء'), findsOneWidget);
      expect(find.text('المرحلة 1: التخطيط والدراسات المسبقة'), findsOneWidget);

      // Verify no stacked English subtitles exist
      expect(find.text('Master Data & Tables'), findsNothing);
      expect(find.text('Shipment Planning'), findsNothing);
      expect(find.text('1. Pre-Planning & Studies'), findsNothing);

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
    });

    testWidgets('Sidebar in English mode displays pure English titles and zero Arabic subtitles', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          navigationIndexProvider.overrideWith((ref) => 35),
        ],
      );
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

      // Verify English hub titles are displayed
      expect(find.text('Master Data & Tables'), findsOneWidget);
      expect(find.text('Shipment Planning'), findsOneWidget);
      expect(find.text('1. Pre-Planning & Studies'), findsOneWidget);

      // Verify no stacked Arabic subtitles exist
      expect(find.text('البيانات والجداول الأساسية'), findsNothing);
      expect(find.text('تخطيط الشحنة وأوامر الشراء'), findsNothing);
      expect(find.text('المرحلة 1: التخطيط والدراسات المسبقة'), findsNothing);

      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
    });
  });
}
