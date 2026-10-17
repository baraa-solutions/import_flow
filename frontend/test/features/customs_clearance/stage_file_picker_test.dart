import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/searchable_dropdown_field.dart';
import 'package:frontend/features/customs_clearance/models/customs_clearance_model.dart';
import 'package:frontend/features/customs_clearance/providers/customs_clearance_provider.dart';
import 'package:frontend/features/customs_clearance/screens/customs_clearance_screen.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_broker_authorization_dialog.dart';
import 'package:frontend/features/customs_clearance/widgets/customs_declaration_46_dialog.dart';
import 'package:frontend/features/customs_clearance/widgets/delivery_order_payment_dialog.dart';
import 'package:frontend/features/external_service_providers/providers/partners_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';

class _MockClearanceNotifier extends CustomsClearanceNotifier {
  final List<CustomsClearanceModel> initialRecords;
  _MockClearanceNotifier(this.initialRecords) : super(Dio()) {
    state = AsyncValue.data(initialRecords);
  }

  @override
  Future<void> fetchRecords({
    bool includeInactive = false,
    int? importFileId,
    String? status,
    String? search, int skip = 0, int limit = 200}) async {
    state = AsyncValue.data(initialRecords);
  }
}

class _MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> files;
  _MockImportFilesNotifier(this.files) : super(Dio()) {
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
  }) async {
    state = AsyncValue.data(files);
  }
}

class _MockPartnersNotifier extends PartnersNotifier {
  _MockPartnersNotifier() : super(category: 'All', showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchPartners({
    String? category,
    bool includeInactive = false,
    String? search,
  }) async {
    state = const AsyncValue.data([]);
  }
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
    companyName: 'Test Logistics Corp',
    supplierName: supplier,
    shipmentMode: 'SEA',
    incotermCode: 'FOB',
    priority: 'Normal',
    shipmentCategory: 'Commercial',
    currentModule: 'Customs Clearance',
    currentStage: 'Phase 6 - Customs Clearance Preparation',
    nextAction: 'Broker Authorization',
    status: status,
    createdAt: '2026-01-01',
    updatedAt: '2026-01-01',
  );
}

CustomsClearanceModel _makeRecord({
  required int id,
  required int fileId,
  required String code,
}) {
  return CustomsClearanceModel(
    customsClearanceId: id,
    clearanceCode: code,
    importFileId: fileId,
    declaration46No: 'DEC-$id',
    customsOfficeName: 'Alexandria Port Customs',
    channelType: 'Red Channel',
    totalDutyPayable: 10000.0,
    actualDutyTotal: 10000.0,
    status: 'Inspection Scheduled',
    createdAt: '2026-09-01T10:00:00Z',
    updatedAt: '2026-09-01T12:00:00Z',
  );
}

