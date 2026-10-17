import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../providers/smart_tasks_provider.dart';
import '../providers/email_settings_provider.dart';
import 'email_settings_dialog.dart';

class SmartEmailListenerDialog extends ConsumerStatefulWidget {
  const SmartEmailListenerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const SmartEmailListenerDialog(),
    );
  }

  @override
  ConsumerState<SmartEmailListenerDialog> createState() => _SmartEmailListenerDialogState();
}

class _SmartEmailListenerDialogState extends ConsumerState<SmartEmailListenerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _senderController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;
  Map<String, dynamic>? _parseResult;

  // Logs Tab
  bool _isLoadingLogs = false;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _senderController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _loadSampleNotice() {
    setState(() {
      _senderController.text = 'arrival.notices@msc.com';
      _subjectController.text = 'ARRIVAL NOTICE - B/L: MEDU123456789 - MSC OSCAR';
      _bodyController.text = '''DEAR CUSTOMER,
PLEASE BE ADVISED THAT VESSEL MSC OSCAR VOYAGE 2401W IS SCHEDULED TO ARRIVE AT ALEXANDRIA PORT.
BILL OF LADING: MEDU123456789
ESTIMATED TIME OF ARRIVAL (ETA): 2026-09-28
CONTAINERS:
MSCU1234567
MSCU7654321
KINDLY ARRANGE PAYMENT OF DELIVERY ORDER CHARGES PRIOR TO DISCHARGE.''';
      _parseResult = null;
      _errorMessage = null;
    });
  }

  Future<void> _previewParse() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _parseResult = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/smart-email/parse-preview',
        data: {
          'subject': _subjectController.text.trim(),
          'body_text': _bodyController.text.trim(),
        },
      );

      if (mounted) {
        setState(() {
          _parseResult = response.data is Map<String, dynamic> ? response.data : null;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processIncomingEmail() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _parseResult = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/smart-email/incoming',
        data: {
          'sender_email': _senderController.text.trim(),
          'subject': _subjectController.text.trim(),
          'body_text': _bodyController.text.trim(),
          'email_type': 'Arrival Notice',
        },
      );

      if (mounted) {
        setState(() {
          _parseResult = response.data is Map<String, dynamic> ? response.data : null;
          _isProcessing = false;
        });

        // Auto-refresh smart tasks table
        ref.read(smartTasksProvider.notifier).fetchTasks();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _parseResult?['summary_message']?.toString() ?? 'تمت المعالجة بنجاح',
            ),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoadingLogs = true;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/smart-email/logs?limit=50');
      if (mounted) {
        setState(() {
          _logs = response.data is List ? response.data : [];
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLogs = false;
        });
      }
    }
  }

  Future<void> _fetchInboxLive() async {
    setState(() => _isProcessing = true);
    final res = await ref.read(emailSettingsProvider.notifier).fetchInboxNow();
    if (mounted) {
      setState(() => _isProcessing = false);
      if (res != null) {
        _fetchLogs();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: res.matchedFilesCount > 0 ? AppTheme.emerald : AppTheme.cobalt,
          ),
        );
      }
    }
  }

  void _exportLogsTsv() {
    final l = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln(
      '${l.smartEmailListenerBlNumberLabel}\t'
      '${l.smartEmailListenerEtaLabel}\t'
      '${l.smartEmailListenerVesselLabel}\t'
      '${l.smartEmailListenerSenderLabel}\t'
      '${l.smartEmailListenerSubjectLabel}',
    );

    for (final log in _logs) {
      final m = log is Map<String, dynamic> ? log : {};
      buffer.writeln(
        '${m['extracted_bl_number'] ?? '-'}\t'
        '${m['extracted_eta'] ?? '-'}\t'
        '${m['extracted_vessel'] ?? '-'}\t'
        '${m['sender_email'] ?? '-'}\t'
        '${(m['subject'] ?? '').toString().replaceAll('\t', ' ')}',
      );
    }

    CopyHelper.copy(
      context,
      buffer.toString().trimRight(),
      customMessage: l.smartTasksExportTsvSuccess,
    );
  }

  Widget _buildResultRow(String label, String? value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final display = value?.trim().isNotEmpty == true ? value! : '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt),
            ),
          ),
          if (display != '-')
            IconButton(
              icon: Icon(Icons.copy, size: 16, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
              tooltip: label,
              onPressed: () => CopyHelper.copy(context, display, customMessage: label),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 860,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, color: AppTheme.cobalt, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.smartEmailListenerDialogTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.smartEmailListenerBtnTooltip,
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _fetchInboxLive,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(l.smartEmailCheckInboxBtn, style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.emerald,
                    side: const BorderSide(color: AppTheme.emerald),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => EmailSettingsDialog.show(context),
                  icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                  label: Text(l.smartEmailSettingsBtn, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.cobalt,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.cobalt,
              onTap: (index) {
                if (index == 1) _fetchLogs();
              },
              tabs: [
                Tab(
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  text: l.smartEmailListenerPreviewBtn,
                ),
                Tab(
                  icon: const Icon(Icons.history, size: 18),
                  text: l.smartEmailListenerLogsTabTitle,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Parse Simulation
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l.smartEmailListenerBodyLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            TextButton.icon(
                              onPressed: _loadSampleNotice,
                              icon: const Icon(Icons.replay, size: 16),
                              label: Text(l.smartEmailListenerLoadSampleBtn),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _senderController,
                                decoration: InputDecoration(
                                  labelText: l.smartEmailListenerSenderLabel,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.alternate_email, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _subjectController,
                                decoration: InputDecoration(
                                  labelText: l.smartEmailListenerSubjectLabel,
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.subject, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _bodyController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: l.smartEmailListenerBodyLabel,
                            alignLabelWithHint: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Action Buttons
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: _isProcessing ? null : _previewParse,
                              icon: const Icon(Icons.search, size: 18),
                              label: Text(l.smartEmailListenerPreviewBtn),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              onPressed: _isProcessing ? null : _processIncomingEmail,
                              icon: _isProcessing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.done_all, size: 18),
                              label: Text(l.smartEmailListenerProcessBtn),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.crimson.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.crimson.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.crimson),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppTheme.crimson),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_parseResult != null) ...[
                          Card(
                            color: isDark ? AppTheme.darkCardBackground : Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.verified, color: AppTheme.emerald, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        l.smartEmailListenerParsedCardTitle,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                      ),
                                      const Spacer(),
                                      if (_parseResult!['is_matched_file'] == true)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.emerald.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${l.smartEmailListenerMatchedFileLabel}: ${_parseResult!['import_file_code']}',
                                            style: const TextStyle(
                                              color: AppTheme.emerald,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  _buildResultRow(
                                    l.smartEmailListenerBlNumberLabel,
                                    _parseResult!['extracted_bl_number']?.toString(),
                                  ),
                                  _buildResultRow(
                                    l.smartEmailListenerEtaLabel,
                                    _parseResult!['extracted_eta']?.toString(),
                                  ),
                                  _buildResultRow(
                                    l.smartEmailListenerVesselLabel,
                                    _parseResult!['extracted_vessel']?.toString(),
                                  ),
                                  _buildResultRow(
                                    l.smartEmailListenerVoyageLabel,
                                    _parseResult!['extracted_voyage']?.toString(),
                                  ),
                                  _buildResultRow(
                                    l.smartEmailListenerContainersLabel,
                                    (_parseResult!['extracted_containers'] as List?)?.join(', '),
                                  ),
                                  if (_parseResult!['payment_task_created'] == true)
                                    _buildResultRow(
                                      l.smartEmailListenerTaskCreatedLabel,
                                      '#${_parseResult!['task_id']}',
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Tab 2: Logs
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.smartEmailListenerLogsTabTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _logs.isEmpty ? null : _exportLogsTsv,
                                icon: const Icon(Icons.copy_all, size: 16, color: AppTheme.cobalt),
                                label: Text(l.smartTasksExportTsvBtn),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: l.smartEmailListenerLogsTabTitle,
                                onPressed: _fetchLogs,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _isLoadingLogs
                            ? const Center(child: CircularProgressIndicator())
                            : _logs.isEmpty
                                ? Center(
                                    child: Text(
                                      l.smartTasksEmptyMessage,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _logs.length,
                                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                                    itemBuilder: (ctx, i) {
                                      final item = _logs[i] as Map<String, dynamic>;
                                      final bl = item['extracted_bl_number'] ?? '-';
                                      final eta = item['extracted_eta'] ?? '-';
                                      final vessel = item['extracted_vessel'] ?? '-';
                                      final status = item['processing_status'] ?? '-';

                                      return ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: AppTheme.cobalt,
                                          foregroundColor: Colors.white,
                                          radius: 16,
                                          child: Icon(Icons.email_outlined, size: 16),
                                        ),
                                        title: Text(
                                          '${l.smartEmailListenerBlNumberLabel}: $bl | $vessel',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                        ),
                                        subtitle: Text(
                                          '${l.smartEmailListenerEtaLabel}: $eta | ${item['sender_email'] ?? ''}',
                                          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: status.toString().contains('Matched') || status.toString().contains('Task')
                                                    ? AppTheme.emerald.withOpacity(0.15)
                                                    : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status.toString(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: status.toString().contains('Matched') || status.toString().contains('Task')
                                                      ? AppTheme.emerald
                                                      : (isDark ? AppTheme.darkTextPrimary : Colors.grey.shade800),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(Icons.copy, size: 16, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                                              tooltip: bl,
                                              onPressed: () => CopyHelper.copy(context, bl.toString()),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
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
