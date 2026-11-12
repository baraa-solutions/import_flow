import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import 'lifecycle_matrix_layout.dart';

/// One selectable step cell of the lifecycle matrix.
///
/// Shows the step name, its in-progress count and, for the focused file, a lock
/// (blocked payment gate, with the blocking reason as tooltip) or a waived marker.
class MatrixStepCell extends StatelessWidget {
  final int phaseId;
  final String stepCode;
  final int count;
  final Color accentColor;
  final bool isSelected;
  final double height;
  final int maxLines;
  final LifecycleMatrixGateState gateState;
  final void Function(int phaseId, String stepCode) onSelectStep;

  const MatrixStepCell({
    super.key,
    required this.phaseId,
    required this.stepCode,
    required this.count,
    required this.accentColor,
    required this.isSelected,
    required this.height,
    required this.gateState,
    required this.onSelectStep,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = l10n.lifecycleStepName(stepCode);
    final isWaived = gateState.isStepWaived(stepCode);
    final blockReason = gateState.stepBlockReason(stepCode, l10n);
    final isActive = count > 0;

    final textColor = isSelected
        ? accentColor
        : isWaived
            ? AppTheme.textMutedOf(context)
            : AppTheme.textPrimaryOf(context);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 1),
        child: InkWell(
          key: ValueKey('matrix-step-$stepCode'),
          onTap: () => onSelectStep(phaseId, stepCode),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
          child: Tooltip(
            message: isWaived ? '$name\n${l10n.matrixStepWaived}' : name,
            waitDuration: const Duration(milliseconds: 400),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.18)
                    : isActive
                        ? AppTheme.surfaceAltOf(context)
                        : AppTheme.transparent,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm - 2),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : isActive
                          ? AppTheme.borderOf(context)
                          : AppTheme.transparent,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  _StatusIcon(
                    isSelected: isSelected,
                    isActive: isActive,
                    isWaived: isWaived,
                    accentColor: accentColor,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.15,
                        fontWeight: isSelected || isActive ? FontWeight.bold : FontWeight.w500,
                        color: textColor,
                        decoration: isWaived ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (blockReason != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 2),
                      child: Tooltip(
                        message: blockReason,
                        child: Icon(
                          Icons.lock_outline,
                          key: ValueKey('matrix-step-lock-$stepCode'),
                          size: 12,
                          color: AppTheme.crimsonTextOf(context),
                        ),
                      ),
                    ),
                  AppStatusBadge(
                    label: '$count',
                    severity: isActive ? AppSeverity.warning : AppSeverity.info,
                    size: AppStatusBadgeSize.small,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isSelected;
  final bool isActive;
  final bool isWaived;
  final Color accentColor;
  final bool isDark;

  const _StatusIcon({
    required this.isSelected,
    required this.isActive,
    required this.isWaived,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isWaived) {
      return Icon(Icons.do_not_disturb_on_outlined, size: 11, color: AppTheme.textMutedOf(context));
    }
    return Icon(
      isSelected ? Icons.check_circle : (isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked),
      size: 11,
      color: isSelected || isActive ? accentColor : AppTheme.textMutedOf(context),
    );
  }
}
