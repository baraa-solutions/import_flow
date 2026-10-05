import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/import_documentation_model.dart';

/// Search and Clone Previous Certificate of Origin Review Dialog (Screen 19 / UX-CLONE-019)
///
/// Allows users to quickly search previous COO/EUR.1 reviews by review code,
/// certificate number, exporter, importer, certificate type, country of origin, or status,
/// and select one to clone with reset certificate numbers and new review state.
class SearchAndCloneCooDialog extends StatefulWidget {
  final List<CertificateOfOriginReviewModel> reviews;
  final ValueChanged<CertificateOfOriginReviewModel> onSelectReview;

  const SearchAndCloneCooDialog({
    super.key,
    required this.reviews,
    required this.onSelectReview,
  });

  @override
  State<SearchAndCloneCooDialog> createState() => _SearchAndCloneCooDialogState();
}

class _SearchAndCloneCooDialogState extends State<SearchAndCloneCooDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<CertificateOfOriginReviewModel> _filtered;

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
          final certNum = r.certificateNumber.toLowerCase();
          final code = r.cooReviewCode.toLowerCase();
          final type = r.certificateType.toLowerCase();
          final status = r.status.toLowerCase();
          final idStr = r.cooReviewId.toString();

          final expName = (r.draftInputData?['exporter_name'] ??
                  r.draftInputData?['box_1_exporter'] ??
                  r.systemSnapshotData?['supplier_name'] ??
                  '')
              .toString()
              .toLowerCase();

          final impName = (r.draftInputData?['importer_name'] ??
                  r.draftInputData?['box_2_consignee'] ??
                  r.systemSnapshotData?['company_name'] ??
                  '')
              .toString()
              .toLowerCase();

          final originCountry = (r.draftInputData?['country_of_origin'] ??
                  r.draftInputData?['box_3_country_of_origin'] ??
                  '')
              .toString()
              .toLowerCase();

          final invoiceNo = (r.draftInputData?['invoice_number'] ??
                  r.draftInputData?['box_10_invoice_number_and_date'] ??
                  '')
              .toString()
              .toLowerCase();

          final notes = (r.notes ?? '').toLowerCase();

          return certNum.contains(lower) ||
              code.contains(lower) ||
              type.contains(lower) ||
              status.contains(lower) ||
              idStr.contains(lower) ||
              expName.contains(lower) ||
              impName.contains(lower) ||
              originCountry.contains(lower) ||
              invoiceNo.contains(lower) ||
              notes.contains(lower);
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
                          l.searchAndCloneCooDialogTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.cooClonedResetNotice,
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
                key: const Key('searchCooDialogQueryInput'),
                controller: _queryController,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimaryOf(context)),
                decoration: InputDecoration(
                  hintText: l.searchCooHint,
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
                            Icon(
                              Icons.verified_outlined,
                              size: 48,
                              color: AppTheme.textMutedOf(context),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l.noCooReviewsFound,
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
                          final certNumber = r.certificateNumber;
                          final expName = r.draftInputData?['exporter_name'] ??
                              r.draftInputData?['box_1_exporter'] ??
                              r.systemSnapshotData?['supplier_name'] ??
                              '—';
                          final impName = r.draftInputData?['importer_name'] ??
                              r.draftInputData?['box_2_consignee'] ??
                              r.systemSnapshotData?['company_name'] ??
                              '—';
                          final originCountry = r.draftInputData?['country_of_origin'] ??
                              r.draftInputData?['box_3_country_of_origin'] ??
                              '—';
                          final isVerified = r.status == 'Verified' || r.status == 'Approved';

                          return Material(
                            color: AppTheme.surfaceAltOf(context),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              key: Key('selectCooItem_${r.cooReviewId}'),
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
                                      child: const Icon(
                                        Icons.verified_outlined,
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
                                                    certNumber,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: AppTheme.wcagCobalt,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.wcagCobalt.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      r.certificateType,
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
                                                      r.cooReviewCode,
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
                                                  color: isVerified
                                                      ? (AppTheme.severityBackgroundOf(context, AppSeverity.success))
                                                      : (AppTheme.severityBackgroundOf(context, AppSeverity.warning)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isVerified
                                                        ? (AppTheme.emeraldBorder)
                                                        : (AppTheme.orange),
                                                  ),
                                                ),
                                                child: Text(
                                                  r.status,
                                                  style: TextStyle(
                                                    fontSize: 11.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: isVerified
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
                                              if (expName != '—')
                                                _buildMetaChip(Icons.business_outlined, expName, isDark),
                                              if (impName != '—')
                                                _buildMetaChip(Icons.domain, impName, isDark),
                                              if (originCountry != '—')
                                                _buildMetaChip(Icons.public, originCountry, isDark),
                                              _buildMetaChip(
                                                Icons.calendar_today_outlined,
                                                r.createdAt.length >= 10 ? r.createdAt.substring(0, 10) : r.createdAt,
                                                isDark,
                                              ),
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
