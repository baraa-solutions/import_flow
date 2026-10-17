import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/widgets/paged_data_table/list_query.dart';
import 'package:frontend/core/widgets/paged_data_table/page_result.dart';
import 'package:frontend/core/widgets/paged_data_table/paged_data_table.dart';
import 'package:frontend/core/widgets/paged_data_table/paged_list_notifier.dart';
import 'package:frontend/core/widgets/paged_data_table/paged_table_column.dart';
import 'package:frontend/core/widgets/paged_data_table/row_action.dart';
import 'package:frontend/core/widgets/enterprise_data_table/widgets/enterprise_table_shimmer_skeleton.dart';
import 'package:frontend/features/auth/providers/current_permissions_provider.dart';
import 'helpers/localized_app.dart';

class _TestRow {
  final int id;
  final String code;
  final String name;
  final double amount;

  const _TestRow({
    required this.id,
    required this.code,
    required this.name,
    required this.amount,
  });
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  List<PagedTableColumn<_TestRow>> createColumns() {
    return [
      PagedTableColumn<_TestRow>(
        id: 'code',
        label: (l) => 'Code',
        width: 120,
        pinned: true,
        sortKey: 'code',
        cell: (context, row) => Text(row.code, key: ValueKey('code_${row.id}')),
        exportValue: (row) => row.code,
      ),
      PagedTableColumn<_TestRow>(
        id: 'name',
        label: (l) => 'Name',
        width: 180,
        sortKey: 'name',
        cell: (context, row) => Text(row.name),
        exportValue: (row) => row.name,
      ),
      PagedTableColumn<_TestRow>(
        id: 'amount',
        label: (l) => 'Amount',
        width: 140,
        numeric: true,
        sortKey: 'amount',
        cell: (context, row) => Text(row.amount.toStringAsFixed(2)),
        exportValue: (row) => row.amount.toString(),
      ),
    ];
  }

  group('PagedDataTable Widget Tests', () {
    testWidgets('virtualizes rows: with 1,000 items in state, fewer than 60 row widgets exist', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = List.generate(
        1000,
        (i) => _TestRow(id: i, code: 'ITEM-$i', name: 'Product $i', amount: (i + 1) * 10.0),
      );

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 100),
        data: PageResult<_TestRow>(
          items: items,
          total: 1000,
          page: 1,
          pageSize: 100,
          totalPages: 10,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_virtualization',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderedCodes = find.byWidgetPredicate(
        (widget) => widget is Text && widget.key is ValueKey && (widget.key as ValueKey).value.toString().startsWith('code_'),
      );

      expect(renderedCodes.evaluate().length, lessThan(60));
      expect(find.text('ITEM-0'), findsOneWidget);
    });

    testWidgets('cycles sort on header tap: code -> -code -> none', (tester) async {
      ListQuery? lastQuery;
      var currentQuery = const ListQuery(page: 1, pageSize: 50);

      final items = [
        const _TestRow(id: 1, code: 'A-01', name: 'Alpha', amount: 100),
        const _TestRow(id: 2, code: 'B-02', name: 'Beta', amount: 200),
      ];

      Widget buildTable(ListQuery q) {
        return ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_sort',
                columns: createColumns(),
                state: PagedListState<_TestRow>(
                  query: q,
                  data: PageResult<_TestRow>(
                    items: items,
                    total: 2,
                    page: 1,
                    pageSize: 50,
                    totalPages: 1,
                  ),
                ),
                onQueryChanged: (newQ) => lastQuery = newQ,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildTable(currentQuery));
      await tester.pumpAndSettle();

      // Tap Code header -> sort = 'code'
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(lastQuery?.sort, equals('code'));

      // Update query state with 'code'
      currentQuery = currentQuery.copyWith(sort: 'code');
      await tester.pumpWidget(buildTable(currentQuery));
      await tester.pumpAndSettle();

      // Tap Code header again -> sort = '-code'
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(lastQuery?.sort, equals('-code'));

      // Update query state with '-code'
      currentQuery = currentQuery.copyWith(sort: '-code');
      await tester.pumpWidget(buildTable(currentQuery));
      await tester.pumpAndSettle();

      // Tap Code header again -> sort = null
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(lastQuery?.sort, isNull);
    });

