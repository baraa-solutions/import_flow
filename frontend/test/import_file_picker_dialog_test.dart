import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/widgets/buttons/app_button.dart';
import 'package:frontend/core/widgets/import_file_picker_dialog.dart';
import 'package:frontend/core/widgets/searchable_dropdown_field.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

import 'helpers/localized_app.dart';

class _FakeImportFilesNotifier extends ImportFilesNotifier {
  final VoidCallback? onFetch;

  _FakeImportFilesNotifier(List<ImportFileModel> files)
      : onFetch = null,
        super(Dio()) {
    state = AsyncValue.data(files);
  }

  _FakeImportFilesNotifier.error(Object err, {this.onFetch}) : super(Dio()) {
    state = AsyncValue.error(err, StackTrace.empty);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {
    onFetch?.call();
  }
}

ImportFileModel _createFakeFile({
  required int id,
  required String code,
  String? customNumber,
  String supplier = 'Global Chem',
  String company = 'Sorour Trading',
  bool isActive = true,
  String status = 'Active',
}) {
  return ImportFileModel(
    importFileId: id,
    importFileCode: code,
    customFileNumber: customNumber,
    companyName: company,
    supplierName: supplier,
    currentModule: 'Customs',
    currentStage: 'Stage 1',
    nextAction: 'Action 1',
    status: status,
    isActive: isActive,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );
}

Widget _wrapTestWidget({
  required Widget child,
  Locale locale = AppLocales.arabic,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: localizedApp(
      locale: locale,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  final file1 = _createFakeFile(
    id: 101,
    code: 'IMP-2026-0001',
    customNumber: 'PET Stock',
    supplier: 'Global Chem',
    isActive: true,
    status: 'In Progress',
  );
  final file2 = _createFakeFile(
    id: 102,
    code: 'IMP-2026-0002',
    customNumber: null,
    supplier: 'Alpha Corp',
    isActive: true,
    status: 'Draft',
  );
  final file3Closed = _createFakeFile(
    id: 103,
    code: 'IMP-2026-0003',
    customNumber: 'Old Cargo',
    supplier: 'Legacy Ltd',
    isActive: false,
    status: 'Closed',
  );
  final file4Archived = _createFakeFile(
    id: 104,
    code: 'IMP-2026-0004',
    customNumber: 'Archived Cargo',
    supplier: 'Archive Supplier',
    isActive: true,
    status: 'Archived',
  );

  group('ImportFilePickerDialog & showImportFilePickerDialog Tests', () {
    testWidgets('pumping with 4 fake files (one closed, one archived): default shows 2 active items', (tester) async {
      final fakeNotifier = _FakeImportFilesNotifier([file1, file2, file3Closed, file4Archived]);

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'اختيار ملف العملية',
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Title is rendered
      expect(find.text('اختيار ملف العملية'), findsOneWidget);

      // Verify SearchableDropdownField is present
      final dropdownFinder = find.byType(SearchableDropdownField<int>);
      expect(dropdownFinder, findsOneWidget);

      final dropdownWidget = tester.widget<SearchableDropdownField<int>>(dropdownFinder);
      // Default should have only 2 active items (file1 and file2), excluding closed file3 and archived file4
      expect(dropdownWidget.items.length, 2);
      expect(dropdownWidget.items.any((item) => item.value == 101), isTrue);
      expect(dropdownWidget.items.any((item) => item.value == 102), isTrue);
      expect(dropdownWidget.items.any((item) => item.value == 103), isFalse);
      expect(dropdownWidget.items.any((item) => item.value == 104), isFalse);

      // Verify label formatting: primaryNameWithCode — supplier
      final item1 = dropdownWidget.items.firstWhere((item) => item.value == 101);
      expect(item1.label, 'PET Stock (IMP-2026-0001) — Global Chem');

      final item2 = dropdownWidget.items.firstWhere((item) => item.value == 102);
      expect(item2.label, 'IMP-2026-0002 — Alpha Corp');
    });

    testWidgets('Continue button is disabled until a file is chosen, then returns picked file', (tester) async {
      ImportFileModel? pickedResult;
      final fakeNotifier = _FakeImportFilesNotifier([file1, file2, file3Closed]);

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  pickedResult = await showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'اختيار ملف الاستيراد',
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Find Continue AppButton (in Arabic: 'متابعة')
      final continueBtnFinder = find.widgetWithText(AppButton, 'متابعة');
      expect(continueBtnFinder, findsOneWidget);

      final continueBtn = tester.widget<AppButton>(continueBtnFinder);
      // Disabled initially because _selectedFileId is null
      expect(continueBtn.onPressed, isNull);

      // Open the dropdown dialog by tapping SearchableDropdownField
      await tester.tap(find.byType(SearchableDropdownField<int>));
      await tester.pumpAndSettle();

      // Tap the first item inside the dropdown dialog
      await tester.tap(find.text('PET Stock (IMP-2026-0001) — Global Chem'));
      await tester.pumpAndSettle();

      // Now Continue button must be enabled
      final updatedContinueBtn = tester.widget<AppButton>(continueBtnFinder);
      expect(updatedContinueBtn.onPressed, isNotNull);

      // Tap Continue
      await tester.tap(continueBtnFinder);
      await tester.pumpAndSettle();

      // Dialog is closed and returns picked file1
      expect(find.byType(ImportFilePickerDialog), findsNothing);
      expect(pickedResult, isNotNull);
      expect(pickedResult?.importFileId, 101);
      expect(pickedResult?.importFileCode, 'IMP-2026-0001');
    });

    testWidgets('Cancel button pops dialog and returns null without side effects', (tester) async {
      ImportFileModel? pickedResult = file1; // start non-null to verify it sets null
      final fakeNotifier = _FakeImportFilesNotifier([file1, file2]);

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  pickedResult = await showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'اختيار ملف',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Cancel button (in Arabic: 'إلغاء')
      await tester.tap(find.widgetWithText(AppButton, 'إلغاء'));
      await tester.pumpAndSettle();

      expect(find.byType(ImportFilePickerDialog), findsNothing);
      expect(pickedResult, isNull);
    });

    testWidgets('Close icon button pops dialog and returns null', (tester) async {
      ImportFileModel? pickedResult = file1;
      final fakeNotifier = _FakeImportFilesNotifier([file1, file2]);

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  pickedResult = await showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'اختيار ملف',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Close icon button (Icons.close_rounded)
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(ImportFilePickerDialog), findsNothing);
      expect(pickedResult, isNull);
    });

    testWidgets('where filter custom predicate applies properly', (tester) async {
      final fakeNotifier = _FakeImportFilesNotifier([file1, file2, file3Closed]);

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'فلترة خاصة',
                    // Only file with code IMP-2026-0002
                    where: (f) => f.importFileCode == 'IMP-2026-0002',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dropdownWidget = tester.widget<SearchableDropdownField<int>>(
        find.byType(SearchableDropdownField<int>),
      );
      expect(dropdownWidget.items.length, 1);
      expect(dropdownWidget.items.single.value, 102);
    });

    testWidgets('excludeId removes the specified file from candidate items', (tester) async {
      final fakeNotifier = _FakeImportFilesNotifier([file1, file2, file3Closed]);

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'استبعاد ملف محدد',
                    excludeId: 101,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dropdownWidget = tester.widget<SearchableDropdownField<int>>(
        find.byType(SearchableDropdownField<int>),
      );
      // 101 excluded, 103 closed -> only 102 remains
      expect(dropdownWidget.items.length, 1);
      expect(dropdownWidget.items.single.value, 102);
    });

    testWidgets('Empty filtered items: displays info text and hides Continue button', (tester) async {
      // All files closed, default filter active
      final fakeNotifier = _FakeImportFilesNotifier([file3Closed]);

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'قائمة فارغة',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Info message is displayed
      expect(find.text('لا توجد ملفات استيراد متاحة'), findsOneWidget);

      // SearchableDropdownField is NOT present
      expect(find.byType(SearchableDropdownField<int>), findsNothing);

      // Continue button is hidden
      expect(find.widgetWithText(AppButton, 'متابعة'), findsNothing);

      // Cancel button is still present
      expect(find.widgetWithText(AppButton, 'إلغاء'), findsOneWidget);
    });

    testWidgets('English (LTR) localization renders English labels', (tester) async {
      final fakeNotifier = _FakeImportFilesNotifier([file1]);

      await tester.pumpWidget(
        _wrapTestWidget(
          locale: AppLocales.english,
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'Select Shipment File',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Select Shipment File'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Continue'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('Error state shows error message and retry button triggers fetchImportFiles', (tester) async {
      bool fetchTriggered = false;
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/import-files'),
        response: Response(
          requestOptions: RequestOptions(path: '/import-files'),
          data: {'detail': 'فشل الاتصال بالخادم'},
          statusCode: 500,
        ),
      );
      final fakeNotifier = _FakeImportFilesNotifier.error(
        dioException,
        onFetch: () => fetchTriggered = true,
      );

      await tester.pumpWidget(
        _wrapTestWidget(
          overrides: [
            importFilesProvider.overrideWith((ref) => fakeNotifier),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () {
                  showImportFilePickerDialog(
                    context,
                    ref,
                    title: 'اختبار الخطأ',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Error message is displayed
      expect(find.text('فشل الاتصال بالخادم'), findsOneWidget);

      // Retry button is displayed (in Arabic: 'إعادة المحاولة')
      final retryBtnFinder = find.widgetWithText(AppButton, 'إعادة المحاولة');
      expect(retryBtnFinder, findsOneWidget);

      // Tap retry
      await tester.tap(retryBtnFinder);
      await tester.pump();

      expect(fetchTriggered, isTrue);
    });
  });
}
