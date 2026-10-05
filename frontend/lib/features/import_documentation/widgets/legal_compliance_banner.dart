import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/import_documentation_provider.dart';
import 'idoc_ui_b.dart';

/// Legal-document validity banner: green when every legal document is valid
/// beyond ETA + 30 days, a persistent red alert otherwise.
class LegalComplianceBanner extends ConsumerWidget {
  final int? importFileId;

  const LegalComplianceBanner({super.key, required this.importFileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (importFileId == null) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;

    final complianceAsync = ref.watch(legalComplianceFamilyProvider(importFileId!));

    return complianceAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 3),
      error: (err, _) => const SizedBox.shrink(),
      data: (data) {
        if (!data.hasCriticalAlerts && data.overallComplianceStatus == 'COMPLIANT') {
          return IdocBNotice(
            severity: AppSeverity.success,
            icon: Icons.verified_user,
            margin: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
            message: l.idocBLegalCompliantMessage(data.etaDate.toString(), data.safetyWindowDate.toString()),
          );
        }

        // Critical alert banner (persistent red alert)
        return Container(
          margin: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.crimsonBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.crimson.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 26),
                  Text(
                    l.idocBLegalCriticalTitle,
                    style: const TextStyle(color: AppTheme.crimson, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  IdocBStatusChip(
                    severity: AppSeverity.danger,
                    icon: Icons.event,
                    label: l.idocBLegalEta(data.etaDate.toString()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data.persistentBannerText != null)
                Text(
                  data.persistentBannerText!,
                  style: const TextStyle(color: AppTheme.crimson, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: data.alerts.where((a) => a.isCriticalBreach || a.isExpired).map((alert) {
                  return Container(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.crimsonBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.crimson, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.idocBLegalDocExpires(alert.docType.toString(), alert.expiryDate.toString(), alert.daysUntilExpiry.toString()),
                            style: const TextStyle(color: AppTheme.crimson, fontSize: 12, fontWeight: FontWeight.bold),
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
    );
  }
}
