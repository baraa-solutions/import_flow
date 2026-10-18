import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../models/logistics_invoice_models.dart';
import '../providers/logistics_invoices_provider.dart';
import '../repositories/logistics_invoices_repository.dart';
import 'bl_container_lock_widget.dart';
import 'partner_balance_card.dart';

class InvoiceFormDialog extends ConsumerStatefulWidget {
  final LogisticsInvoiceModel? initialInvoice;
  final String defaultPartnerType;
  final int? initialShipmentId;
  final String? initialBlNumber;

  const InvoiceFormDialog({
    super.key,
    this.initialInvoice,
    this.defaultPartnerType = 'freight',
    this.initialShipmentId,
    this.initialBlNumber,
  });

  @override
  ConsumerState<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends ConsumerState<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late int _shipmentId;
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
  late TextEditingController _shipmentIdCtrl;
  late TextEditingController _blNumberCtrl;
  late TextEditingController _partnerIdCtrl;
  late TextEditingController _partnerNameCtrl;
  late TextEditingController _invoiceNumberCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final inv = widget.initialInvoice;

    _shipmentId = inv?.shipmentId ?? widget.initialShipmentId ?? 1;
    _blNumber = inv?.blNumber ?? widget.initialBlNumber ?? '';
    _partnerId = inv?.partnerId ?? 1;
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

    _shipmentIdCtrl = TextEditingController(text: _shipmentId.toString());
    _blNumberCtrl = TextEditingController(text: _blNumber);
    _partnerIdCtrl = TextEditingController(text: _partnerId.toString());
    _partnerNameCtrl = TextEditingController(text: _partnerName);
    _invoiceNumberCtrl = TextEditingController(text: _invoiceNumber);
    _notesCtrl = TextEditingController(text: _notes ?? '');

