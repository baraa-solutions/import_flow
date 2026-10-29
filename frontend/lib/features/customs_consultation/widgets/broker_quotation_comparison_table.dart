import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../customs_clearance_quotations/models/customs_clearance_quotation_model.dart';

enum BrokerQuoteSortOption {
  lowestTotal,
  fastestTurnaround,
  lowestClearanceFee,
  brokerName,
}

/// A rich, unified comparison table widget for competing customs broker quotations.
///
/// Features:
/// - Summary KPI badges (Best Price, Fastest Turnaround, Awarded Broker, Total Quotes).
/// - Live text filtering and dynamic sorting options.
/// - Full [SelectionArea] encapsulation for frictionless text selection.
/// - Clean clipboard copying via [CopyHelper.copy].
/// - Pure localization via [context.l10n].
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quotes = _filteredAndSortedQuotes;

    // Discover lowest cost and fastest turnaround quotes
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
            // ── TOP HEADER (Optional) ─────────────────────────────────────────
            if (widget.showHeader) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.compare_arrows_rounded,
                      color: AppTheme.cobalt,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.clearanceQuotesScreenTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.charcoal,
                          ),
                        ),
                        if (widget.rfqTitle != null &&
                            widget.rfqTitle!.isNotEmpty)
                          Text(
                            widget.rfqTitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (widget.onAddQuote != null)
                    AppButton(
                      label: l10n.clearanceQuotesAddManualQuoteBtn,
                      icon: Icons.add,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: widget.onAddQuote,
                    ),
                  if (widget.onSmartExtract != null) ...[
                    const SizedBox(width: 8),
                    AppButton(
                      label: l10n.clearanceQuotesSmartExtractQuoteBtn,
                      icon: Icons.auto_awesome,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.small,
                      onPressed: widget.onSmartExtract,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
            ],

            // ── KPI SUMMARY HIGHLIGHTS STRIP ──────────────────────────────────
            if (widget.quotations.isNotEmpty) ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _SummaryPill(
                    icon: Icons.format_list_numbered,
                    label: l10n.clearanceQuotesTabRfqs,
                    value: '${widget.quotations.length}',
                    color: AppTheme.charcoal,
                  ),
                  if (lowestCostQuote != null)
                    _SummaryPill(
                      icon: Icons.savings_outlined,
                      label: l10n.clearanceQuotesBadgeLowestCost,
                      value:
                          '${CcFormat.money(lowestCostQuote.totalCost)} ${lowestCostQuote.currency} (${lowestCostQuote.providerName})',
                      color: AppTheme.emerald,
                      highlight: true,
                    ),
                  if (fastestQuote != null)
                    _SummaryPill(
                      icon: Icons.bolt_outlined,
                      label: l10n.clearanceQuotesBadgeFastestDuration,
                      value:
                          '${l10n.clearanceQuotesDaysCount(fastestQuote.estimatedTurnaroundDays)} (${fastestQuote.providerName})',
                      color: AppTheme.cobalt,
                    ),
                  if (awardedQuote != null)
                    _SummaryPill(
                      icon: Icons.verified_rounded,
                      label: l10n.clearanceQuotesStatusAwarded,
                      value: awardedQuote.providerName,
                      color: AppTheme.emerald,
                      highlight: true,
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── TOOLBAR: SEARCH & SORT & TSV COPY ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: l10n.clearanceQuotesSearchHint,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Sort Menu
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderOf(context)),
                    color: AppTheme.surfaceOf(context),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BrokerQuoteSortOption>(
                      value: _sortBy,
                      icon: const Icon(Icons.sort_rounded, size: 18),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (opt) {
                        if (opt != null) setState(() => _sortBy = opt);
                      },
                      items: [
                        DropdownMenuItem(
                          value: BrokerQuoteSortOption.lowestTotal,
                          child: Text(l10n.clearanceQuotesBadgeLowestCost),
                        ),
                        DropdownMenuItem(
                          value: BrokerQuoteSortOption.fastestTurnaround,
                          child: Text(l10n.clearanceQuotesBadgeFastestDuration),
                        ),
                        DropdownMenuItem(
                          value: BrokerQuoteSortOption.lowestClearanceFee,
                          child: Text(l10n.clearanceQuotesColClearanceFee),
                        ),
                        DropdownMenuItem(
                          value: BrokerQuoteSortOption.brokerName,
                          child: Text(l10n.clearanceQuotesColBroker),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Export TSV Button
                IconButton(
                  icon: const Icon(Icons.table_view_rounded,
                      color: AppTheme.cobalt, size: 20),
                  tooltip: l10n.clearanceQuotesExportTsvBtn,
                  onPressed: widget.quotations.isEmpty
                      ? null
                      : () => _copyComparisonTsv(context, l10n),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── DATA TABLE / EMPTY STATE ──────────────────────────────────────
            if (quotes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppEmptyState(
                  message: l10n.clearanceQuotesNoQuotesYet,
                  icon: Icons.rate_review_outlined,
                ),
              )
            else
              _buildDataTable(context, l10n, quotes, lowestCostQuote?.quotationId),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    AppLocalizations l10n,
    List<CustomsClearanceQuotationItemModel> quotes,
    int? lowestCostId,
  ) {
    DataColumn col(String label, {bool numeric = false}) => DataColumn(
          numeric: numeric,
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        headingRowHeight: 40,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 52,
        headingRowColor:
            WidgetStateProperty.all(AppTheme.surfaceAltOf(context)),
        columns: [
          col(l10n.clearanceQuotesColStatusActions),
          col(l10n.clearanceQuotesColBroker),
          col(l10n.clearanceQuotesColClearanceFee, numeric: true),
          col(l10n.clearanceQuotesColInlandTransport, numeric: true),
          col(l10n.clearanceQuotesColInspectionFee, numeric: true),
          col(l10n.clearanceQuotesColPortExpenses, numeric: true),
          col(l10n.clearanceQuotesColMiscellaneous, numeric: true),
          col(l10n.clearanceQuotesColEstimatedTotal, numeric: true),
          col(l10n.clearanceQuotesColDuration, numeric: true),
        ],
        rows: quotes.map((q) => _buildRow(context, l10n, q, lowestCostId)).toList(),
      ),
    );
  }

  DataRow _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    CustomsClearanceQuotationItemModel q,
    int? lowestCostId,
  ) {
    final isAwarded = q.isAwarded;
    final isLowest = q.quotationId != null && q.quotationId == lowestCostId;
    final isSelected = widget.selectedBrokerId != null &&
        q.providerId == widget.selectedBrokerId;

    final rowSummary =
        '${q.providerName} | ${l10n.clearanceQuotesColEstimatedTotal}: ${q.totalCost.toStringAsFixed(0)} ${q.currency} | ${l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays)}';

    DataCell moneyCell(double value, {bool isTotal = false}) {
      final text = '${CcFormat.money(value)} ${q.currency}';
      return DataCell(
        CopyableTableCell(
          value: text,
          rowSummary: rowSummary,
          child: LtrText(
            text,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 13 : 12,
              color: isAwarded
                  ? AppTheme.wcagEmerald
                  : (isLowest && isTotal
                      ? AppTheme.emerald
                      : AppTheme.textPrimaryOf(context)),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    final days = l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays);

    return DataRow(
      color: isAwarded
          ? WidgetStateProperty.all(
              AppTheme.severityBackgroundOf(context, AppSeverity.success))
          : (isSelected
              ? WidgetStateProperty.all(AppTheme.cobaltLight.withValues(alpha: 0.5))
              : null),
      cells: [
        // Status & Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    size: 16, color: AppTheme.cobalt),
                tooltip: l10n.copy,
                onPressed: () => CopyHelper.copy(
                  context,
                  rowSummary,
                  customMessage: l10n.clearanceQuotesCopyRowSuccess,
                ),
              ),
              if (isAwarded)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check,
                          size: 14, color: AppTheme.wcagEmerald),
                      const SizedBox(width: 4),
                      Text(
                        l10n.clearanceQuotesStatusAwardedBadge,
                        style: const TextStyle(
                          color: AppTheme.wcagEmerald,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (widget.onAward != null && q.quotationId != null)
                AppButton(
                  label: l10n.clearanceQuotesAwardAndApproveBtn,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.small,
                  onPressed: () => widget.onAward!(q.quotationId!),
                ),
              if (widget.onSelectQuote != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      size: 18, color: AppTheme.cobalt),
                  tooltip: l10n.apply,
                  onPressed: () => widget.onSelectQuote!(q),
                ),
              ],
              if (widget.onDeleteQuote != null && q.quotationId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.crimson, size: 18),
                  tooltip: l10n.delete,
                  onPressed: () => widget.onDeleteQuote!(q.quotationId!),
                ),
            ],
          ),
        ),

        // Broker Name & License
        DataCell(
          CopyableTableCell(
            value: q.providerName,
            rowSummary: rowSummary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      q.providerName,
                      style: TextStyle(
                        fontWeight:
                            isAwarded ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    if (isLowest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.emeraldBorder),
                        ),
                        child: Text(
                          l10n.clearanceQuotesBadgeLowestCost,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.wcagEmerald,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (q.licenseNumber != null && q.licenseNumber!.isNotEmpty)
                  Text(
                    q.licenseNumber!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Fees
        moneyCell(q.clearanceFee),
        moneyCell(q.inlandTransportFee),
        moneyCell(q.inspectionFee),
        moneyCell(q.portExpenses),
        moneyCell(q.miscellaneousFee),

        // Estimated Total
        moneyCell(q.totalCost, isTotal: true),

        // Duration / Turnaround
        DataCell(
          CopyableTableCell(
            value: days,
            rowSummary: rowSummary,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.charcoalSurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                days,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.12)
            : AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight ? color.withValues(alpha: 0.4) : AppTheme.cloudWhite,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
