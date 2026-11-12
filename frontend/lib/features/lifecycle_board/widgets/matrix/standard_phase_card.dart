import 'package:flutter/material.dart';

import '../../models/lifecycle_board_model.dart';
import 'lifecycle_matrix_layout.dart';
import 'matrix_phase_shell.dart';
import 'matrix_tier_column.dart';

/// Matrix card of a phase holding up to 3 steps in a single column (e.g. phases 1, 4, 6).
class StandardPhaseCard extends StatelessWidget {
  final PhaseSummaryModel phase;
  final bool isPhaseSelected;
  final String? selectedStepCode;
  final LifecycleMatrixGateState gateState;
  final ValueChanged<int> onSelectPhase;
  final void Function(int phaseId, String stepCode) onSelectStep;

  const StandardPhaseCard({
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
