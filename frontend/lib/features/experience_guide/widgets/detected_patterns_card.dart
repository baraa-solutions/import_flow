import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/detected_pattern_model.dart';
import '../providers/experience_guide_provider.dart';
import 'add_guide_entry_dialog.dart';

class DetectedPatternsCard extends ConsumerWidget {
  const DetectedPatternsCard({super.key});

  void _promotePattern(BuildContext context, DetectedPatternModel pattern) {
    showDialog(
      context: context,
      builder: (ctx) => AddGuideEntryDialog(
        initialTitle: 'قاعدة تنظيمية: ${pattern.dimensionValue}',
        initialContent: '${pattern.description}\nالإجراء المقترح: ${pattern.suggestedAction}',
        initialSeverity: pattern.severity,
        initialDepartment: 'Logistics',
        initialSupplier: pattern.dimensionType == 'supplier' ? pattern.dimensionValue : null,
        initialDestinationPort:
            pattern.dimensionType == 'port_of_discharge' ? pattern.dimensionValue : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(detectedPatternsProvider);

    return patternsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (patterns) {
        if (patterns.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FBFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.flatCobalt.withValues(alpha: 0.3)),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            leading: const Icon(Icons.auto_graph_rounded, color: AppTheme.flatCobalt),
            title: Row(
              children: [
                const Text(
                  'الأنماط التشغيلية المتكررة المكتشفة',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.flatCharcoal,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.flatCobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${patterns.length} نمط مكتشف',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.flatCobalt,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: const Text(
              'اكتشاف استباقي للأنماط المتكررة (تأخيرات الموردين، زمن التخليص بالموانئ) مع إمكانية الترقية لقاعدة دائمة',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            children: [
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: patterns.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final p = patterns[idx];
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          p.severity == 'critical'
                              ? Icons.error_outline
                              : Icons.warning_amber_rounded,
                          color: p.severity == 'critical'
                              ? AppTheme.flatCrimson
                              : AppTheme.flatOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    p.dimensionValue,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.flatCharcoal,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      'تكرر ${p.occurrenceCount} مرات',
                                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.description,
                                style: const TextStyle(fontSize: 11, color: AppTheme.flatCharcoal),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'التوصية: ${p.suggestedAction}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.flatCobalt,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.flatCobalt,
                            side: const BorderSide(color: AppTheme.flatCobalt),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.upgrade_rounded, size: 14),
                          label: const Text('ترقية لقاعدة دائمة'),
                          onPressed: () => _promotePattern(context, p),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
