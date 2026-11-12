import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/features/import_companies/models/import_company_model.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/incoterms/models/incoterm_model.dart';
import 'package:frontend/features/incoterms/providers/incoterms_provider.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/projects/screens/projects_screen.dart';
import 'package:frontend/features/projects/widgets/project_form_dialog.dart';
import 'package:frontend/features/suppliers/models/supplier_model.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';

class _FakeProjectsNotifier extends StateNotifier<AsyncValue<List<ProjectModel>>>
    implements ProjectsNotifier {
  final List<ProjectModel> _initial;
  _FakeProjectsNotifier(this._initial) : super(AsyncValue.data(_initial));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {
    state = AsyncValue.data(_initial);
  }

  @override
  Future<bool> createProject(ProjectModel project) async {
    final created = ProjectModel(
      projectId: 99,
      projectCode: 'PRJ-2026-099',
      projectName: project.projectName,
      projectOwner: project.projectOwner,
      companyId: project.companyId,
      companyIds: project.companyIds,
      supplierId: project.supplierId,
      incotermId: project.incotermId,
      importType: project.importType,
      priority: project.priority,
      shipmentCategory: project.shipmentCategory,
      allowMultiShipment: project.allowMultiShipment,
      allowMultiCompany: project.allowMultiCompany,
      totalBudgetUsd: project.totalBudgetUsd,
      targetEndDate: project.targetEndDate,
      status: project.status,
      notes: project.notes,
      isActive: true,
    );
    _initial.add(created);
    state = AsyncValue.data(List.from(_initial));
    return true;
  }
}

class _FakeCompaniesNotifier extends StateNotifier<AsyncValue<List<ImportCompanyModel>>>
    implements ImportCompaniesNotifier {
  final List<ImportCompanyModel> _comps;
  _FakeCompaniesNotifier(this._comps) : super(AsyncValue.data(_comps));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fetchCompanies({bool includeInactive = false, String? search}) async {
    state = AsyncValue.data(_comps);
  }
}

class _FakeSuppliersNotifier extends StateNotifier<AsyncValue<List<SupplierModel>>>
    implements SuppliersNotifier {
  final List<SupplierModel> _supps;
  _FakeSuppliersNotifier(this._supps) : super(AsyncValue.data(_supps));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fetchSuppliers({bool includeInactive = false, String? search}) async {
    state = AsyncValue.data(_supps);
  }
}

