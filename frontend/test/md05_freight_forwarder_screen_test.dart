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

  final mockForwarder = PartnerModel(
    providerId: 105,
    partnerCode: 'ESP-000105',
    partnerName: 'Apex Global Freight Logistics (أبيكس للشحن الدولي)',
    partnerType: 'Freight Forwarder',
    fiataId: 'FIATA-EG-7721',
    shippingModes: 'Sea FCL, Sea LCL, Air Freight',
    supportedCurrencies: 'USD, EUR, EGP',
    country: 'Egypt',
    contactPerson: 'Tamer Salem',
    email: 'pricing@apexfreight.com',
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
          final notifier = _FakePartnersNotifier([mockForwarder]);
          return notifier;
        }),
        allPartnersProvider.overrideWith((ref) {
          final notifier = _FakeAllPartnersNotifier([mockForwarder]);
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

  group('MD-05: Freight Forwarder Registration & Quotations Tests', () {
    testWidgets('PartnersScreen displays Freight Forwarder with FIATA badge and shipping modes', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify forwarder name is displayed
      expect(find.textContaining('أبيكس للشحن الدولي'), findsWidgets);

      // Verify FIATA badge is displayed
      expect(find.textContaining('FIATA-EG-7721'), findsWidgets);

      // Verify shipping modes are displayed
      expect(find.textContaining('Sea FCL, Sea LCL, Air Freight'), findsWidgets);

      // Verify supported currencies are displayed
      expect(find.textContaining('USD, EUR, EGP'), findsWidgets);

      // Verify Freight Forwarder category choice chip exists
      expect(find.byType(DropdownButton<String>), findsOneWidget); // category filter is now a dropdown (was ChoiceChips)
      expect(find.text('وكيل شحن'), findsWidgets); // category badge in the partner row

      // Verify add partner button exists
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('Opening Partner Dialog shows Freight Forwarder fields (FIATA, Currencies, Shipping Modes)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Add Partner button
      final addBtn = find.byIcon(Icons.add);
      expect(addBtn, findsWidgets);
      await tester.tap(addBtn.first);
      await tester.pumpAndSettle();

      // Verify dialog is opened
      expect(find.text('إضافة شريك خارجي وبنك جديد'), findsOneWidget);

      // Tap Freight Forwarder filter chip in dialog categories
      final ffChip = find.widgetWithText(FilterChip, 'وكيل شحن');
      expect(ffChip, findsOneWidget);
      await tester.tap(ffChip);
      await tester.pumpAndSettle();

      // Verify Freight Forwarder specific header and fields are visible
      expect(find.textContaining('بيانات وكيل الشحن الدولي وعروض الأسعار'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('رخصة الفياتا')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('العملات المعتمدة')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('طرق ومجالات الشحن')), findsOneWidget);
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
