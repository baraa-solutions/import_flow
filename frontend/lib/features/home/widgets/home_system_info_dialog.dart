import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../app_update/widgets/app_update_panel.dart';
import '../../production_sync/providers/production_sync_provider.dart';
import '../../production_sync/widgets/production_sync_hub_dialog.dart';

class HomeSystemInfoDialog extends StatelessWidget {
  const HomeSystemInfoDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const HomeSystemInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Consumer(
      builder: (context, r, _) {
        final versionAsync = r.watch(systemVersionInfoProvider);
        final version = versionAsync.whenOrNull(data: (i) => i.version) ?? ApiConstants.clientVersion;
        final buildNum = versionAsync.whenOrNull(data: (i) => i.buildNumber) ?? ApiConstants.clientBuildNumber;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: AppTheme.charcoal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/brand/sorour_logo_icon.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.appTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        l.appSubtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow(Icons.verified, l.systemVersion, 'v$version (Release)'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.build_circle_outlined, l.buildId, 'Build $version+$buildNum'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.dns_outlined, l.backendEngine, 'FastAPI (Port ${ApiConstants.serverPort})'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.storage_outlined, l.database, 'SQLite (sorour_logistics.db)'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.offline_pin_outlined, l.operatingMode, 'Standalone Offline / Local Engine'),
                  const Divider(height: 14),
                  _buildInfoRow(Icons.shield_outlined, l.licenseAndRights, '© 2026 Sorour Logistics. All rights reserved.'),
                  const Divider(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l.updateAboutSectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AppUpdatePanel(),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: Text(l.syncHub, style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                ProductionSyncHubDialog.show(context);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.close, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.cobalt),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11.5, color: Colors.black87, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
