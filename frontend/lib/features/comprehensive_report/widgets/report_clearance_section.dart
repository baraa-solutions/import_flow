import 'package:frontend/features/customs_clearance/widgets/customs_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../customs_clearance/models/customs_clearance_model.dart';
import 'report_card_container.dart';
import 'report_copy_badge.dart';

/// Customs clearance real-time data section for Comprehensive Report.
class ReportClearanceSection extends StatelessWidget {
  final AsyncValue<List<CustomsClearanceModel>> state;

  const ReportClearanceSection({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ReportCardContainer(
      title: l.compReportSecClearance,
      icon: Icons.receipt_long_outlined,
      iconColor: AppTheme.cobalt,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('${l.errorPrefix} $err', style: const TextStyle(color: AppTheme.crimson)),
        data: (list) {
          if (list.isEmpty) return Text(l.compReportNoClearanceData, style: const TextStyle(color: Colors.grey));
          final clr = list.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (clr.declaration46No != null)
                    ReportCopyBadge(
                      textToCopy: clr.declaration46No!,
                      label: l.compReportDeclarationChip(clr.declaration46No!),
                      color: Colors.blue.shade50,
                      borderColor: Colors.blue.shade200,
                      textColor: AppTheme.cobalt,
                    ),
                  Chip(
                    label: Text(clr.channelType, style: const TextStyle(fontSize: 12)),
                    backgroundColor: clr.channelType.toLowerCase().contains('green')
                        ? Colors.green.shade50
                        : (clr.channelType.toLowerCase().contains('red') ? Colors.red.shade50 : Colors.orange.shade50),
                  ),
                  Chip(label: Text(clr.customsOfficeName, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.grey.shade100),
                ],
              ),
              const SizedBox(height: 8),
              if (clr.releasePermitNo != null)
                ReportCopyBadge(
                  textToCopy: clr.releasePermitNo!,
                  label: l.compReportReleasePermitChip(clr.releasePermitNo!),
                  color: AppTheme.emerald.withValues(alpha: 0.1),
                  borderColor: AppTheme.emerald.withValues(alpha: 0.3),
                  textColor: AppTheme.emerald,
                ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniStat(l.compReportDutyImport, CcFormat.fixed(clr.importDutyAmount)),
                  _miniStat(l.compReportDutyVat, CcFormat.fixed(clr.vatAmount)),
                  _miniStat(l.compReportDutySchedule, CcFormat.fixed(clr.scheduleTaxAmount)),
                  _miniStat(l.compReportDutyInspection, CcFormat.fixed(clr.labServiceFees)),
                  _miniStat(l.compReportDutyTotal, CcFormat.fixed(clr.totalDutyPayable)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (clr.paymentDate != null) Text(l.compReportPaymentDate(clr.paymentDate!), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 16),
                  if (clr.releaseDate != null) Text(l.compReportReleaseDate(clr.releaseDate!), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              )
            ],
          );
        },
      ),
    );
  }

  static Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.charcoal)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}
