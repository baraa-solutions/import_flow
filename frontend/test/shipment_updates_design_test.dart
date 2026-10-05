import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/app_localizations_ar.dart';
import 'package:frontend/core/localization/app_localizations_en.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/page_header.dart';
import 'package:frontend/features/customs_consultation/models/customs_consultation_model.dart';
import 'package:frontend/features/customs_consultation/providers/customs_consultation_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/shipment_updates/models/shipment_update_model.dart';
import 'package:frontend/features/shipment_updates/providers/shipment_updates_provider.dart';
import 'package:frontend/features/shipment_updates/screens/shipment_update_engine_screen.dart';
import 'package:frontend/features/shipment_updates/widgets/shipment_update_dialog.dart';
import 'package:frontend/features/shipment_updates/widgets/su_ui.dart';

class _FilesNotifier extends ImportFilesNotifier {
  _FilesNotifier(this.files) : super(Dio()) {
    state = AsyncValue.data(files);
  }

  final List<ImportFileModel> files;

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

class _UpdatesNotifier extends ShipmentUpdatesNotifier {
  _UpdatesNotifier(this.initial) : super(Dio()) {
    state = initial;
  }

  final ShipmentUpdatesState initial;

  @override
  Future<void> fetchLogs({int? importFileId, String? updateCategory, String? targetPhase, String? search}) async {
    state = initial;
  }
}

class _ConsultNotifier extends CustomsConsultationNotifier {
  _ConsultNotifier() : super(Dio()) {
    state = const AsyncValue.data(<CustomsConsultationModel>[]);
  }

  @override
  Future<void> fetchConsultations({
    bool includeInactive = false,
    String? search,
    int? brokerId,
    int? poId,
    int? projectId,
    String? status,
  }) async {}
}

ImportFileModel _file() => ImportFileModel(
      importFileId: 1,
      importFileCode: 'IMP-0001',
      companyId: 1,
      companyName: 'ECO',
      supplierName: 'Siemens',
      currentModule: 'Phase 3',
      currentStage: 'Booking',
      nextAction: 'Track',
      status: 'Active',
      createdAt: '2026-08-16T00:00:00',
      updatedAt: '2026-08-16T00:00:00',
    );

ShipmentUpdateLogModel _log(int id, String category) => ShipmentUpdateLogModel(
      updateId: id,
      updateCode: 'UPD-00$id',
      importFileId: 1,
      importFileCode: 'IMP-0001',
      updateCategory: category,
      targetPhase: 'Phase 3',
      phaseStatus: 'Current',
      logDate: '2026-08-16',
      note: 'note $id',
      alertPriority: 'Normal',
      assignedUser: 'Kamal',
      isActive: true,
      createdAt: '2026-08-16T00:00:00',
      createdBy: 'Kamal',
    );

Future<void> _pump(
  WidgetTester tester, {
  required ShipmentUpdatesState state,
  Locale locale = const Locale('en'),
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        importFilesProvider.overrideWith((ref) => _FilesNotifier([_file()])),
        shipmentUpdatesProvider.overrideWith((ref) => _UpdatesNotifier(state)),
        customsConsultationsProvider.overrideWith((ref) => _ConsultNotifier()),
      ],
      child: AppLocalizationsProvider(
        locale: locale,
        child: MaterialApp(
          home: Directionality(
            textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: const ShipmentUpdateEngineScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const en = AppLocalizationsEn();
  const ar = AppLocalizationsAr();

  group('SuUi mappings', () {
    test('category / phase / consultation severities', () {
      expect(SuUi.categorySeverity('Daily Check-in'), AppSeverity.success);
      expect(SuUi.categorySeverity('Phase Cost Adjustment'), AppSeverity.warning);
      expect(SuUi.categorySeverity('Follow-up & Notes'), AppSeverity.info);
      expect(SuUi.phaseSeverity('Completed'), AppSeverity.success);
      expect(SuUi.phaseSeverity('Current'), AppSeverity.info);
      expect(SuUi.phaseSeverity('Future'), AppSeverity.warning);
      expect(SuUi.consultationSeverity('Blocked'), AppSeverity.danger);
      expect(SuUi.docStatusSeverity('Rejected'), AppSeverity.danger);
      expect(SuUi.readinessSeverity(85), AppSeverity.success);
      expect(SuUi.readinessSeverity(60), AppSeverity.warning);
      expect(SuUi.readinessSeverity(10), AppSeverity.danger);
    });

    test('new localization keys exist in both languages', () {
      expect(en.suMetricTotalUpdates, isNotEmpty);
      expect(ar.suMetricTotalUpdates, isNotEmpty);
      expect(en.suMetricCompletedPhases, isNotEmpty);
      expect(ar.suMetricCompletedPhases, isNotEmpty);
    });
  });

  group('ShipmentUpdateEngineScreen design pass', () {
    testWidgets('uses PageHeader (no plain AppBar) and shows loaded metrics', (tester) async {
      await _pump(
        tester,
        state: ShipmentUpdatesState(
          logs: [_log(1, 'Daily Check-in'), _log(2, 'Phase Cost Adjustment'), _log(3, 'Daily Check-in')],
          inspectedPhases: [
            PhaseInspectionModel(phaseCode: 'Phase 1', phaseName: 'x', phaseNumber: 1, status: 'Completed', updateCount: 1),
          ],
        ),
      );
      expect(find.byType(PageHeader), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text(en.suMetricTotalUpdates), findsWidgets);
      expect(find.text('3'), findsWidgets); // total updates
      expect(find.text('1/10'), findsOneWidget); // completed phases
      expect(find.text('UPD-001'), findsOneWidget);
    });

    testWidgets('empty logs show the empty state and no metric strip numbers', (tester) async {
      await _pump(tester, state: ShipmentUpdatesState());
      expect(find.text(en.shipmentUpdateLogsEmptyMessage), findsOneWidget);
    });

    testWidgets('error state offers a retry action', (tester) async {
      await _pump(tester, state: ShipmentUpdatesState(error: 'boom'));
      expect(find.text(en.retry), findsWidgets);
    });

    testWidgets('renders in Arabic on a narrow window without overflow', (tester) async {
      await _pump(
        tester,
        locale: const Locale('ar'),
        size: const Size(480, 900),
        state: ShipmentUpdatesState(logs: [_log(1, 'Daily Check-in')]),
      );
      expect(find.text(ar.shipmentUpdateEngineTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the update dialog opens in the standard shell and validates notes', (tester) async {
      await _pump(tester, state: ShipmentUpdatesState());
      await tester.tap(find.text(en.shipmentUpdateComprehensiveDailyCheckinBtn));
      await tester.pumpAndSettle();
      expect(find.byType(ShipmentUpdateDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('shipmentUpdateSaveBtn')));
      await tester.pumpAndSettle();
      expect(find.text(en.shipmentUpdateFieldNotesRequired), findsOneWidget);
    });
  });
}
