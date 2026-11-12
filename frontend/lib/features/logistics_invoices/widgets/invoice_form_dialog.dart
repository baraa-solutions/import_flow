import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../repositories/logistics_invoices_repository.dart';
import 'bl_container_lock_widget.dart';
import 'partner_balance_card.dart';
import 'invoice_form/invoice_form_basic_fields.dart';
import 'invoice_form/invoice_form_header.dart';
import 'invoice_form/invoice_form_lines_table.dart';
import 'invoice_form/invoice_form_taxes_totals.dart';

class InvoiceFormDialog extends ConsumerStatefulWidget {
  final LogisticsInvoiceModel? initialInvoice;
  final String defaultPartnerType;
  final int? initialShipmentId;
  final String? initialBlNumber;
  final int? initialPartnerId;
  final String? initialPartnerName;

  const InvoiceFormDialog({
    super.key,
    this.initialInvoice,
    this.defaultPartnerType = 'freight',
    this.initialShipmentId,
    this.initialBlNumber,
    this.initialPartnerId,
    this.initialPartnerName,
  });

  @override
  ConsumerState<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends ConsumerState<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _shipmentId;
  late String _blNumber;
  late int _partnerId;
  late String _partnerName;
  late String _partnerType;
  late String _invoiceNumber;
  late DateTime _invoiceDate;
  late String _currency;
  late double _exchangeRate;
  bool _vatIncluded = false;
  double _vatAmount = 0.0;
  bool _whtDeducted = false;
  double _whtAmount = 0.0;
  String? _notes;

  List<String> _selectedContainers = [];
  List<LogisticsInvoiceLineModel> _lines = [];
  bool _isLoading = false;
  bool _isPrefilling = false;

  // Controllers
  late TextEditingController _blNumberCtrl;
  late TextEditingController _partnerIdCtrl;
  late TextEditingController _partnerNameCtrl;
  late TextEditingController _invoiceNumberCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final inv = widget.initialInvoice;

    // Never a made-up file id: the user picks the file when the caller has none.
    _shipmentId = inv?.shipmentId ?? widget.initialShipmentId;
    _blNumber = inv?.blNumber ?? widget.initialBlNumber ?? '';
    _partnerId = inv?.partnerId ?? widget.initialPartnerId ?? 1;
    _partnerName = inv?.partnerName ?? widget.initialPartnerName ?? '';
    _invoiceNumber = inv?.invoiceNumber ?? '';
    const validPartnerTypes = ['freight', 'clearance', 'transport', 'inspection', 'insurance'];
    final rawPartnerType = (inv?.partnerType ?? widget.defaultPartnerType).toLowerCase();
    _partnerType = validPartnerTypes.contains(rawPartnerType) ? rawPartnerType : 'freight';
    _invoiceDate = inv?.invoiceDate ?? DateTime.now();
    _currency = inv?.currency ?? 'USD';
    _exchangeRate = inv?.exchangeRate ?? 48.5;
    _vatIncluded = inv?.vatIncluded ?? false;
    _vatAmount = inv?.vatAmount ?? 0.0;
    _whtDeducted = inv?.whtDeducted ?? false;
    _whtAmount = inv?.whtAmount ?? 0.0;
    _notes = inv?.notes;

    _selectedContainers = inv?.containers.map((c) => c.containerNumber).toList() ?? [];
    _lines = inv?.lines != null ? List.from(inv!.lines) : [];

