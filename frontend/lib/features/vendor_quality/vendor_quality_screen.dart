import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_date_picker_field.dart';
import '../../core/widgets/back_to_dashboard_button.dart';
import '../../core/widgets/buttons/app_button.dart';
import '../../core/widgets/master_data_toolbar.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/searchable_dropdown_field.dart';
import '../../core/widgets/standard_form_action_bar.dart';
import 'vendor_quality_provider.dart';
import 'widgets/psi_certificate_uploader_card.dart';
import 'widgets/vendor_historical_ranking_table.dart';
import 'widgets/vendor_scorecard_radar_chart.dart';

/// Coordinator Screen: Pre-Shipment Inspection (PSI) & Vendor Quality Rating (Type B).
/// < 360 lines, Parallel UI Decomposition, Pure Arabic.
class VendorQualityScreen extends ConsumerStatefulWidget {
  const VendorQualityScreen({super.key});

  @override
  ConsumerState<VendorQualityScreen> createState() => _VendorQualityScreenState();
}

class _VendorQualityScreenState extends ConsumerState<VendorQualityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showNewAssessmentDialog() {
    final vendorNameController = TextEditingController();
    String agency = 'SGS';
    final qualityController = TextEditingController(text: '95.0');
    final timelinessController = TextEditingController(text: '90.0');
    final docsController = TextEditingController(text: '95.0');
    final complianceController = TextEditingController(text: '90.0');
    DateTime? inspectionDate = DateTime.now();
    bool isSaving = false;

    const agencyOptions = [
      SearchableDropdownItem(value: 'SGS', label: 'إس جي إس العالمية للتفتيش'),
      SearchableDropdownItem(value: 'BUREAU_VERITAS', label: 'بيرو فيريتاس الدولية'),
      SearchableDropdownItem(value: 'COTECNA', label: 'كوتكنا لخدمات الفحص'),
      SearchableDropdownItem(value: 'TUV', label: 'تي يو في الألمانية'),
      SearchableDropdownItem(value: 'INTERTEK', label: 'إنترتك لضمان الجودة'),
      SearchableDropdownItem(value: 'INTERNAL_QA', label: 'فحص فني داخلي بالشركة'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SelectionArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تسجيل تقييم جودة وفحص ما قبل الشحن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('احتساب بطاقة الأداء بناءً على ركائز الجودة والالتزام والمستندات', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const Divider(height: 24),
                    TextField(
                      controller: vendorNameController,
                      decoration: const InputDecoration(labelText: 'اسم المورد أو المصنع الأجنبي'),
                    ),
                    const SizedBox(height: 12),
                    SearchableDropdownField<String>(
                      labelText: 'جهة التفتيش والفحص الفني',
                      value: agency,
                      items: agencyOptions,
                      onChanged: (v) => setDialogState(() => agency = v ?? 'SGS'),
                    ),
                    const SizedBox(height: 12),
                    AppDatePickerField(
                      label: 'تاريخ الفحص الفني',
                      value: inspectionDate,
                      onChanged: (d) => setDialogState(() => inspectionDate = d),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qualityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'درجة جودة المنتج (40%)', suffixText: '%'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: timelinessController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'الالتزام بالمواعيد (25%)', suffixText: '%'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: docsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'دقة المستندات (20%)', suffixText: '%'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: complianceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'شروط الامتثال (15%)', suffixText: '%'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    StandardFormActionBar(
                      isSaving: isSaving,
                      submitLabel: 'حساب التقييم واعتماد البطاقة',
                      closeLabel: 'إلغاء',
                      onSubmit: () async {
                        if (vendorNameController.text.trim().isEmpty) return;
                        final q = double.tryParse(qualityController.text.trim()) ?? 100.0;
                        final t = double.tryParse(timelinessController.text.trim()) ?? 100.0;
                        final d = double.tryParse(docsController.text.trim()) ?? 100.0;
                        final c = double.tryParse(complianceController.text.trim()) ?? 100.0;

                        setDialogState(() => isSaving = true);
                        try {
                          await ref.read(vendorQualityActionsProvider).createAssessment({
                            'vendor_name': vendorNameController.text.trim(),
                            'inspection_agency': agency,
                            'inspection_date': inspectionDate?.toIso8601String().substring(0, 10),
                            'quality_score': q,
                            'delivery_timeliness_score': t,
                            'documentation_accuracy_score': d,
                            'compliance_score': c,
                          });
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        } finally {
                          if (ctx.mounted) setDialogState(() => isSaving = false);
                        }
                      },
                      onClose: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assessmentsAsync = ref.watch(vendorQualityProvider);

    return SelectionArea(
      child: Scaffold(
        backgroundColor: AppTheme.surfaceAlt,
        appBar: PageHeader(
          title: 'فحص ما قبل الشحن وتقييم أداء الموردين',
          subtitle: 'تقارير فحص الجودة الميدانية وبطاقات قياس أداء وتصنيف المصنعين والموردين',
          icon: Icons.fact_check_rounded,
          actions: [
            AppButton(
              label: 'تحديث',
              icon: Icons.refresh,
              variant: AppButtonVariant.ghost,
              onPressed: () {
                ref.invalidate(vendorQualityProvider);
                ref.invalidate(vendorRankingsProvider);
              },
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'تسجيل تقرير فحص جديد',
              icon: Icons.add_task_rounded,
              variant: AppButtonVariant.primary,
              onPressed: _showNewAssessmentDialog,
            ),
            const SizedBox(width: 8),
            const BackToDashboardButton(),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: MasterDataToolbarWidget(
                moduleEndpoint: 'api/v1/vendor-quality',
                title: 'تقييم أداء الموردين',
                onRefreshNeeded: () {
                  ref.invalidate(vendorQualityProvider);
                  ref.invalidate(vendorRankingsProvider);
                },
              ),
            ),
            Container(
              color: AppTheme.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.cobalt,
                indicatorColor: AppTheme.cobalt,
                tabs: const [
                  Tab(icon: Icon(Icons.analytics_rounded), text: 'بطاقات تقييم أداء الموردين'),
                  Tab(icon: Icon(Icons.verified_user_rounded), text: 'تقارير فحص ما قبل الشحن'),
                  Tab(icon: Icon(Icons.leaderboard_rounded), text: 'التصنيف التاريخي للموردين'),
                ],
              ),
            ),
            Expanded(
              child: assessmentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('حدث خطأ في تحميل تقييمات الموردين: $e')),
                data: (items) => TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScorecardsTab(items),
                    _buildPsiCertificatesTab(items),
                    const VendorHistoricalRankingTable(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScorecardsTab(List<VendorQualityModel> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد بطاقات تقييم أداء موردين مسجلة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, idx) => VendorScorecardRadarChart(assessment: items[idx]),
    );
  }

  Widget _buildPsiCertificatesTab(List<VendorQualityModel> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد شهادات فحص مسجلة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, idx) => PsiCertificateUploaderCard(assessment: items[idx]),
    );
  }
}
