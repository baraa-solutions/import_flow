import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/customs_consultation_model.dart';
import '../providers/customs_consultation_provider.dart';
import '../utils/customs_expense_group_helper.dart';
import 'price_list/price_list_form_actions.dart';
import 'price_list/price_list_header_section.dart';
import 'price_list/price_list_items_table_section.dart';
import 'price_list/price_list_match_helper.dart';
import 'price_list/price_list_payload_helper.dart';

export 'price_list/price_list_match_helper.dart' show getCategoryLabel, getUnitLabel, standardRatesMap;

/// Entry-point helper to open the [PriceListFormDialog].
void showPriceListFormDialog(
  BuildContext context,
  WidgetRef ref, {
  BrokerPriceListModel? existingPriceList,
  required List<dynamic> brokersList,
  Map<String, dynamic>? initialExtractedData,
}) {
  final l = context.l10n;
  if (brokersList.isEmpty && existingPriceList == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      AppTheme.snackBar(context, l.noBrokersRegistered, severity: AppSeverity.warning),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PriceListFormDialog(
      existingPriceList: existingPriceList,
      brokersList: brokersList,
      initialExtractedData: initialExtractedData,
    ),
  );
}

/// Unified coordinator dialog for creating and editing broker customs price lists.
class PriceListFormDialog extends ConsumerStatefulWidget {
  final BrokerPriceListModel? existingPriceList;
  final List<dynamic> brokersList;
  final Map<String, dynamic>? initialExtractedData;

  const PriceListFormDialog({
    super.key,
    this.existingPriceList,
    required this.brokersList,
    this.initialExtractedData,
  });

  @override
  ConsumerState<PriceListFormDialog> createState() => _PriceListFormDialogState();
}

class _PriceListFormDialogState extends ConsumerState<PriceListFormDialog> {
  int? _selectedBroker;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _usdRateCtrl;
  DateTime? _effectiveDate;
  int _version = 1;

  final List<Map<String, dynamic>> _itemsState = [];
  final Set<CustomsExpenseGroup> _expandedGroups = {...CustomsExpenseGroup.values};
  String _itemSearchQuery = '';
  String _selectedCategoryFilter = 'All';
  String _quickFilterChip = 'all';
  bool _isSaving = false;
  String? _dialogErrorMessage;
  int? _activeRowIndex;

  bool get _isEditing => widget.existingPriceList != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPriceList;
    final extracted = widget.initialExtractedData;

    _selectedBroker = existing?.brokerId;
    _titleCtrl = TextEditingController(text: existing?.title ?? (extracted?['title'] ?? ''));
    _portCtrl = TextEditingController(text: existing?.portName ?? (extracted?['port_name'] ?? ''));
    _notesCtrl = TextEditingController(text: existing?.notes ?? (extracted?['notes'] ?? ''));
    _usdRateCtrl = TextEditingController();
    _version = existing?.version ?? 1;