Widget createHarness({
  required List<ImportFileModel> files,
  required List<CustomsClearanceModel> records,
  int? initialImportFileId,
  Locale locale = const Locale('ar'),
}) {
  return ProviderScope(
    overrides: [
      customsClearanceProvider.overrideWith((ref) => _MockClearanceNotifier(records)),
      importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier(files)),
      partnersProvider.overrideWith((ref) => _MockPartnersNotifier()),
    ],
    child: MaterialApp(
      home: AppLocalizationsProvider(
        locale: locale,
        child: Scaffold(
          body: CustomsClearanceScreen(
            initialImportFileId: initialImportFileId,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FE06-T04: Customs Clearance Stage File Picker Tests', () {
    final file1 = _makeFile(id: 1, code: 'IMP-2026-0001', supplier: 'Alpha Supplier');
    final file2 = _makeFile(id: 2, code: 'IMP-2026-0002', supplier: 'Beta Supplier');
    final record2 = _makeRecord(id: 20, fileId: 2, code: 'CLR-2026-0002');
    final orphanRecord = _makeRecord(id: 99, fileId: 999, code: 'CLR-2026-0999');

    testWidgets('Header button asks for shipment via picker dialog and opens stage dialog on select', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createHarness(
        files: [file1, file2],
        records: [record2],
        initialImportFileId: null,
      ));
      await tester.pumpAndSettle();

      final headerBtn = find.byKey(const Key('authorizeCustomsBrokerHeaderBtn'));
      expect(headerBtn, findsOneWidget);
      // Header actions sit in a horizontal scroll view: bring the button into view first.
      await tester.ensureVisible(headerBtn);
      await tester.pumpAndSettle();
      await tester.tap(headerBtn);
      await tester.pumpAndSettle();

      // Picker dialog is open, CustomsBrokerAuthorizationDialog is NOT open yet
      expect(find.byKey(const Key('importFilePickerDropdown')), findsOneWidget);
      expect(find.byType(CustomsBrokerAuthorizationDialog), findsNothing);

      // Select file 2 from dropdown
      final dropdown = find.byKey(const Key('importFilePickerDropdown'));
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final file2Option = find.textContaining('IMP-2026-0002').last;
      await tester.tap(file2Option);
      await tester.pumpAndSettle();

      // Tap continue button in picker dialog
      final continueBtn = find.byKey(const Key('importFilePickerContinueBtn'));
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Broker authorization dialog is now open with File 2
      expect(find.byType(CustomsBrokerAuthorizationDialog), findsOneWidget);
      expect(find.textContaining('IMP-2026-0002'), findsWidgets);
    });

    testWidgets('Header button picker cancel dismisses dialog without opening stage dialog', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createHarness(
        files: [file1, file2],
        records: [record2],
        initialImportFileId: null,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('authorizeCustomsBrokerHeaderBtn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('authorizeCustomsBrokerHeaderBtn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('importFilePickerDropdown')), findsOneWidget);

      // Cancel button
      final cancelBtn = find.text('إلغاء');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('importFilePickerDropdown')), findsNothing);
      expect(find.byType(CustomsBrokerAuthorizationDialog), findsNothing);
    });

    testWidgets('Header button with initialImportFileId opens stage dialog directly without picker', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createHarness(
        files: [file1, file2],
        records: [record2],
        initialImportFileId: 2,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('authorizeCustomsBrokerHeaderBtn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('authorizeCustomsBrokerHeaderBtn')));
      await tester.pumpAndSettle();

      // No picker dialog was opened
      expect(find.byKey(const Key('importFilePickerDropdown')), findsNothing);
      // Stage dialog opened directly with file 2
      expect(find.byType(CustomsBrokerAuthorizationDialog), findsOneWidget);
      expect(find.textContaining('IMP-2026-0002'), findsWidgets);
    });

    testWidgets('Card stage buttons open directly for that card shipment without picker', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createHarness(
        files: [file1, file2],
        records: [record2],
        initialImportFileId: null,
      ));
      await tester.pumpAndSettle();

      // Card broker auth button
      final cardBrokerBtn = find.byKey(Key('brokerAuthBtn_${record2.clearanceCode}'));
      expect(cardBrokerBtn, findsOneWidget);
      await tester.tap(cardBrokerBtn);
      await tester.pumpAndSettle();

      // Directly opens CustomsBrokerAuthorizationDialog with File 2
      expect(find.byKey(const Key('importFilePickerDropdown')), findsNothing);
      expect(find.byType(CustomsBrokerAuthorizationDialog), findsOneWidget);
      expect(find.textContaining('IMP-2026-0002'), findsWidgets);

      // Close the dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // Card delivery order button
      final cardDoBtn = find.byKey(Key('deliveryOrderBtn_${record2.clearanceCode}'));
      expect(cardDoBtn, findsOneWidget);
      await tester.tap(cardDoBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('importFilePickerDropdown')), findsNothing);
      expect(find.byType(DeliveryOrderPaymentDialog), findsOneWidget);

      // Close DO dialog
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // Card declaration 46 button
      final cardDeclBtn = find.byKey(Key('declaration46Btn_${record2.clearanceCode}'));
      expect(cardDeclBtn, findsOneWidget);
      await tester.tap(cardDeclBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('importFilePickerDropdown')), findsNothing);
      expect(find.byType(CustomsDeclaration46Dialog), findsOneWidget);
    });

    testWidgets('Card stage button shows warning SnackBar when underlying file is missing', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createHarness(
        files: [file1, file2],
        records: [orphanRecord],
        initialImportFileId: null,
      ));
      await tester.pumpAndSettle();

      final orphanBrokerBtn = find.byKey(Key('brokerAuthBtn_${orphanRecord.clearanceCode}'));
      expect(orphanBrokerBtn, findsOneWidget);
      await tester.tap(orphanBrokerBtn);
      await tester.pumpAndSettle();

      // No dialog opened, warning SnackBar shown
      expect(find.byType(CustomsBrokerAuthorizationDialog), findsNothing);
      expect(find.text('لم يتم العثور على ملف الشحنة المرتبط'), findsOneWidget);
    });
  });
}
