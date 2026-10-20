import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/copyable_data_helper.dart';

class ConsoleLogLine {
  final String text;
  final bool isError;
  final DateTime timestamp;

  ConsoleLogLine(this.text, {this.isError = false}) : timestamp = DateTime.now();
}

class SyncConsoleWidget extends StatefulWidget {
  final List<ConsoleLogLine> logs;
  final bool isRunning;
  final VoidCallback? onClear;

  const SyncConsoleWidget({
    super.key,
    required this.logs,
    required this.isRunning,
    this.onClear,
  });

  @override
  State<SyncConsoleWidget> createState() => _SyncConsoleWidgetState();
}

class _SyncConsoleWidgetState extends State<SyncConsoleWidget> {
  final ScrollController _scrollController = ScrollController();
  final bool _autoScroll = true;

  @override
  void didUpdateWidget(covariant SyncConsoleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyAllLogs() {
    final text = widget.logs.map((l) => l.text).join('\n');
    CopyHelper.copy(
      context,
      text,
      customMessage: context.l10n.prodSyncTerminalCopiedToast,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 900
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                // Terminal dots
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                const Icon(Icons.terminal_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.prodSyncTerminalTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isRunning) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.prodSyncTerminalRunningMsg,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white60, size: 15),
                  tooltip: l.prodSyncTerminalCopyTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.logs.isNotEmpty ? _copyAllLogs : null,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.clear_all_rounded, color: Colors.white60, size: 16),
                  tooltip: l.prodSyncTerminalClearTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onClear,
                ),
              ],
            ),
          ),

          // Output Area
          Expanded(
            child: widget.logs.isEmpty
                ? Center(
                    child: Text(
                      l.prodSyncTerminalReadyMsg,
                      style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  )
                : SelectionArea(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: widget.logs.length,
                      itemBuilder: (context, index) {
                        final line = widget.logs[index];
                        final text = line.text;

                        Color textColor = Colors.white70;
                        if (line.isError || text.contains('[ERROR]') || text.contains('❌')) {
                          textColor = const Color(0xFFF87171); // Red
                        } else if (text.startsWith('⚡ >') || text.startsWith('>')) {
                          textColor = const Color(0xFF38BDF8); // Sky blue
                        } else if (text.contains('[SUCCESS]') || text.contains('✅') || text.contains('[PASS]')) {
                          textColor = const Color(0xFF4ADE80); // Green
                        } else if (text.contains('[WARN]') || text.contains('[CHECK]') || text.contains('⚠️')) {
                          textColor = const Color(0xFFFBBF24); // Yellow
                        } else if (text.contains('[STATS]') || text.contains('[BACKUP]') || text.contains('📁')) {
                          textColor = const Color(0xFFA78BFA); // Purple
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Text(
                            text,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              height: 1.35,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
