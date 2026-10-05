import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:frontend/main.dart';

import 'helpers/localized_app.dart';

/// Locale notifier without secure-storage side effects.
class _FixedLocaleNotifier extends LocaleNotifier {
  _FixedLocaleNotifier(Locale initial) {
    state = initial;
  }

  @override
  Future<void> toggleLocale() async {
    state = state.languageCode == 'en' ? AppLocales.arabic : AppLocales.english;
  }

  @override
  Future<void> setLocale(Locale locale) async => state = locale;
}

class _LoggedOutAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _LoggedOutAuthNotifier() : super(const AuthState(isAuthenticated: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pumpRealApp(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(1366, 768);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(overrides: [
    localeProvider.overrideWith((ref) => _FixedLocaleNotifier(locale)),
    authProvider.overrideWith((ref) => _LoggedOutAuthNotifier()),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const SorourLogisticsApp(),
  ));
  await tester.pumpAndSettle();
  return container;
}

BuildContext _loginContext(WidgetTester tester) => tester.element(find.byType(LoginScreen));

void main() {
  group('AppLocales', () {
    test('supports en and plain ar (no country variant), English first', () {
      expect(AppLocales.supportedLocales, const [Locale('en'), Locale('ar')]);
      expect(AppLocales.localizationsDelegates, contains(GlobalMaterialLocalizations.delegate));
      expect(AppLocales.localizationsDelegates, contains(GlobalWidgetsLocalizations.delegate));
      expect(AppLocales.localizationsDelegates, contains(GlobalCupertinoLocalizations.delegate));
    });

    test('textDirectionFor maps ar to rtl and everything else to ltr', () {
      expect(AppLocales.textDirectionFor(const Locale('ar')), TextDirection.rtl);
      expect(AppLocales.textDirectionFor(const Locale('ar', 'EG')), TextDirection.rtl);
      expect(AppLocales.textDirectionFor(const Locale('en')), TextDirection.ltr);
    });
  });

  group('SorourLogisticsApp locale wiring (real MaterialApp from main.dart)', () {
    testWidgets('ar resolves to Arabic, RTL and Arabic Material strings', (tester) async {
      await _pumpRealApp(tester, AppLocales.arabic);

      final ctx = _loginContext(tester);
      expect(Localizations.localeOf(ctx).languageCode, 'ar');
      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(MaterialLocalizations.of(ctx), isA<MaterialLocalizationAr>());
      expect(context10n(ctx).isArabic, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en resolves to English and LTR', (tester) async {
      await _pumpRealApp(tester, AppLocales.english);

      final ctx = _loginContext(tester);
      expect(Localizations.localeOf(ctx).languageCode, 'en');
      expect(Directionality.of(ctx), TextDirection.ltr);
      expect(MaterialLocalizations.of(ctx).okButtonLabel, 'OK');
      expect(context10n(ctx).isArabic, isFalse);
    });

    testWidgets('toggling the locale flips direction both ways', (tester) async {
      final container = await _pumpRealApp(tester, AppLocales.english);
      expect(Directionality.of(_loginContext(tester)), TextDirection.ltr);

      await container.read(localeProvider.notifier).toggleLocale();
      await tester.pumpAndSettle();
      expect(Directionality.of(_loginContext(tester)), TextDirection.rtl);
      expect(Localizations.localeOf(_loginContext(tester)).languageCode, 'ar');

      await container.read(localeProvider.notifier).toggleLocale();
      await tester.pumpAndSettle();
      expect(Directionality.of(_loginContext(tester)), TextDirection.ltr);
      expect(Localizations.localeOf(_loginContext(tester)).languageCode, 'en');
    });

    testWidgets('only one Directionality decides: no outer wrapper above MaterialApp', (tester) async {
      await _pumpRealApp(tester, AppLocales.arabic);

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      expect(find.ancestor(of: materialApp, matching: find.byType(Directionality)), findsNothing);
    });
  });

  group('Digits under ar (decision: Western digits)', () {
    testWidgets('Material formatters keep Western digits for plain ar', (tester) async {
      await tester.pumpWidget(localizedApp(home: const SizedBox()));
      await tester.pumpAndSettle();

      final ml = MaterialLocalizations.of(tester.element(find.byType(SizedBox)));
      expect(ml.formatDecimal(1234567), '1,234,567');
      expect(ml.formatYear(DateTime(2026, 9, 29)), '2026');
      // RLM marks between parts, digits stay 0-9.
      expect(ml.formatCompactDate(DateTime(2026, 9, 29)), '29‏/9‏/2026');
      expect(ml.formatTimeOfDay(const TimeOfDay(hour: 14, minute: 5)), '2:05 م');
      expect(ml.pageRowsInfoTitle(1, 10, 57, false), 'من 1 إلى 10 من إجمالي 57');
    });

    testWidgets('ar_EG would switch to Arabic-Indic digits (why AppLocales uses plain ar)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('ar', 'EG'),
        supportedLocales: [Locale('en'), Locale('ar', 'EG')],
        localizationsDelegates: AppLocales.localizationsDelegates,
        home: SizedBox(),
      ));
      await tester.pumpAndSettle();

      final ml = MaterialLocalizations.of(tester.element(find.byType(SizedBox)));
      expect(ml.formatDecimal(1234567), '١٬٢٣٤٬٥٦٧');
    });
  });
}

AppLocalizations context10n(BuildContext context) => AppLocalizations.of(context);
