import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/import_file_picker_dialog.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _TestImportFilesNotifier extends ImportFilesNotifier {
  _TestImportFilesNotifier(List<ImportFileModel> files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  @override
  Future<void> fetchImportFiles({
    bool includeInactive = false,
    String? search,
    int? companyId,
    int? supplierId,
    String? status,
    String? owner,
  }) async {}
}

ImportFileModel _makeFile({
  required int id,
  required String code,
  required String supplier,
  String status = 'Open',
}) {
  return ImportFileModel(
    importFileId: id,
    importFileCode: code,
    companyName: 'Test Corp',
    supplierName: supplier,
    shipmentMode: 'SEA',
    incotermCode: 'FOB',
    priority: 'Normal',
    shipmentCategory: 'Commercial',
    currentModule: 'Customs Clearance',
    currentStage: 'Phase 7 - Customs Clearance',
    nextAction: 'Sample Inspection',
    status: status,
    createdAt: '2026-01-01',
    updatedAt: '2026-01-01',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final file1 = _makeFile(id: 101, code: 'IMP-2026-0001', supplier: 'Supplier A', status: 'Open');
  final file2 = _makeFile(id: 102, code: 'IMP-2026-0002', supplier: 'Supplier B', status: 'Customs Clearance');
  final fileClosed = _makeFile(id: 103, code: 'IMP-2026-0003', supplier: 'Supplier C', status: 'Closed');

  Widget buildTestHost({
    required List<ImportFileModel> files,
    required Future<void> Function(BuildContext context, WidgetRef ref) onOpen,
    Locale locale = const Locale('ar'),
  }) {
    return ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => _TestImportFilesNotifier(files)),
      ],
      child: MaterialApp(
        home: AppLocalizationsProvider(
          locale: locale,
          child: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return Center(
                  child: ElevatedButton(
                    key: const Key('openPickerBtn'),
                    onPressed: () => onOpen(context, ref),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  group('FEX-T21: Shared Import File Picker Dialog Tests', () {
    testWidgets('Filters out Closed files by default and disables Continue until selection', (tester) async {
      ImportFileModel? pickedResult;

      await tester.pumpWidget(
        buildTestHost(
          files: [file1, file2, fileClosed],
          onOpen: (context, ref) async {
            pickedResult = await showImportFilePickerDialog(
              context,
              ref,
              title: 'اختيار ملف الشحنة',
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openPickerBtn')));
      await tester.pumpAndSettle();

      expect(find.text('اختيار ملف الشحنة'), findsWidgets);

      final continueFinder = find.byKey(const Key('importFilePickerContinueBtn'));
      expect(continueFinder, findsOneWidget);

      // Verify Continue button is disabled before selecting
      final continueButton = tester.widget<ElevatedButton>(find.descendant(
        of: continueFinder,
        matching: find.byType(ElevatedButton),
      ));
      expect(continueButton.onPressed, isNull);

      // Tap the dropdown to open overlay
      await tester.tap(find.byKey(const Key('importFilePickerDropdown')));
      await tester.pumpAndSettle();

      // Only file1 and file2 should be shown, not fileClosed
      expect(find.textContaining('Supplier A'), findsOneWidget);
      expect(find.textContaining('Supplier B'), findsOneWidget);
      expect(find.textContaining('Supplier C'), findsNothing);

      // Select file2
      await tester.tap(find.textContaining('Supplier B').last);
      await tester.pumpAndSettle();

      // Now Continue is enabled
      await tester.tap(continueFinder);
      await tester.pumpAndSettle();

      expect(pickedResult, isNotNull);
      expect(pickedResult!.importFileId, 102);
    });

    testWidgets('Excludes specific file ID when excludeId is passed', (tester) async {
      ImportFileModel? pickedResult;

      await tester.pumpWidget(
        buildTestHost(
          files: [file1, file2],
          onOpen: (context, ref) async {
            pickedResult = await showImportFilePickerDialog(
              context,
              ref,
              title: 'Select File',
              excludeId: 101,
            );
          },
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openPickerBtn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('importFilePickerDropdown')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Supplier A'), findsNothing);
      expect(find.textContaining('Supplier B'), findsOneWidget);

      await tester.tap(find.textContaining('Supplier B').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('importFilePickerContinueBtn')));
      await tester.pumpAndSettle();

      expect(pickedResult?.importFileId, 102);
    });

    testWidgets('Cancel button returns null', (tester) async {
      ImportFileModel? pickedResult = file1;

      await tester.pumpWidget(
        buildTestHost(
          files: [file1, file2],
          onOpen: (context, ref) async {
            pickedResult = await showImportFilePickerDialog(
              context,
              ref,
              title: 'Select File',
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openPickerBtn')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(pickedResult, isNull);
    });

    testWidgets('Shows empty state when no files match criteria', (tester) async {
      await tester.pumpWidget(
        buildTestHost(
          files: [fileClosed], // only closed file
          onOpen: (context, ref) async {
            await showImportFilePickerDialog(
              context,
              ref,
              title: 'اختيار ملف',
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('openPickerBtn')));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد ملفات شحن نشطة متاحة'), findsOneWidget);
      expect(find.byKey(const Key('importFilePickerContinueBtn')), findsNothing);
    });
  });
}
