import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/providers/navigation_provider.dart';
import 'package:frontend/core/providers/workspace_tabs_provider.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:frontend/features/projects/models/project_model.dart';
import 'package:frontend/features/projects/providers/projects_provider.dart';
import 'package:frontend/features/import_companies/providers/import_companies_provider.dart';
import 'package:frontend/features/suppliers/providers/suppliers_provider.dart';
import 'package:frontend/features/incoterms/providers/incoterms_provider.dart';

class MockProjectsNotifier extends ProjectsNotifier {
  MockProjectsNotifier() : super(Dio()) {
    state = AsyncValue.data([
      ProjectModel(
        projectId: 1,
        projectCode: 'PRJ-2026-001',
        projectName: 'Test Project Alpha',
        projectOwner: 'Eng. Maro',
        companyId: 1,
        companyIds: [1],
        supplierId: 1,
        incotermId: 1,
        importType: 'Direct Commercial',
        priority: 'High',
        shipmentCategory: 'FCL Container',
        allowMultiShipment: true,
        allowMultiCompany: true,
        totalBudgetUsd: 100000.0,
        targetEndDate: '2026-12-31',
        status: 'Open',
        isActive: true,
      ),
      ProjectModel(
        projectId: 2,
        projectCode: 'PRJ-2026-002',
        projectName: 'Test Project Beta',
        projectOwner: 'Eng. Amal',
        companyId: 2,
        companyIds: [2],
        supplierId: 2,
        incotermId: 2,
        importType: 'Direct Commercial',
        priority: 'Medium',
        shipmentCategory: 'LCL Breakbulk',
        allowMultiShipment: true,
        allowMultiCompany: false,
        totalBudgetUsd: 50000.0,
        targetEndDate: '2026-11-30',
        status: 'Open',
        isActive: true,
      ),
    ]);
  }

  @override
  Future<void> fetchProjects({bool includeInactive = true, String? status, String? search}) async {
    state = AsyncValue.data([
      ProjectModel(
        projectId: 1,
        projectCode: 'PRJ-2026-001',
        projectName: 'Test Project Alpha (Filtered: $search)',
        projectOwner: 'Eng. Maro',
        companyId: 1,
        companyIds: [1],
        supplierId: 1,
        incotermId: 1,
        importType: 'Direct Commercial',
        priority: 'High',
        shipmentCategory: 'FCL Container',
        allowMultiShipment: true,
        allowMultiCompany: true,
        totalBudgetUsd: 100000.0,
        targetEndDate: '2026-12-31',
        status: status ?? 'Open',
        isActive: true,
      ),
    ]);
  }
}

class MockCompaniesNotifier extends ImportCompaniesNotifier {
  MockCompaniesNotifier() : super(showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchCompanies({bool includeInactive = true}) async {
    state = const AsyncValue.data([]);
  }
}

class MockSuppliersNotifier extends SuppliersNotifier {
  MockSuppliersNotifier() : super(showInactive: true, dio: Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchSuppliers({bool includeInactive = true}) async {
    state = const AsyncValue.data([]);
  }
}

class MockIncotermsNotifier extends IncotermsNotifier {
  MockIncotermsNotifier(Ref ref) : super(ref: ref, showInactive: false, dio: Dio()) {
    state = const AsyncValue.data([]);
  }
  @override
  Future<void> fetchIncoterms({bool includeInactive = false}) async {
    state = const AsyncValue.data([]);
  }
}

void main() {
  group('Diagnostic Test: Screen Close & Navigation Freeze Reproduction', () {
    testWidgets('Simulate Open Tab -> Interact -> Close Tab cycle across multiple iterations', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          projectsProvider.overrideWith((ref) => MockProjectsNotifier()),
          importCompaniesProvider.overrideWith((ref) => MockCompaniesNotifier()),
          suppliersProvider.overrideWith((ref) => MockSuppliersNotifier()),
          incotermsProvider.overrideWith((ref) => MockIncotermsNotifier(ref)),
        ],
      );
      container.read(localeProvider.notifier).setLocale(const Locale('ar'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLocalizationsProvider(
              locale: Locale('ar'),
              child: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      debugPrint('[DIAGNOSTIC] Initial HomeScreen mounted with Dashboard');

      // Test 5 consecutive cycles of opening Projects tab, interacting with it, and closing it
      final List<double> openTimes = [];
      final List<double> interactTimes = [];
      final List<double> closeTimes = [];

      for (int cycle = 1; cycle <= 5; cycle++) {
        // 1. Open Projects Tab (routeIndex 31)
        final openSw = Stopwatch()..start();
        container.read(workspaceTabsProvider.notifier).openTab(
          id: 'tab_31',
          title: 'المشاريع ومراكز التكلفة',
          icon: Icons.folder_special_outlined,
          routeIndex: 31,
        );
        container.read(navigationIndexProvider.notifier).state = 31;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        openSw.stop();
        openTimes.add(openSw.elapsedMicroseconds / 1000.0);

        // 2. Interact with the table (search and filtering)
        final interactSw = Stopwatch()..start();
        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          await tester.enterText(searchField.first, 'Test Query $cycle');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
        }
        interactSw.stop();
        interactTimes.add(interactSw.elapsedMicroseconds / 1000.0);

        // 3. Close the tab via closeTab('tab_31')
        final closeSw = Stopwatch()..start();
        container.read(workspaceTabsProvider.notifier).closeTab('tab_31');
        final activeTab = container.read(workspaceTabsProvider).activeTab;
        if (activeTab != null) {
          container.read(navigationIndexProvider.notifier).state = activeTab.routeIndex;
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        closeSw.stop();
        closeTimes.add(closeSw.elapsedMicroseconds / 1000.0);

        debugPrint('[DIAGNOSTIC] Cycle #$cycle: Open: ${openTimes.last.toStringAsFixed(1)}ms | Interact: ${interactTimes.last.toStringAsFixed(1)}ms | Close: ${closeTimes.last.toStringAsFixed(1)}ms');
      }

      final avgOpen = openTimes.reduce((a, b) => a + b) / openTimes.length;
      final avgInteract = interactTimes.reduce((a, b) => a + b) / interactTimes.length;
      final avgClose = closeTimes.reduce((a, b) => a + b) / closeTimes.length;

      debugPrint('[DIAGNOSTIC SUMMARY] Avg Open: ${avgOpen.toStringAsFixed(1)}ms | Avg Interact: ${avgInteract.toStringAsFixed(1)}ms | Avg Close: ${avgClose.toStringAsFixed(1)}ms');

      // Verify tabs state after all closes
      final currentTabs = container.read(workspaceTabsProvider).tabs;
      expect(currentTabs.length, 1);
      expect(currentTabs.first.id, 'dashboard');
    });
  });
}
