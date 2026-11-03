import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/streamlit_server_control_card.dart';
import '../widgets/streamlit_workflow_pipeline_card.dart';

class StreamlitBoardScreen extends ConsumerStatefulWidget {
  const StreamlitBoardScreen({super.key});

  @override
  ConsumerState<StreamlitBoardScreen> createState() => _StreamlitBoardScreenState();
}

class _StreamlitBoardScreenState extends ConsumerState<StreamlitBoardScreen> {
  bool _isServerRunning = false;
  bool _isLaunching = false;
  String _statusMessage = 'جاهز للتشغيل والربط المباشر';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkServerStatus();
    } else {
      _statusMessage = 'لوحة Streamlit تعمل على http://localhost:8501';
    }
  }

  Future<void> _checkServerStatus() async {
    if (kIsWeb) return;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(Uri.parse('http://localhost:8501'));
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 400) {
        setState(() {
          _isServerRunning = true;
          _statusMessage = 'خادم Streamlit متصل ويعمل بنجاح على البورت 8501';
        });
        return;
      }
    } catch (_) {
      // Ignored if offline
    }
    setState(() {
      _isServerRunning = false;
      _statusMessage = 'الخادم غير نشط حالياً — يمكنك تشغيله بضغطة زر أدناه';
    });
  }

  Future<void> _launchStreamlitServer() async {
    if (kIsWeb) return;
    setState(() {
      _isLaunching = true;
      _statusMessage = 'جاري تشغيل خادم Streamlit...';
    });

    try {
      // Launch streamlit via process in detached/shell mode
      Process.start(
        'python',
        ['-m', 'streamlit', 'run', 'streamlit_app.py', '--server.port', '8501'],
        workingDirectory: '..',
        runInShell: true,
        mode: ProcessStartMode.detached,
      );

      await Future.delayed(const Duration(seconds: 3));
      await _checkServerStatus();
      _openInBrowser();
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ أثناء التشغيل: $e';
      });
    } finally {
      setState(() {
        _isLaunching = false;
      });
    }
  }

  Future<void> _openInBrowser() async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', 'http://localhost:8501']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['http://localhost:8501']);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', ['http://localhost:8501']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            'تعذر فتح المتصفح تلقائياً: $e',
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: PageHeader(
        icon: Icons.dashboard_customize_outlined,
        iconColor: AppTheme.cobalt,
        title: 'Streamlit Operations & Lifecycle Board',
        subtitle: 'لوحة تتبع ومتابعة مراحل الشحنات التفاعلية (المستويات الـ 6 — 25 خطوة تشغيلية)',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'فحص حالة الخادم',
            onPressed: _checkServerStatus,
          ),
          const SizedBox(width: 8),
          const BackToDashboardButton(),
          const SizedBox(width: 12),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamlitServerControlCard(
                isServerRunning: _isServerRunning,
                isLaunching: _isLaunching,
                statusMessage: _statusMessage,
                onLaunchServer: _launchStreamlitServer,
                onOpenInBrowser: _openInBrowser,
              ),
              const SizedBox(height: 24),
              const StreamlitWorkflowPipelineCard(),
            ],
          ),
        ),
      ),
    );
  }
}
