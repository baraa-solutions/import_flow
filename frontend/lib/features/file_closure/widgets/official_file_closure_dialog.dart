import 'package:frontend/core/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/file_closure_model.dart';
import '../providers/file_closure_provider.dart';
import '../../warehouse_receiving/widgets/ops_ui_kit.dart';
import '../../experience_guide/widgets/add_guide_entry_dialog.dart';

/// The six audit pillars shown in the pre-closure strip, read from the server checklist.
/// A pillar the server did not report counts as NOT passed (plan FE-07).
class ClosurePillars {
  final bool customs;
  final bool warehouse;
  final bool landedCost;
  final bool dossier;
  final bool emptyContainers;
  final bool tasks;

  const ClosurePillars({
    required this.customs,
    required this.warehouse,
    required this.landedCost,
    required this.dossier,
    required this.emptyContainers,
    required this.tasks,
  });

  factory ClosurePillars.fromStatus(Map<String, bool> status) => ClosurePillars(
        customs: status['customs_cleared'] ?? false,
        warehouse: status['warehouse_received'] ?? false,
        landedCost: status['landed_cost_settled'] ?? false,
        dossier: status['dossier_exported'] ?? false,
        emptyContainers: status['empty_containers_returned'] ?? false,
        tasks: status['tasks_closed'] ?? false,
      );
}

/// Desktop-oriented modal dialog for CLO-04 Official File Closure & Digital Archive.
///
/// The server evaluates the closure gate (precheck) and re-evaluates it on close: this
/// dialog only DISPLAYS the server checklist and never sends user-edited flags as truth.
class OfficialFileClosureDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const OfficialFileClosureDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ImportFileModel file,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OfficialFileClosureDialog(file: file),
    );
  }

  @override
  ConsumerState<OfficialFileClosureDialog> createState() => _OfficialFileClosureDialogState();
}

