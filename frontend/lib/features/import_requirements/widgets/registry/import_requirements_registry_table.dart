import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/import_requirement_model.dart';
import '../../providers/import_requirements_provider.dart';
import 'import_requirements_columns.dart';
import 'import_requirements_filter_bar.dart';
import 'import_requirements_toolbar.dart';

/// 📊 Import Requirements Enterprise Registry Table — ImportFlow ERP
///
/// Upgraded Enterprise-grade Data Table with column preferences,
/// sorting, searching, multi-status filters, TSV/Excel exports,
/// and integrated maker-checker governance triggers.
class ImportRequirementsRegistryTable extends ConsumerStatefulWidget {
  final ValueChanged<ImportRequirementModel> onEditRequirement;
  final VoidCallback onAddNewRequirement;

  const ImportRequirementsRegistryTable({
    super.key,
    required this.onEditRequirement,
    required this.onAddNewRequirement,
  });

  @override
  ConsumerState<ImportRequirementsRegistryTable> createState() => _ImportRequirementsRegistryTableState();
}

class _ImportRequirementsRegistryTableState extends ConsumerState<ImportRequirementsRegistryTable> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  String _riskFilter = 'All';
  String _activeFilter = 'Active';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _copyRequirementsTsv(BuildContext context, List<ImportRequirementModel> reqs) {
    final l10n = context.l10n;
    if (reqs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.noRequirementsFound),
      );
      return;
    }
    final headers = [
      l10n.requirementsTsvHeaderCode,
      l10n.requirementsTsvHeaderFileCode,
      l10n.colAcidNumber,
      l10n.requirementsTsvHeaderHsCode,
      l10n.requirementsTsvHeaderCommodity,
      l10n.requirementsTsvHeaderSupplier,
      l10n.requirementsTsvHeaderOrigin,
      l10n.requirementsTsvHeaderValue,
      l10n.requirementsTsvHeaderCurrency,
      l10n.requirementsTsvHeaderDecree43,
      l10n.requirementsTsvHeaderCoo,
      l10n.requirementsTsvHeaderInspection,
      l10n.requirementsTsvHeaderPermit,
      l10n.requirementsTsvHeaderTechCerts,
      l10n.requirementsTsvHeaderSailingStatus,
      l10n.requirementsTsvHeaderOverallStatus,
      l10n.requirementsTsvHeaderRiskLevel,
      l10n.requirementsTsvHeaderAssessedBy,
      l10n.requirementsTsvHeaderNotes,
    ];
    final rows = reqs.map((req) {
      return [
        req.assessmentCode,
        req.importFileCode ?? '',
        req.acidNumber ?? '',
        req.hsCode ?? '',
        (req.commodityDescription ?? '').replaceAll('\t', ' ').replaceAll('\n', ' '),
        req.supplierName ?? '',
        req.countryOfOrigin ?? '',
        req.shipmentValue.toStringAsFixed(2),
        req.currency ?? '',
        req.decree43Applicable
            ? (req.whiteListVerified
                ? (req.factoryRegistrationNo ?? 'Registered')
                : (req.decree43Action ?? 'Non-compliant'))
            : 'N/A',
        req.cooRequired ? '${req.cooType ?? "COO"} (${req.cooStatus})' : 'N/A',
        req.inspectionRequired ? '${req.inspectionBody ?? "Inspection"} (${req.inspectionStatus})' : 'N/A',
        req.importPermitRequired
            ? '${DomainEnums.label(l10n, DomainEnumType.regulatoryBody, req.permitIssuingAuthority, fallback: "Authority")} (${req.permitStatus})'
            : 'N/A',
        req.isPostAcidConfirmed ? 'Confirmed' : req.sailingStatus,
        req.sailingStatus,
        req.overallStatus,
        req.riskLevel,
        req.assessedBy,
        (req.assessmentNotes ?? '').replaceAll('\t', ' ').replaceAll('\n', ' '),
      ].join('\t');
    }).toList();

    final tsv = [headers.join('\t'), ...rows].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.requirementsExportTsvSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asyncReqs = ref.watch(importRequirementsProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Toolbar Row: Add, TSV, Excel, PDF, Refresh
            ImportRequirementsToolbar(
              onAddNewRequirement: widget.onAddNewRequirement,
              requirements: asyncReqs.valueOrNull ?? [],
              onRefresh: () => ref.read(importRequirementsProvider.notifier).refreshData(),
              onCopyTsv: _copyRequirementsTsv,
            ),
            const SizedBox(height: 12),

            // Filters Bar
            ImportRequirementsFilterBar(
              searchController: _searchController,
              statusFilter: _statusFilter,
              riskFilter: _riskFilter,
              activeFilter: _activeFilter,
              onStatusChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
              onRiskChanged: (v) => setState(() => _riskFilter = v ?? 'All'),
              onActiveChanged: (v) => setState(() => _activeFilter = v ?? 'Active'),
              onSearchChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Enterprise Data Table
            Expanded(
              child: asyncReqs.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    l10n.requirementsFetchError(err.toString()),
                    style: const TextStyle(color: AppTheme.crimson),
                  ),
                ),
                data: (list) {
                  final filtered = list.where((item) {
                    final query = _searchController.text.trim().toLowerCase();
                    if (query.isNotEmpty) {
                      final matchCode = item.assessmentCode.toLowerCase().contains(query);
                      final matchFile = (item.importFileCode ?? '').toLowerCase().contains(query);
                      final matchHs = (item.hsCode ?? '').toLowerCase().contains(query);
                      final matchAcid = (item.acidNumber ?? '').toLowerCase().contains(query);
                      final matchSupp = (item.supplierName ?? '').toLowerCase().contains(query);
                      final matchDesc = (item.commodityDescription ?? '').toLowerCase().contains(query);
                      if (!matchCode && !matchFile && !matchHs && !matchAcid && !matchSupp && !matchDesc) {
                        return false;
                      }
                    }

                    if (_statusFilter != 'All' && item.overallStatus != _statusFilter) {
                      return false;
                    }
                    if (_riskFilter != 'All' && item.riskLevel != _riskFilter) {
                      return false;
                    }
                    if (_activeFilter == 'Active' && !item.isActive) return false;
                    if (_activeFilter == 'Deleted' && item.isActive) return false;

                    return true;
                  }).toList();

                  return EnterpriseDataTable<ImportRequirementModel>(
                    data: filtered,
                    columns: ImportRequirementsColumnsHelper.buildColumns(
                      context: context,
                      ref: ref,
                      l10n: l10n,
                      importFiles: importFiles,
                      onEditRequirement: widget.onEditRequirement,
                    ),
                    storageKey: 'import_requirements_registry_table',
                    emptyMessage: l10n.noRequirementsFound,
                    emptyIcon: Icons.folder_open,
                    enableExport: true,
                    exportFileName: 'Import_Requirements_Registry',
                    rowHeight: 46,
                    headerHeight: 42,
                    initialPageSize: 25,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
