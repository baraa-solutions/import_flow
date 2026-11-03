// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../shipping_scenarios/providers/shipping_scenarios_provider.dart';

/// 🚢 Saved Shipping Scenarios Studies card for Overview Tab
class OverviewSavedShippingStudiesCard extends ConsumerWidget {
  final int? importFileId;
  final bool isDark;
  final bool isAr;

  const OverviewSavedShippingStudiesCard({
    super.key,
    required this.importFileId,
    required this.isDark,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final shippingState = ref.watch(shippingScenariosProvider);
    final linkedStudies = shippingState.sessions.where((s) => s.importFileId == importFileId).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : Colors.blue.shade50.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.cobalt.withValues(alpha: 0.4) : Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_boat, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                '🚢 ${l.savedShippingStudiesTitle}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (linkedStudies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '-',
                style: TextStyle(color: isDark ? AppTheme.darkTextMuted : Colors.grey, fontStyle: FontStyle.italic, fontSize: 11.5),
              ),
            )
          else
            Column(
              children: linkedStudies.map((s) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBackground : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blue.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.sessionCode, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt, fontSize: 12)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.title ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null), overflow: TextOverflow.ellipsis)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.emerald.withValues(alpha: 0.3) : AppTheme.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isDark ? AppTheme.emerald : AppTheme.emerald.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              s.recommendedScenarioProvider ?? "-",
                              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : AppTheme.emerald, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l.targetEta, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text(s.avgExpectedWarehouseArrivalDate ?? '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l.date, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text('${s.items.isNotEmpty ? s.items.first.readyForShippingDays : 0} d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 12, color: isDark ? AppTheme.darkBorder : null),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isAr ? '⚡ الأبكر' : '⚡ Earliest', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text(s.earliestArrivalScenarioProvider ?? '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt)),
                                      Text(s.earliestArrivalDate ?? "", style: TextStyle(fontSize: 9, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isAr ? '🐢 الأحدث' : '🐢 Latest', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text(s.latestArrivalScenarioProvider ?? '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade300 : AppTheme.orange)),
                                      Text(s.latestArrivalDate ?? "", style: TextStyle(fontSize: 9, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CRD: ${s.cargoReadyDate} | ${s.pickUpAddress ?? "-"} | Transit: ${s.avgExpectedTransitDays} d',
                        style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black87),
                      ),
                      if (s.items.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: s.items.map((opt) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: opt.isRecommended
                                    ? (isDark ? AppTheme.emerald.withValues(alpha: 0.3) : AppTheme.emerald.withValues(alpha: 0.1))
                                    : (isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: opt.isRecommended
                                    ? AppTheme.emerald
                                    : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                              ),
                            ),
                            child: Text(
                              '${opt.providerName} (${opt.vesselName}) | POL: ${opt.polName ?? "-"} ➔ POD: ${opt.podName ?? "-"} | ${opt.sailingDate} ➔ ${opt.expectedWarehouseArrivalDate}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: opt.isRecommended ? FontWeight.bold : FontWeight.normal,
                                color: opt.isRecommended
                                    ? (isDark ? Colors.green.shade300 : AppTheme.charcoal)
                                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
