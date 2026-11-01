import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/master_data_export_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_requirement_model.dart';

class ImportRequirementsToolbar extends StatelessWidget {
  final VoidCallback onAddNewRequirement;
  final List<ImportRequirementModel> requirements;
  final VoidCallback onRefresh;
  final void Function(BuildContext context, List<ImportRequirementModel> reqs) onCopyTsv;

  const ImportRequirementsToolbar({
    super.key,
    required this.onAddNewRequirement,
    required this.requirements,
    required this.onRefresh,
    required this.onCopyTsv,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        AppButton(
          label: l10n.createNewRequirementBtn,
          icon: Icons.add,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          onPressed: onAddNewRequirement,
        ),
        const SizedBox(width: 8),
        AppButton(
          label: l10n.requirementsExportTsvBtn,
          icon: Icons.table_chart_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () => onCopyTsv(context, requirements),
        ),
        const SizedBox(width: 8),
        AppButton(
          label: l10n.requirementsExportExcelBtn,
          icon: Icons.file_download_outlined,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          onPressed: () => MasterDataExportService.exportImportRequirementsToExcel(context, requirements),
        ),
        const SizedBox(width: 8),
        AppButton(
          label: l10n.requirementsExportPdfBtn,
          icon: Icons.picture_as_pdf_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: () => MasterDataExportService.printOrSaveImportRequirementsListPdf(context, requirements),
        ),
        const Spacer(),
        AppButton(
          label: l10n.refresh,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}
