import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../incoterms/providers/incoterms_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/project_model.dart';
import '../providers/projects_provider.dart';
import '../widgets/project_details_dialog.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/projects_screen/projects_actions_bar.dart';
import '../widgets/projects_screen/projects_header.dart';
import '../widgets/projects_screen/projects_helpers.dart';
import '../widgets/projects_screen/projects_stats_bar.dart';
import '../widgets/projects_screen/projects_table_view.dart';

/// Coordinator screen for Screen 31: Projects & Cost Centers.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _statuses = ['All', 'Open', 'Closed', 'On Hold'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectsState = ref.read(projectsProvider);
      if (!projectsState.isLoading) {
        ref.read(projectsProvider.notifier).fetchProjects();
      }
      final companiesState = ref.read(importCompaniesProvider);
      if (!companiesState.isLoading) {
        ref.read(importCompaniesProvider.notifier).fetchCompanies();
      }
      final suppliersState = ref.read(suppliersProvider);
      if (!suppliersState.isLoading) {
        ref.read(suppliersProvider.notifier).fetchSuppliers();
      }
      final incotermsState = ref.read(incotermsProvider);
      if (!incotermsState.isLoading) {
        ref.read(incotermsProvider.notifier).fetchIncoterms();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchQuery = val;
    ref.read(projectsProvider.notifier).fetchProjects(
          status: _selectedStatus,
          search: val,
        );
  }

  void _onStatusChanged(String st) {
    setState(() => _selectedStatus = st);
    ref.read(projectsProvider.notifier).fetchProjects(
          status: st,
          search: _searchQuery,
        );
  }

  void _onRefresh() {
    ref.read(projectsProvider.notifier).fetchProjects(
          status: _selectedStatus,
          search: _searchQuery,
        );
  }

  void _onCreateProject() {
    ProjectFormDialog.show(context, ref: ref);
  }

  void _onEditProject(ProjectModel project) {
    ProjectFormDialog.show(context, ref: ref, project: project);
  }

  void _onViewProject(ProjectModel project) {
    ProjectDetailsDialog.show(
      context,
      project,
      onEdit: () => _onEditProject(project),
    );
  }

  Future<void> _onToggleActive(ProjectModel project) async {
    final l10n = context.l10n;
    final isActive = project.isActive;
    final confirm = await AppConfirmDialog.showToggleActive(
      context,
      isCurrentlyActive: isActive,
      entityName: project.projectName,
      message: isActive
          ? l10n.confirmDeactivateProject(project.projectName)
          : l10n.confirmActivateProject(project.projectName),
    );
    if (confirm == true && project.projectId != null) {
      ref.read(projectsProvider.notifier).toggleActive(project.projectId!, isActive);
    }
  }

  void _onCopySummary(ProjectModel project) {
    final summary = ProjectsHelpers.buildProjectSummary(context, project);
    CopyHelper.copy(
      context,
      summary,
      customMessage: context.l10n.projectCopySummarySuccess,
    );
  }

  void _onExportTsv(List<ProjectModel> projects) {
    ProjectsHelpers.copyProjectsTsv(context, projects);
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsList = projectsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade100,
      appBar: const ProjectsHeader(),
      body: SelectionArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProjectsStatsBar(projects: projectsList),
              if (projectsList.isNotEmpty) const SizedBox(height: 8),
              ProjectsActionsBar(
                projects: projectsAsync.valueOrNull,
                searchController: _searchController,
                selectedStatus: _selectedStatus,
                statuses: _statuses,
                onSearchChanged: _onSearchChanged,
                onStatusChanged: _onStatusChanged,
                onCreateProject: _onCreateProject,
                onRefresh: _onRefresh,
                onExportTsv: () => _onExportTsv(projectsList),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ProjectsTableView(
                  projectsAsync: projectsAsync,
                  onView: _onViewProject,
                  onEdit: _onEditProject,
                  onToggleActive: _onToggleActive,
                  onCopySummary: _onCopySummary,
                  onRetry: _onRefresh,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
