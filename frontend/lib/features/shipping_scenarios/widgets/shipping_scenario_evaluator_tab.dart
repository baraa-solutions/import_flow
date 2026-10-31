import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/localization/api_error_text.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../currencies/models/currency_model.dart';
import '../../currencies/providers/currencies_provider.dart';
import '../../external_service_providers/models/partner_model.dart';
import '../../external_service_providers/providers/partners_provider.dart';
import '../../freight_quotations/widgets/freight_quotations_extractor_dialog.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../transport_locations/providers/transport_locations_provider.dart';
import '../models/shipping_scenario_model.dart';
import '../providers/shipping_scenarios_provider.dart';
import '../utils/shipping_scenario_calculator.dart';
import 'carrier_option_evaluation_tile.dart';
import 'freight_ai_extractor_card.dart';
import 'shipping_quote_smart_mapper.dart';
import 'shipping_scenario_evaluator_form.dart';
import 'shipping_scenarios_dialogs.dart';

class ShippingScenarioEvaluatorTab extends ConsumerStatefulWidget {
  final int? initialImportFileId;
  final VoidCallback? onSwitchToRegistry;
  final VoidCallback? onRefreshData;

  const ShippingScenarioEvaluatorTab({
    super.key,
    this.initialImportFileId,
    this.onSwitchToRegistry,
    this.onRefreshData,
  });

  @override
  ConsumerState<ShippingScenarioEvaluatorTab> createState() => ShippingScenarioEvaluatorTabState();
}

class ShippingScenarioEvaluatorTabState extends ConsumerState<ShippingScenarioEvaluatorTab> {
  final _formKey = GlobalKey<FormState>();

  // Evaluator Form State
  int? _editingSessionId;
  String? _editingSessionCode;
  int _editFormVersion = 0;
  String _title = '';
  DateTime _cargoReadyDate = DateTime.now().add(const Duration(days: 5));
  String _pickUpAddress = '';
  int _avgForm4Days = 5;
  int _avgClearanceDays = 7;
  int? _selectedImportFileId;
  int? _selectedPoId;
  int? _selectedProjectId;
  final String _sessionNotes = '';

  // Carrier Options List
  final List<ShippingScenarioItemModel> _evalItems = [];
  bool _isSaving = false;
  bool _isStackable = true;

