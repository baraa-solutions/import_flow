import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import 'draft_bl_controllers.dart';

/// Helper dialogs for Draft B/L cloning.
class DraftBlCloneDialog {
  static void show(
    BuildContext context, {
    required DraftBLReviewModel session,
    required DraftBlControllers controllers,
    required Future<void> Function() onCloneCompleted,
  }) {
    final l = context.l10n;
    final blNumber = (session.draftExtractedData?['draft_bl_number'] ??
            session.draftExtractedData?['bl_number'] ??
            session.draftBlNumber)
        .toString();

    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SelectionArea(
            child: CloneEntityReviewDialog(
              entityType: l.idocADraftBillOfLadingDraftB,
              sourceCode: session.blReviewCode,
              sourceTitle: '$blNumber — ${session.shippingLine ?? ""}',
              suggestedNewCode: 'DRAFT-BL-2026-',
              copiedFieldsSummary: {
                l.idocAShippingLine: session.shippingLine ?? '-',
                l.idocAVesselVoyage: '${session.vesselName ?? "-"} / ${session.voyageNumber ?? "-"}',
                l.idocABookingNumber: session.bookingNumber ?? '-',
                l.idocAFreightTerms: session.freightTerms ?? 'Prepaid',
                l.idocAPortOfLoadingArrival: '${session.polName ?? "-"} -> ${session.podName ?? "-"}',
              },
              mandatorilyResetFields: [
                l.idocACloneNoteBlNumber,
                l.idocACloneNoteReviewId,
                l.idocACloneNoteImporter,
                l.idocACloneNoteBroker,
                l.idocACloneNoteSnapshot,
              ],
              allowCopyLineItems: false,
              allowCopyAttachments: false,
              onConfirm: ({
                required newCode,
                required newTitle,
                required copyLineItems,
                required copyAttachments,
                notes,
              }) async {
                controllers.clearInputs();
                controllers.draftBlNumber.text = newCode.isNotEmpty ? newCode : 'DRAFT-BL-2026-';
                if (session.bookingNumber != null) controllers.bookingNo.text = session.bookingNumber!;
                if (session.shippingLine != null) controllers.shippingLine.text = session.shippingLine!;
                if (session.vesselName != null) controllers.vesselName.text = session.vesselName!;
                if (session.voyageNumber != null) controllers.voyage.text = session.voyageNumber!;
                if (session.polName != null) controllers.pol.text = session.polName!;
                if (session.podName != null) controllers.pod.text = session.podName!;
                if (session.freightTerms != null) controllers.freightTerms.text = session.freightTerms!;
                if (session.placeOfDelivery != null) controllers.placeOfDelivery.text = session.placeOfDelivery!;
                controllers.cbm.text = session.measurementCbm.toString();
                controllers.netWeight.text = session.netWeightKg.toString();
                controllers.packagesCount.text = session.packagesCount.toString();
                if (session.containerSummary != null) controllers.containerNo.text = session.containerSummary!;

                final draftData = session.draftExtractedData ?? {};
                if (draftData.isNotEmpty) {
                  controllers.syncExtractedFields(draftData);
                  controllers.draftBlNumber.text = newCode.isNotEmpty ? newCode : 'DRAFT-BL-2026-';
                }
                controllers.importerNotes.clear();
                controllers.brokerNotes.clear();

                await onCloneCompleted();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    AppTheme.snackBar(context, l.cloneDraftBlSuccess, severity: AppSeverity.info),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
