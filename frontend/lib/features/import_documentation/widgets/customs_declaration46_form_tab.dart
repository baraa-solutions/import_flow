import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/stored_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/customs_declaration_assessment.dart';
import '../services/customs_declaration46_calculator.dart';
import 'customs_declaration46/declaration46_actions_bar.dart';
import 'customs_declaration46/declaration46_attributes_card.dart';
import 'customs_declaration46/declaration46_calculation_helper.dart';
import 'customs_declaration46/declaration46_exemption_card.dart';
import 'customs_declaration46/declaration46_form_controllers.dart';
import 'customs_declaration46/declaration46_form_service.dart';
import 'customs_declaration46/declaration46_header_card.dart';
import 'customs_declaration46/declaration46_regulatory_card.dart';
import 'customs_declaration46/declaration46_save_delegate.dart';
import 'customs_declaration46/declaration46_variance_reason_card.dart';
import 'form46_figures_panel.dart';
import 'form46_three_column_panel.dart';
import 'form46_variance_bar.dart';
import 'idoc_ui_b.dart';

class CustomsDeclaration46FormTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final CustomsDeclarationAssessment? clonedAssessment;
  final VoidCallback onSaved;
  final VoidCallback onSwitchToRegistry;
  final VoidCallback onOpenSearchAndClone;
  final VoidCallback onRefresh;
  final ValueChanged<bool>? onDirtyChanged;

  const CustomsDeclaration46FormTab({
    super.key,
    this.initialImportFileId,
    this.clonedAssessment,
    required this.onSaved,
    required this.onSwitchToRegistry,
    required this.onOpenSearchAndClone,
    required this.onRefresh,
    this.onDirtyChanged,
  });

  @override
  ConsumerState<CustomsDeclaration46FormTab> createState() => _CustomsDeclaration46FormTabState();
}

class _CustomsDeclaration46FormTabState extends ConsumerState<CustomsDeclaration46FormTab> {
  final _declarationFormKey = GlobalKey<FormState>();
  final _c = Declaration46FormControllers();
  bool _isDirty = false;

  int? _selectedImportFileId;
  DateTime _declarationDate = DateTime.now();
  String? _selectedOffice;
  String? _selectedChannel;

  List<CustomsTariffModel> _matchedTariffs = [];
  bool _hasExemption = false;
  double? _appliedDutyRate;
  List<String> _figuresMissing = const [];
  List<Map<String, dynamic>> _regulatoryApprovals = [];
  bool _isSavingDeclaration = false;
  Form46Figures? _studyFigures;

  String get _miss => context.l10n.idocBMissing;

