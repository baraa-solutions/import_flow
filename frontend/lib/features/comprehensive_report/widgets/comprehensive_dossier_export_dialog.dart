import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../import_files/models/import_file_model.dart';
import '../../import_files/providers/import_files_provider.dart';
import '../models/comprehensive_dossier_model.dart';
import '../services/comprehensive_dossier_service.dart';
import '../services/comprehensive_report_export_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Desktop-oriented interactive modal dialog for CLO-03 Comprehensive Shipment Dossier Export.
/// Provides 10-phase readiness KPIs, multi-format export buttons (PDF, Excel, TSV, Clipboard),
/// and confirmation workflow with downstream TSK-0904 dispatch.
class ComprehensiveDossierExportDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;

  const ComprehensiveDossierExportDialog({
    super.key,
    required this.file,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ImportFileModel file,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ComprehensiveDossierExportDialog(file: file),
    );
  }

  @override
  ConsumerState<ComprehensiveDossierExportDialog> createState() =>
      _ComprehensiveDossierExportDialogState();
}

class _ComprehensiveDossierExportDialogState
    extends ConsumerState<ComprehensiveDossierExportDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  ComprehensiveShipmentDossierModel? _dossier;

  final _formKey = GlobalKey<FormState>();
  final _exportedByController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedFormat = 'PDF & Excel Full Bundle';

  final List<String> _formatOptions = [
    'PDF & Excel Full Bundle',
    'PDF Official Dossier (A4 Cairo)',
    'Excel Raw Ledger (CSV UTF-8)',
    'TSV Text Data Export',
  ];

  @override
  void initState() {
    super.initState();
    // Default to the signed-in user (no hard-coded sample name).
    _exportedByController.text = ref.read(authProvider).user?.fullName ?? '';
    _loadDossier();
  }

  @override
  void dispose() {
    _exportedByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDossier() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(comprehensiveDossierServiceProvider);
      final data = await service.fetchComprehensiveDossier(widget.file.importFileId);
      if (mounted) {
        setState(() {
          _dossier = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleConfirmExport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final service = ref.read(comprehensiveDossierServiceProvider);
      final req = DossierExportConfirmRequestModel(
        importFileId: widget.file.importFileId,
        exportedBy: _exportedByController.text.trim(),
        exportFormat: _selectedFormat,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      final resp = await service.confirmDossierExport(req);

      // Invalidate import files to refresh all screens live
      ref.invalidate(importFilesProvider);

      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(resp.message),
            backgroundColor: AppTheme.flatEmerald,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تأكيد التصدير: $e'),
            backgroundColor: AppTheme.flatCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDialogHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.flatCobalt),
                          SizedBox(height: 12),
                          Text('جاري تجميع بيانات الملف الاستيرادي الشامل من كافة المراحل...'),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppTheme.flatCrimson),
                                const SizedBox(height: 12),
                                Text(
                                  'تعذر جلب بيانات الملف الشامل: $_errorMessage',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppTheme.flatCrimson),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadDossier,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.flatCobalt,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildDialogBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.flatCharcoal,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in, color: AppTheme.cloudWhite, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'إصدار وتصدير التقرير والملف الشامل (CLO-03)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'شحنة: ${widget.file.primaryNameWithCode}  |  المورد: ${widget.file.supplierName}',
                  style: const TextStyle(
                    color: AppTheme.cloudWhite,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('comprehensiveDossierCloseBtn'),
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  Widget _buildDialogBody() {
    final dossier = _dossier!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Strip
          _buildKpiStrip(dossier),
          const SizedBox(height: 16),

          // 2. Export Actions Toolbar
          _buildExportActionsToolbar(dossier),
          const SizedBox(height: 16),

          // 3. 10-Phase Sections Status Breakdown
          _buildSectionsBreakdown(dossier),
          const SizedBox(height: 16),

          // 4. Export & Archival Confirmation Form
          _buildConfirmationForm(dossier),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(ComprehensiveShipmentDossierModel dossier) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'قيمة البضاعة FOB',
            value: _formatFob(dossier),
            subtitle: dossier.fobSource == 'ESTIMATE'
                ? (dossier.totalFobEgp == null ? 'تقديري (— EGP)' : 'تقديري (${dossier.totalFobEgp!.toStringAsFixed(0)} EGP)')
                : (dossier.totalFobEgp == null ? '— EGP' : '${dossier.totalFobEgp!.toStringAsFixed(0)} EGP'),
            icon: Icons.inventory_2_outlined,
            color: AppTheme.flatCobalt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            title: 'تكلفة الوصول الفعلية',
            value: '${dossier.actualLandedCostTotalEgp.toStringAsFixed(2)} EGP',
            subtitle: dossier.actualLandedCostMarkupFactor == null
                ? '—'
                : 'معامل: ${dossier.actualLandedCostMarkupFactor!.toStringAsFixed(3)}x',
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.flatEmerald,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            title: 'الانحراف المالي',
            value: '${dossier.actualLandedCostVariancePct > 0 ? "+" : ""}${dossier.actualLandedCostVariancePct.toStringAsFixed(2)}%',
            subtitle: '${dossier.actualLandedCostVarianceEgp.toStringAsFixed(0)} EGP',
            icon: Icons.trending_up,
            color: dossier.actualLandedCostVariancePct > 5.0 ? AppTheme.flatCrimson : AppTheme.flatOrange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            title: 'حالة الملف والجاهزية',
            value: '${dossier.progressPercent.toStringAsFixed(1)}%',
            subtitle: dossier.status,
            icon: Icons.check_circle_outline,
            color: AppTheme.flatCharcoal,
          ),
        ),
      ],
    );
  }

  String _formatFob(ComprehensiveShipmentDossierModel dossier) {
    if (dossier.totalFobFc != null && dossier.fobCurrency != null) {
      return '${dossier.totalFobFc!.toStringAsFixed(2)} ${dossier.fobCurrency}';
    }
    if (dossier.fobByCurrency.isNotEmpty) {
      return dossier.fobByCurrency.entries
          .map((e) => '${e.value.toStringAsFixed(2)} ${e.key}')
          .join(' / ');
    }
    return '—';
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportActionsToolbar(ComprehensiveShipmentDossierModel dossier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تصدير الحزم والملفات للمراجعة والجهات الرسمية (Mandatory Save As Dialog):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.flatCharcoal),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                key: const Key('exportDossierPdfBtn'),
                onPressed: () => ComprehensiveReportExportService.exportToPdf(
                  context: context,
                  file: widget.file,
                  dossier: dossier,
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('تصدير PDF رسمي (Cairo A4)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('exportDossierExcelBtn'),
                onPressed: () => ComprehensiveReportExportService.exportToExcel(
                  context: context,
                  file: widget.file,
                  dossier: dossier,
                ),
                icon: const Icon(Icons.table_view, size: 18),
                label: const Text('تصدير Excel (CSV UTF-8)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('exportDossierTsvBtn'),
                onPressed: () => ComprehensiveReportExportService.exportToTsv(
                  context: context,
                  file: widget.file,
                  dossier: dossier,
                ),
                icon: const Icon(Icons.text_snippet, size: 18),
                label: const Text('تصدير TSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('copyDossierClipboardBtn'),
                onPressed: () {
                  final text = ComprehensiveReportExportService.buildDossierText(
                    context: context,
                    file: widget.file,
                    dossier: dossier,
                  );
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ تقرير الملف الشامل للحافظة بنجاح!'),
                      backgroundColor: AppTheme.flatEmerald,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('نسخ للحافظة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.flatCharcoal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsBreakdown(ComprehensiveShipmentDossierModel dossier) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مراحل وجاهزية الملف الاستيرادي الشامل (10 Phases):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.flatCharcoal),
              ),
              Text(
                'مكتمل ${dossier.sections.where((s) => s.status == "COMPLETED").length} من 10 مراحل',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.flatEmerald),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dossier.sections.map((sec) {
              final isCompleted = sec.status == 'COMPLETED';
              final isInProgress = sec.status == 'IN_PROGRESS';
              final badgeColor = isCompleted
                  ? AppTheme.flatEmerald
                  : (isInProgress ? AppTheme.flatCobalt : Colors.grey.shade600);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : (isInProgress ? Icons.hourglass_top : Icons.radio_button_unchecked),
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${sec.sectionCode}: ${sec.sectionNameAr}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                        color: AppTheme.flatCharcoal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sec.statusAr,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationForm(ComprehensiveShipmentDossierModel dossier) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.flatCobalt.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.flatCobalt.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اعتماد تصدير الملف الشامل والإرسال للأرشيف الرقمي (CLO-04):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.flatCobalt),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: const Key('dossierExportedByField'),
                    controller: _exportedByController,
                    decoration: const InputDecoration(
                      labelText: 'المسؤول المالي المعتمد للتصدير *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person, size: 18),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسم المسؤول المعتمد';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: const Key('dossierExportFormatDropdown'),
                    value: _selectedFormat,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'صيغة الحزمة المصدرة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _formatOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFormat = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('dossierExportNotesField'),
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات الأرشفة والتدقيق الختامي (اختياري)',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.note, size: 18),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                key: const Key('confirmDossierExportBtn'),
                onPressed: _isSubmitting ? null : _handleConfirmExport,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.done_all),
                label: Text(_isSubmitting ? 'جاري الاعتماد والإرسال...' : 'اعتماد التصدير وإطلاق مهمة الإغلاق (CLO-04)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.flatCobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
