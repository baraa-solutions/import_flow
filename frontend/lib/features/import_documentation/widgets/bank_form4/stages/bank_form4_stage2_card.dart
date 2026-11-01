import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../models/import_documentation_model.dart';
import '../../idoc_ui_b.dart';
import '../bank_form4_dialogs.dart';
import '../bank_form4_localizer.dart';

/// Stage 2: Item Verification card for BankForm4SwiftCard
class BankForm4Stage2ItemVerificationCard extends StatelessWidget {
  final BankingDocumentModel doc;
  final bool isDark;
  final VoidCallback onRefresh;

  const BankForm4Stage2ItemVerificationCard({
    super.key,
    required this.doc,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = doc.itemsPulledVerified;

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
                isDone ? Icons.check_circle : Icons.checklist_outlined,
                color: isDone ? AppTheme.wcagEmerald : AppTheme.wcagCobalt,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  BankForm4Localizer.stage2Title(context),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            BankForm4Localizer.stage2Subtitle(context),
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDone ? AppTheme.wcagEmerald : AppTheme.textMuted).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      BankForm4Localizer.stage2CodingRatio(context, doc.itemsCountCoded, doc.itemsCountTotal),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    if (isDone) const Icon(Icons.check, size: 16, color: AppTheme.wcagEmerald),
                  ],
                ),
                if (doc.regulatoryBodiesDetected.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: doc.regulatoryBodiesDetected
                        .map((b) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                b,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.orange,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                IdocBUi.fit(AppButton(
                  label: BankForm4Localizer.stage2Btn(context, isDone),
                  icon: Icons.fact_check_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => BankForm4Dialogs.showUpdateCodingProgress(
                    context,
                    doc: doc,
                    onSubmitted: onRefresh,
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
