import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/widgets/states/app_loading_state.dart';
import '../../app_update/widgets/app_update_panel.dart';
import '../providers/production_sync_provider.dart';

/// Top banner displaying system version, update state, and release notes.
class ProductionSyncVersionCard extends ConsumerWidget {
  const ProductionSyncVersionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateCheckStateProvider);
    final l = context.l10n;
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return updateState.when(
      data: (result) {
        if (result == null) {
          final versionInfo = ref.watch(systemVersionInfoProvider);
          return _buildCard(
            context,
            ref: ref,
            version: versionInfo.whenOrNull(data: (i) => i.version) ?? ApiConstants.clientVersion,
            buildNumber: versionInfo.whenOrNull(data: (i) => i.buildNumber) ?? ApiConstants.clientBuildNumber,
            hasUpdate: false,
            message: l.prodSyncSystemUpToDateMsg,
            l: l,
          );
        }
        final versionInfo = ref.watch(systemVersionInfoProvider);
        final bannerMsg = !result.hasUpdate
            ? l.prodSyncSystemUpToDateMsg
            : (isArabic
                ? result.message
                : (result.latestVersion.isNotEmpty
                    ? 'New update v${result.latestVersion} is available.'
                    : 'A new system update is available.'));
        return _buildCard(
          context,
          ref: ref,
          version: result.currentVersion,
          buildNumber: versionInfo.whenOrNull(data: (i) => i.buildNumber) ?? ApiConstants.clientBuildNumber,
          hasUpdate: result.hasUpdate,
          latestVersion: result.latestVersion,
          message: bannerMsg,
          releaseNotes: result.releaseNotes,
          downloadUrl: result.downloadUrl,
          l: l,
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const AppLoadingState.inline(),
            const SizedBox(width: 12),
            Text(l.prodSyncCheckingCloudUpdates, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      error: (e, _) => _buildCard(
        context,
        ref: ref,
        version: ApiConstants.clientVersion,
        buildNumber: ApiConstants.clientBuildNumber,
        hasUpdate: false,
        message: l.prodSyncOfflineModeMsg,
        l: l,
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required WidgetRef ref,
    required String version,
    required int buildNumber,
    required bool hasUpdate,
    String? latestVersion,
    required String message,
    List<String> releaseNotes = const [],
    String? downloadUrl,
    required AppLocalizations l,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasUpdate ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasUpdate ? AppTheme.cobalt : Colors.grey.shade300, width: hasUpdate ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Clickable Version Badge with Copy Trigger
              InkWell(
                onTap: () => CopyHelper.copy(
                  context,
                  'v$version (Build $buildNumber)',
                  customMessage: l.prodSyncCopyFieldTooltip,
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasUpdate ? AppTheme.cobalt : AppTheme.charcoal,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'v$version (Build $buildNumber)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      hasUpdate ? Icons.system_update_rounded : Icons.check_circle_rounded,
                      color: hasUpdate ? AppTheme.cobalt : AppTheme.emerald,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: hasUpdate ? AppTheme.cobalt : AppTheme.charcoal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // In-app updates (verified download/install by the backend)
              AppButton(
                label: l.updateSectionTitle,
                size: AppButtonSize.small,
                variant: hasUpdate ? AppButtonVariant.success : AppButtonVariant.ghost,
                icon: Icons.system_update_rounded,
                onPressed: () => showAppUpdatePanelDialog(context),
              ),
              const SizedBox(width: 8),
              // Check for Updates Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(l.prodSyncCheckUpdatesBtn, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  ref.read(productionSyncNotifierProvider.notifier).checkForUpdates();
                },
              ),
            ],
          ),

          // Release Notes
          if (hasUpdate && releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.prodSyncWhatsNewInVersion(latestVersion ?? ''),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.charcoal),
                  ),
                  const SizedBox(height: 4),
                  ...releaseNotes.map((note) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(' • ', style: TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(note, style: const TextStyle(fontSize: 11.5, color: Colors.black87))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
