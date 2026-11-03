import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/demurrage_detention/models/demurrage_model.dart';
import 'package:frontend/features/demurrage_detention/widgets/empty_container_return_dialog.dart';

class _MockImportFilesNotifier extends ImportFilesNotifier {
  final List<ImportFileModel> initialFiles;
  _MockImportFilesNotifier(this.initialFiles) : super(Dio()) {
    state = AsyncValue.data(initialFiles);
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
    state = AsyncValue.data(initialFiles);
  }
}

void main() {
  group('TR-05: Empty Container Return (EIR) Model Tests', () {
    test('EmptyContainerReturnSubmitModel serializes to JSON correctly', () {
      final model = EmptyContainerReturnSubmitModel(
        importFileId: 101,
        eirNumber: 'EIR-2026-0099',
        emptyReturnDate: '2026-09-18',
        depotName: 'MSC Empty Depot - Dekheila',
        returnedContainers: ['MSCU1234567', 'MSCU7654321'],
        containerCondition: 'SOUND_CLEAN',
        damageNotes: 'No damage, clean sweep',
        damageFeeEstimated: 0.0,
        damageCurrency: 'USD',
        driverName: 'Ahmed Hassan',
        truckPlateNo: 'ط س ج 1234',
        notes: 'Handover complete',
      );

      final json = model.toJson();

      expect(json['import_file_id'], 101);
      expect(json['eir_number'], 'EIR-2026-0099');
      expect(json['empty_return_date'], '2026-09-18');
      expect(json['depot_name'], 'MSC Empty Depot - Dekheila');
      expect(json['returned_containers'], ['MSCU1234567', 'MSCU7654321']);
      expect(json['container_condition'], 'SOUND_CLEAN');
      expect(json['driver_name'], 'Ahmed Hassan');
      expect(json['truck_plate_no'], 'ط س ج 1234');
      expect(json['notes'], 'Handover complete');
    });

    test('EmptyContainerReturnResponseModel deserializes and serializes JSON correctly', () {
      final json = {
        'import_file_id': 101,
        'import_file_code': 'IMP-2026-0101',
        'tracking_id': 5,
        'tracking_code': 'TRK-2026-0005',
        'eir_number': 'EIR-2026-0099',
        'empty_return_date': '2026-09-18',
        'depot_name': 'MSC Empty Depot - Dekheila',
        'returned_containers': ['MSCU1234567', 'MSCU7654321'],
        'containers_returned_count': 2,
        'total_containers_count': 2,
        'all_containers_returned': true,
        'container_condition': 'SOUND_CLEAN',
        'damage_fee_estimated': 0.0,
        'demurrage_final_fx': 0.0,
        'detention_final_fx': 0.0,
        'storage_final_egp': 0.0,
        'total_exposure_egp': 0.0,
        'tracking_status': 'RETURNED_SAFE',
        'next_action': 'Proceed to Phase 9 landed cost and settlement',
        'current_stage': 'STEP_20',
        'progress_percent': 98.0,
        'message_ar': 'تم تسجيل إرجاع الحاويات الفارغة بنجاح',
        'returned_at': '2026-09-18T14:30:00Z',
      };

      final model = EmptyContainerReturnResponseModel.fromJson(json);

      expect(model.importFileId, 101);
      expect(model.importFileCode, 'IMP-2026-0101');
      expect(model.trackingId, 5);
      expect(model.eirNumber, 'EIR-2026-0099');
      expect(model.depotName, 'MSC Empty Depot - Dekheila');
      expect(model.containersReturnedCount, 2);
      expect(model.allContainersReturned, isTrue);
      expect(model.trackingStatus, 'RETURNED_SAFE');
      expect(model.progressPercent, 98.0);
      expect(model.messageAr, 'تم تسجيل إرجاع الحاويات الفارغة بنجاح');
      expect(model.returnedAt, '2026-09-18T14:30:00Z');
    });

    test('ImportFileModel correctly maps EIR fields from and to JSON', () {
      final json = {
        'import_file_id': 101,
        'import_file_code': 'IMP-2026-0101',
        'company_id': 1,
        'supplier_id': 2,
        'supplier_name': 'Global Tech Ltd',
        'status': 'In Transit',
        'progress_percent': 98.0,
        'empty_containers_returned_at': '2026-09-18T14:00:00Z',
        'empty_containers_return_status': 'RETURNED_SAFE',
        'empty_containers_eir_numbers': 'EIR-2026-0099',
        'empty_containers_depot_name': 'MSC Empty Depot - Dekheila',
      };

      final file = ImportFileModel.fromJson(json);

      expect(file.emptyContainersReturnedAt, '2026-09-18T14:00:00Z');
      expect(file.emptyContainersReturnStatus, 'RETURNED_SAFE');
      expect(file.emptyContainersEirNumbers, 'EIR-2026-0099');
      expect(file.emptyContainersDepotName, 'MSC Empty Depot - Dekheila');

      final serialized = file.toJson();
      expect(serialized['empty_containers_returned_at'], '2026-09-18T14:00:00Z');
      expect(serialized['empty_containers_return_status'], 'RETURNED_SAFE');
      expect(serialized['empty_containers_eir_numbers'], 'EIR-2026-0099');
      expect(serialized['empty_containers_depot_name'], 'MSC Empty Depot - Dekheila');
    });
  });

  group('TR-05: Empty Container Return Dialog Widget Tests', () {
    final sampleFile = ImportFileModel.fromJson({
      'import_file_id': 101,
      'import_file_code': 'IMP-2026-0101',
      'company_id': 1,
      'company_name': 'Al-Sorour Logistics Ltd',
      'supplier_id': 2,
      'supplier_name': 'Global Logistics Co.',
      'status': 'In Transit',
      'progress_percent': 92.0,
      'current_module': 'Inland Transport',
      'current_stage': 'Phase 8 - Inland Transport & Receiving',
      'next_action': 'Return Empty Containers (TR-05)',
      'created_at': '2026-09-18T10:00:00Z',
      'updated_at': '2026-09-18T10:00:00Z',
    });

    testWidgets('Renders EmptyContainerReturnDialog with all components and fields', (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([sampleFile])),
          ],
          child: const AppLocalizationsProvider(
            locale: Locale('ar'),
            child: MaterialApp(
              locale: Locale('ar'),
              home: Scaffold(
                body: EmptyContainerReturnDialog(
                  initialImportFileId: 101,
                  initialContainerNumber: 'MSCU1234567',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header title
      expect(find.text('تأكيد إرجاع الحاويات الفارغة للخط الملاحي — (TR-05)'), findsOneWidget);

      // Check submit button
      expect(find.byKey(const Key('submitEmptyContainerReturnBtn')), findsOneWidget);

      // Check cancel button
      expect(find.text('إلغاء'), findsOneWidget);

      // Check container condition cards
      expect(find.textContaining('سليمة ونظيفة'), findsOneWidget);
      expect(find.text('تلفيات طفيفة'), findsOneWidget);
      expect(find.textContaining('تتطلب إصلاح'), findsOneWidget);

      // Check initial container number badge
      expect(find.textContaining('MSCU1234567'), findsOneWidget);

      // Ensure visible and tap on 'تلفيات طفيفة' condition card
      await tester.ensureVisible(find.text('تلفيات طفيفة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تلفيات طفيفة'));
      await tester.pumpAndSettle();

      // Verify that damage description field appears
      expect(find.textContaining('ملاحظات وتفاصيل التلفيات'), findsOneWidget);
    });
  });
}
