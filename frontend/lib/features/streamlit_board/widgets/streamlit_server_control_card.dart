import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class StreamlitServerControlCard extends StatelessWidget {
  final bool isServerRunning;
  final bool isLaunching;
  final String statusMessage;
  final VoidCallback onLaunchServer;
  final VoidCallback onOpenInBrowser;

  const StreamlitServerControlCard({
    super.key,
    required this.isServerRunning,
    required this.isLaunching,
    required this.statusMessage,
    required this.onLaunchServer,
    required this.onOpenInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                color: isServerRunning
                    ? AppTheme.emerald.withValues(alpha: 0.2)
                    : AppTheme.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isServerRunning ? AppTheme.emerald : AppTheme.orange,
                  width: 2,
                ),
              ),
              child: Icon(
                isServerRunning ? Icons.check_circle : Icons.sensors_outlined,
                color: isServerRunning ? AppTheme.emerald : AppTheme.orange,
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
                          color: isServerRunning
                              ? AppTheme.emerald.withValues(alpha: 0.3)
                              : Colors.amber.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isServerRunning ? AppTheme.emerald : Colors.amber,
                          ),
                        ),
                        child: Text(
                          isServerRunning ? 'ONLINE (Port 8501)' : 'OFFLINE',
                          style: TextStyle(
                            color: isServerRunning ? Colors.greenAccent : Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusMessage,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                if (!isServerRunning)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLaunching ? null : onLaunchServer,
                    icon: isLaunching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow, color: Colors.white),
                    label: Text(
                      isLaunching ? 'جاري التشغيل...' : 'تشغيل خادم Streamlit',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (isServerRunning) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cobalt,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onOpenInBrowser,
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
    );
  }
}
