import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../freight_booking/providers/freight_booking_provider.dart';
import '../../../import_companies/providers/import_companies_provider.dart';
import '../../../import_documentation/providers/import_documentation_provider.dart';
import '../../../import_files/providers/import_files_provider.dart';
import '../../../suppliers/providers/suppliers_provider.dart';
import '../../models/cargox_model.dart';
import '../../providers/cargox_provider.dart';
import 'cargox_attached_docs_table.dart';
import 'cargox_envelope_identity_form.dart';

/// Form coordinator view for creating & signing CargoX envelopes.
class CargoXCreateEnvelopeView extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final void Function(CargoXEnvelopeModel created, bool isDraft) onEnvelopeCreated;

  const CargoXCreateEnvelopeView({
    super.key,
    this.initialImportFileId,
    required this.onEnvelopeCreated,
  });

  @override
  ConsumerState<CargoXCreateEnvelopeView> createState() => _CargoXCreateEnvelopeViewState();
}

class _CargoXCreateEnvelopeViewState extends ConsumerState<CargoXCreateEnvelopeView> {
  final _envelopeFormKey = GlobalKey<FormState>();
  final TextEditingController _acidNumberCtrl = TextEditingController();
  final TextEditingController _importerNameCtrl = TextEditingController();
  final TextEditingController _importerTaxCtrl = TextEditingController();
  final TextEditingController _supplierNameCtrl = TextEditingController();
  final TextEditingController _supplierCargoXIdCtrl = TextEditingController();
  final TextEditingController _blNumberCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  int? _selectedImportFileId;
  int? _selectedCompanyId;
  int? _selectedSupplierId;
  bool _isSavingEnvelope = false;

  List<Map<String, dynamic>> _attachedDocs = [];

