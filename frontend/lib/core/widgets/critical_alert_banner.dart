import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../../features/notifications/models/notification_model.dart';
import '../../features/notifications/providers/notifications_provider.dart';
import '../localization/app_localizations.dart';

/// بانر تنبيهات الحالات الحرجة — يظهر تلقائياً أعلى رادار اللوجستيات
/// عند وجود إشعارات CRITICAL غير مقروءة
class CriticalAlertBanner extends ConsumerWidget {
  const CriticalAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return notificationsAsync.when(
      data: (notifs) {
        final criticals = notifs
            .where((n) => n.severity == 'CRITICAL' && !n.isRead)
            .toList();
        if (criticals.isEmpty) return const SizedBox.shrink();

        final l10n = context.l10n;
        final preview = criticals.take(2).map((n) => n.localizedTitle(l10n)).join('  |  ');
        return Material(
          color: Colors.transparent,
          child: Container(
            color: AppTheme.crimson.withOpacity(0.10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.crimson.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.crisis_alert, color: AppTheme.crimson, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${criticals.length} تنبيه حرج يتطلب تدخلاً فورياً: $preview',
                    style: const TextStyle(
                      color: AppTheme.crimson,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showCriticalAlertsPanel(context, ref, criticals),
                  icon: const Icon(Icons.arrow_forward_ios, size: 11, color: AppTheme.crimson),
                  label: Text(
                    'عرض التفاصيل (${criticals.length})',
                    style: const TextStyle(color: AppTheme.crimson, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showCriticalAlertsPanel(
    BuildContext context,
    WidgetRef ref,
    List<NotificationModel> criticals,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CriticalAlertsPanelSheet(criticals: criticals, ref: ref),
    );
  }
}

class _CriticalAlertsPanelSheet extends StatelessWidget {
  final List<NotificationModel> criticals;
  final WidgetRef ref;

  const _CriticalAlertsPanelSheet({required this.criticals, required this.ref});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.crisis_alert, color: AppTheme.crimson, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'التنبيهات الحرجة (${criticals.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await ref.read(notificationsProvider.notifier).markAllAsRead();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('وضع الكل مقروءاً ✓',
                        style: TextStyle(fontSize: 11, color: AppTheme.cobalt),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Alert List
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: criticals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _AlertCard(alert: criticals[i], ref: ref),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final NotificationModel alert;
  final WidgetRef ref;

  const _AlertCard({required this.alert, required this.ref});

  @override
  Widget build(BuildContext context) {
    final severityColor = alert.severity == 'CRITICAL' ? AppTheme.crimson : AppTheme.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: severityColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: severityColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  alert.severity,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  alert.localizedTitle(context.l10n),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: severityColor,
                  ),
                ),
              ),
              if (!alert.isRead)
                IconButton(
                  icon: Icon(Icons.check_circle_outline, size: 16, color: severityColor),
                  tooltip: 'وضع مقروءاً',
                  onPressed: () async {
                    await ref.read(notificationsProvider.notifier).markAsRead(alert.notificationId);
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.localizedMessage(context.l10n),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            alert.createdAt,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
