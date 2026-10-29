import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guide_entry_model.dart';
import '../providers/experience_guide_provider.dart';
import 'add_guide_entry_dialog.dart';
import 'autonomous_evidence_trail_dialog.dart';
import '../../../core/localization/app_localizations.dart';

class ExperienceGuideAlertBanner extends ConsumerStatefulWidget {
  final GuideMatchResultModel matchResult;
  final String? supplier;
  final String? hsCode;
  final String? productCategory;
  final String? portOfDischarge;
  final String? portOfLoading;
  final String? shippingLine;
  final String? countryOfOrigin;
  final String? incoterm;
  final String? paymentMethod;
  final String? certificateType;
  final String? customsBroker;
  final String? seasonTiming;
  final String? importFileReference;
  final ValueChanged<bool>? onCriticalAcknowledged;

  const ExperienceGuideAlertBanner({
    super.key,
    required this.matchResult,
    this.supplier,
    this.hsCode,
    this.productCategory,
    this.portOfDischarge,
    this.portOfLoading,
    this.shippingLine,
    this.countryOfOrigin,
    this.incoterm,
    this.paymentMethod,
    this.certificateType,
    this.customsBroker,
    this.seasonTiming,
    this.importFileReference,
    this.onCriticalAcknowledged,
  });

  @override
  ConsumerState<ExperienceGuideAlertBanner> createState() => _ExperienceGuideAlertBannerState();
}

class _ExperienceGuideAlertBannerState extends ConsumerState<ExperienceGuideAlertBanner> {
  bool _isExpanded = false;
  final Set<int> _acknowledgedCriticalIds = {};
  final Set<int> _upvotedIds = {};

