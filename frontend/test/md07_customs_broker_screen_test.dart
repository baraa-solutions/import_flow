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

  final mockBroker = PartnerModel(
    providerId: 107,
    partnerCode: 'ESP-000107',
    partnerName: 'Al-Farouk Customs Clearance Agency (مكتب الفاروق للتخليص الجمركي)',
    partnerType: 'Customs Broker',
    clearanceLicenseNumber: 'LIC-ALX-8844',
    authorizedPorts: 'Alexandria, Port Said, Damietta, Ain Sokhna',
    country: 'Egypt',
    contactPerson: 'Farouk Mohamed',
    email: 'info@alfarouk-customs.eg',
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
          final notifier = _FakePartnersNotifier([mockBroker]);
          return notifier;
        }),
        allPartnersProvider.overrideWith((ref) {
          final notifier = _FakeAllPartnersNotifier([mockBroker]);
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

  group('MD-07: Customs Broker Registration & Authorized Ports Tests', () {
    testWidgets('PartnersScreen displays Customs Broker with License and Ports badges', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify broker name is displayed
      expect(find.textContaining('مكتب الفاروق للتخليص الجمركي'), findsWidgets);

      // Verify license number badge is displayed
      expect(find.textContaining('LIC-ALX-8844'), findsWidgets);

      // Verify authorized ports badge is displayed
      expect(find.textContaining('Alexandria, Port Said, Damietta, Ain Sokhna'), findsWidgets);

      // Verify Customs Broker category choice chip exists
      expect(find.byType(DropdownButton<String>), findsOneWidget); // category filter is now a dropdown (was ChoiceChips)
      expect(find.text('مخلص جمركي'), findsWidgets); // category badge in the partner row

      // Verify add partner button exists
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('Opening Partner Dialog shows Customs Broker fields (License #, Ports)', (tester) async {
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

      // Tap Customs Broker filter chip in dialog categories
      final brokerChip = find.widgetWithText(FilterChip, 'مخلص جمركي');
      expect(brokerChip, findsOneWidget);
      await tester.tap(brokerChip);
      await tester.pumpAndSettle();

      // Verify Customs Broker specific header and fields are visible
      expect(find.textContaining('ترخيص التخليص الجمركي'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('رقم ترخيص مزاولة التخليص')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('الموانئ والمنافذ الجمركية المعتمدة')), findsOneWidget);
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
