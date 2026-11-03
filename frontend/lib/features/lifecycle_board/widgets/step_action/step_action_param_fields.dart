import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';

class StepActionParamFields extends StatelessWidget {
  final String stepCode;
  final TextEditingController param1Controller;
  final TextEditingController param2Controller;
  final TextEditingController param3Controller;
  final TextEditingController notesController;
  final List<String> allStepCodes;
  final List<String> selectedNextSteps;
  final void Function(String stepCode, bool selected) onToggleNextStep;

  const StepActionParamFields({
    super.key,
    required this.stepCode,
    required this.param1Controller,
    required this.param2Controller,
    required this.param3Controller,
    required this.notesController,
    required this.allStepCodes,
    required this.selectedNextSteps,
    required this.onToggleNextStep,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step-Specific Parameters Form
        Text(
          l10n.currentStepRequirementsHeader,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: param1Controller,
                decoration: InputDecoration(
                  labelText: l10n.stepParam1Label(stepCode),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: l10n.copyValue,
                    onPressed: () => CopyHelper.copy(context, param1Controller.text),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? l10n.requiredFieldValidation : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: param2Controller,
                decoration: InputDecoration(
                  labelText: l10n.stepParam2Label(stepCode),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: l10n.copyValue,
                    onPressed: () => CopyHelper.copy(context, param2Controller.text),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: param3Controller,
          decoration: InputDecoration(
            labelText: l10n.stepParam3Label(stepCode),
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: l10n.copyValue,
              onPressed: () => CopyHelper.copy(context, param3Controller.text),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Next Step Multi-Target Picker (Supports Concurrent Multi-Stage)
        Text(
          l10n.targetNextPhasesHeader,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allStepCodes.map((sCode) {
            final isSelected = selectedNextSteps.contains(sCode);
            return FilterChip(
              backgroundColor: AppTheme.surfaceAltOf(context),
              side: BorderSide(color: AppTheme.borderOf(context)),
              label: Text(
                '$sCode: ${l10n.lifecycleStepName(sCode)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppTheme.textPrimaryOf(context),
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.cobalt,
              checkmarkColor: Colors.white,
              onSelected: (selected) => onToggleNextStep(sCode, selected),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Notes & Live Updates
        Text(
          l10n.stepNotesHeader,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.stepNotesHint,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: l10n.copyValue,
              onPressed: () => CopyHelper.copy(context, notesController.text),
            ),
          ),
        ),
      ],
    );
  }
}
