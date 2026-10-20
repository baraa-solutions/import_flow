import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/import_documentation_model.dart';

/// Search and Clone Previous Draft B/L Review Dialog (Screen 18 / UX-CLONE-018)
///
/// Allows users to quickly search previous Draft B/L reviews by review code,
/// B/L number, shipping line, vessel name, voyage, or stage, and select one to clone.
class SearchAndCloneDraftBlDialog extends StatefulWidget {
  final List<DraftBLReviewModel> reviews;
  final ValueChanged<DraftBLReviewModel> onSelectReview;

  const SearchAndCloneDraftBlDialog({
    super.key,
    required this.reviews,
    required this.onSelectReview,
  });

  @override
  State<SearchAndCloneDraftBlDialog> createState() => _SearchAndCloneDraftBlDialogState();
}

class _SearchAndCloneDraftBlDialogState extends State<SearchAndCloneDraftBlDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<DraftBLReviewModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.reviews;
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
        _filtered = widget.reviews;
      } else {
        _filtered = widget.reviews.where((r) {
          final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
                  r.draftExtractedData?['bl_number'] ??
                  r.systemDataSnapshot?['draft_bl_number'] ??
                  r.draftBlNumber)
              .toString()
              .toLowerCase();
          final code = r.blReviewCode.toLowerCase();
          final line = (r.shippingLine ?? '').toLowerCase();
          final vessel = (r.vesselName ?? '').toLowerCase();
          final voyage = (r.voyageNumber ?? '').toLowerCase();
          final stage = r.stage.toLowerCase();
          final status = r.status.toLowerCase();
          final idStr = r.blReviewId.toString();

          return blNumber.contains(lower) ||
              code.contains(lower) ||
              line.contains(lower) ||
              vessel.contains(lower) ||
              voyage.contains(lower) ||
              stage.contains(lower) ||
              status.contains(lower) ||
              idStr.contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: AppTheme.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 620),
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
                          l.searchAndCloneDraftBlDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.draftBlClonedResetNotice,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryOf(context),
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

              // Search Box
              TextField(
                key: const Key('searchDraftBlDialogQueryInput'),
                controller: _queryController,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: l.searchDraftBlHint,
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

              // List of Reviews
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMutedOf(context)),
                            const SizedBox(height: 10),
                            Text(
                              l.noDraftBlFound,
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
                          final r = _filtered[i];
                          final blNumber = (r.draftExtractedData?['draft_bl_number'] ??
                                  r.draftExtractedData?['bl_number'] ??
                                  r.systemDataSnapshot?['draft_bl_number'] ??
                                  r.draftBlNumber)
                              .toString();
                          final vesselVoyage = '${r.vesselName ?? "-"} / ${r.voyageNumber ?? "-"}';
                          final isApproved = r.status == 'Approved' || r.status == 'Final Approved';

                          return Material(
                            color: AppTheme.surfaceAltOf(context),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              key: Key('selectDraftBlItem_${r.blReviewId}'),
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onSelectReview(r);
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
                                      child: const Icon(Icons.assignment_outlined, color: AppTheme.wcagCobalt, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                blNumber,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: AppTheme.wcagCobalt,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  r.blReviewCode,
                                                  style: TextStyle(
                                                    fontSize: 11.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.textSecondaryOf(context),
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isApproved
                                                      ? (AppTheme.severityBackgroundOf(context, AppSeverity.success))
                                                      : (AppTheme.severityBackgroundOf(context, AppSeverity.warning)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isApproved
                                                        ? (AppTheme.emeraldBorder)
                                                        : (AppTheme.orange),
                                                  ),
                                                ),
                                                child: Text(
                                                  r.status,
                                                  style: TextStyle(
                                                    fontSize: 11.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: isApproved
                                                        ? (AppTheme.severityForegroundOf(context, AppSeverity.success))
                                                        : (AppTheme.severityForegroundOf(context, AppSeverity.warning)),
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
                                              if (r.shippingLine != null && r.shippingLine!.isNotEmpty)
                                                _buildMetaChip(Icons.directions_boat, r.shippingLine!, isDark),
                                              _buildMetaChip(Icons.sailing, vesselVoyage, isDark),
                                              _buildMetaChip(Icons.timeline, r.stage, isDark),
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

  Widget _buildMetaChip(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondaryOf(context)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}
