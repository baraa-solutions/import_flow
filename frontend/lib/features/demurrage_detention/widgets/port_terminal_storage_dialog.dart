import '../../../core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/port_storage_model.dart';
import '../services/port_storage_service.dart';

class PortTerminalStorageDialog extends ConsumerStatefulWidget {
  final String? initialTerminal;
  final String? initialGateInDate;

  const PortTerminalStorageDialog({
    super.key,
    this.initialTerminal,
    this.initialGateInDate,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialTerminal,
    String? initialGateInDate,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PortTerminalStorageDialog(
        initialTerminal: initialTerminal,
        initialGateInDate: initialGateInDate,
      ),
    );
  }

  @override
  ConsumerState<PortTerminalStorageDialog> createState() => _PortTerminalStorageDialogState();
}

class _PortTerminalStorageDialogState extends ConsumerState<PortTerminalStorageDialog> {
  String _selectedTerminal = 'ACCHCO';
  String _containerSize = '20ft';
  bool _isReefer = false;
  bool _includeXray = true;
  bool _includeScale = true;

  DateTime _gateInDate = DateTime.now().subtract(const Duration(days: 12));
  DateTime _currentDate = DateTime.now();

  PortStorageBreakdownModel? _breakdown;
  bool _isCalculating = false;
  String? _errorMessage;

