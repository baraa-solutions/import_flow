import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';

class FreightContainerComparisonDialog {
  static void show(
    BuildContext context, {
    required ContainerDualRecommendationResult dualRec,
    required double totalCbm,
    required double totalWeightKg,
  }) {
    final isArabic = context.l10n.isArabic;
    showDialog(
      context: context,
      builder: (context) {
        return SelectionArea(
          child: DefaultTabController(
            length: 2,
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.inventory_2, color: AppTheme.cobalt),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic
                              ? 'تحليل خيارات الحاويات وسيناريوهات التحميل'
                              : 'Container Options & Loading Scenarios Analysis',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${isArabic ? "إجمالي الشحنة:" : "Total Cargo:"} ${totalCbm.toStringAsFixed(2)} m³ | ${totalWeightKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 750,
                height: 480,
                child: Column(
                  children: [
                    Container(
                      color: AppTheme.charcoal,
                      child: TabBar(
                        indicatorColor: AppTheme.cobalt,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        tabs: [
                          Tab(
                              icon: const Icon(Icons.layers),
                              text: isArabic
                                  ? '📦 قابل للرص (Stackable)'
                                  : '📦 Stackable Cargo'),
                          Tab(
                              icon: const Icon(Icons.view_array),
                              text: isArabic
                                  ? '🚫 غير قابل للرص - طبقة واحدة (Non-Stackable)'
                                  : '🚫 Non-Stackable (Single Layer)'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildComparisonTable(dualRec.stackableResult, isArabic),
                          _buildComparisonTable(dualRec.nonStackableResult, isArabic),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isArabic ? 'إغلاق' : 'Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildComparisonTable(ContainerRecommendationResult rec, bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rec.isStackable
                  ? AppTheme.emerald.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: rec.isStackable ? AppTheme.emerald : Colors.orange.shade800),
            ),
            child: Text(
              '${isArabic ? "التوصية المعتمدة:" : "Approved Recommendation:"} ${rec.recommendationSummary}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rec.isStackable ? AppTheme.emerald : Colors.orange.shade900),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                children: [
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(isArabic ? 'نوع الحاوية (Spec)' : 'Container Spec',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(isArabic ? 'العدد المطلوب' : 'Required Count',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(isArabic ? 'استغلال المساحة %' : 'Space Utilization %',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(isArabic ? 'استغلال الوزن %' : 'Weight Utilization %',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(isArabic ? 'التوصية' : 'Recommendation',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              ...rec.comparisonDetails.map((detail) {
                final spec = detail['spec'] as ContainerSpec;
                final int count = detail['reqCount'] as int;
                final double volUtil = detail['spaceUtil'] as double;
                final double weightUtil = detail['payloadUtil'] as double;
                final isBest = spec.code == rec.recommendedContainerCode;

                return TableRow(
                  decoration: isBest
                      ? BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.12))
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spec.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isBest ? AppTheme.emerald : AppTheme.charcoal)),
                          Text(
                              '${isArabic ? "السعة:" : "Capacity:"} ${spec.internalVolumeCbm} CBM | ${isArabic ? "الحمولة:" : "Payload:"} ${spec.maxPayloadKg} kg',
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('$count x ${spec.code}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isBest ? AppTheme.emerald : AppTheme.charcoal)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${volUtil.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: volUtil > 90 ? Colors.green : Colors.orange)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('${weightUtil.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: weightUtil > 90 ? Colors.green : Colors.orange)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: isBest
                          ? Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppTheme.emerald,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(isArabic ? '🌟 الخيار الأنسب' : '🌟 Best Option',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            )
                          : Text(isArabic ? 'بديل قابل للتطبيق' : 'Viable Alternative',
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
