import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../providers/import_requirements_provider.dart';
import '../widgets/form/form.dart';
import '../widgets/registry/registry.dart';

/// 🏛️ Import Requirements Screen (BP-011) — ImportFlow ERP
///
/// Comprehensive regulatory and compliance assessment hub. Orchestrates
/// the statutory 5 Pillars, advanced compliance cards (CargoX, Shelf Life,
/// Testing Labs, Hazmat), and Maker-Checker governance with an Enterprise Table.
class ImportRequirementsScreen extends ConsumerStatefulWidget {
  const ImportRequirementsScreen({super.key});

  @override
  ConsumerState<ImportRequirementsScreen> createState() => _ImportRequirementsScreenState();
}

class _ImportRequirementsScreenState extends ConsumerState<ImportRequirementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  final GlobalKey<ImportRequirementsFormTabState> _formTabKey = GlobalKey<ImportRequirementsFormTabState>();

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAllData());
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  void _refreshAllData() {
    ref.read(importRequirementsProvider.notifier).refreshData();
    ref.read(importFilesProvider.notifier).fetchImportFiles();
    ref.read(suppliersProvider.notifier).fetchSuppliers();
    ref.read(customsTariffProvider.notifier).fetchTariffs();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SelectionArea(
      child: Scaffold(
        appBar: PageHeader(
          title: l10n.importRequirementsScreenTitle,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.white, size: 20),
              tooltip: l10n.refresh,
              onPressed: _refreshAllData,
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: AppTheme.charcoal,
              child: TabBar(
                controller: _mainTabController,
                indicatorColor: AppTheme.cobalt,
                indicatorWeight: 3,
                labelColor: AppTheme.white,
                unselectedLabelColor: AppTheme.cloudWhite,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.edit_note, size: 18),
                    text: l10n.importRequirementsFormTab,
                  ),
                  Tab(
                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                    text: l10n.importRequirementsRegistryTab,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _mainTabController,
                children: [
                  // Tab 0: Multi-Pillar Interactive Form
                  ImportRequirementsFormTab(
                    key: _formTabKey,
                    onSavedSuccessfully: () => _mainTabController.animateTo(1),
                    onGoToRegistryRequested: () => _mainTabController.animateTo(1),
                  ),

                  // Tab 1: Upgraded Enterprise Registry Table
                  ImportRequirementsRegistryTable(
                    onEditRequirement: (item) {
                      _mainTabController.animateTo(0);
                      _formTabKey.currentState?.loadAssessment(item);
                    },
                    onAddNewRequirement: () {
                      _mainTabController.animateTo(0);
                      _formTabKey.currentState?.resetForm();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
