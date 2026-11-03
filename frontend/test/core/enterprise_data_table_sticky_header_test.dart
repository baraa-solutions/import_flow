import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/widgets/enterprise_data_table/enterprise_data_table.dart';

class _Row {
  final int id;
  final String name;
  final int score;

  const _Row(this.id, this.name, this.score);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final rows = List.generate(40, (i) => _Row(i + 1, 'Item ${i + 1}', (i * 37) % 100));

  List<EnterpriseColumn<_Row>> columns({bool allFixed = true}) => [
        EnterpriseColumn<_Row>(
          id: 'id',
          title: 'ID',
          width: 90,
          sortComparator: (a, b) => a.id.compareTo(b.id),
          cellBuilder: (context, r, i) => Text('#${r.id}'),
        ),
        EnterpriseColumn<_Row>(
          id: 'name',
          title: 'Name',
          width: allFixed ? 220 : null,
          cellBuilder: (context, r, i) => Text(r.name),
        ),
        EnterpriseColumn<_Row>(
          id: 'score',
          title: 'Score',
          width: 120,
          sortComparator: (a, b) => a.score.compareTo(b.score),
          cellBuilder: (context, r, i) => Text('s${r.score}'),
        ),
      ];

  Widget app({
    bool sticky = true,
    bool allFixed = true,
    bool scrollbarOnLeft = false,
    TextDirection direction = TextDirection.ltr,
    bool enableSelection = false,
    ValueChanged<Set<_Row>>? onSelectionChanged,
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 500,
            child: EnterpriseDataTable<_Row>(
              data: rows,
              columns: columns(allFixed: allFixed),
              isScrollable: true,
              showHeaderToolbar: false,
              showPagination: false,
              initialPageSize: 100,
              headerHeight: 46,
              enableSelection: enableSelection,
              onSelectionChanged: onSelectionChanged,
              stickyHeader: sticky,
              verticalScrollbarOnLeft: scrollbarOnLeft,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1000, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
  }

  Finder headerCell(String id) => find.byKey(ValueKey('enterprise_table_header_$id'));

  void expectColumnsAligned(WidgetTester tester) {
    // The first row's cells must start and end exactly under their header cells.
    for (final pair in const [('id', '#1'), ('name', 'Item 1'), ('score', 's37')]) {
      final header = tester.getRect(find.ancestor(of: headerCell(pair.$1), matching: find.byType(SizedBox)).first);
      final cell = tester.getRect(find.ancestor(of: find.text(pair.$2), matching: find.byType(SizedBox)).first);
      expect(cell.left, closeTo(header.left, 0.01), reason: 'column ${pair.$1} start');
      expect(cell.right, closeTo(header.right, 0.01), reason: 'column ${pair.$1} end');
    }
  }

  testWidgets('default (off) keeps the single-DataTable layout', (tester) async {
    await pump(tester, app(sticky: false));
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('sticky mode: header-only table above a 0-height-heading body table', (tester) async {
    await pump(tester, app());
    final tables = find.byType(DataTable);
    expect(tables, findsNWidgets(2));
    final header = tester.widget<DataTable>(tables.first);
    final body = tester.widget<DataTable>(tables.last);
    expect(header.rows, isEmpty);
    expect(header.headingRowHeight, 46);
    expect(body.headingRowHeight, 0);
    expect(body.rows.length, rows.length);
    expect(header.columns.length, body.columns.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header stays put while the body scrolls vertically', (tester) async {
    await pump(tester, app());
    final headerTop = tester.getTopLeft(find.byType(DataTable).first).dy;
    final firstRowTop = tester.getTopLeft(find.text('Item 1')).dy;

    await tester.drag(find.text('Item 3'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(DataTable).first).dy, headerTop);
    expect(tester.getTopLeft(headerCell('name')).dy, greaterThanOrEqualTo(headerTop));
    // The rows did move.
    expect(find.text('Item 1').hitTestable(), findsNothing);
    expect(firstRowTop, greaterThan(headerTop));
  });

  testWidgets('columns line up with the header in LTR', (tester) async {
    await pump(tester, app());
    expectColumnsAligned(tester);
  });

  testWidgets('columns line up with the header in RTL', (tester) async {
    await pump(tester, app(direction: TextDirection.rtl));
    expectColumnsAligned(tester);
    // RTL really mirrored the table: the first column is on the right.
    expect(tester.getCenter(headerCell('id')).dx, greaterThan(tester.getCenter(headerCell('score')).dx));
  });

  testWidgets('columns stay aligned after a column is resized', (tester) async {
    await pump(tester, app());
    final handle = find.descendant(
      of: find.ancestor(of: headerCell('id'), matching: find.byType(Row)).first,
      matching: find.byType(GestureDetector),
    );
    await tester.drag(handle.last, const Offset(60, 0));
    await tester.pumpAndSettle();
    expectColumnsAligned(tester);
  });

  testWidgets('vertical scrollbar side: ambient by default, left when verticalScrollbarOnLeft', (tester) async {
    Directionality scrollbarSide() => tester.widget<Directionality>(
          find.ancestor(of: find.byType(Scrollbar).last, matching: find.byType(Directionality)).first,
        );
    Directionality rowsDirection() => tester.widget<Directionality>(
          find.descendant(of: find.byType(Scrollbar).last, matching: find.byType(Directionality)).first,
        );

    await pump(tester, app());
    expect(scrollbarSide().textDirection, TextDirection.ltr);

    await pump(tester, app(scrollbarOnLeft: true));
    expect(scrollbarSide().textDirection, TextDirection.rtl, reason: 'scrollbar flipped to the left');
    expect(rowsDirection().textDirection, TextDirection.ltr, reason: 'rows keep the ambient direction');

    await pump(tester, app(scrollbarOnLeft: true, direction: TextDirection.rtl));
    expect(scrollbarSide().textDirection, TextDirection.rtl);
    expect(rowsDirection().textDirection, TextDirection.rtl);
  });

  testWidgets('sorting from the pinned header reorders the body rows', (tester) async {
    await pump(tester, app());
    await tester.tap(headerCell('score'));
    await tester.pumpAndSettle();
    // Lowest score first: item 1 has score 0.
    final body = tester.widget<DataTable>(find.byType(DataTable).last);
    final firstCell = body.rows.first.cells.first.child;
    expect(find.descendant(of: find.byWidget(firstCell), matching: find.text('#1')), findsOneWidget);

    await tester.tap(headerCell('score'));
    await tester.pumpAndSettle();
    final desc = tester.widget<DataTable>(find.byType(DataTable).last);
    expect(find.descendant(of: find.byWidget(desc.rows.first.cells.first.child), matching: find.text('#1')),
        findsNothing);
  });

  testWidgets('selection: header select-all and row checkboxes still work', (tester) async {
    Set<_Row>? selected;
    await pump(tester, app(enableSelection: true, onSelectionChanged: (s) => selected = s));

    final headerCheckbox = find.descendant(of: find.byType(DataTable).first, matching: find.byType(Checkbox));
    expect(headerCheckbox, findsOneWidget);
    await tester.tap(headerCheckbox);
    await tester.pumpAndSettle();
    expect(selected?.length, rows.length);

    final rowCheckbox = find.descendant(of: find.byType(DataTable).last, matching: find.byType(Checkbox)).first;
    await tester.tap(rowCheckbox);
    await tester.pumpAndSettle();
    expect(selected?.length, rows.length - 1);
  });

  testWidgets('falls back to the normal layout when a column has no fixed width', (tester) async {
    await pump(tester, app(allFixed: false));
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
