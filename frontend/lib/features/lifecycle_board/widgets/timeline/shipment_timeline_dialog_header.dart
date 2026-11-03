import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class ShipmentTimelineDialogHeader extends StatelessWidget {
  final String importFileCode;
  final bool isSyncing;
  final VoidCallback onTriggerSync;

  const ShipmentTimelineDialogHeader({
    super.key,
    required this.importFileCode,
    required this.isSyncing,
    required this.onTriggerSync,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = l.isArabic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.charcoal,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.timeline_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isAr
                          ? 'سجل المسار الزمني التشغيلي (25 مرحلة)'
                          : 'Master Operational Timeline Dossier (25 Stages)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: LtrText(
                        importFileCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isAr
                      ? 'متابعة حية لمطابقة الـ SLA، انحرافات المواعيد، ونقاط الاختناق التشغيلية'
                      : 'Live tracking of stage SLAs, schedule variances, and bottleneck constraints',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            label: isAr ? 'مزامنة المسار' : 'Sync Timeline',
            icon: Icons.sync,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            isLoading: isSyncing,
            onPressed: onTriggerSync,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: isAr ? 'إغلاق' : 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
