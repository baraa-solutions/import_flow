import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../vendor_quality_provider.dart';

class VendorHistoricalRankingTable extends ConsumerWidget {
  const VendorHistoricalRankingTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(vendorRankingsProvider);

    return SelectionArea(
      child: rankingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('حدث خطأ في تحميل تصنيف الموردين: $e')),
        data: (rankings) {
          if (rankings.isEmpty) {
            return const Center(child: Text('لا توجد بيانات تصنيف تاريخي للموردين'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rankings.length,
            itemBuilder: (ctx, idx) {
              final r = rankings[idx];
              final passRate = r.inspectionsCount > 0 ? (r.passedCount / r.inspectionsCount) * 100 : 100.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: idx == 0
                              ? AppTheme.emerald.withValues(alpha: 0.15)
                              : idx == 1
                                  ? AppTheme.cobalt.withValues(alpha: 0.15)
                                  : AppTheme.charcoal.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#${idx + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: idx == 0
                                ? AppTheme.emerald
                                : idx == 1
                                    ? AppTheme.cobalt
                                    : AppTheme.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(r.vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const Spacer(),
                                AppStatusBadge(
                                  label: 'الفئة ${r.currentGrade} (${r.avgOverallRating.toStringAsFixed(1)}%)',
                                  severity: r.currentGrade == 'A'
                                      ? AppSeverity.success
                                      : r.currentGrade == 'B'
                                          ? AppSeverity.info
                                          : r.currentGrade == 'C'
                                              ? AppSeverity.warning
                                              : AppSeverity.danger,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                Text('عدد عمليات الفحص: ${r.inspectionsCount}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                Text('نسبة اجتياز الفحص: ${passRate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                                Text('متوسط الجودة: ${r.avgQualityScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppTheme.cobalt)),
                                Text('متوسط الالتزام الزمني: ${r.avgDeliveryTimeliness.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppTheme.orange)),
                                Text('متوسط دقة المستندات: ${r.avgDocumentationAccuracy.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppTheme.charcoal)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => CopyHelper.copy(ctx, '${r.vendorName} - ${r.avgOverallRating.toStringAsFixed(1)}%'),
                        child: const Icon(Icons.copy_rounded, size: 20, color: AppTheme.cobalt),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
