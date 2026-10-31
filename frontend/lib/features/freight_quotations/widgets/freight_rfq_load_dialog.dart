import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/freight_quotation_model.dart';
import 'rfq_benchmark_dialog.dart';

class FreightRfqLoadDialog {
  static void show(
    BuildContext context,
    WidgetRef ref, {
    required List<FreightRFQRequestModel> rfqs,
    required ValueChanged<FreightRFQRequestModel> onLoadRfq,
    required ValueChanged<FreightRFQRequestModel> onViewDetails,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        String query = '';
        return SelectionArea(
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isArabic = Localizations.localeOf(ctx).languageCode == 'ar';
              final filtered = rfqs.where((r) {
                if (query.isEmpty) return true;
                final q = query.toLowerCase();
                return r.rfqCode.toLowerCase().contains(q) ||
                    r.title.toLowerCase().contains(q) ||
                    r.polName.toLowerCase().contains(q) ||
                    r.podName.toLowerCase().contains(q);
              }).toList();

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Row(
                  children: [
                    const Icon(Icons.folder_open_outlined, color: AppTheme.cobalt),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'استدعاء طلب عرض أسعار مسجل' : 'Load Saved Freight RFQ',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 780,
                  height: 480,
                  child: Column(
                    children: [
                      AppSearchField(
                        controller: searchCtrl,
                        hint: isArabic
                            ? 'البحث برقم الطلب أو العنوان أو الميناء...'
                            : 'Search RFQ Code, Title, or Port...',
                        onChanged: (v) => setDialogState(() => query = v.trim()),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? AppEmptyState(
                                icon: Icons.search_off_rounded,
                                message: isArabic
                                    ? 'لا توجد طلبات عروض أسعار مسجلة مطابقة'
                                    : 'No matching RFQs found',
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final rfq = filtered[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.cobalt.withValues(alpha: 0.1),
                                      child: const Icon(Icons.directions_boat,
                                          color: AppTheme.cobalt, size: 20),
                                    ),
                                    title: Row(
                                      children: [
                                        InkWell(
                                          borderRadius: BorderRadius.circular(4),
                                          onTap: () => CopyHelper.copy(context, rfq.rfqCode),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(rfq.rfqCode,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.cobalt)),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.copy_rounded,
                                                  size: 12, color: AppTheme.cobalt),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AppStatusBadge.fromStatus(status: rfq.status),
                                        const Spacer(),
                                        Text('\$${rfq.lowestFreightCost}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, color: Colors.green)),
                                      ],
                                    ),
                                    subtitle: Text(
                                        '${rfq.title} • ${rfq.polName} ➔ ${rfq.podName} (${rfq.quotations.length} ${isArabic ? "عروض" : "quotes"})'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        RowActionsPill(
                                          viewTooltip: isArabic ? 'عرض التفاصيل' : 'View details',
                                          onView: () => onViewDetails(rfq),
                                          cloneTooltip: isArabic
                                              ? 'المفاضلة التنافسية وعروض الأسعار'
                                              : 'Benchmarking',
                                          onClone: () => showRFQBenchmarkDialog(
                                            context,
                                            ref,
                                            rfqId: rfq.rfqId,
                                            rfqCode: rfq.rfqCode,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.cobalt,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            onLoadRfq(rfq);
                                          },
                                          child: Text(
                                              isArabic ? 'تحميل للمقارنة' : 'Load to Compare',
                                              style: const TextStyle(
                                                  color: Colors.white, fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