    if (inv == null && _lines.isEmpty) {
      _loadPrefillLines();
    }
  }

  @override
  void dispose() {
    _shipmentIdCtrl.dispose();
    _blNumberCtrl.dispose();
    _partnerIdCtrl.dispose();
    _partnerNameCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefillLines() async {
    setState(() => _isPrefilling = true);
    try {
      final repo = ref.read(logisticsInvoicesRepositoryProvider);
      final prefill = await repo.getPrefillLines(_shipmentId, _partnerType);
      setState(() {
        _currency = prefill.currency;
        _exchangeRate = prefill.exchangeRate;
        _lines = prefill.lines;
        _recalculateTotals();
      });
    } catch (_) {
      // Use defaults if prefill fails
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
          SnackBar(content: Text('CBE Exchange Rate updated: $rate EGP')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch CBE rate: $e'), backgroundColor: Colors.red),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice must contain at least one line item!'), backgroundColor: Colors.red),
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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save invoice: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _partnerTypeLabel(bool isArabic) {
    switch (_partnerType) {
      case 'clearance':
        return isArabic ? 'تخليص جمركي' : 'Customs Clearance';
      case 'transport':
        return isArabic ? 'نقل داخلي' : 'Inland Transport';
      case 'inspection':
        return isArabic ? 'فحص ومعاينة' : 'Inspection';
      case 'insurance':
        return isArabic ? 'تأمين بحري' : 'Marine Insurance';
      case 'freight':
      default:
        return isArabic ? 'شحن ونولون' : 'Freight';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 1050,
        height: 750,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    _partnerType == 'freight'
                        ? Icons.directions_boat_outlined
                        : _partnerType == 'clearance'
                            ? Icons.assignment_outlined
                            : _partnerType == 'transport'
                                ? Icons.local_shipping_outlined
                                : _partnerType == 'insurance'
                                    ? Icons.shield_outlined
                                    : Icons.verified_outlined,
                    color: AppTheme.cobalt,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.initialInvoice == null
                        ? (isArabic
                            ? 'تسجيل فاتورة جديدة (${_partnerTypeLabel(isArabic)})'
                            : 'New ${_partnerTypeLabel(isArabic)} Service Invoice')
                        : (isArabic
                            ? 'تعديل فاتورة: ${widget.initialInvoice!.invoiceCode}'
                            : 'Edit Invoice: ${widget.initialInvoice!.invoiceCode}'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.charcoal,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Body content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Partner Balance Card Strip
                      if (_partnerId > 0) PartnerBalanceCard(partnerId: _partnerId),

                      // Basic Details Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: const ['freight', 'clearance', 'transport', 'inspection', 'insurance'].contains(_partnerType)
                                  ? _partnerType
                                  : 'freight',
                              decoration: InputDecoration(
                                labelText: isArabic ? 'نوع الشريك اللوجستي' : 'Partner Type',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(value: 'freight', child: Text(isArabic ? 'شركة شحن ونولون' : 'Freight Forwarder')),
                                DropdownMenuItem(value: 'clearance', child: Text(isArabic ? 'مخلص جمركي' : 'Customs Broker')),
                                DropdownMenuItem(value: 'transport', child: Text(isArabic ? 'نقل داخلي' : 'Inland Transport')),
                                DropdownMenuItem(value: 'inspection', child: Text(isArabic ? 'جهة فحص ومعاينة' : 'Inspection Agency')),
                                DropdownMenuItem(value: 'insurance', child: Text(isArabic ? 'شركة تأمين بحري' : 'Marine Insurance')),
                              ],
                              onChanged: widget.initialInvoice != null
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() => _partnerType = val);
                                        _loadPrefillLines();
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _invoiceNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Invoice Number *',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _partnerNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Partner Name *',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Shipment, B/L, Currency, and CBE Exchange Rate Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _shipmentIdCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Shipment ID *',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final parsed = int.tryParse(v);
                                if (parsed != null && parsed != _shipmentId) {
                                  setState(() => _shipmentId = parsed);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _blNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: 'B/L Number (رقم البوليصة)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => setState(() => _blNumber = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: _currency,
                              decoration: const InputDecoration(
                                labelText: 'Currency',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                                DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                                DropdownMenuItem(value: 'EGP', child: Text('EGP (ج.م)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _currency = val);
                                  _fetchCbeRate();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: _exchangeRate.toString(),
                              decoration: InputDecoration(
                                labelText: 'Exchange Rate',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.sync, size: 16),
                                  tooltip: 'Fetch CBE Rate',
                                  onPressed: _fetchCbeRate,
                                ),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) {
                                final r = double.tryParse(v);
                                if (r != null) {
                                  setState(() {
                                    _exchangeRate = r;
                                    _recalculateTotals();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Container Billing Lock Widget
                      if (_blNumberCtrl.text.trim().isNotEmpty) ...[
                        BLContainerLockWidget(
                          shipmentId: _shipmentId,
                          blNumber: _blNumberCtrl.text.trim(),
                          selectedContainerNumbers: _selectedContainers,
                          onContainersChanged: (c) => setState(() => _selectedContainers = c),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Lines Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _partnerType == 'freight'
                                ? 'Invoice Line Items (21 Quotation Items)'
                                : 'Invoice Line Items',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Row(
                            children: [
                              if (_isPrefilling)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('Reload Prefill'),
                                onPressed: _loadPrefillLines,
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Add Custom Item'),
                                onPressed: _addEmptyLine,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Line Items Table
                      _buildLinesTable(isDark),
                      const SizedBox(height: 16),

                      // Taxes & Summary Row
                      _buildTaxesAndTotalsCard(isDark),
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Save Invoice',
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
    );
  }

  Widget _buildLinesTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3.5), // Description
          1: FlexColumnWidth(1.2), // Group / Category
          2: FlexColumnWidth(1.0), // Qty
          3: FlexColumnWidth(1.4), // Unit Price FX
          4: FlexColumnWidth(1.4), // Amount FX
          5: FlexColumnWidth(1.5), // Amount EGP
          6: FixedColumnWidth(44), // Action
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2630) : const Color(0xFFEDF2F7),
            ),
            children: const [
              Padding(padding: EdgeInsets.all(8), child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('Total FX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('Total EGP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          for (int i = 0; i < _lines.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i % 2 == 1
                    ? (isDark ? const Color(0xFF141A22) : const Color(0xFFF8FAFC))
                    : Colors.transparent,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: TextFormField(
                    initialValue: _lines[i].lineDescription,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: (v) => _lines[i] = LogisticsInvoiceLineModel(
                      lineId: _lines[i].lineId,
                      expenseCode: _lines[i].expenseCode,
                      lineDescription: v,
                      lineGroup: _lines[i].lineGroup,
                      quantity: _lines[i].quantity,
                      unitPriceFx: _lines[i].unitPriceFx,
                      currency: _currency,
                      exchangeRate: _exchangeRate,
                      taxType: _lines[i].taxType,
                      isFromQuotation: _lines[i].isFromQuotation,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    _lines[i].lineGroup ?? 'Other',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: TextFormField(
                    initialValue: _lines[i].quantity.toString(),
                    style: const TextStyle(fontSize: 12),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: (v) {
                      final q = double.tryParse(v);
                      if (q != null) {
                        _lines[i] = LogisticsInvoiceLineModel(
                          lineId: _lines[i].lineId,
                          expenseCode: _lines[i].expenseCode,
                          lineDescription: _lines[i].lineDescription,
                          lineGroup: _lines[i].lineGroup,
                          quantity: q,
                          unitPriceFx: _lines[i].unitPriceFx,
                          currency: _currency,
                          exchangeRate: _exchangeRate,
                          taxType: _lines[i].taxType,
                          isFromQuotation: _lines[i].isFromQuotation,
                        );
                        _recalculateTotals();
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: TextFormField(
                    initialValue: _lines[i].unitPriceFx.toString(),
                    style: const TextStyle(fontSize: 12),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: (v) {
                      final p = double.tryParse(v);
                      if (p != null) {
                        _lines[i] = LogisticsInvoiceLineModel(
                          lineId: _lines[i].lineId,
                          expenseCode: _lines[i].expenseCode,
                          lineDescription: _lines[i].lineDescription,
                          lineGroup: _lines[i].lineGroup,
                          quantity: _lines[i].quantity,
                          unitPriceFx: p,
                          currency: _currency,
                          exchangeRate: _exchangeRate,
                          taxType: _lines[i].taxType,
                          isFromQuotation: _lines[i].isFromQuotation,
                        );
                        _recalculateTotals();
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    '${_lines[i].amountFx.toStringAsFixed(2)} $_currency',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    '${_lines[i].amountEgp.toStringAsFixed(2)} EGP',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  onPressed: () => _removeLine(i),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTaxesAndTotalsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A222D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tax Toggles
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  title: const Text('Add 14% VAT (ضريبة القيمة المضافة)', style: TextStyle(fontSize: 12)),
                  value: _vatIncluded,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    setState(() {
                      _vatIncluded = v ?? false;
                      _vatAmount = _vatIncluded ? (_subtotalEgp * 0.14) : 0.0;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Deduct WHT Form 41 (خصم أرباح تجارية 1% / 3%)', style: TextStyle(fontSize: 12)),
                  value: _whtDeducted,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    setState(() {
                      _whtDeducted = v ?? false;
                      _whtAmount = _whtDeducted ? (_subtotalEgp * 0.01) : 0.0;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Totals summary
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _summaryRow('Subtotal (FX):', '${_subtotalFx.toStringAsFixed(2)} $_currency'),
                _summaryRow('Subtotal (EGP):', '${_subtotalEgp.toStringAsFixed(2)} EGP'),
                if (_vatIncluded) _summaryRow('VAT Amount (+):', '${_vatAmount.toStringAsFixed(2)} EGP', color: Colors.blue),
                if (_whtDeducted) _summaryRow('WHT Deducted (-):', '${_whtAmount.toStringAsFixed(2)} EGP', color: Colors.orange),
                const Divider(height: 14),
                _summaryRow('Net Payable (EGP):', '${_netPayableEgp.toStringAsFixed(2)} EGP', isBold: true, color: AppTheme.emerald),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
