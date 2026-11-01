import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../providers/original_documents_collection_provider.dart';
import '../../services/original_docs_export_service.dart';
import '../idoc_ui.dart';

/// Banner displaying active courier alerts (critical delays and transit warnings).
/// Wrapped in [SelectionArea] with sanitized tracking actions and pure localization.
class OriginalDocsCourierAlertsBanner extends ConsumerWidget {
  final void Function({
    required int importFileId,
    required String courierNo,
    required String courierCompany,
    String? trackingNo,
    required String importFileCode,
  }) onShowDeliveryProof;

  const OriginalDocsCourierAlertsBanner({
    super.key,
    required this.onShowDeliveryProof,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final alertsAsync = ref.watch(courierAlertsProvider);

    return SelectionArea(
      child: alertsAsync.when(
        data: (alertsData) {
          if (alertsData.alerts.isEmpty) {
            return const SizedBox.shrink();
          }

          final hasCritical = alertsData.delayedCount > 0;
          final hasWarning = alertsData.alerts.any((a) => a.alertLevel == 'WARNING');
          final bannerColor = hasCritical
              ? AppTheme.crimson
              : (hasWarning ? AppTheme.orange : AppTheme.cobalt);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bannerColor.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Icon(
                        hasCritical
                            ? Icons.error_outline
                            : (hasWarning ? Icons.warning_amber_rounded : Icons.local_shipping_outlined),
                        color: bannerColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.courierAlertsHeader,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: bannerColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (hasCritical)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.crimson,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l.courierAlertCriticalCount(alertsData.delayedCount),
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (hasWarning) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l.courierAlertWarningCount(
                              alertsData.alerts.where((a) => a.alertLevel == 'WARNING').length,
                            ),
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: alertsData.alerts.map((alert) {
                    final itemColor = alert.alertLevel == 'CRITICAL'
                        ? AppTheme.crimson
                        : (alert.alertLevel == 'WARNING' ? AppTheme.orange : AppTheme.cobalt);

                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                    final alertMsg = isAr ? alert.alertMessageAr : alert.alertMessageEn;

                    return Container(
                      width: 340,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceOf(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: itemColor.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: itemColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    alert.alertLevel == 'CRITICAL'
                                        ? l.idocACriticalDelay
                                        : (alert.alertLevel == 'WARNING'
                                            ? l.idocAWarning
                                            : l.idocAInTransit),
                                    style: TextStyle(
                                      color: itemColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l.daysInTransitLabel(alert.daysInTransit),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: alert.daysInTransit >= 5 ? AppTheme.crimson : AppTheme.charcoal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${alert.importFileCode} — ${alert.courierCompany}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.charcoal,
                            ),
                          ),
                          if (alertMsg.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              alertMsg,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'AWB: ${alert.courierNo}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => OriginalDocsExportService.launchCarrierTracking(
                                  alert.courierCompany,
                                  alert.courierNo,
                                ),
                                child: const Icon(Icons.open_in_new, size: 13, color: AppTheme.cobalt),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: IdocUi.fit(
                              AppButton(
                                label: l.confirmCourierDeliveryBtn,
                                icon: Icons.done_all,
                                variant: AppButtonVariant.success,
                                size: AppButtonSize.small,
                                onPressed: () => onShowDeliveryProof(
                                  importFileId: alert.importFileId,
                                  courierNo: alert.courierNo,
                                  courierCompany: alert.courierCompany,
                                  trackingNo: alert.courierNo,
                                  importFileCode: alert.importFileCode,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
