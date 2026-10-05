import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/ltr_text.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../customs_consultation/models/customs_consultation_model.dart';
import 'su_ui.dart';

/// Customs consultation and inspection results of the selected shipment.
class SuCustomsSection extends StatelessWidget {
  const SuCustomsSection({
    super.key,
    required this.consultations,
    required this.onPrint,
    required this.onSavePdf,
    required this.onView,
    required this.onEdit,
    required this.onRecordDaily,
  });

  final List<CustomsConsultationModel> consultations;
  final void Function(CustomsConsultationModel) onPrint;
  final void Function(CustomsConsultationModel) onSavePdf;
  final void Function(CustomsConsultationModel) onView;
  final void Function(CustomsConsultationModel) onEdit;
  final VoidCallback onRecordDaily;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return CcSectionCard(
      title: l.shipmentUpdateCustomsSecTitle,
      icon: Icons.gavel_rounded,
      trailing: CcStatusChip(
        label: consultations.isNotEmpty
            ? l.shipmentUpdateCustomsStudiesCount(consultations.length)
            : l.shipmentUpdateCustomsNoStudies,
        severity: consultations.isNotEmpty ? AppSeverity.success : AppSeverity.info,
      ),
      margin: EdgeInsets.zero,
      child: consultations.isEmpty
          ? CcStateView.empty(message: l.shipmentUpdateCustomsEmptyPrompt, icon: Icons.info_outline)
          : Column(
              children: [
                for (final c in consultations) _ConsultationCard(c: c, section: this),
              ],
            ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.c, required this.section});

  final CustomsConsultationModel c;
  final SuCustomsSection section;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final readinessPct = c.readinessPercentage;
    final hasBlocking = c.hasBlockingIssues || c.blockingIssuesCount > 0;
    final readinessSev = SuUi.readinessSeverity(readinessPct);
    final readinessColor = AppTheme.severityForegroundOf(context, readinessSev);

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cobaltBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SuCodeBadge(code: c.consultationCode, copiedMessage: l.shipmentUpdateConsultCodeBadgeLabel),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  c.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 16, color: AppTheme.textMutedOf(context)),
                  const SizedBox(width: 4),
                  Text(
                    l.shipmentUpdateBrokerPrefix(c.brokerName),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SuConsultationStatusChip(status: c.overallStatus),
            ],
          ),
          Divider(height: 18, color: AppTheme.borderOf(context)),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SuMetricBadge(
                title: l.shipmentUpdateMetricEstDuties,
                value: '${c.estimatedDutiesEgp.toStringAsFixed(0)} ${l.egpCurrency}',
                severity: AppSeverity.danger,
              ),
              SuMetricBadge(
                title: l.shipmentUpdateMetricApprovedDocs,
                value: l.shipmentUpdateMetricDocsRatio(c.approvedDocumentsCount, c.totalDocumentsCount),
                severity: AppSeverity.success,
              ),
              SuMetricBadge(
                title: l.shipmentUpdateMetricBlockingIssues,
                value: hasBlocking
                    ? l.shipmentUpdateMetricBlockingCount(c.blockingIssuesCount)
                    : l.shipmentUpdateMetricZeroBlocking,
                severity: hasBlocking ? AppSeverity.danger : AppSeverity.success,
              ),
              Container(
                width: 170,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAltOf(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.borderOf(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.shipmentUpdateMetricReadinessRate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                          ),
                        ),
                        LtrText(
                          '${readinessPct.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: readinessColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (readinessPct / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppTheme.borderOf(context),
                        valueColor: AlwaysStoppedAnimation<Color>(readinessColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              CcUi.fit(AppButton(
                label: l.shipmentUpdateBtnPrintPdf,
                icon: Icons.print_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => section.onPrint(c),
              )),
              CcUi.fit(AppButton(
                label: l.shipmentUpdateBtnSavePdf,
                icon: Icons.save_alt_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => section.onSavePdf(c),
              )),
              CcUi.fit(AppButton(
                label: l.shipmentUpdateBtnViewChecklist,
                icon: Icons.visibility_rounded,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: () => section.onView(c),
              )),
              CcUi.fit(AppButton(
                label: l.shipmentUpdateBtnEditDocs,
                icon: Icons.edit_note_rounded,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
                onPressed: () => section.onEdit(c),
              )),
              CcUi.fit(AppButton(
                label: l.shipmentUpdateBtnRecordDailyUpdate,
                icon: Icons.post_add_rounded,
                variant: AppButtonVariant.success,
                size: AppButtonSize.small,
                onPressed: section.onRecordDaily,
              )),
            ],
          ),
        ],
      ),
    );
  }
}
