import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../integrations/providers/integration_status_provider.dart';
import '../../integrations/widgets/simulation_mode_banner.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_documentation/providers/import_documentation_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../suppliers/providers/suppliers_provider.dart';
import '../models/cargox_model.dart';
import '../providers/cargox_provider.dart';
import '../widgets/standard_invoice_hub_tab.dart';
import '../widgets/cargox_hub/cargox_acid_verification_dialog.dart';
import '../widgets/cargox_hub/cargox_create_envelope_view.dart';
import '../widgets/cargox_hub/cargox_envelopes_table.dart';
import '../widgets/cargox_hub/cargox_hub_actions_bar.dart';
import '../widgets/cargox_hub/cargox_hub_header.dart';
import '../widgets/cargox_hub/cargox_hub_stats_bar.dart';
import '../widgets/cargox_hub/cargox_manifest_viewer.dart';

/// Coordinator screen for CargoX & ACI Blockchain Dispatch Hub.
class CargoXHubScreen extends ConsumerStatefulWidget {
  final int initialSubTab;
  final int? initialImportFileId;
  final bool isEmbedded;

  const CargoXHubScreen({
    super.key,
    this.initialSubTab = 0,
    this.initialImportFileId,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<CargoXHubScreen> createState() => _CargoXHubScreenState();
}

class _CargoXHubScreenState extends ConsumerState<CargoXHubScreen> {
  int _selectedSubTab = 0;
  int? _selectedImportFileId;

  // Filter & Search State
  String _searchQuery = '';
  String _statusFilter = 'All';

  DigitalManifestModel? _activeDigitalManifest;
  bool _isLoadingManifest = false;

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _selectedImportFileId = widget.initialImportFileId;

    Future.microtask(() {
      _refreshData();
    });
  }

  @override
  void didUpdateWidget(covariant CargoXHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubTab != oldWidget.initialSubTab) {
      setState(() => _selectedSubTab = widget.initialSubTab);
    }
    if (widget.initialImportFileId != null &&
        widget.initialImportFileId != _selectedImportFileId) {
      setState(() => _selectedImportFileId = widget.initialImportFileId);
    }
  }

