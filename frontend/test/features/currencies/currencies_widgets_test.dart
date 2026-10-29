import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/currencies/models/currency_model.dart';
import 'package:frontend/features/currencies/providers/currencies_provider.dart';
import 'package:frontend/features/currencies/screens/currencies_screen.dart';
import 'package:frontend/features/currencies/widgets/currencies_exchange_rate_table.dart';
import 'package:frontend/features/currencies/widgets/currency_rate_update_dialog.dart';

class _FakeCurrenciesNotifier
    extends StateNotifier<AsyncValue<List<CurrencyModel>>>
    implements CurrenciesNotifier {
  _FakeCurrenciesNotifier(List<CurrencyModel> data)
      : super(AsyncValue.data(data));

  @override
  Future<void> fetchCurrencies(
      {bool includeInactive = true, String? search}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithApp(
  Widget child, {
  Locale locale = const Locale('ar'),
  List<CurrencyModel> currencies = const [],
}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) {
        final n = LocaleNotifier();
        n.setLocale(locale);
        return n;
      }),
      currenciesProvider
          .overrideWith((ref) => _FakeCurrenciesNotifier(currencies)),
    ],
    child: MaterialApp(
      home: AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Material(child: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCurrencies = [
    CurrencyModel(
      currencyId: 1,
      currencyCode: 'EGP',
      currencyName: 'Egyptian Pound',
      currencySymbol: 'E£',
      isBaseCurrency: true,
      latestCommercialRate: 1.0,
      latestCustomsRate: 1.0,
      isActive: true,
    ),
    CurrencyModel(
      currencyId: 2,
      currencyCode: 'USD',
      currencyName: 'US Dollar',
      currencySymbol: r'$',
      isBaseCurrency: false,
      latestCommercialRate: 48.50,
      latestCustomsRate: 48.25,
      isActive: true,
    ),
  ];

  group('Currencies Modularized Widgets Tests', () {
    testWidgets('CurrenciesExchangeRateTable renders with SelectionArea and EnterpriseDataTable',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          CurrenciesExchangeRateTable(currencies: testCurrencies),
          currencies: testCurrencies,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('EGP'), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsWidgets);
    });

    testWidgets('CurrencyRateUpdateDialog renders with SelectionArea, SearchableDropdownField, and AppButton',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const CurrencyRateUpdateDialog(preSelectedCurrencyId: 2),
          currencies: testCurrencies,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(SearchableDropdownField<int?>), findsOneWidget);
      expect(find.byType(AppButton), findsWidgets);
    });

    testWidgets('CurrenciesScreen adheres to Type B header without Stage Badge and uses AppButton',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const CurrenciesScreen(),
          currencies: testCurrencies,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageHeader), findsOneWidget);
      expect(find.byType(BackToDashboardButton), findsOneWidget);
      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.byType(AppButton), findsWidgets);
      expect(find.text('USD'), findsOneWidget);
    });
  });
}
