import 'package:flutter/material.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../models/import_documentation_model.dart';

class DraftBlSessionDetailsDialog extends StatelessWidget {
  final DraftBLReviewModel session;
  final ValueChanged<DraftBLReviewModel> onLoadSessionIntoEditor;

  const DraftBlSessionDetailsDialog({
    super.key,
    required this.session,
    required this.onLoadSessionIntoEditor,
  });

  static void show(
    BuildContext context, {
    required DraftBLReviewModel session,
    required ValueChanged<DraftBLReviewModel> onLoadSessionIntoEditor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: DraftBlSessionDetailsDialog(
          session: session,
          onLoadSessionIntoEditor: onLoadSessionIntoEditor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final matrix = session.comparisonMatrix;
    final isDraft = session.isDraft;

    return AlertDialog(
      titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDraft ? AppTheme.orange : AppTheme.emerald).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDraft ? Icons.bookmark_added_rounded : Icons.verified_rounded,
              color: isDraft ? AppTheme.orange : AppTheme.emerald,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.idocASessionDetailsTitle(session.blReviewCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                ),
                const SizedBox(height: 2),
                Text(
                  l.idocABlNumberCreated(session.draftBlNumber, session.createdAt),
                  style: TextStyle(fontSize: 12, color: AppTheme.textMutedOf(context)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isDraft ? AppTheme.orange : AppTheme.emerald).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDraft ? AppTheme.orange : AppTheme.emerald),
            ),
            child: Text(
              isDraft ? l.idocADraft : l.idocACertified,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDraft ? AppTheme.orange : AppTheme.emerald,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 850,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                l.idocAReviewAndComparisonMatrix,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (matrix.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(l.idocANoSavedMatrixItems)))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.charcoal),
                    headingTextStyle: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12),
                    columns: [
                      DataColumn(label: Text(l.idocAStandardField)),
                      DataColumn(label: Text(l.idocAValueRecordedInTheSystem)),
                      DataColumn(label: Text(l.idocAValueInTheDraftBL)),
                      DataColumn(label: Text(l.idocAMatchStatus)),
                    ],
                    rows: matrix.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item.fieldLabelAr, style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(item.displaySystemValue(l))),
                        DataCell(Text(item.displayDraftValue(l))),
                        DataCell(
                          AppStatusBadge(
                            label: item.matchStatus == 'MATCH' ? l.idocAMatched : l.idocAVariance,
                            severity: item.matchStatus == 'MATCH' ? AppSeverity.success : AppSeverity.danger,
                            size: AppStatusBadgeSize.small,
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        AppButton(
          label: l.idocARestoreAndLoadInTheReview,
          icon: Icons.play_circle_outline,
          variant: AppButtonVariant.ghost,
          onPressed: () {
            Navigator.pop(context);
            onLoadSessionIntoEditor(session);
          },
        ),
        AppButton(
          label: l.close,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
