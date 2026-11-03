import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/lifecycle_board_model.dart';
import 'lifecycle_board_helpers.dart';
import 'phase_pending_badge.dart';

/// Phase summary top card displayed horizontally in the Lifecycle Kanban Board.
class LifecyclePhaseCard extends StatelessWidget {
  final PhaseSummaryModel phase;
  final double width;
  final bool isPhaseSelected;
  final String? selectedStepCode;
  final ValueChanged<int> onSelectPhase;
  final void Function(int phaseId, String stepCode) onSelectStep;

  const LifecyclePhaseCard({
    super.key,
    required this.phase,
    required this.width,
    required this.isPhaseSelected,
    required this.selectedStepCode,
    required this.onSelectPhase,
    required this.onSelectStep,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final headerColor = parseHexColor(phase.colorHex);

    return SelectionArea(
      child: Container(
        width: width,
        margin: const EdgeInsetsDirectional.only(end: 8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPhaseSelected ? headerColor : headerColor.withValues(alpha: 0.35),
            width: isPhaseSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => onSelectPhase(phase.phaseId),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(5),
                    topEnd: Radius.circular(5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.lifecyclePhaseName(phase.phaseId, phase.titleAr, phase.titleEn),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PhasePendingBadge(
                      pendingCount: phase.totalActiveShipments,
                      baseColor: headerColor,
                    ),
                  ],
                ),
              ),
            ),
            // Phase pending files status indicator strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : headerColor.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppTheme.darkBorder : headerColor.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isAr
                          ? '${phase.totalActiveShipments} ملفات بها مهام قيد المتابعة'
                          : '${phase.totalActiveShipments} pending files in phase',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (phase.totalActiveShipments > 0)
                    AppStatusBadge(
                      label: isAr ? 'نشط' : 'Active',
                      severity: AppSeverity.warning,
                      size: AppStatusBadgeSize.small,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
              child: Column(
                children: phase.stepCodes.map((stepCode) {
                  final count = phase.stepCounts[stepCode] ?? 0;
                  final isStepSelected = selectedStepCode == stepCode;
                  final localizedName = l10n.lifecycleStepName(stepCode);

                  return InkWell(
                    onTap: () => onSelectStep(phase.phaseId, stepCode),
                    borderRadius: BorderRadius.circular(4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(
                        color: isStepSelected
                            ? headerColor.withValues(alpha: 0.18)
                            : count > 0
                                ? (isDark ? AppTheme.darkSurface : Colors.grey.shade50)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isStepSelected
                              ? headerColor
                              : count > 0
                                  ? (isDark ? AppTheme.darkBorder : Colors.grey.shade300)
                                  : Colors.transparent,
                          width: isStepSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isStepSelected
                                ? Icons.check_circle
                                : (count > 0 ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                            size: 11,
                            color: isStepSelected
                                ? headerColor
                                : (count > 0 ? headerColor : Colors.grey.shade400),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              localizedName,
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: isStepSelected || count > 0 ? FontWeight.bold : FontWeight.w500,
                                color: isStepSelected ? headerColor : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppStatusBadge(
                            label: '$count',
                            severity: count > 0 ? AppSeverity.warning : AppSeverity.info,
                            size: AppStatusBadgeSize.small,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