    testWidgets('pinned pane is placed at the right in RTL (Arabic) and left in LTR (English)', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = [
        const _TestRow(id: 1, code: 'A-01', name: 'Alpha', amount: 100),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 1,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      // 1. Arabic (RTL)
      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.arabic,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_rtl',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pinnedFinder = find.byKey(const Key('paged_data_table_pinned_pane'));
      final scrollFinder = find.byKey(const Key('paged_data_table_scrolling_pane'));
      expect(pinnedFinder, findsOneWidget);
      expect(scrollFinder, findsOneWidget);

      final pinnedOffsetRtl = tester.getTopLeft(pinnedFinder);
      final scrollOffsetRtl = tester.getTopLeft(scrollFinder);
      // In RTL, pinned pane is at the right, so its X offset is greater than scrolling pane
      expect(pinnedOffsetRtl.dx, greaterThan(scrollOffsetRtl.dx));

      // 2. English (LTR)
      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_ltr',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pinnedOffsetLtr = tester.getTopLeft(pinnedFinder);
      final scrollOffsetLtr = tester.getTopLeft(scrollFinder);
      // In LTR, pinned pane is at the left, so its X offset is less than scrolling pane
      expect(pinnedOffsetLtr.dx, lessThan(scrollOffsetLtr.dx));
    });