  final Map<String, String> _terminals = {
    'ACCHCO': 'شركة الإسكندرية لتداول الحاويات (ACCHCO - الدخيلة والإسكندرية)',
    'DP_WORLD_SOKHNA': 'موانئ دبي العالمية - السخنة (DP World Sokhna)',
    'DCHC': 'شركة دمياط لتداول الحاويات والبضائع (DCHC)',
    'SCCT': 'شركة قناة السويس للحاويات (SCCT - شرق بورسعيد)',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialTerminal != null && _terminals.containsKey(widget.initialTerminal)) {
      _selectedTerminal = widget.initialTerminal!;
    }
    if (widget.initialGateInDate != null) {
      final parsed = DateTime.tryParse(widget.initialGateInDate!);
      if (parsed != null) _gateInDate = parsed;
    }
    _runCalculation();
  }

  String _formatDate(DateTime dt) => dt.toIso8601String().split('T').first;

  Future<void> _runCalculation() async {
    setState(() {
      _isCalculating = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(portStorageServiceProvider);
      final res = await service.calculateStorage(
        terminalCode: _selectedTerminal,
        containerSize: _containerSize,
        isReefer: _isReefer,
        gateInDate: _formatDate(_gateInDate),
        currentOrGateOutDate: _formatDate(_currentDate),
        includeXray: _includeXray,
        includeScale: _includeScale,
      );

      if (mounted) {
        setState(() {
          _breakdown = res;
          _isCalculating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isCalculating = false;
        });
      }
    }
  }

  void _copyBreakdownTsv() {
    if (_breakdown == null) return;
    final b = _breakdown!;
    final buffer = StringBuffer()
      ..writeln('محطة الميناء:\t${b.terminalName} (${b.terminalCode})')
      ..writeln('نوع ومقاس الحاوية:\t${b.containerSize} ${b.isReefer ? "مبردة" : ""}')
      ..writeln('تاريخ الدخول:\t${b.gateInDate}')
      ..writeln('تاريخ الاحتساب:\t${b.endDate}')
      ..writeln('إجمالي الأيام:\t${b.totalDays} يوم (سماح: ${b.freeDaysAllowed} يوم | خاضع: ${b.chargeableDays} يوم)')
      ..writeln('الشريحة الأولى (4-8):\t${b.tier1Days} يوم × ${b.tier1Rate} = ${b.tier1Amount} ج.م')
      ..writeln('الشريحة الثانية (9-15):\t${b.tier2Days} يوم × ${b.tier2Rate} = ${b.tier2Amount} ج.م')
      ..writeln('الشريحة العقابية (16+):\t${b.penalDays} يوم × ${b.penalRate} = ${b.penalAmount} ج.م')
      ..writeln('رسوم كهرباء ومراقبة تبريد:\t${b.reeferPluggingChargesEgp} ج.م')
      ..writeln('رسوم كشف إشعاعي وميزان:\t${b.xrayScanFeeEgp + b.scaleFeeEgp} ج.م')
      ..writeln('إجمالي أرضيات المحطة:\t${b.totalPortStorageEgp} ج.م');

    CopyHelper.copy(context, buffer.toString(), customMessage: 'تم نسخ تفاصيل أرضيات المحطة بنجاح');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: SelectionArea(
        child: Container(
        width: 950,
        height: 680,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.charcoal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined, color: AppTheme.cobalt, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'حاسبة ومحرك أرضيات محطات الموانئ المصرية (Port Terminal Storage Engine)',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'احتساب دقيق لشرائح التخزين التصاعدية لمحطات الإسكندرية، دمياط، السخنة، وشرق بورسعيد',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: SelectionArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Controls Column (Left)
                      SizedBox(
                        width: 360,
                        child: Material(
                          color: Colors.transparent,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'بيانات الحاوية والمحطة',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                                ),
                                const SizedBox(height: 12),

                                // Terminal Dropdown
                                const Text('محطة التداول الجمركية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedTerminal,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  items: _terminals.entries.map((e) {
                                    return DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedTerminal = val);
                                      _runCalculation();
                                    }
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Container Size & Reefer Toggle
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('حجم الحاوية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          DropdownButtonFormField<String>(
                                            initialValue: _containerSize,
                                            isExpanded: true,
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: '20ft', child: Text('20 قدم (20ft)')),
                                            DropdownMenuItem(value: '40ft', child: Text('40 قدم (40ft)')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _containerSize = val);
                                              _runCalculation();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('النوع:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        CheckboxListTile(
                                          title: const Text('مبردة (Reefer)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                          value: _isReefer,
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          onChanged: (val) {
                                            setState(() => _isReefer = val ?? false);
                                            _runCalculation();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Dates
                              AppDatePickerField(
                                label: 'تاريخ الدخول والتفريغ بالمحطة',
                                value: _gateInDate,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _gateInDate = val);
                                    _runCalculation();
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              AppDatePickerField(
                                label: 'تاريخ الاحتساب أو الخروج من الدائرة',
                                value: _currentDate,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _currentDate = val);
                                    _runCalculation();
                                  }
                                },
                              ),
                              const SizedBox(height: 14),

                              // Surcharges Checkboxes
                              const Text('رسوم المحطة الميدانية الإلزامية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              CheckboxListTile(
                                title: const Text('رسم الكشف بالأشعة (X-Ray Fee)', style: TextStyle(fontSize: 12)),
                                value: _includeXray,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) {
                                  setState(() => _includeXray = val ?? true);
                                  _runCalculation();
                                },
                              ),
                              CheckboxListTile(
                                title: const Text('رسم الميزان البسكول (Weighbridge Scale)', style: TextStyle(fontSize: 12)),
                                value: _includeScale,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) {
                                  setState(() => _includeScale = val ?? true);
                                  _runCalculation();
                                },
                              ),
                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                child: AppButton(
                                  label: 'إعادة احتساب الرسوم',
                                  icon: Icons.calculate_rounded,
                                  variant: AppButtonVariant.primary,
                                  onPressed: _isCalculating ? null : _runCalculation,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                      const VerticalDivider(width: 32),

                      // Breakdown & Results Column (Right)
                      Expanded(
                        child: _isCalculating
                            ? const Center(child: CircularProgressIndicator())
                            : _errorMessage != null
                                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                                : _breakdown == null
                                    ? const Center(child: Text('يرجى تحديد المعطيات للاحتساب'))
                                    : SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        _breakdown!.terminalName,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.cobalt),
                                                      ),
                                                      Text(
                                                        'إجمالي الأيام: ${_breakdown!.totalDays} يوم (أيام السماح: ${_breakdown!.freeDaysAllowed} | الخاضعة: ${_breakdown!.chargeableDays} يوم)',
                                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                AppButton(
                                                  label: 'نسخ الحسبة',
                                                  icon: Icons.copy_rounded,
                                                  variant: AppButtonVariant.secondary,
                                                  size: AppButtonSize.small,
                                                  onPressed: _copyBreakdownTsv,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            // Grand Total Banner
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.shade900,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('إجمالي تكلفة أرضيات المحطة المستحقة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                                        Text('شاملة التخزين والخدمات التابعة', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${_breakdown!.totalPortStorageEgp.toStringAsFixed(2)} ج.م',
                                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            // Tiers Detail Card
                                            const Text('تفاصيل الشرائح التصاعدية للأرضيات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 8),

                                            _buildTierRow('شريحة السماح (الأيام 1 إلى 3):', '${_breakdown!.freeDaysAllowed} أيام', '0.00 ج.م', AppTheme.emerald),
                                            _buildTierRow(
                                              'الشريحة الأولى (الأيام 4 إلى 8):',
                                              '${_breakdown!.tier1Days} يوم × ${_breakdown!.tier1Rate} ج.م/يوم',
                                              '${_breakdown!.tier1Amount.toStringAsFixed(2)} ج.م',
                                              Colors.blueGrey.shade800,
                                            ),
                                            _buildTierRow(
                                              'الشريحة الثانية (الأيام 9 إلى 15):',
                                              '${_breakdown!.tier2Days} يوم × ${_breakdown!.tier2Rate} ج.م/يوم',
                                              '${_breakdown!.tier2Amount.toStringAsFixed(2)} ج.م',
                                              AppTheme.orange,
                                            ),
                                            _buildTierRow(
                                              'الشريحة العقابية (الأيام 16 فأكثر):',
                                              '${_breakdown!.penalDays} يوم × ${_breakdown!.penalRate} ج.م/يوم',
                                              '${_breakdown!.penalAmount.toStringAsFixed(2)} ج.م',
                                              AppTheme.crimson,
                                            ),

                                            const Divider(height: 20),

                                            // Additional Services Card
                                            const Text('رسوم الخدمات الإضافية بالمحطة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 8),

                                            if (_isReefer)
                                              _buildTierRow(
                                                'رسوم توصيل الكهرباء ومراقبة التبريد:',
                                                'شاملة فترة التخزين',
                                                '${_breakdown!.reeferPluggingChargesEgp.toStringAsFixed(2)} ج.م',
                                                AppTheme.cobalt,
                                              ),
                                            if (_includeXray)
                                              _buildTierRow(
                                                'رسم الفحص بأشعة الكشف:',
                                                'كشف إشعاعي للمحطة',
                                                '${_breakdown!.xrayScanFeeEgp.toStringAsFixed(2)} ج.م',
                                                Colors.black87,
                                              ),
                                            if (_includeScale)
                                              _buildTierRow(
                                                'رسم ميزان البسكول الجمركي:',
                                                'وزن المحطة عند الصرف',
                                                '${_breakdown!.scaleFeeEgp.toStringAsFixed(2)} ج.م',
                                                Colors.black87,
                                              ),
                                          ],
                                        ),
                                      ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTierRow(String title, String subtitle, String amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
