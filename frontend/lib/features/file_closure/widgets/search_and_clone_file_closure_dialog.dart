import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/file_closure_model.dart';
import 'file_closure_form_dialog.dart' show closureCompletedCount;
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';

/// Modal dialog that allows searching and selecting a previous File Closure Certificate / Archival Record
/// to clone into a new draft following the 5-Task Enterprise Protocol.
class SearchAndCloneFileClosureDialog extends ConsumerStatefulWidget {
  final List<ImportFileClosureModel> records;
  final ValueChanged<ImportFileClosureModel> onSelectRecord;

  const SearchAndCloneFileClosureDialog({
    super.key,
    required this.records,
    required this.onSelectRecord,
  });

  @override
  ConsumerState<SearchAndCloneFileClosureDialog> createState() =>
      _SearchAndCloneFileClosureDialogState();
}

class _SearchAndCloneFileClosureDialogState
    extends ConsumerState<SearchAndCloneFileClosureDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = (screenWidth - 32).clamp(360.0, 920.0);
    final dialogHeight = (screenHeight * 0.82).clamp(420.0, 780.0);
    final allFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final importFilesMap = {for (final f in allFiles) f.importFileId: f};

    final query = _searchController.text.trim().toLowerCase();
    final filteredRecords = widget.records.where((rec) {
      if (_statusFilter == 'Closed' && !rec.isFullyVerified) {
        return false;
      } else if (_statusFilter == 'Draft' && rec.isFullyVerified) {
        return false;
      }

      if (query.isEmpty) return true;

      final codeMatch = rec.closureCode.toLowerCase().contains(query);
      final auditorMatch = rec.auditorName.toLowerCase().contains(query);
      final vaultMatch = rec.archiveLocation.toLowerCase().contains(query);
      final notesMatch = (rec.archivalNotes ?? '').toLowerCase().contains(query);
      final matchingFile = importFilesMap[rec.importFileId];
      final fileCodeMatch = (matchingFile?.primaryNameWithCode ?? 'imp-${rec.importFileId}')
          .toLowerCase()
          .contains(query);
      final compMatch = (matchingFile?.companyName ?? '').toLowerCase().contains(query);

      return codeMatch || auditorMatch || vaultMatch || notesMatch || fileCodeMatch || compMatch;
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      backgroundColor: AppTheme.surfaceOf(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsetsDirectional.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OpsSectionHeader(
              title: l.cloneFileClosureDialogTitle,
              subtitle: l.cloneFileClosureDialogSubtitle,
              icon: Icons.archive_outlined,
              iconColor: AppTheme.emerald,
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: l.cancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.fileClosureSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, val, _) => val.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildFilterChip('All', l.closureFilterAll),
                _buildFilterChip('Closed', l.closureFilterClosed),
                _buildFilterChip('Draft', l.closureStatusDraft),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filteredRecords.isEmpty
                  ? OpsStateView.empty(
                      compact: true,
                      icon: Icons.search_off,
                      message: l.fileClosureEmptyRecords,
                    )
                  : ListView.separated(
                      itemCount: filteredRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final rec = filteredRecords[index];
                        final matchingFile = importFilesMap[rec.importFileId];
                        final fileCode = matchingFile?.primaryNameWithCode ?? 'IMP-${rec.importFileId}';
                        final compName = matchingFile?.companyName ?? '';
                        final verifiedCount = closureCompletedCount(rec.closureChecklist);

                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAltOf(context),
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            border: Border.all(color: AppTheme.borderOf(context)),
                          ),
                          padding: const EdgeInsetsDirectional.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                        border: Border.all(color: AppTheme.emerald),
                                      ),
                                      child: CopyableText(
                                        rec.closureCode,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.emerald,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OpsStatusChip(
                                    label: rec.isFullyVerified ? l.closureArchivedBadge : l.closureStatusDraft,
                                    severity: rec.isFullyVerified ? AppSeverity.success : AppSeverity.warning,
                                    icon: rec.isFullyVerified ? Icons.verified_outlined : Icons.edit_note,
                                    dense: true,
                                  ),
                                  const Spacer(),
                                  OpsFit(
                                    child: AppButton(
                                      key: Key('selectClosureToCloneBtn_${rec.closureCode}'),
                                      label: l.closureCloneToDraft,
                                      variant: AppButtonVariant.success,
                                      icon: Icons.difference_outlined,
                                      size: AppButtonSize.small,
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onSelectRecord(rec);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.folder_open, size: 16, color: AppTheme.cobalt),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      compName.isNotEmpty ? '$fileCode ($compName)' : fileCode,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimaryOf(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.storage, size: 16, color: AppTheme.textSecondaryOf(context)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      rec.archiveLocation,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.person_pin, size: 15, color: AppTheme.textSecondaryOf(context)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      rec.auditorName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
                                    ),
                                  ),
                                  Text(
                                    l.closureVerifiedConditions(verifiedCount),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: verifiedCount == 5 ? AppTheme.emerald : AppTheme.wcagOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _statusFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = filterKey);
        }
      },
      selectedColor: AppTheme.emerald.withOpacity(0.2),
      backgroundColor: AppTheme.surfaceAltOf(context),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.emerald : AppTheme.textSecondaryOf(context),
      ),
      side: BorderSide(color: isSelected ? AppTheme.emerald : AppTheme.borderOf(context)),
    );
  }
}
