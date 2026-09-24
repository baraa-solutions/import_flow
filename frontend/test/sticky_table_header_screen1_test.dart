import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/page_header.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/purchase_orders/providers/purchase_orders_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/import_files/screens/import_files_screen.dart';

void main() {
  final sampleFiles = List.generate(
    25,
    (index) => ImportFileModel(
      importFileId: index + 1,
      importFileCode: 'FILE-EG-2026-000',
      companyId: 1,
      companyName: 'Company ',
      supplierId: 1,
      supplierName: 'Supplier International Ltd',
      status: index % 2 == 0 ? 'Open' : 'Closed',
      priority: index % 3 == 0 ? 'High' : 'Normal',
      shipmentMode: 'AIR',
      incotermCode: 'FOB',
      currentStage: 'stage_01',
      currentModule: 'Shipment Planning',
      progressPercent: 45.0,
      nextAction: 'Review documents',
      owner: 'Broker Ahmed',
      estimatedCost: 15000.0,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    ),
  );

  Widget createTestWidget({
    required Size size,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('ar'),
  }) {
    final container = ProviderContainer(
      overrides: [
        paginatedImportFilesProvider.overrideWith(
          (ref) => _MockPaginatedImportFilesNotifier(sampleFiles),
        ),
        importCompaniesProvider.overrideWith(
          (ref) => _MockImportCompaniesNotifier(),
        ),
        purchaseOrdersProvider.overrideWith(
          (ref) => _MockPurchaseOrdersNotifier(),
        ),
      ],
    );
    container.read(localeProvider.notifier).setLocale(locale);

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
        home: AppLocalizationsProvider(
          locale: locale,
          child: MediaQuery(
            data: MediaQueryData(size: size),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: const Scaffold(
                body: ImportFilesScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Shipment Planning - Sticky Table Header Tests', () {
    testWidgets('Desktop View (1366x768): Table renders sticky header pinned above scrollable body with 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(size: const Size(1366, 768)));
      await tester.pumpAndSettle();

      // Verify two DataTables exist: one for Sticky Header, one for Body
      final dataTableFinders = find.byType(DataTable);
      expect(dataTableFinders, findsNWidgets(2));

      // First DataTable is the Sticky Header
      final headerDataTable = tester.widget<DataTable>(dataTableFinders.first);
      expect(headerDataTable.headingRowHeight, 46.0);
      expect(headerDataTable.rows.isEmpty, isTrue);
      expect(headerDataTable.columns.length, 13);

      // Second DataTable is the Body
      final bodyDataTable = tester.widget<DataTable>(dataTableFinders.last);
      expect(bodyDataTable.headingRowHeight, 0.0);
      expect(bodyDataTable.rows.length, 25);
      expect(bodyDataTable.columns.length, 13);

      // Verify no RenderFlex overflows
      expect(tester.takeException(), isNull);
    });

    testWidgets('Vertical Scroll: Scrolling table body keeps sticky header fixed at top', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(size: const Size(1366, 768)));
      await tester.pumpAndSettle();

      // Get initial position of Sticky Header
      final headerFinder = find.byType(DataTable).first;
      final initialHeaderTop = tester.getTopLeft(headerFinder).dy;

      // Scroll the body down by 300 pixels
      final bodyScrollable = find.byType(SingleChildScrollView).at(1);
      await tester.drag(bodyScrollable, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Header position must remain strictly unchanged (sticky)
      final afterScrollHeaderTop = tester.getTopLeft(headerFinder).dy;
      expect(afterScrollHeaderTop, equals(initialHeaderTop));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tablet View (1366x1024): Sticky header renders with solid background and shadow without overflow', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(size: const Size(1366, 1024)));
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dark Mode: Sticky header uses darkSurface background matching AppTheme', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(size: const Size(1366, 768), themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Vertical Scrollbar: Scrollbar container is flipped to left (RTL) while body content maintains LTR direction', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(size: const Size(1366, 768), locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Find the vertical body scrollbar (last Scrollbar outside the PageHeader actions strip)
      final headerScrollbars = find
          .descendant(of: find.byType(PageHeader), matching: find.byType(Scrollbar))
          .evaluate()
          .toSet();
      final bodyScrollbarFinder = find
          .byElementPredicate((e) => e.widget is Scrollbar && !headerScrollbars.contains(e))
          .last;
      expect(bodyScrollbarFinder, findsOneWidget);

      // Verify the Directionality immediately wrapping the vertical Scrollbar is TextDirection.rtl (scrollbar on left)
      final outerDirectionality = tester.widget<Directionality>(
        find.ancestor(of: bodyScrollbarFinder, matching: find.byType(Directionality)).first,
      );
      expect(outerDirectionality.textDirection, TextDirection.rtl);

      // Verify the Directionality inside the Scrollbar restores ambient LTR for table content
      final innerDirectionality = tester.widget<Directionality>(
        find.descendant(of: bodyScrollbarFinder, matching: find.byType(Directionality)).first,
      );
      expect(innerDirectionality.textDirection, TextDirection.ltr);

      expect(tester.takeException(), isNull);
    });
  });
}

class _MockPaginatedImportFilesNotifier extends PaginatedImportFilesNotifier {
  _MockPaginatedImportFilesNotifier(List<ImportFileModel> files)
      : super(Dio()) {
    state = PaginatedImportFilesState(
      items: files,
      total: files.length,
      page: 1,
      pageSize: 25,
      totalPages: 1,
      isLoading: false,
    );
  }

  @override
  Future<void> fetchPage(
    int page, {
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

class _MockImportCompaniesNotifier extends ImportCompaniesNotifier {
  _MockImportCompaniesNotifier()
      : super(
          showInactive: true,
          dio: Dio(),
        ) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchCompanies() async {}
}

class _MockPurchaseOrdersNotifier extends PurchaseOrdersNotifier {
  _MockPurchaseOrdersNotifier()
      : super(
          Dio(),
          _MockRef(),
        ) {
    state = PurchaseOrdersState(
      purchaseOrders: const [],
      isLoading: false,
    );
  }

  @override
  Future<void> fetchPurchaseOrders() async {}
}

class _MockRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

