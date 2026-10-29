import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/buttons/app_button.dart';
import 'extraction_confidence_indicator.dart';

class ExtractedSummaryItem {
  final String rawName;
  final String? matchedCanonicalName;
  final String? code;
  final String category;
  final String unitType;
  final double price;
  final String currency;
  final double confidence;
  final bool isUncoded;
  final String? notes;

  const ExtractedSummaryItem({
    required this.rawName,
    this.matchedCanonicalName,
    this.code,
    this.category = 'Other Fees',
    this.unitType = 'fixed',
    required this.price,
    this.currency = 'EGP',
    required this.confidence,
    this.isUncoded = false,
    this.notes,
  });
}

/// Dialog displaying summary metrics of AI extraction before applying into form (M1-6).
class ExtractionSummaryDialog extends StatelessWidget {
  final String? fileName;
  final String? brokerName;
  final String? portName;
  final String? title;
  final List<ExtractedSummaryItem> items;

  const ExtractionSummaryDialog({
    super.key,
    this.fileName,
    this.brokerName,
    this.portName,
    this.title,
    required this.items,
  });

  static Future<bool?> show({
    required BuildContext context,
    String? fileName,
    String? brokerName,
    String? portName,
    String? title,
    required List<ExtractedSummaryItem> items,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ExtractionSummaryDialog(
        fileName: fileName,
        brokerName: brokerName,
        portName: portName,
        title: title,
        items: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final l = context.l10n;

    final totalItems = items.length;
    final highConfidenceItems = items.where((i) {
      final double norm = (i.confidence <= 1.0 && i.confidence > 0) ? i.confidence * 100 : i.confidence;
      return !i.isUncoded && norm >= 85;
    }).length;
    final mediumConfidenceItems = items.where((i) {
      final double norm = (i.confidence <= 1.0 && i.confidence > 0) ? i.confidence * 100 : i.confidence;
      return !i.isUncoded && norm >= 60 && norm < 85;
    }).length;
    final uncodedItems = items.where((i) {
      final double norm = (i.confidence <= 1.0 && i.confidence > 0) ? i.confidence * 100 : i.confidence;
      return i.isUncoded || norm < 60;
    }).length;

    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = (mediaQuery.size.width * 0.75).clamp(600.0, 850.0);
    final dialogHeight = (mediaQuery.size.height * 0.82).clamp(420.0, 680.0);

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.cobalt, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'ملخص استخراج البيانات بالذكاء الاصطناعي' : 'AI Extraction Results Summary',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileName != null && fileName!.isNotEmpty
                            ? (isAr ? 'المستند: $fileName' : 'Document: $fileName')
                            : (isAr ? 'تم استخراج وتصنيف بنود المقايسة بنجاح' : 'Quotation items successfully parsed'),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  tooltip: l.cancel,
                ),
              ],
            ),
            const Divider(height: 20),

            // Document metadata banner if available
            if ((brokerName != null && brokerName!.isNotEmpty) ||
                (portName != null && portName!.isNotEmpty) ||
                (title != null && title!.isNotEmpty)) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.charcoalSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.cloudWhite),
                ),
                child: Row(
                  children: [
                    if (brokerName != null && brokerName!.isNotEmpty) ...[
                      const Icon(Icons.person_pin_circle_outlined, size: 16, color: AppTheme.cobalt),
                      const SizedBox(width: 4),
                      Text(
                        '${l.responsibleCustomsBroker}: $brokerName',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 14),
                    ],
                    if (portName != null && portName!.isNotEmpty) ...[
                      const Icon(Icons.anchor_rounded, size: 16, color: AppTheme.cobalt),
                      const SizedBox(width: 4),
                      Text(
                        '${l.targetPortField}: $portName',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 14),
                    ],
                    if (title != null && title!.isNotEmpty) ...[
                      Expanded(
                        child: Text(
                          '${l.priceListTitleField}: $title',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // 4 KPI Summary Cards (Total, High, Medium, Uncoded)
            Row(
              children: [
                _buildKpiCard(
                  title: isAr ? 'إجمالي المستخرج' : 'Total Extracted',
                  count: totalItems,
                  color: AppTheme.cobalt,
                  icon: Icons.receipt_long_rounded,
                  subtitle: isAr ? 'بند تم قراءته' : 'items detected',
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: isAr ? 'مطابقة ذكية موثوقة' : 'High Confidence',
                  count: highConfidenceItems,
                  color: AppTheme.emerald,
                  icon: Icons.verified_rounded,
                  subtitle: '≥ 85% ${isAr ? "دقة" : "confidence"}',
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: isAr ? 'مقترحة للمراجعة' : 'Suggested Review',
                  count: mediumConfidenceItems,
                  color: AppTheme.wcagOrange,
                  icon: Icons.lightbulb_outline_rounded,
                  subtitle: '60-84% ${isAr ? "دقة" : "confidence"}',
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  title: isAr ? 'بحاجة لتكويد' : 'Uncoded Items',
                  count: uncodedItems,
                  color: AppTheme.crimson,
                  icon: Icons.warning_amber_rounded,
                  subtitle: '< 60% ${isAr ? "أو غير مسجل" : "or new"}',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items List Title
            Row(
              children: [
                Text(
                  isAr ? 'معاينة البنود وحالة المطابقة:' : 'Extracted Items & Match Status:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'يرجى مراجعة البنود قبل اعتماد إدراجها بالنموذج' : 'Please review items before confirming import',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Scrollable Items Table / List
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cloudWhite),
                ),
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          isAr ? 'لم يتم العثور على بنود أسعار صالحة بالمستند' : 'No pricing items found in document',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cloudWhite),
                        itemBuilder: (ctx, index) {
                          final item = items[index];
                          final isEven = index.isEven;

                          return Container(
                            color: isEven ? AppTheme.white : AppTheme.charcoalSurface,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                // Index
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Confidence Indicator Badge
                                ExtractionConfidenceIndicator(
                                  confidence: item.confidence,
                                  rawExtractedText: item.rawName,
                                  isUncoded: item.isUncoded,
                                  isCompact: false,
                                ),
                                const SizedBox(width: 10),

                                // Code Badge if available
                                if (item.code != null && item.code!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.code!,
                                      style: const TextStyle(color: AppTheme.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                // Names (Raw & Matched)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.matchedCanonicalName?.isNotEmpty == true
                                            ? item.matchedCanonicalName!
                                            : item.rawName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.matchedCanonicalName?.isNotEmpty == true && item.matchedCanonicalName != item.rawName) ...[
                                        Text(
                                          '${isAr ? "النص الأصلي:" : "Raw:"} ${item.rawName}',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Category & Unit
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    '${item.category} • ${item.unitType}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Price & Currency
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.price > 0
                                        ? AppTheme.emerald.withValues(alpha: 0.08)
                                        : AppTheme.orangeLight,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: item.price > 0
                                          ? AppTheme.emerald.withValues(alpha: 0.3)
                                          : AppTheme.wcagOrange.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    item.price > 0
                                        ? '${item.price.toStringAsFixed(0)} ${item.currency}'
                                        : (isAr ? 'تفاوضي' : 'Negotiable'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: item.price > 0 ? AppTheme.emerald : AppTheme.wcagOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Footer Buttons: Apply to Form / Cancel
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: l.cancel,
                  icon: Icons.close,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.pop(context, false),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: isAr ? 'تطبيق في القائمة' : 'Apply to Form',
                  icon: Icons.check_circle_outline_rounded,
                  variant: AppButtonVariant.success,
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildKpiCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
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
