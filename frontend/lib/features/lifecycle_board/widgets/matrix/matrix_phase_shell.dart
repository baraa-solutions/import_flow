import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/lifecycle_board_model.dart';
import '../lifecycle_board_helpers.dart';
import 'lifecycle_matrix_layout.dart';

/// Shared frame of every matrix phase card: fixed 3-step height, coloured
/// selectable header (title, payment-gate lock, pending badge) and a body slot.
class MatrixPhaseShell extends StatelessWidget {
  final PhaseSummaryModel phase;
  final bool isPhaseSelected;
  final LifecycleMatrixGateState gateState;
  final ValueChanged<int> onSelectPhase;
  final Widget body;

  const MatrixPhaseShell({
    super.key,
    required this.phase,
    required this.isPhaseSelected,
    required this.gateState,
    required this.onSelectPhase,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = parseHexColor(phase.colorHex);
    final title = l10n.lifecyclePhaseName(phase.phaseId, phase.titleAr, phase.titleEn);
    final blockReason = gateState.phaseBlockReason(phase.phaseId, l10n);

    return Container(
      key: ValueKey('matrix-phase-${phase.phaseId}'),
      height: kMatrixCardHeight,
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: isPhaseSelected ? headerColor : headerColor.withValues(alpha: isDark ? 0.6 : 0.35),
          width: isPhaseSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('matrix-phase-header-${phase.phaseId}'),
            onTap: () => onSelectPhase(phase.phaseId),
            child: Container(
              height: kMatrixHeaderHeight,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(AppTheme.radiusSm - 1),
                  topEnd: Radius.circular(AppTheme.radiusSm - 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: title,
                      waitDuration: const Duration(milliseconds: 400),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (blockReason != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 3),
                      child: Tooltip(
                        message: blockReason,
                        child: Icon(
                          Icons.lock,
                          key: ValueKey('matrix-phase-lock-${phase.phaseId}'),
                          size: 13,
                          color: AppTheme.white,
                        ),
                      ),
                    ),
                  // Compact count keeps the narrow 3-step column header readable.
                  Tooltip(
                    message: l10n.phasePendingBadgeTooltip,
                    child: AppStatusBadge(
                      key: ValueKey('matrix-phase-count-${phase.phaseId}'),
                      label: '${phase.totalActiveShipments}',
                      severity: phase.totalActiveShipments > 0 ? AppSeverity.warning : AppSeverity.success,
                      size: AppStatusBadgeSize.small,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(kMatrixBodyPadding),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
