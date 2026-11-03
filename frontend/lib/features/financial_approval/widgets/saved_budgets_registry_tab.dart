import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/financial_approval_model.dart';
import '../providers/financial_approval_provider.dart';
import 'saved_budgets/saved_budgets_actions_handler.dart';
import 'saved_budgets/saved_budgets_metrics_toolbar.dart';
import 'saved_budgets/saved_budget_card.dart';
import 'saved_budgets/saved_budgets_empty_state.dart';

class SavedBudgetsRegistryTab extends ConsumerStatefulWidget {
  final void Function(ImportBudgetModel budget) onEditBudget;
  final VoidCallback onSwitchToForm;
  final void Function(ImportBudgetModel budget)? onCloneBudget;
  final VoidCallback? onSearchAndClone;

  const SavedBudgetsRegistryTab({
    super.key,
    required this.onEditBudget,
    required this.onSwitchToForm,
    this.onCloneBudget,
    this.onSearchAndClone,
  });

  @override
  ConsumerState<SavedBudgetsRegistryTab> createState() =>
      _SavedBudgetsRegistryTabState();
}

class _SavedBudgetsRegistryTabState
    extends ConsumerState<SavedBudgetsRegistryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetsState = ref.watch(importBudgetsProvider);
    final budgetsList = budgetsState.valueOrNull ?? [];

    return SelectionArea(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
            if (widget.onSearchAndClone != null) {
              widget.onSearchAndClone!();
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: _buildHistoryRegistryTab(budgetsList),
        ),
      ),
    );
  }

  Widget _buildHistoryRegistryTab(List<ImportBudgetModel> budgetsList) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = budgetsList.where((b) {
      if (!b.isActive) return false;
      final q = _searchController.text.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          b.budgetCode.toLowerCase().contains(q) ||
          b.title.toLowerCase().contains(q) ||
          (b.importFileCode != null &&
              b.importFileCode!.toLowerCase().contains(q)) ||
          (b.approvedBy != null && b.approvedBy!.toLowerCase().contains(q));

      if (!matchQuery) return false;

      if (_selectedStatusFilter == 'Approved') {
        return b.budgetStatus.toLowerCase().contains('approved');
      } else if (_selectedStatusFilter == 'Pending') {
        return b.budgetStatus.toLowerCase().contains('pending') ||
            b.budgetStatus.toLowerCase().contains('draft');
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SavedBudgetsMetricsToolbar(
          budgetsList: budgetsList,
          filteredBudgets: filtered,
          searchController: _searchController,
          selectedStatusFilter: _selectedStatusFilter,
          onStatusFilterChanged: (val) =>
              setState(() => _selectedStatusFilter = val),
          onSwitchToForm: widget.onSwitchToForm,
          onSearchAndClone: widget.onSearchAndClone,
          ref: ref,
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
        ),
        Expanded(
          child: filtered.isEmpty
              ? SavedBudgetsEmptyState(
                  isDark: isDark,
                  onSwitchToForm: widget.onSwitchToForm,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final budget = filtered[index];
                    return SavedBudgetCard(
                      budget: budget,
                      isDark: isDark,
                      onEditBudget: widget.onEditBudget,
                      onCloneBudget: widget.onCloneBudget,
                      onViewDetails: () =>
                          SavedBudgetsActionsHandler.showBudgetDetailsDialog(
                        context,
                        budget: budget,
                        onEditBudget: widget.onEditBudget,
                      ),
                      onDelete: () =>
                          SavedBudgetsActionsHandler.confirmDeleteBudget(
                        context,
                        ref: ref,
                        budget: budget,
                      ),
                      onWhatsApp: () =>
                          SavedBudgetsActionsHandler.showWhatsAppShareDialog(
                        context,
                        budget,
                      ),
                      onEmail: () =>
                          SavedBudgetsActionsHandler.showEmailShareDialog(
                        context,
                        budget,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
