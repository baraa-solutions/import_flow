import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/helpers/master_data_action_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/density_provider.dart';
import '../../../../core/widgets/action_toolbar.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/project_model.dart';
import 'projects_filter_bar.dart';
import 'projects_helpers.dart';

/// Unified action toolbar for Screen 31: Projects & Cost Centers.
class ProjectsActionsBar extends ConsumerWidget {
  final List<ProjectModel>? projects;
  final TextEditingController searchController;
  final String selectedStatus;
  final List<String> statuses;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onCreateProject;
  final VoidCallback onRefresh;
  final VoidCallback onExportTsv;

  const ProjectsActionsBar({
    super.key,
    required this.projects,
    required this.searchController,
    required this.selectedStatus,
    required this.statuses,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onCreateProject,
    required this.onRefresh,
    required this.onExportTsv,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final hasProjects = projects != null && projects!.isNotEmpty;

    return ActionToolbar(
      primaryActions: [
        AppButton(
          label: l10n.createNewProjectBtn,
          icon: Icons.add,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.medium,
          onPressed: onCreateProject,
        ),
      ],
      moreActionItems: MasterDataActionHelper.buildStandardMoreActionItems(
        context: context,
        includeTsv: hasProjects,
      ),
      onMoreActionSelected: (val) => MasterDataActionHelper.handleStandardAction(
        context: context,
        ref: ref,
        actionValue: val,
        moduleEndpoint: 'projects',
        entityNameAr: 'المشاريع ومراكز التكلفة',
        entityNameEn: 'Projects & Cost Centers',
        entityFilePrefix: 'Projects_CostCenters',
        onImportSuccess: onRefresh,
        onCopyTsv: () {
          if (hasProjects) {
            ProjectsHelpers.copyProjectsTsv(context, projects!);
          }
        },
      ),
      searchController: searchController,
      searchHint: l10n.projectsSearchHint,
      onSearchChanged: onSearchChanged,
      filters: [
        ProjectsFilterBar(
          selectedStatus: selectedStatus,
          statuses: statuses,
          onStatusChanged: onStatusChanged,
        ),
      ],
      quickDataActions: [
        IconButton(
          icon: Icon(Icons.refresh, size: density.buttonIconSize + 2),
          tooltip: l10n.liveRefresh,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: density.buttonHeight,
            minHeight: density.buttonHeight,
          ),
          onPressed: onRefresh,
        ),
        if (hasProjects)
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: density.buttonIconSize + 2,
              color: AppTheme.cobalt,
            ),
            tooltip: l10n.projectsExportTsvBtn,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: density.buttonHeight,
              minHeight: density.buttonHeight,
            ),
            onPressed: onExportTsv,
          ),
      ],
    );
  }
}
