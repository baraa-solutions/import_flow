import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/widgets/paged_data_table/row_action.dart';
import 'package:frontend/core/widgets/row_actions_pill.dart';
import 'package:frontend/core/widgets/row_context_menu.dart';
import 'package:frontend/features/auth/providers/current_permissions_provider.dart';
import 'helpers/localized_app.dart';

Widget _buildTestApp({
  required Widget child,
  PermissionSet permissions = const PermissionSet({'*'}),
}) {
  return ProviderScope(
    overrides: [
      currentPermissionsProvider.overrideWith((ref) async => permissions),
    ],
    child: localizedApp(
      locale: AppLocales.english,
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  group('RowActionsBar tests', () {
    testWidgets('renders standard actions in canonical order', (tester) async {
      final executed = <String>[];

      final actions = [
        RowAction<String>.delete(run: (s) => executed.add('delete')),
        RowAction<String>.view(run: (s) => executed.add('view')),
        RowAction<String>.edit(run: (s) => executed.add('edit')),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: RowActionsBar<String>(
            row: 'row-1',
            actions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Icons should exist
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Verify layout order: View is to the left of Edit, Edit is to the left of Delete
      final viewPos = tester.getTopLeft(find.byIcon(Icons.visibility));
      final editPos = tester.getTopLeft(find.byIcon(Icons.edit));
      final deletePos = tester.getTopLeft(find.byIcon(Icons.delete_outline));

      expect(viewPos.dx, lessThan(editPos.dx));
      expect(editPos.dx, lessThan(deletePos.dx));
    });

    testWidgets('hides actions where user lacks required permission', (tester) async {
      final actions = [
        RowAction<String>.view(
          permission: 'orders.view',
          run: (s) {},
        ),
        RowAction<String>.edit(
          permission: 'orders.manage',
          run: (s) {},
        ),
      ];

      // User only has orders.view
      await tester.pumpWidget(
        _buildTestApp(
          permissions: const PermissionSet({'orders.view'}),
          child: RowActionsBar<String>(
            row: 'row-1',
            actions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('displays disabledReason tooltip when action is disabled', (tester) async {
      final actions = [
        RowAction<String>.edit(
          disabledReason: 'File is locked for editing',
          run: (s) {},
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: RowActionsBar<String>(
            row: 'row-1',
            actions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tooltipFinder = find.byType(Tooltip);
      expect(tooltipFinder, findsOneWidget);

      final tooltipWidget = tester.widget<Tooltip>(tooltipFinder);
      expect(tooltipWidget.message, 'File is locked for editing');
    });

    testWidgets('delete shows confirm dialog and runs only upon confirmation', (tester) async {
      bool deleted = false;

      final actions = [
        RowAction<String>.delete(
          confirm: true,
          run: (s) => deleted = true,
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: RowActionsBar<String>(
            row: 'REC-001',
            actions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confirm Deletion'), findsOneWidget);

      // Cancel first
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleted, isFalse);
      expect(find.byType(AlertDialog), findsNothing);

      // Tap delete again and confirm
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(find.text('Deleted successfully'), findsOneWidget);
    });

    testWidgets('error in run displays red SnackBar with backend error message', (tester) async {
      final actions = [
        RowAction<String>.edit(
          run: (s) {
            throw DioException(
              requestOptions: RequestOptions(path: '/api/v1/resource'),
              response: Response(
                requestOptions: RequestOptions(path: '/api/v1/resource'),
                statusCode: 400,
                data: {'detail': 'Custom backend error: Invalid state transition'},
              ),
            );
          },
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: RowActionsBar<String>(
            row: 'row-1',
            actions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text('Custom backend error: Invalid state transition'), findsOneWidget);
    });

    testWidgets('renders custom actions inside more overflow popup menu', (tester) async {
      bool customRun = false;

      final actions = [
        RowAction<String>.view(run: (s) {}),
        RowAction<String>.custom(
          icon: Icons.star,
          label: (l) => 'Favorite',
          run: (s) => customRun = true,
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: RowActionsBar<String>(
            row: 'row-1',
            actions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Favorite'), findsOneWidget);
      await tester.tap(find.text('Favorite'));
      await tester.pumpAndSettle();

      expect(customRun, isTrue);
    });
  });

  group('RowActionsPill adapter tests', () {
    testWidgets('null actions are completely hidden (no gray eye icon)', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const RowActionsPill(
            onView: null, // Should NOT display view button
            onEdit: null,
            onClone: null,
            onPrint: null,
            onDelete: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No buttons rendered
      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.print), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('displays only non-null actions and executes them', (tester) async {
      bool editTapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          child: RowActionsPill(
            onView: null,
            onEdit: () => editTapped = true,
            onClone: null,
            onPrint: null,
            onDelete: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.edit), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(editTapped, isTrue);
    });
  });

  group('RowContextMenuHelper tests', () {
    testWidgets('shows context menu in canonical order and executes action with confirm', (tester) async {
      bool deleted = false;

      final actions = [
        RowAction<String>.delete(
          confirm: true,
          run: (s) => deleted = true,
        ),
        RowAction<String>.view(
          run: (s) {},
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                RowContextMenuHelper.showActionsMenu<String>(
                  context: ctx,
                  globalPosition: const Offset(100, 100),
                  row: 'item-1',
                  actions: actions,
                  codeToCopy: 'CODE-999',
                );
              },
              child: const Text('Open Menu'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open context menu
      await tester.tap(find.text('Open Menu'));
      await tester.pumpAndSettle();

      // Canonical order: View must be present, Delete must be present, Copy Code present
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('Copy Code'), findsOneWidget);

      // Tap Delete action
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirm dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confirm Deletion'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(find.text('Deleted successfully'), findsOneWidget);
    });

    testWidgets('filters actions by permission in context menu', (tester) async {
      final actions = [
        RowAction<String>.view(
          permission: 'orders.view',
          run: (s) {},
        ),
        RowAction<String>.edit(
          permission: 'orders.manage',
          run: (s) {},
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                RowContextMenuHelper.showActionsMenu<String>(
                  context: ctx,
                  globalPosition: const Offset(100, 100),
                  row: 'item-1',
                  actions: actions,
                  permissions: const PermissionSet({'orders.view'}),
                );
              },
              child: const Text('Open Filtered Menu'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Filtered Menu'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNothing);
    });
  });
}
