import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/export/widgets/export_language_dialog.dart';
import '../../../core/services/master_data_export_service.dart';
import '../models/partner_model.dart';
import '../providers/partners_provider.dart';
import '../widgets/partner_details_dialog.dart';
import '../widgets/partner_registration_dialog.dart';
import '../widgets/partner_scorecard_dialog.dart';
import '../widgets/partner_statement_of_account_dialog.dart';
import '../widgets/partners_data_table.dart';
import '../widgets/partners_filter_toolbar.dart';

/// الشاشة الرئيسية المنسقة لشركاء ومقدمي الخدمات الخارجيين والبنوك
class PartnersScreen extends ConsumerStatefulWidget {
  const PartnersScreen({super.key});

  @override
  ConsumerState<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends ConsumerState<PartnersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  Future<void> _handleToggleActive(PartnerModel partner) async {
    final l10n = context.l10n;
    final confirm = await AppConfirmDialog.showToggleActive(
      context,
      isCurrentlyActive: partner.isActive,
      message: partner.isActive
          ? l10n.confirmDeactivatePartner(partner.partnerName)
          : l10n.confirmActivatePartner(partner.partnerName),
    );
    if (confirm == true && partner.providerId != null) {
      await ref.read(partnersProvider.notifier).toggleActiveStatus(partner.providerId!, partner.isActive);
    }
  }

  Future<void> _handlePrint(PartnerModel partner) async {
    final lang = await ExportLanguageDialog.show(context);
    if (lang != null) {
      await MasterDataExportService.printOrSavePartnerPdf(partner, lang: lang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final partnersAsync = ref.watch(partnersProvider);
    final selectedCategory = ref.watch(selectedPartnerCategoryProvider);
    final partnerList = partnersAsync.asData?.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              PartnersFilterToolbar(
                searchController: _searchController,
                onSearchChanged: (v) {
                  setState(() {
                    _searchQuery = v.toLowerCase();
                  });
                },
                onAddPartner: () => PartnerRegistrationDialog.show(context),
                onExtractAi: () => _openExtractorForCategory(context, selectedCategory),
                onCopyTsv: () {
                  if (partnerList.isNotEmpty) {
                    PartnersFilterToolbar.copyPartnersTsv(context, partnerList);
                  }
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: partnersAsync.when(
                  loading: () => const AppLoadingState(),
                  error: (err, stack) => AppErrorState(
                    error: err,
                    onRetry: () => ref.read(partnersProvider.notifier).fetchPartners(),
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
                      return AppEmptyState(
                        icon: Icons.apartment_outlined,
                        message: l10n.noPartnersFound,
                      );
                    }

                    return PartnersDataTable(
                      partners: filtered,
                      onView: (partner) => PartnerDetailsDialog.show(
                        context,
                        partner,
                        onEdit: () => PartnerRegistrationDialog.show(context, partner),
                      ),
                      onEdit: (partner) => PartnerRegistrationDialog.show(context, partner),
                      onStatementOfAccount: (partner) => PartnerStatementOfAccountDialog.show(context, partner),
                      onScorecard: (partner) {
                        if (partner.providerId != null) {
                          showPartnerScorecardDialog(
                            context,
                            ref,
                            providerId: partner.providerId!,
                            providerName: partner.partnerName,
                            providerType: partner.partnerType,
                          );
                        }
                      },
                      onPrint: _handlePrint,
                      onToggleActive: _handleToggleActive,
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
