import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_documentation_model.dart';
import '../../providers/import_documentation_provider.dart';
import '../search_and_clone_acid_dialog.dart';

class NafezaAcidDialogs {
  static void openSearchAndCloneDialog({
    required BuildContext context,
    required WidgetRef ref,
    required ValueChanged<AcidRegistrationModel> onCloneAcidSelected,
  }) {
    final acidSessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SearchAndCloneAcidDialog(
            sessions: acidSessions,
            onSelectSession: onCloneAcidSelected,
          ),
        ),
      ),
    );
  }

  static void showCloneAcidReviewDialog({
    required BuildContext context,
    required AcidRegistrationModel session,
    required void Function(AcidRegistrationModel session) onConfirmed,
  }) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: CloneEntityReviewDialog(
            entityType: l.idocBAcidCloneEntity,
            sourceCode: session.acidNumber.isNotEmpty ? session.acidNumber : session.acidCode,
            sourceTitle: session.importerName,
            suggestedNewCode: 'ACID-EG-2026-DRAFT',
            copiedFieldsSummary: {
              l.idocBAcidCloneFieldImporter: session.importerName,
              l.idocBAcidCloneFieldExporter: session.exporterName,
              l.idocBAcidCloneFieldCountry: session.exporterCountry,
              l.idocBAcidCloneFieldProforma: session.proformaInvoiceNo,
              l.idocBAcidCloneFieldPorts: '${session.polName} → ${session.podName}',
            },
            mandatorilyResetFields: [
              l.idocBAcidCloneReset1,
              l.idocBAcidCloneReset2,
              l.idocBAcidCloneReset3,
              l.idocBAcidCloneReset4,
            ],
            allowCopyLineItems: false,
            allowCopyAttachments: false,
            onConfirm: ({
              required String newCode,
              required String newTitle,
              required bool copyLineItems,
              required bool copyAttachments,
              String? notes,
            }) async {
              onConfirmed(session);
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(context, l.cloneAcidSuccess, severity: AppSeverity.success),
              );
            },
          ),
        ),
      ),
    );
  }

  static void openImportRawTextFromPreviousDialog({
    required BuildContext context,
    required WidgetRef ref,
    required void Function(String text, int? fileId) onImportText,
  }) {
    final acidSessions = ref.read(acidSessionsProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      builder: (dialogCtx) => AppLocalizationsProvider(
        locale: Localizations.localeOf(context),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SearchAndCloneAcidDialog(
            sessions: acidSessions,
            onSelectSession: (session) {
              final acidNum = session.acidNumber.isNotEmpty && session.acidNumber != 'PENDING'
                  ? session.acidNumber
                  : '';

              final rawReconstructed = '''MTS Notification
Dear ${session.exporterName},

Kindly be informed that an Advance Cargo Information request (ACI) has been approved for shipping:
[ACID: $acidNum]
Requested: ${session.requestedDate ?? ''}   Generated: ${session.generatedDate ?? ''}   Expires: ${session.expiryDate ?? ''}

Egyptian Importer
Egyptian Importer Name: ${session.importerName}
Egyptian Importer Tax ID: ${session.importerTaxId}
Address: ${session.importerAddress ?? ''}

Foreign Exporter
Foreign Exporter Name: ${session.exporterName}
Foreign Exporter ID: ${session.exporterRegId}
Registration Type: ${session.exporterRegType ?? 'Company Registration Number'}
Country of Export: ${session.exporterCountry}

Proforma Invoice No.: ${session.proformaInvoiceNo}
Port of Loading: ${session.polName}
Port of Discharge: ${session.podName}
CargoX Platform ID: ${session.cargoxId ?? ''}''';

              onImportText(rawReconstructed, session.importFileId);
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.snackBar(context, context.l10n.rawTextImportedSuccess, severity: AppSeverity.success),
              );
            },
          ),
        ),
      ),
    );
  }

  static AcidRegistrationModel buildFallbackSessionFromTracker(AcidTrackerItemModel item, List<AcidRegistrationModel> sessions) {
    AcidRegistrationModel? session = sessions.where((s) =>
        (item.acidSessionId != null && s.acidId == item.acidSessionId) ||
        (s.acidNumber.isNotEmpty && s.acidNumber == item.acidNumber) ||
        (item.importFileId != null && s.importFileId == item.importFileId)).firstOrNull;

    return session ?? AcidRegistrationModel(
      acidId: item.acidSessionId ?? 0,
      acidCode: item.acidCode ?? 'ACID-REG-2026',
      acidNumber: item.acidNumber,
      importFileId: item.importFileId,
      importFileCode: item.importFileCode,
      poNumber: item.poNumber,
      importerId: 1,
      importerName: item.importerName.isNotEmpty ? item.importerName : 'مستورد',
      importerTaxId: '100-200-300',
      supplierId: 1,
      exporterName: item.supplierName.isNotEmpty ? item.supplierName : 'مورد أجنبي',
      exporterCountry: 'China',
      exporterCountryCode: 'CN',
      exporterRegId: 'CN91310000',
      proformaInvoiceNo: item.piNumber ?? 'PI-2026-001',
      polName: 'CHANGSHU',
      podName: 'Alexandria',
      customsBrokerName: item.customsBrokerName,
      status: item.status,
      createdAt: item.acidIssueDate ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }
}
