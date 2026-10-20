import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/back_to_dashboard_button.dart';

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
          SnackBar(content: Text('تعذر فتح المتصفح تلقائياً: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.charcoal,
        title: const Row(
          children: [
            Icon(Icons.dashboard_customize_outlined, color: AppTheme.cobalt),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streamlit Operations & Lifecycle Board',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'لوحة تتبع ومتابعة مراحل الشحنات التفاعلية (المستويات الـ 6 — 25 خطوة تشغيلية)',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status & Quick Launcher Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [AppTheme.charcoal, Colors.blueGrey.shade900],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isServerRunning
                            ? AppTheme.emerald.withValues(alpha: 0.2)
                            : AppTheme.orange.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isServerRunning ? AppTheme.emerald : AppTheme.orange,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _isServerRunning ? Icons.check_circle : Icons.sensors_outlined,
                        color: _isServerRunning ? AppTheme.emerald : AppTheme.orange,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Streamlit Lifecycle Pipeline Engine',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isServerRunning
                                      ? AppTheme.emerald.withValues(alpha: 0.3)
                                      : Colors.amber.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _isServerRunning ? AppTheme.emerald : Colors.amber,
                                  ),
                                ),
                                child: Text(
                                  _isServerRunning ? 'ONLINE (Port 8501)' : 'OFFLINE',
                                  style: TextStyle(
                                    color: _isServerRunning ? Colors.greenAccent : Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusMessage,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        if (!_isServerRunning)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.emerald,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isLaunching ? null : _launchStreamlitServer,
                            icon: _isLaunching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.play_arrow, color: Colors.white),
                            label: Text(
                              _isLaunching ? 'جاري التشغيل...' : 'تشغيل خادم Streamlit',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (_isServerRunning) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cobalt,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _openInBrowser,
                            icon: const Icon(Icons.open_in_browser, color: Colors.white),
                            label: const Text(
                              'فتح لوحة Streamlit في المتصفح',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 6-Phase Lifecycle Architecture Overview
            const Text(
              'هيكل المستويات الـ 6 الكبرى المدمجة في لوحة Streamlit:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhaseColumnCard(
                  titleEn: '1. Pre-Planning',
                  titleAr: 'التخطيط والدراسات',
                  color: Colors.amber.shade800,
                  steps: [
                    'Freight Studies (دراسات النولون)',
                    'Customs Studies (الدراسات الجمركية)',
                    'Regulatory Reqs (اشتراطات الاستيراد)',
                  ],
                ),
                const SizedBox(width: 10),
                _buildPhaseColumnCard(
                  titleEn: '2. Initiation',
                  titleAr: 'بداية الشحنة',
                  color: AppTheme.cobalt,
                  steps: [
                    'Finance Approvals (اعتماد الميزانية)',
                    'ACID Operations (إصدار ACID)',
                  ],
                ),
                const SizedBox(width: 10),
                _buildPhaseColumnCard(
                  titleEn: '3. Booking & Docs',
                  titleAr: 'حجز وتدقيق الشحن',
                  color: const Color(0xFF16A085),
                  steps: [
                    'Freight Booking (تأكيد الحجز)',
                    'Freight Allocations (تخصيص الحاويات)',
                    'Draft Docs Review (مراجعة المسودات)',
                    'Customs Approval (الاعتماد النهائي)',
                  ],
                ),
                const SizedBox(width: 10),
                _buildPhaseColumnCard(
                  titleEn: '4. Digital & Bank',
                  titleAr: 'التوثيق والبنك',
                  color: AppTheme.crimson,
                  steps: [
                    'CargoX Upload (رفع المستندات)',
                    'Originals Collection (أصول المستندات)',
                    'Bank Form 4 (نموذج 4 البنكي)',
                  ],
                ),
                const SizedBox(width: 10),
                _buildPhaseColumnCard(
                  titleEn: '5. Port & Clearance',
                  titleAr: 'الميناء والتخليص',
                  color: const Color(0xFF8E44AD),
                  steps: [
                    'Declaration 46 (إقرار 46 ك.م)',
                    'Clearance Follow-up (الكشف والتثمين)',
                    'Drawing Samples (سحب العينات)',
                    'Discrepancy / Damage (محضر المعاينة)',
                    'Final Calculation (سداد الرسوم)',
                    'Demurrage & Detention (الأرضيات)',
                  ],
                ),
                const SizedBox(width: 10),
                _buildPhaseColumnCard(
                  titleEn: '6. Inbound & Closure',
                  titleAr: 'الاستلام والإغلاق',
                  color: AppTheme.emerald,
                  steps: [
                    'Warehouse GRN (إذن الإضافة)',
                    'Landed Cost (تسوية التكلفة)',
                    'Final Closure (إغلاق الملف)',
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Features and Rules Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.cobalt, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'مميزات وقواعد العمل المطبقة في لوحة Streamlit:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.charcoal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildFeatureBullet('مزامنة حية ومباشرة مع قاعدة بيانات SQLite (sorour_logistics.db).'),
                    _buildFeatureBullet('إمكانية تواجد نفس ملف الشحنة في أكثر من مرحلة بالتوازي (Multi-Stage Concurrent Tracking).'),
                    _buildFeatureBullet('تحديث العدادات الرقمية لحظياً بمجرد حفظ أو نقل الشحنة من خطوة إلى أخرى.'),
                    _buildFeatureBullet('واجهة تفاعلية كاملة لتنفيذ مهام كل خطوة (مفاضلة النولون، سداد الرسوم، الـ ACID، إقرار 46، ونموذج 4).'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseColumnCard({
    required String titleEn,
    required String titleAr,
    required Color color,
    required List<String> steps,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(7),
                  topEnd: Radius.circular(7),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    titleEn,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    titleAr,
                    style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, size: 12, color: color),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: AppTheme.cobalt, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
