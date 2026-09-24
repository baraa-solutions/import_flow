import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/widgets/custom_text_field.dart';
import 'package:frontend/features/external_service_providers/models/partner_model.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/external_service_providers/screens/partners_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockShippingLine = PartnerModel(
    providerId: 102,
    partnerCode: 'ESP-000102',
    partnerName: 'Maersk Line Egypt (ميرسك لاين)',
    partnerType: 'Shipping Line',
    scacCode: 'MAEU',
    defaultFreeDays: 14,
    trackingUrl: 'https://www.maersk.com/tracking/',
    country: 'Egypt',
    isActive: true,
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) {
          final n = LocaleNotifier();
          n.setLocale(const Locale('ar'));
          return n;
        }),
        partnersProvider.overrideWith((ref) {
          final notifier = _FakePartnersNotifier([mockShippingLine]);
          return notifier;
        }),
        allPartnersProvider.overrideWith((ref) {
          final notifier = _FakeAllPartnersNotifier([mockShippingLine]);
          return notifier;
        }),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        builder: (context, child) => AppLocalizationsProvider(
          locale: const Locale('ar'),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const Scaffold(
          body: PartnersScreen(),
        ),
      ),
    );
  }

  group('MD-04: Shipping Line Registration & Free Days Tests', () {
    testWidgets('PartnersScreen displays Shipping Line with SCAC and Free Days badge', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify shipping line name is displayed
      expect(find.textContaining('ميرسك لاين'), findsWidgets);

      // Verify SCAC code is displayed
      expect(find.textContaining('MAEU'), findsWidgets);

      // Verify Free Days badge is displayed (14 يوم سماح)
      expect(find.textContaining('14 يوم سماح'), findsWidgets);

      // Verify Shipping Line category choice chip exists
      expect(find.byType(DropdownButton<String>), findsOneWidget); // category filter is now a dropdown (was ChoiceChips)
      expect(find.text('خط ملاحي'), findsWidgets); // category badge in the partner row

      // Verify add partner button exists
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('Opening Partner Dialog shows Shipping Line fields (SCAC, Free Days, Tracking URL)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Add Partner button via add icon
      final addBtn = find.byIcon(Icons.add);
      expect(addBtn, findsWidgets);
      await tester.tap(addBtn.first);
      await tester.pumpAndSettle();

      // Verify dialog is opened
      expect(find.text('إضافة شريك خارجي وبنك جديد'), findsOneWidget);

      // Tap Shipping Line choice chip in dialog categories
      final lineChip = find.widgetWithText(FilterChip, 'خط ملاحي');
      expect(lineChip, findsOneWidget);
      await tester.tap(lineChip);
      await tester.pumpAndSettle();

      // Verify Shipping Line specific header and fields are visible
      expect(find.textContaining('بيانات الخط الملاحي'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('كود الناقل الملاحي')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('فترة السماح الافتراضية')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('رابط تتبع الشحنات الملاحية')), findsOneWidget);
    });
  });
}

class _FakePartnersNotifier extends StateNotifier<AsyncValue<List<PartnerModel>>>
    implements PartnersNotifier {
  _FakePartnersNotifier(List<PartnerModel> data) : super(AsyncValue.data(data));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fetchPartners() async {}
}

class _FakeAllPartnersNotifier extends StateNotifier<AsyncValue<List<PartnerModel>>>
    implements AllPartnersNotifier {
  _FakeAllPartnersNotifier(List<PartnerModel> data) : super(AsyncValue.data(data));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fetchPartners() async {}
}
