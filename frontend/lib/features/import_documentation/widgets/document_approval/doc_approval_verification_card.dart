import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/docs_customs_approval_model.dart';
import 'doc_approval_helpers.dart';

class DocApprovalVerificationCard extends StatelessWidget {
  final CrossDocumentMatrixResultModel matrixResult;

  const DocApprovalVerificationCard({
    super.key,
    required this.matrixResult,
  });

  @override
  Widget build(BuildContext context) {
    final isFullyCompliant = matrixResult.overallCompliance == 'Fully Compliant';
    final complianceColor = isFullyCompliant ? AppTheme.emerald : AppTheme.orange;

    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: complianceColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: complianceColor),
        ),
        child: Row(
          children: [
            Icon(
              isFullyCompliant ? Icons.verified : Icons.warning_amber_rounded,
              color: complianceColor,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CopyableText(
                    context.l10n.customsApprovalMatrixComplianceResult(
                      DocApprovalHelpers.getLocalizedCompliance(matrixResult.overallCompliance, context.l10n),
                      matrixResult.passedChecks,
                      matrixResult.totalChecks,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: complianceColor,
                    ),
                    isSelectable: false,
                  ),
                  if (matrixResult.notCheckedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        key: const Key('matrixNotCheckedChip'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          context.l10n.idocAMatrixNotChecked(matrixResult.notCheckedCount),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                    ),
                  if (matrixResult.completenessPercent > 0 || matrixResult.missingDocuments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: matrixResult.completenessPercent >= 100
                                  ? AppTheme.emerald.withValues(alpha: 0.2)
                                  : AppTheme.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.l10n.idocADocsCompletenessLabel(matrixResult.completenessPercent.toStringAsFixed(1)),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: matrixResult.completenessPercent >= 100 ? AppTheme.emerald : AppTheme.orange,
                              ),
                            ),
                          ),
                          if (matrixResult.missingDocuments.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.crimson.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.crimson.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                context.l10n.idocAMissingDocsWarning(matrixResult.missingDocuments.join(', ')),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.crimson),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (matrixResult.recommendations.isNotEmpty)
                    CopyableText(
                      context.l10n.customsApprovalMatrixRecommendations(matrixResult.recommendations.join(' | ')),
                      style: TextStyle(fontSize: 11, color: AppTheme.textPrimaryOf(context)),
                      isSelectable: false,
                    ),
                ],
              ),
            ),
            CopyableText(
              context.l10n.customsApprovalMatrixOpenTicketsCount(matrixResult.openTicketsCount),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimaryOf(context)),
              isSelectable: false,
            ),
          ],
        ),
      ),
    );
  }
}