class _FakeIncotermsNotifier extends StateNotifier<AsyncValue<List<IncotermModel>>>
    implements IncotermsNotifier {
  final List<IncotermModel> _incs;
  _FakeIncotermsNotifier(this._incs) : super(AsyncValue.data(_incs));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fetchIncoterms({bool includeInactive = false, String? search}) async {
    state = AsyncValue.data(_incs);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PL-01: New Import Project & Budget/Target Tracking Tests', () {
    test('ProjectModel should serialize and deserialize target_end_date and budget correctly', () {
      final json = {
        'project_id': 10,
        'project_code': 'PRJ-2026-010',
        'project_name': 'خط إنتاج مصنع السخنة',
        'project_owner': 'م. حسن البدري',
        'company_id': 1,
        'company_ids': [1, 2],
        'supplier_id': 5,
        'incoterm_id': 2,
        'import_type': 'Direct Commercial',
        'priority': 'High',
        'shipment_category': 'FCL Container',
        'allow_multi_shipment': true,
        'allow_multi_company': true,
        'total_budget_usd': 350000.0,
        'target_end_date': '2026-11-30',
        'status': 'Open',
        'notes': 'توريد وتركيب خط التغليف الآلي',
        'is_active': true,
      };

      final model = ProjectModel.fromJson(json);

      expect(model.projectId, 10);
      expect(model.projectCode, 'PRJ-2026-010');
      expect(model.projectName, 'خط إنتاج مصنع السخنة');
      expect(model.totalBudgetUsd, 350000.0);
      expect(model.targetEndDate, '2026-11-30');
      expect(model.status, 'Open');
      expect(model.allowMultiShipment, isTrue);

      final exportedJson = model.toJson();
      expect(exportedJson['total_budget_usd'], 350000.0);
      expect(exportedJson['target_end_date'], '2026-11-30');
    });

    testWidgets('ProjectsScreen displays projects with budget and target end date badge', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockProject = ProjectModel(
        projectId: 1,
        projectCode: 'PRJ-2026-001',
        projectName: 'مشروع الطاقة النظيفة بالسخنة',
        projectOwner: 'م. أحمد صلاح',
        companyId: 1,
        companyIds: [1],
        companyName: 'شركة سرور للاستيراد والتصدير',
        supplierId: 1,
        supplierName: 'Shanghai Solar Tech Ltd',
        incotermId: 1,
        incotermCode: 'FOB',
        importType: 'Direct Commercial',
        priority: 'High',
        shipmentCategory: 'FCL Container',
        allowMultiShipment: true,
        allowMultiCompany: true,
        totalBudgetUsd: 150000.0,
        targetEndDate: '2026-12-31',
        status: 'Open',
        isActive: true,
      );

      final mockCompany = ImportCompanyModel(
        companyId: 1,
        importerName: 'شركة سرور للاستيراد والتصدير',
        country: 'Egypt',
        address: 'القاهرة',
        importerId: 'IMP-100200',
        importerIdExpiry: DateTime.now().add(const Duration(days: 365)),
        vatId: 'VAT-998877',
        vatIdExpiry: DateTime.now().add(const Duration(days: 365)),
        registrationNumber: 'REG-554433',
        registrationExpiry: DateTime.now().add(const Duration(days: 365)),
        isActive: true,
      );

      final mockSupplier = SupplierModel(
        supplierId: 1,
        supplierCode: 'SUP-000001',
        companyName: 'Shanghai Solar Tech Ltd',
        supplierType: 'Manufacturer',
        registrationType: 'Factory',
        foreignExporterId: 'EXP-CN-8899',
        foreignExporterCountry: 'China',
        foreignExporterCountryCode: 'CN',
        address: 'Shanghai, China',
        isActive: true,
      );

      final mockIncoterm = IncotermModel(
        incotermId: 1,
        incotermCode: 'FOB',
        incotermName: 'Free On Board',
        version: '2020',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) {
              final n = LocaleNotifier();
              n.setLocale(const Locale('ar'));
              return n;
            }),
            projectsProvider.overrideWith((ref) => _FakeProjectsNotifier([mockProject])),
            importCompaniesProvider.overrideWith((ref) => _FakeCompaniesNotifier([mockCompany])),
            suppliersProvider.overrideWith((ref) => _FakeSuppliersNotifier([mockSupplier])),
            incotermsProvider.overrideWith((ref) => _FakeIncotermsNotifier([mockIncoterm])),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            builder: (context, child) => AppLocalizationsProvider(
              locale: const Locale('ar'),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            home: const Scaffold(
              body: ProjectsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify project details rendered in table
      expect(find.text('PRJ-2026-001'), findsOneWidget);
      expect(find.text('مشروع الطاقة النظيفة بالسخنة'), findsOneWidget);
      expect(find.text('USD 150000.00'), findsOneWidget); // budget shown with its budget_currency
      expect(find.text('2026-12-31'), findsOneWidget);

      // Verify create project button exists
      final createBtn = find.byIcon(Icons.add);
      expect(createBtn, findsOneWidget);

      // Tap create project button to open dialog
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Verify dialog fields exist
      expect(find.text('إنشاء مشروع استيراد جديد'), findsOneWidget);
      expect(find.text('اسم المشروع *'), findsOneWidget);
      expect(find.text('مدير أو مسؤول المشروع *'), findsOneWidget);
      // The projects stats bar behind the dialog also shows this label, so scope to the dialog.
      expect(
        find.descendant(of: find.byType(ProjectFormDialog), matching: find.text('الميزانية التقديرية بالدولار')),
        findsOneWidget,
      );
      expect(find.text('تاريخ الانتهاء المستهدف'), findsOneWidget);

      // A new project starts blank: no supplier / incoterm is silently taken from the first row.
      final dialog = find.byType(ProjectFormDialog);
      expect(find.descendant(of: dialog, matching: find.text('Shanghai Solar Tech Ltd')), findsNothing);
      expect(find.descendant(of: dialog, matching: find.text('FOB (Free On Board)')), findsNothing);

      // Submitting without choosing them shows the required errors and creates nothing.
      final l10n = AppLocalizations.of(tester.element(dialog));
      await tester.enterText(find.widgetWithText(TextFormField, 'اسم المشروع *'), 'مشروع تجريبي');
      await tester.enterText(find.widgetWithText(TextFormField, 'مدير أو مسؤول المشروع *'), 'م. كمال');
      final submit = find.text(l10n.createProjectSubmitBtn);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text(l10n.fieldRequired), findsNWidgets(2));
      expect(find.byType(ProjectFormDialog), findsOneWidget);
      expect(find.text('PRJ-2026-099'), findsNothing);
    });
  });
}
