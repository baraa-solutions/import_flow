import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/smart_document_upload_model.dart';
import '../providers/smart_document_upload_provider.dart';
import '../widgets/document_ocr_status_list.dart';
import '../widgets/document_upload_dropzone.dart';

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
    DocumentOcrStatusList.showSessionDetails(context, session);
  }

  Future<void> _handleRunLabExtraction() async {
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
                  // Tab 1: Sessions Archive via DocumentOcrStatusList
                  DocumentOcrStatusList(
                    sessions: state.sessions,
                    isLoading: state.isLoading,
                    supportedModules: state.supportedModules,
                    selectedModuleFilter: state.selectedModuleFilter,
                    onModuleFilterChanged: (v) =>
                        ref.read(smartDocumentUploadProvider.notifier).filterModule(v),
                    onRefresh: () =>
                        ref.read(smartDocumentUploadProvider.notifier).fetchSessions(),
                    onViewDetails: _showSessionDetails,
                    onDelete: (session) =>
                        ref.read(smartDocumentUploadProvider.notifier).deleteSession(session.id),
                  ),

                  // Tab 2: Live Extraction Lab via DocumentUploadDropzone
                  DocumentUploadDropzone(
                    selectedModule: _selectedLabModule,
                    onModuleChanged: (m) => setState(() => _selectedLabModule = m),
                    textController: _rawTextController,
                    isProcessing: _isProcessingLab,
                    onProcess: _handleRunLabExtraction,
                    result: _lastLabResult,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
