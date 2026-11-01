import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/comprehensive_dossier_model.dart';
import '../services/comprehensive_dossier_service.dart';
import 'dossier/comprehensive_dossier_confirm_form.dart';
import 'dossier/comprehensive_dossier_header.dart';
import 'dossier/comprehensive_dossier_kpis.dart';
import 'dossier/comprehensive_dossier_sections.dart';
import 'dossier/comprehensive_dossier_toolbar.dart';

/// Desktop-oriented interactive modal dialog for CLO-03 Comprehensive Shipment Dossier Export.
/// Provides 10-phase readiness KPIs, multi-format export buttons (PDF, Excel, TSV, Clipboard),
/// and confirmation workflow with downstream TSK-0904 dispatch.
class ComprehensiveDossierExportDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const ComprehensiveDossierExportDialog({
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
      builder: (ctx) => ComprehensiveDossierExportDialog(file: file),
    );
  }

  @override
  ConsumerState<ComprehensiveDossierExportDialog> createState() =>
      _ComprehensiveDossierExportDialogState();
}

class _ComprehensiveDossierExportDialogState
    extends ConsumerState<ComprehensiveDossierExportDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  ComprehensiveShipmentDossierModel? _dossier;

  final _formKey = GlobalKey<FormState>();
  final _exportedByController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedFormat = 'PDF & Excel Full Bundle';

  final List<String> _formatOptions = [
    'PDF & Excel Full Bundle',
    'PDF Official Dossier (A4 Cairo)',
    'Excel Raw Ledger (CSV UTF-8)',
    'TSV Text Data Export',
  ];

  @override
  void initState() {
    super.initState();
    _exportedByController.text = ref.read(authProvider).user?.fullName ?? '';
    _loadDossier();
  }

  @override
  void dispose() {
    _exportedByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDossier() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(comprehensiveDossierServiceProvider);
      final data = await service.fetchComprehensiveDossier(widget.file.importFileId);
      if (mounted) {
        setState(() {
          _dossier = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleConfirmExport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final service = ref.read(comprehensiveDossierServiceProvider);
      final req = DossierExportConfirmRequestModel(
        importFileId: widget.file.importFileId,
        exportedBy: _exportedByController.text.trim(),
        exportFormat: _selectedFormat,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      final resp = await service.confirmDossierExport(req);
      ref.invalidate(importFilesProvider);

      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(
          AppTheme.snackBar(context, resp.message),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final l10n = AppLocalizations.of(context);
        final msg = ApiErrorText.of(l10n, e, fallback: 'خطأ أثناء تأكيد التصدير: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, msg),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: SelectionArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ComprehensiveDossierHeader(
                file: widget.file,
                onOpenFullScreen: () {
                  Navigator.of(context).pop();
                  ref.read(selectedComprehensiveReportFileIdProvider.notifier).state = widget.file.importFileId;
                  selectNavigationIndex(ref, 47, tabTitle: 'تقرير الشحنة الشامل المدمج');
                },
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppTheme.flatCobalt),
                            SizedBox(height: 12),
                            Text('جاري تجميع بيانات الملف الاستيرادي الشامل من كافة المراحل...'),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: AppTheme.flatCrimson),
                                  const SizedBox(height: 12),
                                  Text(
                                    'تعذر جلب بيانات الملف الشامل: $_errorMessage',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppTheme.flatCrimson),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _loadDossier,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('إعادة المحاولة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.flatCobalt,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _buildDialogBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogBody() {
    final dossier = _dossier!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ComprehensiveDossierKpiStrip(dossier: dossier),
          const SizedBox(height: 16),
          ComprehensiveDossierToolbar(file: widget.file, dossier: dossier),
          const SizedBox(height: 16),
          ComprehensiveDossierSectionsBreakdown(dossier: dossier),
          const SizedBox(height: 16),
          ComprehensiveDossierConfirmForm(
            formKey: _formKey,
            exportedByController: _exportedByController,
            notesController: _notesController,
            selectedFormat: _selectedFormat,
            formatOptions: _formatOptions,
            isSubmitting: _isSubmitting,
            onFormatChanged: (val) {
              if (val != null) setState(() => _selectedFormat = val);
            },
            onConfirmExport: _handleConfirmExport,
          ),
        ],
      ),
    );
  }
}
