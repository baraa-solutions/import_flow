import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/smart_document_upload_model.dart';
import '../providers/smart_document_upload_provider.dart';

class SmartDocumentUploadHubScreen extends ConsumerStatefulWidget {
  const SmartDocumentUploadHubScreen({super.key});

  @override
  ConsumerState<SmartDocumentUploadHubScreen> createState() =>
      _SmartDocumentUploadHubScreenState();
}

class _SmartDocumentUploadHubScreenState
    extends ConsumerState<SmartDocumentUploadHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Lab Tab State
  String _selectedLabModule = 'purchase-order';
  final TextEditingController _rawTextController = TextEditingController();
  Map<String, dynamic>? _lastLabResult;
  bool _isProcessingLab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rawTextController.dispose();
    super.dispose();
  }

  void _showSessionDetails(UploadSessionModel session) {
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2631) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.document_scanner_rounded, color: AppTheme.cobalt, size: 22),
            const SizedBox(width: 8),
            Text(
              '${isArabic ? 'تفاصيل جلسة الاستخراج:' : 'Extraction Details:'} ${session.sessionRef}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SelectionArea(
          child: SizedBox(
            width: 580,
            height: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cobalt.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          session.moduleName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.cobalt),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isArabic ? 'نسبة الدقة:' : 'Confidence:'} ${(session.confidenceScore * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        session.filename,
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Missing Fields
                  if (session.missingFields.isNotEmpty) ...[
                    Text(
                      isArabic ? 'الحقول الناقصة / غير المكتشفة:' : 'Missing / Undetected Fields:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: session.missingFields
                          .map((f) => Chip(
                                label: Text(f, style: const TextStyle(fontSize: 10.5, color: Colors.orange)),
                                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Extracted Fields Table
                  Text(
                    isArabic ? 'الحقول المستخرجة بنجاح:' : 'Extracted Fields:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.emerald),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: session.extractedFields.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                isArabic ? 'لم يتم استخراج حقول' : 'No fields extracted',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: session.extractedFields.entries.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = session.extractedFields.entries.elementAt(index);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.value?.toString() ?? '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESS':
        return AppTheme.emerald;
      case 'PARTIAL':
        return Colors.orange;
      case 'FAILED':
        return AppTheme.crimson;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartDocumentUploadProvider);
    final isArabic = context.l10n.isArabic;
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: PageHeader(
        title: isArabic
            ? 'مركز المعالجة والاستخراج الذكي للمستندات'
            : 'AI Document Extraction & Audit Hub',
        subtitle: isArabic
            ? 'سجل عمليات الاستخراج الآلي، فحص وتحليل المستندات، ومطابقة الفاتورة التجارية مع البوليصة'
            : 'Automated document extraction sessions archive, parsing lab, and cross-check audit',
        icon: Icons.document_scanner_rounded,
        actions: const [
          BackToDashboardButton(),
        ],
      ),
      body: SelectionArea(
        child: Column(
          children: [
            // Tabs Bar
            Container(
              color: isDark ? const Color(0xFF1E2631) : Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.cobalt,
                indicatorColor: AppTheme.cobalt,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.history_edu_rounded, size: 18),
                    text: isArabic ? 'أرشيف جلسات الاستخراج الذكي' : 'Extraction Sessions Archive',
                  ),
                  Tab(
                    icon: const Icon(Icons.science_rounded, size: 18),
                    text: isArabic ? 'معمل الاستخراج الفوري والمطابقة' : 'Live Parser & Cross-Check Lab',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Sessions Archive
                  _buildSessionsArchiveTab(state, isArabic, isDark),

                  // Tab 2: Live Extraction Lab
                  _buildLiveLabTab(state, isArabic, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsArchiveTab(
      SmartDocumentUploadState state, bool isArabic, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Filter Toolbar
          Row(
            children: [
              Container(
                width: 240,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: state.selectedModuleFilter,
                    isDense: true,
                    isExpanded: true,
                    hint: Text(isArabic ? 'كل الموديولات' : 'All Modules', style: const TextStyle(fontSize: 12)),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(isArabic ? 'كل الموديولات' : 'All Modules', style: const TextStyle(fontSize: 12)),
                      ),
                      ...state.supportedModules.map((m) => DropdownMenuItem<String?>(
                            value: m,
                            child: Text(m, style: const TextStyle(fontSize: 12)),
                          )),
                    ],
                    onChanged: (v) => ref.read(smartDocumentUploadProvider.notifier).filterModule(v),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: isArabic ? 'تحديث' : 'Refresh',
                onPressed: () => ref.read(smartDocumentUploadProvider.notifier).fetchSessions(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sessions List
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.sessions.isEmpty
                    ? Center(
                        child: Text(
                          isArabic ? 'لا توجد جلسات استخراج مسجلة' : 'No upload sessions found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final session = state.sessions[index];
                          return Card(
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _statusColor(session.extractionStatus).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.document_scanner_rounded,
                                      color: _statusColor(session.extractionStatus),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              session.sessionRef,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppTheme.cobalt,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              session.filename,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _statusColor(session.extractionStatus).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                session.extractionStatus,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: _statusColor(session.extractionStatus),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 12,
                                          children: [
                                            Text(
                                              '${isArabic ? "الموديول:" : "Module:"} ${session.moduleName}',
                                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                            ),
                                            Text(
                                              '${isArabic ? "الدقة:" : "Confidence:"} ${(session.confidenceScore * 100).toStringAsFixed(1)}%',
                                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                            ),
                                            Text(
                                              '${isArabic ? "الحقول:" : "Fields:"} ${session.extractedFields.length}',
                                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                            ),
                                            if (session.createdAt != null)
                                              Text(
                                                session.createdAt!.toLocal().toString().substring(0, 16),
                                                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, size: 20),
                                    color: AppTheme.cobalt,
                                    tooltip: isArabic ? 'عرض تفاصيل الحقول' : 'View extracted details',
                                    onPressed: () => _showSessionDetails(session),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    color: AppTheme.crimson,
                                    tooltip: isArabic ? 'حذف الجلسة' : 'Delete session',
                                    onPressed: () => ref
                                        .read(smartDocumentUploadProvider.notifier)
                                        .deleteSession(session.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLabTab(
      SmartDocumentUploadState state, bool isArabic, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left input pane
          SizedBox(
            width: 480,
            child: Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_snippet_rounded, color: AppTheme.cobalt, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? 'مدخلات النص / الوثيقة المباشرة' : 'Direct Text / Document Input',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic ? 'اختر الموديول المستهدف' : 'Target Module',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLabModule,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: [
                        'purchase-order',
                        'cargo-shipping',
                        'customs-clearance',
                        'freight-quotation',
                        'coo-certificate',
                        'inspection-certificate',
                        'warehouse-receiving',
                        'company-entity',
                        'supplier-entity',
                      ]
                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedLabModule = v ?? _selectedLabModule),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic ? 'ألصق نص الفاتورة / المستند هنا' : 'Paste raw document text here',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TextField(
                        controller: _rawTextController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? 'ألصق نص الفاتورة التجارية، البوليصة، أو بيانات الموردين...'
                              : 'Paste text from Commercial Invoice, B/L, or contact card...',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cobalt,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isProcessingLab
                            ? null
                            : () async {
                                final text = _rawTextController.text.trim();
                                if (text.length < 5) return;
                                setState(() => _isProcessingLab = true);
                                final res = await ref
                                    .read(smartDocumentUploadProvider.notifier)
                                    .parseRawText(_selectedLabModule, text);
                                setState(() {
                                  _isProcessingLab = false;
                                  _lastLabResult = res;
                                });
                              },
                        icon: _isProcessingLab
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(
                          isArabic ? 'تشغيل الاستخراج الذكي الفوري' : 'Run Live AI Extraction',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Right results pane
          Expanded(
            child: Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _lastLabResult == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.psychology_outlined, size: 54, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              isArabic
                                  ? 'ألصق النص واضغط "تشغيل الاستخراج الذكي" لرؤية الحقول المستخلصة ونسب الثقة'
                                  : 'Paste text & click "Run Live AI Extraction" to see extracted fields and confidence scores',
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isArabic ? 'نتائج الاستخراج المباشرة' : 'Live Extracted Results',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${isArabic ? "الدقة:" : "Confidence:"} ${((_lastLabResult!["confidence_score"] as num? ?? 0) * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.emerald,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_lastLabResult!['extracted_fields'] is Map) ...[
                                    ...(_lastLabResult!['extracted_fields'] as Map).entries.map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  width: 180,
                                                  child: Text(
                                                    e.key.toString(),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontFamily: 'monospace',
                                                      fontSize: 12,
                                                      color: AppTheme.cobalt,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    e.value?.toString() ?? '',
                                                    style: const TextStyle(fontSize: 12.5),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  ],
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
    );
  }
}
