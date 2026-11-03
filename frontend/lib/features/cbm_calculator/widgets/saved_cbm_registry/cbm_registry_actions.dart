import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/cbm_calculator_model.dart';
import '../../providers/cbm_calculator_provider.dart';
import 'cbm_search_clone_dialog.dart';

/// Helper actions and mutation dialogs for CBM calculations registry.
abstract final class CbmRegistryActions {
  /// Delete (soft) or restore a calculation record.
  static Future<void> handleDeleteOrRestore(
    BuildContext context,
    WidgetRef ref,
    CBMCalculationModel calc,
  ) async {
    final l = context.l10n;
    if (calc.isActive) {
      final confirm = await AppConfirmDialog.show(
        context,
        title: l.confirmSoftDelete,
        message:
            '${l.confirmDeleteCalcMessage} "${calc.calcCode} - ${calc.title}"?',
        confirmLabel: l.delete,
        cancelLabel: l.cancel,
        confirmVariant: AppButtonVariant.danger,
        icon: Icons.warning_rounded,
      );
      if (confirm == true) {
        await ref
            .read(cbmCalculatorProvider.notifier)
            .deleteCalculation(calc.calcId!);
      }
    } else {
      await ref
          .read(cbmCalculatorProvider.notifier)
          .restoreCalculation(calc.calcId!);
    }
  }

