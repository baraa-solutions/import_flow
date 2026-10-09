import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/action_toolbar.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';
import '../../../core/widgets/change_diff_dialog.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/row_context_menu.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../models/import_company_model.dart';
import '../providers/import_companies_provider.dart';
import '../widgets/import_company_details_dialog.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../audit_logs/widgets/row_history_dialog.dart';

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

  void _copyCompaniesTsv(List<ImportCompanyModel> companies) {
    final l10n = context.l10n;
    final headers = [
      l10n.importCompaniesTsvHeaderCode,
      l10n.importCompaniesTsvHeaderName,
      l10n.importCompaniesTsvHeaderImporterCard,
      l10n.importCompaniesTsvHeaderImporterCardExpiry,
      l10n.importCompaniesTsvHeaderVatId,
      l10n.importCompaniesTsvHeaderVatExpiry,
      l10n.importCompaniesTsvHeaderComReg,
      l10n.importCompaniesTsvHeaderComRegExpiry,
      l10n.importCompaniesTsvHeaderCountry,
      l10n.importCompaniesTsvHeaderAddress,
      l10n.importCompaniesTsvHeaderPhone,
      'Mobile',
      'Fax',
      'Primary Email',
      'Secondary Email',
      'Website',
      'Nafeza Token',
      'WIPO Madrid',
      'EUIPO',
      'Global Brand',
      'ISO 9001',
      l10n.importCompaniesTsvHeaderStatus,
      l10n.importCompaniesTsvHeaderNotes,
    ];

    final rows = companies.map((c) {
      final codeText = c.companyId?.toString() ?? '-';
      final statusText = c.isActive ? l10n.statusActive : l10n.statusInactive;
      final countryText = c.country.isNotEmpty ? c.country : l10n.egyptCountryFallback;
      final phoneText = c.phone ?? '-';
      final notesText = (c.notes != null && c.notes!.trim().isNotEmpty) ? c.notes!.trim() : '-';

      return [
        codeText,
        c.importerName,
        c.importerId,
        c.importerIdExpiry.toIso8601String().split('T')[0],
        c.vatId,
        c.vatIdExpiry.toIso8601String().split('T')[0],
        c.registrationNumber,
        c.registrationExpiry.toIso8601String().split('T')[0],
        countryText,
        c.address,
        phoneText,
        c.mobileNumber ?? '-',
        c.faxNumber ?? '-',
        c.primaryEmail ?? '-',
        c.secondaryEmail ?? '-',
        c.website ?? '-',
        (c.nafezaToken != null && c.nafezaToken!.isNotEmpty) ? '****${c.nafezaToken!.length > 4 ? c.nafezaToken!.substring(c.nafezaToken!.length - 4) : c.nafezaToken!}' : '-',
        c.hasWipo ? (c.wipoNumber ?? 'Yes') : 'No',
        c.hasEuipo ? (c.euipoNumber ?? 'Yes') : 'No',
        c.hasGlobalBrand ? (c.globalBrandNumber ?? 'Yes') : 'No',
        c.hasIso9001 ? (c.iso9001Number ?? 'Yes') : 'No',
        statusText,
        notesText,
      ].join('\t');
    }).join('\n');

    final tsv = '${headers.join('\t')}\n$rows';
    CopyHelper.copy(context, tsv, customMessage: l10n.importCompaniesExportTsvSuccess);
  }

  String _buildCompanySummary(ImportCompanyModel c) {
    final l10n = context.l10n;
    final statusText = c.isActive ? l10n.statusActive : l10n.statusInactive;
    final countryText = c.country.isNotEmpty ? c.country : l10n.egyptCountryFallback;
    return [
      '${l10n.companyNameLabel.replaceAll('*', '').trim()}: ${c.importerName}',
      if (c.companyId != null) '${l10n.importCompaniesTsvHeaderCode}: ${c.companyId}',
      '${l10n.statusCol}: $statusText',
      '${l10n.importerCardIdRowLabel}: ${c.importerId} (${l10n.expiryDateLabel(c.importerIdExpiry.toIso8601String().split('T')[0])})',
      '${l10n.vatTaxIdRowLabel}: ${c.vatId} (${l10n.expiryDateLabel(c.vatIdExpiry.toIso8601String().split('T')[0])})',
      '${l10n.commercialRegRowLabel}: ${c.registrationNumber} (${l10n.expiryDateLabel(c.registrationExpiry.toIso8601String().split('T')[0])})',
      '${l10n.countryRowLabel}: $countryText',
      '${l10n.addressRowLabel}: ${c.address}',
      if (c.phone != null && c.phone!.isNotEmpty) '${l10n.phoneRowLabel}: ${c.phone}',
      if (c.mobileNumber != null && c.mobileNumber!.isNotEmpty) 'Mobile: ${c.mobileNumber}',
      if (c.faxNumber != null && c.faxNumber!.isNotEmpty) 'Fax: ${c.faxNumber}',
      if (c.primaryEmail != null && c.primaryEmail!.isNotEmpty) '${l10n.emailRowLabel}: ${c.primaryEmail}',
      if (c.secondaryEmail != null && c.secondaryEmail!.isNotEmpty) 'Secondary Email: ${c.secondaryEmail}',
      if (c.website != null && c.website!.isNotEmpty) 'Website: ${c.website}',
      if (c.hasWipo) 'WIPO Madrid: ${c.wipoNumber ?? 'Yes'}',
      if (c.hasEuipo) 'EUIPO: ${c.euipoNumber ?? 'Yes'}',
      if (c.hasGlobalBrand) 'Global Brand DB: ${c.globalBrandNumber ?? 'Yes'}',
      if (c.hasIso9001) 'ISO 9001: ${c.iso9001Number ?? 'Yes'}',
      if (c.notes != null && c.notes!.isNotEmpty) '${l10n.administrativeNotesHeader}: ${c.notes}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final companiesAsync = ref.watch(importCompaniesProvider);
    final showInactive = ref.watch(showInactiveCompaniesProvider);

    final density = ref.watch(displayDensityProvider);
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
              ActionToolbar(
                primaryActions: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.add_business, size: density.buttonIconSize),
                    label: Text(
                      l10n.addImporterCompanyBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => _showCompanyDialog(context),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, density.buttonHeight),
                      padding: density.buttonPadding,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: Icon(Icons.auto_awesome_rounded, size: density.buttonIconSize),
                    label: Text(
                      l10n.aiCodeCompanyBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => UniversalEntityExtractorDialog.showImporterExtractor(
                      context,
                      onSaved: () => ref.read(importCompaniesProvider.notifier).fetchCompanies(),
                    ),
                  ),
                ],
                moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
                  context: context,
                  includeTsv: companiesAsync.valueOrNull != null && companiesAsync.valueOrNull!.isNotEmpty,
                ),
                onMoreActionSelected: (val) {
                  switch (val) {
                    case 'export_excel':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'import-companies',
                        actionEndpoint: 'export-excel',
                        defaultFileName: 'Import_Companies_Report.xlsx',
                        dialogTitle: 'تصدير الشركات المستوردة إكسيل',
                      );
                      break;
                    case 'export_pdf':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'import-companies',
                        actionEndpoint: 'export-pdf',
                        defaultFileName: 'Import_Companies_Report.pdf',
                        dialogTitle: 'تصدير الشركات المستوردة PDF',
                      );
                      break;
                    case 'copy_tsv':
                      if (companiesAsync.valueOrNull != null) {
                        _copyCompaniesTsv(companiesAsync.valueOrNull!);
                      }
                      break;
                    case 'download_template':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'import-companies',
                        actionEndpoint: 'excel-template',
                        defaultFileName: 'Import_Companies_Template.xlsx',
                        dialogTitle: 'تنزيل نموذج الشركات المستوردة',
                      );
                      break;
                    case 'import_excel':
                      MasterDataActionHelper.importExcel(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'import-companies',
                        onImportSuccess: () => ref.read(importCompaniesProvider.notifier).fetchCompanies(),
                      );
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: l10n.searchImporterHint,
                onSearchChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
                filters: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.includeDeactivatedLabel,
                        style: TextStyle(
                          fontSize: density.buttonFontSize - 1,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: showInactive,
                          activeColor: AppTheme.cobalt,
                          onChanged: (val) {
                            ref.read(showInactiveCompaniesProvider.notifier).state = val;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                quickDataActions: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
                    tooltip: l10n.liveRefresh,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: density.buttonHeight,
                      minHeight: density.buttonHeight,
                    ),
                    onPressed: () => ref.read(importCompaniesProvider.notifier).fetchCompanies(),
                  ),
                  if (companiesAsync.valueOrNull != null && companiesAsync.valueOrNull!.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                      tooltip: l10n.importCompaniesExportTsvBtn,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: density.buttonHeight,
                        minHeight: density.buttonHeight,
                      ),
                      onPressed: () => _copyCompaniesTsv(companiesAsync.valueOrNull!),
                    ),
                ],
              ),
              const SizedBox(height: 8),

            // Data Table Content
            Expanded(
              child: companiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.cobalt)),
                error: (err, stack) => Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.crimson),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            l10n.importersFetchError(err.toString()),
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(l10n.retryConnectionBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            ref.read(importCompaniesProvider.notifier).fetchCompanies();
                          },
                        ),
                      ],
                    ),
                  ),
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
                    return Center(
                      child: Text(l10n.noImportCompaniesFound, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final company = filtered[index];
                        return _buildCompanyRow(company);
                      },
                    ),
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

  Widget _buildCompanyRow(ImportCompanyModel company) {
    final l10n = context.l10n;
    final isActive = company.isActive;

    return GestureDetector(
      onSecondaryTapDown: (details) {
        RowContextMenuHelper.showContextMenu(
          context: context,
          globalPosition: details.globalPosition,
          codeToCopy: company.importerId,
          onEdit: () => _showCompanyDialog(context, company),
          onHistory: () => RowHistoryDialog.show(
            context,
            entityType: 'ImportCompany',
            entityId: company.companyId!,
            entityTitle: company.importerName,
          ),
          isActive: isActive,
          onToggleActive: () async {
            if (company.companyId != null) {
              await ref.read(importCompaniesProvider.notifier).toggleActiveStatus(company.companyId!, isActive);
            }
          },
        );
      },
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              // Quick Copy Summary Button
              Tooltip(
                message: l10n.importCompanyCopySummaryBtn,
                child: IconButton(
                  icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.cobalt),
                  onPressed: () {
                    final summary = _buildCompanySummary(company);
                    CopyHelper.copy(context, summary, customMessage: l10n.importCompanyCopySummarySuccess);
                  },
                ),
              ),
              const SizedBox(width: 4),

              // Standard 4-Action Row Pill: View, Edit, Print, Delete
              RowActionsPill(
                onView: () => ImportCompanyDetailsDialog.show(
                  context,
                  company,
                  onEdit: () => _showCompanyDialog(context, company),
                ),
                onEdit: () => _showCompanyDialog(context, company),
                onPrint: () => MasterDataExportService.printOrSaveImporterPdf(company),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.confirmActionTitle),
                      content: Text(isActive
                          ? l10n.confirmDeactivateCompany(company.importerName)
                          : l10n.confirmActivateCompany(company.importerName)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppTheme.crimson : AppTheme.emerald),
                          child: Text(isActive ? l10n.deactivateBtn : l10n.activateBtn, style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && company.companyId != null) {
                    ref.read(importCompaniesProvider.notifier).toggleActiveStatus(company.companyId!, isActive);
                  }
                },
                deleteTooltip: isActive ? l10n.deactivateCompanyTooltip : l10n.activateCompanyTooltip,
              ),
              const SizedBox(width: 8),
              // Icon Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isActive ? AppTheme.cobalt : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.business, color: isActive ? AppTheme.cobalt : Colors.grey),
              ),
              const SizedBox(width: 16),

              // Name & Status Badge
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: SelectableText(
                            company.importerName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isActive ? AppTheme.charcoal : Colors.grey.shade700,
                              decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: l10n.importCompaniesCopyFieldTooltip,
                          child: InkWell(
                            onTap: () => CopyHelper.copy(context, company.importerName),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Active/Deactive Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isActive ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? l10n.statusActive : l10n.statusInactive,
                            style: TextStyle(
                              color: isActive ? AppTheme.emerald : AppTheme.crimson,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildCopyableIdBadge(
                          context: context,
                          label: l10n.importerCardIdLabelShort,
                          value: company.importerId,
                          icon: Icons.badge_outlined,
                        ),
                        _buildCopyableIdBadge(
                          context: context,
                          label: l10n.vatTaxIdLabelShort,
                          value: company.vatId,
                          icon: Icons.receipt_long_outlined,
                        ),
                        _buildCopyableIdBadge(
                          context: context,
                          label: l10n.commercialRegLabelShort,
                          value: company.registrationNumber,
                          icon: Icons.app_registration_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Expiry Cards
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildExpiryBadge(company.daysUntilImporterIdExpiry, l10n.badgeImportId),
                    const SizedBox(height: 4),
                    _buildExpiryBadge(company.daysUntilVatExpiry, l10n.badgeVatExpiry),
                    const SizedBox(height: 4),
                    _buildExpiryBadge(company.daysUntilRegExpiry, l10n.badgeComReg),
                  ],
                ),
              ),


            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryBadge(int daysLeft, String label) {
    final l10n = context.l10n;
    Color bg;
    Color fg;
    String statusText;

    if (daysLeft < 0) {
      bg = AppTheme.crimson.withOpacity(0.15);
      fg = AppTheme.crimson;
      statusText = l10n.expiryExpired;
    } else if (daysLeft <= 30) {
      bg = AppTheme.orange.withOpacity(0.15);
      fg = AppTheme.orange;
      statusText = l10n.expiryDaysLeft(daysLeft);
    } else {
      bg = AppTheme.emerald.withOpacity(0.15);
      fg = AppTheme.emerald;
      statusText = l10n.expiryValidDays(daysLeft);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        '$label: $statusText',
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCopyableIdBadge({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.cobalt),
          const SizedBox(width: 4),
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
          if (value.isNotEmpty && value != '-') ...[
            const SizedBox(width: 4),
            Tooltip(
              message: '${l10n.importCompaniesCopyFieldTooltip}: $label',
              child: InkWell(
                onTap: () => CopyHelper.copy(context, value),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.copy_rounded, size: 12, color: Colors.grey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCompanyDialog(BuildContext context, [ImportCompanyModel? companyToEdit]) {
    final l10n = context.l10n;
    final isEditing = companyToEdit != null;
    final formKey = GlobalKey<FormState>();

    final nameCtrl = TextEditingController(text: companyToEdit?.importerName ?? '');
    final addressCtrl = TextEditingController(text: companyToEdit?.address ?? '');
    final countryCtrl = TextEditingController(text: companyToEdit?.country ?? '');
    final impIdCtrl = TextEditingController(text: companyToEdit?.importerId ?? '');
    final vatIdCtrl = TextEditingController(text: companyToEdit?.vatId ?? '');
    final regNumCtrl = TextEditingController(text: companyToEdit?.registrationNumber ?? '');
    final phoneCtrl = TextEditingController(text: companyToEdit?.phone ?? '');
    final mobileCtrl = TextEditingController(text: companyToEdit?.mobileNumber ?? '');
    final faxCtrl = TextEditingController(text: companyToEdit?.faxNumber ?? '');
    final emailCtrl = TextEditingController(text: companyToEdit?.primaryEmail ?? '');
    final secondaryEmailCtrl = TextEditingController(text: companyToEdit?.secondaryEmail ?? '');
    final websiteCtrl = TextEditingController(text: companyToEdit?.website ?? '');
    final nafezaTokenCtrl = TextEditingController(text: companyToEdit?.nafezaToken ?? '');
    bool obscureToken = true;

    bool hasWipo = companyToEdit?.hasWipo ?? false;
    final wipoCtrl = TextEditingController(text: companyToEdit?.wipoNumber ?? '');
    bool hasEuipo = companyToEdit?.hasEuipo ?? false;
    final euipoCtrl = TextEditingController(text: companyToEdit?.euipoNumber ?? '');
    bool hasGlobalBrand = companyToEdit?.hasGlobalBrand ?? false;
    final globalBrandCtrl = TextEditingController(text: companyToEdit?.globalBrandNumber ?? '');
    bool hasIso9001 = companyToEdit?.hasIso9001 ?? false;
    final iso9001Ctrl = TextEditingController(text: companyToEdit?.iso9001Number ?? '');

    final isSubmitting = ValueNotifier<bool>(false);

    DateTime impExpiry = companyToEdit?.importerIdExpiry ?? DateTime.now().add(const Duration(days: 365));
    DateTime vatExpiry = companyToEdit?.vatIdExpiry ?? DateTime.now().add(const Duration(days: 365));
    DateTime regExpiry = companyToEdit?.registrationExpiry ?? DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SelectionArea(
            child: SizedBox(
              width: 580,
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  // Dialog Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    decoration: const BoxDecoration(
                      color: AppTheme.charcoal,
                      borderRadius: BorderRadiusDirectional.only(topStart: Radius.circular(16), topEnd: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(isEditing ? Icons.edit : Icons.add_business, color: Colors.white, size: 22),
                            const SizedBox(width: 12),
                            Text(
                              isEditing ? l10n.editImporterCompanyTitle : l10n.addImporterCompanyTitle,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          tooltip: l10n.closeDialogTooltip,
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                  ),

                  // Dialog Form Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextField(
                              controller: nameCtrl,
                              label: l10n.companyNameLabel,
                              icon: Icons.business,
                              isRequired: true,
                              hint: l10n.companyNameHint,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                tooltip: l10n.importCompaniesCopyFieldTooltip,
                                onPressed: () => CopyHelper.copy(context, nameCtrl.text),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: addressCtrl,
                                    label: l10n.addressLabel,
                                    icon: Icons.location_on,
                                    isRequired: true,
                                    hint: l10n.addressHint,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                      tooltip: l10n.importCompaniesCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, addressCtrl.text),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: countryCtrl,
                                    label: l10n.countryLabel,
                                    icon: Icons.flag,
                                    isRequired: true,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                      tooltip: l10n.importCompaniesCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, countryCtrl.text),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          StatefulBuilder(
                            builder: (context, setDialogState) {
                              Future<void> pickDate(String type) async {
                                final initial = type == 'imp'
                                    ? impExpiry
                                    : type == 'vat'
                                        ? vatExpiry
                                        : regExpiry;
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2040),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    if (type == 'imp') impExpiry = picked;
                                    if (type == 'vat') vatExpiry = picked;
                                    if (type == 'reg') regExpiry = picked;
                                  });
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomTextField(
                                          controller: impIdCtrl,
                                          label: l10n.importerCardIdLabel,
                                          icon: Icons.badge,
                                          isRequired: true,
                                          hint: l10n.importerCardIdHint,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                            tooltip: l10n.importCompaniesCopyFieldTooltip,
                                            onPressed: () => CopyHelper.copy(context, impIdCtrl.text),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.importerCardExpiryLabel,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                            ),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () => pickDate('imp'),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.shade400),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.calendar_month, size: 18, color: AppTheme.cobalt),
                                                    const SizedBox(width: 8),
                                                    Text('${impExpiry.year}-${impExpiry.month.toString().padLeft(2, '0')}-${impExpiry.day.toString().padLeft(2, '0')}'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomTextField(
                                          controller: vatIdCtrl,
                                          label: l10n.vatRegIdLabel,
                                          icon: Icons.receipt_long,
                                          isRequired: true,
                                          hint: l10n.vatRegIdHint,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                            tooltip: l10n.importCompaniesCopyFieldTooltip,
                                            onPressed: () => CopyHelper.copy(context, vatIdCtrl.text),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.vatRegExpiryLabel,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                            ),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () => pickDate('vat'),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.shade400),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.calendar_month, size: 18, color: AppTheme.cobalt),
                                                    const SizedBox(width: 8),
                                                    Text('${vatExpiry.year}-${vatExpiry.month.toString().padLeft(2, '0')}-${vatExpiry.day.toString().padLeft(2, '0')}'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomTextField(
                                          controller: regNumCtrl,
                                          label: l10n.commercialRegNumLabel,
                                          icon: Icons.app_registration,
                                          isRequired: true,
                                          hint: l10n.commercialRegNumHint,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                            tooltip: l10n.importCompaniesCopyFieldTooltip,
                                            onPressed: () => CopyHelper.copy(context, regNumCtrl.text),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.commercialRegExpiryLabel,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                                            ),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () => pickDate('reg'),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.shade400),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.calendar_month, size: 18, color: AppTheme.cobalt),
                                                    const SizedBox(width: 8),
                                                    Text('${regExpiry.year}-${regExpiry.month.toString().padLeft(2, '0')}-${regExpiry.day.toString().padLeft(2, '0')}'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    controller: phoneCtrl,
                                    label: l10n.phoneNumberLabel,
                                    icon: Icons.phone,
                                    hint: l10n.phoneNumberHint,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                      tooltip: l10n.importCompaniesCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, phoneCtrl.text),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomTextField(
                                          controller: mobileCtrl,
                                          label: 'رقم الموبايل / Mobile Number',
                                          icon: Icons.smartphone,
                                          hint: 'e.g. +20 100 123 4567',
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                            tooltip: l10n.importCompaniesCopyFieldTooltip,
                                            onPressed: () => CopyHelper.copy(context, mobileCtrl.text),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: CustomTextField(
                                          controller: faxCtrl,
                                          label: 'رقم الفاكس / Fax Number',
                                          icon: Icons.print,
                                          hint: 'e.g. +20 2 2345 6789',
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                            tooltip: l10n.importCompaniesCopyFieldTooltip,
                                            onPressed: () => CopyHelper.copy(context, faxCtrl.text),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CustomTextField(
                                          controller: emailCtrl,
                                          label: 'البريد الإلكتروني الأساسي / Primary Email',
                                          icon: Icons.email,
                                          hint: 'info@company.com',
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                            tooltip: l10n.importCompaniesCopyFieldTooltip,
                                            onPressed: () => CopyHelper.copy(context, emailCtrl.text),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: CustomTextField(
                                          controller: secondaryEmailCtrl,
                                          label: 'البريد الإلكتروني الثانوي / Secondary Email',
                                          icon: Icons.mark_email_read_outlined,
                                          hint: 'imports@company.com',
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                            tooltip: l10n.importCompaniesCopyFieldTooltip,
                                            onPressed: () => CopyHelper.copy(context, secondaryEmailCtrl.text),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  CustomTextField(
                                    controller: websiteCtrl,
                                    label: 'الموقع الإلكتروني / Website URL',
                                    icon: Icons.language,
                                    hint: 'https://company.com',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                      tooltip: l10n.importCompaniesCopyFieldTooltip,
                                      onPressed: () => CopyHelper.copy(context, websiteCtrl.text),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.vpn_key_rounded, size: 16, color: AppTheme.cobalt),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'رمز نافذة والربط الرقمي / Nafeza E-Token',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        CustomTextField(
                                          controller: nafezaTokenCtrl,
                                          label: 'Nafeza Token (مشفر آمن)',
                                          icon: Icons.lock_outline,
                                          obscureText: obscureToken,
                                          hint: 'NFZ-TK-xxxxxxxx',
                                          suffixIcon: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(obscureToken ? Icons.visibility_off : Icons.visibility, size: 16, color: Colors.grey),
                                                tooltip: obscureToken ? 'إظهار الرمز' : 'إخفاء الرمز',
                                                onPressed: () => setDialogState(() => obscureToken = !obscureToken),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                                tooltip: l10n.importCompaniesCopyFieldTooltip,
                                                onPressed: () => CopyHelper.copy(context, nafezaTokenCtrl.text),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.verified_rounded, size: 18, color: Colors.amber.shade900),
                                            const SizedBox(width: 8),
                                            Text(
                                              'قسم شهادات العلامة التجارية والجودة / Trademark Certificates & ISO',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('WIPO Madrid Monitor (شهادة وايپو مدريد)'),
                                          value: hasWipo,
                                          activeColor: AppTheme.cobalt,
                                          onChanged: (val) => setDialogState(() => hasWipo = val ?? false),
                                        ),
                                        if (hasWipo) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: CustomTextField(
                                              controller: wipoCtrl,
                                              label: 'رقم تسجيل WIPO Madrid / Registration No.',
                                              icon: Icons.numbers,
                                              hint: 'e.g. 1234567',
                                            ),
                                          ),
                                        ],
                                        CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('EUIPO (المكتب الأوروبي للملكية الفكرية)'),
                                          value: hasEuipo,
                                          activeColor: AppTheme.cobalt,
                                          onChanged: (val) => setDialogState(() => hasEuipo = val ?? false),
                                        ),
                                        if (hasEuipo) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: CustomTextField(
                                              controller: euipoCtrl,
                                              label: 'رقم تسجيل EUIPO / European Trademark No.',
                                              icon: Icons.numbers,
                                              hint: 'e.g. 018345678',
                                            ),
                                          ),
                                        ],
                                        CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('Global Brand Database (قاعدة بيانات العلامات العالمية)'),
                                          value: hasGlobalBrand,
                                          activeColor: AppTheme.cobalt,
                                          onChanged: (val) => setDialogState(() => hasGlobalBrand = val ?? false),
                                        ),
                                        if (hasGlobalBrand) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: CustomTextField(
                                              controller: globalBrandCtrl,
                                              label: 'معرف العلامة في Global Brand DB',
                                              icon: Icons.numbers,
                                              hint: 'e.g. GBD-987654',
                                            ),
                                          ),
                                        ],
                                        CheckboxListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text('ISO 9001 Certificate (شهادة نظام إدارة الجودة)'),
                                          value: hasIso9001,
                                          activeColor: AppTheme.cobalt,
                                          onChanged: (val) => setDialogState(() => hasIso9001 = val ?? false),
                                        ),
                                        if (hasIso9001) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: CustomTextField(
                                              controller: iso9001Ctrl,
                                              label: 'رقم شهادة ISO 9001 Certificate No.',
                                              icon: Icons.verified_user_outlined,
                                              hint: 'e.g. ISO-9001-2015-XYZ',
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Dialog Action Buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadiusDirectional.only(bottomStart: Radius.circular(16), bottomEnd: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.crimson,
                          side: BorderSide(color: Colors.red.shade300),
                        ),
                        onPressed: () => Navigator.pop(dialogCtx),
                        icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
                        label: Text(l10n.cancelAndCloseBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: isSubmitting,
                        builder: (context, submitting, child) {
                          return ElevatedButton.icon(
                            icon: submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: Text(isEditing ? l10n.updateCompanyBtn : l10n.saveCompanyBtn),
                            onPressed: submitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }

                                    isSubmitting.value = true;
                                    try {
                                      final company = ImportCompanyModel(
                                        companyId: companyToEdit?.companyId,
                                        importerName: nameCtrl.text.trim(),
                                        address: addressCtrl.text.trim(),
                                        country: countryCtrl.text.trim(),
                                        importerId: impIdCtrl.text.trim(),
                                        importerIdExpiry: impExpiry,
                                        vatId: vatIdCtrl.text.trim(),
                                        vatIdExpiry: vatExpiry,
                                        registrationNumber: regNumCtrl.text.trim(),
                                        registrationExpiry: regExpiry,
                                        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                        mobileNumber: mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
                                        faxNumber: faxCtrl.text.trim().isEmpty ? null : faxCtrl.text.trim(),
                                        primaryEmail: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                        secondaryEmail: secondaryEmailCtrl.text.trim().isEmpty ? null : secondaryEmailCtrl.text.trim(),
                                        website: websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim(),
                                        nafezaToken: nafezaTokenCtrl.text.trim().isEmpty ? null : nafezaTokenCtrl.text.trim(),
                                        hasWipo: hasWipo,
                                        wipoNumber: hasWipo && wipoCtrl.text.trim().isNotEmpty ? wipoCtrl.text.trim() : null,
                                        hasEuipo: hasEuipo,
                                        euipoNumber: hasEuipo && euipoCtrl.text.trim().isNotEmpty ? euipoCtrl.text.trim() : null,
                                        hasGlobalBrand: hasGlobalBrand,
                                        globalBrandNumber: hasGlobalBrand && globalBrandCtrl.text.trim().isNotEmpty ? globalBrandCtrl.text.trim() : null,
                                        hasIso9001: hasIso9001,
                                        iso9001Number: hasIso9001 && iso9001Ctrl.text.trim().isNotEmpty ? iso9001Ctrl.text.trim() : null,
                                        isActive: companyToEdit?.isActive ?? true,
                                      );

                                      String? errorMessage;
                                      if (isEditing && companyToEdit.companyId != null) {
                                        final List<FieldChangeItem> changes = [];
                                        if (FieldChangeItem.isDifferent(companyToEdit.importerName, company.importerName)) {
                                          changes.add(FieldChangeItem(fieldName: l10n.diffCompanyName, oldValue: companyToEdit.importerName, newValue: company.importerName));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.importerId, company.importerId)) {
                                          changes.add(FieldChangeItem(fieldName: l10n.diffImporterCardId, oldValue: companyToEdit.importerId, newValue: company.importerId));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.importerIdExpiry.toString().substring(0, 10), company.importerIdExpiry.toString().substring(0, 10))) {
                                          changes.add(FieldChangeItem(fieldName: l10n.diffImporterCardExpiry, oldValue: companyToEdit.importerIdExpiry.toString().substring(0, 10), newValue: company.importerIdExpiry.toString().substring(0, 10)));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.vatId, company.vatId)) {
                                          changes.add(FieldChangeItem(fieldName: l10n.diffVatId, oldValue: companyToEdit.vatId, newValue: company.vatId));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.registrationNumber, company.registrationNumber)) {
                                          changes.add(FieldChangeItem(fieldName: l10n.diffCommercialReg, oldValue: companyToEdit.registrationNumber, newValue: company.registrationNumber));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.address, company.address)) {
                                          changes.add(FieldChangeItem(fieldName: l10n.diffAddress, oldValue: companyToEdit.address, newValue: company.address));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.phone, company.phone)) {
                                          changes.add(FieldChangeItem(fieldName: l10n.diffPhone, oldValue: companyToEdit.phone, newValue: company.phone));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.primaryEmail, company.primaryEmail)) {
                                          changes.add(FieldChangeItem(fieldName: 'البريد الإلكتروني الأساسي', oldValue: companyToEdit.primaryEmail ?? '—', newValue: company.primaryEmail ?? '—'));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.website, company.website)) {
                                          changes.add(FieldChangeItem(fieldName: 'الموقع الإلكتروني', oldValue: companyToEdit.website ?? '—', newValue: company.website ?? '—'));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.hasWipo, company.hasWipo)) {
                                          changes.add(FieldChangeItem(fieldName: 'WIPO Madrid', oldValue: companyToEdit.hasWipo ? 'نعم' : 'لا', newValue: company.hasWipo ? 'نعم' : 'لا'));
                                        }
                                        if (FieldChangeItem.isDifferent(companyToEdit.hasIso9001, company.hasIso9001)) {
                                          changes.add(FieldChangeItem(fieldName: 'ISO 9001', oldValue: companyToEdit.hasIso9001 ? 'نعم' : 'لا', newValue: company.hasIso9001 ? 'نعم' : 'لا'));
                                        }

                                        if (changes.isNotEmpty) {
                                          final confirmed = await showChangeDiffConfirmationDialog(
                                            context,
                                            title: l10n.diffConfirmCompanyTitle,
                                            itemReference: companyToEdit.importerName,
                                            changes: changes,
                                          );
                                          if (!confirmed) return;
                                        }

                                        errorMessage = await ref.read(importCompaniesProvider.notifier).updateCompany(companyToEdit.companyId!, company);
                                      } else {
                                        errorMessage = await ref.read(importCompaniesProvider.notifier).createCompany(company);
                                      }

                                      if (errorMessage == null) {
                                        if (context.mounted) {
                                          Navigator.pop(dialogCtx);
                                        }
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              backgroundColor: AppTheme.crimson,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    } finally {
                                      isSubmitting.value = false;
                                    }
                                  },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    ).then((_) {
      isSubmitting.dispose();
      nameCtrl.dispose();
      addressCtrl.dispose();
      countryCtrl.dispose();
      impIdCtrl.dispose();
      vatIdCtrl.dispose();
      regNumCtrl.dispose();
      phoneCtrl.dispose();
    });
  }
}
