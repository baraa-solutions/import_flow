import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../import_files/models/import_file_model.dart';
import '../idoc_ui_b.dart';
import 'declaration46_summary_dialog.dart';

class Declaration46ActionsBar extends StatelessWidget {
  final bool isSavingDeclaration;
  final VoidCallback onSave;
  final VoidCallback onCopyTsv;
  final VoidCallback onOpenSearchAndClone;
  final ImportFileModel? currentFile;
  final String declaration46No;
  final String submissionDate;
  final String? selectedOffice;
  final String? selectedChannel;
  final String acidNumber;
  final String form4Number;
  final String blNumber;
  final String cifTotal;
  final String dutyRate;
  final String vatRate;
  final String totalDuties;
  final bool hasExemption;
  final double? appliedDutyRate;
  final String miss;

  const Declaration46ActionsBar({
    super.key,
    required this.isSavingDeclaration,
    required this.onSave,
    required this.onCopyTsv,
    required this.onOpenSearchAndClone,
    required this.currentFile,
    required this.declaration46No,
    required this.submissionDate,
    required this.selectedOffice,
    required this.selectedChannel,
    required this.acidNumber,
    required this.form4Number,
    required this.blNumber,
    required this.cifTotal,
    required this.dutyRate,
    required this.vatRate,
    required this.totalDuties,
    required this.hasExemption,
    required this.appliedDutyRate,
    required this.miss,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return IdocBActionBar(
      secondary: [
        AppButton(
          key: const Key('printPreviewDeclaration46Btn'),
          label: l.customsDeclPrintPreviewButton,
          onPressed: () => Declaration46SummaryDialog.show(
            context: context,
            l: l,
            file: currentFile,
            declarationNo: declaration46No,
            submissionDate: submissionDate,
            office: selectedOffice,
            channel: selectedChannel,
            acidNumber: acidNumber,
            form4Number: form4Number,
            blNumber: blNumber,
            cifTotal: cifTotal,
            dutyRate: dutyRate,
            vatRate: vatRate,
            totalDuties: totalDuties,
            hasExemption: hasExemption,
            appliedDutyRate: appliedDutyRate,
            miss: miss,
          ),
          variant: AppButtonVariant.secondary,
          icon: Icons.visibility_outlined,
        ),
        AppButton(
          key: const Key('exportDeclaration46TsvBtn'),
          label: l.customsDeclExportTsvButton,
          onPressed: onCopyTsv,
          variant: AppButtonVariant.secondary,
          icon: Icons.table_chart_outlined,
        ),
        AppButton(
          key: const Key('bottomSearchAndCloneDeclBtn'),
          label: l.searchAndCloneCustomsDeclBtn,
          onPressed: onOpenSearchAndClone,
          variant: AppButtonVariant.secondary,
          icon: Icons.copy_all,
        ),
      ],
      primary: [
        AppButton(
          key: const Key('saveDeclaration46Btn'),
          label: isSavingDeclaration ? l.customsDeclSavingProgress : l.customsDeclSaveButton,
          onPressed: isSavingDeclaration ? null : onSave,
          variant: AppButtonVariant.success,
          icon: Icons.save,
          isLoading: isSavingDeclaration,
        ),
      ],
    );
  }
}
