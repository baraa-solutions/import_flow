import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Header banner for Freight Quotations Extractor Dialog matching Smart Invoice Review UI.
class QuotationsExtractorHeader extends StatelessWidget {
  final double confidenceScore;
  final VoidCallback onClose;

  const QuotationsExtractorHeader({
    super.key,
    required this.confidenceScore,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final int confidencePercent = (confidenceScore * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? 'نتائج الاستخراج — استخراج كامل'
                      : 'Extraction Results — Full Extraction',
                  style: const TextStyle(
                    color: AppTheme.emerald,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isArabic
                      ? 'عروض أسعار الشحن والنولون · معدل الثقة: $confidencePercent%'
                      : 'Freight Quotations · Confidence: $confidencePercent%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.charcoal.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          // Confidence Progress Indicator Badge
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$confidencePercent%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.emerald,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: confidenceScore,
                    color: AppTheme.emerald,
                    backgroundColor: AppTheme.emerald.withValues(alpha: 0.2),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
