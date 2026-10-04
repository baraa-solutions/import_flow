import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/ai_assistant_provider.dart';
import '../../core/theme/app_theme.dart';
import 'copyable_data_helper.dart';
import 'shipment_lifecycle_navigator.dart';

/// Docked side panel version of the AI Assistant for Desktop screens (>= 1200px).
/// Sits directly in the HomeScreen layout Row alongside the main content Expanded view,
/// pushing/shrinking the table and forms so they are NEVER covered by floating overlays.
class AiAssistantDockedPanel extends ConsumerStatefulWidget {
  const AiAssistantDockedPanel({super.key});

  @override
  ConsumerState<AiAssistantDockedPanel> createState() => _AiAssistantDockedPanelState();
}

class _AiAssistantDockedPanelState extends ConsumerState<AiAssistantDockedPanel> {
  bool _isMaximized = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantProvider);
    final isDark = AppTheme.isDark(context);
    final width = _isMaximized ? 560.0 : 420.0;

    return Directionality(
      textDirection: state.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: width,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: BorderDirectional(
            start: BorderSide(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: AiAssistantChatPanel(
          isDocked: true,
          isMaximized: _isMaximized,
          onToggleMaximize: () => setState(() => _isMaximized = !_isMaximized),
          onClose: () => ref.read(aiAssistantProvider.notifier).togglePanel(),
        ),
      ),
    );
  }
}

/// A persistent floating AI Import Assistant overlay.
/// When collapsed, renders the orange circular launcher button in the bottom-right corner.
/// On desktop (>=1200px), opening the assistant docks it into the main layout Row.
/// On smaller screens (<1200px), opens as a modal panel with a dimmed backdrop.
class AiAssistantOverlay extends ConsumerStatefulWidget {
  final bool showFloatingLauncher;
  const AiAssistantOverlay({super.key, this.showFloatingLauncher = false});

  @override
  ConsumerState<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends ConsumerState<AiAssistantOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _panelController;
  late final Animation<double> _panelAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _greetingTimer;
  bool _greetingDismissed = false;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _panelAnimation = CurvedAnimation(parent: _panelController, curve: Curves.easeOutCubic);
    _fadeAnimation = CurvedAnimation(parent: _panelController, curve: Curves.easeIn);

