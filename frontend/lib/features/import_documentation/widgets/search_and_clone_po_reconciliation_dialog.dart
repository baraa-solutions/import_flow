import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/po_reconciliation_session_model.dart';
import '../../../core/widgets/buttons/app_button.dart';
import 'idoc_ui.dart';

class SearchAndClonePoReconciliationDialog extends StatefulWidget {
  final List<POReconciliationSessionModel> sessions;
  final ValueChanged<POReconciliationSessionModel> onSelectSession;

  const SearchAndClonePoReconciliationDialog({
    super.key,
    required this.sessions,
    required this.onSelectSession,
  });

  @override
  State<SearchAndClonePoReconciliationDialog> createState() => _SearchAndClonePoReconciliationDialogState();
}

class _SearchAndClonePoReconciliationDialogState extends State<SearchAndClonePoReconciliationDialog> {
  late List<POReconciliationSessionModel> _filtered;
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.sessions);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(widget.sessions);
      } else {
        _filtered = widget.sessions.where((s) {
          final codeMatch = s.sessionCode.toLowerCase().contains(q);
          final fileMatch = (s.importFileCode ?? '').toLowerCase().contains(q);
          final impMatch = (s.importerName ?? '').toLowerCase().contains(q);
          final invMatch = (s.finalInvoiceNumber ?? '').toLowerCase().contains(q);
          final plMatch = (s.finalPackingListNumber ?? '').toLowerCase().contains(q);
          final statusMatch = s.overallStatus.toLowerCase().contains(q);
          final shipperMatch = (s.shipperName ?? '').toLowerCase().contains(q);
          final acidMatch = (s.acidNumber ?? '').toLowerCase().contains(q);
          return codeMatch ||
              fileMatch ||
              impMatch ||
              invMatch ||
              plMatch ||
              statusMatch ||
              shipperMatch ||
              acidMatch;
        }).toList();
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'FULLY_MATCHED':
        return AppTheme.emerald;
      case 'ACCEPTED_WITH_WARNINGS':
        return AppTheme.orange;
      case 'CRITICAL_DISCREPANCY':
        return AppTheme.crimson;
      default:
        return AppTheme.cobalt;
    }
  }

  String _getStatusLabel(String status, AppLocalizations l) {
    switch (status) {
      case 'FULLY_MATCHED':
        return l.poRecMatchStatusMatched;
      case 'ACCEPTED_WITH_WARNINGS':
        return l.poRecMatchStatusWarning;
      case 'CRITICAL_DISCREPANCY':
        return l.poRecMatchStatusCritical;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.copy_all, color: AppTheme.wcagCobalt, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            l.searchAndClonePoReconDialogTitle,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Field
              TextField(
                key: const Key('searchPoReconField'),
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: l.searchPoReconHint,
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.darkTextSecondary : AppTheme.wcagCobalt),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            _filter('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceAltOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.wcagCobalt, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                onChanged: _filter,
              ),
              const SizedBox(height: 14),

              // Sessions List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l.noPoReconFound,
                          style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: const Key('poReconSessionsListView'),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final session = _filtered[index];
                          final statusColor = _getStatusColor(session.overallStatus);
                          final statusLabel = _getStatusLabel(session.overallStatus, l);
                          final dateStr = (session.createdAt != null && session.createdAt!.length >= 10)
                              ? session.createdAt!.substring(0, 10)
                              : '';

                          return Container(
                            key: Key('poReconSessionCard_${session.sessionId ?? index}'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceOf(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.borderOf(context),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Code + Status Badge + Date + Clone Button
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            session.sessionCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                              color: AppTheme.wcagCobalt,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (dateStr.isNotEmpty) ...[
                                          Icon(Icons.calendar_today, size: 13, color: AppTheme.textSecondaryOf(context)),
                                          const SizedBox(width: 4),
                                          Text(
                                            dateStr,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: AppTheme.textSecondaryOf(context),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                        IdocUi.fit(AppButton(
                                          key: Key('cloneSessionCardBtn_${session.sessionId ?? index}'),
                                          label: l.poRecHistoryLoadInEditorButton,
                                          icon: Icons.copy,
                                          variant: AppButtonVariant.primary,
                                          size: AppButtonSize.small,
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            widget.onSelectSession(session);
                                          },
                                        )),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Secondary Info: Import File & Importer & Invoices
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    if (session.importFileCode != null)
                                      _buildInfoChip(
                                        Icons.folder_outlined,
                                        session.importFileCode!,
                                        isDark,
                                      ),
                                    if (session.importerName != null)
                                      _buildInfoChip(
                                        Icons.business_outlined,
                                        session.importerName!,
                                        isDark,
                                      ),
                                    if (session.finalInvoiceNumber != null)
                                      _buildInfoChip(
                                        Icons.receipt_long_outlined,
                                        '${l.poRecInvoicePrefix}: ${session.finalInvoiceNumber}',
                                        isDark,
                                      ),
                                    if (session.finalPackingListNumber != null)
                                      _buildInfoChip(
                                        Icons.inventory_2_outlined,
                                        '${l.poRecPackingPrefix}: ${session.finalPackingListNumber}',
                                        isDark,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // KPI Totals Summary Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceAltOf(context),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Wrap(
                                    spacing: 14,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '${session.totalInvoiceAmount.toStringAsFixed(2)} ${session.currency}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          color: AppTheme.wcagCobalt,
                                        ),
                                      ),
                                      Text(
                                        '${session.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                                        ),
                                      ),
                                      Text(
                                        '${session.totalGrossWeightKg.toStringAsFixed(1)} ${l.poRecKgUnit}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                                        ),
                                      ),
                                      Text(
                                        '${session.totalCbm.toStringAsFixed(2)} ${l.poRecCbmUnit}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}
