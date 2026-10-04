import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../providers/ai_assistant_provider.dart';
import '../theme/app_theme.dart';
import '../theme/density_provider.dart';

/// Compact top-bar button for the Smart Import AI Assistant.
/// Replaces the bottom-right floating launcher with a streamlined, downsized button
/// in the global system header that preserves the original vibrant orange gradient,
/// chat icon, and live online emerald status indicator.
class AiAssistantTopBarButton extends ConsumerWidget {
  const AiAssistantTopBarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiAssistantProvider);
    final density = ref.watch(displayDensityProvider);
    final l10n = AppLocalizations.of(context);

    final double size = density.isUltraCompact ? 24.0 : (density.isCompact ? 26.0 : 28.0);
    final double iconSize = density.isUltraCompact ? 13.0 : (density.isCompact ? 14.0 : 15.0);
    final double badgeSize = density.isUltraCompact ? 6.0 : 7.0;

    final isOpen = state.isPanelOpen;
    final tooltipText = isOpen
        ? l10n.aiAssistantCloseTooltip
        : l10n.aiAssistantOpenTooltip;

    return Tooltip(
      message: tooltipText,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => ref.read(aiAssistantProvider.notifier).togglePanel(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: isOpen
                    ? [AppTheme.charcoal, const Color(0xFF1E293B)]
                    : [const Color(0xFFF4511E), const Color(0xFFE64A19)],
              ),
              shape: BoxShape.circle,
              border: isOpen
                  ? Border.all(color: const Color(0xFFF4511E), width: 1.2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (isOpen ? AppTheme.charcoal : const Color(0xFFE64A19))
                      .withOpacity(0.38),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  isOpen ? Icons.close_rounded : Icons.chat_bubble_outline_rounded,
                  color: isOpen ? const Color(0xFFFF8A65) : Colors.white,
                  size: iconSize,
                ),

                // Loading Indicator Ring
                if (state.isLoading)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),

                // Live Online Green Status Badge
                if (!isOpen)
                  Positioned(
                    top: 1.0,
                    right: 1.0,
                    child: Container(
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        color: AppTheme.emerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.0),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
