import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Helper dialogs and handlers for promoting or rejecting autonomous evidence inferences
class EvidenceTrailActionHandlers {
  /// Opens a confirmation dialog to promote inferred entry to confirmed standard
  static Future<bool?> confirmPromote(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: AppTheme.emerald),
              SizedBox(width: 8),
              Text('اعتماد الاستنتاج كقاعدة مؤسسية', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'سيتم قفل هذا النمط وتحويله إلى مرجعية مؤسسية معتمدة ومؤكدة (Confirmed Standard)، '
            'بحيث تظل نشطة ولا يتم أرشفتها تلقائياً عند تغير العينات. هل تريد المتابعة؟',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'تأكيد الاعتماد',
              icon: Icons.check_circle_rounded,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a rejection dialog prompting for a reason, returns the reason string or null if cancelled
  static Future<String?> promptRejectionReason(BuildContext context) async {
    final reasonController = TextEditingController();
    try {
      final rejected = await showDialog<bool>(
        context: context,
        builder: (ctx) => SelectionArea(
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cancel_rounded, color: AppTheme.crimson),
                SizedBox(width: 8),
                Text('استبعاد هذا الاستنتاج الذاتي', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'يرجى توضيح سبب استبعاد هذا الاستنتاج حتى يتعلم النظام ولا يعيد اقتراحه مستقبلاً:',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'مثال: تم الاتفاق على ملحق تعاقدي جديد يلغي هذا التأخير...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              AppButton(
                label: 'استبعاد الاستنتاج',
                icon: Icons.block_rounded,
                variant: AppButtonVariant.danger,
                size: AppButtonSize.small,
                onPressed: () {
                  if (reasonController.text.trim().length >= 3) {
                    Navigator.pop(ctx, true);
                  }
                },
              ),
            ],
          ),
        ),
      );

      if (rejected == true && reasonController.text.trim().length >= 3) {
        return reasonController.text.trim();
      }
      return null;
    } finally {
      reasonController.dispose();
    }
  }
}
