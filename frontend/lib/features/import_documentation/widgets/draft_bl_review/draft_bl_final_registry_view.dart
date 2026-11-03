import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/import_documentation_model.dart';
import 'registry_view/draft_bl_registry_table.dart';
import 'registry_view/draft_bl_registry_toolbar.dart';

/// Stage 5 View: Master Registry Archive for Draft B/L sessions.
/// Includes KPIs, multi-criteria filtering, TSV/Excel/PDF export,
/// and enterprise data table with clone, reload, preview, and print actions.
class DraftBlFinalRegistryView extends StatefulWidget {
  final List<DraftBLReviewModel> allReviews;
  final List<dynamic> importFiles;
  final VoidCallback onOpenSearchAndClone;
  final VoidCallback onRefreshRegistry;
  final ValueChanged<DraftBLReviewModel> onCloneSession;
  final ValueChanged<DraftBLReviewModel> onLoadSessionIntoEditor;
  final Future<void> Function(DraftBLReviewModel) onDeleteSession;

  const DraftBlFinalRegistryView({
    super.key,
    required this.allReviews,
    required this.importFiles,
    required this.onOpenSearchAndClone,
    required this.onRefreshRegistry,
    required this.onCloneSession,
    required this.onLoadSessionIntoEditor,
    required this.onDeleteSession,
  });

  @override
  State<DraftBlFinalRegistryView> createState() => _DraftBlFinalRegistryViewState();
}

class _DraftBlFinalRegistryViewState extends State<DraftBlFinalRegistryView> {
  String _selectedStatusFilter = 'ALL';
  int? _filterImportFileId;
  String _registrySearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.allReviews.length;
    final certifiedCount = widget.allReviews.where((r) => !r.isDraft).length;
    final draftCount = widget.allReviews.where((r) => r.isDraft).length;

    final filteredReviews = widget.allReviews.where((r) {
      if (_selectedStatusFilter == 'DRAFT' && !r.isDraft) return false;
      if (_selectedStatusFilter == 'CERTIFIED' && r.isDraft) return false;
      if (_filterImportFileId != null && r.importFileId != _filterImportFileId) return false;
      if (_registrySearchQuery.trim().isEmpty) return true;
      final q = _registrySearchQuery.trim().toLowerCase();
      final blNo = (r.draftExtractedData?['draft_bl_number'] ??
              r.draftExtractedData?['bl_number'] ??
              r.draftBlNumber)
          .toString()
          .toLowerCase();
      final line = (r.shippingLine ?? '').toLowerCase();
      final stage = r.stage.toLowerCase();
      final code = r.blReviewCode.toLowerCase();
      return blNo.contains(q) || line.contains(q) || stage.contains(q) || code.contains(q) || r.blReviewId.toString().contains(q);
    }).toList();

    return SelectionArea(
      child: Card(
        elevation: 2,
        color: AppTheme.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.transparent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DraftBlRegistryToolbar(
                totalCount: totalCount,
                certifiedCount: certifiedCount,
                draftCount: draftCount,
                selectedStatusFilter: _selectedStatusFilter,
                onStatusFilterChanged: (s) => setState(() => _selectedStatusFilter = s),
                importFiles: widget.importFiles,
                filterImportFileId: _filterImportFileId,
                onImportFileIdChanged: (id) => setState(() => _filterImportFileId = id),
                registrySearchQuery: _registrySearchQuery,
                onSearchQueryChanged: (q) => setState(() => _registrySearchQuery = q),
                onClearSearch: () => setState(() => _registrySearchQuery = ''),
                filteredReviews: filteredReviews,
                onOpenSearchAndClone: widget.onOpenSearchAndClone,
                onRefreshRegistry: widget.onRefreshRegistry,
              ),
              DraftBlRegistryTable(
                filteredReviews: filteredReviews,
                registrySearchQuery: _registrySearchQuery,
                onCloneSession: widget.onCloneSession,
                onLoadSessionIntoEditor: widget.onLoadSessionIntoEditor,
                onDeleteSession: widget.onDeleteSession,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
