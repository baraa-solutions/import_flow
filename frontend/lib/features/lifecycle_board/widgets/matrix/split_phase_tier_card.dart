import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'lifecycle_matrix_layout.dart';
import 'matrix_phase_shell.dart';
import 'matrix_tier_column.dart';

/// Matrix card of a phase longer than 3 steps: one shared header spanning
/// side-by-side sub-columns of at most 3 steps each (e.g. phase 5: 6 steps → 3 + 3;
/// phase 3: 8 steps → stacked 2 + 3 + 3).
class SplitPhaseTierCard extends StatelessWidget {
  final MatrixPhaseBlock block;
  final bool isPhaseSelected;
  final String? selectedStepCode;
  final LifecycleMatrixGateState gateState;
  final ValueChanged<int> onSelectPhase;
  final void Function(int phaseId, String stepCode) onSelectStep;

  const SplitPhaseTierCard({
    super.key,
    required this.block,
    required this.isPhaseSelected,
    required this.selectedStepCode,
    required this.gateState,
    required this.onSelectPhase,
    required this.onSelectStep,
  });

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      width: 1,
      margin: const EdgeInsetsDirectional.symmetric(horizontal: kMatrixTierGap / 2 - 0.5),
      color: AppTheme.borderOf(context),
    );

    final children = <Widget>[];
    for (var i = 0; i < block.tiers.length; i++) {
      if (i > 0) children.add(divider);
      children.add(
        Expanded(
          child: MatrixTierColumn(
            phase: block.phase,
            stepCodes: block.tiers[i],
            selectedStepCode: selectedStepCode,
            gateState: gateState,
            onSelectStep: onSelectStep,
          ),
        ),
      );
    }

    return MatrixPhaseShell(
      phase: block.phase,
      isPhaseSelected: isPhaseSelected,
      gateState: gateState,
      onSelectPhase: onSelectPhase,
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
