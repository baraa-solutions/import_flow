import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/widgets/widgets.dart';
import 'package:frontend/features/incoterms/models/incoterm_model.dart';
import 'package:frontend/features/incoterms/providers/incoterms_provider.dart';
import 'package:frontend/features/incoterms/screens/incoterms_screen.dart';
import 'package:frontend/features/incoterms/widgets/incoterm_edit_dialog.dart';
import 'package:frontend/features/incoterms/widgets/incoterms_data_table.dart';

class _FakeIncotermsNotifier
    extends StateNotifier<AsyncValue<List<IncotermModel>>>
    implements IncotermsNotifier {
  _FakeIncotermsNotifier(List<IncotermModel> data)
      : super(AsyncValue.data(data));

  @override
  Future<void> fetchIncoterms() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCostItemsNotifier
    extends StateNotifier<AsyncValue<List<CostItemModel>>>
    implements CostItemsNotifier {
  _FakeCostItemsNotifier() : super(const AsyncValue.data([]));

  @override
  Future<void> fetchCostItems() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMatrixNotifier
    extends StateNotifier<AsyncValue<List<IncotermResponsibilityModel>>>
    implements ResponsibilityMatrixNotifier {
  _FakeMatrixNotifier() : super(const AsyncValue.data([]));

  @override
  Future<void> fetchAll() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithApp(
  Widget child, {
  Locale locale = const Locale('ar'),
  List<IncotermModel> incoterms = const [],
}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) {
        final n = LocaleNotifier();
        n.setLocale(locale);
        return n;
      }),
      incotermsProvider.overrideWith((ref) => _FakeIncotermsNotifier(incoterms)),
      costItemsProvider.overrideWith((ref) => _FakeCostItemsNotifier()),
      responsibilityMatrixProvider.overrideWith((ref) => _FakeMatrixNotifier()),
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

  final now = DateTime.now();
  final testIncoterms = [
    IncotermModel(
      incotermId: 1,
      incotermCode: 'FOB',
      incotermName: 'Free on Board',
      version: 'Incoterms 2020',
      description: 'Seller delivers goods on board vessel.',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
    IncotermModel(
      incotermId: 2,
      incotermCode: 'CIF',
      incotermName: 'Cost, Insurance and Freight',
      version: 'Incoterms 2020',
      description: 'Seller pays freight and insurance.',
      isActive: false,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  group('Incoterms Modularized Widgets Tests', () {
    testWidgets('IncotermsDataTable renders within SelectionArea with copyable cells',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          IncotermsDataTable(incoterms: testIncoterms),
          incoterms: testIncoterms,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.text('FOB'), findsOneWidget);
      expect(find.text('Free on Board'), findsOneWidget);
      expect(find.byType(AppStatusBadge), findsWidgets);
    });

    testWidgets('IncotermEditDialog renders with SelectionArea and AppButton',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(const IncotermEditDialog()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(AppButton), findsWidgets);
    });

    testWidgets('IncotermsScreen adheres to Type B header without Stage Badge',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const IncotermsScreen(),
          incoterms: testIncoterms,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageHeader), findsOneWidget);
      expect(find.byType(BackToDashboardButton), findsOneWidget);
      expect(find.byType(SelectionArea), findsWidgets);
      expect(find.text('FOB'), findsOneWidget);
    });
  });
}
