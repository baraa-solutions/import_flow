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

  final mockBankPartner = PartnerModel(
    providerId: 101,
    partnerCode: 'ESP-000101',
    partnerName: 'National Bank of Egypt (NBE) - البنك الأهلي المصري',
    partnerType: 'Bank',
    swiftCode: 'NBEGEGCX',
    bankCode: 'NBE-01',
    branchName: 'Mohandessin Branch',
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
          final notifier = _FakePartnersNotifier([mockBankPartner]);
          return notifier;
        }),
        allPartnersProvider.overrideWith((ref) {
          final notifier = _FakeAllPartnersNotifier([mockBankPartner]);
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

  group('MD-03: Bank Partner Registration & Verification Tests', () {
    testWidgets('PartnersScreen displays Bank partner with Swift code and Bank filter', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify Bank partner name is displayed
      expect(find.textContaining('البنك الأهلي المصري'), findsWidgets);

      // Verify Bank category chip exists
      expect(find.byType(DropdownButton<String>), findsOneWidget); // category filter is now a dropdown (was ChoiceChips)
      expect(find.text('بنك'), findsWidgets); // category badge in the partner row

      // Verify add partner button exists
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('Opening Partner Dialog shows Banking fields when Bank category is chosen', (tester) async {
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

      // Tap Bank choice chip in dialog categories
      final bankChip = find.widgetWithText(FilterChip, 'بنك');
      expect(bankChip, findsOneWidget);
      await tester.tap(bankChip);
      await tester.pumpAndSettle();

      // Verify Bank specific fields are now visible in the dialog
      expect(find.textContaining('بيانات الحساب البنكي'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label.contains('كود السويفت')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label == 'كود البنك'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomTextField && w.label == 'اسم الفرع'), findsOneWidget);
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
