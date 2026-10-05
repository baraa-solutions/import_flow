import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/dedicated_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/docs_customs_approval_provider.dart';
import '../widgets/customs_document_approval_tab.dart';
import '../widgets/formal_letter_generator_dialog.dart';
import '../widgets/search_and_clone_customs_approval_dialog.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../widgets/idoc_ui.dart';

/// Stage 6 of Draft Documents / Phase 3 Final Gate: Docs Customs Approval & Rectifications Screen (Full-Width View)
class DocsCustomsApprovalScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const DocsCustomsApprovalScreen({
    super.key,
    this.initialImportFileId,
  });

  @override
  ConsumerState<DocsCustomsApprovalScreen> createState() => _DocsCustomsApprovalScreenState();
}

class _DocsCustomsApprovalScreenState extends ConsumerState<DocsCustomsApprovalScreen> {
  int? _selectedImportFileId;
  final GlobalKey<CustomsDocumentApprovalTabState> _tabKey = GlobalKey<CustomsDocumentApprovalTabState>();

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() => _refreshData());
  }

  @override
  void didUpdateWidget(covariant DocsCustomsApprovalScreen oldWidget) {
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
      final approvals = ref.read(docsCustomsApprovalProvider).valueOrNull ?? [];
      showDialog(
        context: context,
        builder: (ctx) => SearchAndCloneCustomsApprovalDialog(
          items: approvals,
          onSelectItem: (item) {
            setState(() {
              _selectedImportFileId = item.importFileId;
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
          stageCode: 'STEP_09',
          titleAr: 'مركز اعتماد المستندات الجمركية وتعديلات المورد',
          titleEn: 'Docs Customs Approval & Rectifications Hub',
          headerIcon: Icons.verified_user_outlined,
          headerColor: AppTheme.cobalt,
          selectedImportFileId: _selectedImportFileId,
          onShipmentStatusChanged: _refreshData,
          headerActions: [
            IconButton(
              key: const Key('searchAndCloneCustomsApprovalBtn'),
              icon: Icon(Icons.copy_all, color: AppTheme.white, size: density.headerIconSize),
              tooltip: l.searchAndCloneCustomsApprovalBtn,
              onPressed: _openSearchAndCloneDialog,
            ),
            IdocUi.fit(AppButton(
              label: l.formalLetterDialogTitle,
              icon: Icons.description,
              variant: AppButtonVariant.secondary,
              onPressed: () => FormalLetterGeneratorDialog.show(context, importFileId: _selectedImportFileId),
            )),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.refresh, color: AppTheme.white, size: density.headerIconSize),
              tooltip: l.refresh,
              onPressed: _refreshData,
            ),
          ],
          body: CustomsDocumentApprovalTab(
            key: _tabKey,
            initialImportFileId: _selectedImportFileId,
          ),
        ),
      ),
    );
  }
}
