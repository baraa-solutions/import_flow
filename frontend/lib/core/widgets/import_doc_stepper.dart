import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A unified stepper navigation bar for all Import Documentation screens.
/// Supports any number of steps with consistent pill-button design.
class ImportDocStepper extends StatelessWidget {
  final List<ImportDocStep> steps;
  final int currentStep;
  final ValueChanged<int> onStepTapped;

  const ImportDocStepper({
    super.key,
    required this.steps,
    required this.currentStep,
    required this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isActive = currentStep == index;
            final isCompleted = currentStep > index;

            return Padding(
              padding: EdgeInsetsDirectional.only(end: index < steps.length - 1 ? 8 : 0),
              child: _ImportDocStepButton(
                step: step,
                isActive: isActive,
                isCompleted: isCompleted,
                onTap: () => onStepTapped(index),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ImportDocStepButton extends StatelessWidget {
  final ImportDocStep step;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback onTap;

  const _ImportDocStepButton({
    required this.step,
    required this.isActive,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isActive
        ? AppTheme.cobalt
        : isCompleted
            ? AppTheme.emerald.withOpacity(0.12)
            : Colors.grey.shade100;

    final Color contentColor = isActive
        ? Colors.white
        : isCompleted
            ? AppTheme.emerald
            : Colors.black87;

    final FontWeight fontWeight =
        isActive ? FontWeight.bold : FontWeight.normal;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: isCompleted && !isActive
                ? Border.all(color: AppTheme.emerald.withOpacity(0.4))
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.cobalt.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCompleted && !isActive ? Icons.check_circle : step.icon,
                size: 15,
                color: contentColor,
              ),
              const SizedBox(width: 7),
              Text(
                step.label,
                style: TextStyle(
                  color: contentColor,
                  fontWeight: fontWeight,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data model for a single step in [ImportDocStepper].
class ImportDocStep {
  final String label;
  final IconData icon;

  const ImportDocStep({required this.label, required this.icon});
}
