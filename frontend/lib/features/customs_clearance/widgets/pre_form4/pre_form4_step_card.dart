import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';

/// Reusable Step Card frame for PreForm4NafezaWorkflowDialog
class PreForm4StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final bool isCompleted;
  final String? completionDate;
  final Color accentColor;
  final IconData icon;
  final Widget child;

  const PreForm4StepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.isCompleted,
    required this.completionDate,
    required this.accentColor,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isCompleted
              ? AppTheme.emerald.withValues(alpha: 0.4)
              : AppTheme.borderOf(context),
          width: isCompleted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.emerald.withValues(alpha: 0.08)
                  : accentColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.emerald : accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? AppTheme.emerald : accentColor,
                    ),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isAr ? 'مكتمل' : 'Completed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (completionDate != null) ...[
                          const SizedBox(width: 4),
                          LtrText(
                            '($completionDate)',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAr ? 'في الانتظار' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
