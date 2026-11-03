import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../logistics_invoices/screens/logistics_invoices_screen.dart';
import '../../models/invoices_aggregation_model.dart';
import '../settlement_ui.dart';

class FinalSettlementPartiesFilter extends StatelessWidget {
  final InvoicesAggregationResponseModel data;
  final String selectedPartyFilter;
  final ValueChanged<String> onFilterChanged;
  final int importFileId;
  final VoidCallback onReloadNeeded;

  const FinalSettlementPartiesFilter({
    super.key,
    required this.data,
    required this.selectedPartyFilter,
    required this.onFilterChanged,
    required this.importFileId,
    required this.onReloadNeeded,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final partyFilters = <MapEntry<String, String>>[
      MapEntry('ALL', l10n.settlementClo01PartyAll(data.invoices.length)),
      MapEntry('SUPPLIER', l10n.settlementClo01PartySupplier),
      MapEntry('CARRIER', l10n.settlementClo01PartyCarrier),
      MapEntry('INSURANCE', l10n.settlementClo01PartyInsurance),
      MapEntry('CUSTOMS', l10n.settlementClo01PartyCustoms),
      MapEntry('BROKER', l10n.settlementClo01PartyBroker),
      MapEntry('TRANSPORT', l10n.settlementClo01PartyTransport),
      MapEntry('DEMURRAGE', l10n.settlementClo01PartyDemurrage),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...partyFilters.map((filter) {
            final isSelected = selectedPartyFilter == filter.key;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8.0),
              child: FilterChip(
                label: Text(filter.value),
                selected: isSelected,
                onSelected: (selected) => onFilterChanged(filter.key),
                selectedColor: AppTheme.charcoal,
                checkmarkColor: AppTheme.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.white : AppTheme.charcoal,
                ),
                backgroundColor: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppTheme.charcoal : SettlementTokens.border,
                  ),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8.0),
            child: ActionChip(
              avatar: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
              label: Text(
                l10n.isArabic ? 'إدارة فواتير الخدمات اللوجستية' : 'Manage Logistics Service Invoices',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF0D9488),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => LogisticsInvoicesScreen(
                      initialShipmentId: importFileId,
                    ),
                  ),
                );
                onReloadNeeded();
              },
            ),
          ),
        ],
      ),
    );
  }
}