    final dateStr = existing?.effectiveFrom ??
        (extracted?['effective_from'] ?? DateTime.now().toIso8601String().split('T').first);
    _effectiveDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    _loadInitialItems();
  }

  void _loadInitialItems() {
    if (!ref.read(expenseCatalogProvider).isLoading && ref.read(expenseCatalogProvider).valueOrNull == null) {
      Future.microtask(() => ref.read(expenseCatalogProvider.notifier).fetchCatalog());
    }

    final catalog = ref.read(clearanceExpenseTypesProvider).valueOrNull ?? [];
    final items = PriceListPayloadHelper.initializeItems(
      existingPriceList: widget.existingPriceList,
      catalog: catalog,
      initialExtractedData: widget.initialExtractedData,
    );
    _itemsState.addAll(items);

    if (widget.initialExtractedData != null && !_isEditing) {
      final matched = PriceListPayloadHelper.matchBroker(
        widget.initialExtractedData!['broker_name'] as String?,
        widget.brokersList,
      );
      if (matched != null) _selectedBroker = matched;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _portCtrl.dispose();
    _notesCtrl.dispose();
    _usdRateCtrl.dispose();
    super.dispose();
  }

  void _cloneRowAt(int realIdx) {
    if (realIdx < 0 || realIdx >= _itemsState.length) return;
    final orig = _itemsState[realIdx];
    final cloned = Map<String, dynamic>.from(orig);
    cloned['item_id'] = null;
    cloned['expense_type_id'] = null;
    cloned['expense_name'] = '${orig['expense_name']}${TableRowCloneHelper.copySuffix}';
    cloned['notes'] = orig['notes'] != null && orig['notes'].toString().isNotEmpty
        ? '${orig['notes']} | Cloned'
        : 'Cloned';
    setState(() {
      _itemsState.insert(realIdx + 1, cloned);
      _activeRowIndex = realIdx + 1;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          context.l10n.ccRowClonedSuccessfullyCtrlD,
          severity: AppSeverity.info,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onDataExtracted(Map<String, dynamic> extracted) {
    setState(() {
      if (extracted['title'] != null && (extracted['title'] as String).isNotEmpty) {
        _titleCtrl.text = extracted['title'] as String;
      }
      if (extracted['port_name'] != null && (extracted['port_name'] as String).isNotEmpty) {
        _portCtrl.text = extracted['port_name'] as String;
      }
      if (extracted['effective_from'] != null && (extracted['effective_from'] as String).isNotEmpty) {
        final parsed = DateTime.tryParse(extracted['effective_from'] as String);
        if (parsed != null) _effectiveDate = parsed;
      }
      if (extracted['notes'] != null && (extracted['notes'] as String).isNotEmpty) {
        _notesCtrl.text = extracted['notes'] as String;
      }
      final matched = PriceListPayloadHelper.matchBroker(
        extracted['broker_name'] as String?,
        widget.brokersList,
      );
      if (matched != null) _selectedBroker = matched;

      applyExtractedExpenses(extracted, _itemsState, isInitial: false);
    });
  }

  Future<void> _savePriceList() async {
    final l = context.l10n;
    setState(() => _dialogErrorMessage = null);

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _dialogErrorMessage = l.priceListTitleRequired);
      return;
    }
    if (_selectedBroker == null) {
      setState(() => _dialogErrorMessage = l.selectBrokerRequired);
      return;
    }

    setState(() => _isSaving = true);

    try {
      dynamic matchedBroker;
      for (final b in widget.brokersList) {
        if (b.providerId == _selectedBroker) {
          matchedBroker = b;
          break;
        }
      }
      final brokerName = matchedBroker?.partnerName ??
          (widget.existingPriceList?.brokerName ?? (context.l10n.ccCustomsBroker2));

      final effDate = _effectiveDate != null
          ? AppDatePickerField.format(_effectiveDate!)
          : DateTime.now().toIso8601String().split('T').first;

      final payload = PriceListPayloadHelper.buildPayload(
        title: title,
        selectedBroker: _selectedBroker!,
        brokerName: brokerName,
        portName: _portCtrl.text,
        effectiveFrom: effDate,
        version: _isEditing ? _version : 1,
        isActive: _isEditing ? widget.existingPriceList!.isActive : true,
        notes: _notesCtrl.text,
        itemsState: _itemsState,
        isEditing: _isEditing,
      );

      final notifier = ref.read(brokerPriceListsProvider.notifier);
      if (_isEditing) {
        await notifier.updatePriceList(widget.existingPriceList!.priceListId, payload);
      } else {
        await notifier.createPriceList(payload);
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      ref.invalidate(brokerPriceListsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            _isEditing ? l.priceListUpdatedSuccess : l.priceListCreatedSuccess,
            severity: AppSeverity.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (e is DioException) {
        final resData = e.response?.data;
        if (resData is Map && resData.containsKey('detail')) {
          errorMsg = resData['detail'].toString();
        } else if (resData != null) {
          errorMsg = resData.toString();
        } else {
          errorMsg = e.message ?? l.ccServerConnectionFailed;
        }
      }
      if (mounted) {
        setState(() => _dialogErrorMessage = '❌ ${l.ccFailedToSave}: $errorMsg');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = (mediaQuery.size.width * 0.92).clamp(750.0, 1050.0);
    final dialogHeight = (mediaQuery.size.height * 0.88).clamp(420.0, 750.0);
    final double? usdRefRate = double.tryParse(_usdRateCtrl.text.trim());

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          if (_activeRowIndex != null) {
            _cloneRowAt(_activeRowIndex!);
          } else if (_itemsState.isNotEmpty) {
            _cloneRowAt(0);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SelectionArea(
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PriceListHeaderSection(
                    ref: ref,
                    isEditing: _isEditing,
                    existingPriceListTitle: widget.existingPriceList?.title ?? '',
                    existingBrokerName: widget.existingPriceList?.brokerName,
                    selectedBroker: _selectedBroker,
                    brokersList: widget.brokersList,
                    onBrokerChanged: (v) => setState(() => _selectedBroker = v),
                    titleController: _titleCtrl,
                    portController: _portCtrl,
                    effectiveDate: _effectiveDate,
                    onDateChanged: (v) => setState(() => _effectiveDate = v),
                    notesController: _notesCtrl,
                    usdRateController: _usdRateCtrl,
                    errorMessage: _dialogErrorMessage,
                    onClearError: () => setState(() => _dialogErrorMessage = null),
                    itemsState: _itemsState,
                    onDataExtracted: _onDataExtracted,
                    onClose: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 12),
                  PriceListItemsTableSection(
                    ref: ref,
                    itemsState: _itemsState,
                    expandedGroups: _expandedGroups,
                    itemSearchQuery: _itemSearchQuery,
                    selectedCategoryFilter: _selectedCategoryFilter,
                    quickFilterChip: _quickFilterChip,
                    usdRefRate: usdRefRate,
                    dialogWidth: dialogWidth,
                    onSearchChanged: (v) => setState(() => _itemSearchQuery = v),
                    onCategoryFilterChanged: (v) => setState(() => _selectedCategoryFilter = v),
                    onQuickFilterChanged: (v) => setState(() => _quickFilterChip = v),
                    onToggleGroup: (grp) => setState(() {
                      if (_expandedGroups.contains(grp)) {
                        _expandedGroups.remove(grp);
                      } else {
                        _expandedGroups.add(grp);
                      }
                    }),
                    onExpandAll: () => setState(() => _expandedGroups.addAll(CustomsExpenseGroup.values)),
                    onCollapseAll: () => setState(() => _expandedGroups.clear()),
                    onFillStandardRates: () => setState(() => PriceListPayloadHelper.fillStandardRates(_itemsState)),
                    onZeroOutRates: () => setState(() => PriceListPayloadHelper.zeroOutRates(_itemsState)),
                    onCloneRow: _cloneRowAt,
                    onDeleteCustomItem: (realIdx) => setState(() => _itemsState.removeAt(realIdx)),
                    onAddCustomItemSaved: (itemData) => setState(() {
                      _selectedCategoryFilter = 'All';
                      _itemSearchQuery = '';
                      _itemsState.insert(0, {
                        'expense_type_id': null,
                        ...itemData,
                      });
                    }),
                    onStateChanged: (fn) => setState(fn),
                  ),
                  const SizedBox(height: 6),
                  PriceListFormActions(
                    itemsState: _itemsState,
                    usdRefRate: usdRefRate,
                    isSaving: _isSaving,
                    isEditing: _isEditing,
                    onCancel: () => Navigator.pop(context),
                    onSave: _savePriceList,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
