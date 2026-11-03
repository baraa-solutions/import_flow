import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/display_name_resolver.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/import_file_model.dart';
import '../../providers/import_files_provider.dart';

/// Dialog to search and select an import file to clone.
class SearchAndCloneImportFileDialog extends StatefulWidget {
  final List<ImportFileModel> files;
  final ValueChanged<ImportFileModel> onSelectFile;

  const SearchAndCloneImportFileDialog({
    super.key,
    required this.files,
    required this.onSelectFile,
  });

  /// Opens the search and clone dialog for import files.
  static void show(BuildContext context, WidgetRef ref) {
    final allFiles = ref.read(importFilesProvider).value ?? ref.read(paginatedImportFilesProvider).items;
    final textDirection = Directionality.of(context);
    final locale = Localizations.localeOf(context);
    showDialog(
      context: context,
      builder: (ctx) => AppLocalizationsProvider(
        locale: locale,
        child: Directionality(
          textDirection: textDirection,
          child: SearchAndCloneImportFileDialog(
            files: allFiles,
            onSelectFile: (file) {
              Navigator.of(ctx).pop();
              showCloneDialog(context, ref, file);
            },
          ),
        ),
      ),
    );
  }

  /// Opens the clone entity review dialog and executes the clone workflow.
  static void showCloneDialog(BuildContext context, WidgetRef ref, ImportFileModel file) {
    final l = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final arrowSymbol = DirectionalArrow.symbolForArabic(isAr);
    CloneEntityReviewDialog.show(
      context,
      entityType: l.cloneImportFileDialogTitle,
      sourceCode: file.importFileCode,
      suggestedNewCode: '${file.importFileCode}-CLONE',
      sourceTitle: file.customFileNumber ?? file.companyName,
      copiedFieldsSummary: {
        l.importingCompany: file.companyName.isNotEmpty ? file.companyName : '-',
        l.foreignSupplier: file.supplierName.isNotEmpty ? file.supplierName : '-',
        l.portsOfLoadingAndDischarge: '${file.portOfLoading ?? '-'} $arrowSymbol ${file.portOfDischarge ?? '-'}',
        l.transportModeIncoterm: '${file.shipmentMode} (${file.incotermCode})',
      },
      mandatorilyResetFields: [
        l.cloneFieldStatusDraftBadge,
        l.cloneFieldCustomsClearedReset,
        l.cloneFieldFinancialReset,
        l.cloneFieldAcidReset,
        l.cloneFieldPoReset,
      ],
      allowCopyLineItems: true,
      allowCopyAttachments: false,
      initialCopyLineItems: true,
      initialCopyAttachments: false,
      onConfirm: ({
        required String newCode,
        required String newTitle,
        required bool copyLineItems,
        required bool copyAttachments,
        String? notes,
      }) async {
        try {
          final cloned = await ref.read(importFilesProvider.notifier).cloneImportFile(
            file.importFileId,
            {
              'target_import_file_code': newCode.trim(),
              'new_import_file_code': newCode.trim(),
              'target_custom_file_number': newTitle.trim().isNotEmpty ? newTitle.trim() : null,
              'copy_invoices_data': copyLineItems,
              'copy_packing_lists': copyLineItems,
              'copy_items': copyLineItems,
              'copy_attachments': copyAttachments,
              if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
            },
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(
                context,
                l.clonedSuccessfullyToast(cloned?.importFileCode ?? newCode),
                severity: AppSeverity.success,
              ),
            );
          }
          final paginatedState = ref.read(paginatedImportFilesProvider);
          ref.read(paginatedImportFilesProvider.notifier).fetchPage(paginatedState.page);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(
                context,
                '${l.errorPrefix}: $e',
                severity: AppSeverity.danger,
              ),
            );
          }
          rethrow;
        }
      },
    );
  }

  @override
  State<SearchAndCloneImportFileDialog> createState() => _SearchAndCloneImportFileDialogState();
}

class _SearchAndCloneImportFileDialogState extends State<SearchAndCloneImportFileDialog> {
  final TextEditingController _queryController = TextEditingController();
  late List<ImportFileModel> _filteredFiles;

  @override
  void initState() {
    super.initState();
    _filteredFiles = widget.files;
    _queryController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _queryController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFiles = widget.files;
      } else {
        _filteredFiles = widget.files.where((f) {
          final code = f.importFileCode.toLowerCase();
          final customNum = (f.customFileNumber ?? '').toLowerCase();
          final comp = f.companyName.toLowerCase();
          final supp = f.supplierName.toLowerCase();
          final po = (f.poNumber ?? '').toLowerCase();
          return code.contains(query) ||
              customNum.contains(query) ||
              comp.contains(query) ||
              supp.contains(query) ||
              po.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Directionality.of(context) == TextDirection.rtl || Localizations.localeOf(context).languageCode == 'ar';

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? AppTheme.darkCardBackground : Colors.white,
        child: Container(
          width: 700,
          height: 600,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cobalt.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.control_point_duplicate_rounded, color: AppTheme.cobalt, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.searchAndCloneImportFileDialogTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.searchAndCloneImportFileSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: l.searchAndCloneImportFileHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _queryController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppTheme.darkInputBackground : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Results count
              Text(
                l.resultsWithCount(_filteredFiles.length),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),

              // Results List
              Expanded(
                child: _filteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              l.noMatchingShipmentsFound,
                              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final file = _filteredFiles[idx];
                          final shipName = DisplayNameResolver.resolveShipmentName(file, isArabic: isAr);
                          final stageName = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isAr);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            shipName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark ? AppTheme.darkHyperlink : AppTheme.cobalt,
                                            ),
                                          ),
                                          if (shipName != file.importFileCode) ...[
                                            const SizedBox(width: 8),
                                            LtrText(
                                              file.importFileCode,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 8),
                                          Chip(
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            label: Text(file.status, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                            backgroundColor: file.status == 'Open' ? AppTheme.wcagEmerald : (isDark ? const Color(0xFF475569) : Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${file.companyName} │ ${file.supplierName} │ ${file.shipmentMode} (${file.incotermCode})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${l.currentPhaseStage}: $stageName │ ${file.progressPercent.toInt()}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.wcagCobalt,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.control_point_duplicate_rounded, size: 16, color: Colors.white),
                                  label: Text(
                                    l.cloneBtn,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  onPressed: () => widget.onSelectFile(file),
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
      ),
    );
  }
}
