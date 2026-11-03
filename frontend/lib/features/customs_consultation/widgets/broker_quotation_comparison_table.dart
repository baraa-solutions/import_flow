import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance_quotations/models/customs_clearance_quotation_model.dart';
import 'comparison/broker_quote_data_table.dart';
import 'comparison/broker_quote_header.dart';
import 'comparison/broker_quote_kpis.dart';
import 'comparison/broker_quote_toolbar.dart';

enum BrokerQuoteSortOption {
  lowestTotal,
  fastestTurnaround,
  lowestClearanceFee,
  brokerName,
}

/// A rich, unified comparison table widget for competing customs broker quotations.
class BrokerQuotationComparisonTable extends StatefulWidget {
  final List<CustomsClearanceQuotationItemModel> quotations;
  final String? rfqCode;
  final String? rfqTitle;
  final int? selectedBrokerId;
  final void Function(int quotationId)? onAward;
  final void Function(int quotationId)? onDeleteQuote;
  final void Function(CustomsClearanceQuotationItemModel quote)? onSelectQuote;
  final VoidCallback? onAddQuote;
  final VoidCallback? onSmartExtract;
  final bool showHeader;
  final bool isCompact;

  const BrokerQuotationComparisonTable({
    super.key,
    required this.quotations,
    this.rfqCode,
    this.rfqTitle,
    this.selectedBrokerId,
    this.onAward,
    this.onDeleteQuote,
    this.onSelectQuote,
    this.onAddQuote,
    this.onSmartExtract,
    this.showHeader = true,
    this.isCompact = false,
  });

  @override
  State<BrokerQuotationComparisonTable> createState() =>
      _BrokerQuotationComparisonTableState();
}

class _BrokerQuotationComparisonTableState
    extends State<BrokerQuotationComparisonTable> {
  final TextEditingController _searchCtrl = TextEditingController();
  BrokerQuoteSortOption _sortBy = BrokerQuoteSortOption.lowestTotal;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CustomsClearanceQuotationItemModel> get _filteredAndSortedQuotes {
    final query = _searchQuery.trim().toLowerCase();
    var list = widget.quotations.where((q) {
      if (query.isEmpty) return true;
      final name = q.providerName.toLowerCase();
      final license = (q.licenseNumber ?? '').toLowerCase();
      final remarks = (q.remarks ?? '').toLowerCase();
      return name.contains(query) ||
          license.contains(query) ||
          remarks.contains(query);
    }).toList();

    switch (_sortBy) {
      case BrokerQuoteSortOption.lowestTotal:
        list.sort((a, b) => a.totalCost.compareTo(b.totalCost));
        break;
      case BrokerQuoteSortOption.fastestTurnaround:
        list.sort((a, b) =>
            a.estimatedTurnaroundDays.compareTo(b.estimatedTurnaroundDays));
        break;
      case BrokerQuoteSortOption.lowestClearanceFee:
        list.sort((a, b) => a.clearanceFee.compareTo(b.clearanceFee));
        break;
      case BrokerQuoteSortOption.brokerName:
        list.sort((a, b) => a.providerName.compareTo(b.providerName));
        break;
    }

    return list;
  }

  void _copyComparisonTsv(BuildContext context, AppLocalizations l10n) {
    if (widget.quotations.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln([
      l10n.clearanceQuotesColBroker,
      l10n.clearanceQuotesColClearanceFee,
      l10n.clearanceQuotesColInlandTransport,
      l10n.clearanceQuotesColInspectionFee,
      l10n.clearanceQuotesColPortExpenses,
      l10n.clearanceQuotesColMiscellaneous,
      l10n.clearanceQuotesColEstimatedTotal,
      l10n.clearanceQuotesColDuration,
      l10n.statusCol,
    ].join('\t'));

    for (final q in _filteredAndSortedQuotes) {
      buffer.writeln([
        q.providerName,
        '${q.clearanceFee.toStringAsFixed(2)} ${q.currency}',
        '${q.inlandTransportFee.toStringAsFixed(2)} ${q.currency}',
        '${q.inspectionFee.toStringAsFixed(2)} ${q.currency}',
        '${q.portExpenses.toStringAsFixed(2)} ${q.currency}',
        '${q.miscellaneousFee.toStringAsFixed(2)} ${q.currency}',
        '${q.totalCost.toStringAsFixed(2)} ${q.currency}',
        '${q.estimatedTurnaroundDays}',
        q.isAwarded ? l10n.clearanceQuotesStatusAwarded : l10n.statusPending,
      ].join('\t'));
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.clearanceQuotesCopiedTsvSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quotes = _filteredAndSortedQuotes;

    CustomsClearanceQuotationItemModel? lowestCostQuote;
    CustomsClearanceQuotationItemModel? fastestQuote;
    CustomsClearanceQuotationItemModel? awardedQuote;

    for (final q in widget.quotations) {
      if (q.isAwarded) awardedQuote = q;
      if (lowestCostQuote == null || q.totalCost < lowestCostQuote.totalCost) {
        lowestCostQuote = q;
      }
      if (fastestQuote == null ||
          q.estimatedTurnaroundDays < fastestQuote.estimatedTurnaroundDays) {
        fastestQuote = q;
      }
    }

    return SelectionArea(
      child: Container(
        decoration: AppTheme.cardDecorationOf(context),
        padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader) ...[
              BrokerQuoteHeader(
                rfqTitle: widget.rfqTitle,
                onAddQuote: widget.onAddQuote,
                onSmartExtract: widget.onSmartExtract,
              ),
              const SizedBox(height: 14),
            ],
            if (widget.quotations.isNotEmpty) ...[
              BrokerQuoteKpis(
                totalCount: widget.quotations.length,
                lowestCostQuote: lowestCostQuote,
                fastestQuote: fastestQuote,
                awardedQuote: awardedQuote,
              ),
              const SizedBox(height: 12),
            ],
            BrokerQuoteToolbar(
              searchCtrl: _searchCtrl,
              searchQuery: _searchQuery,
              onSearchChanged: (val) => setState(() => _searchQuery = val),
              onClearSearch: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
              sortBy: _sortBy,
              onSortChanged: (opt) => setState(() => _sortBy = opt),
              onExportTsv: widget.quotations.isEmpty
                  ? null
                  : () => _copyComparisonTsv(context, l10n),
            ),
            const SizedBox(height: 12),
            if (quotes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppEmptyState(
                  message: l10n.clearanceQuotesNoQuotesYet,
                  icon: Icons.rate_review_outlined,
                ),
              )
            else
              BrokerQuoteDataTable(
                quotes: quotes,
                lowestCostId: lowestCostQuote?.quotationId,
                selectedBrokerId: widget.selectedBrokerId,
                onAward: widget.onAward,
                onDeleteQuote: widget.onDeleteQuote,
                onSelectQuote: widget.onSelectQuote,
              ),
          ],
        ),
      ),
    );
  }
}
