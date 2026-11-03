import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/freight_quotation_model.dart';

class FreightMatchedRfqBanner extends StatelessWidget {
  final FreightRFQRequestModel matchedExistingRFQ;
  final VoidCallback onLoadQuotes;

  const FreightMatchedRfqBanner({
    super.key,
    required this.matchedExistingRFQ,
    required this.onLoadQuotes,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_rounded, color: Colors.amber.shade900, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? '💡 توجد عروض أسعار مسجلة مسبقاً لهذا الملف (${matchedExistingRFQ.rfqCode}) — عدد ${matchedExistingRFQ.quotations.length} عروض ناقلين مقدمة.'
                      : '💡 Saved quotations found for this file (${matchedExistingRFQ.rfqCode}) — ${matchedExistingRFQ.quotations.length} carrier quotes available.',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown.shade900),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabic
                      ? 'يمكنك استدعاء هذه العروض في أي وقت بنقرة واحدة لتحديث جدول المقارنة والترسية الفورية:'
                      : 'You can load these quotations anytime with one click to update the comparison and award immediately:',
                  style: TextStyle(fontSize: 11, color: Colors.brown.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.download_for_offline_outlined, size: 16, color: Colors.white),
            label: Text(
              isArabic ? 'استدعاء العروض الآن للجدول' : 'Load Quotes to Table Now',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            onPressed: onLoadQuotes,
          ),
        ],
      ),
    );
  }
}
