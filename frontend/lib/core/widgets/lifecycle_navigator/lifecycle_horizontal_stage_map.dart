import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/import_files/models/import_file_model.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../theme/app_theme.dart';
import 'lifecycle_constants.dart';

class LifecycleHorizontalStageMap extends ConsumerWidget {
  final ImportFileModel file;
  final AiAssistantState state;
  final bool isAr;
  final int currentStepIndex;
  final Set<int> overdueStepIds;

  const LifecycleHorizontalStageMap({
    super.key,
    required this.file,
    required this.state,
    required this.isAr,
    required this.currentStepIndex,
    required this.overdueStepIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: LifecycleConstants.kLifecycleSteps.map((step) {
          final stepNum = int.tryParse(step['id']!) ?? 1;
          final isCompleted = stepNum < currentStepIndex;
          final isCurrent = stepNum == currentStepIndex;
          final isOverdue = overdueStepIds.contains(stepNum);

          final isSelectedInContext = state.activeContext != null &&
              state.activeContext!.shipmentId == file.importFileId &&
              state.activeContext!.stepId == stepNum;

          final Color stepColor;
          final Color stepBg;
          final IconData stepIcon;

          if (isCompleted) {
            stepColor = AppTheme.emerald;
            stepBg = AppTheme.emeraldLight;
            stepIcon = Icons.check_circle_rounded;
          } else if (isOverdue) {
            stepColor = AppTheme.crimson;
            stepBg = AppTheme.crimsonLight;
            stepIcon = Icons.warning_amber_rounded;
          } else if (isCurrent) {
            stepColor = AppTheme.cobalt;
            stepBg = AppTheme.cobaltLight;
            stepIcon = Icons.play_circle_fill_rounded;
          } else {
            stepColor = Colors.grey.shade500;
            stepBg = Colors.grey.shade100;
            stepIcon = Icons.radio_button_unchecked_rounded;
          }

          final stepTitle = isAr ? step['nameAr']! : step['nameEn']!;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelectedInContext ? stepBg : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isSelectedInContext ? stepColor : Colors.grey.shade300,
                    width: isSelectedInContext ? 1.8 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(stepIcon, size: 14, color: stepColor),
                        const SizedBox(width: 4),
                        Text(
                          '$stepNum',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: stepColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stepTitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isSelectedInContext
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelectedInContext
                            ? AppTheme.charcoal
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
