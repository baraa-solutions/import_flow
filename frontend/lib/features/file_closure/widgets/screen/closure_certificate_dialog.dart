import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../../warehouse_receiving/widgets/ops_ui_kit.dart';
import '../../models/file_closure_model.dart';

/// Modal dialog displaying details of a closure certificate
class ClosureCertificateDialog {
  static void show(
    BuildContext context, {
    required ImportFileClosureModel record,
    required ImportFileModel? file,
    required VoidCallback onCopySummary,
  }) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: OpsSectionHeader(
          title: l10n.fileClosureCertificateDialogTitle(record.closureCode),
          icon: Icons.verified_outlined,
          iconColor: AppTheme.emerald,
        ),
        content: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CopyableText(l10n.fileClosureCertFileNo(record.importFileId)),
              const SizedBox(height: 4),
              CopyableText(l10n.fileClosureCertLocation(record.archiveLocation)),
              const SizedBox(height: 4),
              CopyableText(l10n.fileClosureCertAuditor(record.auditorName)),
              const SizedBox(height: 4),
              CopyableText(l10n.fileClosureCertClosedDate(record.closedAt)),
              if (record.archivalNotes != null) ...[
                const SizedBox(height: 4),
                CopyableText(l10n.fileClosureCertNotes(record.archivalNotes!)),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 16),
        actions: [
          AppButton(
            label: l10n.fileClosureCopyCertTsvBtn,
            icon: Icons.copy,
            variant: AppButtonVariant.ghost,
            onPressed: onCopySummary,
          ),
          AppButton(
            label: l10n.close,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }
}
