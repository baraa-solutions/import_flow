import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../import_files/models/import_file_model.dart';
import 'report_basic_info_card.dart';
import 'report_card_container.dart';
import 'report_header_banner_card.dart';

/// Overall shipment milestone progress, stage, and priority status card.
class ReportStatusCard extends StatelessWidget {
  final ImportFileModel file;

  const ReportStatusCard({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final pColor = ReportHeaderBanner.priorityColor(file.priority);

    return ReportCardContainer(
      title: l.compReportSecStatus,
      icon: Icons.timeline_outlined,
      iconColor: AppTheme.emerald,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: pColor),
              const SizedBox(width: 6),
              Text(
                l.compReportPriorityPrefix(file.priority),
                style: TextStyle(fontWeight: FontWeight.bold, color: pColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ReportBasicInfoCard.buildInfoRow(context, l.compReportStatusLabel, file.status),
          ReportBasicInfoCard.buildInfoRow(
            context,
            l.compReportCurrentStageLabel,
            DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr),
          ),
          ReportBasicInfoCard.buildInfoRow(
            context,
            l.compReportCurrentModuleLabel,
            file.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(file.currentModule, isArabic: isAr),
          ),
          ReportBasicInfoCard.buildInfoRow(
            context,
            l.compReportNextActionLabel,
            file.displayNextAction(context.l10n),
          ),
          const SizedBox(height: 10),
          Text(
            l.compReportTotalProgressLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: file.progressPercent / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      file.progressPercent >= 80 ? AppTheme.emerald : AppTheme.cobalt,
                    ),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${file.progressPercent.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
