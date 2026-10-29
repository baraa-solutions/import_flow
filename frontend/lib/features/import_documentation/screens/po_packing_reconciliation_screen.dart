import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/dedicated_stage_scaffold.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../providers/import_documentation_provider.dart';
import '../widgets/formal_letter_generator_dialog.dart';
import '../widgets/po_reconciliation_tab.dart';
import '../widgets/search_and_clone_po_reconciliation_dialog.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../widgets/idoc_ui.dart';

/// Stage 1 of Draft Documents: PO & Packing Reconciliation Screen (Full-Width View)
class POPackingReconciliationScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;

  const POPackingReconciliationScreen({
    super.key,
    this.initialImportFileId,
  });

  @override
  ConsumerState<POPackingReconciliationScreen> createState() => _POPackingReconciliationScreenState();
}

class _POPackingReconciliationScreenState extends ConsumerState<POPackingReconciliationScreen> {
  int? _selectedImportFileId;
  final GlobalKey<POReconciliationTabState> _tabKey = GlobalKey<POReconciliationTabState>();

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    Future.microtask(() => _refreshData());
  }

  @override
  void didUpdateWidget(covariant POPackingReconciliationScreen oldWidget) {
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
      final sessions = ref.read(poReconciliationSessionsProvider).valueOrNull ?? [];
      showDialog(
        context: context,
        builder: (ctx) => SearchAndClonePoReconciliationDialog(
          sessions: sessions,
          onSelectSession: (s) {
            setState(() {
              _selectedImportFileId = s.importFileId;
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
          stageCode: 'STEP_08_PO',
          titleAr: 'مطابقة الفاتورة وقائمة التعبئة مع أمر الشراء',
          titleEn: 'PO & Packing Reconciliation',
          headerIcon: Icons.fact_check_outlined,
          headerColor: AppTheme.cobalt,
          selectedImportFileId: _selectedImportFileId,
          onShipmentStatusChanged: _refreshData,
          headerActions: [
            IconButton(
              key: const Key('searchAndClonePoReconBtn'),
              icon: Icon(Icons.copy_all, color: AppTheme.white, size: density.headerIconSize),
              tooltip: l.searchAndClonePoReconBtn,
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
          body: SelectionArea(
            child: POReconciliationTab(
            key: _tabKey,
            initialImportFileId: _selectedImportFileId,
            ),
          ),
        ),
      ),
    );
  }
}