  void _openAddEntryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddGuideEntryDialog(
        initialSupplier: widget.supplier,
        initialHsCode: widget.hsCode,
        initialCategory: widget.productCategory,
        initialDestinationPort: widget.portOfDischarge,
        initialPortOfLoading: widget.portOfLoading,
        initialShippingLine: widget.shippingLine,
        initialCountryOfOrigin: widget.countryOfOrigin,
        initialIncoterm: widget.incoterm,
        initialPaymentMethod: widget.paymentMethod,
        initialCertificateType: widget.certificateType,
        initialCustomsBroker: widget.customsBroker,
        initialSeasonTiming: widget.seasonTiming,
        initialImportFileReference: widget.importFileReference,
      ),
    );
  }

  void _acknowledgeCritical(int entryId) {
    setState(() {
      _acknowledgedCriticalIds.add(entryId);
    });
    final criticalEntries = widget.matchResult.matchedEntries.where((e) => e.isCritical).toList();
    final allDone = criticalEntries.every((e) => _acknowledgedCriticalIds.contains(e.entryId));
    if (allDone && widget.onCriticalAcknowledged != null) {
      widget.onCriticalAcknowledged!(true);
    }
  }

  Future<void> _handleUpvote(int entryId) async {
    if (_upvotedIds.contains(entryId)) return;
    final success = await ref.read(experienceGuideProvider.notifier).upvoteEntry(entryId);
    if (success && mounted) {
      setState(() {
        _upvotedIds.add(entryId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, 'شكراً لمشاركتك! تم تسجيل تصويتك في بنك المعرفة.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.matchResult.matchedEntries;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final criticalEntries = entries.where((e) => e.isCritical).toList();
    final warningEntries = entries.where((e) => e.isWarning).toList();
    final infoEntries = entries.where((e) => e.isInfo).toList();
    final positiveEntries = entries.where((e) => e.isPositive).toList();

    final unacknowledgedCritical =
        criticalEntries.where((e) => !_acknowledgedCriticalIds.contains(e.entryId)).toList();
    final hasUnacknowledgedCritical = unacknowledgedCritical.isNotEmpty;

    // Determine banner color based on highest severity
    Color bannerBorderColor;
    Color bannerBgColor;
    IconData bannerIcon;
    String bannerTitle;

    if (hasUnacknowledgedCritical) {
      bannerBorderColor = AppTheme.flatCrimson;
      bannerBgColor = const Color(0xFFFDF2F2);
      bannerIcon = Icons.dangerous_rounded;
      bannerTitle = 'إنذار تشغيلي حرج يمنع استكمال الإجراءات حتى الإقرار والاطلاع';
    } else if (warningEntries.isNotEmpty) {
      bannerBorderColor = AppTheme.flatOrange;
      bannerBgColor = const Color(0xFFFEF9E7);
      bannerIcon = Icons.warning_amber_rounded;
      bannerTitle = 'تنبيهات وتجارب تشغيلية سابقة مطابقة لظروف هذه الشحنة';
    } else if (positiveEntries.isNotEmpty) {
      bannerBorderColor = AppTheme.flatEmerald;
      bannerBgColor = const Color(0xFFEAFAF1);
      bannerIcon = Icons.verified_rounded;
      bannerTitle = 'توجيهات وأفضل ممارسات موثقة من شحنات سابقة مماثلة';
    } else {
      bannerBorderColor = AppTheme.flatCobalt;
      bannerBgColor = const Color(0xFFEBF5FB);
      bannerIcon = Icons.psychology_outlined;
      bannerTitle = 'دليل الخبرة المؤسسية: ملاحظات ودروس مستفادة مسجلة';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bannerBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(bannerIcon, color: bannerBorderColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              bannerTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: bannerBorderColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: bannerBorderColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entries.length} ملاحظة مطابقة',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: bannerBorderColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasUnacknowledgedCritical)
                        const Text(
                          'يوجد توجيه حرج يتطلب الضغط على "إقرار واطلاع" للمتابعة وتفادي التكرار.',
                          style: TextStyle(fontSize: 11, color: AppTheme.flatCrimson),
                        ),
                    ],
                  ),
                ),
                // Add Entry Action
                TextButton.icon(
                  onPressed: _openAddEntryDialog,
                  icon: const Icon(Icons.add_comment_outlined, size: 15),
                  label: const Text('إضافة درس مستفاد', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.flatCharcoal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                const SizedBox(width: 4),
                // Expand / Collapse Toggle
                IconButton(
                  icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                  color: AppTheme.flatCharcoal,
                  tooltip: _isExpanded ? 'طي التفاصيل' : 'عرض التفاصيل',
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),

          // If unacknowledged critical entries exist, always show them even if collapsed
          if (hasUnacknowledgedCritical)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 12),
              child: Column(
                children: unacknowledgedCritical.map((e) => _buildCriticalEntryCard(e)).toList(),
              ),
            ),

          // Collapsible body with remaining entries
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Acknowledged critical
                  ...criticalEntries
                      .where((e) => _acknowledgedCriticalIds.contains(e.entryId))
                      .map((e) => _buildEntryCard(e)),

                  // Warnings
                  ...warningEntries.map((e) => _buildEntryCard(e)),

                  // Positive / Best Practice
                  ...positiveEntries.map((e) => _buildEntryCard(e)),

                  // Informational
                  ...infoEntries.map((e) => _buildEntryCard(e)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriticalEntryCard(GuideEntryModel entry) {
    final upvotesCount = entry.upvotes + (_upvotedIds.contains(entry.entryId) ? 1 : 0);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.flatCrimson, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.flatCrimson, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.localizedTitle(context.l10n),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.flatCrimson,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'قسم: ${entry.department}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.flatCrimson),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildSourceBadge(entry),
          const SizedBox(height: 6),
          Text(
            entry.localizedContent(context.l10n),
            style: const TextStyle(fontSize: 12, color: AppTheme.flatCharcoal, height: 1.4),
          ),
          const SizedBox(height: 8),
          _buildScopeTags(entry),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Upvote Button
                  InkWell(
                    onTap: () => _handleUpvote(entry.entryId),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            _upvotedIds.contains(entry.entryId) ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 14,
                            color: _upvotedIds.contains(entry.entryId) ? AppTheme.flatCobalt : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'مفيد ($upvotesCount)',
                            style: TextStyle(
                              fontSize: 11,
                              color: _upvotedIds.contains(entry.entryId) ? AppTheme.flatCobalt : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (entry.isSystemInferred) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openEvidenceTrail(entry),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.manage_search_rounded, size: 15, color: Color(0xFF0284C7)),
                            SizedBox(width: 4),
                            Text(
                              'مسار الأدلة (Evidence Trail)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Acknowledge Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 14),
                label: const Text('إقرار واطلاع قبل المتابعة (Acknowledge)'),
                onPressed: () => _acknowledgeCritical(entry.entryId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(GuideEntryModel entry) {
    final upvotesCount = entry.upvotes + (_upvotedIds.contains(entry.entryId) ? 1 : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: entry.severityColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(entry.severityIcon, color: entry.severityColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.localizedTitle(context.l10n),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: entry.severityColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.severityColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.department,
                  style: TextStyle(fontSize: 10, color: entry.severityColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildSourceBadge(entry),
          const SizedBox(height: 6),
          Text(
            entry.localizedContent(context.l10n),
            style: const TextStyle(fontSize: 12, color: AppTheme.flatCharcoal, height: 1.4),
          ),
          const SizedBox(height: 8),
          _buildScopeTags(entry),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => _handleUpvote(entry.entryId),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            _upvotedIds.contains(entry.entryId) ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 14,
                            color: _upvotedIds.contains(entry.entryId) ? AppTheme.flatCobalt : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'مفيد ($upvotesCount)',
                            style: TextStyle(
                              fontSize: 11,
                              color: _upvotedIds.contains(entry.entryId) ? AppTheme.flatCobalt : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (entry.isSystemInferred) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openEvidenceTrail(entry),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.manage_search_rounded, size: 15, color: Color(0xFF0284C7)),
                            SizedBox(width: 4),
                            Text(
                              'مسار الأدلة (Evidence Trail)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (entry.createdAt.isNotEmpty)
                Text(
                  'تاريخ التوثيق: ${entry.createdAt.split('T').first}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEvidenceTrail(GuideEntryModel entry) {
    AutonomousEvidenceTrailDialog.show(
      context,
      entryId: entry.entryId,
      initialTitle: entry.localizedTitle(context.l10n),
      initialEvidence: entry.localizedEvidence(context.l10n),
      initialReason: entry.localizedReason(context.l10n),
      onStateChanged: () {
        ref.read(experienceGuideProvider.notifier).fetchEntries();
      },
    );
  }

  Widget _buildSourceBadge(GuideEntryModel entry) {
    if (entry.isSystemInferred) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.flatEmerald.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 12, color: AppTheme.flatEmerald),
                const SizedBox(width: 4),
                Text(
                  'استنتاج ذكي ذاتي (${entry.confidencePercentString})',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.flatEmerald),
                ),
              ],
            ),
          ),
          if (entry.sampleSize != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'عينة: ${entry.sampleSize} شحنة',
                style: TextStyle(fontSize: 9.5, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
              ),
            ),
          if (entry.isConfirmed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 11, color: AppTheme.flatEmerald),
                  SizedBox(width: 3),
                  Text(
                    'معتمد مؤسسياً',
                    style: TextStyle(fontSize: 9.5, color: AppTheme.flatEmerald, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 12, color: Colors.indigo.shade700),
            const SizedBox(width: 4),
            Text(
              'توثيق بشري: ${entry.createdBy} (${entry.department})',
              style: TextStyle(fontSize: 10, color: Colors.indigo.shade900, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildScopeTags(GuideEntryModel entry) {
    if (entry.scopes.isEmpty && entry.matchedDimensions.isEmpty) {
      return const SizedBox.shrink();
    }

    final tags = entry.scopes.map((s) => '${s.scopeTypeAr}: ${s.scopeValue}').toList();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300, width: 0.8),
          ),
          child: Text(
            tag,
            style: const TextStyle(fontSize: 10, color: AppTheme.flatCharcoal),
          ),
        );
      }).toList(),
    );
  }
}
