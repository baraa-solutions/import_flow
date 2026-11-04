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

  final mockTransport = PartnerModel(
    providerId: 108,
    partnerCode: 'ESP-000108',
    partnerName: 'Al-Ahram Heavy Transport & Logistics (الأهرام للنقل الثقيل)',
    partnerType: 'Inland Transport',
    transportLicenseNumber: 'MOT-EG-7744',
    fleetTypes: '20/40ft Flatbed, Lowbed, Reefer',
    coverageAreas: 'Alexandria Port, Sokhna, Cairo',
    country: 'Egypt',
    contactPerson: 'Eng. Ahmed El-Banna',
    email: 'dispatch@alahram-transport.com',
    isActive: true,
  );

  final mockInsurance = PartnerModel(
    providerId: 109,
    partnerCode: 'ESP-000109',
    partnerName: 'Misr Marine & Cargo Insurance Company (مصر للتأمين البحري)',
    partnerType: 'Insurance Company',
    insuranceLicenseNumber: 'FRA-INS-808',
    insuranceCoverageTypes: 'Institute Cargo Clauses (A/B/C), War & Strikes',
    country: 'Egypt',
    contactPerson: 'Dr. Tarek Hegazy',
    email: 'marine.claims@misrinsure.eg',
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
          final notifier = _FakePartnersNotifier([mockTransport, mockInsurance]);
          return notifier;
        }),
        allPartnersProvider.overrideWith((ref) {
          final notifier = _FakeAllPartnersNotifier([mockTransport, mockInsurance]);
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

  group('MD-08: Inland Transport & Insurance Registration Tests', () {
    testWidgets('PartnersScreen displays Transport & Insurance partners with badges and categories', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify partner names
      expect(find.textContaining('الأهرام للنقل الثقيل'), findsWidgets);
      expect(find.textContaining('مصر للتأمين البحري'), findsWidgets);

      // Verify Inland Transport badges
      expect(find.textContaining('MOT-EG-7744'), findsWidgets);
      expect(find.textContaining('20/40ft Flatbed, Lowbed, Reefer'), findsWidgets);
      expect(find.textContaining('Alexandria Port, Sokhna, Cairo'), findsWidgets);

      // Verify Insurance Company badges
      expect(find.textContaining('FRA-INS-808'), findsWidgets);
      expect(find.textContaining('Institute Cargo Clauses (A/B/C)'), findsWidgets);

      // Verify category chips
      expect(find.byType(DropdownButton<String>), findsOneWidget); // category filter is now a dropdown (was ChoiceChips)
      expect(find.text('نقل بري'), findsWidgets); // category badge in the partner row
      expect(find.text('شركة تأمين'), findsWidgets); // category badge in the partner row
    });

    testWidgets('Opening Partner Dialog shows Inland Transport and Insurance fields', (tester) async {
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

      // Verify dialog is open
      expect(find.text('إضافة شريك خارجي وبنك جديد'), findsOneWidget);

      // Tap Inland Transport filter chip
      final transportChip = find.widgetWithText(FilterChip, 'نقل بري');
      expect(transportChip, findsOneWidget);
      await tester.tap(transportChip);
      await tester.pumpAndSettle();

      // Verify Inland Transport specific header and fields
      expect(find.textContaining('بيانات أسطول وترخيص النقل البري'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('رقم ترخيص النقل البري')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('أنواع الشاحنات والأسطول')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('نطاق التغطية والمحافظات')), findsOneWidget);

      // Tap Insurance Company filter chip
      final insuranceChip = find.widgetWithText(FilterChip, 'شركة تأمين');
      expect(insuranceChip, findsOneWidget);
      await tester.tap(insuranceChip);
      await tester.pumpAndSettle();

      // Verify Insurance specific header and fields
      expect(find.textContaining('بيانات ترخيص وتغطيات التأمين البحري'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('رقم ترخيص الهيئة العامة للرقابة المالية')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('أنواع التغطيات التأمينية المعتمدة')), findsOneWidget);
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