  void _setDirty(bool dirty) {
    if (_isDirty != dirty && mounted) {
      setState(() => _isDirty = dirty);
      if (widget.onDirtyChanged != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onDirtyChanged?.call(dirty);
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _c.attachListeners(() {
      if (!_isDirty && mounted) _setDirty(true);
    });

    _selectedImportFileId = widget.initialImportFileId;
    if (widget.clonedAssessment != null) {
      _applyClonedAssessment(widget.clonedAssessment!);
    } else if (_selectedImportFileId != null) {
      Future.microtask(() => _onImportFileSelected(_selectedImportFileId));
    }
  }

  @override
  void didUpdateWidget(CustomsDeclaration46FormTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clonedAssessment != oldWidget.clonedAssessment && widget.clonedAssessment != null) {
      _applyClonedAssessment(widget.clonedAssessment!);
    } else if (widget.initialImportFileId != oldWidget.initialImportFileId && widget.initialImportFileId != null) {
      _onImportFileSelected(widget.initialImportFileId);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _applyClonedAssessment(CustomsDeclarationAssessment a) {
    final res = CustomsDeclaration46FormService.loadClonedAssessment(ref, a);
    setState(() {
      if (res.matchedFileId != null) _selectedImportFileId = res.matchedFileId;
      _applyFormData(res.data);
      _c.notesCtrl.text = storedText.idocBCloneDeclNote(a.declarationNo);
    });
  }

  void _applyFormData(Form46LoadedData data) {
    _studyFigures = data.figures;
    _declarationDate = data.declarationDate;
    if (data.selectedOffice != null) _selectedOffice = data.selectedOffice;
    _matchedTariffs = data.matchedTariffs;
    _appliedDutyRate = data.appliedDutyRate;
    _figuresMissing = data.figuresMissing;
    _hasExemption = data.hasExemption;
    _regulatoryApprovals = data.regulatoryApprovals;
    _c.applyFormData(data);
  }

  void _onImportFileSelected(int? fileId) {
    setState(() => _selectedImportFileId = fileId);
    if (fileId == null) {
      _declarationDate = DateTime.now();
      _c.clearForEmptyFile(_declarationDate);
      setState(() {
        _studyFigures = null;
        _matchedTariffs = [];
        _regulatoryApprovals = [];
        _hasExemption = false;
        _appliedDutyRate = null;
        _figuresMissing = const [];
      });
      return;
    }

    final data = CustomsDeclaration46FormService.loadForFile(ref, fileId);
    setState(() => _applyFormData(data));
    _refreshFiguresAtDeclarationDate(fileId, data.declarationDate);
  }

  /// Re-computes the study figures with the customs rate in force on [onDate] (backend history).
  /// Only the computed figures change; the user's other inputs stay.
  Future<void> _refreshFiguresAtDeclarationDate(int fileId, DateTime onDate) async {
    final data = await CustomsDeclaration46FormService.loadForFileAtDeclarationDate(ref, fileId, onDate: onDate);
    if (!mounted || _selectedImportFileId != fileId) return;
    setState(() {
      _studyFigures = data.figures;
      _matchedTariffs = data.matchedTariffs;
      _appliedDutyRate = data.appliedDutyRate;
      _figuresMissing = data.figuresMissing;
      _c.customsValueEgpCtrl.text = data.cifEgp;
      _c.importDutyEgpCtrl.text = data.importDutyEgp;
      _c.vatEgpCtrl.text = data.vatEgp;
      _c.otherFeesEgpCtrl.text = data.otherFeesEgp;
      _c.totalDutyAndTaxesCtrl.text = data.totalDutiesEgp;
      _c.revisedFxRateCtrl.text = data.figures?.exchangeRate?.toStringAsFixed(4) ?? '';
    });
  }

  void _recalculateRevisedEstimate() {
    final res = Declaration46CalculationHelper.calculateRevised(
      fobForeign: _studyFigures?.fobForeign ?? 0.0,
      fxRate: double.tryParse(_c.revisedFxRateCtrl.text) ?? _studyFigures?.exchangeRate ?? 1.0,
      freight: double.tryParse(_c.approvedFreightCtrl.text) ?? 0.0,
      insurance: double.tryParse(_c.actualInsuranceCtrl.text) ?? 0.0,
      discharge: double.tryParse(_c.dischargeExpensesCtrl.text) ?? 0.0,
      newFees: double.tryParse(_c.newCustomsFeesCtrl.text) ?? 0.0,
      dutyRate: _appliedDutyRate ?? _matchedTariffs.firstOrNull?.customsDutyRate ?? 0.0,
      vatRate: _matchedTariffs.firstOrNull?.vatRate ?? 14.0,
      devRate: _matchedTariffs.firstOrNull?.developmentFeeRate ?? 0.0,
      serviceRate: _matchedTariffs.firstOrNull?.customsServiceFeeRate ?? 0.0,
      scheduleTaxRate: _matchedTariffs.firstOrNull?.scheduleTaxRate ?? 0.0,
      importFeeRate: _matchedTariffs.firstOrNull?.importFeeRate ?? 0.0,
    );

    setState(() {
      _c.revisedCifCtrl.text = res.cif.toStringAsFixed(2);
      _c.revisedDutyCtrl.text = res.duty.toStringAsFixed(2);
      _c.revisedVatCtrl.text = res.vat.toStringAsFixed(2);
      _c.revisedOtherFeesCtrl.text = res.other.toStringAsFixed(2);
      _c.revisedTotalDutiesCtrl.text = res.total.toStringAsFixed(2);
    });
    _setDirty(true);
  }

  void _recalculateActualTotal() {
    final duty = double.tryParse(_c.actualDutyCtrl.text) ?? 0.0;
    final vat = double.tryParse(_c.actualVatCtrl.text) ?? 0.0;
    final other = double.tryParse(_c.actualOtherFeesCtrl.text) ?? 0.0;
    setState(() {
      _c.actualTotalDutiesCtrl.text = (duty + vat + other).toStringAsFixed(2);
    });
    _setDirty(true);
  }

  void _onNafezaDataExtracted(Map<String, dynamic> ext) {
    setState(() {
      Declaration46CalculationHelper.applyNafezaExtractedData(ext: ext, controllers: _c);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, context.l10n.customsClearanceExtractNafezaSuccess, severity: AppSeverity.success),
    );
  }

  bool _isVarianceOver10() {
    return Declaration46CalculationHelper.isVarianceOver10(
      studyTot: double.tryParse(_c.totalDutyAndTaxesCtrl.text),
      revisedTot: double.tryParse(_c.revisedTotalDutiesCtrl.text),
      actualTot: double.tryParse(_c.actualTotalDutiesCtrl.text),
    );
  }

  Future<void> _selectSubmissionDate() async {
    await Declaration46SaveDelegate.selectSubmissionDate(
      context: context,
      currentDate: _declarationDate,
      onDatePicked: (picked) {
        setState(() {
          _declarationDate = picked;
          _c.submissionDateCtrl.text = picked.toIso8601String().substring(0, 10);
        });
        final fileId = _selectedImportFileId;
        if (fileId != null) _refreshFiguresAtDeclarationDate(fileId, picked);
      },
    );
  }

  Future<void> _saveDeclaration46(AppLocalizations l) async {
    setState(() => _isSavingDeclaration = true);
    final ok = await Declaration46SaveDelegate.saveDeclaration46(
      context: context,
      ref: ref,
      l: l,
      formKey: _declarationFormKey,
      controllers: _c,
      selectedImportFileId: _selectedImportFileId,
      selectedOffice: _selectedOffice,
      selectedChannel: _selectedChannel,
      declarationDate: _declarationDate,
      matchedTariffs: _matchedTariffs,
      studyFigures: _studyFigures,
    );
    if (mounted) {
      setState(() => _isSavingDeclaration = false);
      if (ok) widget.onSaved();
    }
  }

  void _copyDeclarationAsTsv(AppLocalizations l) {
    CustomsDeclaration46FormService.copyDeclarationAsTsv(
      context: context,
      ref: ref,
      l: l,
      importFileId: _selectedImportFileId,
      declaration46No: _c.declaration46NoCtrl.text,
      submissionDate: _c.submissionDateCtrl.text,
      acidNumber: _c.acidNumberCtrl.text,
      form4Number: _c.form4NumberCtrl.text,
      blNumber: _c.blNumberCtrl.text,
      selectedOffice: _selectedOffice,
      selectedChannel: _selectedChannel,
      cifTotal: _c.customsValueEgpCtrl.text,
      dutyRate: _c.importDutyEgpCtrl.text,
      vatRate: _c.vatEgpCtrl.text,
      totalDuties: _c.totalDutyAndTaxesCtrl.text,
      hasExemption: _hasExemption,
      appliedDutyRate: _appliedDutyRate,
      miss: _miss,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final importFiles = ref.watch(importFilesProvider).valueOrNull ?? [];
    final currentFile = importFiles.where((f) => f.importFileId == _selectedImportFileId).firstOrNull;
    final over10 = _isVarianceOver10();

    return SelectionArea(
      child: Form(
        key: _declarationFormKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Declaration46HeaderCard(
                  selectedImportFileId: _selectedImportFileId,
                  importFiles: importFiles,
                  onImportFileSelected: _onImportFileSelected,
                  onOpenSearchAndClone: widget.onOpenSearchAndClone,
                ),
                const SizedBox(height: 20),
                Declaration46AttributesCard(
                  declaration46NoCtrl: _c.declaration46NoCtrl,
                  submissionDateCtrl: _c.submissionDateCtrl,
                  acidNumberCtrl: _c.acidNumberCtrl,
                  form4NumberCtrl: _c.form4NumberCtrl,
                  blNumberCtrl: _c.blNumberCtrl,
                  selectedOffice: _selectedOffice,
                  selectedChannel: _selectedChannel,
                  onOfficeChanged: (val) {
                    if (val != null) setState(() => _selectedOffice = val);
                  },
                  onChannelChanged: (val) {
                    if (val != null) setState(() => _selectedChannel = val);
                  },
                  onSelectDate: _selectSubmissionDate,
                  maxWidth: constraints.maxWidth,
                ),
                if (_selectedImportFileId != null && _figuresMissing.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  IdocBNotice(
                    key: const Key('decl46FiguresMissingBanner'),
                    severity: AppSeverity.danger,
                    message: Form46FiguresPanel.missingItemsText(l, _figuresMissing),
                  ),
                ],
                const SizedBox(height: 16),
                Form46VarianceBar(
                  studyTotal: double.tryParse(_c.totalDutyAndTaxesCtrl.text),
                  revisedTotal: double.tryParse(_c.revisedTotalDutiesCtrl.text),
                  actualTotal: double.tryParse(_c.actualTotalDutiesCtrl.text),
                ),
                const SizedBox(height: 16),
                Form46ThreeColumnPanel(
                  studyFigures: _studyFigures,
                  appliedTariff: _matchedTariffs.firstOrNull,
                  revisedFxRateCtrl: _c.revisedFxRateCtrl,
                  approvedFreightCtrl: _c.approvedFreightCtrl,
                  actualInsuranceCtrl: _c.actualInsuranceCtrl,
                  dischargeExpensesCtrl: _c.dischargeExpensesCtrl,
                  newCustomsFeesCtrl: _c.newCustomsFeesCtrl,
                  revisedCifCtrl: _c.revisedCifCtrl,
                  revisedDutyCtrl: _c.revisedDutyCtrl,
                  revisedVatCtrl: _c.revisedVatCtrl,
                  revisedOtherFeesCtrl: _c.revisedOtherFeesCtrl,
                  revisedTotalDutiesCtrl: _c.revisedTotalDutiesCtrl,
                  onRevisedVariableChanged: _recalculateRevisedEstimate,
                  actualCifCtrl: _c.actualCifCtrl,
                  actualDutyCtrl: _c.actualDutyCtrl,
                  actualVatCtrl: _c.actualVatCtrl,
                  actualOtherFeesCtrl: _c.actualOtherFeesCtrl,
                  actualTotalDutiesCtrl: _c.actualTotalDutiesCtrl,
                  nafezaClaimNoCtrl: _c.nafezaClaimNoCtrl,
                  nafezaClaimDateCtrl: _c.nafezaClaimDateCtrl,
                  onActualComponentChanged: _recalculateActualTotal,
                  onNafezaDataExtracted: _onNafezaDataExtracted,
                ),
                const SizedBox(height: 16),
                Declaration46VarianceReasonCard(
                  over10: over10,
                  controller: _c.dutyVarianceReasonCtrl,
                ),
                const SizedBox(height: 16),
                if (_selectedImportFileId != null) ...[
                  Declaration46ExemptionCard(
                    hasExemption: _hasExemption,
                    appliedDutyRate: _appliedDutyRate,
                    miss: _miss,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_regulatoryApprovals.isNotEmpty) ...[
                  Declaration46RegulatoryCard(
                    regulatoryApprovals: _regulatoryApprovals,
                    selectedImportFile: currentFile,
                    declaration46No: _c.declaration46NoCtrl.text,
                    submissionDate: _c.submissionDateCtrl.text,
                  ),
                  const SizedBox(height: 20),
                ],
                Declaration46ActionsBar(
                  isSavingDeclaration: _isSavingDeclaration,
                  onSave: () => _saveDeclaration46(l),
                  onCopyTsv: () => _copyDeclarationAsTsv(l),
                  onOpenSearchAndClone: widget.onOpenSearchAndClone,
                  currentFile: currentFile,
                  declaration46No: _c.declaration46NoCtrl.text,
                  submissionDate: _c.submissionDateCtrl.text,
                  selectedOffice: _selectedOffice,
                  selectedChannel: _selectedChannel,
                  acidNumber: _c.acidNumberCtrl.text,
                  form4Number: _c.form4NumberCtrl.text,
                  blNumber: _c.blNumberCtrl.text,
                  cifTotal: _c.customsValueEgpCtrl.text,
                  dutyRate: _c.importDutyEgpCtrl.text,
                  vatRate: _c.vatEgpCtrl.text,
                  totalDuties: _c.totalDutyAndTaxesCtrl.text,
                  hasExemption: _hasExemption,
                  appliedDutyRate: _appliedDutyRate,
                  miss: _miss,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
