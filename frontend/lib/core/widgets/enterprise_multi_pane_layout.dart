import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import 'directional_icon.dart';

/// An enterprise-grade, responsive Master-Detail Multi-Pane Layout optimized for desktop displays (1080p, 2K, 4K).
///
/// Features:
/// - Side-by-side dual panes on desktop/large screens (Master list ~35%, Detail pane ~65%)
/// - Smooth interactive horizontal splitter with mouse drag resizing
/// - 1-Click collapsible master sidebar to maximize work area for documents & calculations
/// - Graceful responsive fallback for tablets and narrow windows (< 1024px)
/// - Directionality-aware (fully RTL and LTR compatible)
/// - Themed empty state placeholder when no item is currently selected
class EnterpriseMultiPaneLayout extends StatefulWidget {
  /// The sidebar/master widget (e.g. shipment list, invoices overview, search panel).
  final Widget masterPane;

  /// The main detail pane widget (e.g. selected shipment file, document viewer, customs clearance tab).
  final Widget? detailPane;

  /// Optional custom widget shown in the detail area when no item is selected.
  final Widget? emptyDetailPlaceholder;

  /// Header title shown in the master pane toolbar (optional).
  final String? masterTitle;

  /// Actions or search controls rendered in master pane header (optional).
  final List<Widget>? masterActions;

  /// Header title for the detail pane (optional).
  final String? detailTitle;

  /// Actions rendered in detail pane header (optional).
  final List<Widget>? detailActions;

  /// Initial width in pixels of the master pane. Defaults to 400.0.
  final double initialMasterWidth;

  /// Minimum allowable width for the master pane during drag resizing. Defaults to 280.0.
  final double minMasterWidth;

  /// Maximum allowable width for the master pane during drag resizing. Defaults to 650.0.
  final double maxMasterWidth;

  /// Width threshold below which the layout collapses to single-pane navigation. Defaults to 1024.0.
  final double responsiveBreakpoint;

  /// Whether the user can drag the divider to resize master pane. Defaults to true.
  final bool allowResize;

  /// Callback when user hits the back button in narrow mode.
  final VoidCallback? onBackToMaster;

  const EnterpriseMultiPaneLayout({
    super.key,
    required this.masterPane,
    this.detailPane,
    this.emptyDetailPlaceholder,
    this.masterTitle,
    this.masterActions,
    this.detailTitle,
    this.detailActions,
    this.initialMasterWidth = 400.0,
    this.minMasterWidth = 280.0,
    this.maxMasterWidth = 650.0,
    this.responsiveBreakpoint = 1024.0,
    this.allowResize = true,
    this.onBackToMaster,
  });

  @override
  State<EnterpriseMultiPaneLayout> createState() => _EnterpriseMultiPaneLayoutState();
}

class _EnterpriseMultiPaneLayoutState extends State<EnterpriseMultiPaneLayout> {
  late double _masterWidth;
  bool _isMasterCollapsed = false;

  @override
  void initState() {
    super.initState();
    _masterWidth = widget.initialMasterWidth;
  }

  void _toggleMasterCollapse() {
    setState(() {
      _isMasterCollapsed = !_isMasterCollapsed;
    });
  }

  void _resetMasterWidth() {
    setState(() {
      _masterWidth = widget.initialMasterWidth;
      _isMasterCollapsed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < widget.responsiveBreakpoint;

        // 1. Narrow / Mobile Screen: Display single pane at a time
        if (isNarrow) {
          if (widget.detailPane != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: widget.onBackToMaster,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text(l10n.multiPaneBackToList),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.cobalt,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.detailTitle != null) ...[
                        Expanded(
                          child: Text(
                            widget.detailTitle!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (widget.detailActions != null) ...widget.detailActions!,
                    ],
                  ),
                ),
                Expanded(child: widget.detailPane!),
              ],
            );
          }
          return widget.masterPane;
        }

