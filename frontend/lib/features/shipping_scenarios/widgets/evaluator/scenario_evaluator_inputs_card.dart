import 'package:flutter/material.dart';

import '../../../freight_quotations/widgets/freight_quotations_extractor_dialog.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../freight_ai_extractor_card.dart';
import '../shipping_scenario_evaluator_form.dart';
import '../shipping_scenarios_dialogs.dart';

/// Inputs card component combining AI freight quote extraction and study configuration parameters.
class ScenarioEvaluatorInputsCard extends StatelessWidget {
  final String title;
  final ValueChanged<String> onTitleChanged;
  final DateTime cargoReadyDate;
  final ValueChanged<DateTime> onCargoReadyDateChanged;
  final int? selectedImportFileId;
  final ValueChanged<int?> onImportFileChanged;
  final String pickUpAddress;
  final ValueChanged<String> onPickUpAddressChanged;
  final int? selectedPoId;
  final ValueChanged<int?> onPoChanged;
  final int? selectedProjectId;
  final ValueChanged<int?> onProjectChanged;
  final int avgForm4Days;
  final ValueChanged<int> onAvgForm4DaysChanged;
  final int avgClearanceDays;
  final ValueChanged<int> onAvgClearanceDaysChanged;
  final bool isStackable;
  final ValueChanged<bool> onStackableChanged;
  final int? editingSessionId;
  final String? editingSessionCode;
  final int editFormVersion;
  final VoidCallback onCancelEdit;
  final List<PurchaseOrderModel> poList;
  final List<dynamic> projectsList;
  final ValueChanged<List<ExtractedQuotationOption>> onAddExtractedQuotations;
  final ValueChanged<ExtractedQuotationOption> onAddSingleExtractedQuotation;

  const ScenarioEvaluatorInputsCard({
    super.key,
    required this.title,
    required this.onTitleChanged,
    required this.cargoReadyDate,
    required this.onCargoReadyDateChanged,
    required this.selectedImportFileId,
    required this.onImportFileChanged,
    required this.pickUpAddress,
    required this.onPickUpAddressChanged,
    required this.selectedPoId,
    required this.onPoChanged,
    required this.selectedProjectId,
    required this.onProjectChanged,
    required this.avgForm4Days,
    required this.onAvgForm4DaysChanged,
    required this.avgClearanceDays,
    required this.onAvgClearanceDaysChanged,
    required this.isStackable,
    required this.onStackableChanged,
    required this.editingSessionId,
    required this.editingSessionCode,
    required this.editFormVersion,
    required this.onCancelEdit,
    required this.poList,
    required this.projectsList,
    required this.onAddExtractedQuotations,
    required this.onAddSingleExtractedQuotation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Smart AI Freight Quotations Extractor
        FreightAiExtractorCard(
          onAddQuotations: onAddExtractedQuotations,
          onAddSingleQuotation: onAddSingleExtractedQuotation,
          onAddAllQuotations: onAddExtractedQuotations,
        ),
        const SizedBox(height: 16),

        // Evaluator Form Inputs
        ShippingScenarioEvaluatorForm(
          title: title,
          onTitleChanged: onTitleChanged,
          cargoReadyDate: cargoReadyDate,
          onCargoReadyDateChanged: onCargoReadyDateChanged,
          selectedImportFileId: selectedImportFileId,
          onImportFileChanged: onImportFileChanged,
          pickUpAddress: pickUpAddress,
          onPickUpAddressChanged: onPickUpAddressChanged,
          selectedPoId: selectedPoId,
          onPoChanged: onPoChanged,
          selectedProjectId: selectedProjectId,
          onProjectChanged: onProjectChanged,
          avgForm4Days: avgForm4Days,
          onAvgForm4DaysChanged: onAvgForm4DaysChanged,
          avgClearanceDays: avgClearanceDays,
          onAvgClearanceDaysChanged: onAvgClearanceDaysChanged,
          isStackable: isStackable,
          onStackableChanged: onStackableChanged,
          editingSessionId: editingSessionId,
          editingSessionCode: editingSessionCode,
          editFormVersion: editFormVersion,
          onCancelEdit: onCancelEdit,
          poList: poList,
          projectsList: projectsList,
          onShowContainerComparison: (dualRec, cbm, weightKg) =>
              ShippingScenariosDialogs.showContainerComparisonDialog(context, dualRec, cbm, weightKg),
          onShowVisualLoadPlan: (filteredPos, cbm, weightKg) =>
              ShippingScenariosDialogs.showVisualLoadPlanDialog(context, filteredPos, cbm, weightKg),
        ),
      ],
    );
  }
}
