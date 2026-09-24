import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown_field.dart';
import '../../../core/services/table_export_service.dart';
import '../models/warehouse_receiving_model.dart';
import '../providers/warehouse_receiving_provider.dart';

class WarehouseInspectionDialog extends ConsumerStatefulWidget {
  final WarehouseReceivingModel record;
  final String? importFileCode;

  const WarehouseInspectionDialog({
    super.key,
    required this.record,
    this.importFileCode,
  });

  static Future<void> show(
    BuildContext context, {
    required WarehouseReceivingModel record,
    String? importFileCode,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WarehouseInspectionDialog(
        record: record,
        importFileCode: importFileCode,
      ),
    );
  }

  @override
  ConsumerState<WarehouseInspectionDialog> createState() => _WarehouseInspectionDialogState();
}

class _WarehouseInspectionDialogState extends ConsumerState<WarehouseInspectionDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _committeeCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _insuranceRefCtrl;
  late TextEditingController _supplierRefCtrl;
  late TextEditingController _claimAmountCtrl;

  late String _selectedVerdict;
  String? _selectedRootCause;
  late String _claimCurrency;
  late bool _quarantineAssigned;
  late bool _insuranceClaimFiled;
  late bool _supplierClaimFiled;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final rec = widget.record;
    final hasDiscrepancy = (rec.totalShortageQty + rec.totalDamagedQty) > 0;

    _committeeCtrl = TextEditingController(
      text: rec.inspectionCommittee ?? 'لجنة الفحص الفني والاستلام المخزني (م. كمال - رئيس اللجنة)',
    );
    _notesCtrl = TextEditingController(
      text: rec.discrepancyNotes ?? (hasDiscrepancy ? 'تم رصد فروقات أثناء تفريغ ومطابقة الشحنة.' : 'البضاعة كاملة وسليمة ومطابقة للفاتورة.'),
    );
    _insuranceRefCtrl = TextEditingController(text: rec.insuranceClaimRef ?? '');
    _supplierRefCtrl = TextEditingController(text: rec.supplierClaimRef ?? '');
    _claimAmountCtrl = TextEditingController(
      text: rec.claimAmountEstimated > 0 ? rec.claimAmountEstimated.toStringAsFixed(0) : '',
    );

    _selectedVerdict = rec.inspectionVerdict != 'PENDING'
        ? (rec.inspectionVerdict ?? 'ACCEPTED_FULL')
        : (hasDiscrepancy ? 'ACCEPTED_WITH_DISCREPANCY' : 'ACCEPTED_FULL');

    _selectedRootCause = rec.rootCause ?? (hasDiscrepancy ? 'Port Handling & Rough Unloading' : 'None - Clean Delivery');
    _claimCurrency = rec.claimCurrency;
    _quarantineAssigned = rec.quarantineZoneAssigned;
    _insuranceClaimFiled = rec.insuranceClaimFiled;
    _supplierClaimFiled = rec.supplierClaimFiled;
  }

  @override
  void dispose() {
    _committeeCtrl.dispose();
    _notesCtrl.dispose();
    _insuranceRefCtrl.dispose();
    _supplierRefCtrl.dispose();
    _claimAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportInspectionReport() async {
    final rec = widget.record;
    final headers = [
      'كود الصنف',
      'اسم الصنف',
      'كمية الفاتورة',
      'الكمية المقبولة',
      'العجز',
      'التالف',
      'الحالة',
    ];

    final rows = rec.grnItems.map((item) {
      final status = (item.shortageQty > 0 || item.damagedQty > 0) ? 'يوجد فروقات' : 'مطابق وسليم';
      return [
        item.itemCode,
        item.itemName,
        item.invoicedQty.toString(),
        item.acceptedQty.toString(),
        item.shortageQty.toString(),
        item.damagedQty.toString(),
        status,
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'Warehouse Inspection Protocol',
      importFileNameOrCode: widget.importFileCode ?? rec.grnCode,
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _submitProtocol() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final claimAmount = double.tryParse(_claimAmountCtrl.text.trim()) ?? 0.0;
      final payload = {
        'inspection_date': DateTime.now().toIso8601String(),
        'inspection_committee': _committeeCtrl.text.trim(),
        'inspection_verdict': _selectedVerdict,
        'root_cause': _selectedRootCause,
        'discrepancy_type': (_selectedVerdict == 'ACCEPTED_FULL')
            ? 'None'
            : (widget.record.totalShortageQty > 0 && widget.record.totalDamagedQty > 0
                ? 'Shortage & Damaged'
                : (widget.record.totalShortageQty > 0 ? 'Shortage' : 'Damage')),
        'discrepancy_notes': _notesCtrl.text.trim(),
        'quarantine_zone_assigned': _quarantineAssigned,
        'insurance_claim_filed': _insuranceClaimFiled,
        'insurance_claim_ref': _insuranceClaimFiled ? _insuranceRefCtrl.text.trim() : null,
        'supplier_claim_filed': _supplierClaimFiled,
        'supplier_claim_ref': _supplierClaimFiled ? _supplierRefCtrl.text.trim() : null,
        'claim_amount_estimated': claimAmount,
        'claim_currency': _claimCurrency,
      };

      await ref.read(warehouseReceivingProvider.notifier).submitInspectionProtocol(
            widget.record.receivingId,
            payload,
          );

      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم اعتماد محضر الفحص الفني والمطابقة بنجاح (${widget.record.grnCode})'),
          backgroundColor: AppTheme.emerald,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final rec = widget.record;
    final totalDiscrepancy = rec.totalShortageQty + rec.totalDamagedQty;
    final discrepancyRate = rec.totalInvoicedQty > 0
        ? (totalDiscrepancy / rec.totalInvoicedQty * 100).toStringAsFixed(1)
        : '0.0';

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cobalt.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user_rounded, color: AppTheme.cobalt, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'محضر الفحص الفني ومطابقة العجز والتالف (TR-04)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'إذن الإضافة: ${rec.grnCode} | الشحنة: ${widget.importFileCode ?? "IMP-FILE-${rec.importFileId}"}',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppTheme.charcoal.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const Key('exportInspectionProtocolBtn'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('تصدير المحضر Excel', style: TextStyle(fontSize: 12)),
            onPressed: _exportInspectionReport,
          ),
        ],
      ),
      content: SizedBox(
        width: 860,
        height: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. KPI Metric Strip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevatedSurface : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      _buildMetricTile('الكمية بالفاتورة', '${rec.totalInvoicedQty}', Colors.blueGrey),
                      _buildMetricTile('الكمية المقبولة', '${rec.totalAcceptedQty}', AppTheme.emerald),
                      _buildMetricTile('كمية العجز', '${rec.totalShortageQty}', totalDiscrepancy > 0 ? AppTheme.orange : Colors.grey),
                      _buildMetricTile('كمية التالف', '${rec.totalDamagedQty}', rec.totalDamagedQty > 0 ? AppTheme.crimson : Colors.grey),
                      _buildMetricTile('نسبة الفروقات', '$discrepancyRate%', totalDiscrepancy > 0 ? AppTheme.crimson : AppTheme.emerald),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Line Items Table Preview
                if (rec.grnItems.isNotEmpty) ...[
                  const Text(
                    'مطابقة بنود وأصناف الشحنة:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 30,
                        dataRowMaxHeight: 32,
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('كود الصنف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('اسم الصنف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الفاتورة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('المقبول', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('العجز', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('التالف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                        rows: rec.grnItems.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item.itemCode, style: const TextStyle(fontSize: 11))),
                            DataCell(Text(item.itemName, style: const TextStyle(fontSize: 11))),
                            DataCell(Text('${item.invoicedQty}', style: const TextStyle(fontSize: 11))),
                            DataCell(Text('${item.acceptedQty}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald))),
                            DataCell(Text('${item.shortageQty}', style: TextStyle(fontSize: 11, color: item.shortageQty > 0 ? AppTheme.orange : null))),
                            DataCell(Text('${item.damagedQty}', style: TextStyle(fontSize: 11, color: item.damagedQty > 0 ? AppTheme.crimson : null))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Inspection Committee & Verdict
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _committeeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'لجنة الفحص الفني والاستلام *',
                          prefixIcon: Icon(Icons.people_alt_outlined, size: 18),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال أسماء أعضاء اللجنة' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        value: _selectedVerdict,
                        labelText: 'قرار ونتيجة الفحص *',
                        items: const [
                          SearchableDropdownItem(value: 'ACCEPTED_FULL', label: '🟢 قبول كامل ومطابق (سليم)'),
                          SearchableDropdownItem(value: 'ACCEPTED_WITH_DISCREPANCY', label: '🟡 قبول مع إثبات عجز/تالف'),
                          SearchableDropdownItem(value: 'REJECTED_QUARANTINED', label: '🔴 رفض وحجز في منطقة الحجر'),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedVerdict = v;
                              if (v == 'REJECTED_QUARANTINED') {
                                _quarantineAssigned = true;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. Root Cause and Notes
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: SearchableDropdownField<String>(
                        value: _selectedRootCause ?? 'None - Clean Delivery',
                        labelText: 'السبب الجذري للفروقات والتلفيات',
                        items: const [
                          SearchableDropdownItem(value: 'None - Clean Delivery', label: 'سليم - لا توجد تلفيات أو عجز'),
                          SearchableDropdownItem(value: 'Port Handling & Rough Unloading', label: 'سوء مناولة وتفريغ بالميناء'),
                          SearchableDropdownItem(value: 'Inland Transit Vibration & Shock', label: 'اهتزازات وسوء نقل بري للشاحنة'),
                          SearchableDropdownItem(value: 'Supplier Packaging Defect', label: 'سوء تعبئة وتغليف من المورد'),
                          SearchableDropdownItem(value: 'Container Water Ingress & Humidity', label: 'تسريب مياه ورطوبة بالحاوية'),
                          SearchableDropdownItem(value: 'Supplier Factory Shortage', label: 'عجز مصنعي في الشحن من المصنع'),
                          SearchableDropdownItem(value: 'Other / Under Investigation', label: 'أسباب أخرى / قيد التحقيق'),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedRootCause = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات الفحص ومحضر المعاينة الفنية *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى تدوين الملاحظات الفنية' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 5. Insurance & Supplier Claims Panel
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkElevatedSurface : Colors.amber.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 18, color: AppTheme.orange),
                          SizedBox(width: 6),
                          Text(
                            'إجراءات المطالبات والتعويضات والعزل:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                              title: const Text('رفع مطالبة تأمين بحري/نقل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              value: _insuranceClaimFiled,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setState(() => _insuranceClaimFiled = v ?? false),
                            )),
                          ),
                          Expanded(
                            child: Material(type: MaterialType.transparency, child: CheckboxListTile(
                              title: const Text('طلب إشعار دائن (Credit Note) من المورد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              value: _supplierClaimFiled,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setState(() => _supplierClaimFiled = v ?? false),
                            )),
                          ),
                          Expanded(
                            child: Material(type: MaterialType.transparency, child: SwitchListTile(
                              title: const Text('عزل الأصناف التالفة في منطقة الحجر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              value: _quarantineAssigned,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setState(() => _quarantineAssigned = v),
                            )),
                          ),
                        ],
                      ),
                      if (_insuranceClaimFiled || _supplierClaimFiled) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_insuranceClaimFiled) ...[
                              Expanded(
                                child: TextFormField(
                                  controller: _insuranceRefCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم مرجع مطالبة التأمين',
                                    prefixIcon: Icon(Icons.tag, size: 16),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (_supplierClaimFiled) ...[
                              Expanded(
                                child: TextFormField(
                                  controller: _supplierRefCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم إشعار خصم/مطالبة المورد',
                                    prefixIcon: Icon(Icons.receipt_long, size: 16),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _claimAmountCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'قيمة التعويض التقديرية',
                                        prefixIcon: Icon(Icons.attach_money, size: 16),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      value: _claimCurrency,
                                      decoration: const InputDecoration(
                                        labelText: 'العملة',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'EGP', child: Text('EGP')),
                                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _claimCurrency = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        ElevatedButton.icon(
          key: const Key('certifyInspectionProtocolBtn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cobalt,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.verified, size: 18),
          label: const Text('اعتماد محضر الفحص الفني (TR-04)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _isLoading ? null : _submitProtocol,
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
