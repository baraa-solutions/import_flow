import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../customs_clearance_quotations/screens/customs_clearance_quotations_screen.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../providers/customs_consultation_provider.dart';
import 'broker_price_lists/broker_price_lists_view.dart';
import 'broker_price_lists/clearance_expense_catalog_view.dart';

class BrokerPriceListsTab extends ConsumerStatefulWidget {
  const BrokerPriceListsTab({super.key});

  @override
  ConsumerState<BrokerPriceListsTab> createState() => _BrokerPriceListsTabState();
}

class _BrokerPriceListsTabState extends ConsumerState<BrokerPriceListsTab> {
  int _managementSubTabIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!ref.read(allPartnersProvider).isLoading) {
        ref.read(allPartnersProvider.notifier).fetchPartners();
      }
      if (!ref.read(partnersProvider).isLoading) {
        ref.read(partnersProvider.notifier).fetchPartners();
      }
      if (!ref.read(brokerPriceListsProvider).isLoading) {
        ref.read(brokerPriceListsProvider.notifier).fetchPriceLists();
      }
      if (!ref.read(clearanceExpenseTypesProvider).isLoading) {
        ref.read(clearanceExpenseTypesProvider.notifier).fetchExpenseTypes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final allPartners = ref.watch(allPartnersProvider).valueOrNull ??
        ref.watch(partnersProvider).valueOrNull ??
        [];
    final brokersList = allPartners
        .where((p) =>
            p.partnerType.toLowerCase().contains('customs broker') ||
            p.partnerType.toLowerCase().contains('مخلص'))
        .toList();

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-Tab Switcher (Segmented Control)
            Row(
              children: [
                ChoiceChip(
                  label: Text(l.brokerPriceListsTab, style: const TextStyle(fontWeight: FontWeight.bold)),
                  selected: _managementSubTabIndex == 0,
                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.18),
                  onSelected: (_) => setState(() => _managementSubTabIndex = 0),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: Text(l.clearanceQuotesTab, style: const TextStyle(fontWeight: FontWeight.bold)),
                  selected: _managementSubTabIndex == 1,
                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.18),
                  onSelected: (_) => setState(() => _managementSubTabIndex = 1),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: Text(l.smartClearanceQuoteExtractor,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  selected: _managementSubTabIndex == 2,
                  selectedColor: AppTheme.cobalt.withValues(alpha: 0.18),
                  onSelected: (_) => setState(() => _managementSubTabIndex = 2),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sub-Tab Content
            Expanded(
              child: _managementSubTabIndex == 0
                  ? BrokerPriceListsView(brokersList: brokersList)
                  : (_managementSubTabIndex == 1
                      ? const ClearanceExpenseCatalogView()
                      : const CustomsClearanceQuotationsScreen(embedded: true)),
            ),
          ],
        ),
      ),
    );
  }
}
