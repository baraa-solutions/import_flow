import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/purchase_orders/screens/purchase_orders_screen.dart';

class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode([]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _createTestDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:28080/api/v1'));
  dio.httpClientAdapter = _MockHttpAdapter();
  return dio;
}

class MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  MockPurchaseOrdersNotifier(Ref ref, List<PurchaseOrderModel> orders) : super(Dio(), ref) {
    state = PurchaseOrdersState(
      purchaseOrders: orders,
      isLoading: false,
    );
  }

  @override
  Future<void> fetchPurchaseOrders() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleOrder = PurchaseOrderModel(
    poId: 1,
    poNumber: 'PO-2026-0005',
    poReference: 'YH20260901-3',
    companyId: 10,
    companyName: 'SCAS For Construction And Finishing',
    supplierId: 20,
    supplierName: 'Suzhou Yuheng Textile Co.,Ltd',
    projectId: 1,
    projectName: 'PET -YH20260901-3',
    incotermId: 1,
    incotermCode: 'EXW',
    currencyId: 1,
    currencyCode: 'USD',
    exchangeRate: 48.7,
    status: 'Approved',
    totalAmountFob: 39820.0,
    totalCbm: 60.668,
    totalGrossWeightKg: 12960.0,
    totalNetWeightKg: 12740.0,
    countryOfOrigin: 'CN - الصين (China)',
    orderDate: DateTime(2026, 9, 1),
    items: [
      POLineItemModel(
        itemId: 1,
        itemCode: 'YH-625',
        mainDescription: 'Acoustic Panels',
        descriptionAr: 'ألواح عزل صوتي ديكورية YH-625',
        quantity: 400,
        unitOfMeasure: 'PCS',
        unitPrice: 17.30,
        totalPrice: 6920.0,
        hsCode: '5602290000',
      ),
      POLineItemModel(
        itemId: 2,
        itemCode: 'YH-808',
        mainDescription: 'Acoustic Panels',
        descriptionAr: 'ألواح عزل صوتي YH-808',
        quantity: 100,
        unitOfMeasure: 'PCS',
        unitPrice: 23.50,
        totalPrice: 2350.0,
        hsCode: '5602290000',
      ),
    ],
    packingListItems: [
      PackingListItemModel(
        packingItemId: 1,
        itemCode: 'YH-625',
        hsCode: '5602290000',
        qtyPkg: 40,
        qtyPcs: 400,
        packageType: 'Carton',
        lengthCm: 120,
        widthCm: 80,
        heightCm: 60,
        grossWeightUnitKg: 30,
        netWeightUnitKg: 28,
        isStackable: true,
      ),
      PackingListItemModel(
        packingItemId: 2,
        itemCode: 'YH-808',
        hsCode: '5602290000',
        qtyPkg: 10,
        qtyPcs: 100,
        packageType: 'Carton',
        lengthCm: 120,
        widthCm: 80,
        heightCm: 60,
        grossWeightUnitKg: 35,
        netWeightUnitKg: 33,
        isStackable: true,
      ),
    ],
  );

  Widget createTestApp({
    required Size size,
    Locale locale = const Locale('ar'),
    ThemeMode themeMode = ThemeMode.light,
    required Widget child,
  }) {
    final textDir = locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    final testDio = _createTestDio();

    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(testDio),
        localeProvider.overrideWith((ref) {
          final n = LocaleNotifier();
          n.setLocale(locale);
          return n;
        }),
        purchaseOrdersProvider.overrideWith((ref) => MockPurchaseOrdersNotifier(ref, [sampleOrder])),
        projectsProvider.overrideWith((ref) => ProjectsNotifier(Dio())),
        importFilesProvider.overrideWith((ref) => ImportFilesNotifier(Dio())),
      ],
      // The provider must sit ABOVE MaterialApp so dialog routes see context.l10n.
      child: AppLocalizationsProvider(
        locale: locale,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: locale,
          home: Directionality(
            textDirection: textDir,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Purchase Order View Dialog — 3D Container Load Planner & Simulation Tests', () {
    testWidgets('1. PO View Dialog contains 3 tabs including 3D Container Load Planner & Simulation', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          size: const Size(1400, 900),
          child: const Scaffold(body: PurchaseOrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on row display name to open PO View Dialog
      final displayNameFinder = find.text('YH20260901-3');
      expect(displayNameFinder, findsWidgets);
      await tester.tap(displayNameFinder.first);
      await tester.pumpAndSettle();

      // Verify the Dialog Title is displayed
      expect(find.textContaining('PO-2026-0005'), findsWidgets);

      // Verify the 3 Tabs exist in the TabBar
      expect(find.descendant(of: find.byType(TabBar), matching: find.byIcon(Icons.receipt_long)), findsOneWidget);
      expect(find.descendant(of: find.byType(TabBar), matching: find.byIcon(Icons.fact_check)), findsOneWidget);
      expect(find.descendant(of: find.byType(TabBar), matching: find.byIcon(Icons.view_in_ar_rounded)), findsOneWidget);

      // Verify action button for 3D Load Planner exists (TabBar + Footer action = 2 icons)
      expect(find.byIcon(Icons.view_in_ar_rounded), findsAtLeastNWidgets(2));
    });

    testWidgets('2. Tapping Tab 3 displays interactive 3D Container Load Planner with Stacking Modes & Dual View', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          size: const Size(1400, 900),
          child: const Scaffold(body: PurchaseOrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Open View Dialog
      final displayNameFinder = find.text('YH20260901-3');
      await tester.tap(displayNameFinder.first);
      await tester.pumpAndSettle();

      // Tap on Tab 3 (3D Container Load Planner) in the TabBar
      final tab3Finder = find.descendant(of: find.byType(TabBar), matching: find.byIcon(Icons.view_in_ar_rounded));
      await tester.tap(tab3Finder);
      await tester.pumpAndSettle();

      // Verify Stacking simulation mode chips exist
      expect(find.byType(ChoiceChip), findsWidgets);

      // Verify Dual View selector exists
      expect(find.textContaining('Both Views'), findsWidgets);

      // Verify Grouped items table is rendered
      expect(find.textContaining('YH-625'), findsWidgets);
      expect(find.textContaining('YH-808'), findsWidgets);
    });

    testWidgets('3. Tab 2 Review Packing List contains a direct launch button for 3D Load Planner', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          size: const Size(1400, 900),
          child: const Scaffold(body: PurchaseOrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Open View Dialog
      final displayNameFinder = find.text('YH20260901-3');
      await tester.tap(displayNameFinder.first);
      await tester.pumpAndSettle();

      // Switch to Tab 2 (Review Packing List)
      final tab2Finder = find.descendant(of: find.byType(TabBar), matching: find.byIcon(Icons.fact_check));
      await tester.tap(tab2Finder);
      await tester.pumpAndSettle();

      // Verify 3D simulation banner exists in Tab 2
      expect(find.textContaining('3D'), findsWidgets);
    });
  });
}
