import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ltr_text.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/customs_clearance_model.dart';
import '../customs_ui.dart';
import '../cc_dialog_shell.dart';

class CustomsInspectionInfoHeader extends StatelessWidget {
  final ImportFileModel file;
  final CustomsClearanceModel? clearanceRecord;

  const CustomsInspectionInfoHeader({
    super.key,
    required this.file,
    this.clearanceRecord,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final channel = clearanceRecord?.channelType;
    final channelInfo = channel != null && channel.trim().isNotEmpty
        ? CcUi.channelStyle(l, channel)
        : null;
    final channelLabel = channelInfo?.label ?? '—';
    final channelIcon = channelInfo?.icon ?? Icons.security_rounded;
    final channelColor = channelInfo != null
        ? AppTheme.severityForegroundOf(context, channelInfo.severity)
        : AppTheme.charcoal;

    final String dateValue;
    if (file.form46Date != null && file.form46Date!.trim().isNotEmpty) {
      final trimmed = file.form46Date!.trim();
      dateValue = trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
    } else {
      dateValue = '—';
    }

    return CcFieldRow(
      gap: 12,
      children: [
        _buildInfoBadge(
          context,
          title: l.ccInsBadgeDecl,
          value: file.form46No ?? l.ccInsBadgeDeclFallback,
          icon: Icons.assignment_turned_in_rounded,
          accentColor: AppTheme.cobalt,
        ),
        _buildInfoBadge(
          context,
          title: l.ccInsBadgeChannel,
          value: channelLabel,
          icon: channelIcon,
          accentColor: channelColor,
        ),
        _buildInfoBadge(
          context,
          title: l.ccInsBadgeDate,
          value: dateValue,
          icon: Icons.calendar_today_rounded,
          accentColor: AppTheme.charcoal,
          ltr: true,
        ),
      ],
    );
  }

  Widget _buildInfoBadge(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    bool ltr = false,
  }) {
    final valueStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.bold,
      color: accentColor,
    );
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                ),
                ltr
                    ? LtrText(value, style: valueStyle, overflow: TextOverflow.ellipsis)
                    : Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
