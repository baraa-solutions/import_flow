import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';

class FreightMonitorOverviewTab extends StatelessWidget {
  final Map<String, dynamic>? statusData;
  final bool isLoading;
  final String? error;
  final bool isSyncingSfx;
  final VoidCallback onFetchStatus;
  final VoidCallback onSyncSfxNow;

  const FreightMonitorOverviewTab({
    super.key,
    required this.statusData,
    required this.isLoading,
    required this.error,
    required this.isSyncingSfx,
    required this.onFetchStatus,
    required this.onSyncSfxNow,
  });

  void _copyCompleteStatusDossier(BuildContext context) {
    final l10n = context.l10n;
    if (statusData == null) return;
    final sb = StringBuffer();
    sb.writeln("=== ${l10n.freightDataConnectorDialogTitle} ===");
    sb.writeln("${l10n.freightDataShaqFreightSection}: ${statusData!['shaq_freight_status']}");
    sb.writeln("${l10n.freightDataLastSyncDate}: ${statusData!['last_sfx_sync'] ?? l10n.freightDataNeverSynced}");
    sb.writeln("${l10n.freightDataTrackedRoutesCount}: ${statusData!['total_sfx_routes_tracked']}");
    sb.writeln("---------------------------------------------");
    sb.writeln("${l10n.freightDataShippingRatesSection}: ${statusData!['shippingrates_status']}");
    sb.writeln("${l10n.freightDataMonthlyQuota}: ${statusData!['monthly_quota_limit']}");
    sb.writeln("${l10n.freightDataQuotaUsed}: ${statusData!['monthly_quota_used']}");
    sb.writeln("${l10n.freightDataQuotaRemaining}: ${statusData!['monthly_quota_remaining']}");
    sb.writeln("${l10n.freightDataTrackedLinesCount}: ${statusData!['active_shipping_lines_tracked']}");
    sb.writeln("---------------------------------------------");
    sb.writeln("${l10n.freightDataPortDecreesSection}: ${statusData!['active_port_decrees_count']}");
    sb.writeln("${l10n.freightDataSimPortAuthority}: ${(statusData!['active_port_authorities'] as List?)?.join(', ') ?? ''}");

    CopyHelper.copy(context, sb.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (isLoading) {
      return const CcStateView.loading();
    }
    if (error != null) {
      return CcStateView.error(
        message: error!,
        actionLabel: l10n.freightDataRefreshStatus,
        onAction: onFetchStatus,
      );
    }

    final data = statusData ?? {};
    final used = (data['monthly_quota_used'] as int?) ?? 0;
    final limit = (data['monthly_quota_limit'] as int?) ?? 25;
    final remaining = (data['monthly_quota_remaining'] as int?) ?? 25;
    final authorities = (data['active_port_authorities'] as List?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Bar
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                onPressed: () => _copyCompleteStatusDossier(context),
                icon: Icons.copy_all_rounded,
                label: l10n.freightDataCopyStatusSummary,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton(
                    onPressed: onFetchStatus,
                    icon: Icons.refresh_rounded,
                    label: l10n.freightDataRefreshStatus,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                  ),
                  AppButton(
                    onPressed: isSyncingSfx ? null : onSyncSfxNow,
                    isLoading: isSyncingSfx,
                    icon: Icons.sync_rounded,
                    label: l10n.freightDataSyncSfxNow,
                    size: AppButtonSize.small,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Shaq-Freight Card
          _buildCard(
            context: context,
            title: l10n.freightDataShaqFreightSection,
            subtitle: l10n.freightDataShaqFreightDesc,
            accentColor: AppTheme.cobalt,
            icon: Icons.alt_route_rounded,
            child: Row(
              children: [
                _buildMetricBox(
                  context: context,
                  label: l10n.freightDataStatusActive,
                  value: data['shaq_freight_status'] ?? '',
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 12),
                _buildMetricBox(
                  context: context,
                  label: l10n.freightDataTrackedRoutesCount,
                  value: "${data['total_sfx_routes_tracked'] ?? 0}",
                  color: AppTheme.cobalt,
                ),
                const SizedBox(width: 12),
                _buildMetricBox(
                  context: context,
                  label: l10n.freightDataLastSyncDate,
                  value: data['last_sfx_sync'] != null
                      ? data['last_sfx_sync'].toString().split('T').first
                      : l10n.freightDataNeverSynced,
                  color: AppTheme.charcoal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. ShippingRates.org Card
          _buildCard(
            context: context,
            title: l10n.freightDataShippingRatesSection,
            subtitle: l10n.freightDataShippingRatesDesc,
            accentColor: AppTheme.emerald,
            icon: Icons.security_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildMetricBox(
                      context: context,
                      label: l10n.freightDataMonthlyQuota,
                      value: "$limit",
                      color: AppTheme.charcoal,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricBox(
                      context: context,
                      label: l10n.freightDataQuotaUsed,
                      value: "$used",
                      color: used > 10 ? AppTheme.orange : AppTheme.cobalt,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricBox(
                      context: context,
                      label: l10n.freightDataQuotaRemaining,
                      value: "$remaining",
                      color: AppTheme.emerald,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricBox(
                      context: context,
                      label: l10n.freightDataTrackedLinesCount,
                      value: "${data['active_shipping_lines_tracked'] ?? 0}",
                      color: AppTheme.charcoal,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.emerald, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.freightDataQuotaGuardAlert,
                          style: const TextStyle(
                            color: AppTheme.emerald,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Port Decrees Card
          _buildCard(
            context: context,
            title: l10n.freightDataPortDecreesSection,
            subtitle: l10n.freightDataPortDecreesDesc,
            accentColor: AppTheme.orange,
            icon: Icons.account_balance_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildMetricBox(
                      context: context,
                      label: l10n.freightDataActiveDecreesCount,
                      value: "${data['active_port_decrees_count'] ?? 0}",
                      color: AppTheme.orange,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: authorities.map((a) {
                          return Chip(
                            label: Text(a, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppTheme.surfaceAltOf(context),
                            side: BorderSide(color: AppTheme.borderOf(context)),
                            avatar: Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color accentColor,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: LtrText(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => CopyHelper.copy(context, value),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
