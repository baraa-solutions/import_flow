import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/widgets.dart';

/// Top header for Screen 31: Projects & Cost Centers.
///
/// Implements standard Type B PageHeader with title, subtitle, and navigation actions.
class ProjectsHeader extends StatelessWidget implements PreferredSizeWidget {
  const ProjectsHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PageHeader(
      icon: Icons.folder_special_outlined,
      title: l10n.projectsScreenTitle,
      subtitle: l10n.projectsScreenSubtitle,
      actions: const [
        BackToDashboardButton(),
        SizedBox(width: 8),
      ],
    );
  }
}
