import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/api_error_text.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/docs_customs_approval_model.dart';
import '../idoc_ui.dart';
import 'doc_approval_helpers.dart';

class DocApprovalActionsBar extends StatelessWidget {
  final AsyncValue<List<DiscrepancyRectificationTicketModel>> ticketsState;
  final VoidCallback onCopyTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onRaiseTicket;
  final ValueChanged<DiscrepancyRectificationTicketModel> onCloneTicket;
  final ValueChanged<DiscrepancyRectificationTicketModel> onResolveTicket;

  const DocApprovalActionsBar({
    super.key,
    required this.ticketsState,
    required this.onCopyTsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onRaiseTicket,
    required this.onCloneTicket,
    required this.onResolveTicket,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final tickets = ticketsState.valueOrNull ?? const [];
    final canExport = tickets.isNotEmpty;

    return Card(
      elevation: 2,
      color: isDark ? AppTheme.darkCardBackground : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, color: AppTheme.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.customsApprovalTicketsHeader,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const Key('copyTicketsBtn'),
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            onPressed: canExport ? onCopyTsv : null,
                            tooltip: context.l10n.idocACopyTicketsAsTSV,
                          ),
                          IconButton(
                            key: const Key('exportTicketsExcelBtn'),
                            icon: const Icon(Icons.table_chart_outlined, size: 18),
                            onPressed: canExport ? onExportExcel : null,
                            tooltip: context.l10n.exportExcel,
                          ),
                          IconButton(
                            key: const Key('exportTicketsPdfBtn'),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            onPressed: canExport ? onExportPdf : null,
                            tooltip: context.l10n.exportPdf,
                          ),
                          IdocUi.fit(AppButton(
                            label: context.l10n.customsApprovalNewTicketButton,
                            icon: Icons.add,
                            variant: AppButtonVariant.ghost,
                            onPressed: onRaiseTicket,
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ticketsState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      context.l10n.customsApprovalError(ApiErrorText.of(context.l10n, e)),
                      style: const TextStyle(color: AppTheme.crimson),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          context.l10n.customsApprovalNoTickets,
                          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final t = items[index];
                        return DocApprovalTicketCard(
                          ticket: t,
                          onCloneTicket: () => onCloneTicket(t),
                          onResolveTicket: () => onResolveTicket(t),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DocApprovalTicketCard extends StatelessWidget {
  final DiscrepancyRectificationTicketModel ticket;
  final VoidCallback onCloneTicket;
  final VoidCallback onResolveTicket;

  const DocApprovalTicketCard({
    super.key,
    required this.ticket,
    required this.onCloneTicket,
    required this.onResolveTicket,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l = context.l10n;
    final isResolved = ticket.status == 'Resolved';
    final localizedSeverity = DocApprovalHelpers.getLocalizedSeverity(ticket.severity, l);
    final localizedTicketStatus = DocApprovalHelpers.getLocalizedTicketStatus(ticket.status, l);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isResolved
              ? AppTheme.emerald.withValues(alpha: 0.06)
              : (isDark ? AppTheme.darkElevatedSurface : AppTheme.orange.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isResolved
                ? AppTheme.emerald.withValues(alpha: 0.4)
                : (isDark ? AppTheme.darkBorder : AppTheme.orange.withValues(alpha: 0.4)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                CopyableText(
                  ticket.ticketCode,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryOf(context)),
                  isSelectable: false,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: ticket.severity == 'Critical' ? AppTheme.crimson : AppTheme.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: CopyableText(
                    localizedSeverity,
                    style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold),
                    isSelectable: false,
                  ),
                ),
                CopyableText(
                  localizedTicketStatus,
                  style: TextStyle(
                    color: isResolved ? AppTheme.emerald : AppTheme.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  isSelectable: false,
                ),
                IconButton(
                  key: Key('cloneTicketRowBtn_${ticket.ticketId}'),
                  icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.wcagCobalt),
                  tooltip: l.cloneTicketRecordTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onCloneTicket,
                ),
              ],
            ),
            const SizedBox(height: 4),
            CopyableText(
              ticket.description,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryOf(context)),
              isSelectable: false,
            ),
            if (ticket.expectedValue != null || ticket.foundValue != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CopyableText(
                  l.customsApprovalTicketExpectedVsFound(ticket.expectedValue ?? '-', ticket.foundValue ?? '-'),
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context)),
                  isSelectable: false,
                ),
              ),
            if (!isResolved)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IdocUi.fit(AppButton(
                  label: l.customsApprovalResolveTicketButton,
                  icon: Icons.check_circle_outline,
                  variant: AppButtonVariant.ghost,
                  onPressed: onResolveTicket,
                )),
              ),
          ],
        ),
      ),
    );
  }
}
