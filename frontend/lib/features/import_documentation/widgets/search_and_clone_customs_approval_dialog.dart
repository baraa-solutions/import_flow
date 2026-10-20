import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/docs_customs_approval_model.dart';

class SearchAndCloneCustomsApprovalDialog extends StatefulWidget {
  final List<CustomsDocumentApprovalModel> items;
  final ValueChanged<CustomsDocumentApprovalModel> onSelectItem;

  const SearchAndCloneCustomsApprovalDialog({
    super.key,
    required this.items,
    required this.onSelectItem,
  });

  @override
  State<SearchAndCloneCustomsApprovalDialog> createState() => _SearchAndCloneCustomsApprovalDialogState();
}

class _SearchAndCloneCustomsApprovalDialogState extends State<SearchAndCloneCustomsApprovalDialog> {
  late List<CustomsDocumentApprovalModel> _filtered;
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
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
        _filtered = List.from(widget.items);
      } else {
        _filtered = widget.items.where((item) {
          final codeMatch = item.approvalCode.toLowerCase().contains(q);
          final typeMatch = item.documentType.toLowerCase().contains(q);
          final refMatch = (item.documentReferenceNo ?? '').toLowerCase().contains(q);
          final statusMatch = item.overallStatus.toLowerCase().contains(q);
          final fileCodeMatch = (item.importFileCode ?? '').toLowerCase().contains(q);
          final commStatusMatch = item.commercialStatus.toLowerCase().contains(q);
          final customsStatusMatch = item.customsStatus.toLowerCase().contains(q);
          return codeMatch ||
              typeMatch ||
              refMatch ||
              statusMatch ||
              fileCodeMatch ||
              commStatusMatch ||
              customsStatusMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = context.l10n;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
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
                            l.searchAndCloneCustomsApprovalDialogTitle,
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
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Input Field
              TextField(
                key: const Key('searchCustomsApprovalQueryInput'),
                controller: _queryController,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: l.searchCustomsApprovalHint,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMutedOf(context),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.textSecondaryOf(context),
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: _filter,
              ),
              const SizedBox(height: 12),

              // Results List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 48,
                              color: AppTheme.textMutedOf(context),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l.noCustomsApprovalsFound,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final item = _filtered[i];
                          final isApproved = item.overallStatus == 'Approved for Clearance' || item.overallStatus == 'Approved';
                          final isRectReq = item.overallStatus == 'Rectification Required' || item.overallStatus == 'Rejected';

                          Color statusColor = AppTheme.orange;
                          if (isApproved) statusColor = AppTheme.wcagEmerald;
                          if (isRectReq) statusColor = AppTheme.crimson;

                          return Material(
                            color: AppTheme.surfaceAltOf(context),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              key: Key('selectApprovalItem_${item.approvalId}'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onSelectItem(item);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.borderOf(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.wcagCobalt.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.description_outlined,
                                        color: AppTheme.wcagCobalt,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            alignment: WrapAlignment.spaceBetween,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    item.documentType,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: AppTheme.wcagCobalt,
                                                    ),
                                                  ),
                                                  if (item.documentReferenceNo != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        item.documentReferenceNo!,
                                                        style: TextStyle(
                                                          fontSize: 11.0,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppTheme.textSecondaryOf(context),
                                                        ),
                                                      ),
                                                    ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.textMutedOf(context).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      item.approvalCode,
                                                      style: TextStyle(
                                                        fontSize: 11.0,
                                                        color: AppTheme.textSecondaryOf(context),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  item.overallStatus,
                                                  style: TextStyle(
                                                    fontSize: 11.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 4,
                                            children: [
                                              if (item.importFileCode != null)
                                                _buildMetaChip(Icons.folder_outlined, item.importFileCode!, isDark),
                                              _buildMetaChip(
                                                Icons.person_outline,
                                                'Commercial: ${item.commercialStatus}',
                                                isDark,
                                                color: item.commercialStatus == 'Approved' ? AppTheme.wcagEmerald : null,
                                              ),
                                              _buildMetaChip(
                                                Icons.gavel_outlined,
                                                'Customs: ${item.customsStatus}',
                                                isDark,
                                                color: item.customsStatus == 'Approved' ? AppTheme.wcagEmerald : null,
                                              ),
                                              if (item.documentDate != null)
                                                _buildMetaChip(Icons.calendar_today_outlined, item.documentDate!, isDark),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.wcagCobalt),
                                  ],
                                ),
                              ),
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

  Widget _buildMetaChip(IconData icon, String text, bool isDark, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: color ?? (AppTheme.textSecondaryOf(context))),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
            color: color ?? (AppTheme.textSecondaryOf(context)),
          ),
        ),
      ],
    );
  }
}
