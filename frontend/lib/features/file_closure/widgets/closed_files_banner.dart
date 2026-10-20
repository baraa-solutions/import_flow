import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';

/// Shipments that were stopped / closed early, each with a "reopen" action.
class ClosedFilesBanner extends StatelessWidget {
  const ClosedFilesBanner({super.key, required this.files, required this.onReopen});

  final List<ImportFileModel> files;
  final void Function(ImportFileModel file) onReopen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final warn = AppTheme.severityForegroundOf(context, AppSeverity.warning);

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: warn.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: warn, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.fileClosureClosedFilesBannerTitle(files.length),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimaryOf(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: files.map((cf) {
              final shipName = DisplayNameResolver.resolveShipmentName(cf, isArabic: isAr);
              final phaseName = cf.closedAtPhase != null
                  ? DisplayNameResolver.resolvePhaseName(cf.closedAtPhase!, isArabic: isAr)
                  : l.fileClosureClosedBadge;

              return Container(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CopyableText(
                          shipName,
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(context), fontSize: 13),
                        ),
                        OpsStatusChip(label: phaseName, severity: AppSeverity.danger, dense: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    OpsTagChip(label: cf.importFileCode, icon: Icons.folder_open_outlined),
                    if (cf.closureReason != null && cf.closureReason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        l.fileClosureStopReason(cf.closureReason!),
                        style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryOf(context)),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OpsFit(
                      child: AppButton(
                        label: l.fileClosureReopenBtn,
                        variant: AppButtonVariant.success,
                        icon: Icons.restart_alt,
                        size: AppButtonSize.small,
                        onPressed: () => onReopen(cf),
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
  }
}
