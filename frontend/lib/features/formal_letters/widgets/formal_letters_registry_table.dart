import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/formal_letter_model.dart';

/// Registry table and history list for generated official formal letters.
class FormalLettersRegistryTable extends StatelessWidget {
  final List<FormalLetterRecordModel> history;
  final int? selectedFileId;
  final VoidCallback? onRefresh;
  final void Function(FormalLetterRecordModel record)? onSelect;

  const FormalLettersRegistryTable({
    super.key,
    required this.history,
    this.selectedFileId,
    this.onRefresh,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 18, color: AppTheme.charcoal),
                const SizedBox(width: 6),
                Text(
                  isArabic ? 'سجل الخطابات الصادرة للشحنة' : 'Shipment Letters History',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                if (selectedFileId != null && onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: isArabic ? 'تحديث' : 'Refresh',
                    onPressed: onRefresh,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Text(
                        isArabic
                            ? 'لا توجد خطابات رسمية سابقة مسجلة لهذه الشحنة'
                            : 'No previous letters recorded for this shipment',
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final rec = history[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          onTap: onSelect != null ? () => onSelect!(rec) : null,
                          title: Text(
                            rec.letterTitleAr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          subtitle: Text(
                            '${rec.letterCode} — ${isArabic ? "بواسطة:" : "By:"} ${rec.createdBy}',
                            style: const TextStyle(fontSize: 10.5),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            color: AppTheme.cobalt,
                            tooltip: isArabic ? 'نسخ نص الخطاب' : 'Copy letter text',
                            onPressed: () => CopyHelper.copy(context, rec.letterBody),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
