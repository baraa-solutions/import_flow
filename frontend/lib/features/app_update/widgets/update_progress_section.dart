import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/update_format.dart';
import '../models/update_models.dart';

/// Renders one `GET /status` snapshot: progress bar while downloading,
/// indeterminate bar while verifying / backing up, ready / failed notices.
/// Idle and unknown render nothing.
class UpdateProgressSection extends StatelessWidget {
  final UpdateStatus status;

  const UpdateProgressSection({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    switch (status.state) {
      case UpdateState.downloading:
        return _bar(
          text: formatUpdateProgress(l, status.downloadedBytes, status.totalBytes),
          value: status.progress,
          color: AppTheme.cobalt,
        );
      case UpdateState.verifying:
        return _bar(text: l.updateVerifying, value: null, color: AppTheme.cobalt);
      case UpdateState.backingUp:
        return _bar(text: l.updateBackingUp, value: null, color: AppTheme.orange);
      case UpdateState.installing:
        return _bar(text: l.updateInstalling, value: null, color: AppTheme.emerald);
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
      case UpdateState.idle:
      case UpdateState.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _bar({required String text, required double? value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
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
