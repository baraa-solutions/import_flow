import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/export/widgets/export_language_dialog.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../audit_logs/widgets/row_history_dialog.dart';
import '../models/import_company_model.dart';
import '../providers/import_companies_provider.dart';
import '../widgets/import_companies_data_table.dart';
import '../widgets/import_companies_filter_toolbar.dart';
import '../widgets/import_company_details_dialog.dart';
import '../widgets/import_company_form_dialog.dart';

/// الشاشة الرئيسية المنسقة للشركات المستوردة المصرية
class ImportCompaniesScreen extends ConsumerStatefulWidget {
  const ImportCompaniesScreen({super.key});

  @override
  ConsumerState<ImportCompaniesScreen> createState() => _ImportCompaniesScreenState();
}

class _ImportCompaniesScreenState extends ConsumerState<ImportCompaniesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final companiesState = ref.read(importCompaniesProvider);
      if (!companiesState.isLoading) {
        ref.read(importCompaniesProvider.notifier).fetchCompanies();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleToggleActive(ImportCompanyModel company) async {
    final l10n = context.l10n;
    final isActive = company.isActive;
    final confirm = await AppConfirmDialog.showToggleActive(
      context,
      isCurrentlyActive: isActive,
      entityName: company.importerName,
      message: isActive
          ? l10n.confirmDeactivateCompany(company.importerName)
          : l10n.confirmActivateCompany(company.importerName),
    );
    if (confirm == true && company.companyId != null) {
      await ref.read(importCompaniesProvider.notifier).toggleActiveStatus(company.companyId!, isActive);
    }
  }

  Future<void> _handlePrint(ImportCompanyModel company) async {
    final lang = await ExportLanguageDialog.show(context);
    if (lang != null) {
      await MasterDataExportService.printOrSaveImporterPdf(company, lang: lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final companiesAsync = ref.watch(importCompaniesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkScaffoldBackground : AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.business,
        title: l10n.importCompaniesScreenTitle,
        subtitle: l10n.importCompaniesScreenSubtitle,
        actions: const [
          BackToDashboardButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImportCompaniesFilterToolbar(
                searchController: _searchController,
                onSearchChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
                onAddCompany: () => ImportCompanyFormDialog.show(context),
                onExtractAi: () => UniversalEntityExtractorDialog.showImporterExtractor(
                  context,
                  onSaved: () => ref.read(importCompaniesProvider.notifier).fetchCompanies(),
                ),
                onCopyTsv: () {
                  final list = companiesAsync.valueOrNull;
                  if (list != null && list.isNotEmpty) {
                    ImportCompaniesFilterToolbar.copyCompaniesTsv(context, list);
                  }
                },
                onRefresh: () => ref.read(importCompaniesProvider.notifier).fetchCompanies(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: companiesAsync.when(
                  loading: () => const AppLoadingState(),
                  error: (err, stack) => AppErrorState(
                    message: l10n.importersFetchError(err.toString()),
                    onRetry: () => ref.read(importCompaniesProvider.notifier).fetchCompanies(),
                  ),
                  data: (companies) {
                    final filtered = companies.where((c) {
                      return c.importerName.toLowerCase().contains(_searchQuery) ||
                          c.importerId.toLowerCase().contains(_searchQuery) ||
                          c.registrationNumber.toLowerCase().contains(_searchQuery) ||
                          (c.primaryEmail != null && c.primaryEmail!.toLowerCase().contains(_searchQuery)) ||
                          (c.secondaryEmail != null && c.secondaryEmail!.toLowerCase().contains(_searchQuery)) ||
                          (c.phone != null && c.phone!.toLowerCase().contains(_searchQuery)) ||
                          (c.mobileNumber != null && c.mobileNumber!.toLowerCase().contains(_searchQuery)) ||
                          (c.website != null && c.website!.toLowerCase().contains(_searchQuery));
                    }).toList();

                    if (filtered.isEmpty) {
                      return AppEmptyState(
                        message: l10n.noImportCompaniesFound,
                        icon: Icons.business_outlined,
                      );
                    }

                    return ImportCompaniesDataTable(
                      companies: filtered,
                      onView: (c) => ImportCompanyDetailsDialog.show(
                        context,
                        c,
                        onEdit: () => ImportCompanyFormDialog.show(context, c),
                      ),
                      onEdit: (c) => ImportCompanyFormDialog.show(context, c),
                      onPrint: _handlePrint,
                      onToggleActive: _handleToggleActive,
                      onHistory: (c) {
                        RowHistoryDialog.show(
                          context,
                          entityType: 'ImportCompany',
                          entityId: c.companyId!,
                          entityTitle: c.importerName,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
