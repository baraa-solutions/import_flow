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
import '../../../core/helpers/master_data_action_helper.dart';
import '../../../core/widgets/row_actions_pill.dart';
import '../../../core/widgets/universal_entity_extractor_dialog.dart';
import '../models/partner_model.dart';
import '../providers/partners_provider.dart';
import '../widgets/partner_details_dialog.dart';
import '../widgets/partner_statement_of_account_dialog.dart';
import '../widgets/partner_scorecard_dialog.dart';
import '../../../core/services/master_data_export_service.dart';
import '../../../core/widgets/copyable_data_helper.dart';

class PartnersScreen extends ConsumerStatefulWidget {
  const PartnersScreen({super.key});

  @override
  ConsumerState<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends ConsumerState<PartnersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Bank',
    'Shipping Line',
    'Customs Broker',
    'Freight Forwarder',
    'Inland Transport',
    'Inspection Agency',
    'Insurance Company',
  ];

  String _getCategoryLabel(BuildContext context, String cat) {
    final l10n = context.l10n;
    switch (cat) {
      case 'All':
        return l10n.partnerCatAll;
      case 'Bank':
        return l10n.partnerCatBank;
      case 'Shipping Line':
        return l10n.partnerCatShippingLine;
      case 'Customs Broker':
        return l10n.partnerCatCustomsBroker;
      case 'Freight Forwarder':
        return l10n.partnerCatFreightForwarder;
      case 'Inland Transport':
        return l10n.partnerCatInlandTransport;
      case 'Inspection Agency':
        return l10n.partnerCatInspectionAgency;
      case 'Insurance Company':
        return l10n.partnerCatInsuranceCompany;
      default:
        return cat;
    }
  }

  void _copyPartnersTsv(BuildContext context, List<PartnerModel> partners) {
    final l10n = context.l10n;
    final headers = [
      l10n.partnersTsvHeaderCode,
      l10n.partnersTsvHeaderName,
      l10n.partnersTsvHeaderCategories,
      l10n.partnersTsvHeaderCountry,
      l10n.partnersTsvHeaderAddress,
      l10n.partnersTsvHeaderPhone,
      l10n.partnersTsvHeaderMobile,
      l10n.partnersTsvHeaderFax,
      l10n.partnersTsvHeaderEmail,
      l10n.partnersTsvHeaderSecondaryEmail,
      l10n.partnersTsvHeaderWebsite,
      l10n.partnersTsvHeaderSwift,
      l10n.partnersTsvHeaderScac,
      l10n.defaultFreeDaysLabel,
      l10n.fiataLicenseLabel,
      l10n.shippingModesLabel,
      l10n.supportedCurrenciesLabel,
      l10n.inspectionAccreditationNumLabel,
      l10n.inspectionScopeLabel,
      l10n.partnersTsvHeaderLicense,
      l10n.authorizedPortsLabel,
      l10n.transportLicenseNumLabel,
      l10n.fleetTypesLabel,
      l10n.coverageAreasLabel,
      l10n.insuranceLicenseNumLabel,
      l10n.insuranceCoverageTypesLabel,
      l10n.partnersTsvHeaderCommercialReg,
      l10n.partnersTsvHeaderTaxId,
      l10n.partnersTsvHeaderStatus,
      l10n.partnersTsvHeaderNotes,
    ];
    final rows = partners.map((p) => [
      p.partnerCode,
      p.partnerName,
      p.partnerType,
      p.country,
      p.address ?? '',
      p.phone ?? '',
      p.mobile ?? '',
      p.fax ?? '',
      p.email ?? '',
      p.secondaryEmail ?? '',
      p.website ?? '',
      p.swiftCode ?? '',
      p.scacCode ?? '',
      p.defaultFreeDays != null ? '${p.defaultFreeDays}' : '',
      p.fiataId ?? '',
      p.shippingModes ?? '',
      p.supportedCurrencies ?? '',
      p.inspectionAccreditationNumber ?? '',
      p.inspectionScope ?? '',
      p.clearanceLicenseNumber ?? '',
      p.authorizedPorts ?? '',
      p.transportLicenseNumber ?? '',
      p.fleetTypes ?? '',
      p.coverageAreas ?? '',
      p.insuranceLicenseNumber ?? '',
      p.insuranceCoverageTypes ?? '',
      p.commercialRegister ?? '',
      p.taxId ?? '',
      p.isActive ? l10n.statusActive : l10n.statusInactive,
      p.notes ?? '',
    ]);
    final tsv = [
      headers.join('\t'),
      ...rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ').replaceAll('\n', ' ')).join('\t')),
    ].join('\n');
    CopyHelper.copy(context, tsv, customMessage: l10n.partnersExportTsvSuccess);
  }

  String _buildPartnerSummary(BuildContext context, PartnerModel p) {
    final l10n = context.l10n;
    final b = StringBuffer();
    b.writeln('📋 ${l10n.partnerProfileTitle}');
    b.writeln('${l10n.partnerCodeBadgeLabel}${p.partnerCode}');
    b.writeln('${l10n.partnerNameLabel}: ${p.partnerName}');
    b.writeln('${l10n.partnerCategoriesLabel}: ${p.partnerType}');
    b.writeln('${l10n.countryDetailLabel}: ${p.country}');
    if (p.address != null && p.address!.isNotEmpty) b.writeln('${l10n.fullAddressDetailLabel}: ${p.address}');
    if (p.phone != null && p.phone!.isNotEmpty) b.writeln('${l10n.partnerPhoneLabel}: ${p.phone}');
    if (p.mobile != null && p.mobile!.isNotEmpty) b.writeln('${l10n.partnerMobileLabel}: ${p.mobile}');
    if (p.email != null && p.email!.isNotEmpty) b.writeln('${l10n.emailDetailLabel}: ${p.email}');
    if (p.website != null && p.website!.isNotEmpty) b.writeln('${l10n.websiteDetailLabel}: ${p.website}');
    if (p.swiftCode != null && p.swiftCode!.isNotEmpty) b.writeln('${l10n.partnerSwiftCodeDetailLabel}: ${p.swiftCode}');
    if (p.scacCode != null && p.scacCode!.isNotEmpty) b.writeln('${l10n.partnerScacCodeDetailLabel}: ${p.scacCode}');
    if (p.defaultFreeDays != null) b.writeln('${l10n.defaultFreeDaysLabel}: ${p.defaultFreeDays}');
    if (p.fiataId != null && p.fiataId!.isNotEmpty) b.writeln('${l10n.fiataLicenseLabel}: ${p.fiataId}');
    if (p.shippingModes != null && p.shippingModes!.isNotEmpty) b.writeln('${l10n.shippingModesLabel}: ${p.shippingModes}');
    if (p.supportedCurrencies != null && p.supportedCurrencies!.isNotEmpty) b.writeln('${l10n.supportedCurrenciesLabel}: ${p.supportedCurrencies}');
    if (p.inspectionAccreditationNumber != null && p.inspectionAccreditationNumber!.isNotEmpty) b.writeln('${l10n.inspectionAccreditationNumLabel}: ${p.inspectionAccreditationNumber}');
    if (p.inspectionScope != null && p.inspectionScope!.isNotEmpty) b.writeln('${l10n.inspectionScopeLabel}: ${p.inspectionScope}');
    if (p.clearanceLicenseNumber != null && p.clearanceLicenseNumber!.isNotEmpty) b.writeln('${l10n.clearanceLicenseDetailLabel}: ${p.clearanceLicenseNumber}');
    if (p.authorizedPorts != null && p.authorizedPorts!.isNotEmpty) b.writeln('${l10n.authorizedPortsLabel}: ${p.authorizedPorts}');
    if (p.transportLicenseNumber != null && p.transportLicenseNumber!.isNotEmpty) b.writeln('${l10n.transportLicenseNumLabel}: ${p.transportLicenseNumber}');
    if (p.fleetTypes != null && p.fleetTypes!.isNotEmpty) b.writeln('${l10n.fleetTypesLabel}: ${p.fleetTypes}');
    if (p.coverageAreas != null && p.coverageAreas!.isNotEmpty) b.writeln('${l10n.coverageAreasLabel}: ${p.coverageAreas}');
    if (p.insuranceLicenseNumber != null && p.insuranceLicenseNumber!.isNotEmpty) b.writeln('${l10n.insuranceLicenseNumLabel}: ${p.insuranceLicenseNumber}');
    if (p.insuranceCoverageTypes != null && p.insuranceCoverageTypes!.isNotEmpty) b.writeln('${l10n.insuranceCoverageTypesLabel}: ${p.insuranceCoverageTypes}');
    if (p.commercialRegister != null && p.commercialRegister!.isNotEmpty) b.writeln('${l10n.commercialRegDetailLabel}: ${p.commercialRegister}');
    if (p.taxId != null && p.taxId!.isNotEmpty) b.writeln('${l10n.taxIdDetailLabel}: ${p.taxId}');
    b.writeln('${l10n.partnerStatusCol}: ${p.isActive ? l10n.statusActive : l10n.statusInactive}');
    if (p.notes != null && p.notes!.isNotEmpty) b.writeln('${l10n.additionalNotesSection}: ${p.notes}');
    return b.toString().trim();
  }

  void _openExtractorForCategory(BuildContext context, String category) {
    void onDone() {
      ref.read(partnersProvider.notifier).fetchPartners();
      ref.read(allPartnersProvider.notifier).fetchPartners();
      ref.invalidate(partnersProvider);
      ref.invalidate(allPartnersProvider);
    }

    switch (category) {
      case 'Shipping Line':
        UniversalEntityExtractorDialog.showShippingLineExtractor(
          context,
          onSaved: onDone,
        );
        break;
      case 'Customs Broker':
        UniversalEntityExtractorDialog.showCustomsBrokerExtractor(
          context,
          onSaved: onDone,
        );
        break;
      case 'Freight Forwarder':
        UniversalEntityExtractorDialog.showFreightForwarderExtractor(
          context,
          onSaved: onDone,
        );
        break;
      case 'Inland Transport':
        UniversalEntityExtractorDialog.showInlandTransportExtractor(
          context,
          onSaved: onDone,
        );
        break;
      case 'Inspection Agency':
        UniversalEntityExtractorDialog.showInspectionAgencyExtractor(
          context,
          onSaved: onDone,
        );
        break;
      case 'Insurance Company':
        UniversalEntityExtractorDialog.showInsuranceCompanyExtractor(
          context,
          onSaved: onDone,
        );
        break;
      case 'Bank':
        UniversalEntityExtractorDialog.showBankExtractor(
          context,
          onSaved: onDone,
        );
        break;
      default:
        UniversalEntityExtractorDialog.show(
          context,
          initialTarget: EntityTarget.customsBroker,
          onSaved: onDone,
        );
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!ref.read(partnersProvider).isLoading) {
      Future.microtask(() => ref.read(partnersProvider.notifier).fetchPartners());
    }
    if (!ref.read(allPartnersProvider).isLoading) {
      Future.microtask(() => ref.read(allPartnersProvider.notifier).fetchPartners());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final partnersAsync = ref.watch(partnersProvider);
    final selectedCategory = ref.watch(selectedPartnerCategoryProvider);
    final showInactive = ref.watch(showInactivePartnersProvider);
    final partnerList = partnersAsync.asData?.value ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final density = ref.watch(displayDensityProvider);

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : AppTheme.cloudWhite,
      appBar: PageHeader(
        icon: Icons.apartment,
        title: l10n.partnersScreenTitle,
        subtitle: l10n.partnersScreenSubtitle,
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
                    icon: Icon(Icons.add, size: density.buttonIconSize),
                    label: Text(
                      l10n.addExternalPartnerBtn,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => _showPartnerDialog(context),
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
                      selectedCategory == 'All'
                          ? l10n.aiCodePartnerBtn
                          : l10n.aiCodeCategoryPartner(_getCategoryLabel(context, selectedCategory)),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
                    ),
                    onPressed: () => _openExtractorForCategory(context, selectedCategory),
                  ),
                ],
                moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
                  context: context,
                  includeTsv: partnerList.isNotEmpty,
                ),
                onMoreActionSelected: (val) {
                  switch (val) {
                    case 'export_excel':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'external-service-providers',
                        actionEndpoint: 'export-excel',
                        defaultFileName: 'Partners_Banks_Report.xlsx',
                        dialogTitle: 'تصدير الشركاء والبنوك إكسيل',
                      );
                      break;
                    case 'export_pdf':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'external-service-providers',
                        actionEndpoint: 'export-pdf',
                        defaultFileName: 'Partners_Banks_Report.pdf',
                        dialogTitle: 'تصدير الشركاء والبنوك PDF',
                      );
                      break;
                    case 'copy_tsv':
                      if (partnerList.isNotEmpty) {
                        _copyPartnersTsv(context, partnerList);
                      }
                      break;
                    case 'download_template':
                      MasterDataActionHelper.downloadFile(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'external-service-providers',
                        actionEndpoint: 'excel-template',
                        defaultFileName: 'Partners_Banks_Template.xlsx',
                        dialogTitle: 'تنزيل نموذج الشركاء والبنوك',
                      );
                      break;
                    case 'import_excel':
                      MasterDataActionHelper.importExcel(
                        context: context,
                        ref: ref,
                        moduleEndpoint: 'external-service-providers',
                        onImportSuccess: () {
                          ref.read(partnersProvider.notifier).fetchPartners();
                          ref.read(allPartnersProvider.notifier).fetchPartners();
                        },
                      );
                      break;
                  }
                },
                searchController: _searchController,
                searchHint: l10n.searchPartnersHint,
                onSearchChanged: (v) {
                  setState(() {
                    _searchQuery = v.toLowerCase();
                  });
                },
                filters: [
                  // Category Dropdown Filter
                  SizedBox(
                    width: 155,
                    height: density.buttonHeight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.black26, width: 0.8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          style: TextStyle(
                            fontSize: density.buttonFontSize - 1,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                          items: _categories.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(
                              _getCategoryLabel(context, cat),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (cat) {
                            if (cat != null) {
                              ref.read(selectedPartnerCategoryProvider.notifier).state = cat;
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.showInactivePartnersLabel,
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
                            ref.read(showInactivePartnersProvider.notifier).state = val;
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
                    onPressed: () {
                      ref.read(partnersProvider.notifier).fetchPartners();
                      ref.read(allPartnersProvider.notifier).fetchPartners();
                    },
                  ),
                  if (partnerList.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: density.buttonIconSize + 2, color: AppTheme.cobalt),
                      tooltip: l10n.partnersExportTsvBtn,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: density.buttonHeight,
                        minHeight: density.buttonHeight,
                      ),
                      onPressed: () => _copyPartnersTsv(context, partnerList),
                    ),
                ],
              ),
              const SizedBox(height: 8),

            // Data Table Content
            Expanded(
              child: partnersAsync.when(
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
                            l10n.partnersFetchError.replaceAll('\$error', err.toString()),
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
                            ref.read(partnersProvider.notifier).fetchPartners();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                data: (partners) {
                  final filtered = partners.where((p) {
                    final q = _searchQuery;
                    return q.isEmpty ||
                        p.partnerName.toLowerCase().contains(q) ||
                        p.partnerCode.toLowerCase().contains(q) ||
                        (p.swiftCode?.toLowerCase().contains(q) ?? false) ||
                        (p.clearanceLicenseNumber?.toLowerCase().contains(q) ?? false) ||
                        (p.taxId?.toLowerCase().contains(q) ?? false) ||
                        p.country.toLowerCase().contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(l10n.noPartnersFound, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = constraints.maxWidth < 1350 ? 1350.0 : constraints.maxWidth;

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: Table(
                                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                  columnWidths: const {
                                    0: FixedColumnWidth(480),
                                    1: FixedColumnWidth(160),
                                    2: FlexColumnWidth(3.0),
                                    3: FlexColumnWidth(2.6),
                                    4: FlexColumnWidth(2.2),
                                    5: FixedColumnWidth(100),
                                  },
                                  children: [
                                    // Table Header
                                    TableRow(
                                      decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal),
                                      children: [
                                        l10n.partnerActionsCol,
                                        l10n.partnerCodeCol,
                                        l10n.partnerNameAndCategoryCol,
                                        l10n.registrationAndLicenseCol,
                                        l10n.contactDetailsCol,
                                        l10n.partnerStatusCol,
                                      ]
                                          .map((h) => Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                                child: Text(
                                                  h,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),

                                    // Table Data Rows
                                    ...filtered.asMap().entries.map((entry) {
                                      final partner = entry.value;
                                      final isEven = entry.key % 2 == 0;
                                      final isActive = partner.isActive;
                                      final categories = partner.categoriesList;

                                      return TableRow(
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? (isEven ? AppTheme.darkElevatedSurface : AppTheme.darkCardBackground)
                                              : (isEven ? Colors.white : Colors.grey.shade50),
                                          border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200)),
                                        ),
                                        children: [
                                          // Actions: View, Edit, Print, Delete, Statement of Account
                                          _cell(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                Tooltip(
                                                  message: l10n.partnerStatementOfAccountTooltip,
                                                  child: InkWell(
                                                    onTap: () => PartnerStatementOfAccountDialog.show(context, partner),
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                      margin: const EdgeInsetsDirectional.only(end: 6),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.cobalt.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.receipt_long, size: 14, color: AppTheme.cobalt),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            l10n.partnerStatementOfAccountBtn,
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (partner.providerId != null) ...[
                                                    const SizedBox(width: 6),
                                                    Tooltip(
                                                      message: l10n.partnerScorecardTooltip,
                                                      child: InkWell(
                                                        onTap: () => showPartnerScorecardDialog(
                                                          context,
                                                          ref,
                                                          providerId: partner.providerId!,
                                                          providerName: partner.partnerName,
                                                          providerType: partner.partnerType,
                                                        ),
                                                        borderRadius: BorderRadius.circular(6),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.shade50,
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(color: Colors.amber.shade600),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.workspace_premium_outlined, size: 14, color: Colors.amber.shade800),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                l10n.partnerScorecardBtn,
                                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  Tooltip(
                                                    message: l10n.partnerCopySummaryBtn,
                                                    child: InkWell(
                                                      onTap: () => CopyHelper.copy(
                                                        context,
                                                        _buildPartnerSummary(context, partner),
                                                        customMessage: l10n.partnerCopySummarySuccess,
                                                      ),
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                        margin: const EdgeInsetsDirectional.only(end: 6),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.emerald.withOpacity(0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.copy_all_rounded, size: 14, color: AppTheme.emerald),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              l10n.partnerCopySummaryBtn,
                                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  RowActionsPill(
                                                  onView: () => PartnerDetailsDialog.show(
                                                    context,
                                                    partner,
                                                    onEdit: () => _showPartnerDialog(context, partner),
                                                  ),
                                                  onEdit: () => _showPartnerDialog(context, partner),
                                                  onPrint: () => MasterDataExportService.printOrSavePartnerPdf(partner),
                                                  onDelete: () async {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: Text(l10n.confirmActionTitle),
                                                        content: Text(isActive
                                                            ? l10n.confirmDeactivatePartner(partner.partnerName)
                                                            : l10n.confirmActivatePartner(partner.partnerName)),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.closeBtn)),
                                                          ElevatedButton(
                                                            onPressed: () => Navigator.pop(ctx, true),
                                                            style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppTheme.crimson : AppTheme.emerald),
                                                            child: Text(isActive ? l10n.deactivateBtn : l10n.activateBtn, style: const TextStyle(color: Colors.white)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true && partner.providerId != null) {
                                                      ref.read(partnersProvider.notifier).toggleActiveStatus(partner.providerId!, isActive);
                                                    }
                                                  },
                                                  deleteTooltip: isActive ? l10n.deactivatePartnerTooltip : l10n.activatePartnerTooltip,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                          // Code
                                          _cell(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Tooltip(
                                                message: '${l10n.partnerCodeBadgeLabel}${partner.partnerCode} (${l10n.partnersCopyFieldTooltip})',
                                                child: InkWell(
                                                  onTap: () => CopyHelper.copy(
                                                    context,
                                                    partner.partnerCode,
                                                    customMessage: l10n.copiedToClipboard(partner.partnerCode),
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoal.withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withOpacity(0.15)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          partner.partnerCode,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            letterSpacing: 0.3,
                                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Icon(Icons.copy_rounded, size: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Partner Name & Categories
                                          _cell(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        partner.partnerName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                          color: isActive ? (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal) : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                                                          decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Tooltip(
                                                      message: l10n.partnersCopyFieldTooltip,
                                                      child: InkWell(
                                                        onTap: () => CopyHelper.copy(
                                                          context,
                                                          partner.partnerName,
                                                          customMessage: l10n.copiedToClipboard(partner.partnerName),
                                                        ),
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: const Padding(
                                                          padding: EdgeInsets.all(2.0),
                                                          child: Icon(Icons.copy_rounded, size: 13, color: Colors.grey),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: categories.map((cat) => _buildCategoryBadge(context, cat)).toList(),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Registration & Identifiers
                                          _cell(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (partner.swiftCode != null && partner.swiftCode!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.account_balance_outlined, size: 12, color: AppTheme.cobalt),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerSwiftLabel(partner.swiftCode!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.scacCode != null && partner.scacCode!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.directions_boat_outlined, size: 12, color: AppTheme.cobalt),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerScacLabel(partner.scacCode!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.defaultFreeDays != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.timer_outlined, size: 12, color: AppTheme.emerald),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerFreeDaysBadge(partner.defaultFreeDays!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.fiataId != null && partner.fiataId!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.badge_rounded, size: 12, color: isDark ? AppTheme.cobalt : AppTheme.charcoal),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerFiataBadge(partner.fiataId!),
                                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.cobalt : AppTheme.charcoal),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.shippingModes != null && partner.shippingModes!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.alt_route_rounded, size: 12, color: AppTheme.cobalt),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            partner.shippingModes!,
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.cobalt),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.supportedCurrencies != null && partner.supportedCurrencies!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.monetization_on_outlined, size: 12, color: AppTheme.emerald),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            partner.supportedCurrencies!,
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.inspectionAccreditationNumber != null && partner.inspectionAccreditationNumber!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.verified_user_outlined, size: 12, color: AppTheme.cobalt),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerAccreditationBadge(partner.inspectionAccreditationNumber!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.inspectionScope != null && partner.inspectionScope!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.rule_folder_outlined, size: 12, color: AppTheme.emerald),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            partner.inspectionScope!,
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.emerald),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.clearanceLicenseNumber != null && partner.clearanceLicenseNumber!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.badge_outlined, size: 12, color: AppTheme.orange),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerLicenseLabel(partner.clearanceLicenseNumber!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.authorizedPorts != null && partner.authorizedPorts!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.anchor_outlined, size: 12, color: AppTheme.orange),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerPortsBadge(partner.authorizedPorts!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.orange),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.transportLicenseNumber != null && partner.transportLicenseNumber!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.local_shipping_outlined, size: 12, color: AppTheme.emerald),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerLicenseLabel(partner.transportLicenseNumber!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.fleetTypes != null && partner.fleetTypes!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.rv_hookup, size: 12, color: AppTheme.emerald),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerFleetBadge(partner.fleetTypes!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.emerald),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.coverageAreas != null && partner.coverageAreas!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.map_outlined, size: 12, color: AppTheme.emerald),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerCoverageBadge(partner.coverageAreas!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.emerald),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.insuranceLicenseNumber != null && partner.insuranceLicenseNumber!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.verified_user_outlined, size: 12, color: AppTheme.cobalt),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerLicenseLabel(partner.insuranceLicenseNumber!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.insuranceCoverageTypes != null && partner.insuranceCoverageTypes!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.health_and_safety_outlined, size: 12, color: AppTheme.cobalt),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerInsuranceCoverageBadge(partner.insuranceCoverageTypes!),
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.cobalt),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (partner.commercialRegister != null && partner.commercialRegister!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.description_outlined, size: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            l10n.partnerRegLabel(partner.commercialRegister!),
                                                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.public, size: 12, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        l10n.partnerCountryLabel(partner.country),
                                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Contact Details
                                          _cell(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (partner.email != null && partner.email!.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 3),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.email_outlined, size: 12, color: AppTheme.cobalt),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            partner.email!,
                                                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else
                                                  Text(l10n.noEmailLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                if (partner.phone != null && partner.phone!.isNotEmpty)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          partner.phone!,
                                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                else
                                                  Text(l10n.noPhoneLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),

                                          // Status
                                          _cell(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (isActive ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: (isActive ? AppTheme.emerald : AppTheme.crimson).withOpacity(0.3),
                                                  width: 0.8,
                                                ),
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
                                          ),

                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
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

  Widget _cell({required Widget child}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Align(alignment: AlignmentDirectional.centerStart, child: child),
      );

  Widget _buildCategoryBadge(BuildContext context, String cat) {
    Color color;
    switch (cat) {
      case 'Bank':
        color = AppTheme.emerald;
        break;
      case 'Shipping Line':
        color = AppTheme.cobalt;
        break;
      case 'Customs Broker':
        color = AppTheme.orange;
        break;
      case 'Freight Forwarder':
        color = AppTheme.charcoal;
        break;
      default:
        color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        _getCategoryLabel(context, cat),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }



  void _showPartnerDialog(BuildContext context, [PartnerModel? partnerToEdit]) {
    final l10n = context.l10n;
    final isEditing = partnerToEdit != null;
    final formKey = GlobalKey<FormState>();

    final availableCategories = [
      'Bank',
      'Shipping Line',
      'Customs Broker',
      'Freight Forwarder',
      'Inland Transport',
      'Inspection Agency',
      'Insurance Company',
    ];

    final Set<String> selectedCategories = partnerToEdit != null
        ? partnerToEdit.categoriesList.toSet()
        : <String>{};

    final nameCtrl = TextEditingController(text: partnerToEdit?.partnerName ?? '');
    final taxIdCtrl = TextEditingController(text: partnerToEdit?.taxId ?? '');
    final regCtrl = TextEditingController(text: partnerToEdit?.commercialRegister ?? '');
    final licenseCtrl = TextEditingController(text: partnerToEdit?.clearanceLicenseNumber ?? '');
    final authorizedPortsCtrl = TextEditingController(text: partnerToEdit?.authorizedPorts ?? '');
    final transportLicenseCtrl = TextEditingController(text: partnerToEdit?.transportLicenseNumber ?? '');
    final fleetTypesCtrl = TextEditingController(text: partnerToEdit?.fleetTypes ?? '');
    final coverageAreasCtrl = TextEditingController(text: partnerToEdit?.coverageAreas ?? '');
    final insuranceLicenseCtrl = TextEditingController(text: partnerToEdit?.insuranceLicenseNumber ?? '');
    final insuranceCoverageCtrl = TextEditingController(text: partnerToEdit?.insuranceCoverageTypes ?? '');
    final scacCtrl = TextEditingController(text: partnerToEdit?.scacCode ?? '');
    final defaultFreeDaysCtrl = TextEditingController(
      text: partnerToEdit?.defaultFreeDays != null ? partnerToEdit!.defaultFreeDays.toString() : '',
    );
    final trackingCtrl = TextEditingController(text: partnerToEdit?.trackingUrl ?? '');
    final fiataCtrl = TextEditingController(text: partnerToEdit?.fiataId ?? '');
    final shippingModesCtrl = TextEditingController(text: partnerToEdit?.shippingModes ?? '');
    final supportedCurrenciesCtrl = TextEditingController(
      text: partnerToEdit?.supportedCurrencies ?? '',
    );
    final accreditationCtrl = TextEditingController(text: partnerToEdit?.inspectionAccreditationNumber ?? '');
    final inspectionScopeCtrl = TextEditingController(text: partnerToEdit?.inspectionScope ?? '');
    final swiftCtrl = TextEditingController(text: partnerToEdit?.swiftCode ?? '');
    final bankCodeCtrl = TextEditingController(text: partnerToEdit?.bankCode ?? '');
    final branchCtrl = TextEditingController(text: partnerToEdit?.branchName ?? '');
    final phoneCtrl = TextEditingController(text: partnerToEdit?.phone ?? '');
    final mobileCtrl = TextEditingController(text: partnerToEdit?.mobile ?? '');
    final faxCtrl = TextEditingController(text: partnerToEdit?.fax ?? '');
    final emailCtrl = TextEditingController(text: partnerToEdit?.email ?? '');
    final secondaryEmailCtrl = TextEditingController(text: partnerToEdit?.secondaryEmail ?? '');
    final websiteCtrl = TextEditingController(text: partnerToEdit?.website ?? '');
    final addressCtrl = TextEditingController(text: partnerToEdit?.address ?? '');
    final countryCtrl = TextEditingController(text: partnerToEdit?.country ?? '');

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isBank = selectedCategories.contains('Bank');
            final isShippingLine = selectedCategories.contains('Shipping Line');
            final isCustomsBroker = selectedCategories.contains('Customs Broker');
            final isFreightForwarder = selectedCategories.contains('Freight Forwarder');
            final isInspectionAgency = selectedCategories.contains('Inspection Agency');
            final isInlandTransport = selectedCategories.contains('Inland Transport');
            final isInsuranceCompany = selectedCategories.contains('Insurance Company');

            Widget buildCopySuffix(TextEditingController ctrl) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: ctrl,
                builder: (ctx, val, _) {
                  if (val.text.trim().isEmpty) return const SizedBox.shrink();
                  return Tooltip(
                    message: l10n.partnersCopyFieldTooltip,
                    child: InkWell(
                      onTap: () => CopyHelper.copy(
                        context,
                        val.text.trim(),
                        customMessage: l10n.copiedToClipboard(val.text.trim()),
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
                      ),
                    ),
                  );
                },
              );
            }

            final isDarkDialog = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDarkDialog ? AppTheme.darkCardBackground : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SelectionArea(
                child: SizedBox(
                  width: 640,
                  height: MediaQuery.of(context).size.height * 0.85,
                  child: Column(
                  children: [
                    // Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: isDarkDialog ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                        borderRadius: const BorderRadiusDirectional.only(topStart: Radius.circular(16), topEnd: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(isEditing ? Icons.edit : Icons.add_business, color: Colors.white, size: 22),
                              const SizedBox(width: 12),
                              Text(
                                isEditing ? l10n.editPartnerDialogTitle : l10n.addPartnerDialogTitle,
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

                    // Scrollable Form Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Multi-Select Partner Categories
                              Row(
                                children: [
                                  Text(
                                    l10n.partnerCategoriesLabel,
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: availableCategories.map((cat) {
                                  final isChecked = selectedCategories.contains(cat);
                                  return FilterChip(
                                    label: Text(_getCategoryLabel(context, cat)),
                                    selected: isChecked,
                                    selectedColor: AppTheme.cobalt.withOpacity(0.2),
                                    checkmarkColor: AppTheme.cobalt,
                                    labelStyle: TextStyle(
                                      color: isChecked ? AppTheme.cobalt : (isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                      fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    onSelected: (bool selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          selectedCategories.add(cat);
                                        } else {
                                          if (selectedCategories.length > 1) {
                                            selectedCategories.remove(cat);
                                          }
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),

                              CustomTextField(
                                controller: nameCtrl,
suffixIcon: buildCopySuffix(nameCtrl),
                                label: l10n.partnerNameLabel,
                                icon: Icons.business,
                                isRequired: true,
                                hint: l10n.partnerNameHint,
                              ),
                              const SizedBox(height: 16),

                              // Dynamic Category Fields
                              if (isBank) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.emerald.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('🏦 ${l10n.bankingDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomTextField(
                                              controller: swiftCtrl,
                                              textDirection: TextDirection.ltr,
suffixIcon: buildCopySuffix(swiftCtrl),
                                              label: l10n.bankSwiftCodeLabel,
                                              icon: Icons.code,
                                              isRequired: true,
                                              hint: l10n.bankSwiftCodeHint,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: CustomTextField(
                                              controller: bankCodeCtrl,
suffixIcon: buildCopySuffix(bankCodeCtrl),
                                              label: l10n.bankCodeLabel,
                                              icon: Icons.account_balance,
                                              hint: l10n.bankCodeHint,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: branchCtrl,
suffixIcon: buildCopySuffix(branchCtrl),
                                        label: l10n.branchNameLabel,
                                        icon: Icons.location_city,
                                        hint: l10n.branchNameHint,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (isShippingLine) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('🚢 ${l10n.shippingLineDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomTextField(
                                              controller: scacCtrl,
                                              suffixIcon: buildCopySuffix(scacCtrl),
                                              label: l10n.scacCarrierCodeLabel,
                                              icon: Icons.code,
                                              isRequired: true,
                                              hint: l10n.scacCarrierCodeHint,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: CustomTextField(
                                              controller: defaultFreeDaysCtrl,
                                              suffixIcon: buildCopySuffix(defaultFreeDaysCtrl),
                                              label: l10n.defaultFreeDaysLabel,
                                              icon: Icons.timer_outlined,
                                              isRequired: true,
                                              keyboardType: TextInputType.number,
                                              hint: l10n.defaultFreeDaysHint,
                                              validator: (val) {
                                                if (val == null || val.trim().isEmpty) return l10n.fieldRequired;
                                                final parsed = int.tryParse(val.trim());
                                                if (parsed == null || parsed < 0) return l10n.defaultFreeDaysHint;
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: trackingCtrl,
                                        suffixIcon: buildCopySuffix(trackingCtrl),
                                        label: l10n.trackingWebUrlLabel,
                                        icon: Icons.link,
                                        hint: l10n.trackingWebUrlHint,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (isCustomsBroker) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.orange.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('🛂 ${l10n.customsBrokerLicenseHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange)),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: licenseCtrl,
                                        suffixIcon: buildCopySuffix(licenseCtrl),
                                        label: l10n.customsClearanceLicenseNumLabel,
                                        icon: Icons.assignment_ind,
                                        isRequired: true,
                                        hint: l10n.customsClearanceLicenseNumHint,
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: authorizedPortsCtrl,
                                        suffixIcon: buildCopySuffix(authorizedPortsCtrl),
                                        label: l10n.authorizedPortsLabel,
                                        icon: Icons.anchor_outlined,
                                        hint: l10n.authorizedPortsHint,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (isFreightForwarder) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.charcoal.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.charcoal.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '📦 ${l10n.freightForwarderDetailsHeader}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkDialog ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomTextField(
                                              controller: fiataCtrl,
                                              suffixIcon: buildCopySuffix(fiataCtrl),
                                              label: l10n.fiataLicenseLabel,
                                              icon: Icons.badge_outlined,
                                              hint: l10n.fiataLicenseHint,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: CustomTextField(
                                              controller: supportedCurrenciesCtrl,
                                              suffixIcon: buildCopySuffix(supportedCurrenciesCtrl),
                                              label: l10n.supportedCurrenciesLabel,
                                              icon: Icons.monetization_on_outlined,
                                              hint: l10n.supportedCurrenciesHint,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: shippingModesCtrl,
                                        suffixIcon: buildCopySuffix(shippingModesCtrl),
                                        label: l10n.shippingModesLabel,
                                        icon: Icons.alt_route_rounded,
                                        hint: l10n.shippingModesHint,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (isInspectionAgency) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '🔬 ${l10n.inspectionAgencyDetailsHeader}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.cobalt,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: accreditationCtrl,
                                        suffixIcon: buildCopySuffix(accreditationCtrl),
                                        label: l10n.inspectionAccreditationNumLabel,
                                        icon: Icons.verified_user_outlined,
                                        isRequired: true,
                                        hint: l10n.inspectionAccreditationNumHint,
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: inspectionScopeCtrl,
                                        suffixIcon: buildCopySuffix(inspectionScopeCtrl),
                                        label: l10n.inspectionScopeLabel,
                                        icon: Icons.rule_folder_outlined,
                                        hint: l10n.inspectionScopeHint,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (isInlandTransport) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.emerald.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('🚛 ${l10n.inlandTransportDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: transportLicenseCtrl,
                                        suffixIcon: buildCopySuffix(transportLicenseCtrl),
                                        label: l10n.transportLicenseNumLabel,
                                        icon: Icons.badge_outlined,
                                        isRequired: true,
                                        hint: l10n.transportLicenseNumHint,
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: fleetTypesCtrl,
                                        suffixIcon: buildCopySuffix(fleetTypesCtrl),
                                        label: l10n.fleetTypesLabel,
                                        icon: Icons.local_shipping_outlined,
                                        isRequired: true,
                                        hint: l10n.fleetTypesHint,
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: coverageAreasCtrl,
                                        suffixIcon: buildCopySuffix(coverageAreasCtrl),
                                        label: l10n.coverageAreasLabel,
                                        icon: Icons.map_outlined,
                                        hint: l10n.coverageAreasHint,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (isInsuranceCompany) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cobalt.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.cobalt.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('🛡️ ${l10n.insuranceDetailsHeader}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: insuranceLicenseCtrl,
                                        suffixIcon: buildCopySuffix(insuranceLicenseCtrl),
                                        label: l10n.insuranceLicenseNumLabel,
                                        icon: Icons.verified_user_outlined,
                                        isRequired: true,
                                        hint: l10n.insuranceLicenseNumHint,
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        controller: insuranceCoverageCtrl,
                                        suffixIcon: buildCopySuffix(insuranceCoverageCtrl),
                                        label: l10n.insuranceCoverageTypesLabel,
                                        icon: Icons.health_and_safety_outlined,
                                        isRequired: true,
                                        hint: l10n.insuranceCoverageTypesHint,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: taxIdCtrl,
suffixIcon: buildCopySuffix(taxIdCtrl),
                                      label: l10n.partnerTaxIdLabel,
                                      icon: Icons.receipt_long,
                                      hint: l10n.partnerTaxIdHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: regCtrl,
suffixIcon: buildCopySuffix(regCtrl),
                                      label: l10n.partnerCommercialRegLabel,
                                      icon: Icons.app_registration,
                                      hint: l10n.partnerCommercialRegHint,
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
suffixIcon: buildCopySuffix(emailCtrl),
                                      label: l10n.partnerPrimaryEmailLabel,
                                      icon: Icons.email,
                                      hint: l10n.partnerPrimaryEmailHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: secondaryEmailCtrl,
suffixIcon: buildCopySuffix(secondaryEmailCtrl),
                                      label: l10n.partnerSecondaryEmailLabel,
                                      icon: Icons.mark_email_read_outlined,
                                      hint: l10n.partnerSecondaryEmailHint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: phoneCtrl,
suffixIcon: buildCopySuffix(phoneCtrl),
                                      label: l10n.partnerPhoneLabel,
                                      icon: Icons.phone,
                                      hint: l10n.partnerPhoneHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: mobileCtrl,
suffixIcon: buildCopySuffix(mobileCtrl),
                                      label: l10n.partnerMobileLabel,
                                      icon: Icons.smartphone,
                                      hint: l10n.partnerMobileHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: faxCtrl,
suffixIcon: buildCopySuffix(faxCtrl),
                                      label: l10n.partnerFaxLabel,
                                      icon: Icons.print,
                                      hint: l10n.partnerFaxHint,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              CustomTextField(
                                controller: websiteCtrl,
suffixIcon: buildCopySuffix(websiteCtrl),
                                label: l10n.partnerWebsiteUrlLabel,
                                icon: Icons.language,
                                hint: l10n.partnerWebsiteUrlHint,
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: addressCtrl,
suffixIcon: buildCopySuffix(addressCtrl),
                                      label: l10n.partnerAddressLabel,
                                      icon: Icons.location_on,
                                      hint: l10n.partnerAddressHint,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextField(
                                      controller: countryCtrl,
suffixIcon: buildCopySuffix(countryCtrl),
                                      label: l10n.partnerCountryLabelField,
                                      icon: Icons.flag,
                                      isRequired: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actions
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
                            onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close, size: 16, color: AppTheme.crimson),
                            label: Text(l10n.cancelAndCloseBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: isSubmitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check, size: 18),
                            label: Text(isSubmitting ? l10n.savingChanges : (isEditing ? l10n.updatePartnerBtn : l10n.savePartnerBtn)),
                            onPressed: isSubmitting ? null : () async {
                              if (!formKey.currentState!.validate() || selectedCategories.isEmpty) {
                                return;
                              }

                              setDialogState(() {
                                isSubmitting = true;
                              });

                              final partnerTypeJoined = selectedCategories.join(', ');

                              final partner = PartnerModel(
                                providerId: partnerToEdit?.providerId,
                                partnerCode: partnerToEdit?.partnerCode ?? '',
                                partnerName: nameCtrl.text.trim(),
                                partnerType: partnerTypeJoined,
                                taxId: taxIdCtrl.text.trim().isEmpty ? null : taxIdCtrl.text.trim(),
                                commercialRegister: regCtrl.text.trim().isEmpty ? null : regCtrl.text.trim(),
                                clearanceLicenseNumber: isCustomsBroker ? (licenseCtrl.text.trim().isEmpty ? null : licenseCtrl.text.trim()) : null,
                                authorizedPorts: isCustomsBroker ? (authorizedPortsCtrl.text.trim().isEmpty ? null : authorizedPortsCtrl.text.trim()) : null,
                                transportLicenseNumber: isInlandTransport ? (transportLicenseCtrl.text.trim().isEmpty ? null : transportLicenseCtrl.text.trim()) : null,
                                fleetTypes: isInlandTransport ? (fleetTypesCtrl.text.trim().isEmpty ? null : fleetTypesCtrl.text.trim()) : null,
                                coverageAreas: isInlandTransport ? (coverageAreasCtrl.text.trim().isEmpty ? null : coverageAreasCtrl.text.trim()) : null,
                                insuranceLicenseNumber: isInsuranceCompany ? (insuranceLicenseCtrl.text.trim().isEmpty ? null : insuranceLicenseCtrl.text.trim()) : null,
                                insuranceCoverageTypes: isInsuranceCompany ? (insuranceCoverageCtrl.text.trim().isEmpty ? null : insuranceCoverageCtrl.text.trim()) : null,
                                scacCode: scacCtrl.text.trim().isEmpty ? null : scacCtrl.text.trim(),
                                trackingUrl: trackingCtrl.text.trim().isEmpty ? null : trackingCtrl.text.trim(),
                                defaultFreeDays: isShippingLine ? (int.tryParse(defaultFreeDaysCtrl.text.trim()) ?? 14) : null,
                                fiataId: isFreightForwarder ? (fiataCtrl.text.trim().isEmpty ? null : fiataCtrl.text.trim()) : null,
                                shippingModes: isFreightForwarder ? (shippingModesCtrl.text.trim().isEmpty ? null : shippingModesCtrl.text.trim()) : null,
                                supportedCurrencies: isFreightForwarder ? (supportedCurrenciesCtrl.text.trim().isEmpty ? null : supportedCurrenciesCtrl.text.trim()) : null,
                                inspectionAccreditationNumber: isInspectionAgency ? (accreditationCtrl.text.trim().isEmpty ? null : accreditationCtrl.text.trim()) : null,
                                inspectionScope: isInspectionAgency ? (inspectionScopeCtrl.text.trim().isEmpty ? null : inspectionScopeCtrl.text.trim()) : null,
                                swiftCode: swiftCtrl.text.trim().isEmpty ? null : swiftCtrl.text.trim(),
                                bankCode: bankCodeCtrl.text.trim().isEmpty ? null : bankCodeCtrl.text.trim(),
                                branchName: branchCtrl.text.trim().isEmpty ? null : branchCtrl.text.trim(),
                                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                secondaryEmail: secondaryEmailCtrl.text.trim().isEmpty ? null : secondaryEmailCtrl.text.trim(),
                                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
                                fax: faxCtrl.text.trim().isEmpty ? null : faxCtrl.text.trim(),
                                website: websiteCtrl.text.trim().isEmpty ? null : websiteCtrl.text.trim(),
                                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                                country: countryCtrl.text.trim(),
                                isActive: partnerToEdit?.isActive ?? true,
                              );

                              String? errorMessage;
                              if (isEditing && partnerToEdit.providerId != null) {
                                final List<FieldChangeItem> changes = [];
                                if (FieldChangeItem.isDifferent(partnerToEdit.partnerName, partner.partnerName)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffPartnerName, oldValue: partnerToEdit.partnerName, newValue: partner.partnerName));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.partnerType, partner.partnerType)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffPartnerType, oldValue: partnerToEdit.partnerType, newValue: partner.partnerType));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.fiataId, partner.fiataId)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.fiataLicenseLabel, oldValue: partnerToEdit.fiataId ?? '—', newValue: partner.fiataId ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.shippingModes, partner.shippingModes)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.shippingModesLabel, oldValue: partnerToEdit.shippingModes ?? '—', newValue: partner.shippingModes ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.supportedCurrencies, partner.supportedCurrencies)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.supportedCurrenciesLabel, oldValue: partnerToEdit.supportedCurrencies ?? '—', newValue: partner.supportedCurrencies ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.inspectionAccreditationNumber, partner.inspectionAccreditationNumber)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.inspectionAccreditationNumLabel, oldValue: partnerToEdit.inspectionAccreditationNumber ?? '—', newValue: partner.inspectionAccreditationNumber ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.inspectionScope, partner.inspectionScope)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.inspectionScopeLabel, oldValue: partnerToEdit.inspectionScope ?? '—', newValue: partner.inspectionScope ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.clearanceLicenseNumber, partner.clearanceLicenseNumber)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.customsClearanceLicenseNumLabel, oldValue: partnerToEdit.clearanceLicenseNumber ?? '—', newValue: partner.clearanceLicenseNumber ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.authorizedPorts, partner.authorizedPorts)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.authorizedPortsLabel, oldValue: partnerToEdit.authorizedPorts ?? '—', newValue: partner.authorizedPorts ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.transportLicenseNumber, partner.transportLicenseNumber)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.transportLicenseNumLabel, oldValue: partnerToEdit.transportLicenseNumber ?? '—', newValue: partner.transportLicenseNumber ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.fleetTypes, partner.fleetTypes)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.fleetTypesLabel, oldValue: partnerToEdit.fleetTypes ?? '—', newValue: partner.fleetTypes ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.coverageAreas, partner.coverageAreas)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.coverageAreasLabel, oldValue: partnerToEdit.coverageAreas ?? '—', newValue: partner.coverageAreas ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.insuranceLicenseNumber, partner.insuranceLicenseNumber)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.insuranceLicenseNumLabel, oldValue: partnerToEdit.insuranceLicenseNumber ?? '—', newValue: partner.insuranceLicenseNumber ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.insuranceCoverageTypes, partner.insuranceCoverageTypes)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.insuranceCoverageTypesLabel, oldValue: partnerToEdit.insuranceCoverageTypes ?? '—', newValue: partner.insuranceCoverageTypes ?? '—'));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.email, partner.email)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffPartnerEmail, oldValue: partnerToEdit.email, newValue: partner.email));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.phone, partner.phone)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffPartnerPhone, oldValue: partnerToEdit.phone, newValue: partner.phone));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.address, partner.address)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffPartnerAddress, oldValue: partnerToEdit.address, newValue: partner.address));
                                }
                                if (FieldChangeItem.isDifferent(partnerToEdit.country, partner.country)) {
                                  changes.add(FieldChangeItem(fieldName: l10n.diffPartnerCountry, oldValue: partnerToEdit.country, newValue: partner.country));
                                }

                                if (changes.isNotEmpty) {
                                  final confirmed = await showChangeDiffConfirmationDialog(
                                    context,
                                    title: l10n.diffConfirmPartnerTitle,
                                    itemReference: '${partnerToEdit.partnerCode} (${partnerToEdit.partnerName})',
                                    changes: changes,
                                  );
                                  if (!confirmed) {
                                    setDialogState(() => isSubmitting = false);
                                    return;
                                  }
                                }

                                errorMessage = await ref.read(partnersProvider.notifier).updatePartner(partnerToEdit.providerId!, partner);
                              } else {
                                errorMessage = await ref.read(partnersProvider.notifier).createPartner(partner);
                              }

                              if (errorMessage == null) {
                                if (context.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                              } else {
                                setDialogState(() {
                                  isSubmitting = false;
                                });
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
      );
      },
    ).then((_) {
      nameCtrl.dispose();
      taxIdCtrl.dispose();
      regCtrl.dispose();
      licenseCtrl.dispose();
      authorizedPortsCtrl.dispose();
      transportLicenseCtrl.dispose();
      fleetTypesCtrl.dispose();
      coverageAreasCtrl.dispose();
      insuranceLicenseCtrl.dispose();
      insuranceCoverageCtrl.dispose();
      scacCtrl.dispose();
      defaultFreeDaysCtrl.dispose();
      trackingCtrl.dispose();
      fiataCtrl.dispose();
      shippingModesCtrl.dispose();
      supportedCurrenciesCtrl.dispose();
      accreditationCtrl.dispose();
      inspectionScopeCtrl.dispose();
      swiftCtrl.dispose();
      bankCodeCtrl.dispose();
      branchCtrl.dispose();
      phoneCtrl.dispose();
      mobileCtrl.dispose();
      faxCtrl.dispose();
      emailCtrl.dispose();
      secondaryEmailCtrl.dispose();
      websiteCtrl.dispose();
      addressCtrl.dispose();
      countryCtrl.dispose();
    });
  }
}
