import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../models/import_company_model.dart';
import '../providers/import_companies_provider.dart';

/// شريط أدوات الفلترة والبحث والإجراءات السريعة للشركات المستوردة
class ImportCompaniesFilterToolbar extends ConsumerWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddCompany;
  final VoidCallback onExtractAi;
  final VoidCallback onCopyTsv;
  final VoidCallback onRefresh;

  const ImportCompaniesFilterToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAddCompany,
    required this.onExtractAi,
    required this.onCopyTsv,
    required this.onRefresh,
  });

  static void copyCompaniesTsv(BuildContext context, List<ImportCompanyModel> companies) {
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
        c.maskedNafezaToken ?? (c.hasNafezaToken ? '****' : '-'),
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

  static String buildCompanySummary(BuildContext context, ImportCompanyModel c) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showInactive = ref.watch(showInactiveCompaniesProvider);
    final companiesAsync = ref.watch(importCompaniesProvider);
    final companiesList = companiesAsync.valueOrNull ?? [];

    return ActionToolbar(
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
          onPressed: onAddCompany,
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
          onPressed: onExtractAi,
        ),
      ],
      moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
        context: context,
        includeTsv: companiesList.isNotEmpty,
      ),
      onMoreActionSelected: (val) => MasterDataActionHelper.handleStandardAction(
        context: context,
        ref: ref,
        actionValue: val,
        moduleEndpoint: 'import-companies',
        entityNameAr: 'الشركات المستوردة',
        entityNameEn: 'Import Companies',
        entityFilePrefix: 'Egyptian_Import_Companies',
        onImportSuccess: onRefresh,
        onCopyTsv: onCopyTsv,
      ),
      searchController: searchController,
      searchHint: l10n.searchImporterHint,
      onSearchChanged: onSearchChanged,
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
                activeThumbColor: AppTheme.cobalt,
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
          onPressed: onRefresh,
        ),
        if (companiesList.isNotEmpty)
          IconButton(
            icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
            tooltip: l10n.importCompaniesExportTsvBtn,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: density.buttonHeight,
              minHeight: density.buttonHeight,
            ),
            onPressed: onCopyTsv,
          ),
      ],
    );
  }
}
