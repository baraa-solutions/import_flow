import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

/// Fixed bottom action bar providing study actions (Refresh, Clear/Reset, Save Draft, Submit).
class ScenarioEvaluatorActionsBar extends StatelessWidget {
  final bool isSaving;
  final bool isEditing;
  final VoidCallback? onRefresh;
  final VoidCallback onResetForm;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmitStudy;

  const ScenarioEvaluatorActionsBar({
    super.key,
    required this.isSaving,
    required this.isEditing,
    this.onRefresh,
    required this.onResetForm,
    required this.onSaveDraft,
    required this.onSubmitStudy,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppTheme.black.withValues(alpha: 0.26) : AppTheme.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Live Refresh Button
                      AppButton(
                        label: '${l.liveRefresh} 🔄',
                        icon: Icons.refresh,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: onRefresh,
                      ),
                      const SizedBox(width: 8),

                      // 2. Clear Form & Start New
                      AppButton(
                        label: '${l.clearAndStartNew} 🔄',
                        icon: Icons.cleaning_services_outlined,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: onResetForm,
                      ),
                      const SizedBox(width: 8),

                      // 3. Save Draft & Continue Later
                      AppButton(
                        label: '${l.saveDraftContinueLater} 💾',
                        icon: Icons.save_outlined,
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.small,
                        onPressed: isSaving ? null : onSaveDraft,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // 4. Final Submit / Save Study
                  AppButton(
                    label: isEditing ? '${l.saveChanges} 💾' : '${l.saveAndSubmitStudy} ✅',
                    icon: Icons.check_circle_outline,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.small,
                    isLoading: isSaving,
                    onPressed: isSaving ? null : onSubmitStudy,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
