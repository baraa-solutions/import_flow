import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../idoc_ui_b.dart';

class InspectionReviewActionsBar extends StatelessWidget {
  final bool hasCritical;
  final bool hasDisc;
  final VoidCallback onExportTsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onCopyDossier;
  final VoidCallback onSaveReview;

  const InspectionReviewActionsBar({
    super.key,
    required this.hasCritical,
    required this.hasDisc,
    required this.onExportTsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onCopyDossier,
    required this.onSaveReview,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              hasCritical
                  ? Icons.error
                  : (hasDisc ? Icons.warning : Icons.check_circle),
              color: hasCritical
                  ? AppTheme.crimson
                  : (hasDisc ? AppTheme.orange : AppTheme.emerald),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              hasCritical
                  ? l10n.hasCriticalMismatchStatus
                  : (hasDisc
                      ? l10n.hasMinorDiscrepanciesStatus
                      : l10n.inspectionConforms100Status),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IdocBUi.fit(
              AppButton(
                label: l10n.exportTsvBtn,
                onPressed: onExportTsv,
                variant: AppButtonVariant.secondary,
                icon: Icons.table_chart_outlined,
              ),
            ),
            IdocBUi.fit(
              AppButton(
                label: l10n.exportExcelBtn,
                onPressed: onExportExcel,
                variant: AppButtonVariant.secondary,
                icon: Icons.file_download_outlined,
              ),
            ),
            IdocBUi.fit(
              AppButton(
                label: l10n.exportPdfBtn,
                onPressed: onExportPdf,
                variant: AppButtonVariant.secondary,
                icon: Icons.picture_as_pdf,
              ),
            ),
            IdocBUi.fit(
              AppButton(
                label: l10n.copyDossierBtn,
                onPressed: onCopyDossier,
                variant: AppButtonVariant.secondary,
                icon: Icons.copy_all_outlined,
              ),
            ),
            IdocBUi.fit(
              AppButton(
                label: l10n.saveToInspectionRegistryBtn,
                onPressed: onSaveReview,
                icon: Icons.save,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