  /// Launch Clone Review dialog for a calculation record.
  static void showCloneReviewDialog(
    BuildContext context,
    WidgetRef ref,
    CBMCalculationModel calc,
  ) {
    final l = context.l10n;
    CloneEntityReviewDialog.show(
      context,
      entityType: l.cloneCbmDialogTitle,
      sourceCode: calc.calcCode,
      suggestedNewCode: '${calc.calcCode}-CLONE',
      sourceTitle: calc.title ?? calc.calcCode,
      copiedFieldsSummary: {
        l.calculationSessionTitle: calc.title ?? '-',
        l.totalCbmVolumeMetric: '${calc.totalCbm.toStringAsFixed(2)} m³',
        l.grossWeightMetric: '${calc.totalGrossWeightKg.toStringAsFixed(0)} kg',
        l.stackingCol: calc.isStackable ? l.stackable : l.nonStackable,
        l.shippingStrategyCol: calc.shippingMethodLabel(l),
      },
      mandatorilyResetFields: [
        l.cloneFieldCalcCodeGenerated,
        l.cloneFieldImportFileReset,
        l.cloneFieldPoReset,
      ],
      allowCopyLineItems: true,
      allowCopyAttachments: false,
      initialCopyLineItems: true,
      initialCopyAttachments: false,
      onConfirm: ({
        required newCode,
        required newTitle,
        required copyLineItems,
        required copyAttachments,
        notes,
      }) async {
        final cloned =
            await ref.read(cbmCalculatorProvider.notifier).cloneCalculation(
                  calc.calcId!,
                  newCode: newCode,
                  newTitle: newTitle,
                  copyItems: copyLineItems,
                  notes: notes,
                );
        if (cloned != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              l.cloneCbmSuccess(cloned.calcCode),
              severity: AppSeverity.success,
            ),
          );
        }
      },
    );
  }

  /// Open Search & Clone Dialog, and immediately launch clone review dialog if selected.
  static Future<void> openSearchAndCloneCBMDialog(
    BuildContext context,
    WidgetRef ref,
    List<CBMCalculationModel> calculations,
  ) async {
    final selectedCalc = await CbmSearchCloneDialog.show(
      context,
      calculations: calculations,
    );
    if (selectedCalc != null && context.mounted) {
      showCloneReviewDialog(context, ref, selectedCalc);
    }
  }

  /// Open Edit Metadata Dialog (title & notes).
  static void showEditCalcDialog(
    BuildContext context,
    WidgetRef ref,
    CBMCalculationModel calc,
  ) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: calc.title ?? '');
    final notesCtrl = TextEditingController(text: calc.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCardBackground : null,
          title: Text(l.cbmEditMetadataDialogTitle(calc.calcCode)),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: l.cbmMetadataTitleLabel,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l.requiredFieldValidation
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.cbmMetadataNotesLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            AppButton(
              label: l.save,
              variant: AppButtonVariant.primary,
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final ok = await ref
                      .read(cbmCalculatorProvider.notifier)
                      .updateCalculation(
                    calc.calcId!,
                    {
                      'title': titleCtrl.text.trim(),
                      'notes': notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    },
                  );
                  if (ok && context.mounted) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(
                        context,
                        l.cbmMetadataSavedSuccess,
                        severity: AppSeverity.success,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Open Link to PO / Project Dialog.
  static void showLinkToPODialog(
    BuildContext context,
    WidgetRef ref,
    CBMCalculationModel calc,
    List poList,
    List projectsList,
  ) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int? selectedPoId = calc.poId;
    int? selectedProjectId = calc.projectId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SelectionArea(
          child: AlertDialog(
            backgroundColor: isDark ? AppTheme.darkCardBackground : null,
            title: Text(l.cbmLinkPoDialogTitle(calc.calcCode)),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<int?>(
                    value: selectedPoId,
                    labelText: l.cbmLinkSelectPoLabel,
                    searchHintText: l.cbmLinkSelectPoSearchHint,
                    items: [
                      SearchableDropdownItem<int?>(
                        value: null,
                        label: l.cbmSessionStandalone,
                      ),
                      ...poList.map((po) {
                        final projPart = po.projectName != null
                            ? ' (${po.projectName})'
                            : '';
                        return SearchableDropdownItem<int?>(
                          value: po.poId,
                          label:
                              '${po.displayName} (${po.poNumber})$projPart',
                          subtitle: po.supplierName,
                        );
                      }),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedPoId = v),
                  ),
                  const SizedBox(height: 12),
                  SearchableDropdownField<int?>(
                    value: selectedProjectId,
                    labelText: l.cbmLinkSelectProjectLabel,
                    searchHintText: l.cbmLinkSelectProjectSearchHint,
                    items: [
                      SearchableDropdownItem<int?>(
                        value: null,
                        label: l.cbmSessionStandalone,
                      ),
                      ...projectsList.map((p) => SearchableDropdownItem<int?>(
                            value: p.projectId,
                            label: '${p.projectCode} - ${p.projectName}',
                          )),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedProjectId = v),
                  ),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: l.cancel,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => Navigator.pop(dialogCtx),
              ),
              AppButton(
                label: l.save,
                variant: AppButtonVariant.primary,
                onPressed: () async {
                  final ok = await ref
                      .read(cbmCalculatorProvider.notifier)
                      .linkToPO(
                        calc.calcId!,
                        poId: selectedPoId,
                        projectId: selectedProjectId,
                      );
                  if (ok && context.mounted) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      AppTheme.snackBar(
                        context,
                        l.cbmLinkSavedSuccess,
                        severity: AppSeverity.success,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Export CBM registry list to Excel.
  static Future<void> exportCbmListToExcel(
    BuildContext context,
    List<CBMCalculationModel> calcs,
  ) async {
    final l = context.l10n;
    if (calcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.cbmNoCalculationsToExport,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      l.cbmCalcCode,
      l.colImportFile,
      l.customsTaxLogTsvHeaderTitle,
      l.poTotalCBM2,
      l.cbmVolumetricWtKg,
      l.grossWeightCol,
      l.cbmStackable,
      l.cbmShippingStrategy,
      l.recommendedContainerCol,
    ];

    final rows = calcs.map((c) {
      return [
        c.calcCode,
        c.importFileCode ?? '-',
        c.title ?? '-',
        c.totalCbm.toStringAsFixed(3),
        c.totalVolumetricWeightKg.toStringAsFixed(1),
        c.totalGrossWeightKg.toStringAsFixed(1),
        c.isStackable ? l.projectMultiShipmentYes : l.projectMultiShipmentNo,
        c.shippingMethodLabel(l),
        c.recommendedContainersLabel(l),
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.cbmCBMRegistry,
      importFileNameOrCode: 'CBM_Calculations_Registry',
    );
  }

  /// Export CBM registry list to PDF.
  static Future<void> exportCbmListToPdf(
    BuildContext context,
    List<CBMCalculationModel> calcs,
  ) async {
    final l = context.l10n;
    if (calcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.cbmNoCalculationsToExport,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      l.cbmCode,
      l.cbmFile,
      l.titleField,
      l.cbmRowLineCbm,
      l.cbmVolWt2,
      l.cbmGrossWt,
      l.cbmMode,
      l.containerCol,
    ];

    final rows = calcs.map((c) {
      return [
        c.calcCode,
        c.importFileCode ?? '-',
        c.title ?? '-',
        c.totalCbm.toStringAsFixed(3),
        c.totalVolumetricWeightKg.toStringAsFixed(1),
        c.totalGrossWeightKg.toStringAsFixed(1),
        c.shippingMethodLabel(l),
        c.recommendedContainersLabel(l),
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: l.cbmCBMRegistry,
      importFileNameOrCode: 'CBM_Calculations_Registry',
      headerContext: TableExportHeaderContext(
        title: l.cbmCBMVolumetricWeightRegistry,
        subtitle: 'Sorour Logistics ERP',
        metadata: {
          l.totalStudiesMetric: '${calcs.length}',
          l.date: DateTime.now().toString().substring(0, 10),
        },
      ),
    );
  }

  /// Copy CBM registry table data as TSV to sanitized clipboard.
  static void copyCbmTableAsTsv(
    BuildContext context,
    List<CBMCalculationModel> calcs,
  ) {
    final l = context.l10n;
    if (calcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l.cbmNoCalculationsToCopy,
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    final headers = [
      l.cbmCalcCode,
      l.colImportFile,
      l.customsTaxLogTsvHeaderTitle,
      l.poTotalCBM2,
      l.cbmVolumetricWtKg,
      l.grossWeightCol,
      l.cbmStackable,
      l.cbmShippingStrategy,
      l.recommendedContainerCol,
    ];

    final rows = calcs.map((c) {
      return [
        c.calcCode,
        c.importFileCode ?? '-',
        c.title ?? '-',
        c.totalCbm.toStringAsFixed(3),
        c.totalVolumetricWeightKg.toStringAsFixed(1),
        c.totalGrossWeightKg.toStringAsFixed(1),
        c.isStackable ? l.projectMultiShipmentYes : l.projectMultiShipmentNo,
        c.shippingMethodLabel(l),
        c.recommendedContainersLabel(l),
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l.cbmCBMCalculationsTableCopiedToClipboard,
    );
  }
}
