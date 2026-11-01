import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_consultation_model.dart';
import '../providers/customs_consultation_provider.dart';
import 'saved_consultations/consultation_clone_handler.dart';
import 'saved_consultations/consultations_toolbar_strip.dart';
import 'saved_consultations/consultations_data_table.dart';
import 'saved_consultations/consultations_mobile_list.dart';

class SavedConsultationsTab extends ConsumerStatefulWidget {
  final Function(CustomsConsultationModel) onEdit;
  final Function(BuildContext, CustomsConsultationModel) onViewDetails;
  final bool isTaxReviewOnly;

  const SavedConsultationsTab({
    super.key,
    required this.onEdit,
    required this.onViewDetails,
    this.isTaxReviewOnly = false,
  });

  @override
  ConsumerState<SavedConsultationsTab> createState() => _SavedConsultationsTabState();
}

class _SavedConsultationsTabState extends ConsumerState<SavedConsultationsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  bool _showInactive = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCloneDialog(CustomsConsultationModel source) {
    ConsultationCloneHandler.openCloneReviewDialog(
      context: context,
      ref: ref,
      source: source,
      onEdit: widget.onEdit,
    );
  }

  void _openSearchAndClone(List<CustomsConsultationModel> sessions) {
    ConsultationCloneHandler.openSearchAndCloneDialog(
      context: context,
      ref: ref,
      consultations: sessions,
      onEdit: widget.onEdit,
    );
  }

  void _deleteOrRestore(CustomsConsultationModel session) {
    ConsultationCloneHandler.handleDeleteOrRestore(
      context: context,
      ref: ref,
      session: session,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final consultationsState = ref.watch(customsConsultationsProvider);
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return consultationsState.when(
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.cobalt),
            const SizedBox(height: 16),
            Text(l.loading, style: const TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      ),
      error: (err, stack) => Center(child: Text('${l.error}: $err')),
      data: (allSessions) {
        final sessions = widget.isTaxReviewOnly
            ? allSessions.where((s) => s.estimatedDutiesEgp > 0).toList()
            : allSessions;

        final filtered = sessions.where((s) {
          final rawFileCode = s.importFileCode ?? (s.importFileId != null ? 'IMP-${s.importFileId}' : '');
          final shipmentTitle = rawFileCode.isNotEmpty
              ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isArabic)
              : '';
          final matchQuery = _searchQuery.isEmpty ||
              s.consultationCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.brokerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              rawFileCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              shipmentTitle.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchStatus = _statusFilter == 'All' || s.overallStatus == _statusFilter;
          return matchQuery && matchStatus;
        }).toList();

        return SelectionArea(
          child: Column(
            children: [
              ConsultationsToolbarStrip(
                sessions: sessions,
                filteredSessions: filtered,
                importFiles: importFiles,
                searchController: _searchController,
                statusFilter: _statusFilter,
                showInactive: _showInactive,
                onSearchChanged: (v) => setState(() => _searchQuery = v),
                onStatusFilterChanged: (v) => setState(() => _statusFilter = v),
                onToggleInactive: (val) {
                  setState(() => _showInactive = val);
                  ref.read(customsConsultationsProvider.notifier).fetchConsultations(includeInactive: val);
                },
                onClonePressed: () => _openSearchAndClone(sessions),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 64, color: isDark ? AppTheme.textStrong : AppTheme.cloudWhite),
                            const SizedBox(height: 16),
                            Text(
                              l.noResultsFound,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 768) {
                            return ConsultationsMobileList(
                              sessions: filtered,
                              importFiles: importFiles,
                              isDark: isDark,
                              isArabic: isArabic,
                              onViewDetails: widget.onViewDetails,
                              onEdit: widget.onEdit,
                              onClone: _openCloneDialog,
                              onDeleteOrRestore: _deleteOrRestore,
                            );
                          }

                          return ConsultationsDataTable(
                            sessions: filtered,
                            importFiles: importFiles,
                            isDark: isDark,
                            isArabic: isArabic,
                            onViewDetails: widget.onViewDetails,
                            onEdit: widget.onEdit,
                            onClone: _openCloneDialog,
                            onDeleteOrRestore: _deleteOrRestore,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