    testWidgets('triggers onOpen on row double click', (tester) async {
      _TestRow? openedRow;
      final items = [
        const _TestRow(id: 42, code: 'ITEM-42', name: 'Galaxy', amount: 500),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 1,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_open',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
                onOpen: (row) => openedRow = row,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Double tap on row
      await tester.tap(find.text('ITEM-42'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('ITEM-42'));
      await tester.pumpAndSettle();

      expect(openedRow?.id, equals(42));
    });

    testWidgets('shows shimmer skeleton on first load', (tester) async {
      const state = PagedListState<_TestRow>(
        query: ListQuery(page: 1, pageSize: 50),
        isLoading: true,
        data: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_shimmer',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EnterpriseTableShimmerSkeleton), findsOneWidget);
    });

    testWidgets('shows error view and triggers retry callback', (tester) async {
      bool retried = false;
      const state = PagedListState<_TestRow>(
        query: ListQuery(page: 1, pageSize: 50),
        isLoading: false,
        data: null,
        error: 'Failed to fetch items from backend',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_error',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
                onRefresh: () async => retried = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to fetch items from backend'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsWidgets);

      // Tap Retry button
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
    });

    testWidgets('shows progress bar on subsequent page load without clearing existing data', (tester) async {
      final items = [
        const _TestRow(id: 1, code: 'A-01', name: 'Alpha', amount: 100),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 2, pageSize: 50),
        isLoading: true,
        data: PageResult<_TestRow>(
          items: items,
          total: 100,
          page: 1,
          pageSize: 50,
          totalPages: 2,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_subsequent_load',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('A-01'), findsOneWidget);
    });

    testWidgets('search field input triggers onQueryChanged with updated search text and reset page', (tester) async {
      ListQuery? changedQuery;
      const state = PagedListState<_TestRow>(
        query: ListQuery(page: 2, pageSize: 50),
        data: PageResult<_TestRow>(
          items: [
            _TestRow(id: 1, code: 'A-01', name: 'Alpha', amount: 100),
          ],
          total: 1,
          page: 2,
          pageSize: 50,
          totalPages: 2,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_search',
                columns: createColumns(),
                state: state,
                onQueryChanged: (q) => changedQuery = q,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'TestSearch');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(changedQuery?.search, equals('TestSearch'));
      expect(changedQuery?.page, equals(1));
    });

    testWidgets('pagination footer page click calls onQueryChanged with next page', (tester) async {
      ListQuery? changedQuery;
      const state = PagedListState<_TestRow>(
        query: ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: [
            _TestRow(id: 1, code: 'A-01', name: 'Alpha', amount: 100),
          ],
          total: 100,
          page: 1,
          pageSize: 50,
          totalPages: 2,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_pagination',
                columns: createColumns(),
                state: state,
                onQueryChanged: (q) => changedQuery = q,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap next page button in footer
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(changedQuery?.page, equals(2));
    });

    testWidgets('keyboard Enter on focused row invokes onOpen', (tester) async {
      _TestRow? openedRow;
      final items = [
        const _TestRow(id: 1, code: 'ROW-1', name: 'Alpha', amount: 100),
        const _TestRow(id: 2, code: 'ROW-2', name: 'Beta', amount: 200),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 2,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_keyboard',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
                onOpen: (row) => openedRow = row,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus row 0 and press Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(openedRow?.id, equals(1));
    });

    testWidgets('renders row actions and executes action', (tester) async {
      _TestRow? viewedRow;
      final items = [
        const _TestRow(id: 10, code: 'ROW-10', name: 'Target', amount: 300),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 1,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_actions',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
                rowActions: (row) => [
                  RowAction<_TestRow>(
                    kind: RowActionKind.view,
                    run: (r) async => viewedRow = r,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the view action icon (visibility) and tap it
      final viewIconFinder = find.byIcon(Icons.visibility);
      expect(viewIconFinder, findsOneWidget);

      await tester.tap(viewIconFinder);
      await tester.pumpAndSettle();

      expect(viewedRow?.id, equals(10));
    });

    testWidgets('opens column picker dialog on button click', (tester) async {
      final items = [
        const _TestRow(id: 1, code: 'A-01', name: 'Alpha', amount: 100),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 1,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_picker',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap customize columns icon
      await tester.tap(find.byIcon(Icons.view_column_outlined));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Customize Columns'), findsOneWidget);
      expect(find.text('Reset to Defaults'), findsOneWidget);
    });

    testWidgets('Delete key shows confirm dialog when user has permission, and runs delete on confirm', (tester) async {
      _TestRow? deletedRow;
      final items = [
        const _TestRow(id: 1, code: 'ROW-1', name: 'Item 1', amount: 100),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 1,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPermissionsProvider.overrideWith((ref) async => const PermissionSet({'items.manage'})),
          ],
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_delete_permitted',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
                rowActions: (row) => [
                  RowAction<_TestRow>.delete(
                    permission: 'items.manage',
                    run: (r) async => deletedRow = r,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Row 0 is focused by default. Press Delete key
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(deletedRow, isNull);

      // Tap confirm button in dialog
      final confirmButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      );
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(deletedRow?.id, equals(1));
    });

    testWidgets('Delete key does nothing when user lacks permission', (tester) async {
      _TestRow? deletedRow;
      final items = [
        const _TestRow(id: 1, code: 'ROW-1', name: 'Item 1', amount: 100),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 1,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPermissionsProvider.overrideWith((ref) async => const PermissionSet({'items.view'})),
          ],
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_delete_unpermitted',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
                rowActions: (row) => [
                  RowAction<_TestRow>.delete(
                    permission: 'items.manage',
                    run: (r) async => deletedRow = r,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Press Delete key
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      // No confirm dialog and no delete executed
      expect(find.byType(AlertDialog), findsNothing);
      expect(deletedRow, isNull);
    });

    testWidgets('export button renders and invokes onExport with all items', (tester) async {
      List<_TestRow>? exportedItems;
      final items = [
        const _TestRow(id: 1, code: 'EXP-1', name: 'Export 1', amount: 10),
        const _TestRow(id: 2, code: 'EXP-2', name: 'Export 2', amount: 20),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 2,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_export',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
                exportStageName: 'Test Stage',
                onExport: (rows) async {
                  exportedItems = rows;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exportButton = find.byKey(const Key('paged_data_table_export_button'));
      expect(exportButton, findsOneWidget);

      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      // Tap CSV export item
      final csvItem = find.byKey(const Key('paged_data_table_export_csv_item'));
      expect(csvItem, findsOneWidget);
      await tester.tap(csvItem);
      await tester.pumpAndSettle();

      expect(exportedItems, isNotNull);
      expect(exportedItems!.length, equals(2));
      expect(exportedItems![0].code, equals('EXP-1'));
    });

    testWidgets('Ctrl+F focuses the search field', (tester) async {
      final items = [
        const _TestRow(id: 1, code: 'SEARCH-1', name: 'Searchable', amount: 10),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 50),
        data: PageResult<_TestRow>(
          items: items,
          total: 1,
          page: 1,
          pageSize: 50,
          totalPages: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_ctrl_f',
                columns: createColumns(),
                state: state,
                onQueryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Press Ctrl+F
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      final searchTextField = tester.widget<TextField>(find.byType(TextField));
      expect(searchTextField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('focus index is clamped on page change and Enter does not throw RangeError', (tester) async {
      _TestRow? openedRow;
      final page1Items = List.generate(
        10,
        (i) => _TestRow(id: i, code: 'P1-$i', name: 'Row $i', amount: 100),
      );
      final page2Items = [
        const _TestRow(id: 100, code: 'P2-0', name: 'Page 2 item 0', amount: 50),
        const _TestRow(id: 101, code: 'P2-1', name: 'Page 2 item 1', amount: 60),
      ];

      var currentState = PagedListState<_TestRow>(
        query: const ListQuery(page: 1, pageSize: 10),
        data: PageResult<_TestRow>(
          items: page1Items,
          total: 12,
          page: 1,
          pageSize: 10,
          totalPages: 2,
        ),
      );

      late StateSetter setStateCallback;

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: StatefulBuilder(
              builder: (context, setState) {
                setStateCallback = setState;
                return Scaffold(
                  body: PagedDataTable<_TestRow>(
                    storageKey: 'test_table_focus_clamp',
                    columns: createColumns(),
                    state: currentState,
                    onOpen: (row) => openedRow = row,
                    onQueryChanged: (_) {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Move focus down to index 8
      for (int i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }

      // Now switch state to page 2 (which only has 2 items: indices 0 and 1)
      setStateCallback(() {
        currentState = PagedListState<_TestRow>(
          query: const ListQuery(page: 2, pageSize: 10),
          data: PageResult<_TestRow>(
            items: page2Items,
            total: 12,
            page: 2,
            pageSize: 10,
            totalPages: 2,
          ),
        );
      });
      await tester.pumpAndSettle();

      // Press Enter. Must not throw RangeError and should target clamped index (item 1)
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(openedRow, isNotNull);
      expect(openedRow?.id, equals(101));
    });

    testWidgets('shows inline error banner and retry button when data and error are both set', (tester) async {
      bool retryCalled = false;
      final items = [
        const _TestRow(id: 1, code: 'ERR-1', name: 'Old Page Data', amount: 100),
      ];

      final state = PagedListState<_TestRow>(
        query: const ListQuery(page: 2, pageSize: 10),
        data: PageResult<_TestRow>(
          items: items,
          total: 10,
          page: 1,
          pageSize: 10,
          totalPages: 1,
        ),
        error: 'Failed to fetch page 2',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            locale: AppLocales.english,
            home: Scaffold(
              body: PagedDataTable<_TestRow>(
                storageKey: 'test_table_inline_error',
                columns: createColumns(),
                state: state,
                onRefresh: () => retryCalled = true,
                onQueryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Old rows are still displayed
      expect(find.text('ERR-1'), findsOneWidget);

      // Inline error banner is visible
      expect(find.byKey(const Key('paged_data_table_inline_error_banner')), findsOneWidget);
      expect(find.text('Failed to fetch page 2'), findsOneWidget);

      // Tap Retry button
      final retryBtn = find.byKey(const Key('paged_data_table_inline_retry_button'));
      expect(retryBtn, findsOneWidget);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });
  });
}
