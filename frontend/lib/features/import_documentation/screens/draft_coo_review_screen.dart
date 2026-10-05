import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/dedicated_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/coo_review_tab.dart';
import '../widgets/formal_letter_generator_dialog.dart';
import '../widgets/search_and_clone_coo_dialog.dart';

/// Stage 4 of Draft Documents: Draft COO & EUR.1 Review Screen (Full-Width View)
class DraftCOOReviewScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const DraftCOOReviewScreen({
    super.key,
    this.initialImportFileId,
  });

  @override
  ConsumerState<DraftCOOReviewScreen> createState() => _DraftCOOReviewScreenState();
}

class _DraftCOOReviewScreenState extends ConsumerState<DraftCOOReviewScreen> {
  int? _selectedImportFileId;
  final GlobalKey<COOReviewTabState> _tabKey = GlobalKey<COOReviewTabState>();

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() => _refreshData());
  }

  @override
  void didUpdateWidget(covariant DraftCOOReviewScreen oldWidget) {
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

  void _openSearchAndCloneDialog() {
    if (_tabKey.currentState != null) {
      _tabKey.currentState!.openSearchAndCloneDialog();
    } else {
      final cooReviews = ref.read(cooReviewsProvider).valueOrNull ?? [];
      showDialog(
        context: context,
        builder: (ctx) => SearchAndCloneCooDialog(
          reviews: cooReviews,
          onSelectReview: (r) {
            setState(() {
              _selectedImportFileId = r.importFileId ?? _selectedImportFileId;
            });
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final density = ref.watch(displayDensityProvider);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _openSearchAndCloneDialog,
      },
      child: Focus(
        autofocus: true,
        child: DedicatedStageScaffold(
          stageCode: 'STEP_08_COO',
          titleAr: 'مسودة شهادة المنشأ و EUR.1 والاتفاقيات التفضيلية',
          titleEn: 'Draft COO & EUR.1 Review',
          headerIcon: Icons.flag_circle_outlined,
          headerColor: AppTheme.warningForeground,
          selectedImportFileId: _selectedImportFileId,
          onShipmentStatusChanged: _refreshData,
          headerActions: [
            IconButton(
              key: const Key('searchAndCloneCooBtn'),
              icon: Icon(Icons.copy_all, color: AppTheme.cloudWhite, size: density.headerIconSize),
              tooltip: l.searchAndCloneCooBtn,
              onPressed: _openSearchAndCloneDialog,
            ),
            AppButton(label: l.formalLetterDialogTitle, onPressed: () => FormalLetterGeneratorDialog.show(context, importFileId: _selectedImportFileId), variant: AppButtonVariant.secondary, icon: Icons.description),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.refresh, color: AppTheme.cloudWhite, size: density.headerIconSize),
              tooltip: l.refresh,
              onPressed: _refreshData,
            ),
          ],
          body: COOReviewTab(
            key: _tabKey,
            initialImportFileId: _selectedImportFileId,
          ),
        ),
      ),
    );
  }
}