  @override
  void initState() {
    super.initState();
    _selectedImportFileId = widget.initialImportFileId;
    _initDefaultAttachedDocs();

    Future.microtask(() {
      if (_selectedImportFileId != null) {
        _onImportFileSelected(_selectedImportFileId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CargoXCreateEnvelopeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImportFileId != null && widget.initialImportFileId != _selectedImportFileId) {
      setState(() => _selectedImportFileId = widget.initialImportFileId);
      _onImportFileSelected(widget.initialImportFileId);
    }
  }

  @override
  void dispose() {
    _acidNumberCtrl.dispose();
    _importerNameCtrl.dispose();
    _importerTaxCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierCargoXIdCtrl.dispose();
    _blNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _initDefaultAttachedDocs() {
    _attachedDocs = [
      {
        'doc_type': 'Commercial Invoice',
        'doc_number': 'INV-2026-FINAL',
        'file_name': 'Commercial_Invoice_Final.pdf',
        'file_size_kb': 420.0,
        'is_mandatory': true,
        'verified_against_acid': true,
      },
      {
        'doc_type': 'Packing List',
        'doc_number': 'PL-2026-FINAL',
        'file_name': 'Packing_List_Final.pdf',
        'file_size_kb': 310.0,
        'is_mandatory': true,
        'verified_against_acid': true,
      },
      {
        'doc_type': 'Draft B/L',
        'doc_number': 'MEDUST982145',
        'file_name': 'Bill_of_Lading_Official.pdf',
        'file_size_kb': 650.0,
        'is_mandatory': true,
        'verified_against_acid': true,
      },
      {
        'doc_type': 'Certificate of Origin / EUR.1',
        'doc_number': 'COO-EG-9981',
        'file_name': 'Certificate_of_Origin_EUR1.pdf',
        'file_size_kb': 280.0,
        'is_mandatory': false,
        'verified_against_acid': true,
      },
    ];
  }

  void _onImportFileSelected(int? fileId) {
    setState(() => _selectedImportFileId = fileId);
    if (fileId == null) {
      _acidNumberCtrl.clear();
      _importerNameCtrl.clear();
      _importerTaxCtrl.clear();
      _supplierNameCtrl.clear();
      _supplierCargoXIdCtrl.clear();
      _blNumberCtrl.clear();
      return;
    }

    final files = ref.read(importFilesProvider).valueOrNull ?? [];
    final file = files.where((f) => f.importFileId == fileId).firstOrNull;
    if (file == null) return;

    // 1. Auto-populate ACID Number
    _acidNumberCtrl.text = file.acidNumber ?? '';

    // 2. Auto-populate Importer Company
    _selectedCompanyId = file.companyId;
    final companies = ref.read(importCompaniesProvider).valueOrNull ?? [];
    final matchedCompany = companies.where((c) => c.companyId == file.companyId).firstOrNull;
    _importerNameCtrl.text = matchedCompany?.importerName ?? file.companyName;
    if (matchedCompany?.vatId != null && matchedCompany!.vatId.isNotEmpty) {
      _importerTaxCtrl.text = matchedCompany.vatId;
    } else if (matchedCompany?.registrationNumber != null && matchedCompany!.registrationNumber.isNotEmpty) {
      _importerTaxCtrl.text = matchedCompany.registrationNumber;
    }

    // 3. Auto-populate Foreign Exporter (Supplier) & CargoX ID
    final suppliers = ref.read(suppliersProvider).valueOrNull ?? [];
    final matchedSup = suppliers.where((s) => s.supplierId == file.supplierId).firstOrNull;
    if (matchedSup != null) {
      _selectedSupplierId = matchedSup.supplierId;
      _supplierNameCtrl.text = matchedSup.companyName;
      _supplierCargoXIdCtrl.text = (matchedSup.cargoxPlatformId != null && matchedSup.cargoxPlatformId!.trim().isNotEmpty)
          ? matchedSup.cargoxPlatformId!.trim()
          : (matchedSup.foreignExporterId.isNotEmpty
              ? matchedSup.foreignExporterId.trim()
              : 'CX-${matchedSup.supplierCode}');
    } else {
      _supplierNameCtrl.text = file.supplierName;
      _supplierCargoXIdCtrl.text = 'CX-${file.supplierName.replaceAll(RegExp(r'\s+'), '-').toUpperCase()}';
    }

    // 4. Auto-populate B/L Number
    String resolvedBlNumber = '';
    final reviews = ref.read(draftBLReviewsProvider).valueOrNull ?? [];
    final linkedReview = reviews.where((r) => r.importFileId == fileId).firstOrNull;
    if (linkedReview != null) {
      final extractedBl = linkedReview.draftExtractedData?['draft_bl_number'] ??
          linkedReview.draftExtractedData?['bl_number'] ??
          linkedReview.systemDataSnapshot?['draft_bl_number'] ??
          linkedReview.draftBlNumber;
      if (extractedBl != null && extractedBl.toString().trim().isNotEmpty) {
        resolvedBlNumber = extractedBl.toString().trim();
      }
    }

    if (resolvedBlNumber.isEmpty) {
      final bookings = ref.read(freightBookingProvider).valueOrNull ?? [];
      final linkedBooking = bookings.where((b) => b.importFileId == fileId).firstOrNull;
      if (linkedBooking != null) {
        resolvedBlNumber = linkedBooking.bookingConfirmationNo ?? linkedBooking.bookingCode;
      }
    }

    if (resolvedBlNumber.isEmpty && file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      resolvedBlNumber = file.customFileNumber!;
    }

    _blNumberCtrl.text = resolvedBlNumber;

    // 5. Update Attached Documents references
    final invRef = file.invoicesData.isNotEmpty
        ? file.invoicesData.first.invoiceNo
        : (file.piNumber != null && file.piNumber!.isNotEmpty ? file.piNumber! : 'INV-${file.importFileCode}');

    setState(() {
      _attachedDocs = [
        {
          'doc_type': 'Commercial Invoice',
          'doc_number': invRef,
          'file_name': 'Commercial_Invoice_${file.importFileCode}.pdf',
          'file_size_kb': 420.0,
          'is_mandatory': true,
          'verified_against_acid': true,
        },
        {
          'doc_type': 'Packing List',
          'doc_number': 'PL-${file.importFileCode}',
          'file_name': 'Packing_List_${file.importFileCode}.pdf',
          'file_size_kb': 310.0,
          'is_mandatory': true,
          'verified_against_acid': true,
        },
        {
          'doc_type': 'Draft B/L',
          'doc_number': resolvedBlNumber.isNotEmpty ? resolvedBlNumber : 'BL-${file.importFileCode}',
          'file_name': 'Bill_of_Lading_${file.importFileCode}.pdf',
          'file_size_kb': 650.0,
          'is_mandatory': true,
          'verified_against_acid': true,
        },
        {
          'doc_type': 'Certificate of Origin / EUR.1',
          'doc_number': 'COO-${file.importFileCode}',
          'file_name': 'Certificate_of_Origin_${file.importFileCode}.pdf',
          'file_size_kb': 280.0,
          'is_mandatory': false,
          'verified_against_acid': true,
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _envelopeFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.cobalt.withValues(alpha: 0.12), Colors.blue.shade50],
                  begin: AlignmentDirectional.centerEnd,
                  end: AlignmentDirectional.centerStart,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.cobalt, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.cargoxEnvelopeGenTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.cargoxEnvelopeGenDesc,
                          style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card 1: Main Identification
            CargoXEnvelopeIdentityForm(
              selectedImportFileId: _selectedImportFileId,
              importFiles: importFiles,
              onSelectImportFile: _onImportFileSelected,
              acidNumberCtrl: _acidNumberCtrl,
              blNumberCtrl: _blNumberCtrl,
              importerNameCtrl: _importerNameCtrl,
              supplierNameCtrl: _supplierNameCtrl,
              supplierCargoXIdCtrl: _supplierCargoXIdCtrl,
            ),
            const SizedBox(height: 16),

            // Card 2: Attached Documents Matrix
            CargoXAttachedDocsTable(
              attachedDocs: _attachedDocs,
              onRestoreDefaults: () => setState(() => _initDefaultAttachedDocs()),
              onRemoveDoc: (idx) => setState(() => _attachedDocs.removeAt(idx)),
              onAddDoc: (newDoc) => setState(() => _attachedDocs.add(newDoc)),
            ),
            const SizedBox(height: 20),

            // Submit Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: context.l10n.saveDraft,
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.saveDraft,
                  size: AppButtonSize.large,
                  isLoading: _isSavingEnvelope,
                  onPressed: _isSavingEnvelope ? null : () => _submitCreateEnvelope(isDraft: true),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: context.l10n.cargoxGenerateAndSignEnvelopeBtn,
                  icon: Icons.security,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.large,
                  isLoading: _isSavingEnvelope,
                  onPressed: _isSavingEnvelope ? null : () => _submitCreateEnvelope(isDraft: false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCreateEnvelope({bool isDraft = false}) async {
    if (!isDraft && !_envelopeFormKey.currentState!.validate()) return;
    if (!isDraft && _attachedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.cargoxAtLeastOneDocError,
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    setState(() => _isSavingEnvelope = true);
    try {
      final payload = {
        'import_file_id': _selectedImportFileId,
        'acid_number': _acidNumberCtrl.text.trim().isNotEmpty
            ? _acidNumberCtrl.text.trim()
            : 'DRAFT-${DateTime.now().millisecondsSinceEpoch}',
        'importer_company_id': _selectedCompanyId,
        'importer_company_name': _importerNameCtrl.text.trim(),
        'importer_tax_number': _importerTaxCtrl.text.trim(),
        'supplier_id': _selectedSupplierId,
        'supplier_name': _supplierNameCtrl.text.trim(),
        'supplier_cargox_id': _supplierCargoXIdCtrl.text.trim(),
        'bl_number': _blNumberCtrl.text.trim().isNotEmpty ? _blNumberCtrl.text.trim() : null,
        'notes': _notesCtrl.text.trim(),
        'documents': _attachedDocs,
        'mode': 'MOCK',
        'is_draft': isDraft,
        'status': isDraft ? 'DRAFT' : null,
      };

      final created = await ref.read(cargoxEnvelopesProvider.notifier).createEnvelope(payload);
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        final message = isDraft
            ? (isAr
                ? 'تم حفظ مسودة المظروف بنجاح (${created.envelopeCode})'
                : 'Envelope draft saved successfully (${created.envelopeCode})')
            : context.l10n.cargoxEnvelopeCreatedSuccess(created.envelopeCode);

        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            message,
            severity: isDraft ? AppSeverity.info : AppSeverity.success,
          ),
        );
        widget.onEnvelopeCreated(created, isDraft);
      }
    } catch (e) {
      if (mounted) {
        showErrorDetailsDialog(
          context,
          title: context.l10n.cargoxEnvelopeCreateError,
          error: e,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEnvelope = false);
    }
  }
}
