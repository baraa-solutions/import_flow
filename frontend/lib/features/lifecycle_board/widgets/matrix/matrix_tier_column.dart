import 'package:flutter/material.dart';

import '../../models/lifecycle_board_model.dart';
import '../lifecycle_board_helpers.dart';
import 'lifecycle_matrix_layout.dart';
import 'matrix_step_cell.dart';

/// One sub-column of at most 3 steps inside a matrix phase card.
///
/// - 3 steps → three standard rows.
/// - 2 steps → two single-step blocks stacked vertically, sharing the 3-row height.
/// - 1 step  → a single block filling the 3-row height.
class MatrixTierColumn extends StatelessWidget {
  final PhaseSummaryModel phase;
  final List<String> stepCodes;
  final String? selectedStepCode;
  final LifecycleMatrixGateState gateState;
  final void Function(int phaseId, String stepCode) onSelectStep;

  const MatrixTierColumn({
    super.key,
    required this.phase,
    required this.stepCodes,
    required this.selectedStepCode,
    required this.gateState,
    required this.onSelectStep,
  });

  /// True when the tier renders as stacked single-step blocks (fewer than 3 steps).
  bool get isStacked => stepCodes.length < kMatrixMaxStepsPerTier;

  @override
  Widget build(BuildContext context) {
    assert(stepCodes.length <= kMatrixMaxStepsPerTier, 'A matrix tier may hold at most 3 steps');
    final accentColor = parseHexColor(phase.colorHex);
    const totalHeight = kMatrixStepRowHeight * kMatrixMaxStepsPerTier;
    final cellHeight = stepCodes.isEmpty
        ? kMatrixStepRowHeight
        : isStacked
            ? totalHeight / stepCodes.length
            : kMatrixStepRowHeight;
    // Taller stacked blocks let long step names wrap instead of being cut.
    final maxLines = !isStacked ? 1 : (stepCodes.length == 1 ? 3 : 2);

    return Column(
      key: ValueKey('matrix-tier-${phase.phaseId}-${stepCodes.isEmpty ? 'empty' : stepCodes.first}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final stepCode in stepCodes)
          MatrixStepCell(
            phaseId: phase.phaseId,
            stepCode: stepCode,
            count: phase.stepCounts[stepCode] ?? 0,
            accentColor: accentColor,
            isSelected: selectedStepCode == stepCode,
            height: cellHeight,
            maxLines: maxLines,
            gateState: gateState,
            onSelectStep: onSelectStep,
          ),
      ],
    );
  }
}
