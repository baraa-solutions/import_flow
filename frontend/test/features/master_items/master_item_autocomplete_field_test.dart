import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/master_items/models/master_item_model.dart';
import 'package:frontend/features/master_items/repositories/master_items_repository.dart';
import 'package:frontend/features/master_items/widgets/master_item_autocomplete_field.dart';

/// Fake repository for isolated unit and widget testing of the Autocomplete field.
class FakeMasterItemsRepository extends MasterItemsRepository {
  FakeMasterItemsRepository() : super(Dio());

  int fetchCount = 0;
  String? lastSearchQuery;
  List<MasterItemModel> mockItems = [];

  @override
  Future<MasterItemListModel> fetchMasterItems({
    String? search,
    String? category,
    int skip = 0,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    fetchCount++;
    lastSearchQuery = search;
    return MasterItemListModel(
      total: mockItems.length,
      items: mockItems,
    );
  }
}

Widget createTestApp({
  required Widget child,
  required MasterItemsRepository repository,
  Locale locale = const Locale('ar'),
}) {
  return ProviderScope(
    overrides: [
      masterItemsRepositoryProvider.overrideWithValue(repository),
    ],
    child: AppLocalizationsProvider(
      locale: locale,
      child: MaterialApp(
        locale: locale,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late FakeMasterItemsRepository fakeRepo;

  const sampleItem1 = MasterItemModel(
    itemId: 101,
    itemCode: 'CHILL-100',
    descriptionAr: 'مبرد مياه صناعي',
    descriptionEn: 'Industrial Water Chiller',
    tariffId: 10,
    hsCode: '8418.69',
    defaultUom: 'PCS',
    cbmPerUnit: 1.5,
    grossWeightKg: 250.0,
    netWeightKg: 220.0,
    lastCustomsDutyPct: 0.05,
    lastVatPct: 0.14,
  );

  const sampleItem2 = MasterItemModel(
    itemId: 102,
    itemCode: 'VALV-200',
    descriptionAr: 'صمام ضغط هيدروليكي',
    descriptionEn: 'Hydraulic Pressure Valve',
    tariffId: 12,
    hsCode: '8481.20',
    defaultUom: 'SET',
    cbmPerUnit: 0.05,
    grossWeightKg: 4.5,
    netWeightKg: 4.0,
    lastCustomsDutyPct: 0.02,
    lastVatPct: 0.14,
  );

  setUp(() {
    fakeRepo = FakeMasterItemsRepository();
    fakeRepo.mockItems = [sampleItem1, sampleItem2];
  });

  group('MasterItemAutocompleteField Widget Tests', () {
    testWidgets('1. Zero-Weight Rule: does not load any items on initial render',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          repository: fakeRepo,
          child: const MasterItemAutocompleteField(),
        ),
      );
      await tester.pumpAndSettle();

      // Zero network calls before typing
      expect(fakeRepo.fetchCount, equals(0));
      expect(fakeRepo.lastSearchQuery, isNull);
    });

    testWidgets('2. 300ms Debounce: queries repository only after debounce delay',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          repository: fakeRepo,
          child: const MasterItemAutocompleteField(),
        ),
      );
      await tester.pumpAndSettle();

      // Type search query
      final fieldFinder = find.byType(TextFormField);
      expect(fieldFinder, findsOneWidget);

      await tester.enterText(fieldFinder, 'CHILL');
      await tester.pump(); // Immediate pump

      // Should not have queried yet due to 300ms debounce
      expect(fakeRepo.fetchCount, equals(0));

      // Advance by 150ms - still debouncing
      await tester.pump(const Duration(milliseconds: 150));
      expect(fakeRepo.fetchCount, equals(0));

      // Advance past 300ms
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Now query was sent with 'CHILL'
      expect(fakeRepo.fetchCount, equals(1));
      expect(fakeRepo.lastSearchQuery, equals('CHILL'));
    });

    testWidgets('3. Suggestions Rendering: displays matching items in overlay',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          repository: fakeRepo,
          child: const MasterItemAutocompleteField(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'CHILL');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify overlay displays item details
      expect(find.text('CHILL-100'), findsWidgets);
      expect(find.text('مبرد مياه صناعي'), findsOneWidget);
      expect(find.text('HS: 8418.69'), findsOneWidget);
      expect(find.text('UOM: PCS'), findsOneWidget);
      expect(find.text('250.0 KG'), findsOneWidget);
    });

    testWidgets('4. Item Selection: invokes onItemSelected and pre-fills text',
        (tester) async {
      MasterItemModel? selectedItem;
      String? changedText;

      await tester.pumpWidget(
        createTestApp(
          repository: fakeRepo,
          child: MasterItemAutocompleteField(
            onItemSelected: (item) => selectedItem = item,
            onChanged: (val) => changedText = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'VALV');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Tap the second suggestion
      final suggestion = find.text('صمام ضغط هيدروليكي');
      expect(suggestion, findsOneWidget);
      await tester.tap(suggestion);
      await tester.pumpAndSettle();

      // Callback triggered with sampleItem2
      expect(selectedItem, isNotNull);
      expect(selectedItem!.itemId, equals(102));
      expect(selectedItem!.itemCode, equals('VALV-200'));
      expect(changedText, equals('VALV-200'));

      // Text in field updated
      expect(find.text('VALV-200'), findsOneWidget);
    });

    testWidgets('5. Backward Compatibility: accepts custom manual text entry',
        (tester) async {
      String? lastChangedText;

      await tester.pumpWidget(
        createTestApp(
          repository: fakeRepo,
          child: MasterItemAutocompleteField(
            initialValue: 'CUSTOM-LEGACY-001',
            onChanged: (val) => lastChangedText = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays initial legacy value without errors
      expect(find.text('CUSTOM-LEGACY-001'), findsOneWidget);

      // Typing custom edit
      await tester.enterText(find.byType(TextFormField), 'CUSTOM-MANUAL-EDIT');
      await tester.pump();

      expect(lastChangedText, equals('CUSTOM-MANUAL-EDIT'));
      expect(find.text('CUSTOM-MANUAL-EDIT'), findsOneWidget);
    });

    testWidgets('6. Clear Button: clears field and resets selection',
        (tester) async {
      bool clearedCalled = false;
      String? changedValue;

      await tester.pumpWidget(
        createTestApp(
          repository: fakeRepo,
          child: MasterItemAutocompleteField(
            initialValue: 'TEST-CODE',
            onCleared: () => clearedCalled = true,
            onChanged: (v) => changedValue = v,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find clear button
      final clearBtn = find.byIcon(Icons.clear_rounded);
      expect(clearBtn, findsOneWidget);

      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(clearedCalled, isTrue);
      expect(changedValue, equals(''));
      expect(find.text('TEST-CODE'), findsNothing);
    });
  });
}
