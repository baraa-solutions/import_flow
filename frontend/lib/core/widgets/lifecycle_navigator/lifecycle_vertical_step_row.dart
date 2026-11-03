import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/import_files/models/import_file_model.dart';
import '../../localization/app_localizations.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../theme/app_theme.dart';

class LifecycleVerticalStepRow extends ConsumerWidget {
  final ImportFileModel file;
  final Map<String, String> step;
  final int stepNum;
  final int currentStepIndex;
  final bool isOverdue;
  final bool isSelectedInContext;
  final bool isAr;
  final AppLocalizations l;

  const LifecycleVerticalStepRow({
    super.key,
    required this.file,
    required this.step,
    required this.stepNum,
    required this.currentStepIndex,
    required this.isOverdue,
    required this.isSelectedInContext,
    required this.isAr,
    required this.l,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = stepNum == currentStepIndex;
    final isCompleted = stepNum < currentStepIndex && !isOverdue;

    // Status colors & icons
    final Color stepColor;
    final IconData stepIcon;
    final String statusText;
    final Widget statusSuffix;
    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeTextColor;

    if (isOverdue) {
      stepColor = AppTheme.crimson;
      stepIcon = Icons.error_rounded;
      statusText = isAr ? l.aiLifecycleStatusOverdue : 'Overdue';
      statusSuffix = const Text(' ⚠️', style: TextStyle(fontSize: 9));
      badgeBg = AppTheme.crimsonLight;
      badgeBorder = AppTheme.crimsonBorder;
      badgeTextColor = AppTheme.crimson;
    } else if (isCompleted) {
      stepColor = AppTheme.emerald;
      stepIcon = Icons.check_circle_rounded;
      statusText = isAr ? l.aiLifecycleStatusCompleted : 'Completed';
      statusSuffix = const Text(' ✓',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
      badgeBg = AppTheme.emeraldLight;
      badgeBorder = AppTheme.emeraldBorder;
      badgeTextColor = AppTheme.emerald;
    } else if (isCurrent) {
      stepColor = AppTheme.cobalt;
      stepIcon = Icons.radio_button_checked_rounded;
      statusText = isAr ? l.aiLifecycleStatusActive : 'Active';
      statusSuffix = const Text(' ●', style: TextStyle(fontSize: 8));
      badgeBg = AppTheme.cobaltLight;
      badgeBorder = AppTheme.cobaltBorder;
      badgeTextColor = AppTheme.cobalt;
    } else {
      stepColor = Colors.grey.shade400;
      stepIcon = Icons.radio_button_unchecked_rounded;
      statusText = isAr ? l.aiLifecycleStatusUpcoming : 'Upcoming';
      statusSuffix = const SizedBox.shrink();
      badgeBg = Colors.grey.shade100;
      badgeBorder = Colors.grey.shade300;
      badgeTextColor = Colors.grey.shade600;
    }

    final stepTitle = isAr ? step['nameAr']! : step['nameEn']!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          ref.read(aiAssistantProvider.notifier).setActiveStep(
                shipmentId: file.importFileId,
                shipmentName: file.displayName,
                clientName: file.companyName,
                fileCode: file.importFileCode,
                stepId: stepNum,
                screenReference: step['screen'],
              );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelectedInContext
                ? stepColor.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelectedInContext ? stepColor : Colors.grey.shade200,
              width: isSelectedInContext ? 1.5 : 1,
            ),
            boxShadow: isSelectedInContext
                ? [
                    BoxShadow(
                      color: stepColor.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Indicator icon per status
              Icon(stepIcon, size: 14, color: stepColor),
              const SizedBox(width: 6),
              // Step number and title (never truncated with ellipsis hiding the name)
              Expanded(
                child: Text(
                  '$stepNum. $stepTitle',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isCurrent || isSelectedInContext
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isSelectedInContext || isCurrent
                        ? AppTheme.charcoal
                        : Colors.grey.shade800,
                  ),
                  softWrap: true,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                    statusSuffix,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
