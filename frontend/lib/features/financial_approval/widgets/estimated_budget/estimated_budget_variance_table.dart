import 'package:flutter/material.dart';

import '../../models/financial_approval_model.dart';
import '../banners/upstream_variance_alert_banner.dart';
import '../consolidated_budget_summary_card.dart';

class EstimatedBudgetVarianceTable extends StatelessWidget {
  final ImportBudgetModel? budget;
  final BudgetPrefillModel? prefill;
  final double? formInvoiceEgp;
  final double? formFreightEgp;
  final double? formDutiesEgp;
  final double? formClearanceEgp;
  final VoidCallback onFillLiveCosts;
  final void Function(dynamic result)? onRecalculateSuccess;

  const EstimatedBudgetVarianceTable({
    super.key,
    required this.budget,
    required this.prefill,
    this.formInvoiceEgp,
    this.formFreightEgp,
    this.formDutiesEgp,
    this.formClearanceEgp,
    required this.onFillLiveCosts,
    this.onRecalculateSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upstream Variance Alert Banner
        UpstreamVarianceAlertBanner(
          budget: budget,
          prefill: prefill,
          formInvoiceEgp: formInvoiceEgp,
          formFreightEgp: formFreightEgp,
          formDutiesEgp: formDutiesEgp,
          formClearanceEgp: formClearanceEgp,
          onFillLiveCosts: onFillLiveCosts,
          onRecalculateSuccess: onRecalculateSuccess,
        ),
        const SizedBox(height: 12),

        // Multi-Currency Live Consolidated Breakdown Tables
        ConsolidatedBudgetSummaryCard(
          budget: budget,
          prefill: prefill,
          invoiceEgp: formInvoiceEgp,
          freightEgp: formFreightEgp,
          customsDutiesEgp: formDutiesEgp,
          clearanceInlandEgp: formClearanceEgp,
          showVarianceAlert: true,
        ),
      ],
    );
  }
}
