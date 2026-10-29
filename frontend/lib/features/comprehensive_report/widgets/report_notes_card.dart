import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import 'report_card_container.dart';

/// Operational notes card for the Comprehensive Report.
class ReportNotesCard extends StatelessWidget {
  final ImportFileModel file;

  const ReportNotesCard({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ReportCardContainer(
      title: l.compReportSecNotes,
      icon: Icons.notes_outlined,
      iconColor: AppTheme.charcoal,
      child: file.notes == null || file.notes!.isEmpty
          ? Text(l.compReportNoNotes, style: const TextStyle(color: Colors.grey, fontSize: 12))
          : Text(file.notes!, style: const TextStyle(fontSize: 12, height: 1.5)),
    );
  }
}
