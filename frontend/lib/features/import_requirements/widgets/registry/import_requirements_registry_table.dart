import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/domain_enum_labels.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../models/import_requirement_model.dart';
import '../../providers/import_requirements_provider.dart';
import '../dialogs/requirement_details_dialog.dart';
import '../governance/maker_checker_dialog.dart';

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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Obtained':
      case 'Completed':
      case 'Approved':
      case 'Cleared':
      case 'Confirmed':
      case 'Cleared for Sailing':
      case 'Sailed':
        return AppTheme.emerald;
      case 'Pending':
      case 'In Progress':
      case 'Applied':
      case 'Scheduled':
      case 'Pre-Sailing':
        return AppTheme.orange;
      case 'Rejected':
        return AppTheme.crimson;
      case 'Waived':
        return AppTheme.cobalt;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'Low':
      case 'منخفض':
        return AppTheme.emerald;
      case 'Medium':
      case 'متوسط':
        return AppTheme.orange;
      case 'High':
      case 'مرتفع':
        return AppTheme.crimson;
      default:
        return AppTheme.textMuted;
    }
  }

  String _buildRequirementSummary(AppLocalizations l10n, ImportRequirementModel req) {
    return '${req.assessmentCode} | ${req.importFileCode ?? ""} | ${req.hsCode ?? ""} | '
        '${req.commodityDescription ?? ""} | ${req.shipmentValue.toStringAsFixed(2)} ${req.currency ?? ""} | '
        '${req.supplierName ?? ""} | ${req.overallStatus} | ${req.riskLevel}';
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

  void _confirmDeleteAssessment(BuildContext context, ImportRequirementModel req) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteRequirementTitle),
        content: Text(l10n.confirmDeleteRequirementContent(req.assessmentCode, req.importFileCode ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            onPressed: () async {
              Navigator.pop(ctx);
              if (req.assessmentId != null) {
                try {
                  await ref.read(importRequirementsProvider.notifier).deleteRequirement(req.assessmentId!);
                  if (mounted) {
                    messenger.showSnackBar(
                      AppTheme.snackBar(context, l10n.deletedRequirementSuccessSnack(req.assessmentCode), severity: AppSeverity.danger),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      AppTheme.snackBar(context, e.toString(), severity: AppSeverity.danger),
                    );
                  }
                }
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: AppTheme.white)),
          ),
        ],
      ),
    );
  }

  List<EnterpriseColumn<ImportRequirementModel>> _buildColumns(
    BuildContext context,
    AppLocalizations l10n,
    List<dynamic> importFiles,
  ) {
    return [
      EnterpriseColumn<ImportRequirementModel>(
        id: 'assessment_code',
        title: l10n.colAssessmentCode,
        width: 135,
        isLocked: true,
        isSortable: true,
        isSearchable: true,
        searchValue: (item) => item.assessmentCode,
        exportValue: (item) => item.assessmentCode,
        cellBuilder: (ctx, item, idx) {
          return InkWell(
            onTap: () => CopyHelper.copy(
              ctx,
              item.assessmentCode,
              customMessage: l10n.copyAssessmentCodeTooltip,
            ),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy, size: 10, color: AppTheme.cobalt),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.assessmentCode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cobalt,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'import_file',
        title: l10n.colImportFile,
        width: 170,
        isSortable: true,
        isSearchable: true,
        searchValue: (item) => '${item.importFileCode ?? ""} ${item.supplierName ?? ""}',
        exportValue: (item) => item.importFileCode ?? '',
        cellBuilder: (ctx, item, idx) {
          final matchingFile = importFiles.where((f) => f.importFileId == item.importFileId).firstOrNull;
          final fileCode = item.importFileCode ?? (matchingFile?.primaryNameWithCode ?? '-');
          final company = (matchingFile?.companyName.isNotEmpty == true && matchingFile?.companyName != 'N/A')
              ? matchingFile!.companyName
              : (item.supplierName ?? '');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                fileCode,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.charcoal),
                overflow: TextOverflow.ellipsis,
              ),
              if (company.isNotEmpty)
                Text(
                  company,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'acid_number',
        title: l10n.colAcidNumber,
        width: 130,
        isSortable: true,
        isSearchable: true,
        searchValue: (item) => item.acidNumber ?? '',
        exportValue: (item) => item.acidNumber ?? '',
        cellBuilder: (ctx, item, idx) {
          if (item.acidNumber == null || item.acidNumber!.isEmpty) {
            return const Text('-', style: TextStyle(color: AppTheme.textMuted, fontSize: 11));
          }
          return InkWell(
            onTap: () => CopyHelper.copy(
              ctx,
              item.acidNumber!,
              customMessage: l10n.copyAcidNumberTooltip,
            ),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy, size: 10, color: AppTheme.emerald),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.acidNumber!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'hs_code',
        title: l10n.colHsCodeAndCommodity,
        width: 180,
        isSortable: true,
        isSearchable: true,
        searchValue: (item) => '${item.hsCode ?? ""} ${item.commodityDescription ?? ""}',
        exportValue: (item) => '${item.hsCode ?? ""} - ${item.commodityDescription ?? ""}',
        cellBuilder: (ctx, item, idx) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.hsCode ?? '-',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.charcoal),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.commodityDescription ?? '-',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'shipment_value',
        title: l10n.colShipmentValue,
        width: 120,
        isNumeric: true,
        isSortable: true,
        sortComparator: (a, b) => a.shipmentValue.compareTo(b.shipmentValue),
        exportValue: (item) => '${item.shipmentValue.toStringAsFixed(2)} ${item.currency ?? ""}',
        cellBuilder: (ctx, item, idx) {
          return Text(
            '${item.shipmentValue.toStringAsFixed(2)} ${item.currency ?? ""}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
          );
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'compliance_pillars',
        title: l10n.colCompliancePillars,
        width: 180,
        cellBuilder: (ctx, item, idx) {
          return Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              if (item.decree43Applicable)
                _buildMiniIndicator(
                  item.whiteListVerified ? Icons.check_circle : Icons.warning_amber_rounded,
                  item.whiteListVerified ? AppTheme.emerald : AppTheme.orange,
                  l10n.pillar1Decree43Tab,
                ),
              if (item.cooRequired)
                _buildMiniIndicator(
                  Icons.public,
                  item.cooStatus == 'Obtained' ? AppTheme.emerald : AppTheme.orange,
                  l10n.pillar2CooTab,
                ),
              if (item.inspectionRequired)
                _buildMiniIndicator(
                  Icons.fact_check_outlined,
                  item.inspectionStatus == 'Completed' ? AppTheme.emerald : AppTheme.orange,
                  l10n.pillar3InspectionTab,
                ),
              if (item.importPermitRequired)
                _buildMiniIndicator(
                  Icons.verified_outlined,
                  item.permitStatus == 'Approved' ? AppTheme.emerald : AppTheme.orange,
                  l10n.pillar4PermitsTab,
                ),
              if (item.isHazmat)
                _buildMiniIndicator(
                  Icons.warning_rounded,
                  AppTheme.crimson,
                  l10n.hazardousMaterialsHeader,
                ),
            ],
          );
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'risk_level',
        title: l10n.colRiskLevel,
        width: 95,
        isSortable: true,
        sortComparator: (a, b) => a.riskLevel.compareTo(b.riskLevel),
        exportValue: (item) => item.riskLevel,
        cellBuilder: (ctx, item, idx) {
          final color = _getRiskColor(item.riskLevel);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              item.riskLevel,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'status',
        title: l10n.colStatus,
        width: 100,
        isSortable: true,
        sortComparator: (a, b) => a.overallStatus.compareTo(b.overallStatus),
        exportValue: (item) => item.overallStatus,
        cellBuilder: (ctx, item, idx) {
          final color = _getStatusColor(item.overallStatus);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              item.overallStatus,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'governance',
        title: l10n.colGovernance,
        width: 120,
        isSortable: true,
        cellBuilder: (ctx, item, idx) {
          if (item.isOverridden) {
            return _buildGovernanceBadge(
              l10n.checkerStatusOverriddenBadge,
              AppTheme.orange,
              Icons.shield_outlined,
            );
          } else if (item.checkerApproved) {
            return _buildGovernanceBadge(
              l10n.checkerStatusApprovedBadge,
              AppTheme.emerald,
              Icons.verified_outlined,
            );
          } else {
            return _buildGovernanceBadge(
              l10n.checkerStatusPendingBadge,
              AppTheme.charcoal,
              Icons.pending_outlined,
            );
          }
        },
      ),
      EnterpriseColumn<ImportRequirementModel>(
        id: 'actions',
        title: l10n.colActions,
        width: 210,
        isLocked: true,
        cellBuilder: (ctx, item, idx) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppTheme.cobalt),
                  tooltip: l10n.requirementDetailsDialogTitle,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: () => RequirementDetailsDialog.show(context, requirement: item),
                ),
                IconButton(
                  icon: const Icon(Icons.gavel_rounded, size: 16, color: AppTheme.charcoal),
                  tooltip: l10n.governanceActionTooltip,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: () => MakerCheckerDialog.show(context, requirement: item),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.cobalt),
                  tooltip: l10n.editRequirementTooltip,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: () => widget.onEditRequirement(item),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.textMuted),
                  tooltip: l10n.requirementCopySummaryBtn,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: () {
                    final summary = _buildRequirementSummary(l10n, item);
                    CopyHelper.copy(context, summary, customMessage: l10n.requirementCopySummarySuccess);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined, size: 16, color: AppTheme.emerald),
                  tooltip: l10n.printRequirementSlipBtn,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: () => MasterDataExportService.printOrSaveImportRequirementSlipPdf(context, item),
                ),
                IconButton(
                  icon: Icon(
                    item.isActive ? Icons.delete_outline : Icons.restore,
                    size: 16,
                    color: item.isActive ? AppTheme.crimson : AppTheme.emerald,
                  ),
                  tooltip: item.isActive ? l10n.deleteRequirementTooltip : l10n.restoreRequirementTooltip,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: item.isActive
                      ? () => _confirmDeleteAssessment(context, item)
                      : () async {
                          if (item.assessmentId != null) {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await ref.read(importRequirementsProvider.notifier).restoreRequirement(item.assessmentId!);
                              if (mounted) {
                                messenger.showSnackBar(
                                  AppTheme.snackBar(context, l10n.restoredRequirementSuccessSnack(item.assessmentCode), severity: AppSeverity.success),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  AppTheme.snackBar(context, e.toString(), severity: AppSeverity.danger),
                                );
                              }
                            }
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  Widget _buildMiniIndicator(IconData icon, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }

  Widget _buildGovernanceBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asyncReqs = ref.watch(importRequirementsProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Toolbar Row: Refresh, TSV, Excel, PDF, Add New
          Row(
            children: [
              AppButton(
                label: l10n.createNewRequirementBtn,
                icon: Icons.add,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: widget.onAddNewRequirement,
              ),
              const SizedBox(width: 8),
              AppButton(
                label: l10n.requirementsExportTsvBtn,
                icon: Icons.table_chart_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () {
                  final list = asyncReqs.valueOrNull ?? [];
                  _copyRequirementsTsv(context, list);
                },
              ),
              const SizedBox(width: 8),
              AppButton(
                label: l10n.requirementsExportExcelBtn,
                icon: Icons.file_download_outlined,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: () {
                  final list = asyncReqs.valueOrNull ?? [];
                  MasterDataExportService.exportImportRequirementsToExcel(context, list);
                },
              ),
              const SizedBox(width: 8),
              AppButton(
                label: l10n.requirementsExportPdfBtn,
                icon: Icons.picture_as_pdf_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () {
                  final list = asyncReqs.valueOrNull ?? [];
                  MasterDataExportService.printOrSaveImportRequirementsListPdf(context, list);
                },
              ),
              const Spacer(),
              AppButton(
                label: l10n.refresh,
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => ref.read(importRequirementsProvider.notifier).refreshData(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cloudWhite),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, val, _) {
                      return TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l10n.searchRequirementsHint,
                          prefixIcon: const Icon(Icons.search, color: AppTheme.cobalt),
                          suffixIcon: val.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.complianceStatusFilterLabel,
                    value: _statusFilter,
                    items: [
                      SearchableDropdownItem(value: 'All', label: l10n.partnerCatAll),
                      SearchableDropdownItem(value: 'Draft', label: l10n.overallStatusDraftOption),
                      SearchableDropdownItem(value: 'In Progress', label: l10n.overallStatusInProgressOption),
                      SearchableDropdownItem(value: 'Complete', label: l10n.overallStatusCompleteOption),
                      SearchableDropdownItem(value: 'Confirmed', label: l10n.overallStatusConfirmedOption),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.riskLevelFilterLabel,
                    value: _riskFilter,
                    items: [
                      SearchableDropdownItem(value: 'All', label: l10n.partnerCatAll),
                      SearchableDropdownItem(value: 'Low', label: l10n.riskLevelLowOption),
                      SearchableDropdownItem(value: 'Medium', label: l10n.riskLevelMediumOption),
                      SearchableDropdownItem(value: 'High', label: l10n.riskLevelHighOption),
                    ],
                    onChanged: (v) => setState(() => _riskFilter = v ?? 'All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SearchableDropdownField<String>(
                    labelText: l10n.activeDeletedFilterLabel,
                    value: _activeFilter,
                    items: [
                      SearchableDropdownItem(value: 'All', label: l10n.allRecordsActiveAndDeleted),
                      SearchableDropdownItem(value: 'Active', label: l10n.activeOnlyOption),
                      SearchableDropdownItem(value: 'Deleted', label: l10n.deletedOnlyOption),
                    ],
                    onChanged: (v) => setState(() => _activeFilter = v ?? 'Active'),
                  ),
                ),
              ],
            ),
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
                  columns: _buildColumns(context, l10n, importFiles),
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
    );
  }
}
