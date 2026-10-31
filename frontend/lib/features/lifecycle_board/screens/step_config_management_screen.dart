import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/rbac_provider.dart';
import '../models/step_config_model.dart';
import '../providers/step_config_provider.dart';
import '../widgets/step_config_access_denied_view.dart';
import '../widgets/step_config_audit_history_dialog.dart';
import '../widgets/step_config_edit_dialog.dart';
import '../widgets/step_config_filter_bar.dart';
import '../widgets/step_config_table_view.dart';

/// Screen for managing lifecycle step skip policies, approval workflows, and audit history.
class StepConfigManagementScreen extends ConsumerStatefulWidget {
  const StepConfigManagementScreen({super.key});

  @override
  ConsumerState<StepConfigManagementScreen> createState() =>
      _StepConfigManagementScreenState();
}

class _StepConfigManagementScreenState
    extends ConsumerState<StepConfigManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rbacProvider.notifier).fetchRbacData();
      ref.read(stepConfigProvider.notifier).fetchConfigs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canManageUsers(UserModel? user) {
    if (user == null) return false;
    final role = user.role.toUpperCase();
    return role == 'ADMIN' ||
        role == 'DEVELOPER' ||
        role == 'GENERAL_MANAGER' ||
        role == 'OPERATIONS_MANAGER';
  }

  void _showEditDialog(BuildContext context, StepConfigModel config) {
    if (!_canManageUsers(ref.read(authProvider).user)) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => StepConfigEditDialog(config: config),
    );
  }

  void _showAuditDialog(BuildContext context, StepConfigModel config) {
    showDialog(
      context: context,
      builder: (dialogCtx) => StepConfigAuditHistoryDialog(config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isAuthorized = _canManageUsers(user);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SelectionArea(
        child: isAuthorized
            ? _buildAuthorizedManagementView()
            : const StepConfigAccessDeniedView(),
      ),
    );
  }

  Widget _buildAuthorizedManagementView() {
    final state = ref.watch(stepConfigProvider);
    final notifier = ref.read(stepConfigProvider.notifier);
    final l = context.l10n;
    final canManage = _canManageUsers(ref.watch(authProvider).user);

    if (state.isLoading) {
      return const Center(child: AppLoadingState());
    }

    if (state.errorMessage != null && state.configs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => notifier.fetchConfigs(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.retry),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(notifier),
        StepConfigFilterBar(
          state: state,
          notifier: notifier,
          searchController: _searchController,
          onClearSearch: () {
            _searchController.clear();
            notifier.setSearchQuery('');
            setState(() {});
          },
        ),
        Expanded(
          child: state.filteredConfigs.isEmpty
              ? _buildEmptyView()
              : StepConfigTableView(
                  configs: state.filteredConfigs,
                  canManage: canManage,
                  onShowEdit: (cfg) => _showEditDialog(context, cfg),
                  onShowAudit: (cfg) => _showAuditDialog(context, cfg),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(StepConfigNotifier notifier) {
    final l = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.flatCobalt.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppTheme.flatCobalt,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.stepConfigTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.stepConfigSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.stepConfigRefreshTooltip,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2C3E50)),
            onPressed: () => notifier.fetchConfigs(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    final l = context.l10n;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            l.stepConfigEmptySearch,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
