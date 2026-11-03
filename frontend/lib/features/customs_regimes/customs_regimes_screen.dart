import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/searchable_dropdown_field.dart';
import '../../core/widgets/buttons/app_button.dart';
import '../../core/widgets/vertical_stage_scaffold.dart';
import 'customs_regimes_provider.dart';
import 'widgets/guarantee_bond_tracking_table.dart';
import 'widgets/re_export_reconciliation_card.dart';
import 'widgets/regime_selection_stepper.dart';

class CustomsRegimesScreen extends ConsumerStatefulWidget {
  final int? importFileId;

  const CustomsRegimesScreen({super.key, this.importFileId});

  @override
  ConsumerState<CustomsRegimesScreen> createState() => _CustomsRegimesScreenState();
}

class _CustomsRegimesScreenState extends ConsumerState<CustomsRegimesScreen> {
  int _selectedTabIndex = 0;
  String _selectedRegimeType = 'TEMPORARY_ADMISSION';
  CustomsRegimeItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(customsRegimesProvider.notifier).fetchRegimes(
            fileId: widget.importFileId,
            regimeType: _selectedRegimeType,
          );
    });
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedRegimeType = type;
      _selectedItem = null;
    });
    ref.read(customsRegimesProvider.notifier).fetchRegimes(
          fileId: widget.importFileId,
          regimeType: type,
        );
  }

  void _showAddRegimeDialog() {
    final amountController = TextEditingController();
    final bankController = TextEditingController();
    final refController = TextEditingController();
    final formNoController = TextEditingController();
    final officeController = TextEditingController();
    String guaranteeType = 'LETTER_OF_GUARANTEE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسجيل نظام جمركي معلق جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<String>(
                    labelText: 'نوع الضمان / الأمانة',
                    value: guaranteeType,
                    decoration: const InputDecoration(labelText: 'نوع الضمان / الأمانة'),
                    items: const [
                      SearchableDropdownItem(value: 'LETTER_OF_GUARANTEE', label: 'خطاب ضمان بنكي'),
                      SearchableDropdownItem(value: 'CASH_DEPOSIT', label: 'أمانة نقدية معلقة'),
                      SearchableDropdownItem(value: 'INSURANCE_POLICY', label: 'وثيقة تأمين'),
                      SearchableDropdownItem(value: 'PROMISSORY_NOTE', label: 'سند لأمر'),
                    ],
                    onChanged: (v) => setDialogState(() => guaranteeType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bankController,
                    decoration: const InputDecoration(labelText: 'اسم البنك الضامن'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(labelText: 'رقم مرجع الضمان / الإيصال'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'قيمة الضمان الجمركي المعلق'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: formNoController,
                    decoration: const InputDecoration(labelText: 'رقم نموذج الإفراج المؤقت'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: officeController,
                    decoration: const InputDecoration(labelText: 'المنفذ الجمركي المختص'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'حفظ وتثبيت',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final amt = double.tryParse(amountController.text) ?? 0.0;
                final success = await ref.read(customsRegimesProvider.notifier).createRegime({
                  'import_file_id': widget.importFileId ?? 1,
                  'regime_type': _selectedRegimeType,
                  'status': 'ACTIVE',
                  'guarantee_type': guaranteeType,
                  'guarantee_bank': bankController.text,
                  'guarantee_reference': refController.text,
                  'guarantee_amount': amt,
                  'release_form_number': formNoController.text,
                  'customs_office': officeController.text,
                  're_export_deadline': DateTime.now().add(const Duration(days: 365)).toIso8601String().substring(0, 10),
                });
                if (success && ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettleDialog(CustomsRegimeItem item) {
    final decNoController = TextEditingController();
    final refundController = TextEditingController();
    final drawbackRefController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تسوية وإغلاق النظام: ${item.regimeCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: decNoController,
                decoration: const InputDecoration(labelText: 'رقم شهادة الصادر الجمركية'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: drawbackRefController,
                decoration: const InputDecoration(labelText: 'رقم ملف تسوية رد الرسوم'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refundController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ المسترد بالجنيه'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'تأكيد التسوية',
            variant: AppButtonVariant.success,
            onPressed: () async {
              final refund = double.tryParse(refundController.text) ?? 0.0;
              final success = await ref.read(customsRegimesProvider.notifier).settleRegime(item.id, {
                'actual_re_export_date': DateTime.now().toIso8601String().substring(0, 10),
                're_export_export_declaration_no': decNoController.text,
                'drawback_reconciliation_ref': drawbackRefController.text,
                'drawback_refund_amount': refund,
                'reconciled_date': DateTime.now().toIso8601String().substring(0, 10),
              });
              if (success && ctx.mounted) {
                Navigator.of(ctx).pop();
                setState(() => _selectedItem = null);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customsRegimesProvider);

    const tabs = [
      VerticalNavTabItem(
        icon: Icons.account_balance_outlined,
        titleAr: 'الأنظمة المعلقة والضمانات',
        titleEn: 'Suspended Regimes',
      ),
      VerticalNavTabItem(
        icon: Icons.sync_alt_outlined,
        titleAr: 'مهل إعادة التصدير والرد',
        titleEn: 'Re-export & Drawback',
      ),
    ];

    Widget body;
    if (state.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_selectedTabIndex == 0) {
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RegimeSelectionStepper(
              selectedType: _selectedRegimeType,
              onTypeChanged: _onTypeChanged,
              onAddNew: _showAddRegimeDialog,
            ),
            if (_selectedItem != null)
              ReExportReconciliationCard(
                item: _selectedItem!,
                onSettlePressed: () => _showSettleDialog(_selectedItem!),
              ),
            const SizedBox(height: 8),
            GuaranteeBondTrackingTable(
              items: state.items,
              onSelect: (item) => setState(() => _selectedItem = item),
              onSettle: _showSettleDialog,
            ),
          ],
        ),
      );
    } else {
      body = SingleChildScrollView(
        child: Column(
          children: state.items
              .map((it) => ReExportReconciliationCard(
                    item: it,
                    onSettlePressed: () => _showSettleDialog(it),
                  ))
              .toList(),
        ),
      );
    }

    return SelectionArea(
      child: VerticalStageScaffold(
        stageCode: 'CUSTOMS_REGIMES',
        titleAr: 'النظم الجمركية المعلقة والمناطق الحرة',
        titleEn: 'Suspended Customs Regimes',
        headerIcon: Icons.account_balance_outlined,
        headerColor: AppTheme.cobalt,
        tabs: tabs,
        selectedIndex: _selectedTabIndex,
        onTabSelected: (idx) => setState(() => _selectedTabIndex = idx),
        headerActions: [
          AppButton(
            label: 'تحديث البيانات',
            icon: Icons.refresh,
            variant: AppButtonVariant.ghost,
            onPressed: () => ref.read(customsRegimesProvider.notifier).fetchRegimes(
                  fileId: widget.importFileId,
                  regimeType: _selectedRegimeType,
                ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'تسجيل نظام جديد',
            icon: Icons.add,
            variant: AppButtonVariant.primary,
            onPressed: _showAddRegimeDialog,
          ),
        ],
        body: body,
      ),
    );
  }
}
