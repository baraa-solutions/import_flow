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

  final mockAgency = PartnerModel(
    providerId: 106,
    partnerCode: 'ESP-000106',
    partnerName: 'SGS Inspection Services Egypt (إس جي إس للفحص)',
    partnerType: 'Inspection Agency',
    inspectionAccreditationNumber: 'GOIEC-EG-9001',
    inspectionScope: 'Pre-shipment Inspection, CoC/VOC, Food, Machinery',
    country: 'Egypt',
    contactPerson: 'Dr. Hesham Kamal',
    email: 'egypt.inspection@sgs.com',
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
          final notifier = _FakePartnersNotifier([mockAgency]);
          return notifier;
        }),
        allPartnersProvider.overrideWith((ref) {
          final notifier = _FakeAllPartnersNotifier([mockAgency]);
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

  group('MD-06: Inspection Agency Registration & Accreditation Tests', () {
    testWidgets('PartnersScreen displays Inspection Agency with Accreditation badge and Scope', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify agency name is displayed
      expect(find.textContaining('إس جي إس للفحص'), findsWidgets);

      // Verify accreditation badge is displayed
      expect(find.textContaining('GOIEC-EG-9001'), findsWidgets);

      // Verify inspection scope is displayed
      expect(find.textContaining('Pre-shipment Inspection, CoC/VOC'), findsWidgets);

      // Verify Inspection Agency category choice chip exists
      expect(find.byType(DropdownButton<String>), findsOneWidget); // category filter is now a dropdown (was ChoiceChips)
      expect(find.text('هيئة فحص ومعاينة'), findsWidgets); // category badge in the partner row

      // Verify add partner button exists
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('Opening Partner Dialog shows Inspection Agency fields (Accreditation #, Scope)', (tester) async {
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

      // Tap Inspection Agency filter chip in dialog categories
      final agencyChip = find.widgetWithText(FilterChip, 'هيئة فحص ومعاينة');
      expect(agencyChip, findsOneWidget);
      await tester.tap(agencyChip);
      await tester.pumpAndSettle();

      // Verify Inspection Agency specific header and fields are visible
      expect(find.textContaining('بيانات جهة الفحص والاعتماد'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('رقم اعتماد جهة الفحص')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('نطاق الفحص والمعاينة')), findsOneWidget);
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
