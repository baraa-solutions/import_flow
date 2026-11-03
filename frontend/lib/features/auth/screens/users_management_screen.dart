import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';
import '../providers/rbac_provider.dart';
import '../providers/users_provider.dart';
import '../widgets/users_management/user_form_dialog.dart';
import '../widgets/users_management/users_management_filter_bar.dart';
import '../widgets/users_management/users_management_header.dart';
import '../widgets/users_management/users_management_table.dart';

/// Screen 66 Coordinator: Users Management & RBAC Security Hub.
///
/// Radical decomposition keeping coordinator strictly under 350 lines while
/// delegating modular concerns to dedicated sub-components.
class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterRole = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(usersProvider).isLoading) {
        ref.read(usersProvider.notifier).fetchUsers();
      }
      if (!ref.read(rbacProvider).isLoading) {
        ref.read(rbacProvider.notifier).fetchRbacData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final usersState = ref.watch(usersProvider);
    final currentUser = ref.watch(authProvider).user;
    final isAdmin = currentUser?.isAdmin ?? false;

    // Filter users by role and search query
    final filtered = usersState.users.where((u) {
      final matchRole = _filterRole == 'ALL' || u.role.toUpperCase() == _filterRole;
      final matchSearch = _searchQuery.isEmpty ||
          u.fullName.toLowerCase().contains(_searchQuery) ||
          u.username.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery);
      return matchRole && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header ──────────────────────────────────────────────
            UsersManagementHeader(
              totalCount: usersState.users.length,
              isAdmin: isAdmin,
              onRefresh: () => ref.read(usersProvider.notifier).fetchUsers(),
              onAddUser: () => UserFormDialog.show(context),
            ),

            // ── Export Action Toolbar ───────────────────────────────────
            UsersManagementExportBar(filteredUsers: filtered),

            // ── Filters & Stats Row ─────────────────────────────────────
            UsersManagementFilterBar(
              state: usersState,
              searchController: _searchController,
              filterRole: _filterRole,
              onSearchChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              onRoleChanged: (role) => setState(() => _filterRole = role),
            ),

            // ── Main Content Area ───────────────────────────────────────
            Expanded(
              child: usersState.isLoading
                  ? const AppLoadingState()
                  : usersState.error != null
                      ? AppErrorState(
                          message: usersState.error!,
                          onRetry: () => ref.read(usersProvider.notifier).fetchUsers(),
                        )
                      : filtered.isEmpty
                          ? AppEmptyState(
                              icon: Icons.group_outlined,
                              message: l.usersMgmtNoResults,
                              subtitle: l.usersMgmtNoResultsHint,
                            )
                          : UsersManagementTable(
                              users: filtered,
                              isAdmin: isAdmin,
                              currentUserId: currentUser?.userId ?? -1,
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
