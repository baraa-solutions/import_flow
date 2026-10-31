import 'package:flutter/material.dart';

import '../saved_budgets_registry_tab.dart';
import '../../models/financial_approval_model.dart';

class ApprovedBudgetsRegistryTab extends StatelessWidget {
  final void Function(ImportBudgetModel budget) onEditBudget;
  final VoidCallback onSwitchToForm;
  final void Function(ImportBudgetModel budget)? onCloneBudget;
  final VoidCallback? onSearchAndClone;

  const ApprovedBudgetsRegistryTab({
    super.key,
    required this.onEditBudget,
    required this.onSwitchToForm,
    this.onCloneBudget,
    this.onSearchAndClone,
  });

  @override
  Widget build(BuildContext context) {
    return SavedBudgetsRegistryTab(
      onEditBudget: onEditBudget,
      onSwitchToForm: onSwitchToForm,
      onCloneBudget: onCloneBudget,
      onSearchAndClone: onSearchAndClone,
    );
  }
}
