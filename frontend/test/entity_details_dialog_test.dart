import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/entity_details/details_section.dart';
import 'package:frontend/core/widgets/entity_details/entity_details_dialog.dart';
import 'package:frontend/core/widgets/entity_details/entity_ref.dart';
import 'package:frontend/core/widgets/paged_data_table/row_action.dart';
import 'package:frontend/features/auth/providers/current_permissions_provider.dart';
import 'helpers/localized_app.dart';

class _FakeSupplier {
  final int id;
  final String code;
  final String name;
  final String? taxId;

  const _FakeSupplier({
    required this.id,
    required this.code,
    required this.name,
    this.taxId,
  });
}

Widget _wrapTestWidget({
  required Widget child,
  Locale locale = AppLocales.arabic,
  List<Override> overrides = const [],
  Size? screenSize,
}) {
  return ProviderScope(
    overrides: overrides,
    child: localizedApp(
      locale: locale,
      home: screenSize != null
          ? MediaQuery(
              data: MediaQueryData(size: screenSize),
              child: Scaffold(body: child),
            )
          : Scaffold(body: child),
    ),
  );
}

void main() {
  tearDown(() {
    EntityDetailsRegistry.clear();
  });

  group('DetailsSection & DetailsField', () {
    testWidgets('DetailsField renders "—" when value is null or empty', (tester) async {
      await tester.pumpWidget(
        _wrapTestWidget(
          child: const DetailsSection(
            title: 'معلومات المورد',
            children: [
              DetailsField(label: 'الرقم الضريبي', value: null),
              DetailsField(label: 'ملاحظات', value: '   '),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('معلومات المورد'), findsOneWidget);
      expect(find.text('الرقم الضريبي'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('DetailsField renders value, LTR text and copy button when value present', (tester) async {
      await tester.pumpWidget(
        _wrapTestWidget(
          child: const DetailsSection(
            title: 'معلومات عامة',
            children: [
              DetailsField(
                label: 'كود المورد',
                value: 'SUP-2026-001',
                ltr: true,
                copyable: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SUP-2026-001'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });
  });

  group('EntityDetailsRegistry & EntityDetailsDialog Integration', () {
    testWidgets('A test body registered for EntityType.supplier opens from EntityDetailsRegistry.open with loading then data', (tester) async {
      final supplierStateProvider = StateProvider<AsyncValue<_FakeSupplier>>((ref) {
        return const AsyncLoading();
      });

      EntityDetailsRegistry.register(EntityType.supplier, (context, id) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(supplierStateProvider);
            return EntityDetailsDialog<_FakeSupplier>(
              title: 'مورد #$id',
              value: state,
              body: (supplier) => DetailsSection(
                title: 'بيانات المورد',
                children: [
                  DetailsField(label: 'الكود', value: supplier.code, ltr: true),
                  DetailsField(label: 'الاسم', value: supplier.name),
                  DetailsField(label: 'الرقم الضريبي', value: supplier.taxId),
                ],
              ),
            );
          },
        );
      });

      late BuildContext rootContext;

      await tester.pumpWidget(
        _wrapTestWidget(
          child: Builder(
            builder: (ctx) {
              rootContext = ctx;
              return ElevatedButton(
                onPressed: () {
                  EntityDetailsRegistry.open(ctx, const EntityRef(type: EntityType.supplier, id: 42));
                },
                child: const Text('Open Supplier'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap button to open from registry
      await tester.tap(find.text('Open Supplier'));
      await tester.pump();

      // 1. Loading state with shimmer
      expect(find.byType(EntityDetailsShimmerSkeleton), findsOneWidget);

      // 2. Transition state to data
      final container = ProviderScope.containerOf(rootContext);
      container.read(supplierStateProvider.notifier).state = const AsyncData(
        _FakeSupplier(
          id: 42,
          code: 'SUP-EG-42',
          name: 'شركة النيل للتجارة',
          taxId: '123-456-789',
        ),
      );

      await tester.pumpAndSettle();

      // Shimmer is gone, supplier data is rendered
      expect(find.byType(EntityDetailsShimmerSkeleton), findsNothing);
      expect(find.text('مورد #42'), findsOneWidget);
      expect(find.text('بيانات المورد'), findsOneWidget);
      expect(find.text('SUP-EG-42'), findsOneWidget);
      expect(find.text('شركة النيل للتجارة'), findsOneWidget);
      expect(find.text('123-456-789'), findsOneWidget);
    });

    testWidgets('404 error shows the l10n "not found" text, not a raw exception', (tester) async {
      final dio404 = DioException(
        requestOptions: RequestOptions(path: '/api/v1/suppliers/999'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/suppliers/999'),
          statusCode: 404,
          data: {'detail': 'Supplier not found'},
        ),
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          child: EntityDetailsDialog<_FakeSupplier>(
            title: 'تفاصيل المورد',
            value: AsyncError(dio404, StackTrace.empty),
            body: (supplier) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Arabic 404 text
      expect(find.text('السجل غير موجود أو تم حذفه'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      // Raw exception text should NOT appear
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('Supplier not found'), findsNothing);
    });

    testWidgets('English 404 error shows English "Record not found or deleted"', (tester) async {
      final notFoundException = Exception('404 not found');

      await tester.pumpWidget(
        _wrapTestWidget(
          locale: AppLocales.english,
          child: EntityDetailsDialog<_FakeSupplier>(
            title: 'Supplier Details',
            value: AsyncError(notFoundException, StackTrace.empty),
            body: (supplier) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Record not found or deleted'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('Non-404 error shows ApiError.message and Retry calls onRetry', (tester) async {
      int retryCount = 0;
      final serverError = DioException(
        requestOptions: RequestOptions(path: '/api/v1/suppliers/1'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/suppliers/1'),
          statusCode: 500,
          data: {'detail': 'Internal database failure'},
        ),
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          child: EntityDetailsDialog<_FakeSupplier>(
            title: 'تفاصيل المورد',
            value: AsyncError(serverError, StackTrace.empty),
            onRetry: () => retryCount++,
            body: (supplier) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Internal database failure'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();

      expect(retryCount, 1);
    });

    testWidgets('Edit action is hidden without permission', (tester) async {
      const supplier = _FakeSupplier(
        id: 1,
        code: 'SUP-001',
        name: 'المورد الأول',
      );

      final editAction = RowAction<_FakeSupplier>.edit(
        permission: 'suppliers.manage',
        run: (_) {},
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            currentPermissionsProvider.overrideWith(
              (ref) async => const PermissionSet({'suppliers.view'}),
            ),
          ],
          child: EntityDetailsDialog<_FakeSupplier>(
            title: 'تفاصيل المورد',
            value: const AsyncData(supplier),
            footerActions: [editAction],
            body: (s) => Text('Body: ${s.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('Edit action is visible with permission and clickable', (tester) async {
      const supplier = _FakeSupplier(
        id: 1,
        code: 'SUP-001',
        name: 'المورد الأول',
      );

      int editClicked = 0;
      final editAction = RowAction<_FakeSupplier>.edit(
        permission: 'suppliers.manage',
        run: (_) => editClicked++,
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            currentPermissionsProvider.overrideWith(
              (ref) async => const PermissionSet({'suppliers.manage'}),
            ),
          ],
          child: EntityDetailsDialog<_FakeSupplier>(
            title: 'تفاصيل المورد',
            value: const AsyncData(supplier),
            footerActions: [editAction],
            body: (s) => Text('Body: ${s.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      expect(editClicked, 1);
    });

    testWidgets('Edit button built with RowAction.edit() resolves to solid orange, not orangeLight', (tester) async {
      const supplier = _FakeSupplier(
        id: 1,
        code: 'SUP-001',
        name: 'المورد الأول',
      );

      final editAction = RowAction<_FakeSupplier>.edit(
        permission: 'suppliers.manage',
        run: (_) {},
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            currentPermissionsProvider.overrideWith(
              (ref) async => const PermissionSet({'suppliers.manage'}),
            ),
          ],
          child: EntityDetailsDialog<_FakeSupplier>(
            title: 'تفاصيل المورد',
            value: const AsyncData(supplier),
            footerActions: [editAction],
            body: (s) => Text('Body: ${s.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = filledButton.style?.backgroundColor?.resolve({});
      expect(bg, isNot(equals(AppTheme.orangeLight)));
      expect(bg, equals(AppTheme.orange));
    });

    testWidgets('Footer action shows SnackBar with ApiError.message when run() throws DioException', (tester) async {
      const supplier = _FakeSupplier(
        id: 1,
        code: 'SUP-001',
        name: 'المورد الأول',
      );

      final deleteAction = RowAction<_FakeSupplier>.delete(
        permission: 'suppliers.manage',
        confirm: false,
        run: (_) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/api/v1/suppliers/1'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/v1/suppliers/1'),
              statusCode: 409,
              data: {'detail': 'Record is locked and cannot be deleted'},
            ),
          );
        },
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            currentPermissionsProvider.overrideWith(
              (ref) async => const PermissionSet({'suppliers.manage'}),
            ),
          ],
          child: EntityDetailsDialog<_FakeSupplier>(
            title: 'تفاصيل المورد',
            value: const AsyncData(supplier),
            footerActions: [deleteAction],
            body: (s) => Text('Body: ${s.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Record is locked and cannot be deleted'), findsOneWidget);
    });

    testWidgets('Destructive footer action shows deletedSuccessfully SnackBar on success', (tester) async {
      const supplier = _FakeSupplier(
        id: 1,
        code: 'SUP-001',
        name: 'المورد الأول',
      );

      final deleteAction = RowAction<_FakeSupplier>.delete(
        permission: 'suppliers.manage',
        confirm: false,
        run: (_) async {},
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            currentPermissionsProvider.overrideWith(
              (ref) async => const PermissionSet({'suppliers.manage'}),
            ),
          ],
          child: EntityDetailsDialog<_FakeSupplier>(
            title: 'تفاصيل المورد',
            value: const AsyncData(supplier),
            footerActions: [deleteAction],
            body: (s) => Text('Body: ${s.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('تم الحذف بنجاح'), findsOneWidget);
    });

    testWidgets('RTL: the sheet opens from the right on wide desktop screens (width >= 1200)', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapTestWidget(
          locale: AppLocales.arabic,
          child: const EntityDetailsDialog<String>(
            title: 'عرض جانبي',
            value: AsyncData('اختبار المحاذاة'),
            body: Text.new,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final align = dialog.child as Align;
      expect(align.alignment, AlignmentDirectional.centerStart);

      // In RTL, AlignmentDirectional.centerStart resolves to Alignment.centerRight
      final resolved = align.alignment.resolve(TextDirection.rtl);
      expect(resolved, Alignment.centerRight);

      // Verify screen coordinates: right edge at 1400, width 560
      final sheetFinder = find.byWidgetPredicate((w) => w is SizedBox && w.width == 560.0);
      expect(sheetFinder, findsOneWidget);
      final rect = tester.getRect(sheetFinder);
      expect(rect.width, equals(560.0));
      expect(rect.right, equals(1400.0));
      expect(rect.left, equals(1400.0 - 560.0));
    });

    testWidgets('LTR: the sheet opens from the left on wide desktop screens (width >= 1200)', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapTestWidget(
          locale: AppLocales.english,
          child: const EntityDetailsDialog<String>(
            title: 'Side Sheet',
            value: AsyncData('Alignment Test'),
            body: Text.new,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final align = dialog.child as Align;
      expect(align.alignment, AlignmentDirectional.centerStart);

      // In LTR, AlignmentDirectional.centerStart resolves to Alignment.centerLeft
      final resolved = align.alignment.resolve(TextDirection.ltr);
      expect(resolved, Alignment.centerLeft);

      final sheetFinder = find.byWidgetPredicate((w) => w is SizedBox && w.width == 560.0);
      expect(sheetFinder, findsOneWidget);
      final rect = tester.getRect(sheetFinder);
      expect(rect.width, equals(560.0));
      expect(rect.left, equals(0.0));
    });

    testWidgets('Centered dialog on narrow screens (< 1200)', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapTestWidget(
          locale: AppLocales.arabic,
          child: const EntityDetailsDialog<String>(
            title: 'نافذة منبثقة وسطية',
            value: AsyncData('شاشة صغيرة'),
            body: Text.new,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final align = dialog.child as Align;
      expect(align.alignment, AlignmentDirectional.center);
    });
  });
}
