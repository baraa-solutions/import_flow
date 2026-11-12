import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/providers/payment_pathway_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../providers/lifecycle_board_provider.dart';
import '../providers/live_polling_provider.dart';
import '../widgets/kanban_phases_view.dart';
import '../widgets/live_radar_view.dart';

/// Coordinator screen for the Import Lifecycle Operations Board and Live Logistics Radar.
class LifecycleBoardScreen extends ConsumerStatefulWidget {
  const LifecycleBoardScreen({super.key});

  @override
  ConsumerState<LifecycleBoardScreen> createState() => _LifecycleBoardScreenState();
}

class _LifecycleBoardScreenState extends ConsumerState<LifecycleBoardScreen> {
  int _viewModeIndex = 0; // 0: 6-Phase Kanban Board, 1: Live Logistics Tracking Radar

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(lifecycleBoardSummaryProvider);
      ref.invalidate(liveLogisticsTrackingProvider);
      ref.invalidate(livePollingProvider);
      ref.invalidate(paymentPathwayStatusProvider);
    });
  }

  void _refreshAll() {
    ref.invalidate(lifecycleBoardSummaryProvider);
    ref.invalidate(liveLogisticsTrackingProvider);
    ref.invalidate(livePollingProvider);
    ref.invalidate(paymentPathwayStatusProvider);
    // CL-006: تشغيل فحص التنبيهات الحرجة عند كل تحديث يدوي
    ref.read(notificationsProvider.notifier).triggerExpiryCheck();
  }

  Widget _buildViewModeTab({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _viewModeIndex == index;
    final density = ref.watch(displayDensityProvider);

    return InkWell(
      onTap: () {
        if (_viewModeIndex != index) {
          setState(() => _viewModeIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cobalt : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: density.buttonIconSize - 2,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PageHeader(
        icon: _viewModeIndex == 0 ? Icons.view_kanban_outlined : Icons.radar_outlined,
        iconColor: AppTheme.cobalt,
        title: _viewModeIndex == 0 ? l10n.lifecycleBoardTitle : l10n.viewModeLiveRadar,
        elevation: 2,
        actions: [
          // Dual View Switcher Segmented Control
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewModeTab(
                  index: 0,
                  label: l10n.viewModeKanbanPhases,
                  icon: Icons.view_kanban_outlined,
                ),
                _buildViewModeTab(
                  index: 1,
                  label: l10n.viewModeLiveRadar,
                  icon: Icons.radar,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // CL-004: مؤشر التحديث الحي (يظهر فقط في وضع الرادار)
          if (_viewModeIndex == 1) ...[
            ref.watch(isRefreshingProvider)
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: AppLoadingState.inline(),
                    ),
                  )
                : ref.watch(refreshCountdownProvider).when(
                    data: (seconds) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: seconds <= 10
                            ? AppTheme.orange.withValues(alpha: 0.3)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: seconds <= 10
                              ? AppTheme.orange.withValues(alpha: 0.5)
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: density.buttonIconSize - 4,
                            color: seconds <= 10 ? AppTheme.orange : Colors.white60,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${seconds}s',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: seconds <= 10 ? AppTheme.orange : Colors.white60,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white, size: density.buttonIconSize),
            tooltip: l10n.refreshLiveBoardTooltip,
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 6),
          const BackToDashboardButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SelectionArea(
        child: _viewModeIndex == 0
            ? KanbanPhasesView(onRefresh: _refreshAll)
            : LiveRadarView(onRefresh: _refreshAll),
      ),
    );
  }
}