class _OfficialFileClosureDialogState extends ConsumerState<OfficialFileClosureDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _auditorController;
  late final TextEditingController _archiveLocationController;
  late final TextEditingController _notesController;

  bool _isLoading = true;
  bool _isSubmitting = false;
  Object? _loadError;
  ClosurePrecheckResponseModel? _precheck;
  // Set after a successful close: the certificate can only be exported from this point.
  OfficialClosureCertificateResponseModel? _certificate;

  ClosurePillars get _pillars => ClosurePillars.fromStatus(_precheck?.checklistStatus ?? const {});

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _auditorController = TextEditingController(text: user?.username ?? '');
    _archiveLocationController = TextEditingController();
    _notesController = TextEditingController();
    _loadPrecheck();
  }

  @override
  void dispose() {
    _auditorController.dispose();
    _archiveLocationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPrecheck() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final precheck = await ref.read(fileClosureProvider.notifier).fetchClosurePrecheck(widget.file.importFileId);
      if (!mounted) return;
      setState(() {
        _precheck = precheck;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e;
      });
    }
  }

  Future<void> _handleExportCertificate() async {
    final cert = _certificate;
    if (cert == null) return;
    final l10n = context.l10n;
    final pre = _precheck;
    final pillars = _pillars;
    String yn(bool ok, String yes, String no) => ok ? yes : no;
    const rule = '================================================================================';
    const thin = '--------------------------------------------------------------------------------';

    final notes = cert.archivalNotes?.trim() ?? '';
    final text = StringBuffer()
      ..writeln(rule)
      ..writeln(l10n.closureCertTitle)
      ..writeln(rule)
      ..writeln('${l10n.closureCertNumber}: ${cert.closureCode}')
      ..writeln('${l10n.closureCertIssuedAt}: ${cert.closedAt.isNotEmpty ? cert.closedAt : DateTime.now().toIso8601String()}')
      ..writeln('${l10n.closureCertFileCode}: ${cert.importFileCode}')
      ..writeln('${l10n.closureCertCompany}: ${cert.companyName}')
      ..writeln('${l10n.closureCertSupplier}: ${cert.supplierName}')
      ..writeln('${l10n.closureCertAuditor}: ${cert.auditorName}')
      ..writeln('${l10n.closureCertLocation}: ${cert.archiveLocation}')
      ..writeln(thin)
      ..writeln(l10n.closureCertPillarsHeader)
      ..writeln('1. ${l10n.closurePillarCustoms}: ${yn(pillars.customs, l10n.closureCertOk, l10n.closureCertNotOk)}')
      ..writeln('2. ${l10n.closurePillarWarehouse}: ${yn(pillars.warehouse, l10n.closureCertOk, l10n.closureCertNotOk)}')
      ..writeln('3. ${l10n.closurePillarLandedCost}: ${yn(pillars.landedCost, l10n.closureCertOk, l10n.closureCertNotOk)}');
    if (pre != null) {
      text
        ..writeln('   - ${l10n.closureCertTotalCost}: ${pre.actualLandedCostEgp.toStringAsFixed(2)} EGP')
        ..writeln('   - ${l10n.closureCertMarkup}: ${pre.actualMarkupFactor != null ? "${pre.actualMarkupFactor!.toStringAsFixed(3)}x" : "—"}');
    }
    text
      ..writeln('4. ${l10n.closurePillarDossier}: ${yn(pillars.dossier, l10n.closureCertOk, l10n.closureCertNotOk)}')
      ..writeln('5. ${l10n.closurePillarContainers}: ${yn(pillars.emptyContainers, l10n.closureCertOk, l10n.closureCertNotOk)}')
      ..writeln('6. ${l10n.closurePillarTasks}: ${yn(pillars.tasks, l10n.closureCertOk, l10n.closureCertNotOk)}')
      ..writeln(thin)
      ..writeln(l10n.closureCertNotesHeader)
      ..writeln(notes.isNotEmpty ? notes : l10n.closureCertNoNotes)
      ..writeln(rule)
      ..writeln('${l10n.closureCertStatusLine}: ${cert.status} (${cert.progressPercent.toStringAsFixed(0)}%)');

    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: utf8.encode(text.toString()),
      stageName: 'Closure Certificate',
      importFileNameOrCode: cert.importFileCode.isNotEmpty ? cert.importFileCode : widget.file.importFileCode,
      extension: 'txt',
      customDialogTitle: l10n.closureCertSaveTitle,
      showNotification: true,
    );
  }

  Future<void> _handleConfirmClosure() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_precheck != null && !_precheck!.canClose) {
      messenger.showSnackBar(
        AppTheme.snackBar(context, l10n.closureCannotCloseSnack),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // The checklist sent is the SERVER's own evaluation, kept for the record only;
      // the server re-runs the gate and rejects the close when it fails.
      final payload = {
        'import_file_id': widget.file.importFileId,
        'auditor_name': _auditorController.text.trim(),
        'archive_location': _archiveLocationController.text.trim(),
        'archival_notes': _notesController.text.trim(),
        'closure_checklist': ClosureChecklistModel.fromStatusMap(_precheck?.checklistStatus ?? const {}).toJson(),
        'is_draft': false,
      };

      final certificate = await ref.read(fileClosureProvider.notifier).officialCloseImportFile(payload);

      if (!mounted) return;
      setState(() {
        _certificate = certificate;
        _isSubmitting = false;
      });
      messenger.showSnackBar(
        AppTheme.snackBar(context, l10n.closureOfficialSuccess(certificate.importFileCode, certificate.closureCode)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        AppTheme.snackBar(context, ApiErrorText.of(l10n, e)),
      );
    }
  }

  void _openLessonDialog() {
    // The dialog is still mounted here (it shows the closed state), so its context is valid.
    showDialog(
      context: context,
      builder: (dCtx) => AddGuideEntryDialog(
        initialSupplier: widget.file.supplierName,
        initialHsCode: widget.file.hsCode,
        initialCategory: widget.file.productCategory,
        initialDestinationPort: widget.file.portOfDischarge,
        initialIncoterm: widget.file.incotermCode,
        initialImportFileReference: widget.file.importFileCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppTheme.isDark(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: (MediaQuery.of(context).size.width - 32).clamp(320.0, 860.0),
        constraints: BoxConstraints(maxHeight: (MediaQuery.of(context).size.height - 48).clamp(360.0, 740.0)),
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Expanded(
              child: _certificate != null
                  ? _buildClosedView()
                  : _isLoading
                      ? OpsLoadingView(message: l10n.closureLoadingPillars)
                      : _loadError != null
                          ? _buildErrorView()
                          : _buildMainContent(isDark),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildActionsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.flatEmerald.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_rounded, color: AppTheme.flatEmerald, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.closureDialogTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                l10n.closureDialogSubtitle(
                  widget.file.importFileCode,
                  widget.file.supplierName.isNotEmpty ? widget.file.supplierName : '-',
                  widget.file.status,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(_certificate != null),
          icon: const Icon(Icons.close),
          tooltip: l10n.closureCloseTooltip,
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OpsStateView.error(
            message: l10n.closurePrecheckFailed(ApiErrorText.of(l10n, _loadError)),
          ),
          AppButton(
            key: const Key('closureRetryPrecheckBtn'),
            label: l10n.closureRetryBtn,
            icon: Icons.refresh,
            onPressed: _loadPrecheck,
          ),
        ],
      ),
    );
  }

  Widget _buildClosedView() {
    final l10n = context.l10n;
    final cert = _certificate!;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.emerald, size: 56),
            const SizedBox(height: 12),
            Text(
              l10n.closureOfficialSuccess(cert.importFileCode, cert.closureCode),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                AppButton(
                  key: const Key('exportClosureCertificateBtn'),
                  label: l10n.closureExportCertificateBtn,
                  icon: Icons.download_rounded,
                  onPressed: _handleExportCertificate,
                ),
                AppButton(
                  key: const Key('closureDocumentLessonBtn'),
                  label: l10n.closureLessonBtn,
                  variant: AppButtonVariant.ghost,
                  icon: Icons.add_comment_outlined,
                  onPressed: _openLessonDialog,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.closureLessonPrompt, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    final l10n = context.l10n;
    final precheck = _precheck!;
    final blocking = precheck.blockingTexts(l10n);
    final warnings = precheck.warningTexts(l10n);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSixPillarsStrip(),
            const SizedBox(height: 14),
            if (blocking.isNotEmpty) ...[
              _buildAlertBox(title: l10n.closureBlockingTitle, items: blocking, isError: true),
              const SizedBox(height: 12),
            ],
            if (warnings.isNotEmpty) ...[
              _buildAlertBox(title: l10n.closureWarningsTitle, items: warnings, isError: false),
              const SizedBox(height: 12),
            ],
            _buildCertificateSummaryCard(precheck),
            const SizedBox(height: 14),
            _buildArchivalFormFields(),
          ],
        ),
      ),
    );
  }

  Widget _buildSixPillarsStrip() {
    final l10n = context.l10n;
    final p = _pillars;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded, size: 18, color: AppTheme.flatCobalt),
              const SizedBox(width: 6),
              Text(l10n.closurePillarsHeader, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillarBadge('1. ${l10n.closurePillarCustoms}', p.customs, Icons.local_police_outlined),
              _pillarBadge('2. ${l10n.closurePillarWarehouse}', p.warehouse, Icons.warehouse_outlined),
              _pillarBadge('3. ${l10n.closurePillarLandedCost}', p.landedCost, Icons.account_balance_wallet_outlined),
              _pillarBadge('4. ${l10n.closurePillarDossier}', p.dossier, Icons.description_outlined),
              _pillarBadge('5. ${l10n.closurePillarContainers}', p.emptyContainers, Icons.directions_boat_outlined),
              _pillarBadge('6. ${l10n.closurePillarTasks}', p.tasks, Icons.task_alt_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillarBadge(String label, bool isOk, IconData icon) {
    return OpsStatusChip(
      label: label,
      severity: isOk ? AppSeverity.success : AppSeverity.danger,
      icon: isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
    );
  }

  Widget _buildAlertBox({
    required String title,
    required List<String> items,
    required bool isError,
  }) {
    final color = isError ? AppTheme.flatCrimson : AppTheme.flatOrange;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 18, top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      it,
                      style: TextStyle(fontSize: 11.5, color: isError ? AppTheme.flatCrimson : AppTheme.textPrimaryOf(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateSummaryCard(ClosurePrecheckResponseModel precheck) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.flatCobalt.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.flatCobalt.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              const Icon(Icons.card_membership_rounded, size: 18, color: AppTheme.flatCobalt),
              Text(l10n.closureCertPreviewLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.flatCobalt, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  precheck.certificateCodePreview,
                  style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.closureLandedCostLine(
              precheck.actualLandedCostEgp.toStringAsFixed(2),
              precheck.actualMarkupFactor != null
                  ? precheck.actualMarkupFactor!.toStringAsFixed(3)
                  : '—',
            ).replaceAll('—x', '—'),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(l10n.closureExportAfterCloseHint, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryOf(context))),
        ],
      ),
    );
  }

  Widget _buildArchivalFormFields() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.closureArchivalSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('closureAuditorNameField'),
                controller: _auditorController,
                decoration: InputDecoration(
                  labelText: l10n.closureAuditorLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? l10n.closureAuditorRequired : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: const Key('closureArchiveLocationField'),
                controller: _archiveLocationController,
                decoration: InputDecoration(
                  labelText: l10n.closureArchiveLocationLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? l10n.closureArchiveLocationRequired : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const Key('closureArchivalNotesField'),
          controller: _notesController,
          decoration: InputDecoration(
            labelText: l10n.closureNotesLabel,
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildActionsRow() {
    final l10n = context.l10n;
    if (_certificate != null) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: AppButton(
          key: const Key('closureDoneBtn'),
          label: l10n.closureDoneBtn,
          variant: AppButtonVariant.success,
          icon: Icons.check,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      );
    }
    final canClose = _precheck?.canClose ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppButton(
          key: const Key('cancelClosureBtn'),
          label: l10n.cancel,
          icon: Icons.close,
          variant: AppButtonVariant.secondary,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton(
          key: const Key('confirmOfficialClosureBtn'),
          label: _isSubmitting
              ? l10n.closureSubmittingLabel
              : canClose
                  ? l10n.closureConfirmBtn
                  : l10n.closureUnavailableBtn,
          variant: AppButtonVariant.success,
          icon: Icons.lock_person_rounded,
          isLoading: _isSubmitting,
          onPressed: (_isSubmitting || !canClose) ? null : _handleConfirmClosure,
        ),
      ],
    );
  }
}
