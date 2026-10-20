import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

enum ExtractionConfidenceLevel {
  high,
  medium,
  uncoded,
}

/// Visual confidence indicator for AI/OCR extracted quotation items (M1-5).
class ExtractionConfidenceIndicator extends StatelessWidget {
  final double? confidence;
  final String? rawExtractedText;
  final bool isUncoded;
  final VoidCallback? onUncodedTap;
  final bool isCompact;

  const ExtractionConfidenceIndicator({
    super.key,
    this.confidence,
    this.rawExtractedText,
    this.isUncoded = false,
    this.onUncodedTap,
    this.isCompact = true,
  });

  ExtractionConfidenceLevel get level {
    final double? normConf = (confidence != null && confidence! <= 1.0 && confidence! > 0)
        ? confidence! * 100
        : confidence;
    if (isUncoded || (normConf != null && normConf < 60)) {
      return ExtractionConfidenceLevel.uncoded;
    }
    if (normConf != null && normConf >= 85) {
      return ExtractionConfidenceLevel.high;
    }
    return ExtractionConfidenceLevel.medium;
  }

  @override
  Widget build(BuildContext context) {
    if (confidence == null && !isUncoded && (rawExtractedText == null || rawExtractedText!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final l = context.l10n;
    final currentLevel = level;
    final double? normConf = (confidence != null && confidence! <= 1.0 && confidence! > 0)
        ? confidence! * 100
        : confidence;
    final score = normConf?.round() ?? (currentLevel == ExtractionConfidenceLevel.uncoded ? 50 : 80);

    Color badgeColor;
    IconData icon;
    String statusTitle;

    switch (currentLevel) {
      case ExtractionConfidenceLevel.high:
        badgeColor = AppTheme.emerald;
        icon = Icons.verified_rounded;
        statusTitle = isAr ? 'مطابقة ذكية موثوقة ($score%)' : 'Verified Smart Match ($score%)';
        break;
      case ExtractionConfidenceLevel.medium:
        badgeColor = AppTheme.wcagOrange;
        icon = Icons.warning_amber_rounded;
        statusTitle = isAr ? 'مطابقة مقترحة تحتاج مراجعة ($score%)' : 'Suggested Match - Review Needed ($score%)';
        break;
      case ExtractionConfidenceLevel.uncoded:
        badgeColor = AppTheme.crimson;
        icon = Icons.help_outline_rounded;
        statusTitle = isAr
            ? (confidence != null ? '${l.needsCodingBadge} ($score%)' : l.needsCodingBadge)
            : (confidence != null ? 'Needs Coding ($score%)' : 'Needs Coding');
        break;
    }

    final StringBuffer tooltipBuf = StringBuffer(statusTitle);
    if (rawExtractedText != null && rawExtractedText!.trim().isNotEmpty) {
      tooltipBuf.write(isAr ? '\nالنص الأصلي بالمستند: "${rawExtractedText!.trim()}"' : '\nOriginal Text: "${rawExtractedText!.trim()}"');
    }
    if (currentLevel == ExtractionConfidenceLevel.uncoded && onUncodedTap != null) {
      tooltipBuf.write(isAr ? '\n(اضغط للتكويد السريع)' : '\n(Click for quick coding)');
    }

    final badge = Tooltip(
      message: tooltipBuf.toString(),
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.charcoal.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.7)),
      ),
      textStyle: const TextStyle(color: AppTheme.white, fontSize: 11, height: 1.3),
      child: Container(
        padding: isCompact
            ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: currentLevel == ExtractionConfidenceLevel.high
              ? AppTheme.emerald.withValues(alpha: 0.12)
              : (currentLevel == ExtractionConfidenceLevel.medium
                  ? AppTheme.orangeLight
                  : AppTheme.crimsonLight),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isCompact ? 11 : 13, color: badgeColor),
            const SizedBox(width: 3),
            Text(
              currentLevel == ExtractionConfidenceLevel.uncoded
                  ? l.needsCodingBadge
                  : '$score%',
              style: TextStyle(
                fontSize: isCompact ? 9 : 10,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ],
        ),
      ),
    );

    if (currentLevel == ExtractionConfidenceLevel.uncoded && onUncodedTap != null) {
      return InkWell(
        onTap: onUncodedTap,
        borderRadius: BorderRadius.circular(4),
        child: badge,
      );
    }

    return badge;
  }
}
