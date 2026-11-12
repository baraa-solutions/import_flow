import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/lifecycle_board_model.dart';
import 'lifecycle_matrix_layout.dart';
import 'split_phase_tier_card.dart';
import 'stacked_dual_phase_card.dart';
import 'standard_phase_card.dart';

/// Capped 3-step symmetrical overview matrix of the lifecycle board.
///
/// Every card shares one fixed height (header + 3 step rows); long phases are split
/// into 3-step sub-columns and short ones stack their single-step stages, so the
/// strip fits a 1366px desktop with no horizontal scrolling. Widths are flex-based
/// (one unit per sub-column); only below [matrixMinimumWidth] does it scroll.
class LifecyclePhaseMatrix extends StatelessWidget {
  final List<PhaseSummaryModel> phases;
  final int totalActiveFiles;
  final int? selectedPhaseId;
  final String? selectedStepCode;
  final LifecycleMatrixGateState gateState;
  final ValueChanged<int> onSelectPhase;
  final void Function(int phaseId, String stepCode) onSelectStep;
  final VoidCallback onShowAll;

  const LifecyclePhaseMatrix({
    super.key,
    required this.phases,
    required this.totalActiveFiles,
    required this.selectedPhaseId,
    required this.selectedStepCode,
    required this.onSelectPhase,
    required this.onSelectStep,
    required this.onShowAll,
    this.gateState = LifecycleMatrixGateState.empty,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = planLifecycleMatrix(phases);
    final minimumWidth = matrixMinimumWidth(blocks);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = !constraints.hasBoundedWidth || constraints.maxWidth >= minimumWidth;
        final row = _buildRow(blocks);
        if (fits) return SizedBox(key: const ValueKey('matrix-strip-fitted'), height: kMatrixCardHeight, child: row);
        // Narrow-window fallback only (below the 1366px desktop target).
        return SizedBox(
          key: const ValueKey('matrix-strip-scrolling'),
          height: kMatrixCardHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minimumWidth, child: row),
          ),
        );
      },
    );
  }

  Widget _buildRow(List<MatrixPhaseBlock> blocks) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Expanded(
            flex: block.tierCount,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: kMatrixCardGap),
              child: _buildCard(block),
            ),
          ),
        SizedBox(
          width: kMatrixResetCardWidth,
          child: _AllPhasesResetCard(
            totalActiveFiles: totalActiveFiles,
            isSelected: selectedPhaseId == null && selectedStepCode == null,
            onTap: onShowAll,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(MatrixPhaseBlock block) {
    final phaseId = block.phase.phaseId;
    final isPhaseSelected = selectedPhaseId == phaseId && selectedStepCode == null;
    final stepSelection = selectedPhaseId == phaseId ? selectedStepCode : null;
    switch (block.kind) {
      case MatrixPhaseKind.split:
        return SplitPhaseTierCard(
          block: block,
          isPhaseSelected: isPhaseSelected,
          selectedStepCode: stepSelection,
          gateState: gateState,
          onSelectPhase: onSelectPhase,
          onSelectStep: onSelectStep,
        );
      case MatrixPhaseKind.stackedDual:
        return StackedDualPhaseCard(
          phase: block.phase,
          isPhaseSelected: isPhaseSelected,
          selectedStepCode: stepSelection,
          gateState: gateState,
          onSelectPhase: onSelectPhase,
          onSelectStep: onSelectStep,
        );
      case MatrixPhaseKind.standard:
        return StandardPhaseCard(
          phase: block.phase,
          isPhaseSelected: isPhaseSelected,
          selectedStepCode: stepSelection,
          gateState: gateState,
          onSelectPhase: onSelectPhase,
          onSelectStep: onSelectStep,
        );
    }
  }
}

/// "All shipments / all phases" reset tile closing the matrix row.
class _AllPhasesResetCard extends StatelessWidget {
  final int totalActiveFiles;
  final bool isSelected;
  final VoidCallback onTap;

  const _AllPhasesResetCard({
    required this.totalActiveFiles,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = AppTheme.cobaltTextOf(context);

    return Tooltip(
      message: l10n.allShipmentsAllPhases,
      child: InkWell(
        key: const ValueKey('matrix-show-all'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          height: kMatrixCardHeight,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.cobalt.withValues(alpha: 0.10) : AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isSelected ? AppTheme.cobalt : AppTheme.borderOf(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.all_inclusive, size: 20, color: isSelected ? accent : AppTheme.textMutedOf(context)),
              const SizedBox(height: 4),
              Text(
                l10n.matrixAllPhasesShort,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? accent : AppTheme.textPrimaryOf(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              AppStatusBadge(
                label: '$totalActiveFiles',
                severity: AppSeverity.info,
                size: AppStatusBadgeSize.small,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