  // Track expanded quotes in UI
  final Map<int, bool> _expandedQuotes = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialImportFileId != null) {
      _selectedImportFileId = widget.initialImportFileId;
    }
  }

  void loadSessionForEditing(ShippingEvaluationModel sess, {bool showLoadedSnackbar = true}) {
    setState(() {
      _editFormVersion++;
      _editingSessionId = sess.sessionId;
      _editingSessionCode = sess.sessionCode;
      _title = sess.title ?? '';
      _cargoReadyDate = DateTime.tryParse(sess.cargoReadyDate) ?? DateTime.now();
      _pickUpAddress = sess.pickUpAddress ?? '';
      _avgForm4Days = sess.avgForm4Days;
      _avgClearanceDays = sess.avgClearanceDays;
      _selectedImportFileId = sess.importFileId;
      _selectedPoId = sess.poId;
      _selectedProjectId = sess.projectId;
      _evalItems.clear();
      _evalItems.addAll(sess.items);
      _expandedQuotes.clear();
      for (int i = 0; i < sess.items.length; i++) {
        _expandedQuotes[i] = true;
      }
    });
    if (showLoadedSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.sessionLoadedMsg(sess.sessionCode),
          severity: AppSeverity.info,
        ),
      );
    }
  }

  Future<void> resetFormForNewStudy() async {
    final l = context.l10n;
    if (_evalItems.isNotEmpty) {
      final confirm = await AppConfirmDialog.show(
        context,
        title: l.clearAndStartNew,
        message: l.confirmActionTitle,
        confirmLabel: l.confirm,
        cancelLabel: l.cancel,
        confirmVariant: AppButtonVariant.warning,
        icon: Icons.refresh_rounded,
      );
      if (!confirm) return;
    }
    setState(() {
      _editFormVersion++;
      _editingSessionId = null;
      _editingSessionCode = null;
      _title = '';
      _cargoReadyDate = DateTime.now().add(const Duration(days: 5));
      _pickUpAddress = '';
      _avgForm4Days = 5;
      _avgClearanceDays = 7;
      _selectedImportFileId = null;
      _selectedPoId = null;
      _selectedProjectId = null;
      _expandedQuotes.clear();
      _evalItems.clear();
    });
  }

  void _addNewBlankCarrierOption() {
    setState(() {
      _evalItems.add(ShippingScenarioItemModel(
        providerName: '',
        vesselName: '',
        voyageNumber: '',
        sailingDate: _cargoReadyDate.add(const Duration(days: 2)).toString().substring(0, 10),
        estimatedArrivalDate: _cargoReadyDate.add(const Duration(days: 22)).toString().substring(0, 10),
        expectedLineDelayDays: 2,
        quotationCurrency: 'USD',
        freeTimeDays: 21,
        container40ftApplicable: true,
        container40ftPrice: 0.0,
        container40ftQty: 1,
        container40ftCurrency: 'USD',
        container20ftApplicable: false,
        container20ftPrice: 0.0,
        container20ftQty: 0,
        container20ftCurrency: 'USD',
        bookingCancellationApplicable: false,
        bookingCancellationPrice: 0.0,
        bookingCancellationCurrency: 'USD',
        isRecommended: _evalItems.isEmpty,
        riskLevel: 'Low',
        notes: '',
      ));
      _expandedQuotes[_evalItems.length - 1] = false;
    });
  }

  void _cloneCarrierOption(int idx) {
    if (idx < 0 || idx >= _evalItems.length) return;
    final source = _evalItems[idx];
    final l = context.l10n;
    final clonedItem = source.copyWith(
      isRecommended: false,
      isSelected: false,
    );
    setState(() {
      _evalItems.insert(idx + 1, clonedItem);
      _expandedQuotes[idx + 1] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        l.carrierOptionClonedSuccess,
        severity: AppSeverity.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleAddExtractedQuotations(List<ExtractedQuotationOption> selectedOptions) {
    if (selectedOptions.isEmpty) return;
    final crd = _cargoReadyDate;
    final partners = ref.read(allPartnersProvider).valueOrNull ?? ref.read(partnersProvider).valueOrNull ?? [];
    final ports = ref.read(transportLocationsProvider).valueOrNull ?? [];

    setState(() {
      _editFormVersion++;
      for (int i = 0; i < selectedOptions.length; i++) {
        final opt = selectedOptions[i];
        final newItem = ShippingQuoteSmartMapper.mapExtractedOptionToScenarioItem(
          opt: opt,
          crd: crd,
          partners: partners,
          portsList: ports,
          isRecommended: _evalItems.isEmpty && i == 0,
        );
        _evalItems.add(newItem);
        _expandedQuotes[_evalItems.length - 1] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.freightQuotesAddedMsg(selectedOptions.length),
        severity: AppSeverity.success,
      ),
    );
  }

  void _handleAddSingleExtractedQuotation(ExtractedQuotationOption opt) {
    final crd = _cargoReadyDate;
    final partners = ref.read(allPartnersProvider).valueOrNull ?? ref.read(partnersProvider).valueOrNull ?? [];
    final ports = ref.read(transportLocationsProvider).valueOrNull ?? [];

    final newItem = ShippingQuoteSmartMapper.mapExtractedOptionToScenarioItem(
      opt: opt,
      crd: crd,
      partners: partners,
      portsList: ports,
      isRecommended: _evalItems.isEmpty,
    );

    setState(() {
      _editFormVersion++;
      _evalItems.add(newItem);
      _expandedQuotes[_evalItems.length - 1] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.freightQuotesAddedMsg(1),
        severity: AppSeverity.success,
      ),
    );
  }

  void applySmartExtractedFreightQuotes(Map<String, dynamic> fields) {
    final crd = _cargoReadyDate;
    final List<dynamic> options = (fields['rate_options'] is List && (fields['rate_options'] as List).isNotEmpty)
        ? fields['rate_options'] as List
        : [fields];

    final List<ShippingScenarioItemModel> newItems = [];
    final partners = ref.read(allPartnersProvider).valueOrNull ?? ref.read(partnersProvider).valueOrNull ?? [];
    final portsList = ref.read(transportLocationsProvider).valueOrNull ?? [];

    for (int i = 0; i < options.length; i++) {
      final optMap = Map<String, dynamic>.from(options[i] as Map);
      final opt = ExtractedQuotationOption.fromMap(optMap, i + 1);
      newItems.add(ShippingQuoteSmartMapper.mapExtractedOptionToScenarioItem(
        opt: opt,
        crd: crd,
        partners: partners,
        portsList: portsList,
        isRecommended: i == 0,
      ));
    }

    setState(() {
      _editFormVersion++;
      _evalItems.clear();
      _evalItems.addAll(newItems);
      _expandedQuotes.clear();
      for (int i = 0; i < newItems.length; i++) {
        _expandedQuotes[i] = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(
        context,
        context.l10n.freightQuotesAddedMsg(newItems.length),
        severity: AppSeverity.success,
      ),
    );
  }

  Future<void> _saveEvaluationSession(BuildContext context, List<CurrencyModel> currenciesList) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.completeRequiredDataMsg,
          severity: AppSeverity.danger,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

    if (_evalItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic
              ? 'يرجى إضافة خيار شحن واحد على الأقل لحفظ دراسة السيناريوهات'
              : 'Please add at least one shipping carrier option to save the study',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    // Client-side validation of shipping scenarios items
    final seen = <String>{};
    for (int i = 0; i < _evalItems.length; i++) {
      final item = _evalItems[i];
      if (item.providerName.isEmpty || item.providerName == 'Select Line') {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.shippingLineRequiredMsg(i + 1),
            severity: AppSeverity.danger,
          ),
        );
        return;
      }

      final sDate = DateTime.tryParse(item.sailingDate);
      final etaDate = DateTime.tryParse(item.estimatedArrivalDate);

      if (sDate == null || etaDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.datesRequiredMsg(i + 1, item.providerName),
            severity: AppSeverity.danger,
          ),
        );
        return;
      }

      final crdDateOnly = DateTime(_cargoReadyDate.year, _cargoReadyDate.month, _cargoReadyDate.day);
      final sailingDateOnly = DateTime(sDate.year, sDate.month, sDate.day);
      if (sailingDateOnly.isBefore(crdDateOnly)) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.sailingBeforeCrdError(i + 1, item.providerName, item.sailingDate, crdDateOnly.toString().substring(0, 10)),
            severity: AppSeverity.danger,
          ),
        );
        return;
      }

      if (!etaDate.isAfter(sDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.etaAfterSailingError(i + 1, item.providerName, item.estimatedArrivalDate, item.sailingDate),
            severity: AppSeverity.danger,
          ),
        );
        return;
      }

      if (item.expectedLineDelayDays < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.negativeDaysError(i + 1, item.providerName),
            severity: AppSeverity.danger,
          ),
        );
        return;
      }

      final key = '${item.providerId}_${item.providerName.trim().toLowerCase()}_${item.vesselName.trim().toLowerCase()}_${item.sailingDate}';
      if (seen.contains(key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.duplicateQuoteError(i + 1, item.providerName),
            severity: AppSeverity.danger,
          ),
        );
        return;
      }

      if (item.totalQuotationAmount == null) {
        final currencies = ref.read(currenciesProvider).valueOrNull ?? [];
        final missing = ShippingScenarioCalculator.calculateTotalQuoteValue(item: item, currencies: currencies).missingCurrencies;
        final missingStr = missing.isNotEmpty ? missing.join(', ') : (item.quotationCurrency ?? '—');
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            context.l10n.scenarioSaveRateMissingError(i + 1, item.providerName, missingStr),
            severity: AppSeverity.danger,
          ),
        );
        return;
      }

      seen.add(key);
    }

    _formKey.currentState!.save();

    String titleToSave = _title.trim();
    if (_selectedImportFileId != null) {
      final importFiles = ref.read(importFilesProvider).valueOrNull ?? [];
      final f = importFiles.where((file) => file.importFileId == _selectedImportFileId).firstOrNull;
      if (f != null) {
        final fCode = f.displayName;
        if (!titleToSave.startsWith('[$fCode]')) {
          titleToSave = '[$fCode] ${f.companyName}';
        }
      }
    }
    if (titleToSave.isEmpty) {
      titleToSave = context.l10n.defaultStudyTitle(DateTime.now().toString().substring(0, 10));
    }

    setState(() => _isSaving = true);

    bool ok = false;
    if (_editingSessionId != null) {
      final oldSession = ref.read(shippingScenariosProvider).sessions.where((s) => s.sessionId == _editingSessionId).firstOrNull;
      if (oldSession != null) {
        final List<FieldChangeItem> changes = [];

        if (FieldChangeItem.isDifferent(oldSession.title, titleToSave)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'عنوان دراسة الشحن',
            oldValue: oldSession.title,
            newValue: titleToSave,
          ));
        }

        final newCrd = _cargoReadyDate.toString().substring(0, 10);
        if (FieldChangeItem.isDifferent(oldSession.cargoReadyDate, newCrd)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'تاريخ جاهزية البضاعة',
            oldValue: oldSession.cargoReadyDate,
            newValue: newCrd,
          ));
        }

        final newPickup = _pickUpAddress.trim().isNotEmpty ? _pickUpAddress.trim() : null;
        if (FieldChangeItem.isDifferent(oldSession.pickUpAddress, newPickup)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'موقع وعنوان الاستلام',
            oldValue: oldSession.pickUpAddress,
            newValue: newPickup,
          ));
        }

        if (FieldChangeItem.isDifferent(oldSession.avgForm4Days, _avgForm4Days)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'أيام إصدار نموذج 4 المتوقعة',
            oldValue: '${oldSession.avgForm4Days} يوم',
            newValue: '$_avgForm4Days يوم',
          ));
        }

        if (FieldChangeItem.isDifferent(oldSession.avgClearanceDays, _avgClearanceDays)) {
          changes.add(FieldChangeItem(
            section: 'البيانات العامة للدراسة',
            fieldName: 'أيام التخليص الجمركي المتوقعة',
            oldValue: '${oldSession.avgClearanceDays} يوم',
            newValue: '$_avgClearanceDays يوم',
          ));
        }

        if (FieldChangeItem.isDifferent(oldSession.importFileId, _selectedImportFileId)) {
          changes.add(FieldChangeItem(
            section: 'الربط التشغيلي',
            fieldName: 'ملف الاستيراد المرتبط',
            oldValue: oldSession.importFileCode ?? (oldSession.importFileId != null ? 'ID: ${oldSession.importFileId}' : null),
            newValue: _selectedImportFileId != null ? 'ID: $_selectedImportFileId' : null,
          ));
        }

        if (FieldChangeItem.isDifferent(oldSession.poId, _selectedPoId)) {
          changes.add(FieldChangeItem(
            section: 'الربط التشغيلي',
            fieldName: 'أمر الشراء المرتبط',
            oldValue: oldSession.poNumber ?? (oldSession.poId != null ? 'ID: ${oldSession.poId}' : null),
            newValue: _selectedPoId != null ? 'ID: $_selectedPoId' : null,
          ));
        }

        if (oldSession.items.length != _evalItems.length) {
          changes.add(FieldChangeItem(
            section: 'عروض أسعار الشحن المقارنة',
            fieldName: 'عدد عروض الشحن المدرجة',
            oldValue: '${oldSession.items.length} عرض',
            newValue: '${_evalItems.length} عرض',
          ));
        } else {
          for (int i = 0; i < _evalItems.length; i++) {
            final o = oldSession.items[i];
            final n = _evalItems[i];
            final defaultCarrier = context.l10n.ssCarrier;
            final quotePrefix = context.l10n.ssQuote;
            final quoteTitle = '$quotePrefix #${i + 1} (${n.providerName.isNotEmpty ? n.providerName : defaultCarrier})';

            if (FieldChangeItem.isDifferent(o.providerName, n.providerName)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - وكيل الشحن',
                oldValue: o.providerName,
                newValue: n.providerName,
              ));
            }
            if (FieldChangeItem.isDifferent(o.vesselName, n.vesselName)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - الخط الملاحي / الباخرة',
                oldValue: o.vesselName,
                newValue: n.vesselName,
              ));
            }
            if (FieldChangeItem.isDifferent(o.sailingDate, n.sailingDate)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - تاريخ الإبحار',
                oldValue: o.sailingDate,
                newValue: n.sailingDate,
              ));
            }
            if (FieldChangeItem.isDifferent(o.estimatedArrivalDate, n.estimatedArrivalDate)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - تاريخ الوصول المتوقع',
                oldValue: o.estimatedArrivalDate,
                newValue: n.estimatedArrivalDate,
              ));
            }
            if (FieldChangeItem.isDifferent(o.freeTimeDays, n.freeTimeDays)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - أيام السماح',
                oldValue: '${o.freeTimeDays} يوم',
                newValue: '${n.freeTimeDays} يوم',
              ));
            }
            if (FieldChangeItem.isDifferent(o.totalQuotationAmount, n.totalQuotationAmount)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - إجمالي قيمة العرض (${n.quotationCurrency ?? ""})',
                oldValue: o.totalQuotationAmount != null ? '${o.totalQuotationAmount!.toStringAsFixed(2)} ${o.quotationCurrency ?? ""}' : '—',
                newValue: n.totalQuotationAmount != null ? '${n.totalQuotationAmount!.toStringAsFixed(2)} ${n.quotationCurrency ?? ""}' : '—',
              ));
            }
            if (FieldChangeItem.isDifferent(o.isExcludedFromAverage, n.isExcludedFromAverage)) {
              changes.add(FieldChangeItem(
                section: 'عروض أسعار الشحن المقارنة',
                fieldName: '$quoteTitle - استبعاد من المتوسط الحسابي',
                oldValue: o.isExcludedFromAverage ? 'مستبعد' : 'محتسب',
                newValue: n.isExcludedFromAverage ? 'مستبعد' : 'محتسب',
              ));
            }
          }
        }

        if (changes.isNotEmpty) {
          if (!context.mounted) return;
          final confirmed = await showChangeDiffConfirmationDialog(
            context,
            title: isArabic ? 'مراجعة وتأكيد تعديلات دراسة وعروض الشحن' : 'Review and Confirm Shipping Study Edits',
            itemReference: oldSession.sessionCode.isNotEmpty ? oldSession.sessionCode : titleToSave,
            changes: changes,
          );
          if (!confirmed) {
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      final data = {
        'title': titleToSave,
        'cargo_ready_date': _cargoReadyDate.toString().substring(0, 10),
        if (_pickUpAddress.trim().isNotEmpty) 'pick_up_address': _pickUpAddress.trim(),
        'avg_form4_days': _avgForm4Days,
        'avg_clearance_days': _avgClearanceDays,
        if (_selectedImportFileId != null) 'import_file_id': _selectedImportFileId,
        if (_selectedPoId != null) 'po_id': _selectedPoId,
        if (_selectedProjectId != null) 'project_id': _selectedProjectId,
        'is_active': true,
        'items': _evalItems.map((i) => i.toCreateJson()).toList(),
      };
      ok = await ref.read(shippingScenariosProvider.notifier).updateSession(_editingSessionId!, data);
    } else {
      final session = ShippingEvaluationModel(
        sessionCode: '',
        title: titleToSave,
        cargoReadyDate: _cargoReadyDate.toString().substring(0, 10),
        pickUpAddress: _pickUpAddress.trim().isNotEmpty ? _pickUpAddress.trim() : null,
        avgForm4Days: _avgForm4Days,
        avgClearanceDays: _avgClearanceDays,
        importFileId: _selectedImportFileId,
        poId: _selectedPoId,
        projectId: _selectedProjectId,
        notes: _sessionNotes,
        items: _evalItems,
      );
      ok = await ref.read(shippingScenariosProvider.notifier).createSession(session);
    }

    setState(() => _isSaving = false);

    if (ok && context.mounted) {
      final freshState = ref.read(shippingScenariosProvider);
      final savedSess = freshState.sessions.firstWhere(
        (s) => s.title == titleToSave || s.sessionCode == _editingSessionCode,
        orElse: () => ShippingEvaluationModel(
          sessionCode: _editingSessionCode ?? 'NEW',
          title: titleToSave,
          cargoReadyDate: _cargoReadyDate.toString().substring(0, 10),
          items: _evalItems,
          recommendedScenarioProvider: _evalItems.isNotEmpty
              ? _evalItems.firstWhere((i) => i.isRecommended, orElse: () => _evalItems.first).providerName
              : null,
        ),
      );

      resetFormForNewStudy();
      widget.onSwitchToRegistry?.call();
      ShippingScenariosDialogs.showSaveSuccessReportDialog(context, savedSess);
    } else if (!ok && context.mounted) {
      final failure = ref.read(shippingScenariosProvider).error;
      if (ApiErrorText.code(failure) == ApiErrorCode.scenarioSessionExists) {
        final l = context.l10n;
        final existingId = ApiErrorText.detail(failure)?['session_id'];
        final existingCode = ApiErrorText.detail(failure)?['session_code'];
        showExistingRecordSnack(
          context,
          message: ApiErrorText.of(l, failure),
          actionLabel: l.openExistingRecord,
          onOpen: () {
            final match = ref.read(shippingScenariosProvider).sessions.where(
                  (s) => s.sessionId == existingId || (existingCode != null && s.sessionCode == existingCode),
                );
            if (match.isNotEmpty && mounted) loadSessionForEditing(match.first);
          },
        );
        return;
      }
      final err = ApiErrorText.of(context.l10n, failure, fallback: context.l10n.saveFailed);
      await showErrorDetailsDialog(
        context,
        title: context.l10n.saveFailedTitle,
        error: err,
        onRetry: () async {
          await _saveEvaluationSession(context, currenciesList);
        },
      );
    }
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color, {String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppTheme.black.withValues(alpha: 0.26) : AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CopyableText(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            CopyableText(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crd = _cargoReadyDate;
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar') == 'ar';

    final poState = ref.watch(purchaseOrdersProvider);
    final projectsState = ref.watch(projectsProvider);
    final partnersState = ref.watch(allPartnersProvider);
    final portsState = ref.watch(transportLocationsProvider);
    final currenciesAsync = ref.watch(currenciesProvider);

    final poList = poState.purchaseOrders;
    final projectsList = projectsState.valueOrNull ?? [];
    final List<PartnerModel> partnersList = partnersState.valueOrNull ?? [];
    final List<CurrencyModel> currenciesList = currenciesAsync.valueOrNull ?? [];

    final List<PartnerModel> freightForwarders = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('freight forwarder') || t.contains('forwarder') || t.contains('شحن') || t.contains('لوجستي');
    }).toList();

    final List<PartnerModel> shippingLines = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('shipping line') ||
          t.contains('carrier') ||
          t.contains('liner') ||
          t.contains('ملاحي') ||
          t.contains('خط شحن') ||
          t.contains('خطوط ملاحية');
    }).toList();

    final List<PartnerModel> customsBrokers = partnersList.where((p) {
      final t = p.partnerType.toLowerCase();
      return t.contains('customs broker') || t.contains('broker') || t.contains('تخليص') || t.contains('مخلص');
    }).toList();
    final portsList = portsState.valueOrNull ?? [];

    // Calculate Scenario lead times
    final calculatedScenarios = _evalItems.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      final sDate = DateTime.tryParse(item.sailingDate) ?? crd;
      final etaDate = DateTime.tryParse(item.estimatedArrivalDate) ?? sDate.add(const Duration(days: 20));

      final vesselLeadTime = etaDate.difference(sDate).inDays;
      final readyDays = sDate.difference(crd).inDays;
      final totalDays = vesselLeadTime + readyDays + _avgForm4Days + _avgClearanceDays + item.expectedLineDelayDays;

      final expectedWhDate = crd.add(Duration(days: totalDays)).toString().substring(0, 10);

      return {
        'index': idx,
        'item': item,
        'vesselLeadTime': vesselLeadTime,
        'readyDays': readyDays,
        'totalDays': totalDays,
        'expectedWhDate': expectedWhDate,
      };
    }).toList();

    final validScenarios = calculatedScenarios.where((c) => !(c['item'] as ShippingScenarioItemModel).isExcludedFromAverage).toList();
    final avgTotalDays = validScenarios.isNotEmpty
        ? (validScenarios.fold<int>(0, (sum, c) => sum + (c['totalDays'] as int)) / validScenarios.length).round()
        : 0;
    final avgArrivalDate = validScenarios.isNotEmpty
        ? crd.add(Duration(days: avgTotalDays)).toString().substring(0, 10)
        : 'N/A';

    final recItemMap = calculatedScenarios.where((c) {
      final it = c['item'] as ShippingScenarioItemModel;
      return it.isRecommended && it.totalQuotationAmount != null;
    }).firstOrNull;
    final recItem = recItemMap != null ? (recItemMap['item'] as ShippingScenarioItemModel) : null;

    final earliestItemMap = validScenarios.isNotEmpty
        ? validScenarios.reduce((a, b) => (a['totalDays'] as int) < (b['totalDays'] as int) ? a : b)
        : null;
    final latestItemMap = validScenarios.isNotEmpty
        ? validScenarios.reduce((a, b) => (a['totalDays'] as int) > (b['totalDays'] as int) ? a : b)
        : null;

    return SelectionArea(
      child: Form(
        key: _formKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: KeyedSubtree(
                key: ValueKey('evaluator_form_${_editingSessionId ?? "new"}_$_editFormVersion'),
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 16, top: 16, bottom: 85),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Metrics Cards Responsive Layout
                      LayoutBuilder(
                        builder: (context, metricConstraints) {
                          final card1 = _buildMetricCard(
                            l.avgWarehouseArrivalMetric,
                            avgArrivalDate,
                            Icons.date_range,
                            AppTheme.wcagEmerald,
                            subtitle: l.avgDaysFromReadiness(avgTotalDays),
                          );
                          final card2 = _buildMetricCard(
                            l.earliestLineMetric,
                            earliestItemMap != null ? (earliestItemMap["item"] as ShippingScenarioItemModel).providerName : 'N/A',
                            Icons.speed,
                            AppTheme.wcagCobalt,
                            subtitle: earliestItemMap != null ? '${l.estimatedArrivalDateCol}: ${earliestItemMap["expectedWhDate"]}' : null,
                          );
                          final card3 = _buildMetricCard(
                            l.latestLineMetric,
                            latestItemMap != null ? (latestItemMap["item"] as ShippingScenarioItemModel).providerName : 'N/A',
                            Icons.warning_amber_rounded,
                            AppTheme.wcagOrange,
                            subtitle: latestItemMap != null ? '${l.estimatedArrivalDateCol}: ${latestItemMap["expectedWhDate"]}' : null,
                          );
                          final card4 = _buildMetricCard(
                            l.recommendedLineMetric,
                            recItem != null ? '${recItem.providerName} (${recItem.vesselName})' : l.unassigned,
                            Icons.stars_rounded,
                            AppTheme.cobalt,
                            subtitle: recItemMap != null ? '${l.avgWarehouseArrivalMetric}: ${recItemMap["expectedWhDate"]} (${recItemMap["totalDays"]} d)' : null,
                          );

                          if (metricConstraints.maxWidth < 600) {
                            return Column(
                              children: [
                                card1,
                                const SizedBox(height: 8),
                                card2,
                                const SizedBox(height: 8),
                                card3,
                                const SizedBox(height: 8),
                                card4,
                              ],
                            );
                          } else if (metricConstraints.maxWidth < 1100) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: card1),
                                    const SizedBox(width: 8),
                                    Expanded(child: card2),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: card3),
                                    const SizedBox(width: 8),
                                    Expanded(child: card4),
                                  ],
                                ),
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                Expanded(child: card1),
                                const SizedBox(width: 8),
                                Expanded(child: card2),
                                const SizedBox(width: 8),
                                Expanded(child: card3),
                                const SizedBox(width: 8),
                                Expanded(child: card4),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Smart AI Freight Quotations Extractor (Sub-component 1)
                      FreightAiExtractorCard(
                        onAddQuotations: _handleAddExtractedQuotations,
                        onAddSingleQuotation: _handleAddSingleExtractedQuotation,
                        onAddAllQuotations: _handleAddExtractedQuotations,
                      ),
                      const SizedBox(height: 16),

                      // Evaluator Form Inputs
                      ShippingScenarioEvaluatorForm(
                        title: _title,
                        onTitleChanged: (val) => _title = val,
                        cargoReadyDate: _cargoReadyDate,
                        onCargoReadyDateChanged: (val) => setState(() => _cargoReadyDate = val),
                        selectedImportFileId: _selectedImportFileId,
                        onImportFileChanged: (val) => setState(() => _selectedImportFileId = val),
                        pickUpAddress: _pickUpAddress,
                        onPickUpAddressChanged: (val) => _pickUpAddress = val,
                        selectedPoId: _selectedPoId,
                        onPoChanged: (val) => setState(() => _selectedPoId = val),
                        selectedProjectId: _selectedProjectId,
                        onProjectChanged: (val) => setState(() => _selectedProjectId = val),
                        avgForm4Days: _avgForm4Days,
                        onAvgForm4DaysChanged: (val) => setState(() => _avgForm4Days = val),
                        avgClearanceDays: _avgClearanceDays,
                        onAvgClearanceDaysChanged: (val) => setState(() => _avgClearanceDays = val),
                        isStackable: _isStackable,
                        onStackableChanged: (val) => setState(() => _isStackable = val),
                        editingSessionId: _editingSessionId,
                        editingSessionCode: _editingSessionCode,
                        editFormVersion: _editFormVersion,
                        onCancelEdit: () {
                          resetFormForNewStudy();
                          ScaffoldMessenger.of(context).showSnackBar(
                            AppTheme.snackBar(
                              context,
                              l.cancelEditModeMsg,
                              severity: AppSeverity.info,
                            ),
                          );
                        },
                        poList: poList,
                        projectsList: projectsList,
                        onShowContainerComparison: (dualRec, cbm, weightKg) =>
                            ShippingScenariosDialogs.showContainerComparisonDialog(context, dualRec, cbm, weightKg),
                        onShowVisualLoadPlan: (filteredPos, cbm, weightKg) =>
                            ShippingScenariosDialogs.showVisualLoadPlanDialog(context, filteredPos, cbm, weightKg),
                      ),
                      const SizedBox(height: 20),

                      // Carrier Options Section Header
                      LayoutBuilder(
                        builder: (context, headerConstraints) {
                          final isNarrowHeader = headerConstraints.maxWidth < 650;
                          final titleWidget = Text(
                            l.shippingCarrierOptions,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          );
                          final addBtn = AppButton(
                            label: l.addNewShippingOption,
                            icon: Icons.add,
                            variant: AppButtonVariant.primary,
                            onPressed: _addNewBlankCarrierOption,
                          );
                          if (isNarrowHeader) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                titleWidget,
                                const SizedBox(height: 8),
                                addBtn,
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: titleWidget),
                              const SizedBox(width: 8),
                              addBtn,
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      if (_evalItems.isEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_boat_outlined,
                                size: 40,
                                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isArabic
                                    ? 'لا توجد خيارات أو عروض شحن مضافة حتى الآن'
                                    : 'No shipping carrier options added yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isArabic
                                    ? 'اضغط "+ إضافة خيار شحن جديد" لإضافة خيار شحن فارغ، أو استخرج العروض تلقائياً من المستندات أعلاه'
                                    : 'Click "+ Add New Shipping Option" to add a blank carrier option, or extract quotes above',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              AppButton(
                                label: l.addNewShippingOption,
                                icon: Icons.add,
                                variant: AppButtonVariant.primary,
                                size: AppButtonSize.small,
                                onPressed: _addNewBlankCarrierOption,
                              ),
                            ],
                          ),
                        ),

                      // Carrier Option Cards List
                      ..._evalItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final calc = calculatedScenarios.firstWhere((c) => c['index'] == idx, orElse: () => {});

                        return CarrierOptionEvaluationTile(
                          key: ValueKey('carrier_tile_${_editingSessionId ?? "new"}_${idx}_$_editFormVersion'),
                          index: idx,
                          item: item,
                          calculation: calc,
                          isExpanded: _expandedQuotes[idx] ?? false,
                          onToggleExpanded: () => setState(() => _expandedQuotes[idx] = !(_expandedQuotes[idx] ?? false)),
                          onUpdateItem: (updated) => setState(() => _evalItems[idx] = updated),
                          onClone: () => _cloneCarrierOption(idx),
                          onDelete: () async {
                            final confirm = await AppConfirmDialog.showDelete(
                              context,
                              entityName: item.providerName,
                              title: l.confirmDelete,
                              message: '${l.confirmDelete} (${item.providerName})؟',
                            );
                            if (confirm) {
                              setState(() {
                                _evalItems.removeAt(idx);
                                _expandedQuotes.remove(idx);
                              });
                            }
                          },
                          freightForwarders: freightForwarders,
                          shippingLines: shippingLines,
                          customsBrokers: customsBrokers,
                          portsList: portsList,
                          currenciesList: currenciesList,
                          editingSessionId: _editingSessionId,
                          editFormVersion: _editFormVersion,
                          onRefreshData: () => widget.onRefreshData?.call(),
                        );
                      }),
                      const SizedBox(height: 20),

                      // Comparison Summary Enterprise Table
                      SizedBox(
                        height: 380,
                        child: EnterpriseDataTable<Map<String, dynamic>>(
                          data: calculatedScenarios,
                          title: l.sideBySideComparison,
                          storageKey: 'shipping_scenarios_comparison_table',
                          enableExport: true,
                          exportFileName: 'Shipping_Scenarios_Comparison',
                          columns: [
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'index',
                              title: '#',
                              width: 50,
                              cellBuilder: (ctx, c, i) => Text('${(c['index'] as int) + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              searchValue: (c) => '${(c['index'] as int) + 1}',
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'provider_name',
                              title: l.shippingLineCol,
                              width: 140,
                              cellBuilder: (ctx, c, i) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                return Text(item.providerName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt));
                              },
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).providerName,
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'total_quote',
                              title: l.totalQuoteValue,
                              width: 130,
                              isNumeric: true,
                              cellBuilder: (ctx, c, i) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                final totalStr = item.totalQuotationAmount != null
                                    ? '${item.totalQuotationAmount!.toStringAsFixed(0)} ${item.quotationCurrency ?? ""}'
                                    : '—';
                                return item.totalQuotationAmount != null
                                    ? Text(totalStr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.crimson))
                                    : Tooltip(
                                        message: l.rateMissingWarning(item.quotationCurrency ?? '—'),
                                        child: const Text('—', style: TextStyle(color: AppTheme.wcagOrange, fontWeight: FontWeight.bold)),
                                      );
                              },
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).totalQuotationAmount?.toString() ?? '',
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'expected_wh_date',
                              title: l.whDateCol,
                              width: 110,
                              cellBuilder: (ctx, c, i) => Text('${c["expectedWhDate"]}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                              searchValue: (c) => '${c["expectedWhDate"]}',
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'total_days',
                              title: l.avgTransitMetric,
                              width: 90,
                              isNumeric: true,
                              cellBuilder: (ctx, c, i) => Text('${c["totalDays"]} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                              searchValue: (c) => '${c["totalDays"]}',
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'customs_broker',
                              title: l.customsBrokerLabel,
                              width: 140,
                              cellBuilder: (ctx, c, i) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                return Text(item.customsBrokerName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600));
                              },
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).customsBrokerName ?? '',
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'route',
                              title: '${l.portOfLoadingCol} / ${l.portOfDischargeCol}',
                              width: 150,
                              cellBuilder: (ctx, c, i) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                return Text('${item.polName ?? "-"} ➔ ${item.podName ?? "-"}', style: const TextStyle(fontSize: 11));
                              },
                              searchValue: (c) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                return '${item.polName} ${item.podName}';
                              },
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'vessel',
                              title: l.vesselNameCol,
                              width: 130,
                              cellBuilder: (ctx, c, i) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                return Text('${item.vesselName} (${item.voyageNumber ?? "-"})');
                              },
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).vesselName,
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'sailing_date',
                              title: l.sailingDateCol,
                              width: 105,
                              cellBuilder: (ctx, c, i) => Text((c['item'] as ShippingScenarioItemModel).sailingDate),
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).sailingDate,
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'eta_date',
                              title: l.estimatedArrivalDateCol,
                              width: 105,
                              cellBuilder: (ctx, c, i) => Text((c['item'] as ShippingScenarioItemModel).estimatedArrivalDate),
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).estimatedArrivalDate,
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'free_time',
                              title: l.freeTimeDaysCol,
                              width: 90,
                              isNumeric: true,
                              cellBuilder: (ctx, c, i) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                return Text('${item.freeTimeDays} d', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt));
                              },
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).freeTimeDays.toString(),
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'risk_level',
                              title: l.riskLevelCol,
                              width: 100,
                              cellBuilder: (ctx, c, i) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                return AppStatusBadge(
                                  label: item.riskLevel,
                                  severity: item.riskLevel == 'High'
                                      ? AppSeverity.danger
                                      : item.riskLevel == 'Medium'
                                          ? AppSeverity.warning
                                          : AppSeverity.success,
                                );
                              },
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).riskLevel,
                            ),
                            EnterpriseColumn<Map<String, dynamic>>(
                              id: 'status',
                              title: l.statusCol,
                              width: 120,
                              cellBuilder: (ctx, c, i) {
                                final item = c['item'] as ShippingScenarioItemModel;
                                return Text(
                                  item.isExcludedFromAverage ? l.excludedFromAvg : l.includedInAvg,
                                  style: TextStyle(
                                    color: item.isExcludedFromAverage ? AppTheme.crimson : AppTheme.cobalt,
                                    fontSize: 11,
                                  ),
                                );
                              },
                              searchValue: (c) => (c['item'] as ShippingScenarioItemModel).isExcludedFromAverage ? 'Excluded' : 'Included',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Fixed Action Bar
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                  border: Border(top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite)),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? AppTheme.black.withValues(alpha: 0.26) : AppTheme.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Live Refresh Button
                                AppButton(
                                  label: '${l.liveRefresh} 🔄',
                                  icon: Icons.refresh,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  onPressed: () => widget.onRefreshData?.call(),
                                ),
                                const SizedBox(width: 8),

                                // 2. Clear Form & Start New
                                AppButton(
                                  label: '${l.clearAndStartNew} 🔄',
                                  icon: Icons.cleaning_services_outlined,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.small,
                                  onPressed: resetFormForNewStudy,
                                ),
                                const SizedBox(width: 8),

                                // 3. Save Draft & Continue Later
                                AppButton(
                                  label: '${l.saveDraftContinueLater} 💾',
                                  icon: Icons.save_outlined,
                                  variant: AppButtonVariant.primary,
                                  size: AppButtonSize.small,
                                  onPressed: _isSaving ? null : () => _saveEvaluationSession(context, currenciesList),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),

                            // 4. Final Submit / Save Study
                            AppButton(
                              label: _editingSessionId != null ? '${l.saveChanges} 💾' : '${l.saveAndSubmitStudy} ✅',
                              icon: Icons.check_circle_outline,
                              variant: AppButtonVariant.success,
                              size: AppButtonSize.small,
                              isLoading: _isSaving,
                              onPressed: _isSaving ? null : () => _saveEvaluationSession(context, currenciesList),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
