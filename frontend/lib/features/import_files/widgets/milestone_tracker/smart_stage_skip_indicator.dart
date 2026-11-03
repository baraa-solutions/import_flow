// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 📌 Smart Stage Skip Indicator for Lifecycle Stages & Milestone Tracker.
///
/// Handles stages skipped due to postal parcel exemptions (e.g. `STEP_05`, `STEP_10`, `STEP_12`).
/// Displays "معفى نظامياً (طرد بريدي)" with a subtle emerald or muted style
/// rather than an error or pending state.
class SmartStageSkipIndicator extends StatelessWidget {
  final String stepCode;
  final String? stepName;
  final String? exemptionReason;
  final bool compact;

  const SmartStageSkipIndicator({
    super.key,
    required this.stepCode,
    this.stepName,
    this.exemptionReason,
    this.compact = false,
  });

  /// Checks if a specific step code is in the skipped stages list.
  static bool isStepSkipped(List<String> skippedStages, String stepCode) {
    if (skippedStages.isEmpty) return false;
    final normalized = stepCode.toUpperCase().trim();
    return skippedStages.any((s) {
      final cur = s.toUpperCase().trim();
      return cur == normalized ||
          cur.replaceAll('_', '') == normalized.replaceAll('_', '') ||
          (normalized.contains('05') && (cur.contains('STEP_05') || cur.contains('ACID'))) ||
          (normalized.contains('10') && (cur.contains('STEP_10') || cur.contains('CARGOX'))) ||
          (normalized.contains('12') && (cur.contains('STEP_12') || cur.contains('FORM4') || cur.contains('BANK')));
    });
  }

  /// Checks if a 10-phase index has skipped steps.
  /// Phase 3 (num 3): Docs & ACID -> STEP_05
  /// Phase 5 (num 5): CargoX & Shipping -> STEP_10, STEP_12
  static bool isPhaseSkipped(List<String> skippedStages, int phaseNum) {
    if (skippedStages.isEmpty) return false;
    if (phaseNum == 3) {
      return isStepSkipped(skippedStages, 'STEP_05');
    } else if (phaseNum == 5) {
      return isStepSkipped(skippedStages, 'STEP_10') || isStepSkipped(skippedStages, 'STEP_12');
    }
    return false;
  }

  /// Returns clean, idiomatic Arabic title for a step code without English acronyms.
  static String getStepArabicTitle(String stepCode) {
    final code = stepCode.toUpperCase();
    if (code.contains('05') || code.contains('ACID')) {
      return 'رقم القيد الجمركي المبدئي';
    } else if (code.contains('10') || code.contains('CARGOX')) {
      return 'منصة التوثيق الرقمي المعتمد';
    } else if (code.contains('12') || code.contains('FORM4') || code.contains('BANK')) {
      return 'النموذج البنكي والتحويل';
    }
    return 'المرحلة التشغيلية $stepCode';
  }

  /// Returns English title for a step code.
  static String getStepEnglishTitle(String stepCode) {
    final code = stepCode.toUpperCase();
    if (code.contains('05') || code.contains('ACID')) {
      return 'Advance Cargo Registration';
    } else if (code.contains('10') || code.contains('CARGOX')) {
      return 'Blockchain Document Transfer';
    } else if (code.contains('12') || code.contains('FORM4') || code.contains('BANK')) {
      return 'Bank Form 4 Financing';
    }
    return 'Lifecycle Step $stepCode';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final label = isAr ? 'معفى نظامياً (طرد بريدي)' : 'Regulatory Exemption (Postal Parcel)';
    final displayTitle = stepName ?? (isAr ? getStepArabicTitle(stepCode) : getStepEnglishTitle(stepCode));

    return SelectionArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.emerald.withValues(alpha: 0.18)
              : AppTheme.emerald.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark
                ? AppTheme.emerald.withValues(alpha: 0.6)
                : AppTheme.emerald.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: compact ? 12 : 14,
              color: isDark ? Colors.tealAccent : AppTheme.emerald,
            ),
            const SizedBox(width: 4),
            Text(
              displayTitle,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '• $label',
              style: TextStyle(
                fontSize: compact ? 9.5 : 10.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.tealAccent : AppTheme.emerald,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact badge for rendering in phase nodes.
  static Widget phaseBadge({
    required bool isArabic,
    required bool isDark,
    bool compact = true,
  }) {
    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.emerald.withValues(alpha: 0.25)
              : AppTheme.emerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDark ? Colors.tealAccent : AppTheme.emerald,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 10,
              color: isDark ? Colors.tealAccent : AppTheme.emerald,
            ),
            const SizedBox(width: 3),
            Text(
              isArabic ? 'معفى نظامياً' : 'Exempt',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.tealAccent : AppTheme.emerald,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Informative banner summarizing all skipped steps for a shipment file.
  static Widget banner({
    required List<String> skippedStages,
    required bool isArabic,
    required bool isDark,
  }) {
    if (skippedStages.isEmpty) return const SizedBox.shrink();

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.emerald.withValues(alpha: 0.15)
              : AppTheme.emerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? AppTheme.emerald.withValues(alpha: 0.5)
                : AppTheme.emerald.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: isDark ? Colors.tealAccent : AppTheme.emerald,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    isArabic
                        ? 'إعفاء نظامي لمراحل الشحن (طرد بريدي معفى):'
                        : 'Regulatory Stage Exemption (Postal Parcel):',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.tealAccent : AppTheme.emerald,
                    ),
                  ),
                  for (final step in skippedStages)
                    SmartStageSkipIndicator(
                      stepCode: step,
                      compact: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
