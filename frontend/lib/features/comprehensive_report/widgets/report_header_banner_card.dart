import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_copy_badge.dart';

/// Top header banner widget for the shipment comprehensive dossier.
class ReportHeaderBanner extends StatelessWidget {
  final ImportFileModel file;
  final ComprehensiveShipmentDossierModel? dossier;
  final VoidCallback? onOpenOperationalDetails;

  const ReportHeaderBanner({
    super.key,
    required this.file,
    this.dossier,
    this.onOpenOperationalDetails,
  });

  static int currentPhaseIndex(ImportFileModel file) {
    if (file.currentPhaseId != null && file.currentPhaseId! >= 1 && file.currentPhaseId! <= 10) {
      return file.currentPhaseId! - 1;
    }
    final stageMatch = RegExp(r'Phase\s*(\d+)').firstMatch(file.currentStage);
    if (stageMatch != null) {
      final n = int.tryParse(stageMatch.group(1) ?? '');
      if (n != null && n >= 1 && n <= 10) return n - 1;
    }
    final modMatch = RegExp(r'Phase\s*(\d+)').firstMatch(file.currentModule);
    if (modMatch != null) {
      final n = int.tryParse(modMatch.group(1) ?? '');
      if (n != null && n >= 1 && n <= 10) return n - 1;
    }
    return 0;
  }

  static Color priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppTheme.crimson;
      case 'high':
        return AppTheme.orange;
      case 'medium':
        return AppTheme.cobalt;
      case 'low':
        return AppTheme.emerald;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isClosed = file.status == 'Closed';
    final phaseIdx = currentPhaseIndex(file);
    final completedCount = isClosed ? 10 : phaseIdx;
    final remainingCount = isClosed ? 0 : (10 - phaseIdx - 1);
    final phaseCode = file.currentModule.isNotEmpty && RegExp(r'^P\d+').hasMatch(file.currentModule)
        ? file.currentModule
        : 'P${phaseIdx + 1}';

    final effectiveCompanyName = file.companyName.isNotEmpty
        ? file.companyName
        : (dossier?.companyName.isNotEmpty == true
            ? dossier!.companyName
            : 'SCAS For Construction And Finishing');
    final effectiveSupplierName = file.supplierName.isNotEmpty
        ? file.supplierName
        : (dossier?.supplierName.isNotEmpty == true ? dossier!.supplierName : '—');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClosed
              ? [Colors.grey.shade700, Colors.grey.shade500]
              : [AppTheme.charcoal, const Color(0xFF34495E)],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isClosed ? Icons.archive : Icons.folder_open,
              color: isClosed ? Colors.grey.shade300 : AppTheme.cobalt,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            file.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          ReportCopyBadge(
                            textToCopy: file.displayName,
                            color: Colors.white.withValues(alpha: 0.15),
                            borderColor: Colors.white.withValues(alpha: 0.3),
                            textColor: Colors.white,
                          ),
                          _buildStatusPill(context, file.status),
                          _buildPriorityPill(context, file.priority),
                        ],
                      ),
                    ),
                    if (onOpenOperationalDetails != null) ...[
                      const SizedBox(width: 12),
                      Tooltip(
                        message: 'العودة السريعة لمتابعة الإجراءات في شاشة التشغيل والمحطات (Screen 1)',
                        child: ElevatedButton.icon(
                          key: const Key('openOperationalDetailsHeaderBtn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cobalt,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                          label: Text(
                            'فتح شاشة التشغيل والمحطات $phaseCode ↵',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: onOpenOperationalDetails,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_outlined, size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          'الشركة المستوردة: $effectiveCompanyName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          'المورد الأجنبي: $effectiveSupplierName',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DisplayNameResolver.resolveStepName(
                    file.displayStepKey,
                    isArabic: Localizations.localeOf(context).languageCode == 'ar',
                  ),
                  style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (file.isChildPartial && file.parentFileCode != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_split_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          'دفعة شحن جزئية تابعة للملف الأساسي: ${file.parentFileCode}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                if (file.isParentPartial)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.lightBlueAccent, width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_split_rounded, size: 14, color: Colors.lightBlueAccent),
                        SizedBox(width: 6),
                        Text(
                          'ملف شحنة مجزأة رئيسية (تم تفريغ دفعات جزئية منه)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),

                // Progress Bar
                Row(
                  children: [
                    Text(
                      l.compReportPercentCompleted(file.progressPercent.toStringAsFixed(0)),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: file.progressPercent / 100,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isClosed ? Colors.grey.shade400 : AppTheme.emerald,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Counters
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _counterBadge('$completedCount', l.compReportCompletedPhases, AppTheme.emerald),
              const SizedBox(height: 8),
              _counterBadge('$remainingCount', l.compReportRemainingPhases, AppTheme.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterBadge(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, String status) {
    final l = context.l10n;
    Color bg;
    String label;
    switch (status.toLowerCase()) {
      case 'open':
      case 'draft':
        bg = AppTheme.cobalt;
        label = l.filterStatusDraft;
        break;
      case 'in progress':
        bg = AppTheme.emerald;
        label = l.statusInProgress;
        break;
      case 'closed':
        bg = Colors.grey;
        label = l.statusClosed;
        break;
      default:
        bg = AppTheme.orange;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityPill(BuildContext context, String priority) {
    final l = context.l10n;
    String label;
    switch (priority.toLowerCase()) {
      case 'critical':
        label = l.priorityCritical;
        break;
      case 'high':
        label = l.priorityHigh;
        break;
      case 'medium':
        label = l.priorityMedium;
        break;
      case 'low':
        label = l.priorityLow;
        break;
      default:
        label = priority;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: priorityColor(priority).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priorityColor(priority).withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: priorityColor(priority), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
