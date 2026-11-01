import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../providers/customs_clearance_quotations_provider.dart';
import '../widgets/price_lists_tab_view.dart';
import '../widgets/rfq_tab_view.dart';
import '../widgets/smart_extractor_launcher.dart';

// Other screens (customs consultation) open the smart extractor from here.
export '../widgets/smart_clearance_extractor_dialog.dart' show showSmartClearanceExtractorDialog;

class CustomsClearanceQuotationsScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const CustomsClearanceQuotationsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<CustomsClearanceQuotationsScreen> createState() =>
      _CustomsClearanceQuotationsScreenState();
}

class _CustomsClearanceQuotationsScreenState
    extends ConsumerState<CustomsClearanceQuotationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customsClearanceQuotationsProvider.notifier).fetchRFQs();
      ref.read(clearancePriceListProvider.notifier).fetchPriceList();
      ref.read(partnersProvider.notifier).fetchPartners();
      ref.read(importFilesProvider.notifier).fetchImportFiles();
      ref.read(transportLocationsProvider.notifier).fetchLocations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(customsClearanceQuotationsProvider);
    ref.invalidate(clearancePriceListProvider);
    ref.invalidate(partnersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final tabBar = Container(
      color: AppTheme.surfaceOf(context),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.cobalt,
        indicatorWeight: 3,
        labelColor: AppTheme.cobalt,
        unselectedLabelColor: AppTheme.textSecondaryOf(context),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(
            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
            text: l10n.clearanceQuotesTabRfqs,
          ),
          Tab(
            icon: const Icon(Icons.price_change_rounded, size: 18),
            text: l10n.clearanceQuotesTabPriceLists,
          ),
        ],
      ),
    );

    final tabs = Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          RfqTabView(
            onSmartExtract: (rfqId) => SmartExtractorLauncher.launch(context, ref, targetRfqId: rfqId),
          ),
          const PriceListsTabView(),
        ],
      ),
    );

    if (widget.embedded) {
      return SelectionArea(
        child: Container(
          color: AppTheme.surfaceAltOf(context),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.request_quote_rounded, color: AppTheme.cobalt, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.clearanceQuotesEmbeddedTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.charcoal),
                      tooltip: l10n.refresh,
                      onPressed: _refreshAll,
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: l10n.clearanceQuotesSmartExtractorBtn,
                      icon: Icons.auto_awesome,
                      variant: AppButtonVariant.success,
                      size: AppButtonSize.small,
                      onPressed: () => SmartExtractorLauncher.launch(context, ref),
                    ),
                  ],
                ),
              ),
              tabBar,
              tabs,
            ],
          ),
        ),
      );
    }

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAltOf(context),
        appBar: PageHeader(
          icon: Icons.request_quote_rounded,
          title: l10n.clearanceQuotesScreenTitle,
          subtitle: l10n.clearanceQuotesScreenSubtitle,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.white),
              tooltip: l10n.refresh,
              onPressed: _refreshAll,
            ),
          ],
        ),
        body: Column(children: [tabBar, tabs]),
      ),
    );
  }
}
