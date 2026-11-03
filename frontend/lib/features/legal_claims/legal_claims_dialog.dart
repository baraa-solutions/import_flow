import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_button.dart';
import 'legal_claims_provider.dart';
import 'widgets/reservation_letter_generator_card.dart';
import 'widgets/surveyor_report_manager.dart';
import 'widgets/time_bar_countdown_banner.dart';

class LegalClaimsDialog extends ConsumerStatefulWidget {
  final int importFileId;

  const LegalClaimsDialog({super.key, required this.importFileId});

  static Future<void> show(BuildContext context, {required int importFileId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LegalClaimsDialog(importFileId: importFileId),
    );
  }

  @override
  ConsumerState<LegalClaimsDialog> createState() => _LegalClaimsDialogState();
}

class _LegalClaimsDialogState extends ConsumerState<LegalClaimsDialog> {
  LegalClaimItem? _selectedClaim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(legalClaimsProvider.notifier).fetchClaims(fileId: widget.importFileId);
    });
  }

  void _showCreateClaimDialog() {
    final partyController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String claimType = 'CARRIER_DAMAGE';
    String damageNature = 'LATENT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسجيل مطالبة وتحفظ قانوني جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: claimType,
                    decoration: const InputDecoration(labelText: 'نوع المطالبة'),
                    items: const [
                      DropdownMenuItem(value: 'CARRIER_DAMAGE', child: Text('تلف بضائع منقولة')),
                      DropdownMenuItem(value: 'CARRIER_SHORTAGE', child: Text('عجز تفريغ ومحتويات')),
                      DropdownMenuItem(value: 'PORT_DAMAGE', child: Text('تلف ساحات وموانئ')),
                      DropdownMenuItem(value: 'INSURANCE_RECOVERY', child: Text('مطالبة تعويض تأميني')),
                    ],
                    onChanged: (v) => setDialogState(() => claimType = v!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: damageNature,
                    decoration: const InputDecoration(labelText: 'طبيعة الضرر'),
                    items: const [
                      DropdownMenuItem(value: 'LATENT', child: Text('تلف مستتر / خفي (مهلة 3 أيام)')),
                      DropdownMenuItem(value: 'APPARENT', child: Text('تلف ظاهر وفوري')),
                    ],
                    onChanged: (v) => setDialogState(() => damageNature = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: partyController, decoration: const InputDecoration(labelText: 'الطرف الموجه له التحفظ')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'قيمة الضرر التقديرية بالدولار'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات وتفاصيل الضرر')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            AppButton(
              label: 'حفظ وتوجيه التحفظ',
              variant: AppButtonVariant.primary,
              onPressed: () async {
                final amt = double.tryParse(amountController.text) ?? 0.0;
                final nowStr = DateTime.now().toIso8601String().substring(0, 10);
                final success = await ref.read(legalClaimsProvider.notifier).createClaim({
                  'import_file_id': widget.importFileId,
                  'claim_type': claimType,
                  'damage_nature': damageNature,
                  'delivery_date': nowStr,
                  'target_party': partyController.text,
                  'claimed_amount': amt,
                  'claimed_currency': 'USD',
                  'notes': notesController.text,
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

  void _showScheduleSurveyDialog(LegalClaimItem claim) {
    final companyController = TextEditingController(text: 'شركة الخبرة والمعاينة الدولية');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('جدولة معاينة مشتركة', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: companyController, decoration: const InputDecoration(labelText: 'اسم شركة المعاينة والخبرة')),
            const SizedBox(height: 12),
            const Text('سيتم تحديد موعد المعاينة غداً بحضور مندوب الناقل وشركة التأمين.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          AppButton(
            label: 'تأكيد الجدولة',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              final dateStr = DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10);
              final success = await ref.read(legalClaimsProvider.notifier).scheduleSurvey(claim.id, {
                'survey_date': dateStr,
                'surveyor_company': companyController.text,
                'notes': 'تم التنسيق لإجراء المعاينة بمقر المستودع',
              });
              if (success && ctx.mounted) {
                Navigator.of(ctx).pop();
                setState(() => _selectedClaim = null);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSettleDialog(LegalClaimItem claim) {
    final settleAmtController = TextEditingController(text: claim.claimedAmount.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسوية المطالبة واستلام التعويض', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: settleAmtController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مبلغ التعويض المستلم النهائي'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          AppButton(
            label: 'إتمام التسوية',
            variant: AppButtonVariant.success,
            onPressed: () async {
              final amt = double.tryParse(settleAmtController.text) ?? 0.0;
              final nowStr = DateTime.now().toIso8601String().substring(0, 10);
              final success = await ref.read(legalClaimsProvider.notifier).settleClaim(claim.id, {
                'settled_amount': amt,
                'settlement_date': nowStr,
                'notes': 'تم استلام الشيك وتسوية النزاع ودياً',
              });
              if (success && ctx.mounted) {
                Navigator.of(ctx).pop();
                setState(() => _selectedClaim = null);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(legalClaimsProvider);

    return SelectionArea(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: SizedBox(
          width: 900,
          height: 680,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.charcoal,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'رادار مواعيد المطالبات القانونية والتأمين والتحفظات',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    AppButton(
                      label: 'رفع مطالبة جديدة',
                      icon: Icons.add,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                      onPressed: _showCreateClaimDialog,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            if (_selectedClaim != null) ...[
                              TimeBarCountdownBanner(claim: _selectedClaim!),
                              ReservationLetterGeneratorCard(claim: _selectedClaim!),
                              SurveyorReportManager(
                                claim: _selectedClaim!,
                                onScheduleSurvey: () => _showScheduleSurveyDialog(_selectedClaim!),
                                onSettleClaim: () => _showSettleDialog(_selectedClaim!),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Table(
                                border: TableBorder.all(color: AppTheme.border),
                                children: [
                                  const TableRow(
                                    decoration: BoxDecoration(color: AppTheme.sorourSurfaceTint),
                                    children: [
                                      Padding(padding: EdgeInsets.all(8), child: Text('كود المطالبة', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(8), child: Text('طبيعة التلف', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(8), child: Text('الطرف المسؤول', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(8), child: Text('قيمة المطالبة', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(8), child: Text('سقوط الحق', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Padding(padding: EdgeInsets.all(8), child: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                  ...state.items.map((it) => TableRow(
                                        children: [
                                          Padding(padding: const EdgeInsets.all(8), child: Text(it.claimCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt))),
                                          Padding(padding: const EdgeInsets.all(8), child: Text(it.damageNature == 'LATENT' ? 'مستتر (3 أيام)' : 'ظاهر')),
                                          Padding(padding: const EdgeInsets.all(8), child: Text(it.targetParty)),
                                          Padding(padding: const EdgeInsets.all(8), child: Text('${it.claimedAmount.toStringAsFixed(0)} ${it.claimedCurrency}')),
                                          Padding(padding: const EdgeInsets.all(8), child: Text('${it.daysUntilTimeBar} يوم', style: TextStyle(color: it.isTimeBarred ? AppTheme.crimson : AppTheme.charcoal, fontWeight: FontWeight.bold))),
                                          Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: IconButton(
                                              icon: const Icon(Icons.open_in_new, size: 18, color: AppTheme.cobalt),
                                              tooltip: 'عرض الرادار والتحفظ',
                                              onPressed: () => setState(() => _selectedClaim = it),
                                            ),
                                          ),
                                        ],
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
