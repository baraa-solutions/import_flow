import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/financial_approval_model.dart';

/// Search and Clone Previous Import Budget Dialog (UX-CLONE-013)
///
/// Allows users to quickly search previous import budgets by code,
/// title, import file, or status, and select one to clone into a new draft.
class SearchAndCloneBudgetDialog extends StatefulWidget {
  final List<ImportBudgetModel> budgets;
  final ValueChanged<ImportBudgetModel> onSelectBudget;

  const SearchAndCloneBudgetDialog({
    super.key,
    required this.budgets,
    required this.onSelectBudget,
  });

  @override
  State<SearchAndCloneBudgetDialog> createState() =>
      _SearchAndCloneBudgetDialogState();
}

class _SearchAndCloneBudgetDialogState
    extends State<SearchAndCloneBudgetDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<ImportBudgetModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.budgets;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      if (lower.isEmpty) {
        _filtered = widget.budgets;
      } else {
        _filtered = widget.budgets.where((b) {
          final code = b.budgetCode.toLowerCase();
          final title = b.title.toLowerCase();
          final file = (b.importFileCode ?? '').toLowerCase();
          final status = b.budgetStatus.toLowerCase();
          final notes = (b.notes ?? '').toLowerCase();
          return code.contains(lower) ||
              title.contains(lower) ||
              file.contains(lower) ||
              status.contains(lower) ||
              notes.contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
      ),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.copy_all,
                        color: AppTheme.cobalt, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchAndCloneBudgetDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.searchAndCloneBudgetSubtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Bar
              TextField(
                controller: _queryController,
                onChanged: _filter,
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: l.searchByBudgetCodeOrTitleHint,
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textMuted,
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(Icons.search,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      size: 20),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkInputBackground
                      : AppTheme.charcoalSurface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppTheme.cobalt, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Results Count Banner
              Text(
                '${_filtered.length} / ${widget.budgets.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // List of Budgets
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48,
                                color: isDark
                                    ? AppTheme.darkBorder
                                    : AppTheme.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              l.noMatchingBudgetsFound,
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final b = _filtered[idx];
                          final isApproved =
                              b.budgetStatus == 'Budget Approved';
                          final statusColor =
                              isApproved ? AppTheme.emerald : AppTheme.orange;

                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectBudget(b);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkElevatedSurface
                                    : AppTheme.charcoalSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.cloudWhite,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Code + Status + Import File Wrap
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.cobalt
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: AppTheme.cobalt
                                                        .withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                b.budgetCode,
                                                style: const TextStyle(
                                                  color: AppTheme.cobalt,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusColor
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: statusColor
                                                        .withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                b.budgetStatus,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            if (b.importFileCode != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.charcoal
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  b.importFileCode!,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppTheme
                                                            .darkTextSecondary
                                                        : AppTheme.charcoal,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Title
                                        Text(
                                          b.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppTheme.darkTextPrimary
                                                : AppTheme.charcoal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),

                                        // Cost Breakdown Summary
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              '${l.estimatedInvoiceValue}: ${b.invoiceAmountForeign.toStringAsFixed(2)} ${b.invoiceCurrency}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme.textStrong,
                                              ),
                                            ),
                                            Text(
                                              '${l.estimatedFreightCost}: ${b.freightCostForeign.toStringAsFixed(2)} ${b.freightCurrency}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme.textStrong,
                                              ),
                                            ),
                                            Text(
                                              '${l.customsAndVatEstimate}: ${b.customsDutiesEgp.toStringAsFixed(0)} EGP',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppTheme.darkTextSecondary
                                                    : AppTheme.textStrong,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Total Amount + Action Pill
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${b.totalBudgetEgp.toStringAsFixed(2)} EGP',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.emerald,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            l.cloneBudgetTooltip,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.cobalt,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 16,
                                            color: AppTheme.cobalt,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
