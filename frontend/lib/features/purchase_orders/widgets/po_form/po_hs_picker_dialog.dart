import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../customs_tariff/models/customs_tariff_model.dart';

/// Modal dialog for searching and picking a Customs Tariff item.
class PoHsPickerDialog {
  static Future<CustomsTariffModel?> show(
    BuildContext context,
    List<CustomsTariffModel> tariffs,
  ) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return showDialog<CustomsTariffModel?>(
      context: context,
      builder: (ctx) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = search.trim().toLowerCase();
            final filtered = tariffs.where((t) {
              if (query.isEmpty) return true;
              return t.hsCode.toLowerCase().contains(query) ||
                  t.hsDescription.toLowerCase().contains(query) ||
                  t.categorySearchText.contains(query);
            }).toList();

            return SelectionArea(
              child: AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.search, color: AppTheme.cobalt),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'اختيار البند الجمركي' : 'Select Customs Tariff',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 600,
                  height: 450,
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? 'ابحث برقم البند الجمركي أو الوصف...'
                              : 'Search by HS code or description...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.cobalt),
                          suffixIcon: search.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setDialogState(() => search = ''),
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setDialogState(() => search = v),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  isArabic
                                      ? 'لا توجد نتائج مطابقة لمفتاح البحث'
                                      : 'No matching results found',
                                  style: const TextStyle(color: AppTheme.textMuted),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final item = filtered[i];
                                  final categoryLabel = isArabic
                                      ? (item.categoryLabelArabic ?? 'عام')
                                      : (item.categoryLabelArabic ?? 'General');
                                  return ListTile(
                                    dense: true,
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cobalt.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: LtrText(
                                            item.hsCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.cobalt,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.hsDescription,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        isArabic
                                            ? 'الفئة: $categoryLabel | جمارك: ${item.customsDutyRate}% | قيمة مضافة: ${item.vatRate}% | رسم تنمية: ${item.developmentFeeRate}%'
                                            : 'Category: $categoryLabel | Customs: ${item.customsDutyRate}% | VAT: ${item.vatRate}% | Dev: ${item.developmentFeeRate}%',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textStrong),
                                      ),
                                    ),
                                    onTap: () => Navigator.pop(ctx, item),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  AppButton(
                    label: isArabic ? 'إلغاء' : 'Cancel',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(ctx, null),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
