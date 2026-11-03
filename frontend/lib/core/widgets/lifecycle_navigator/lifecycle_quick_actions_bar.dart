import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/lifecycle_board/widgets/skip_step_dialog_helper.dart';
import '../../localization/app_localizations.dart';
import '../../models/active_shipment_context.dart';
import '../../theme/app_theme.dart';

class LifecycleQuickActionsBar extends ConsumerWidget {
  final ActiveShipmentContext ctx;
  final bool isAr;
  final AppLocalizations l;
  final void Function(String prompt)? onSendMessage;

  const LifecycleQuickActionsBar({
    super.key,
    required this.ctx,
    required this.isAr,
    required this.l,
    this.onSendMessage,
  });

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? AppTheme.cobalt;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: effectiveColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepLabel = ctx.stepName(isAr ? 'ar' : 'en');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cobaltLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cobaltBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isAr
                  ? l.aiLifecycleActionsFor(stepLabel)
                  : 'Actions for: $stepLabel',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.cobalt,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildActionBtn(
            label: isAr ? l.aiLifecycleActionView : 'View Data',
            icon: Icons.bar_chart_rounded,
            onTap: () {
              onSendMessage?.call(
                isAr
                    ? 'اعرض بيانات وموقف مرحلة ($stepLabel) لشحنة ${ctx.displayText("ar")}.'
                    : 'Show data and status of phase ($stepLabel) for shipment ${ctx.displayText("en")}.',
              );
            },
          ),
          const SizedBox(width: 4),
          _buildActionBtn(
            label: isAr ? l.aiLifecycleActionUpdate : 'Update',
            icon: Icons.edit_note_rounded,
            onTap: () {
              onSendMessage?.call(
                isAr
                    ? 'أريد تحديث وتسجيل بيانات مرحلة ($stepLabel) لشحنة ${ctx.displayText("ar")}.'
                    : 'I want to update and record data for phase ($stepLabel) of shipment ${ctx.displayText("en")}.',
              );
            },
          ),
          const SizedBox(width: 4),
          _buildActionBtn(
            label: isAr ? l.aiLifecycleActionAsk : 'Ask',
            icon: Icons.help_outline_rounded,
            onTap: () {
              onSendMessage?.call(
                isAr
                    ? 'ما هي المتطلبات والمستندات اللازمة لإنجاز مرحلة ($stepLabel)؟'
                    : 'What are the requirements and documents needed to complete ($stepLabel)?',
              );
            },
          ),
          const SizedBox(width: 4),
          _buildActionBtn(
            label: isAr ? l.aiLifecycleActionSkip : 'Skip',
            icon: Icons.fast_forward_rounded,
            color: AppTheme.orange,
            onTap: () {
              final stepCode = 'STEP_${ctx.stepId.toString().padLeft(2, '0')}';
              SkipStepDialogHelper.show(
                context: context,
                ref: ref,
                importFileCode: ctx.fileCode,
                currentStepCode: stepCode,
                currentStepName: stepLabel,
              );
            },
          ),
        ],
      ),
    );
  }
}
