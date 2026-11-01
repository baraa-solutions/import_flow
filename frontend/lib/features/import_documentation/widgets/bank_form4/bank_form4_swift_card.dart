import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../idoc_ui_b.dart';
import 'bank_form4_localizer.dart';
import 'stages/bank_form4_readiness_badge.dart';
import 'stages/bank_form4_stage1_card.dart';
import 'stages/bank_form4_stage2_card.dart';
import 'stages/bank_form4_stage3_card.dart';

/// Pre-Form 4 Readiness Pipeline (BP-015) & Bank SWIFT Linkage Card.
class BankForm4SwiftCard extends StatelessWidget {
  final int? importFileId;
  final BankingDocumentModel? activeDoc;
  final bool isDark;
  final bool isMobile;
  final VoidCallback onRefresh;
  final VoidCallback onOpenFormalLetter;

  const BankForm4SwiftCard({
    super.key,
    required this.importFileId,
    required this.activeDoc,
    required this.isDark,
    required this.isMobile,
    required this.onRefresh,
    required this.onOpenFormalLetter,
  });

  @override
  Widget build(BuildContext context) {
    if (importFileId == null) {
      return const SizedBox.shrink();
    }

    final doc = activeDoc;
    final isDocReady = doc != null && doc.canSubmitForm4;
    final hasBlockers = doc != null && doc.blockers.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDocReady
              ? AppTheme.wcagEmerald
              : (hasBlockers ? AppTheme.orange : (isDark ? AppTheme.darkBorder : AppTheme.border)),
          width: isDocReady || hasBlockers ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDocReady ? AppTheme.wcagEmerald : AppTheme.wcagCobalt).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDocReady ? Icons.verified : Icons.account_balance,
                    color: isDocReady ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              BankForm4Localizer.readinessPipelineTitle(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.wcagCobalt.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BP-015',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.wcagCobalt,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        BankForm4Localizer.readinessPipelineSubtitle(context),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                BankForm4ReadinessBadge(doc: doc),
              ],
            ),
            const SizedBox(height: 16),
            if (doc != null) ...[
              if (isMobile) ...[
                BankForm4Stage1TaxCodingCard(doc: doc, isDark: isDark, onRefresh: onRefresh),
                const SizedBox(height: 12),
                BankForm4Stage2ItemVerificationCard(doc: doc, isDark: isDark, onRefresh: onRefresh),
                const SizedBox(height: 12),
                BankForm4Stage3BankLinkageCard(doc: doc, isDark: isDark, onRefresh: onRefresh),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: BankForm4Stage1TaxCodingCard(doc: doc, isDark: isDark, onRefresh: onRefresh)),
                    const SizedBox(width: 12),
                    Expanded(child: BankForm4Stage2ItemVerificationCard(doc: doc, isDark: isDark, onRefresh: onRefresh)),
                    const SizedBox(width: 12),
                    Expanded(child: BankForm4Stage3BankLinkageCard(doc: doc, isDark: isDark, onRefresh: onRefresh)),
                  ],
                ),
              ],
              if (hasBlockers) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            BankForm4Localizer.pendingBlockersHeader(context),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.crimson,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...doc.blockers.map((blocker) => Padding(
                            padding: const EdgeInsetsDirectional.only(start: 26, bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    blocker,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.dangerForeground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IdocBUi.fit(AppButton(
                        label: BankForm4Localizer.formalLetterBtn(context),
                        icon: Icons.mark_email_read_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: onOpenFormalLetter,
                      )),
                      if (doc.swiftReferenceNo != null && doc.swiftReferenceNo!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.wcagCobalt.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.wcagCobalt.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz, size: 16, color: AppTheme.wcagCobalt),
                              const SizedBox(width: 6),
                              Text(
                                BankForm4Localizer.swiftRefBadge(context, doc.swiftReferenceNo!),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.wcagCobalt,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (doc.canSubmitForm4)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.wcagEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: AppTheme.wcagEmerald),
                          const SizedBox(width: 6),
                          Text(
                            BankForm4Localizer.qualifiedBadge(context),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.wcagEmerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