    // Auto-dismiss greeting bubble after 7 seconds
    _greetingTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        ref.read(aiAssistantProvider.notifier).dismissGreeting();
      }
    });
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _panelController.dispose();
    super.dispose();
  }

  void _togglePanel() {
    final notifier = ref.read(aiAssistantProvider.notifier);
    notifier.togglePanel();
    final isOpen = ref.read(aiAssistantProvider).isPanelOpen;
    if (isOpen) {
      _panelController.forward();
    } else {
      _panelController.reverse();
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isGreetingDismissed = state.isGreetingDismissed || _greetingDismissed;

    // Sync animation when panel state changes externally
    if (state.isPanelOpen && _panelController.status == AnimationStatus.dismissed) {
      _panelController.forward();
    } else if (!state.isPanelOpen && _panelController.status == AnimationStatus.completed) {
      _panelController.reverse();
    }

    // On Desktop (>= 1200px), when panel is open, it docks into the HomeScreen layout Row!
    if (isDesktop && state.isPanelOpen) {
      return const SizedBox.shrink();
    }

    // When floating launcher is disabled and panel is closed, render nothing
    if (!widget.showFloatingLauncher && !state.isPanelOpen) {
      return const SizedBox.shrink();
    }

    return Stack(
      alignment: AlignmentDirectional.bottomEnd,
      children: [
        // ── Modal Barrier for screens < 1200px when panel is open ────────────
        if (!isDesktop && state.isPanelOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePanel,
              child: Container(
                color: Colors.black38,
              ),
            ),
          ),

        // ── Chat Panel (Floating Modal on < 1200px) ─────────────────────────
        if (!isDesktop && state.isPanelOpen)
          Positioned(
            bottom: 80,
            right: 16,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _panelAnimation,
                alignment: Alignment.bottomRight,
                child: _buildChatPanel(state),
              ),
            ),
          ),

        // ── Greeting Bubble (Exact match to user's uploaded image) ───────────
        if (widget.showFloatingLauncher && !state.isPanelOpen && !isGreetingDismissed)
          Positioned(
            bottom: 80,
            right: 16,
            child: _buildGreetingBubble(state),
          ),

        // ── Floating Button (Orange circular button with chat icon) ──────────
        if (widget.showFloatingLauncher)
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildFloatingButton(state),
          ),
      ],
    );
  }

  // ─── Greeting Bubble ────────────────────────────────────────────────────────

  Widget _buildGreetingBubble(AiAssistantState state) {
    final isAr = state.isArabic;
    final l = context.l10n;
    return Material(
      color: Colors.transparent,
      child: Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: SelectionArea(
          child: Container(
            width: 230,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAr ? l.aiAssistantGreetingTitle : 'Hello',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _greetingTimer?.cancel();
                        ref.read(aiAssistantProvider.notifier).dismissGreeting();
                        setState(() => _greetingDismissed = true);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {
                    _greetingTimer?.cancel();
                    ref.read(aiAssistantProvider.notifier).dismissGreeting();
                    setState(() => _greetingDismissed = true);
                    _togglePanel();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? l.aiAssistantGreetingBody : 'Here to help - Feedback,\nChat.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isAr ? l.aiAssistantOnlineStatus : 'Import Assistant Online',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.cobalt,
                              ),
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
        ),
      ),
    );
  }

  // ─── Floating Button ────────────────────────────────────────────────────────

  Widget _buildFloatingButton(AiAssistantState state) {
    final l = context.l10n;
    return Tooltip(
      message: state.isPanelOpen
          ? l.aiAssistantCloseTooltip
          : l.aiAssistantOpenTooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: _togglePanel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: state.isPanelOpen ? 48 : 56,
          height: state.isPanelOpen ? 48 : 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: state.isPanelOpen
                  ? [AppTheme.charcoal, const Color(0xFF1E293B)]
                  : [const Color(0xFFF4511E), const Color(0xFFE64A19)], // Exact vibrant orange from image
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (state.isPanelOpen ? AppTheme.charcoal : const Color(0xFFE64A19))
                    .withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                state.isPanelOpen ? Icons.close_rounded : Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: state.isPanelOpen ? 20 : 24,
              ),
              // Loading indicator ring
              if (state.isLoading)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              // Online green badge
              if (!state.isPanelOpen)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.emerald,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  // ─── Chat Panel ─────────────────────────────────────────────────────────────

  Widget _buildChatPanel(AiAssistantState state) {
    final screenSize = MediaQuery.of(context).size;
    final availableWidth = (screenSize.width - 32).clamp(360.0, 3000.0);
    final availableHeight = (screenSize.height - 96).clamp(420.0, 3000.0);

    final targetWidth = _isMaximized
        ? (screenSize.width * 0.58).clamp(650.0, 920.0)
        : (screenSize.width * 0.42).clamp(480.0, 620.0);
    final targetHeight = _isMaximized
        ? (screenSize.height * 0.90).clamp(600.0, 1050.0)
        : (screenSize.height * 0.82).clamp(520.0, 850.0);

    final panelWidth = targetWidth > availableWidth ? availableWidth : targetWidth;
    final panelHeight = targetHeight > availableHeight ? availableHeight : targetHeight;

    return Directionality(
      textDirection: state.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: panelWidth,
        height: panelHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AiAssistantChatPanel(
            isDocked: false,
            isMaximized: _isMaximized,
            onToggleMaximize: () => setState(() => _isMaximized = !_isMaximized),
            onClose: _togglePanel,
          ),
        ),
      ),
    );
  }
}

/// The core chat interface and logic, used both inside the docked desktop side panel
/// and within the floating modal overlay on smaller screens.
class AiAssistantChatPanel extends ConsumerStatefulWidget {
  final bool isDocked;
  final bool isMaximized;
  final VoidCallback? onToggleMaximize;
  final VoidCallback? onClose;

  const AiAssistantChatPanel({
    super.key,
    this.isDocked = false,
    this.isMaximized = false,
    this.onToggleMaximize,
    this.onClose,
  });

  @override
  ConsumerState<AiAssistantChatPanel> createState() => _AiAssistantChatPanelState();
}

