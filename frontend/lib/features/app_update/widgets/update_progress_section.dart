import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/update_format.dart';
import '../models/update_models.dart';

/// Renders one `GET /status` snapshot: progress bar while downloading (sized
/// by the installer), determinate "preparing rollback copy" bar, indeterminate
/// bar while verifying / backing up / installing, ready / failed notices.
/// Idle and unknown render nothing.
class UpdateProgressSection extends StatelessWidget {
  final UpdateStatus status;

  /// `installer_size_bytes` of the check, used for the download total.
  final int? installerSizeBytes;

  const UpdateProgressSection({super.key, required this.status, this.installerSizeBytes});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busyText = updateBusyText(l, status, installerSizeBytes: installerSizeBytes);
    if (busyText != null) {
      return _bar(
        text: busyText,
        value: updateBusyProgress(status, installerSizeBytes: installerSizeBytes),
        color: switch (status.state) {
          UpdateState.backingUp => AppTheme.orange,
          UpdateState.installing => AppTheme.emerald,
          _ => AppTheme.cobalt,
        },
      );
    }
    switch (status.state) {
      case UpdateState.ready:
        return _notice(l.updateReadyToInstall, AppTheme.emerald, Icons.verified_rounded);
      case UpdateState.failed:
        // error_detail is the backend's Arabic message (hash_mismatch,
        // size_exceeded, download_failed, ...).
        final detail = status.errorDetail;
        return _notice(
          detail == null ? l.updateFailed : '${l.updateFailed}: $detail',
          AppTheme.crimson,
          Icons.error_rounded,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _bar({required String text, required double? value, required Color color}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: AppTheme.cloudWhite,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsetsDirectional.only(top: 12),
      padding: const EdgeInsetsDirectional.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }
}