  void _refreshData() {
    ref.invalidate(integrationStatusProvider);
    if (!ref.read(cargoxEnvelopesProvider).isLoading) {
      ref.read(cargoxEnvelopesProvider.notifier).fetchEnvelopes();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(suppliersProvider).isLoading) {
      ref.read(suppliersProvider.notifier).fetchSuppliers();
    }
    if (!ref.read(importCompaniesProvider).isLoading) {
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
    if (!ref.read(draftBLReviewsProvider).isLoading) {
      ref.read(draftBLReviewsProvider.notifier).fetchReviews();
    }
    if (!ref.read(freightBookingProvider).isLoading) {
      ref.read(freightBookingProvider.notifier).fetchBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopesState = ref.watch(cargoxEnvelopesProvider);
    final envelopes = envelopesState.valueOrNull ?? [];
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    final filtered = envelopes.where((e) {
      final q = _searchQuery.toLowerCase();
      if (q.isNotEmpty) {
        final matches = e.envelopeCode.toLowerCase().contains(q) ||
            e.acidNumber.toLowerCase().contains(q) ||
            e.supplierName.toLowerCase().contains(q) ||
            (e.blNumber != null && e.blNumber!.toLowerCase().contains(q)) ||
            (e.importFileCode != null && e.importFileCode!.toLowerCase().contains(q));
        if (!matches) return false;
      }
      if (_statusFilter != 'All' && e.status != _statusFilter) return false;
      return true;
    }).toList();

    final totalCount = envelopes.length;
    final acceptedCount = envelopes.where((e) => e.status == 'ACCEPTED_BY_CUSTOMS').length;
    final uploadedCount = envelopes.where((e) => e.status == 'UPLOADED_BY_SUPPLIER' || e.status == 'DRAFT').length;
    final verifiedCount = envelopes.where((e) => e.isAcidVerified).length;

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.table_chart_outlined,
        titleEn: 'Standard Commercial Invoice',
        titleAr: context.l10n.cargoxTabStandardInvoice,
      ),
      VerticalNavTabItem(
        icon: Icons.markunread_mailbox_outlined,
        titleEn: 'Create CargoX Envelope',
        titleAr: context.l10n.cargoxTabCreateEnvelope,
      ),
      VerticalNavTabItem(
        icon: Icons.hub_outlined,
        titleEn: 'Blockchain Envelopes Hub',
        titleAr: context.l10n.cargoxTabTrackingHub,
        badge: envelopes.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${envelopes.length}',
                  style: const TextStyle(
                    color: AppTheme.cobalt,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
      VerticalNavTabItem(
        icon: Icons.description_outlined,
        titleEn: 'ACI Digital Manifest Viewer',
        titleAr: context.l10n.cargoxTabManifestViewer,
      ),
    ];

    final stackContent = IndexedStack(
      index: _selectedSubTab,
      children: [
        StandardInvoiceHubTab(initialImportFileId: _selectedImportFileId),
        CargoXCreateEnvelopeView(
          initialImportFileId: _selectedImportFileId,
          onEnvelopeCreated: (created, isDraft) {
            setState(() => _selectedSubTab = 2);
            _refreshData();
          },
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CargoXHubStatsBar(
                totalCount: totalCount,
                acceptedCount: acceptedCount,
                uploadedCount: uploadedCount,
                verifiedCount: verifiedCount,
              ),
              const SizedBox(height: 18),
              CargoXHubActionsBar(
                searchQuery: _searchQuery,
                onSearchChanged: (val) => setState(() => _searchQuery = val),
                statusFilter: _statusFilter,
                onStatusFilterChanged: (val) => setState(() => _statusFilter = val),
                filteredEnvelopes: filtered,
                importFiles: importFiles,
                onPrepareNewEnvelope: () => setState(() => _selectedSubTab = 1),
              ),
              const SizedBox(height: 14),
              CargoXEnvelopesTable(
                envelopes: filtered,
                importFiles: importFiles,
                onVerifyAcid: _runAcidVerification,
                onViewManifest: _viewManifest,
                onSealAndTransfer: _sealAndTransfer,
              ),
            ],
          ),
        ),
        CargoXManifestViewer(
          activeDigitalManifest: _activeDigitalManifest,
          isLoadingManifest: _isLoadingManifest,
          envelopes: envelopes,
          onViewManifest: _viewManifest,
        ),
      ],
    );

    // Production Mock Guard (NLv0Dpj5): CargoX / Nafeza statuses below come from a simulation
    // whenever the backend says so; the banner makes that unmistakable.
    final bodyContent = Column(
      children: [
        const IntegrationSimulationBanner(),
        Expanded(child: stackContent),
      ],
    );

    if (widget.isEmbedded) {
      return SelectionArea(
        child: Column(
          children: [
            CargoXHubEmbeddedHeader(
              selectedSubTab: _selectedSubTab,
              onTabSelected: (idx) => setState(() => _selectedSubTab = idx),
            ),
            const Divider(height: 1),
            Expanded(child: bodyContent),
          ],
        ),
      );
    }

    return SelectionArea(
      child: VerticalStageScaffold(
        stageCode: 'PHASE-4: STEP_11',
        titleEn: 'CargoX & ACI Blockchain Dispatch Hub',
        titleAr: context.l10n.cargoxHubTitle,
        headerIcon: Icons.hub_outlined,
        headerColor: AppTheme.cobalt,
        tabs: tabs,
        selectedIndex: _selectedSubTab,
        onTabSelected: (idx) => setState(() => _selectedSubTab = idx),
        selectedImportFileId: _selectedImportFileId,
        onShipmentStatusChanged: _refreshData,
        headerActions: CargoXHubHeaderActions.build(
          context,
          selectedImportFileId: _selectedImportFileId,
          onRefresh: _refreshData,
        ),
        body: bodyContent,
      ),
    );
  }

  Future<void> _runAcidVerification(int envelopeId) async {
    try {
      final report = await ref
          .read(cargoxEnvelopesProvider.notifier)
          .verifyAcidConsistency(envelopeId);
      if (mounted) {
        CargoXAcidVerificationDialog.show(context, report);
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(
          context,
          title: context.l10n.cargoxAcidCheckError,
          error: e,
        );
      }
    }
  }

  Future<void> _sealAndTransfer(CargoXEnvelopeModel env) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: context.l10n.cargoxConfirmSealTransferTitle,
      message: context.l10n.cargoxConfirmSealTransferContent(env.envelopeCode),
      confirmLabel: context.l10n.cargoxConfirmTransferBtn,
      confirmVariant: AppButtonVariant.primary,
      icon: Icons.security,
    );

    if (confirm != true) return;

    try {
      final res = await ref
          .read(cargoxEnvelopesProvider.notifier)
          .sealAndTransferToCustoms(
            env.envelopeId,
            blNumber: env.blNumber,
            mode: 'MOCK',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.cargoxSealSuccessSnackbar(
              res['message'],
              res['customs_confirmation_receipt'],
            ),
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(
          context,
          title: context.l10n.cargoxTransferError,
          error: e,
        );
      }
    }
  }

  void _viewManifest(CargoXEnvelopeModel env) async {
    setState(() {
      _selectedSubTab = 3;
      _isLoadingManifest = true;
    });

    try {
      final manifest = await ref
          .read(cargoxEnvelopesProvider.notifier)
          .fetchDigitalManifest(env.envelopeId);
      if (mounted) {
        setState(() {
          _activeDigitalManifest = manifest;
          _isLoadingManifest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingManifest = false);
        showErrorDetailsDialog(
          context,
          title: context.l10n.cargoxFetchManifestError,
          error: e,
        );
      }
    }
  }
}
