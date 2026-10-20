import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../demurrage_detention/models/demurrage_model.dart';
import '../../demurrage_detention/providers/demurrage_provider.dart';
import '../../demurrage_detention/screens/demurrage_detention_screen.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class ContainerDemurrageRadarCard extends ConsumerWidget {
  const ContainerDemurrageRadarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radarAsync = ref.watch(containerRadarOverviewProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return radarAsync.when(
      loading: () => Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => const SizedBox.shrink(),
      data: (radar) => _buildRadarCard(context, ref, radar, isDark),
    );
  }

  Widget _buildRadarCard(
    BuildContext context,
    WidgetRef ref,
    ContainerRadarOverviewModel radar,
    bool isDark,
  ) {
    final l = context.l10n;
    return Container(
      key: const Key('containerDemurrageRadarCard'),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: radar.criticalOverdueCount > 0
              ? const Color(0xFFC0392B).withValues(alpha: 0.5)
              : (radar.warningContainersCount > 0
                  ? const Color(0xFFE67E22).withValues(alpha: 0.5)
                  : (isDark ? AppTheme.darkBorder : Colors.grey.shade200)),
          width: radar.criticalOverdueCount > 0 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: radar.criticalOverdueCount > 0
                      ? const Color(0xFFC0392B).withValues(alpha: 0.12)
                      : (radar.warningContainersCount > 0
                          ? const Color(0xFFE67E22).withValues(alpha: 0.12)
                          : const Color(0xFF27AE60).withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.radar_rounded,
                  color: radar.criticalOverdueCount > 0
                      ? const Color(0xFFC0392B)
                      : (radar.warningContainersCount > 0
                          ? const Color(0xFFE67E22)
                          : const Color(0xFF27AE60)),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.demurrageRadarCardTitle,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.demurrageRadarCardSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal.withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('refreshDemurrageRadarBtn'),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: l.demurrageRadarRefreshTooltip,
                onPressed: () => ref.invalidate(containerRadarOverviewProvider),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                key: const Key('openDemurrageRadarBtn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(l.demurrageRadarOpenScreenBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const DemurrageDetentionScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 KPI Badges Bar
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildKpiBadge(
                context,
                title: l.demurrageRadarSafeBadge,
                count: radar.safeContainersCount,
                color: const Color(0xFF27AE60),
                icon: Icons.check_circle_rounded,
                isDark: isDark,
              ),
              _buildKpiBadge(
                context,
                title: l.demurrageRadarWarningBadge,
                count: radar.warningContainersCount,
                color: const Color(0xFFE67E22),
                icon: Icons.warning_amber_rounded,
                isDark: isDark,
              ),
              _buildKpiBadge(
                context,
                title: l.demurrageRadarActiveFinesBadge,
                count: radar.criticalOverdueCount,
                color: const Color(0xFFC0392B),
                icon: Icons.error_rounded,
                isDark: isDark,
              ),
              _buildKpiBadge(
                context,
                title: l.demurrageRadarReturnedBadge,
                count: radar.returnedContainersCount,
                color: const Color(0xFF7F8C8D),
                icon: Icons.assignment_turned_in_rounded,
                isDark: isDark,
              ),
            ],
          ),

          // Accrued Exposure Warning Banner if > 0
          if (radar.totalEstimatedExposureEgp > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFC0392B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC0392B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.priority_high_rounded, color: Color(0xFFC0392B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.demurrageRadarExposureBanner(
                        radar.totalAccruedDemurrageUsd.toStringAsFixed(2),
                        radar.totalAccruedStorageEgp.toStringAsFixed(0),
                        radar.totalEstimatedExposureEgp.toStringAsFixed(0),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC0392B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Container Items List / Carousel
          if (radar.radarItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  l.demurrageRadarEmptyState,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 155,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: radar.radarItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, index) {
                  final item = radar.radarItems[index];
                  return _buildContainerCard(ctx, item, isDark);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiBadge(
    BuildContext context, {
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$title: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerCard(
    BuildContext context,
    ContainerRadarItemModel item,
    bool isDark,
  ) {
    final l = context.l10n;
    final statusColor = _parseColor(item.colorCode);

    final String statusLabel = l.isArabic
        ? item.statusLabelAr
        : (item.radarStatus.contains('SAFE') && !item.radarStatus.contains('RETURNED')
            ? l.demurrageRadarStatusSafe
            : (item.radarStatus.contains('WARNING')
                ? l.demurrageRadarStatusWarning
                : (item.radarStatus.contains('CRITICAL')
                    ? l.demurrageRadarStatusCritical
                    : (item.radarStatus.contains('RETURNED')
                        ? l.demurrageRadarStatusReturned
                        : item.statusLabelAr))));

    final String alertMessage;
    if (l.isArabic) {
      alertMessage = item.alertMessageAr;
    } else {
      if (item.radarStatus.contains('CRITICAL')) {
        final overdueDays = item.demurrageDaysConsumed > item.demurrageFreeDays
            ? (item.demurrageDaysConsumed - item.demurrageFreeDays)
            : 1;
        alertMessage = 'Fine Risk: Exceeded by $overdueDays days! Expedite unstuffing & return.';
      } else if (item.radarStatus.contains('WARNING')) {
        alertMessage = 'Warning: Only ${item.demurrageDaysRemaining} free days left before fines apply.';
      } else if (item.radarStatus.contains('RETURNED')) {
        alertMessage = 'Container ${item.containerNumber} returned safely to shipping line.';
      } else {
        alertMessage = 'Safe: Container is within free time (${item.demurrageDaysRemaining} days remaining).';
      }
    }

    return Container(
      key: Key('radar_item_${item.containerNumber}'),
      width: 340,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Container No & Status Badge
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, size: 16, color: AppTheme.cobalt),
              const SizedBox(width: 4),
              Expanded(
                child: LtrText(
                  item.containerNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          // Middle info: Carrier & File
          Text(
            '${item.carrierName} • ${item.importFileCode}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal.withValues(alpha: 0.7),
            ),
            overflow: TextOverflow.ellipsis,
          ),

          // Days comparison progress bars / indicators
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.demurrageRadarCarrierFreeDays,
                      style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    l.demurrageRadarDaysCount(item.demurrageDaysConsumed, item.demurrageFreeDays),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: item.demurrageFreeDays > 0 ? (item.demurrageDaysConsumed / item.demurrageFreeDays).clamp(0.0, 1.0) : 1.0,
                  backgroundColor: isDark ? Colors.black26 : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    item.demurrageDaysRemaining <= 0 ? const Color(0xFFC0392B) : (item.demurrageDaysRemaining <= 4 ? const Color(0xFFE67E22) : const Color(0xFF27AE60)),
                  ),
                  minHeight: 4,
                ),
              ),
            ],
          ),

          // Alert Message snippet
          Text(
            alertMessage,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF27AE60);
    }
  }
}
