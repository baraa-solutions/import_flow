import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/dedicated_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../widgets/formal_letter_generator_dialog.dart';
import '../widgets/inspection_review_tab.dart';

/// Stage 5 of Draft Documents: Inspection & Conformity Review (COC) Screen (Full-Width View)
class DraftInspectionReviewScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const DraftInspectionReviewScreen({
    super.key,
    this.initialImportFileId,
  });

  @override
  ConsumerState<DraftInspectionReviewScreen> createState() => _DraftInspectionReviewScreenState();
}

class _DraftInspectionReviewScreenState extends ConsumerState<DraftInspectionReviewScreen> {
  int? _selectedImportFileId;

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() => _refreshData());
  }

  @override
  void didUpdateWidget(covariant DraftInspectionReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialImportFileId != widget.initialImportFileId && widget.initialImportFileId != null) {
      setState(() {
        _selectedImportFileId = widget.initialImportFileId;
      });
    }
  }

  Future<void> _refreshData() async {
    if (!ref.read(importFilesProvider).isLoading) {
      await ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    if (_selectedImportFileId == null && files.isNotEmpty && mounted) {
      setState(() {
        _selectedImportFileId = files.first.importFileId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);

    return DedicatedStageScaffold(
      stageCode: 'STEP_08_COC',
      titleAr: 'شهادات الفحص والتفتيش المسبق والمطابقة (COC)',
      titleEn: 'Inspection & Conformity Review (COC)',
      headerIcon: Icons.security_outlined,
      headerColor: AppTheme.cobalt,
      selectedImportFileId: _selectedImportFileId,
      onShipmentStatusChanged: _refreshData,
      headerActions: [
        AppButton(label: l.formalLetterDialogTitle, onPressed: () => FormalLetterGeneratorDialog.show(context, importFileId: _selectedImportFileId), variant: AppButtonVariant.secondary, icon: Icons.description),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.cloudWhite, size: density.headerIconSize),
          tooltip: l.refresh,
          onPressed: _refreshData,
        ),
      ],
      body: SelectionArea(
        child: InspectionReviewTab(
        initialImportFileId: _selectedImportFileId,
        ),
      ),
    );
  }
}
