import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/helpers/master_data_action_helper.dart';
import '../models/partner_model.dart';
import '../providers/partners_provider.dart';

/// شريط أدوات الفلترة والبحث والإجراءات السريعة لصفحة الشركاء
class PartnersFilterToolbar extends ConsumerWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddPartner;
  final VoidCallback onExtractAi;
  final VoidCallback onCopyTsv;

  static const List<String> categories = [
    'All',
    'Bank',
    'Shipping Line',
    'Customs Broker',
    'Freight Forwarder',
    'Inland Transport',
    'Inspection Agency',
    'Insurance Company',
  ];

  const PartnersFilterToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAddPartner,
    required this.onExtractAi,
    required this.onCopyTsv,
  });

  static String getCategoryLabel(BuildContext context, String cat) {
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

  static void copyPartnersTsv(BuildContext context, List<PartnerModel> partners) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final density = ref.watch(displayDensityProvider);
    final selectedCategory = ref.watch(selectedPartnerCategoryProvider);
    final showInactive = ref.watch(showInactivePartnersProvider);
    final partnersAsync = ref.watch(partnersProvider);
    final partnerList = partnersAsync.asData?.value ?? [];

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
          icon: Icon(Icons.add, size: density.buttonIconSize),
          label: Text(
            l10n.addExternalPartnerBtn,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
          onPressed: onAddPartner,
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
                : l10n.aiCodeCategoryPartner(getCategoryLabel(context, selectedCategory)),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: density.buttonFontSize),
          ),
          onPressed: onExtractAi,
        ),
      ],
      moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
        context: context,
        includeTsv: partnerList.isNotEmpty,
      ),
      onMoreActionSelected: (val) => MasterDataActionHelper.handleStandardAction(
        context: context,
        ref: ref,
        actionValue: val,
        moduleEndpoint: 'external-service-providers',
        entityNameAr: 'الشركاء ومقدمي الخدمات والبنوك',
        entityNameEn: 'Partners & Service Providers',
        entityFilePrefix: 'External_Service_Providers_Banks',
        onImportSuccess: () {
          ref.read(partnersProvider.notifier).fetchPartners();
          ref.read(allPartnersProvider.notifier).fetchPartners();
        },
        onCopyTsv: onCopyTsv,
      ),
      searchController: searchController,
      searchHint: l10n.searchPartnersHint,
      onSearchChanged: onSearchChanged,
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
                items: categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(
                            getCategoryLabel(context, cat),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
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
                activeThumbColor: AppTheme.cobalt,
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
          onPressed: () async {
            await ref.read(partnersProvider.notifier).fetchPartners();
            await ref.read(allPartnersProvider.notifier).fetchPartners();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    Directionality.of(context) == TextDirection.rtl
                        ? 'تم تحديث قائمة الشركاء والبنوك بنجاح'
                        : 'Partners & banks refreshed successfully',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
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
            onPressed: onCopyTsv,
          ),
      ],
    );
  }
}
