import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/searchable_dropdown_field.dart';
import '../../core/widgets/app_status_badge.dart';
import '../../core/widgets/buttons/app_button.dart';
import '../../core/widgets/copyable_data_helper.dart';
import '../../core/widgets/master_data_toolbar.dart';
import '../../core/widgets/page_header.dart';
import 'trade_agreements_provider.dart';
import 'widgets/certificate_authenticity_checklist.dart';
import 'widgets/provisional_escrow_calculator_card.dart';

class TradeAgreementsScreen extends ConsumerStatefulWidget {
  final int? importFileId;

  const TradeAgreementsScreen({super.key, this.importFileId});

  @override
  ConsumerState<TradeAgreementsScreen> createState() => _TradeAgreementsScreenState();
}

class _TradeAgreementsScreenState extends ConsumerState<TradeAgreementsScreen> {
  TradeAgreementItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tradeAgreementsProvider.notifier).fetchVerifications(fileId: widget.importFileId);
    });
  }

  void _showAddCertificateDialog() {
    final certNoController = TextEditingController();
    final countryController = TextEditingController();
    final authorityController = TextEditingController();
    final escrowAmtController = TextEditingController();
    final escrowReceiptController = TextEditingController();
    String agreement = 'EUR1';
    String certType = 'EUR.1';
    bool escrowReq = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسجيل شهادة منشأ تفضيلية جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdownField<String>(
                    labelText: 'الاتفاقية التفضيلية',
                    value: agreement,
                    decoration: const InputDecoration(labelText: 'الاتفاقية التفضيلية'),
                    items: const [
                      SearchableDropdownItem(value: 'EUR1', label: 'الشراكة المصرية الأوروبية'),
                      SearchableDropdownItem(value: 'GAFTA', label: 'منطقة التجارة العربية الكبرى'),
                      SearchableDropdownItem(value: 'AGADIR', label: 'اتفاقية أغادير'),
                      SearchableDropdownItem(value: 'COMESA', label: 'الكوميسا'),
                      SearchableDropdownItem(value: 'TURKEY', label: 'التجارة الحرة مع تركيا'),
                      SearchableDropdownItem(value: 'MERCOSUR', label: 'الميركوسور'),
                    ],
                    onChanged: (v) => setDialogState(() => agreement = v!),
                  ),
                  const SizedBox(height: 10),
                  SearchableDropdownField<String>(
                    labelText: 'نموذج شهادة المنشأ',
                    value: certType,
                    decoration: const InputDecoration(labelText: 'نموذج شهادة المنشأ'),
                    items: const [
                      SearchableDropdownItem(value: 'EUR.1', label: 'شهادة يورو 1'),
                      SearchableDropdownItem(value: 'EUR_MED', label: 'شهادة يورو متوسطية'),
                      SearchableDropdownItem(value: 'FORM_A', label: 'نموذج أ كوميسا'),
                      SearchableDropdownItem(value: 'ARAB_LEAGUE', label: 'شهادة المنشأ العربية'),
                      SearchableDropdownItem(value: 'CERTIFICATE_OF_ORIGIN', label: 'شهادة منشأ عامة'),
                    ],
                    onChanged: (v) => setDialogState(() => certType = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: certNoController, decoration: const InputDecoration(labelText: 'رقم شهادة المنشأ')),
                  const SizedBox(height: 10),
                  TextField(controller: countryController, decoration: const InputDecoration(labelText: 'دولة الإصدار')),
                  const SizedBox(height: 10),
                  TextField(controller: authorityController, decoration: const InputDecoration(labelText: 'الجهة المصدرة')),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('طلب أمانة جمركية مؤقتة لتأخر الأصل'),
                    value: escrowReq,
                    onChanged: (v) => setDialogState(() => escrowReq = v),
                  ),
                  if (escrowReq) ...[
                    TextField(
                      controller: escrowAmtController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'قيمة الأمانة النقدية المطلوبة بالجنيه'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: escrowReceiptController,
                      decoration: const InputDecoration(labelText: 'رقم قسيمة سداد الأمانة'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'حفظ وتثبيت',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final amt = double.tryParse(escrowAmtController.text) ?? 0.0;
                final now = DateTime.now();
                final success = await ref.read(tradeAgreementsProvider.notifier).createVerification({
                  'import_file_id': widget.importFileId ?? 1,
                  'agreement_name': agreement,
                  'certificate_type': certType,
                  'certificate_number': certNoController.text,
                  'issuing_country': countryController.text,
                  'issuing_authority': authorityController.text,
                  'issuing_date': now.toIso8601String().substring(0, 10),
                  'validity_months': 4,
                  'provisional_escrow_required': escrowReq,
                  'provisional_escrow_amount': amt,
                  'provisional_escrow_receipt': escrowReceiptController.text,
                  'provisional_escrow_deadline': now.add(const Duration(days: 90)).toIso8601String().substring(0, 10),
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

  void _showVerifyOriginalDialog(TradeAgreementItem item) {
    bool refundEscrow = item.provisionalEscrowRequired;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('إثبات استلام أصل الشهادة: ${item.certificateNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تم فحص أصل الشهادة الورقية ومطابقتها للأختام والبيانات المسجلة.'),
              if (item.provisionalEscrowRequired) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('تم استرداد الأمانة النقدية المعلقة من الجمارك'),
                  value: refundEscrow,
                  onChanged: (v) => setDialogState(() => refundEscrow = v ?? false),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'تأكيد الاستلام',
              variant: AppButtonVariant.success,
              onPressed: () async {
                final nowStr = DateTime.now().toIso8601String().substring(0, 10);
                final success = await ref.read(tradeAgreementsProvider.notifier).verifyOriginal(item.id, {
                  'original_received_date': nowStr,
                  'provisional_escrow_refunded': refundEscrow,
                  'refund_date': refundEscrow ? nowStr : null,
                });
                if (success && ctx.mounted) {
                  Navigator.of(ctx).pop();
                  setState(() => _selectedItem = null);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradeAgreementsProvider);

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: PageHeader(
          title: 'الاتفاقيات التفضيلية وشهادات المنشأ',
          subtitle: 'إدارة شروط اتفاقيات التجارة الحرة وتتبع أمانات تأخر أصل الشهادات',
          icon: Icons.verified_user_outlined,
          actions: [
            AppButton(
              label: 'تسجيل شهادة جديدة',
              icon: Icons.add,
              variant: AppButtonVariant.primary,
              onPressed: _showAddCertificateDialog,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            MasterDataToolbarWidget(
              moduleEndpoint: '/api/v1/trade-agreements',
              title: 'شهادات المنشأ التفضيلية',
              onRefreshNeeded: () => ref.read(tradeAgreementsProvider.notifier).fetchVerifications(fileId: widget.importFileId),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedItem != null) ...[
                            CertificateAuthenticityChecklist(
                              item: _selectedItem!,
                              onVerifyOriginal: () => _showVerifyOriginalDialog(_selectedItem!),
                            ),
                            ProvisionalEscrowCalculatorCard(
                              item: _selectedItem!,
                              onRecordRefund: () => _showVerifyOriginalDialog(_selectedItem!),
                            ),
                          ],
                          Card(
                            elevation: 0,
                            margin: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(AppTheme.sorourSurfaceTint),
                                columns: const [
                                  DataColumn(label: Text('كود السجل')),
                                  DataColumn(label: Text('الاتفاقية')),
                                  DataColumn(label: Text('رقم الشهادة')),
                                  DataColumn(label: Text('دولة الإصدار')),
                                  DataColumn(label: Text('حالة التقديم')),
                                  DataColumn(label: Text('الأمانة المؤقتة')),
                                  DataColumn(label: Text('مهلة الأمانة')),
                                  DataColumn(label: Text('الإجراءات')),
                                ],
                                rows: state.items.map((it) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        InkWell(
                                          onTap: () => CopyHelper.copy(context, it.verificationCode),
                                          child: Text(it.verificationCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                                        ),
                                      ),
                                      DataCell(Text(it.agreementName)),
                                      DataCell(
                                        InkWell(
                                          onTap: () => CopyHelper.copy(context, it.certificateNumber),
                                          child: Text(it.certificateNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                      DataCell(Text(it.issuingCountry)),
                                      DataCell(
                                        AppStatusBadge.fromStatus(
                                          status: it.submissionStatus,
                                          label: it.hasOriginalReceived ? 'أصل مستلم' : 'صورة مؤقتة',
                                        ),
                                      ),
                                      DataCell(
                                        Text(it.provisionalEscrowRequired ? '${it.provisionalEscrowAmount.toStringAsFixed(0)} جنيه' : 'لا يوجد'),
                                      ),
                                      DataCell(
                                        Text(
                                          it.provisionalEscrowDeadline != null
                                              ? it.provisionalEscrowDeadline!.toIso8601String().substring(0, 10)
                                              : 'لا ينطبق',
                                          style: TextStyle(
                                            color: it.isEscrowAtRisk ? AppTheme.crimson : AppTheme.charcoal,
                                            fontWeight: it.isEscrowAtRisk ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.assignment_outlined, color: AppTheme.cobalt, size: 20),
                                          tooltip: 'فحص الاشتراطات والأمانة',
                                          onPressed: () => setState(() => _selectedItem = it),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
