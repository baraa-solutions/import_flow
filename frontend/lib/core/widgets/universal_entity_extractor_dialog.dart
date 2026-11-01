import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'copyable_data_helper.dart';
import 'entity_extractor/extractor_controllers.dart';
import 'entity_extractor/extractor_finance_inspection_fields.dart';
import 'entity_extractor/extractor_header.dart';
import 'entity_extractor/extractor_logistics_fields.dart';
import 'entity_extractor/extractor_service.dart';
import 'entity_extractor/extractor_supplier_importer_fields.dart';
import 'entity_extractor/extractor_text_input_area.dart';
import 'entity_extractor/extractor_types.dart';

export 'entity_extractor/extractor_types.dart' show EntityTarget;

class UniversalEntityExtractorDialog extends ConsumerStatefulWidget {
  final EntityTarget initialTarget;
  final bool lockTarget;
  final VoidCallback? onSaved;

  const UniversalEntityExtractorDialog({
    super.key,
    this.initialTarget = EntityTarget.supplier,
    this.lockTarget = false,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    EntityTarget initialTarget = EntityTarget.supplier,
    bool lockTarget = false,
    VoidCallback? onSaved,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UniversalEntityExtractorDialog(
        initialTarget: initialTarget,
        lockTarget: lockTarget,
        onSaved: onSaved,
      ),
    );
  }

  static Future<void> showSupplierExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.supplier, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showImporterExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.company, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showCustomsBrokerExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.customsBroker, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showShippingLineExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.shippingLine, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showFreightForwarderExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.freightForwarder, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showInlandTransportExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.inlandTransport, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showInspectionAgencyExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.inspectionAgency, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showInsuranceCompanyExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.insuranceCompany, lockTarget: true, onSaved: onSaved);
  }

  static Future<void> showBankExtractor(BuildContext context, {VoidCallback? onSaved}) {
    return show(context, initialTarget: EntityTarget.bank, lockTarget: true, onSaved: onSaved);
  }

  @override
  ConsumerState<UniversalEntityExtractorDialog> createState() => _UniversalEntityExtractorDialogState();
}

class _UniversalEntityExtractorDialogState extends ConsumerState<UniversalEntityExtractorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ExtractorControllers _controllers = ExtractorControllers();

  late EntityTarget _selectedTarget;
  int _inputModeTab = 0;
  bool _isExtracting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTarget = widget.initialTarget;
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  void _onExtractFromRawText() {
    ExtractorService.extractFromRawText(
      context: context,
      ref: ref,
      controllers: _controllers,
      target: _selectedTarget,
      setExtracting: (val) => setState(() => _isExtracting = val),
      onExtracted: () => setState(() {}),
    );
  }

  void _onPickAndExtractFile() {
    ExtractorService.pickAndExtractFile(
      context: context,
      ref: ref,
      controllers: _controllers,
      target: _selectedTarget,
      setExtracting: (val) => setState(() => _isExtracting = val),
      onExtracted: () => setState(() {}),
    );
  }

  void _onSaveEntity() {
    ExtractorService.saveEntity(
      context: context,
      ref: ref,
      controllers: _controllers,
      target: _selectedTarget,
      formKey: _formKey,
      setSaving: (val) => setState(() => _isSaving = val),
      onSaved: widget.onSaved,
    );
  }

  void _copyExtractedDataSummary(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    CopyHelper.copy(
      context,
      _controllers.buildExtractedSummary(context, _selectedTarget),
      customMessage: isArabic ? 'تم نسخ البيانات المستخرجة بنجاح' : 'Extracted data copied successfully',
    );
  }

  Widget _buildTargetSpecificFields() {
    switch (_selectedTarget) {
      case EntityTarget.supplier:
        return ExtractorSupplierFields(controllers: _controllers);
      case EntityTarget.company:
        return ExtractorImporterFields(controllers: _controllers);
      case EntityTarget.customsBroker:
        return ExtractorCustomsBrokerFields(controllers: _controllers);
      case EntityTarget.shippingLine:
        return ExtractorShippingLineFields(controllers: _controllers);
      case EntityTarget.freightForwarder:
      case EntityTarget.partner:
        return ExtractorFreightForwarderFields(controllers: _controllers);
      case EntityTarget.inlandTransport:
        return ExtractorInlandTransportFields(controllers: _controllers);
      case EntityTarget.inspectionAgency:
        return ExtractorInspectionAgencyFields(controllers: _controllers);
      case EntityTarget.insuranceCompany:
        return ExtractorInsuranceCompanyFields(controllers: _controllers);
      case EntityTarget.bank:
        return ExtractorBankFields(controllers: _controllers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SelectionArea(
        child: Container(
          width: 1080,
          height: 720,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              ExtractorDialogHeader(
                target: _selectedTarget,
                onClose: () => Navigator.of(context).pop(),
              ),
              if (!widget.lockTarget)
                ExtractorTargetSelectorBar(
                  selectedTarget: _selectedTarget,
                  onTargetSelected: (target) => setState(() => _selectedTarget = target),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Side: Input (Raw Text or File Upload)
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: isArabic
                              ? BorderDirectional(start: BorderSide(color: Colors.grey.shade200))
                              : BorderDirectional(end: BorderSide(color: Colors.grey.shade200)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExtractorInputModeSwitcher(
                              selectedIndex: _inputModeTab,
                              onIndexChanged: (idx) => setState(() => _inputModeTab = idx),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _inputModeTab == 0
                                  ? ExtractorRawTextInput(
                                      controller: _controllers.rawTextCtrl,
                                      target: _selectedTarget,
                                    )
                                  : ExtractorFileUploadArea(
                                      selectedFileName: _controllers.selectedFileName,
                                      isExtracting: _isExtracting,
                                      onPickFile: _onPickAndExtractFile,
                                    ),
                            ),
                            const SizedBox(height: 12),
                            ExtractorSmartExtractButton(
                              isExtracting: _isExtracting,
                              onExtract: _inputModeTab == 0 ? _onExtractFromRawText : _onPickAndExtractFile,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right Side: Extracted Structured Form
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExtractorFormHeader(
                                target: _selectedTarget,
                                confidenceScore: _controllers.confidenceScore,
                                onCopy: () => _copyExtractedDataSummary(context),
                              ),
                              const Divider(height: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: _buildTargetSpecificFields(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ExtractorSaveButton(
                                target: _selectedTarget,
                                isSaving: _isSaving,
                                isExtracting: _isExtracting,
                                onSave: _onSaveEntity,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
