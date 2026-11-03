import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/import_documentation_model.dart';
import '../../idoc_ui_b.dart';
import '../bank_form4_dialogs.dart';
import '../bank_form4_localizer.dart';

/// Stage 1: Tax Coding card for BankForm4SwiftCard
class BankForm4Stage1TaxCodingCard extends StatelessWidget {
  final BankingDocumentModel doc;
  final bool isDark;
  final VoidCallback onRefresh;

  const BankForm4Stage1TaxCodingCard({
    super.key,
    required this.doc,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isPulled = doc.taxCodingPulledDate != null;
    final isUploaded = doc.taxCodingUploadedDate != null;
    final isDone = isPulled && isUploaded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? AppTheme.wcagEmerald : (isDark ? AppTheme.darkBorder : AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.receipt_long_outlined,
                color: isDone ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  BankForm4Localizer.stage1Title(context),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            BankForm4Localizer.stage1Subtitle(context),
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isPulled ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPulled ? Icons.check : Icons.circle_outlined,
                          size: 14,
                          color: isPulled ? AppTheme.wcagEmerald : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            BankForm4Localizer.stage1StepA(context),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isPulled)
                      Text(
                        doc.taxCodingPulledDate ?? '',
                        style: const TextStyle(fontSize: 10, color: AppTheme.wcagEmerald),
                      ),
                  ],
                ),
                if (!isPulled) ...[
                  const SizedBox(height: 6),
                  IdocBUi.fit(AppButton(
                    label: BankForm4Localizer.stage1StepABtn(context),
                    icon: Icons.file_download_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => BankForm4Dialogs.showPullTaxCoding(
                      context,
                      doc: doc,
                      onSubmitted: onRefresh,
                    ),
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isUploaded ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUploaded ? Icons.check : Icons.circle_outlined,
                          size: 14,
                          color: isUploaded ? AppTheme.wcagEmerald : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            BankForm4Localizer.stage1StepB(context),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isUploaded)
                      Text(
                        doc.taxCodingUploadedDate ?? '',
                        style: const TextStyle(fontSize: 10, color: AppTheme.wcagEmerald),
                      ),
                  ],
                ),
                if (!isUploaded) ...[
                  const SizedBox(height: 6),
                  IdocBUi.fit(AppButton(
                    label: BankForm4Localizer.stage1StepBBtn(context),
                    icon: Icons.upload_file_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: isPulled
                        ? () => BankForm4Dialogs.showUploadTaxCoding(
                              context,
                              doc: doc,
                              onSubmitted: onRefresh,
                            )
                        : null,
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