        // 2. Wide Desktop: Dual-Pane Master & Detail with Interactive Splitter
        final effectiveMasterWidth = _isMasterCollapsed ? 0.0 : _masterWidth.clamp(
          widget.minMasterWidth,
          constraints.maxWidth - 320.0,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Master Pane
            if (!_isMasterCollapsed)
              SizedBox(
                width: effectiveMasterWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.masterTitle != null || widget.masterActions != null)
                      _buildPaneHeader(
                        title: widget.masterTitle ?? l10n.multiPaneSidebarTitle,
                        actions: [
                          if (widget.masterActions != null) ...widget.masterActions!,
                          IconButton(
                            icon: const DirectionalIcon(Icons.menu_open_rounded, size: 18),
                            tooltip: l10n.multiPaneCollapseSidebar,
                            onPressed: _toggleMasterCollapse,
                          ),
                        ],
                        isDark: isDark,
                      ),
                    Expanded(child: widget.masterPane),
                  ],
                ),
              ),

            // Vertical Splitter & Collapse Bar
            _buildSplitterBar(context, isDark: isDark, l10n: l10n),

            // Detail Pane or Empty Placeholder
            Expanded(
              child: Container(
                color: isDark ? AppTheme.darkCardBackground : Colors.white,
                child: widget.detailPane != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.detailTitle != null || widget.detailActions != null || _isMasterCollapsed)
                            _buildPaneHeader(
                              title: widget.detailTitle ?? l10n.multiPaneDetailsTitle,
                              leading: _isMasterCollapsed
                                  ? IconButton(
                                      icon: const Icon(Icons.menu_rounded, size: 20),
                                      tooltip: l10n.multiPaneExpandSidebar,
                                      onPressed: _toggleMasterCollapse,
                                    )
                                  : null,
                              actions: widget.detailActions,
                              isDark: isDark,
                            ),
                          Expanded(child: widget.detailPane!),
                        ],
                      )
                    : (widget.emptyDetailPlaceholder ?? _buildDefaultEmptyState(isDark: isDark, l10n: l10n)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaneHeader({
    required String title,
    Widget? leading,
    List<Widget>? actions,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actions != null) ...actions,
        ],
      ),
    );
  }

  Widget _buildSplitterBar(BuildContext context, {required bool isDark, required AppLocalizations l10n}) {
    final borderColor = isDark ? AppTheme.darkBorder : Colors.grey.shade300;
    final handleColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;

    if (_isMasterCollapsed) {
      return Container(
        width: 24,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
          border: BorderDirectional(
            end: BorderSide(color: borderColor, width: 1.0),
          ),
        ),
        child: InkWell(
          onTap: _toggleMasterCollapse,
          child: Center(
            child: Tooltip(
              message: l10n.multiPaneExpandSidebar,
              // chevron_right has matchTextDirection: it already points
              // left in RTL (toward the content) without a manual swap.
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.cobalt,
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: widget.allowResize ? SystemMouseCursors.resizeColumn : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: widget.allowResize
            ? (details) {
                final isRtl = Directionality.of(context) == TextDirection.rtl;
                final delta = isRtl ? -details.delta.dx : details.delta.dx;
                setState(() {
                  _masterWidth = (_masterWidth + delta).clamp(
                    widget.minMasterWidth,
                    widget.maxMasterWidth,
                  );
                });
              }
            : null,
        onDoubleTap: widget.allowResize ? _resetMasterWidth : null,
        child: Container(
          width: 8,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
            border: Border.symmetric(
              vertical: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 28,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultEmptyState({required bool isDark, required AppLocalizations l10n}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppTheme.darkSurface : AppTheme.cobalt.withOpacity(0.08),
              ),
              child: Icon(
                Icons.view_sidebar_outlined,
                size: 48,
                color: isDark ? AppTheme.wcagCobalt : AppTheme.cobalt,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.multiPaneDetailsTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                l10n.multiPaneSelectPrompt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
