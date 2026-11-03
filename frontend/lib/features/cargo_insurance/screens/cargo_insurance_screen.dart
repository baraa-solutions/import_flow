import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../services/cargo_insurance_export_service.dart';
import '../../cargo_shipping/providers/cargo_shipping_provider.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../import_companies/providers/import_companies_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../models/cargo_insurance_model.dart';
import '../providers/cargo_insurance_provider.dart';
import '../widgets/insurance_certificates_table.dart';
import '../widgets/insurance_details_dialog.dart';
import '../widgets/damage_claim_dialog.dart';
import '../widgets/insurance_form_dialog.dart';
import '../widgets/insurance_policy_card.dart';

class CargoInsuranceScreen extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final bool isEmbedded;

  const CargoInsuranceScreen({
    super.key,
    this.initialImportFileId,
    this.isEmbedded = false,
  });

  static void showCreateDialog(BuildContext context, {int? initialImportFileId}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CargoInsuranceFormDialog(
        initialImportFileId: initialImportFileId,
      ),
    );
  }

  @override
  ConsumerState<CargoInsuranceScreen> createState() => _CargoInsuranceScreenState();
}

class _CargoInsuranceScreenState extends ConsumerState<CargoInsuranceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _refreshData();
    });
  }

  void _refreshData() {
    if (!ref.read(cargoInsuranceProvider).isLoading) {
      ref.read(cargoInsuranceProvider.notifier).fetchCertificates();
    }
    if (!ref.read(importFilesProvider).isLoading) {
      ref.read(importFilesProvider.notifier).fetchImportFiles();
    }
    if (!ref.read(partnersProvider).isLoading) {
      ref.read(partnersProvider.notifier).fetchPartners();
    }
    if (!ref.read(importCompaniesProvider).isLoading) {
      ref.read(importCompaniesProvider.notifier).fetchCompanies();
    }
    if (!ref.read(currenciesProvider).isLoading) {
      ref.read(currenciesProvider.notifier).fetchCurrencies();
    }
    if (!ref.read(freightBookingProvider).isLoading) {
      ref.read(freightBookingProvider.notifier).fetchBookings();
    }
    if (!ref.read(cargoShippingProvider).isLoading) {
      ref.read(cargoShippingProvider.notifier).fetchRecords();
    }
    if (!ref.read(purchaseOrdersProvider).isLoading) {
      ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditCertificateDialog([CargoInsuranceModel? certificateToEdit]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CargoInsuranceFormDialog(
        certificateToEdit: certificateToEdit,
        initialImportFileId: widget.initialImportFileId,
      ),
    );
  }

  void _showViewCertificateDialog(CargoInsuranceModel certificate) {
    showDialog(
      context: context,
      builder: (context) => CargoInsuranceDetailsDialog(certificate: certificate),
    );
  }

  void _showPolicyCardDialog(CargoInsuranceModel certificate) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: InsurancePolicyCard(
            policy: certificate,
            onViewDetails: () {
              Navigator.of(context).pop();
              _showViewCertificateDialog(certificate);
            },
            onFileClaim: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (ctx) => DamageClaimDialog(
                  importFileId: certificate.importFileId ?? widget.initialImportFileId,
                  initialPolicyNumber: certificate.policyNumber ?? certificate.certificateCode,
                  initialCurrency: certificate.currency,
                ),
              );
            },
            onPrint: () {
              Navigator.of(context).pop();
              _showViewCertificateDialog(certificate);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final certificatesAsync = ref.watch(cargoInsuranceProvider);

    if (widget.isEmbedded) {
      return _buildMainContent(certificatesAsync);
    }

    final tabs = [
      VerticalNavTabItem(
        icon: Icons.shield_rounded,
        titleEn: 'Certificates Registry',
        titleAr: l.insuranceTabCertificatesRegistry,
      ),
      VerticalNavTabItem(
        icon: Icons.add_moderator_rounded,
        titleEn: 'New Certificate',
        titleAr: l.insuranceTabNewCertificate,
      ),
    ];

    return VerticalStageScaffold(
      stageCode: 'PHASE-3-INS',
      titleEn: 'Marine & Cargo Insurance Engine',
      titleAr: l.insuranceScreenTitle,
      headerIcon: Icons.security_rounded,
      headerColor: AppTheme.cobalt,
      tabs: tabs,
      selectedIndex: 0,
      onTabSelected: (index) {
        if (index == 1) {
          _showAddEditCertificateDialog();
        }
      },
      selectedImportFileId: widget.initialImportFileId,
      onShipmentStatusChanged: _refreshData,
      headerActions: [
        AppButton(
          label: isAr ? 'مطالبة هوالك' : 'Damage Claim',
          icon: Icons.assignment_late_outlined,
          variant: AppButtonVariant.danger,
          size: AppButtonSize.small,
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => DamageClaimDialog(importFileId: widget.initialImportFileId),
          ),
        ),
        const SizedBox(width: 8),
        AppButton(
          label: l.insuranceAiExtractorBtn,
          icon: Icons.auto_awesome_rounded,
          variant: AppButtonVariant.success,
          size: AppButtonSize.small,
          onPressed: () => UniversalEntityExtractorDialog.showInsuranceCompanyExtractor(
            context,
            onSaved: () => ref.read(partnersProvider.notifier).fetchPartners(),
          ),
        ),
        const SizedBox(width: 8),
        SmartUploadButton(
          module: SmartUploadModule.cargoShipping,
          label: l.insuranceSmartUploadBtn,
          onDataExtracted: (result) {
            final fields = result.extractedFields;
            ScaffoldMessenger.of(context).showSnackBar(
              AppTheme.snackBar(context, l.insuranceExtractedSnackbar(
                          fields['bl_number'] ?? fields['policy_number'] ?? l.insuranceExtractedDone,
                        ), severity: AppSeverity.success, duration: const Duration(seconds: 4)),
            );
            _showAddEditCertificateDialog();
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.refresh, color: AppTheme.white.withValues(alpha: 0.70)),
          tooltip: l.insuranceRefreshTooltip,
          onPressed: _refreshData,
        ),
      ],
      body: _buildMainContent(certificatesAsync),
    );
  }

  Widget _buildMainContent(AsyncValue<List<CargoInsuranceModel>> certificatesAsync) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return certificatesAsync.when(
      loading: () => const AppLoadingState(),
      error: (err, _) => AppErrorState(
        message: l.insuranceFetchError(ApiErrorText.of(l, err)),
        onRetry: _refreshData,
      ),
      data: (certificates) {
        final totalCount = certificates.length;
        final issuedCount = certificates.where((c) => c.status == 'ISSUED').length;
        final totalInsuredValue = certificates.fold<double>(0.0, (sum, c) => sum + c.insuredValue);
        final totalPremiumsPaid = certificates.fold<double>(0.0, (sum, c) => sum + c.totalPayablePremium);

        final query = _searchController.text.trim().toLowerCase();
        final filteredCertificates = certificates.where((c) {
          if (!_showInactive && !c.isActive) return false;
          if (_showInactive && c.isActive) return false;
          if (_selectedStatusFilter != 'All' && c.status != _selectedStatusFilter) return false;
          if (query.isNotEmpty) {
            final code = c.certificateCode.toLowerCase();
            final pol = (c.policyNumber ?? '').toLowerCase();
            final entity = c.insuredEntityName.toLowerCase();
            final carrier = (c.carrierName ?? '').toLowerCase();
            final shipmentCode = c.importFileId != null ? 'IMP-${c.importFileId}' : '';
            final shipmentTitle = c.importFileId != null
                ? DisplayNameResolver.resolveShipmentTitleByCode(shipmentCode, shipments: importFiles, isArabic: isAr).toLowerCase()
                : '';
            final file = c.importFileId != null ? 'file #${c.importFileId} $shipmentCode $shipmentTitle' : '';
            final ports = '${c.portOfLoading} ${c.portOfDischarge}'.toLowerCase();
            if (!code.contains(query) &&
                !pol.contains(query) &&
                !entity.contains(query) &&
                !carrier.contains(query) &&
                !file.contains(query) &&
                !ports.contains(query)) {
              return false;
            }
          }
          return true;
        }).toList();

        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Metric strip (values already loaded) ─────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: CcUi.metrics([
                  MetricCardData(
                    title: l.insuranceKpiTotalPolicies,
                    value: '$totalCount',
                    icon: Icons.shield_rounded,
                    color: AppTheme.cobalt,
                  ),
                  MetricCardData(
                    title: l.insuranceKpiIssuedValid,
                    value: '$issuedCount',
                    icon: Icons.check_circle_rounded,
                    color: AppTheme.emerald,
                  ),
                  MetricCardData(
                    title: l.insuranceKpiTotalInsured,
                    value: '\$${totalInsuredValue.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppTheme.orange,
                  ),
                  MetricCardData(
                    title: l.insuranceKpiTotalPremiums,
                    value: '\$${totalPremiumsPaid.toStringAsFixed(0)}',
                    icon: Icons.payments_rounded,
                    color: AppTheme.charcoal,
                  ),
                ]),
              ),

              // ─── Actions & export toolbar ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsetsDirectional.all(10),
                  decoration: AppTheme.toolbarDecorationOf(context),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CcUi.fit(AppButton(
                        label: isAr ? 'مطالبة هوالك' : 'Damage Claim',
                        icon: Icons.assignment_late_outlined,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.small,
                        onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => DamageClaimDialog(importFileId: widget.initialImportFileId),
                        ),
                      )),
                      CcUi.fit(AppButton(
                        label: l.insuranceNewCertificateBtn,
                        icon: Icons.add_moderator_rounded,
                        size: AppButtonSize.small,
                        onPressed: () => _showAddEditCertificateDialog(),
                      )),
                      CcUi.fit(AppButton(
                        label: l.insuranceRefreshRegistryBtn,
                        icon: Icons.refresh_rounded,
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.small,
                        onPressed: _refreshData,
                      )),
                      CcUi.fit(AppButton(
                        label: l.insuranceExportTsvBtn,
                        icon: Icons.table_chart_outlined,
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.small,
                        onPressed: () => CargoInsuranceExportService.saveCertificatesTsvToFile(
                          context,
                          filteredCertificates,
                          shipments: importFiles,
                        ),
                      )),
                      CcUi.fit(AppButton(
                        label: l.insuranceExportExcelBtn,
                        icon: Icons.table_chart,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.small,
                        onPressed: () => CargoInsuranceExportService.saveCertificatesCsvToFile(
                          context,
                          filteredCertificates,
                          shipments: importFiles,
                        ),
                      )),
                      CcUi.fit(AppButton(
                        label: l.insurancePrintPdfBtn,
                        icon: Icons.picture_as_pdf,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.small,
                        onPressed: () => CargoInsuranceExportService.printOrSaveCertificatesPdf(
                          context,
                          filteredCertificates,
                          shipments: importFiles,
                        ),
                      )),
                      CcUi.fit(AppButton(
                        label: l.shipmentUpdateBtnSavePdf,
                        icon: Icons.save_alt_rounded,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () => CargoInsuranceExportService.printOrSaveCertificatesPdf(
                          context,
                          filteredCertificates,
                          shipments: importFiles,
                          save: true,
                        ),
                      )),
                      CcUi.fit(AppButton(
                        label: l.insuranceCopyDossierBtn,
                        icon: Icons.copy_all_rounded,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.small,
                        onPressed: () => CargoInsuranceExportService.copyDossierToClipboard(
                          context,
                          filteredCertificates,
                          shipments: importFiles,
                        ),
                      )),
                    ],
                  ),
                ),
              ),

              // ─── Data Actions Toolbar ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: MasterDataToolbarWidget(
                  moduleEndpoint: 'cargo-insurance',
                  title: 'Cargo_Insurance_Certificates',
                  onRefreshNeeded: _refreshData,
                ),
              ),

              // ─── Search & Filter Bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                  decoration: AppTheme.cardDecorationOf(context),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 260, maxWidth: 420),
                        child: AppSearchField(
                          controller: _searchController,
                          hint: l.insuranceSearchHint,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildStatusFilterChip('All', l.insuranceFilterAll),
                          _buildStatusFilterChip('ISSUED', l.insuranceFilterIssued, AppTheme.emerald),
                          _buildStatusFilterChip('DRAFT', l.insuranceFilterDraft, AppTheme.orange),
                          _buildStatusFilterChip('CANCELLED', l.insuranceFilterCancelled, AppTheme.crimson),
                        ],
                      ),
                      FilterChip(
                        avatar: Icon(
                          _showInactive ? Icons.visibility_off : Icons.visibility,
                          size: 16,
                          color: _showInactive ? AppTheme.crimson : AppTheme.textMutedOf(context),
                        ),
                        label: Text(
                          _showInactive ? l.insuranceShowDeleted : l.insuranceHideDeleted,
                          style: TextStyle(
                            fontSize: 12,
                            color: _showInactive ? AppTheme.crimson : AppTheme.textSecondaryOf(context),
                            fontWeight: _showInactive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: _showInactive,
                        selectedColor: AppTheme.crimson.withValues(alpha: 0.12),
                        checkmarkColor: AppTheme.crimson,
                        onSelected: (val) => setState(() => _showInactive = val),
                      ),
                      AppStatusBadge(
                        label: '${filteredCertificates.length}',
                        severity: AppSeverity.info,
                        size: AppStatusBadgeSize.small,
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Data Table ───────────────────────────────────────────────────
              Expanded(
                child: filteredCertificates.isEmpty
                    ? AppEmptyState(
                        message: _searchController.text.isNotEmpty || _selectedStatusFilter != 'All'
                            ? l.insuranceNoMatchingFound
                            : l.insuranceNoDataFound,
                        icon: Icons.shield_outlined,
                        actionLabel: l.insuranceNewCertificateBtn,
                        onAction: () => _showAddEditCertificateDialog(),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
                        child: InsuranceCertificatesTable(
                          certificates: filteredCertificates,
                          importFiles: importFiles,
                          isArabic: isAr,
                          onView: _showViewCertificateDialog,
                          onViewPolicyCard: _showPolicyCardDialog,
                          onFileClaim: (cert) => showDialog(
                            context: context,
                            builder: (ctx) => DamageClaimDialog(
                              importFileId: cert.importFileId ?? widget.initialImportFileId,
                              initialPolicyNumber: cert.policyNumber ?? cert.certificateCode,
                              initialCurrency: cert.currency,
                            ),
                          ),
                          onEdit: _showAddEditCertificateDialog,
                          onDelete: _confirmDeleteCertificate,
                          onIssue: _confirmIssueCertificate,
                        ),
                      ),
              ),
              _buildLoadMoreFooter(filteredCertificates.length),
            ],
          ),
        );
      },
    );
  }


  bool _isLoadingMore = false;

  /// "Load more" bar shown while the server holds more certificates than loaded (FE-10).
  Widget _buildLoadMoreFooter(int visibleCount) {
    final notifier = ref.read(cargoInsuranceProvider.notifier);
    if (!notifier.hasMore) return const SizedBox.shrink();
    final l = context.l10n;
    final loaded = ref.read(cargoInsuranceProvider).valueOrNull?.length ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surfaceOf(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l.insuranceLoadedOfTotal(loaded, notifier.total), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          AppButton(
            label: l.insuranceLoadMoreBtn,
            icon: Icons.expand_more_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            isLoading: _isLoadingMore,
            onPressed: _isLoadingMore
                ? null
                : () async {
                    setState(() => _isLoadingMore = true);
                    try {
                      await notifier.loadMore();
                    } finally {
                      if (mounted) setState(() => _isLoadingMore = false);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String status, String label, [Color? activeColor]) {
    final isSelected = _selectedStatusFilter == status;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.white : AppTheme.textPrimaryOf(context),
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor ?? AppTheme.cobalt,
      checkmarkColor: AppTheme.white,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatusFilter = status);
        }
      },
    );
  }

  Future<void> _confirmIssueCertificate(CargoInsuranceModel cert) async {
    final l = context.l10n;
    final confirm = await AppConfirmDialog.show(
      context,
      title: l.insuranceConfirmIssueTitle,
      message: l.insuranceConfirmIssueMsg(cert.certificateCode),
      confirmLabel: l.insuranceConfirmIssueBtn,
      cancelLabel: l.cancel,
      confirmVariant: AppButtonVariant.success,
      icon: Icons.verified_rounded,
    );
    if (confirm) {
      try {
        await ref.read(cargoInsuranceProvider.notifier).issueCertificate(cert.certificateId);
        ref.invalidate(importFilesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, l.insuranceIssueSuccessMsg, severity: AppSeverity.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteCertificate(CargoInsuranceModel cert) async {
    final l = context.l10n;
    final confirm = await AppConfirmDialog.show(
      context,
      title: l.insuranceConfirmDeleteTitle,
      message: l.insuranceConfirmDeleteMsg,
      confirmLabel: l.insuranceDeleteBtn,
      cancelLabel: l.cancel,
      confirmVariant: AppButtonVariant.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (confirm) {
      try {
        await ref.read(cargoInsuranceProvider.notifier).deleteCertificate(cert.certificateId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(context, ApiErrorText.of(l, e), severity: AppSeverity.danger),
          );
        }
      }
    }
  }
}