class _AiAssistantChatPanelState extends ConsumerState<AiAssistantChatPanel> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isMaximized = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    await ref.read(aiAssistantProvider.notifier).sendMessage(text);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _copyToClipboard(String text, String successMsg) {
    CopyHelper.copy(context, text, customMessage: successMsg);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantProvider);
    return Directionality(
      textDirection: state.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SelectionArea(
        child: Column(
          children: [
            _buildPanelHeader(state),
            if (state.isNavigatorOpen)
              ShipmentLifecycleNavigator(
                onSendMessage: _sendMessage,
              ),
            Expanded(
              child: state.hasApiKey
                  ? _buildMessageList(state)
                  : _buildApiKeySetup(state),
            ),
            if (state.hasApiKey) _buildActiveContextBadge(state),
            if (state.hasApiKey) _buildInputBar(state),
          ],
        ),
      ),
    );
  }

  // ─── Panel Header ────────────────────────────────────────────────────────────

  Widget _buildPanelHeader(AiAssistantState state) {
    final isAr = state.isArabic;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.cobalt, Color(0xFF2980B9)],
        ),
        boxShadow: [
          BoxShadow(color: AppTheme.cobalt.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? l.aiAssistantTitle : 'Smart Import Assistant',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  state.currentScreenContext,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // "My Shipments" / "شحناتي" Lifecycle Navigator Toggle Button
          _buildHeaderAction(
            icon: Icon(
              state.isNavigatorOpen ? Icons.alt_route_rounded : Icons.alt_route_outlined,
              color: state.isNavigatorOpen ? Colors.amberAccent : Colors.white,
              size: 17,
            ),
            tooltip: isAr ? l.aiAssistantMyShipmentsTooltip : 'My Shipments (Lifecycle Navigator)',
            onPressed: () => ref.read(aiAssistantProvider.notifier).toggleNavigator(),
          ),
          const SizedBox(width: 4),
          // Language selector toggle pill (Rule 2: Starting default & switcher, Rule 1: Dynamic detection also updates state)
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLangBtn('AR', state.isArabic, () {
                  ref.read(aiAssistantProvider.notifier).setLanguage('ar');
                }),
                _buildLangBtn('EN', state.isEnglish, () {
                  ref.read(aiAssistantProvider.notifier).setLanguage('en');
                }),
              ],
            ),
          ),
          const SizedBox(width: 3),
          // Copy full conversation transcript dossier button
          if (state.hasApiKey && state.messages.isNotEmpty)
            _buildHeaderAction(
              icon: const Icon(Icons.copy_all_rounded, color: Colors.white70, size: 16),
              tooltip: isAr ? l.aiAssistantCopyTranscriptTooltip : 'Copy full conversation transcript',
              onPressed: () {
                final buffer = StringBuffer();
                buffer.writeln(isAr ? l.aiAssistantTitle : 'Smart Import Assistant');
                if (state.hasActiveContext) {
                  buffer.writeln(state.activeContext!.displayText(state.activeLanguage));
                }
                buffer.writeln('========================================');
                for (final msg in state.messages) {
                  final sender = msg.sender == MessageSender.user
                      ? (isAr ? 'المستخدم' : 'User')
                      : (isAr ? 'المساعد الذكي' : 'Assistant');
                  buffer.writeln('[$sender]:\n${msg.text}\n');
                }
                CopyHelper.copy(
                  context,
                  buffer.toString().trim(),
                  customMessage: isAr ? l.aiAssistantTranscriptCopied : 'Full conversation copied to clipboard',
                );
              },
            ),
          // Clear chat
          if (state.hasApiKey && state.messages.isNotEmpty) ...[
            const SizedBox(width: 2),
            _buildHeaderAction(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 16),
              tooltip: isAr ? l.aiAssistantClearChatTooltip : 'Clear Chat',
              onPressed: () => ref.read(aiAssistantProvider.notifier).clearChat(),
            ),
          ],
          const SizedBox(width: 2),
          // API Key settings
          _buildHeaderAction(
            icon: const Icon(Icons.key_outlined, color: Colors.white70, size: 16),
            tooltip: isAr ? l.aiAssistantApiKeySettingsTooltip : 'API Key Settings',
            onPressed: () => _showApiKeyDialog(state.apiKey),
          ),
          const SizedBox(width: 2),
          // Maximize / Restore
          _buildHeaderAction(
            icon: Icon(
              (widget.onToggleMaximize != null ? widget.isMaximized : _isMaximized)
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
              color: Colors.white70,
              size: 16,
            ),
            tooltip: (widget.onToggleMaximize != null ? widget.isMaximized : _isMaximized)
                ? (isAr ? l.aiAssistantRestoreTooltip : 'Restore size')
                : (isAr ? l.aiAssistantExpandTooltip : 'Expand chat window'),
            onPressed: widget.onToggleMaximize ?? () => setState(() => _isMaximized = !_isMaximized),
          ),
          const SizedBox(width: 2),
          // Close
          _buildHeaderAction(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
            tooltip: isAr ? l.aiAssistantCloseTooltip : 'Close',
            onPressed: widget.onClose ?? () => ref.read(aiAssistantProvider.notifier).togglePanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: icon,
        ),
      ),
    );
  }

  // ─── Active Context Badge ───────────────────────────────────────────────────

  Widget _buildActiveContextBadge(AiAssistantState state) {
    if (!state.hasActiveContext) return const SizedBox.shrink();
    final ctx = state.activeContext!;
    final isAr = state.isArabic;
    final l = context.l10n;
    final displayText = ctx.displayText(isAr ? 'ar' : 'en');
    final stepLabel = ctx.stepName(isAr ? 'ar' : 'en');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: Colors.blueGrey.shade100, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: AppTheme.cobalt, size: 8),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.cobalt),
                tooltip: isAr ? l.aiLifecycleCopySummaryTooltip : 'Copy context summary',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => CopyHelper.copy(
                  context,
                  displayText,
                  customMessage: isAr ? l.aiLifecycleSummaryCopied : 'Context copied to clipboard',
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                tooltip: isAr ? l.aiAssistantClearContextTooltip : 'Clear active context',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => ref.read(aiAssistantProvider.notifier).clearActiveContext(),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              _buildContextShortcut(
                label: isAr ? l.aiAssistantViewDataShortcut : 'View Data',
                icon: Icons.bar_chart_rounded,
                onTap: () => _sendMessage(
                  isAr
                      ? 'اعرض بيانات وموقف مرحلة ($stepLabel) لشحنة ${ctx.displayText("ar")}.'
                      : 'Show data and status of phase ($stepLabel) for shipment ${ctx.displayText("en")}.',
                ),
              ),
              const SizedBox(width: 4),
              _buildContextShortcut(
                label: isAr ? l.aiAssistantUpdateDataShortcut : 'Update Data',
                icon: Icons.edit_note_rounded,
                onTap: () => _sendMessage(
                  isAr
                      ? 'أريد تحديث وتسجيل بيانات مرحلة ($stepLabel) لشحنة ${ctx.displayText("ar")}.'
                      : 'I want to update and record data for phase ($stepLabel) of shipment ${ctx.displayText("en")}.',
                ),
              ),
              const SizedBox(width: 4),
              _buildContextShortcut(
                label: isAr ? l.aiAssistantAskAboutStepShortcut : 'Ask about Step',
                icon: Icons.help_outline_rounded,
                onTap: () => _sendMessage(
                  isAr
                      ? 'ما هي المتطلبات والمستندات اللازمة لإنجاز مرحلة ($stepLabel)؟'
                      : 'What are the requirements and documents needed to complete ($stepLabel)?',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextShortcut({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppTheme.cobalt),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangBtn(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppTheme.cobalt : Colors.white.withOpacity(0.9),
          ),
        ),
      ),
    );
  }

  // ─── Message List ───────────────────────────────────────────────────────────

  Widget _buildMessageList(AiAssistantState state) {
    if (state.messages.isEmpty) {
      return _buildWelcomeScreen(state);
    }

    return SelectionArea(
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: state.messages.length + (state.isLoading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == state.messages.length) {
            return _buildTypingIndicator();
          }
          return _buildMessageBubble(state.messages[i], state);
        },
      ),
    );
  }

  Widget _buildWelcomeScreen(AiAssistantState state) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppTheme.cobalt),
              const SizedBox(width: 6),
              Text(
                state.isArabic ? l.aiAssistantQuickSuggestionsTitle : 'Categorized Quick Suggestions',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...kCategorizedQuickSuggestions.map((cat) => _buildCategorySection(cat, state)),
        ],
      ),
    );
  }

  Widget _buildCategorySection(QuickSuggestionCategory cat, AiAssistantState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(
            children: [
              Icon(cat.icon, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                cat.title(state.activeLanguage),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: cat.items.map((item) => _buildBilingualSuggestionChip(item, state)).toList(),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildBilingualSuggestionChip(BilingualQuickSuggestion item, AiAssistantState state) {
    return GestureDetector(
      onTap: () => _sendMessage(item.prompt(state.activeLanguage)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cobalt.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cobalt.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 12, color: AppTheme.cobalt),
            const SizedBox(width: 5),
            Text(
              item.label(state.activeLanguage),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.cobalt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, AiAssistantState state) {
    final isUser = msg.sender == MessageSender.user;
    final isSystem = msg.sender == MessageSender.system;
    final isAr = state.isArabic;
    final l = context.l10n;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: msg.isError ? AppTheme.crimson.withOpacity(0.08) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: msg.isError ? AppTheme.crimson.withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              msg.isError ? Icons.error_outline : Icons.info_outline,
              size: 13,
              color: msg.isError ? AppTheme.crimson : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 12,
                  color: msg.isError ? AppTheme.crimson : Colors.grey.shade700,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
              tooltip: isAr ? l.aiAssistantCopyNotificationTooltip : 'Copy notification',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copyToClipboard(
                msg.text,
                isAr ? l.aiAssistantNotificationCopied : 'Notification copied ✅',
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: EdgeInsetsDirectional.only(
          top: 4,
          bottom: 4,
          start: isUser ? 36 : 0,
          end: isUser ? 0 : 36,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.cobalt
              : (msg.isError ? AppTheme.crimson.withOpacity(0.06) : Colors.grey.shade100),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(14),
            topEnd: const Radius.circular(14),
            bottomStart: Radius.circular(isUser ? 14 : 4),
            bottomEnd: Radius.circular(isUser ? 4 : 14),
          ),
          border: msg.isError ? Border.all(color: AppTheme.crimson.withOpacity(0.35)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser)
              Text(
                msg.text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.white,
                  height: 1.45,
                ),
              )
            else if (msg.isError)
              Text(
                msg.text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.crimson,
                  height: 1.45,
                ),
              )
            else
              _buildAssistantResponseContent(msg.text, state.isArabic),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _copyToClipboard(
                    msg.text,
                    isUser
                        ? (isAr ? l.aiAssistantUserMessageCopied : 'Your message copied ✅')
                        : (isAr ? l.aiAssistantAssistantMessageCopied : 'Assistant response copied ✅'),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 11,
                          color: isUser ? Colors.white70 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isAr ? 'نسخ' : 'Copy',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isUser ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (msg.isError) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      final currState = ref.read(aiAssistantProvider);
                      final lastUserMsg = currState.messages
                          .lastWhere((m) => m.sender == MessageSender.user, orElse: () => msg);
                      if (lastUserMsg.sender == MessageSender.user) {
                        _sendMessage(lastUserMsg.text);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 12,
                            color: AppTheme.crimson.withOpacity(0.8),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isAr ? l.aiAssistantRetry : 'Retry',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.crimson.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildInlineFormattedText(String text, TextStyle baseStyle) {
    if (!text.contains('**')) {
      return Text(text, style: baseStyle);
    }
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(text: parts[i], style: baseStyle));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildAssistantResponseContent(String text, bool isAr) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 5));
        continue;
      }

      final trimmed = line.trim();

      // 1. Overdue Summary Alert (e.g. ⚠️ 4 مهام متأخرة منذ ...)
      if (trimmed.startsWith('⚠️') &&
          (trimmed.contains('متأخرة') || trimmed.contains('overdue'))) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.crimsonLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.crimsonBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.crimson),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trimmed.replaceFirst(RegExp(r'^⚠️\s*'), ''),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.crimson,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 2. Duplicate Warning Alert Pill (e.g. ⚠️ يبدو تكرار...)
      if (trimmed.startsWith('⚠️') &&
          (trimmed.contains('تكرار') || trimmed.contains('duplicate'))) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 2, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.copy_rounded, size: 13, color: Color(0xFFB45309)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    trimmed.replaceFirst(RegExp(r'^⚠️\s*'), ''),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 3. Completion rate / visual progress bar line
      if (trimmed.contains('نسبة الإنجاز:') || trimmed.contains('Completion Rate:')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              trimmed,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.charcoal,
              ),
            ),
          ),
        );
        continue;
      }

      // 4. Section headers (متأخرة: / مستحقة اليوم: / قادمة:)
      if (trimmed == 'متأخرة:' ||
          trimmed == '**متأخرة:**' ||
          trimmed.toLowerCase() == 'overdue:' ||
          trimmed.toLowerCase() == '**overdue:**') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.crimson, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'المهام المتأخرة:' : 'Overdue Tasks:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.crimson,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      if (trimmed == 'مستحقة اليوم:' ||
          trimmed == '**مستحقة اليوم:**' ||
          trimmed.toLowerCase() == 'due today:' ||
          trimmed.toLowerCase() == '**due today:**') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.orange, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'مستحقة اليوم:' : 'Due Today:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.orange,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      if (trimmed == 'قادمة:' ||
          trimmed == '**قادمة:**' ||
          trimmed.toLowerCase() == 'upcoming:' ||
          trimmed.toLowerCase() == '**upcoming:**') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.cobalt, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'المهام القادمة:' : 'Upcoming Tasks:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cobalt,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 5. Individual Priority Task Rows (🔴, 🟠, 🟡, 🟢, ✅)
      if (trimmed.startsWith('🔴') ||
          trimmed.startsWith('🟠') ||
          trimmed.startsWith('🟡') ||
          trimmed.startsWith('🟢') ||
          trimmed.startsWith('✅')) {
        final Color cardBg;
        final Color cardBorder;
        final String icon;
        if (trimmed.startsWith('🔴')) {
          cardBg = const Color(0xFFFFF5F5);
          cardBorder = const Color(0xFFFFD1D1);
          icon = '🔴';
        } else if (trimmed.startsWith('🟠')) {
          cardBg = const Color(0xFFFFF9F2);
          cardBorder = const Color(0xFFFFE0B2);
          icon = '🟠';
        } else if (trimmed.startsWith('🟡')) {
          cardBg = const Color(0xFFFFFDE7);
          cardBorder = const Color(0xFFFFF59D);
          icon = '🟡';
        } else {
          cardBg = AppTheme.emeraldLight;
          cardBorder = AppTheme.emeraldBorder;
          icon = trimmed.startsWith('✅') ? '✅' : '🟢';
        }

        final contentText = trimmed.substring(icon.length).trim();

        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(icon, style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildInlineFormattedText(
                    contentText,
                    const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.charcoal,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 6. Action Callout Box (المطلوب منك الآن: / What is needed now:)
      if (trimmed.startsWith('المطلوب منك الآن:') ||
          trimmed.startsWith('What is needed now:')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.touch_app_rounded, size: 16, color: AppTheme.cobalt),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildInlineFormattedText(
                    trimmed,
                    const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 7. General text line
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: _buildInlineFormattedText(
            trimmed,
            const TextStyle(
              fontSize: 12.5,
              color: AppTheme.charcoal,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0),
            const SizedBox(width: 4),
            _dot(150),
            const SizedBox(width: 4),
            _dot(300),
          ],
        ),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ─── Input Bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar(AiAssistantState state) {
    final isAr = state.isArabic;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              focusNode: _focusNode,
              enabled: !state.isLoading,
              maxLines: 3,
              minLines: 1,
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              contextMenuBuilder: (context, editableTextState) {
                return AdaptiveTextSelectionToolbar.editableText(
                  editableTextState: editableTextState,
                );
              },
              decoration: InputDecoration(
                hintText: isAr
                    ? l.aiAssistantInputHint
                    : 'Ask about imports, customs, freight, tasks...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, size: 18, color: AppTheme.cobalt),
                  tooltip: isAr ? l.aiAssistantPasteTooltip : 'Paste from clipboard',
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null && data!.text!.isNotEmpty) {
                            final currentText = _inputCtrl.text;
                            final selection = _inputCtrl.selection;
                            if (selection.isValid && selection.start >= 0 && selection.end >= 0) {
                              final newText = currentText.replaceRange(
                                selection.start,
                                selection.end,
                                data.text!,
                              );
                              _inputCtrl.value = TextEditingValue(
                                text: newText,
                                selection: TextSelection.collapsed(
                                  offset: selection.start + data.text!.length,
                                ),
                              );
                            } else {
                              _inputCtrl.text = '$currentText${data.text}';
                              _inputCtrl.selection = TextSelection.collapsed(
                                offset: _inputCtrl.text.length,
                              );
                            }
                          }
                        },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.cobalt),
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (v) => _sendMessage(v),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: isAr ? l.aiAssistantSendTooltip : 'Send',
            child: GestureDetector(
              onTap: state.isLoading ? null : () => _sendMessage(_inputCtrl.text),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: state.isLoading ? Colors.grey.shade300 : AppTheme.cobalt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: state.isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : Transform.rotate(
                        angle: isAr ? 3.14159 : 0.0,
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 17),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── API Key Setup ──────────────────────────────────────────────────────────

  Widget _buildApiKeySetup(AiAssistantState state) {
    final isAr = state.isArabic;
    final l = context.l10n;
    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cobalt.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.key_rounded, color: AppTheme.cobalt, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              isAr ? l.aiAssistantActivateTitle : 'Activate AI Assistant',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.charcoal),
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? l.aiAssistantActivateDesc
                  : 'Enter your Gemini API Key to start chatting with the smart import assistant.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showApiKeyDialog(AiAssistantNotifier.defaultApiKey),
              icon: const Icon(Icons.key_outlined, size: 16),
              label: Text(isAr ? l.aiAssistantEnterApiKey : 'Enter API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () async {
                const url = 'https://aistudio.google.com/app/apikey';
                await Clipboard.setData(const ClipboardData(text: url));
                try {
                  if (Platform.isWindows) {
                    await Process.run('cmd', ['/c', 'start', '', url.replaceAll('&', '^&')], runInShell: true);
                  } else if (Platform.isMacOS) {
                    await Process.run('open', [url]);
                  } else if (Platform.isLinux) {
                    await Process.run('xdg-open', [url]);
                  }
                } catch (_) {}
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAr
                            ? l.aiAssistantCopiedUrlSuccess
                            : 'Opened Google AI Studio in browser and copied URL to clipboard',
                      ),
                      backgroundColor: AppTheme.cobalt,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              icon: Icon(Icons.open_in_new, size: 13, color: Colors.grey.shade600),
              label: Text(
                isAr
                    ? l.aiAssistantGetApiKeyLabel
                    : 'Get API Key from Google AI Studio (Click to open)',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── API Key Dialog ─────────────────────────────────────────────────────────

  void _showApiKeyDialog(String? currentKey) {
    final state = ref.read(aiAssistantProvider);
    final isAr = state.isArabic;
    final l = context.l10n;
    final effectiveKey = (currentKey != null && currentKey.isNotEmpty)
        ? currentKey
        : (state.apiKey ?? AiAssistantNotifier.defaultApiKey);
    final ctrl = TextEditingController(text: effectiveKey);
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.key_rounded, color: AppTheme.cobalt, size: 20),
                const SizedBox(width: 10),
                Text(isAr ? l.aiAssistantApiKeyDialogTitle : 'Gemini API Key'),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isAr
                              ? 'احصل على المفتاح مجاناً من المنصة الرسمية:'
                              : 'Get free API key from Google AI Studio:',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          const url = 'https://aistudio.google.com/app/apikey';
                          await Clipboard.setData(const ClipboardData(text: url));
                          try {
                            if (Platform.isWindows) {
                              await Process.run('cmd', ['/c', 'start', '', url.replaceAll('&', '^&')], runInShell: true);
                            }
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.open_in_new, size: 12),
                        label: Text(isAr ? l.aiAssistantOpenLink : 'Open Link', style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    obscureText: obscure,
                    contextMenuBuilder: (context, editableTextState) {
                      return AdaptiveTextSelectionToolbar.editableText(
                        editableTextState: editableTextState,
                      );
                    },
                    decoration: InputDecoration(
                      labelText: isAr ? l.aiAssistantApiKeyFieldLabel : 'API Key',
                      hintText: 'AIzaSy...',
                      prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 16,
                        ),
                        onPressed: () => setLocal(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (currentKey != null || state.hasApiKey) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppTheme.emerald, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          isAr ? l.aiAssistantApiKeyActiveStatus : 'Active and configured API key',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (currentKey != null || state.hasApiKey)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(aiAssistantProvider.notifier).clearApiKey();
                  },
                  style: TextButton.styleFrom(foregroundColor: AppTheme.crimson),
                  child: Text(isAr ? l.aiAssistantDisableKey : 'Disable Key'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isAr ? l.aiAssistantCancel : 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(aiAssistantProvider.notifier).saveApiKey(ctrl.text);
                },
                child: Text(isAr ? l.aiAssistantSaveAndActivate : 'Save & Activate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
