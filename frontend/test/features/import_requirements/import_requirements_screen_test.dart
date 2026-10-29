import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_locales.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/widgets/enterprise_data_table/enterprise_data_table.dart';
import 'package:frontend/features/customs_tariff/models/customs_tariff_model.dart';
import 'package:frontend/features/customs_tariff/providers/customs_tariff_provider.dart';
import 'package:frontend/features/import_files/models/import_file_model.dart';
import 'package:frontend/features/import_files/providers/import_files_provider.dart';
import 'package:frontend/features/import_requirements/models/import_requirement_model.dart';
import 'package:frontend/features/import_requirements/providers/import_requirements_provider.dart';
import 'package:frontend/features/import_requirements/screens/import_requirements_screen.dart';
import 'package:frontend/features/import_requirements/widgets/dialogs/requirement_details_dialog.dart';
import 'package:frontend/features/import_requirements/widgets/registry/import_requirements_registry_table.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

Widget _buildTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocales.localizationsDelegates,
      supportedLocales: AppLocales.supportedLocales,
      home: AppLocalizationsProvider(
        locale: const Locale('ar'),
        child: child,
      ),
    ),
  );
}

final testRequirement = ImportRequirementModel(
  assessmentId: 101,
  assessmentCode: 'REQ-2026-00101',
  importFileId: 5,
  importFileCode: 'IMP-2026-0005',
  hsCode: '8471.30.00',
  commodityDescription: 'أجهزة حاسب آلي محمولة',
  countryOfOrigin: 'China',
  currency: 'USD',
  shipmentValue: 50000.0,
  shipmentValueUsd: 50000.0,
  decree43Applicable: true,
  whiteListRequired: true,
  whiteListVerified: true,
  cooRequired: true,
  cooStatus: 'Obtained',
  inspectionRequired: true,
  inspectionStatus: 'Completed',
  importPermitRequired: true,
  permitStatus: 'Approved',
  msdsRequired: false,
  msdsStatus: 'Not Required',
  halalCertRequired: false,
  halalCertStatus: 'Not Required',
  coaRequired: false,
  coaStatus: 'Not Required',
  overallStatus: 'Draft',
  riskLevel: 'Low',
  assessedBy: 'كمال - استشاري التخليص الجمركي',
  isActive: true,
  createdAt: DateTime(2026, 6, 1),
  updatedAt: DateTime(2026, 6, 1),
);

void main() {
  group('Session 4: Import Requirements Screen & Enterprise Table Tests', () {
    testWidgets('1. ImportRequirementsScreen renders with SelectionArea and 2 tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));

      await tester.pumpWidget(
        _buildTestApp(
          const ImportRequirementsScreen(),
          overrides: [
            importRequirementsProvider.overrideWith(() => _MockRequirementsNotifier([testRequirement])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([])),
            suppliersProvider.overrideWith((ref) => _MockSuppliersNotifier([])),
            customsTariffProvider.overrideWith((ref) => _MockCustomsTariffNotifier([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify SelectionArea exists
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify Screen Title
      expect(find.text('تقييم متطلبات ومستندات الاستيراد والموافقات التنظيمية'), findsOneWidget);

      // Verify TabBar with Form and Registry tabs
      expect(find.text('📋 تقييم ومطابقة المتطلبات التنظيمية'), findsOneWidget);
      expect(find.text('📑 سجل دراسات المتطلبات المحفوظة'), findsOneWidget);

      // Tap registry tab
      await tester.tap(find.text('📑 سجل دراسات المتطلبات المحفوظة'));
      await tester.pumpAndSettle();

      // Verify EnterpriseDataTable renders in Registry tab
      expect(find.byType(EnterpriseDataTable<ImportRequirementModel>), findsOneWidget);
    });

    testWidgets('2. ImportRequirementsRegistryTable renders EnterpriseDataTable with governance column', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));

      await tester.pumpWidget(
        _buildTestApp(
          Scaffold(
            body: ImportRequirementsRegistryTable(
              onEditRequirement: (_) {},
              onAddNewRequirement: () {},
            ),
          ),
          overrides: [
            importRequirementsProvider.overrideWith(() => _MockRequirementsNotifier([testRequirement])),
            importFilesProvider.overrideWith((ref) => _MockImportFilesNotifier([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify EnterpriseDataTable renders
      expect(find.byType(EnterpriseDataTable<ImportRequirementModel>), findsOneWidget);

      // Verify column headers exist
      expect(find.text('كود التقييم'), findsOneWidget);
      expect(find.text('الحوكمة'), findsOneWidget);

      // Verify row item is present
      expect(find.text('REQ-2026-00101'), findsOneWidget);
    });

    testWidgets('3. RequirementDetailsDialog renders properly with SelectionArea', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));

      await tester.pumpWidget(
        _buildTestApp(
          RequirementDetailsDialog(
            requirement: testRequirement,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SelectionArea exists
      expect(find.byType(SelectionArea), findsWidgets);

      // Verify details title and metadata
      expect(find.text('تفاصيل دراسة المتطلبات الرقابية وما قبل الشحن'), findsOneWidget);
      expect(find.text('REQ-2026-00101'), findsOneWidget);
      expect(find.text('8471.30.00'), findsOneWidget);
    });
  });
}

class _MockRequirementsNotifier extends AsyncNotifier<List<ImportRequirementModel>>
    implements ImportRequirementsNotifier {
  final List<ImportRequirementModel> _initial;
  _MockRequirementsNotifier(this._initial);

  @override
  Future<List<ImportRequirementModel>> build() async => _initial;

  @override
  Future<void> refreshData() async {
    state = AsyncValue.data(_initial);
  }

  @override
  Future<void> addRequirement(Map<String, dynamic> data) async {}

  @override
  Future<void> updateRequirement(int id, Map<String, dynamic> data) async {}

  @override
  Future<void> deleteRequirement(int id) async {}

  @override
  Future<void> restoreRequirement(int id) async {}

  @override
  Future<ImportRequirementPrefillModel?> fetchPrefillData(int importFileId) async => null;

  @override
  Future<void> fetchByFileId(int? fileId) async {}
}

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

class _MockSuppliersNotifier extends SuppliersNotifier {
  final List<SupplierModel> initialSuppliers;
  _MockSuppliersNotifier(this.initialSuppliers) : super(showInactive: true, dio: Dio()) {
    state = AsyncValue.data(initialSuppliers);
  }

  @override
  Future<void> fetchSuppliers({
    bool includeInactive = false,
    String? search,
    String? country,
    String? currency,
    String? productCategory,
  }) async {
    state = AsyncValue.data(initialSuppliers);
  }
}

class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCustomsTariffNotifier extends CustomsTariffNotifier {
  final List<CustomsTariffModel> initialTariffs;
  _MockCustomsTariffNotifier(this.initialTariffs)
      : super(ref: _FakeRef(), showInactive: false, search: '', dio: Dio()) {
    state = AsyncValue.data(initialTariffs);
  }

  @override
  Future<void> fetchTariffs() async {
    state = AsyncValue.data(initialTariffs);
  }
}
