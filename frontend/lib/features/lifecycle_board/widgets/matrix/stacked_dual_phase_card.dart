import 'package:flutter/material.dart';

import '../../models/lifecycle_board_model.dart';
import 'lifecycle_matrix_layout.dart';
import 'matrix_phase_shell.dart';
import 'matrix_tier_column.dart';

/// Matrix card of a two-step phase whose single-step stages are stacked vertically
/// in one column (e.g. phase 2: finance approvals over ACID pre-registration), so
/// the column stays within the 3-step height instead of leaving dead whitespace.
class StackedDualPhaseCard extends StatelessWidget {
  final PhaseSummaryModel phase;
  final bool isPhaseSelected;
  final String? selectedStepCode;
  final LifecycleMatrixGateState gateState;
  final ValueChanged<int> onSelectPhase;
  final void Function(int phaseId, String stepCode) onSelectStep;

  const StackedDualPhaseCard({
    super.key,
    required this.phase,
    required this.isPhaseSelected,
    required this.selectedStepCode,
    required this.gateState,
    required this.onSelectPhase,
    required this.onSelectStep,
  });

  @override
  Widget build(BuildContext context) {
    assert(phase.stepCodes.length == 2, 'StackedDualPhaseCard expects exactly two steps');
    return MatrixPhaseShell(
      phase: phase,
      isPhaseSelected: isPhaseSelected,
      gateState: gateState,
      onSelectPhase: onSelectPhase,
      body: MatrixTierColumn(
        phase: phase,
        stepCodes: phase.stepCodes,
        selectedStepCode: selectedStepCode,
        gateState: gateState,
        onSelectStep: onSelectStep,
      ),
    );
  }
}
