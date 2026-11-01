import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../services/customs_declaration46_calculator.dart';
import '../idoc_ui_b.dart';

class Declaration46SummaryDialog {
  static void show({
    required BuildContext context,
    required AppLocalizations l,
    required ImportFileModel? file,
    required String declarationNo,
    required String submissionDate,
    required String? office,
    required String? channel,
    required String acidNumber,
    required String form4Number,
    required String blNumber,
    required String cifTotal,
    required String dutyRate,
    required String vatRate,
    required String totalDuties,
    required bool hasExemption,
    required double? appliedDutyRate,
    required String miss,
  }) {
    final declSummaryText = '''
==================================================
${l.customsDeclPreviewTitle}
==================================================
${l.customsDeclColDeclarationNo}: $declarationNo
${l.customsDeclSubmissionDateLabel.replaceAll('*', '').trim()}: $submissionDate
${l.customsDeclColFileNumber}: ${file?.primaryNameWithCode ?? '-'}
${l.customsDeclColSupplier}: ${file?.supplierName ?? '-'}
${l.ccDecOfficeLabel}: ${office ?? '-'}
${l.customsDeclChannelLabel}: ${channel ?? '-'}
${l.customsDeclAcidNumberLabel}: $acidNumber
${l.customsDeclForm4NumberLabel}: $form4Number
${l.customsDeclBlNumberLabel}: $blNumber
--------------------------------------------------
[${l.customsDeclDutiesHeader}]
${l.customsDeclCifTotalEgpLabel}: $cifTotal
${l.customsDeclImportDutyRateLabel}: $dutyRate
${l.customsDeclVatRateLabel}: $vatRate
${l.customsDeclTotalDutiesLabel}: $totalDuties
--------------------------------------------------
[${l.customsDeclExemptionHeader}]
${hasExemption ? l.customsDeclEur1ExemptionTitle : l.customsDeclMfnExemptionTitle(appliedDutyRate.fixedOrMissing(1, miss))}
==================================================
''';

    showDialog(
      context: context,
      builder: (ctx) => IdocBDialogShell(
        title: l.customsDeclPreviewTitle,
        icon: Icons.description_outlined,
        badge: declarationNo.isNotEmpty ? declarationNo : 'DRAFT',
        maxWidth: 640,
        body: SelectionArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: Text(
              declSummaryText,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
        ),
        actions: [
          IdocBDialogAction(
            label: l.customsDeclCopySummarySuccess,
            icon: Icons.copy,
            onPressed: () => CopyHelper.copy(context, declSummaryText, customMessage: l.customsDeclCopySummarySuccess),
          ),
          IdocBDialogAction(
            label: l.customsDeclCloseDialog,
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}
