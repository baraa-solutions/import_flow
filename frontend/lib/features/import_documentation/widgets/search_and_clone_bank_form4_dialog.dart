import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/import_documentation_model.dart';
import '../../../core/widgets/buttons/app_button.dart';
import 'idoc_ui.dart';

/// Search and Clone Previous Bank Form 4 Dialog (Screen 16 / UX-CLONE-016)
///
/// Allows users to quickly search previous Bank Form 4 records by code,
/// bank name, import file code, currency, or amount, and select one to clone.
class SearchAndCloneBankForm4Dialog extends StatefulWidget {
  final List<BankingDocumentModel> bankingDocs;
  final ValueChanged<BankingDocumentModel> onSelectDoc;

  const SearchAndCloneBankForm4Dialog({
    super.key,
    required this.bankingDocs,
    required this.onSelectDoc,
  });

  @override
  State<SearchAndCloneBankForm4Dialog> createState() => _SearchAndCloneBankForm4DialogState();
}

class _SearchAndCloneBankForm4DialogState extends State<SearchAndCloneBankForm4Dialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<BankingDocumentModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.bankingDocs;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      if (lower.isEmpty) {
        _filtered = widget.bankingDocs;
      } else {
        _filtered = widget.bankingDocs.where((d) {
          final code = d.bankDocCode.toLowerCase();
          final bank = d.bankName.toLowerCase();
          final file = (d.importFileCode ?? '').toLowerCase();
          final currency = d.currencyCode.toLowerCase();
          final amount = d.amount.toString();
          final notes = (d.notes ?? '').toLowerCase();
          final status = d.status.toLowerCase();
          return code.contains(lower) ||
              bank.contains(lower) ||
              file.contains(lower) ||
              currency.contains(lower) ||
              amount.contains(lower) ||
              notes.contains(lower) ||
              status.contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchAndCloneBankForm4DialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.bankForm4ClonedResetNotice,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondaryOf(context)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Box
              TextField(
                controller: _queryController,
                onChanged: _filter,
                style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: l.searchBankForm4Hint,
                  hintStyle: TextStyle(color: AppTheme.textMutedOf(context)),
                  prefixIcon: Icon(Icons.search, color: AppTheme.textSecondaryOf(context)),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                ),
              ),
              const SizedBox(height: 14),

              // Documents List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: AppTheme.textMutedOf(context)),
                            const SizedBox(height: 10),
                            Text(
                              l.noBankForm4Found,
                              style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = _filtered[index];
                          final formattedAmount = '${doc.amount.toStringAsFixed(2)} ${doc.currencyCode}';
                          final formattedDate = doc.requestDate ?? doc.issueDate.substring(0, doc.issueDate.length >= 10 ? 10 : doc.issueDate.length);

                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAltOf(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderOf(context)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Leading Icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.wcagCobalt.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.account_balance, color: AppTheme.wcagCobalt, size: 20),
                                ),
                                const SizedBox(width: 12),

                                // Main Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            doc.bankDocCode,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.wcagCobalt),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: doc.status == 'Received'
                                                  ? AppTheme.emerald.withValues(alpha: 0.15)
                                                  : AppTheme.orange.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              doc.status == 'Received' ? l.endorsedStatusBadge : l.bankProcessingStatusBadge,
                                              style: TextStyle(
                                                fontSize: DisplayDensityMode.clampFontSize(11.0),
                                                fontWeight: FontWeight.bold,
                                                color: doc.status == 'Received'
                                                    ? (AppTheme.severityForegroundOf(context, AppSeverity.success))
                                                    : (AppTheme.severityForegroundOf(context, AppSeverity.warning)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${doc.bankName}  •  ${doc.importFileCode ?? (doc.importFileId != null ? 'IMP-${doc.importFileId}' : '-')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimaryOf(context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$formattedAmount  •  $formattedDate',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondaryOf(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Select / Clone Action Button
                                IdocUi.fit(AppButton(
                                  key: Key('selectCloneBankForm4Btn_${doc.bankDocId}'),
                                  label: l.searchAndCloneBankForm4Btn,
                                  icon: Icons.copy,
                                  variant: AppButtonVariant.primary,
                                  size: AppButtonSize.small,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onSelectDoc(doc);
                                  },
                                )),
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
      ),
    );
  }
}
