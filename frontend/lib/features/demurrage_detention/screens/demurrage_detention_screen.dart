import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/density_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../l10n/container_eir_l10n.dart';
import '../providers/demurrage_provider.dart';
import '../widgets/container_deposit_ledger_dialog.dart';
import '../widgets/container_eir_dialog.dart';
import '../widgets/customs_abandonment_radar_dialog.dart';
import '../widgets/demurrage_policies_tab.dart';
import '../widgets/demurrage_simulator_tab.dart';
import '../widgets/demurrage_trackings_tab.dart';
import '../widgets/free_days_agreement_dialog.dart';
import '../widgets/freight_data_monitor_dialog.dart';
import '../widgets/port_terminal_storage_dialog.dart';

class DemurrageDetentionScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  const DemurrageDetentionScreen({super.key, this.initialImportFileId});

  @override
  ConsumerState<DemurrageDetentionScreen> createState() => _DemurrageDetentionScreenState();
}

class _DemurrageDetentionScreenState extends ConsumerState<DemurrageDetentionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(demurrageProvider).isLoading) {
        if (widget.initialImportFileId != null) {
          ref.read(demurrageProvider.notifier).fetchTrackings(importFileId: widget.initialImportFileId);
          ref.read(demurrageProvider.notifier).fetchFreeDaysAgreement(widget.initialImportFileId!);
        } else {
          ref.read(demurrageProvider.notifier).loadInitialData();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    ref.invalidate(demurrageProvider);
    ref.read(demurrageProvider.notifier).loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = ref.watch(displayDensityProvider);
    final state = ref.watch(demurrageProvider);
    final stageBadge = DisplayNameResolver.resolveStageBadge(
      'STEP_18',
      isArabic: Directionality.of(context) == TextDirection.rtl,
    );

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAltOf(context),
        appBar: PageHeader(
          icon: Icons.timer_outlined,
          iconColor: AppTheme.orange,
          title: l10n.demurrageScreenTitle,
          subtitle: stageBadge.isEmpty ? null : stageBadge,
          actions: [
            AppButton(
              label: _isAr ? 'رادار المهمل (مادة 67)' : 'Abandonment Radar',
              icon: Icons.radar_rounded,
              variant: AppButtonVariant.danger,
              size: AppButtonSize.small,
              onPressed: () => CustomsAbandonmentRadarDialog.show(context),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: _isAr ? 'أرضيات المحطات' : 'Port Storage',
              icon: Icons.account_balance_outlined,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: () => PortTerminalStorageDialog.show(context),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: l10n.openContainerEirDialog,
              icon: Icons.assignment_turned_in,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              onPressed: () => ContainerEirDialog.showForFile(context, ref, importFileId: widget.initialImportFileId),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: _isAr ? 'تأمين الحاويات (EIR)' : 'Container Deposit',
              icon: Icons.inventory_2_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: () => ContainerDepositLedgerDialog.show(context, initialImportFileId: widget.initialImportFileId),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: l10n.demHeaderFreeDaysBtn,
              icon: Icons.verified_user_outlined,
              variant: AppButtonVariant.success,
              size: AppButtonSize.small,
              onPressed: () {
                FreeDaysAgreementDialog.show(
                  context,
                  initialImportFileId: widget.initialImportFileId,
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: l10n.freightDataLaunchConnectorTooltip,
              icon: Icon(Icons.cloud_sync_outlined, color: AppTheme.white, size: density.buttonIconSize),
              onPressed: () => showFreightDataMonitorDialog(context, ref),
            ),
            IconButton(
              tooltip: l10n.refresh,
              icon: Icon(Icons.refresh, color: AppTheme.white, size: density.buttonIconSize),
              onPressed: _reload,
            ),
            const BackToDashboardButton(),
            const SizedBox(width: 12),
          ],
        ),
        body: SelectionArea(
          child: state.isLoading && state.trackings.isEmpty
              ? const CcStateView.loading()
              : AdaptiveTabScaffold(
                  controller: _tabController,
                  tabs: [
                    AdaptiveTabItem(
                      icon: Icons.list_alt_rounded,
                      label: l10n.containerTrackingsTab,
                      content: DemurrageTrackingsTab(
                        initialImportFileId: widget.initialImportFileId,
                        onReload: _reload,
                      ),
                    ),
                    AdaptiveTabItem(
                      icon: Icons.calculate_outlined,
                      label: l10n.simulatorAndTierCalcTab,
                      content: const DemurrageSimulatorTab(),
                    ),
                    AdaptiveTabItem(
                      icon: Icons.policy_outlined,
                      label: l10n.carrierTariffPoliciesTab,
                      content: const DemurragePoliciesTab(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