    _blNumberCtrl = TextEditingController(text: _blNumber);
    _partnerIdCtrl = TextEditingController(text: _partnerId.toString());
    _partnerNameCtrl = TextEditingController(text: _partnerName);
    _invoiceNumberCtrl = TextEditingController(text: _invoiceNumber);
    _notesCtrl = TextEditingController(text: _notes ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(importFilesProvider.notifier).fetchImportFiles();
    });
    if (inv == null && _lines.isEmpty) {
      _loadPrefillLines();
    }
  }

  @override
  void dispose() {
    _blNumberCtrl.dispose();
    _partnerIdCtrl.dispose();
    _partnerNameCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefillLines() async {
    final shipmentId = _shipmentId;
    if (shipmentId == null) {
      if (_lines.isEmpty) _addEmptyLine();
      return;
    }
    setState(() => _isPrefilling = true);
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final prefill = await repo.getPrefillLines(shipmentId, _partnerType);
      setState(() {
        _currency = prefill.currency;
        _exchangeRate = prefill.exchangeRate;
        _lines = prefill.lines;
        _recalculateTotals();
      });
    } catch (_) {
      if (_lines.isEmpty) {
        _addEmptyLine();
      }
    } finally {
      if (mounted) setState(() => _isPrefilling = false);
    }
  }

  Future<void> _fetchCbeRate() async {
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final rate = await repo.getCbeExchangeRate(_currency);
      setState(() {
        _exchangeRate = rate;
        _recalculateTotals();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'CBE Exchange Rate updated: $rate EGP',
            severity: AppSeverity.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'Failed to fetch CBE rate: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  void _addEmptyLine() {
    setState(() {
      _lines.add(
        LogisticsInvoiceLineModel(
          lineDescription: 'Additional Expense Item',
          quantity: 1.0,
          unitPriceFx: 0.0,
          currency: _currency,
          exchangeRate: _exchangeRate,
          amountFx: 0.0,
          amountEgp: 0.0,
        ),
      );
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    double calculatedVat = 0.0;
    double calculatedWht = 0.0;

    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final amtFx = line.quantity * line.unitPriceFx;
      final amtEgp = amtFx * _exchangeRate;
      final lineVat = line.vatRate > 0 ? (amtEgp * line.vatRate / 100.0) : 0.0;
      final lineWht = line.whtRate > 0 ? (amtEgp * line.whtRate / 100.0) : 0.0;
      final netEgp = amtEgp + lineVat - lineWht;

      _lines[i] = LogisticsInvoiceLineModel(
        lineId: line.lineId,
        invoiceId: line.invoiceId,
        expenseCode: line.expenseCode,
        lineDescription: line.lineDescription,
        lineGroup: line.lineGroup,
        quantity: line.quantity,
        unitPriceFx: line.unitPriceFx,
        currency: _currency,
        amountFx: amtFx,
        exchangeRate: _exchangeRate,
        amountEgp: amtEgp,
        taxType: line.taxType,
        vatRate: line.vatRate,
        vatAmount: lineVat,
        whtRate: line.whtRate,
        whtAmount: lineWht,
        netAmountEgp: netEgp,
        isFromQuotation: line.isFromQuotation,
      );

      calculatedVat += lineVat;
      calculatedWht += lineWht;
    }

    setState(() {
      _vatAmount = calculatedVat;
      _whtAmount = calculatedWht;
    });
  }

  double get _subtotalFx => _lines.fold(0.0, (acc, item) => acc + item.amountFx);
  double get _subtotalEgp => _subtotalFx * _exchangeRate;
  double get _netPayableEgp => _subtotalEgp + (_vatIncluded ? _vatAmount : 0.0) - (_whtDeducted ? _whtAmount : 0.0);

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isArabic
              ? 'يجب أن تحتوي الفاتورة على بند واحد على الأقل!'
              : 'Invoice must contain at least one line item!',
          severity: AppSeverity.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payload = {
        'shipment_id': _shipmentId,
        'bl_number': _blNumberCtrl.text.trim().isEmpty ? null : _blNumberCtrl.text.trim(),
        'partner_id': _partnerId,
        'partner_type': _partnerType,
        'partner_name': _partnerNameCtrl.text.trim().isEmpty ? 'Logistics Partner' : _partnerNameCtrl.text.trim(),
        'invoice_number': _invoiceNumberCtrl.text.trim(),
        'invoice_date': _invoiceDate.toIso8601String(),
        'currency': _currency,
        'total_amount_fx': _subtotalFx,
        'exchange_rate': _exchangeRate,
        'total_amount_egp': _subtotalEgp,
        'vat_included': _vatIncluded,
        'vat_amount': _vatAmount,
        'wht_deducted': _whtDeducted,
        'wht_amount': _whtAmount,
        'net_payable_egp': _netPayableEgp,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'lines': _lines.map((l) => l.toJson()).toList(),
        'containers': _selectedContainers.map((c) => {'container_number': c}).toList(),
      };

      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      if (widget.initialInvoice == null) {
        await repo.createInvoice(payload);
      } else {
        await repo.updateInvoice(widget.initialInvoice!.invoiceId, payload);
      }

      ref.invalidate(logisticsInvoicesListProvider);
      if (mounted) {
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            isArabic
                ? 'تم حفظ الفاتورة بنجاح!'
                : 'Invoice saved successfully!',
            severity: AppSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'Failed to save invoice: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SelectionArea(
        child: Container(
          width: 1050,
          height: 750,
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InvoiceFormHeader(
                  initialInvoice: widget.initialInvoice,
                  partnerType: _partnerType,
                  isDark: isDark,
                  isArabic: isArabic,
                  onClose: () => Navigator.pop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_partnerId > 0) PartnerBalanceCard(partnerId: _partnerId),
                        InvoiceFormBasicFields(
                          isArabic: isArabic,
                          isEditMode: widget.initialInvoice != null,
                          partnerType: _partnerType,
                          onPartnerTypeChanged: (val) {
                            if (val != null) {
                              setState(() => _partnerType = val);
                              _loadPrefillLines();
                            }
                          },
                          invoiceNumberCtrl: _invoiceNumberCtrl,
                          partnerNameCtrl: _partnerNameCtrl,
                          shipmentId: _shipmentId,
                          importFiles: ref.watch(importFilesProvider).valueOrNull ?? const [],
                          blNumberCtrl: _blNumberCtrl,
                          onShipmentIdChanged: (id) {
                            setState(() => _shipmentId = id);
                            if (widget.initialInvoice == null) _loadPrefillLines();
                          },
                          onBlNumberChanged: (bl) => setState(() => _blNumber = bl),
                          currency: _currency,
                          onCurrencyChanged: (c) {
                            if (c != null) {
                              setState(() => _currency = c);
                              _fetchCbeRate();
                            }
                          },
                          exchangeRate: _exchangeRate,
                          onExchangeRateChanged: (rate) {
                            setState(() {
                              _exchangeRate = rate;
                              _recalculateTotals();
                            });
                          },
                          onFetchCbeRate: _fetchCbeRate,
                        ),
                        const SizedBox(height: 12),
                        if (_shipmentId != null && _blNumberCtrl.text.trim().isNotEmpty) ...[
                          BLContainerLockWidget(
                            shipmentId: _shipmentId!,
                            blNumber: _blNumberCtrl.text.trim(),
                            selectedContainerNumbers: _selectedContainers,
                            onContainersChanged: (c) => setState(() => _selectedContainers = c),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _partnerType == 'freight'
                                    ? (isArabic ? 'بنود الفاتورة (21 بند عرض أسعار)' : 'Invoice Line Items (21 Quotation Items)')
                                    : (isArabic ? 'بنود الفاتورة' : 'Invoice Line Items'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                if (_isPrefilling)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: AppLoadingState.inline(),
                                  ),
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: Text(isArabic ? 'إعادة تحميل' : 'Reload Prefill'),
                                  onPressed: _loadPrefillLines,
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add, size: 14),
                                  label: Text(isArabic ? 'إضافة بند مخصص' : 'Add Custom Item'),
                                  onPressed: _addEmptyLine,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InvoiceFormLinesTable(
                          lines: _lines,
                          currency: _currency,
                          exchangeRate: _exchangeRate,
                          isDark: isDark,
                          isArabic: isArabic,
                          onLineChanged: (index, line) {
                            _lines[index] = line;
                            _recalculateTotals();
                          },
                          onRemoveLine: _removeLine,
                        ),
                        const SizedBox(height: 16),
                        InvoiceFormTaxesTotals(
                          isDark: isDark,
                          isArabic: isArabic,
                          vatIncluded: _vatIncluded,
                          onVatChanged: (val) {
                            setState(() {
                              _vatIncluded = val;
                              _vatAmount = _vatIncluded ? (_subtotalEgp * 0.14) : 0.0;
                            });
                          },
                          whtDeducted: _whtDeducted,
                          onWhtChanged: (val) {
                            setState(() {
                              _whtDeducted = val;
                              _whtAmount = _whtDeducted ? (_subtotalEgp * 0.01) : 0.0;
                            });
                          },
                          subtotalFx: _subtotalFx,
                          subtotalEgp: _subtotalEgp,
                          vatAmount: _vatAmount,
                          whtAmount: _whtAmount,
                          netPayableEgp: _netPayableEgp,
                          currency: _currency,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      label: isArabic ? 'حفظ الفاتورة' : 'Save Invoice',
                      variant: AppButtonVariant.primary,
                      icon: Icons.check,
                      isLoading: _isLoading,
                      onPressed: _saveInvoice,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
