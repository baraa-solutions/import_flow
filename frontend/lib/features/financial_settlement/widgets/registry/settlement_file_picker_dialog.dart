import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/searchable_dropdown_field.dart';
import '../../../import_files/models/import_file_model.dart';
import '../actual_landed_cost_dialog.dart';
import '../final_settlement_invoices_dialog.dart';

class SettlementFilePickerDialog {
  static Future<void> pickAndOpen({
    required BuildContext context,
    required List<ImportFileModel> files,
    required bool actualCost,
  }) async {
    final l10n = context.l10n;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          actualCost
              ? l10n.settlementSelectShipmentForActual
              : l10n.settlementSelectShipmentForInvoices,
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    int? selectedFileId;
    final formKey = GlobalKey<FormState>();

    final chosen = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.settlementPickFileTitle),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: SearchableDropdownField<int>(
                key: const Key('settlementPickFileField'),
                value: selectedFileId,
                labelText: l10n.settlementPickFileField,
                items: files.map((f) {
                  final label = f.companyName.isNotEmpty
                      ? '${f.primaryNameWithCode} - ${f.companyName}'
                      : f.primaryNameWithCode;
                  return SearchableDropdownItem<int>(
                    value: f.importFileId,
                    label: label,
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedFileId = val;
                  });
                },
                validator: (v) =>
                    v == null ? l10n.financialSettlementImportFileValidator : null,
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l10n.cancel,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(dialogCtx).pop(false),
            ),
            AppButton(
              key: const Key('settlementPickFileContinueBtn'),
              label: l10n.settlementPickFileContinue,
              variant: AppButtonVariant.primary,
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogCtx).pop(true);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (chosen != true || selectedFileId == null || !context.mounted) {
      return;
    }

    final chosenFile = files.firstWhere((f) => f.importFileId == selectedFileId);

    if (actualCost) {
      ActualLandedCostDialog.show(
        context,
        importFileId: chosenFile.importFileId,
        importFileCode: chosenFile.importFileCode,
      );
    } else {
      FinalSettlementInvoicesDialog.show(
        context,
        importFileId: chosenFile.importFileId,
        importFileCode: chosenFile.importFileCode,
      );
    }
  }
}
