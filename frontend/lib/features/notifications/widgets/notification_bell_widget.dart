import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../operational_dashboard/providers/operational_dashboard_provider.dart';
import '../models/notification_model.dart';
import '../providers/notifications_provider.dart';
import '../../../core/localization/app_localizations.dart';

class NotificationBellWidget extends ConsumerWidget {
  const NotificationBellWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifs = ref.watch(notificationsProvider);

    return asyncNotifs.when(
      loading: () => const IconButton(
        icon: Icon(Icons.notifications_none, color: Colors.white70),
        onPressed: null,
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.notifications_off, color: Colors.white38),
        onPressed: () => ref.read(notificationsProvider.notifier).fetchNotifications(),
      ),
      data: (notifs) {
        final unreadList = notifs.where((n) => !n.isRead).toList();
        final unreadCount = unreadList.length;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isAr = ref.watch(localeProvider).languageCode == 'ar';
        final l10n = context.l10n;

        return PopupMenuButton<void>(
          tooltip: isAr ? 'إشعارات النظام والتنبيهات' : 'System Notifications & Alerts',
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          offset: const Offset(0, 45),
          constraints: const BoxConstraints(minWidth: 360, maxWidth: 440),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications, color: Colors.white, size: 24),
              if (unreadCount > 0)
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: unreadList.any((n) => n.severity == 'CRITICAL')
                          ? AppTheme.crimson
                          : AppTheme.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          itemBuilder: (ctx) => [
            PopupMenuItem<void>(
              enabled: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isAr ? 'التنبيهات والإشعارات ($unreadCount)' : 'Alerts & Notifications ($unreadCount)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                          ),
                          onPressed: () {
                            ref.read(notificationsProvider.notifier).triggerExpiryCheck();
                            Navigator.pop(ctx);
                          },
                          child: Text(isAr ? 'فحص الصلاحيات' : 'Check Expiry', style: const TextStyle(fontSize: 11)),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 4),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: isDark ? Colors.tealAccent : AppTheme.cobalt,
                            ),
                            onPressed: () {
                              ref.read(notificationsProvider.notifier).markAllAsRead();
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              isAr ? 'قراءة الكل' : 'Mark All Read',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            if (notifs.isEmpty)
              PopupMenuItem<void>(
                enabled: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    height: 60,
                    alignment: Alignment.center,
                    child: Text(
                      isAr ? 'لا توجد تنبيهات جديدة حالياً.' : 'No new notifications currently.',
                      style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              )
            else
              ...notifs.take(8).map((n) {
                    final targetName = _getTargetScreenName(n.category, n.entityType, isAr);
                    final targetIcon = _getTargetScreenIcon(n.category, n.entityType);
                    final sevColor = _getSeverityBgColor(n.severity);

                    return PopupMenuItem<void>(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      onTap: () => _handleNotificationClick(ref, n),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: n.isRead
                                  ? (isDark ? AppTheme.darkElevatedSurface.withValues(alpha: 0.5) : Colors.transparent)
                                  : (isDark ? sevColor.withValues(alpha: 0.2) : sevColor.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(8),
                              border: BorderDirectional(
                                end: isAr ? BorderSide(color: sevColor, width: 3.5) : BorderSide.none,
                                start: !isAr ? BorderSide(color: sevColor, width: 3.5) : BorderSide.none,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getCategoryIcon(n.category, n.severity),
                                      size: 16,
                                      color: isDark
                                          ? (n.severity == 'CRITICAL'
                                              ? Colors.redAccent
                                              : (n.severity == 'WARNING' ? Colors.orangeAccent : Colors.lightBlueAccent))
                                          : sevColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        n.localizedTitle(l10n),
                                        style: TextStyle(
                                          fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                                          fontSize: 12,
                                          color: isDark
                                              ? (n.isRead ? AppTheme.darkTextSecondary : AppTheme.darkTextPrimary)
                                              : (n.isRead ? Colors.grey.shade700 : AppTheme.charcoal),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n.localizedMessage(l10n),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(targetIcon, size: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                targetName,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTheme.cobalt.withValues(alpha: 0.28)
                                            : AppTheme.cobalt.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDark ? AppTheme.cobalt.withValues(alpha: 0.6) : AppTheme.cobalt.withValues(alpha: 0.35),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isAr ? 'تنفيذ المهمة' : 'Execute Task',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.open_in_new_rounded,
                                            size: 11,
                                            color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
          ],
        );
      },
    );
  }

  void _handleNotificationClick(WidgetRef ref, NotificationModel n) {
    if (!n.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead(n.notificationId);
    }

    // Extract shipment code if present (e.g. IMP-2026-0004)
    final codeRegex = RegExp(r'IMP-\d{4}-\d{4}');
    final match = codeRegex.firstMatch('${n.title} ${n.message}')?.group(0);
    if (match != null) {
      try {
        ref.read(operationalDashboardProvider.notifier).setSearchQuery(match);
      } catch (_) {}
    }

    final targetIndex = _getTargetScreenIndex(n.category, n.entityType);
    selectNavigationIndex(ref, targetIndex);
  }

  int _getTargetScreenIndex(String category, String? entityType) {
    final cat = category.toUpperCase();
    final ent = (entityType ?? '').toUpperCase();

    if (cat.contains('INCOMPLETE_DOCS') || cat.contains('DOC') || cat.contains('COURIER')) {
      return 51; // CentralDocsArchiveScreen
    }
    if (cat.contains('REGULATORY') || cat.contains('INSPECTION') || ent.contains('REQUIREMENT')) {
      return 43; // ImportRequirementsScreen
    }
    if (cat.contains('COMPANY') || ent.contains('COMPANY')) {
      return 32; // ImportCompaniesScreen
    }
    if (cat.contains('ACID') || ent.contains('ACID')) {
      return 11; // NafezaAcidScreen
    }
    if (cat.contains('CARGOX')) {
      return 54; // OriginalDocsAndCargoXScreen
    }
    if (cat.contains('FORM4') || cat.contains('BANK')) {
      return 16; // BankForm4Screen
    }
    if (cat.contains('DEMURRAGE') || cat.contains('DETENTION') || cat.contains('CONTAINER') || ent.contains('DEMURRAGE')) {
      return 44; // DemurrageDetentionScreen
    }
    if (cat.contains('TASK') || ent.contains('TASK')) {
      return 40; // SmartTasksScreen
    }
    if (cat.contains('CURRENCY') || cat.contains('EXCHANGE')) {
      return 38; // CurrenciesScreen
    }
    if (cat.contains('BUDGET') || cat.contains('VARIANCE')) {
      return 8; // FinancialApprovalScreen
    }
    if (ent.contains('IMPORTFILE')) {
      return 0; // OperationalDashboardScreen (focused on the shipment)
    }
    return 40; // Default: SmartTasksScreen
  }

  String _getTargetScreenName(String category, String? entityType, bool isAr) {
    final cat = category.toUpperCase();
    final ent = (entityType ?? '').toUpperCase();

    if (cat.contains('INCOMPLETE_DOCS') || cat.contains('DOC') || cat.contains('COURIER')) {
      return isAr ? 'الأرشيف المركزي للمستندات' : 'Central Docs Archive';
    }
    if (cat.contains('REGULATORY') || cat.contains('INSPECTION') || ent.contains('REQUIREMENT')) {
      return isAr ? 'اشتراطات وموافقات الاستيراد' : 'Import Requirements';
    }
    if (cat.contains('COMPANY') || ent.contains('COMPANY')) {
      return isAr ? 'الشركات المستوردة' : 'Import Companies';
    }
    if (cat.contains('ACID') || ent.contains('ACID')) {
      return isAr ? 'منظومة نافذة ACID' : 'Nafeza ACID Engine';
    }
    if (cat.contains('CARGOX')) {
      return isAr ? 'منظومة CargoX للمستندات' : 'CargoX Documents Engine';
    }
    if (cat.contains('FORM4') || cat.contains('BANK')) {
      return isAr ? 'نموذج 4 البنكي' : 'Bank Form 4';
    }
    if (cat.contains('DEMURRAGE') || cat.contains('DETENTION') || cat.contains('CONTAINER') || ent.contains('DEMURRAGE')) {
      return isAr ? 'رادار الغرامات والأرضيات' : 'Demurrage & Detention Radar';
    }
    if (cat.contains('TASK') || ent.contains('TASK')) {
      return isAr ? 'المهام الذكية' : 'Smart Tasks';
    }
    if (cat.contains('CURRENCY') || cat.contains('EXCHANGE')) {
      return isAr ? 'العملات وأسعار الصرف' : 'Currencies & Rates';
    }
    if (cat.contains('BUDGET') || cat.contains('VARIANCE')) {
      return isAr ? 'الموافقات المالية' : 'Financial Approvals';
    }
    if (ent.contains('IMPORTFILE')) {
      return isAr ? 'لوحة تحكم الشحنات' : 'Operational Dashboard';
    }
    return isAr ? 'المهام الذكية' : 'Smart Tasks';
  }

  IconData _getTargetScreenIcon(String category, String? entityType) {
    final cat = category.toUpperCase();
    final ent = (entityType ?? '').toUpperCase();

    if (cat.contains('INCOMPLETE_DOCS') || cat.contains('DOC') || cat.contains('COURIER')) {
      return Icons.inventory_2_outlined;
    }
    if (cat.contains('REGULATORY') || cat.contains('INSPECTION') || ent.contains('REQUIREMENT')) {
      return Icons.verified_outlined;
    }
    if (cat.contains('COMPANY') || ent.contains('COMPANY')) {
      return Icons.domain_outlined;
    }
    if (cat.contains('ACID') || ent.contains('ACID')) {
      return Icons.cloud_done_outlined;
    }
    if (cat.contains('CARGOX')) {
      return Icons.cloud_upload_outlined;
    }
    if (cat.contains('FORM4') || cat.contains('BANK')) {
      return Icons.account_balance_outlined;
    }
    if (cat.contains('DEMURRAGE') || cat.contains('DETENTION') || cat.contains('CONTAINER') || ent.contains('DEMURRAGE')) {
      return Icons.timer_outlined;
    }
    if (cat.contains('TASK') || ent.contains('TASK')) {
      return Icons.checklist_outlined;
    }
    if (cat.contains('CURRENCY') || cat.contains('EXCHANGE')) {
      return Icons.currency_exchange_outlined;
    }
    if (cat.contains('BUDGET') || cat.contains('VARIANCE')) {
      return Icons.monetization_on_outlined;
    }
    return Icons.open_in_new_rounded;
  }

  Color _getSeverityBgColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return AppTheme.crimson;
      case 'WARNING':
        return AppTheme.orange;
      default:
        return AppTheme.cobalt;
    }
  }

  IconData _getCategoryIcon(String category, String severity) {
    final cat = category.toUpperCase();
    if (cat.contains('CARGOX')) return Icons.cloud_upload_outlined;
    if (cat.contains('FORM4') || cat.contains('BANK')) return Icons.account_balance_outlined;
    if (cat.contains('DETENTION') || cat.contains('CONTAINER')) return Icons.local_shipping_outlined;
    if (cat.contains('COURIER') || cat.contains('DOC')) return Icons.markunread_mailbox_outlined;
    if (cat.contains('REGULATORY') || cat.contains('INSPECTION')) return Icons.verified_user_outlined;
    if (cat.contains('BUDGET') || cat.contains('VARIANCE')) return Icons.attach_money_outlined;
    if (cat.contains('CURRENCY') || cat.contains('EXCHANGE')) return Icons.currency_exchange_outlined;
    if (cat.contains('COMPANY')) return Icons.business_outlined;
    if (cat.contains('ACID')) return Icons.timer_outlined;

    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Icons.error_outline;
      case 'WARNING':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }
}
