import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/users_provider.dart';
import '../../services/users_management_export_service.dart';

/// Top header for Screen 66: Users Management & RBAC Security Hub.
///
/// Displays screen title, dynamic total count, quick refresh, and Add User action.
class UsersManagementHeader extends StatelessWidget {
  final int totalCount;
  final bool isAdmin;
  final VoidCallback onRefresh;
  final VoidCallback onAddUser;

  const UsersManagementHeader({
    super.key,
    required this.totalCount,
    required this.isAdmin,
    required this.onRefresh,
    required this.onAddUser,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.manage_accounts_rounded,
              color: AppTheme.cobalt,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.usersMgmtTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              Text(
                l.usersMgmtSubtitle(totalCount),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Refresh
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.cobalt),
            tooltip: l.usersMgmtRefreshTooltip,
          ),
          const SizedBox(width: 8),
          // Add User (Admin) or Read-Only Notice
          if (isAdmin)
            AppButton(
              label: l.usersMgmtNewUserBtn,
              icon: Icons.person_add_outlined,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: onAddUser,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 14, color: AppTheme.orange),
                  const SizedBox(width: 6),
                  Text(
                    l.usersMgmtReadOnlyNotice,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact export action bar for exporting filtered users (TSV, Excel, PDF, Dossier).
class UsersManagementExportBar extends StatelessWidget {
  final List<UserDetail> filteredUsers;

  const UsersManagementExportBar({
    super.key,
    required this.filteredUsers,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEmpty = filteredUsers.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        border: Border(bottom: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // TSV Export
          OutlinedButton.icon(
            onPressed: isEmpty
                ? null
                : () async {
                    await UsersManagementExportService.saveUsersTsvToFile(context, filteredUsers);
                  },
            icon: const Icon(Icons.file_download_outlined, size: 15),
            label: Text(l.usersMgmtExportTsvBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.charcoal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // Excel / CSV Export
          OutlinedButton.icon(
            onPressed: isEmpty
                ? null
                : () async {
                    await UsersManagementExportService.saveUsersCsvToFile(context, filteredUsers);
                  },
            icon: const Icon(Icons.table_chart_outlined, size: 15),
            label: Text(l.usersMgmtExportExcelBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.emerald,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // PDF Print / Save
          OutlinedButton.icon(
            onPressed: isEmpty
                ? null
                : () async {
                    await UsersManagementExportService.printOrSaveUsersPdf(context, filteredUsers);
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
            label: Text(l.usersMgmtPrintPdfBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.crimson,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          // Dossier Copy
          OutlinedButton.icon(
            onPressed: isEmpty
                ? null
                : () {
                    UsersManagementExportService.copyDossierToClipboard(context, filteredUsers);
                  },
            icon: const Icon(Icons.content_copy_outlined, size: 15),
            label: Text(l.usersMgmtCopyDossierBtn),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cobalt,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
