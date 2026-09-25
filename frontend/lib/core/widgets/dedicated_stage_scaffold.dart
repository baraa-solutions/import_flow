import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/display_name_resolver.dart';
import '../theme/app_theme.dart';
import '../theme/density_provider.dart';
import 'back_to_dashboard_button.dart';
import 'shipment_stage_lifecycle_control.dart';

/// A dedicated, full-width scaffold for independent operational stages in ImportFlow ERP.
/// Provides a unified enterprise header with stage code badge, lifecycle controls,
/// shipment selector, and header actions while dedicating 100% of the screen width
/// to the actual stage workspace without nested vertical sub-tab navigation.
class DedicatedStageScaffold extends ConsumerWidget {
  final String stageCode;
  final String titleAr;
  final String titleEn;
  final IconData headerIcon;
  final Color headerColor;
  final Widget body;
  final List<Widget>? headerActions;
  final Widget? topBanner;
  final int? selectedImportFileId;
  final bool showStageLifecycleControls;
  final VoidCallback? onShipmentStatusChanged;

  const DedicatedStageScaffold({
    super.key,
    required this.stageCode,
    required this.titleAr,
    required this.titleEn,
    required this.headerIcon,
    this.headerColor = AppTheme.cobalt,
    required this.body,
    this.headerActions,
    this.topBanner,
    this.selectedImportFileId,
    this.showStageLifecycleControls = true,
    this.onShipmentStatusChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = ref.watch(displayDensityProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Top Header Bar
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: density.isUltraCompact ? 10 : 14,
              vertical: density.isUltraCompact ? 3.0 : (density.isCompact ? 4.5 : 6.0),
            ),
            decoration: BoxDecoration(
              color: AppTheme.charcoal,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final isArabic = Directionality.of(context) == TextDirection.rtl;
                final badgeText = DisplayNameResolver.resolveStageBadge(stageCode, isArabic: isArabic);

                final iconAndTitle = Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(density.isUltraCompact ? 4 : (density.isCompact ? 5.5 : 7)),
                      decoration: BoxDecoration(
                        color: headerColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: headerColor.withOpacity(0.5)),
                      ),
                      child: Icon(headerIcon, color: headerColor, size: density.headerIconSize * 0.9),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              isArabic ? titleAr : titleEn,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: DisplayDensityMode.clampFontSize(density.headerTitleFontSize * 0.9),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            // Flexible so a long badge + title never overflow the header row.
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: density.isUltraCompact ? 5 : 7,
                                  vertical: density.isUltraCompact ? 1 : 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: headerColor.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: headerColor.withOpacity(0.6)),
                                ),
                                child: Text(
                                  badgeText,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: DisplayDensityMode.clampFontSize(density.headerSubtitleFontSize * 0.9),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );

                final hasControls = showStageLifecycleControls;
                final hasActions = headerActions != null && headerActions!.isNotEmpty;

                if (headerConstraints.maxWidth < 650) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: iconAndTitle),
                          const SizedBox(width: 8),
                          const BackToDashboardButton(),
                        ],
                      ),
                      if (hasControls || hasActions) ...[
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasControls) ...[
                                ShipmentStageLifecycleControl(
                                  importFileId: selectedImportFileId,
                                  stageName: Directionality.of(context) == TextDirection.rtl ? titleAr : titleEn,
                                  stageCode: stageCode,
                                  onStatusChanged: onShipmentStatusChanged,
                                ),
                                if (hasActions) const SizedBox(width: 8),
                              ],
                              if (hasActions) ...headerActions!,
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }

                // Desktop / Laptop: single row (<40px) when title + lifecycle controls + actions
                // + back button fit; otherwise title/back on row 1 and controls/actions on row 2,
                // so the lifecycle buttons are never clipped.
                return AdaptiveStageHeaderLayout(
                  textDirection: Directionality.of(context),
                  title: iconAndTitle,
                  trailing: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                            if (showStageLifecycleControls) ...[
                              const SizedBox(width: 10),
                              // Stop Shipment & Skip Step remain directly visible and prominent in AppTheme.crimson
                              ShipmentStageLifecycleControl(
                                importFileId: selectedImportFileId,
                                stageName: Directionality.of(context) == TextDirection.rtl ? titleAr : titleEn,
                                stageCode: stageCode,
                                onStatusChanged: onShipmentStatusChanged,
                              ),
                            ],
                            if (hasActions) ...[
                              const SizedBox(width: 8),
                              // Secondary actions menu or compact row
                              if (headerConstraints.maxWidth < 1100 && headerActions!.length > 2)
                                PopupMenuButton<int>(
                                  tooltip: isArabic ? 'إجراءات إضافية' : 'More Actions',
                                  position: PopupMenuPosition.under,
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  color: const Color(0xFF1E2631),
                                  itemBuilder: (ctx) => [
                                    for (int i = 0; i < headerActions!.length; i++)
                                      PopupMenuItem<int>(
                                        value: i,
                                        height: 36,
                                        child: headerActions![i],
                                      ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cobalt.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: AppTheme.cobalt.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isArabic ? 'الإجراءات' : 'Actions',
                                          style: TextStyle(
                                            fontSize: density.buttonFontSize,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white70),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (int i = 0; i < headerActions!.length; i++) ...[
                                      headerActions![i],
                                      if (i < headerActions!.length - 1) const SizedBox(width: 6),
                                    ],
                                  ],
                                ),
                            ],
                      ],
                    ),
                  ),
                  back: const BackToDashboardButton(),
                );
              },
            ),
          ),

          // Optional Top Banner
          if (topBanner != null) topBanner!,

          // 100% Full-Width Body Workspace (Maximized Viewport)
          Expanded(
            child: body,
          ),
        ],
      ),
    );
  }
}

/// Lays out a stage header as a single row when `title` (at least 200 px) +
/// `trailing` + `back` fit the available width; otherwise `title` and `back` share the
/// first row and `trailing` moves to a second row (full width, horizontally scrollable).
///
/// `trailing` is measured at its natural width, so the decision is based on the real
/// width of the lifecycle controls and header actions rather than a fixed breakpoint.
@visibleForTesting
class AdaptiveStageHeaderLayout extends MultiChildRenderObjectWidget {
  AdaptiveStageHeaderLayout({
    super.key,
    required Widget title,
    required Widget trailing,
    required Widget back,
    required this.textDirection,
  }) : super(children: [title, trailing, back]);

  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAdaptiveStageHeader(textDirection: textDirection);

  @override
  void updateRenderObject(BuildContext context, RenderAdaptiveStageHeader renderObject) {
    renderObject.textDirection = textDirection;
  }
}

class _HeaderSlotParentData extends ContainerBoxParentData<RenderBox> {}

/// Render object for [AdaptiveStageHeaderLayout].
@visibleForTesting
class RenderAdaptiveStageHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderSlotParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderSlotParentData> {
  RenderAdaptiveStageHeader({required TextDirection textDirection}) : _textDirection = textDirection;

  /// Minimum width reserved for the title before `trailing` wraps to row 2.
  static const double _minTitleWidth = 200;
  static const double _gap = 8;
  static const double _rowGap = 6;

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  /// True when the last layout used a single row (exposed for tests/diagnostics).
  bool isSingleRow = true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderSlotParentData) {
      child.parentData = _HeaderSlotParentData();
    }
  }

  void _place(RenderBox child, double x, double y, double maxWidth) {
    final dx = _textDirection == TextDirection.rtl ? maxWidth - x - child.size.width : x;
    (child.parentData! as _HeaderSlotParentData).offset = Offset(dx, y);
  }

  @override
  void performLayout() {
    final title = firstChild!;
    final trailing = childAfter(title)!;
    final back = childAfter(trailing)!;
    final maxWidth = constraints.maxWidth;
    final loose = BoxConstraints(maxHeight: constraints.maxHeight);

    back.layout(loose, parentUsesSize: true);
    trailing.layout(loose, parentUsesSize: true); // natural (unconstrained) width
    final trailingGap = trailing.size.width > 0 ? _gap : 0.0;
    final needed = _minTitleWidth + trailingGap + trailing.size.width + _gap + back.size.width;

    isSingleRow = !maxWidth.isFinite || needed <= maxWidth;
    if (isSingleRow) {
      final titleWidth = maxWidth.isFinite
          ? maxWidth - trailing.size.width - trailingGap - back.size.width - _gap
          : _minTitleWidth;
      title.layout(loose.copyWith(minWidth: titleWidth, maxWidth: titleWidth), parentUsesSize: true);
      final height = [title.size.height, trailing.size.height, back.size.height].reduce((a, b) => a > b ? a : b);
      final width = titleWidth + trailingGap + trailing.size.width + _gap + back.size.width;
      _place(title, 0, (height - title.size.height) / 2, width);
      _place(trailing, titleWidth + trailingGap, (height - trailing.size.height) / 2, width);
      _place(back, width - back.size.width, (height - back.size.height) / 2, width);
      size = constraints.constrain(Size(width, height));
      return;
    }

    // Two rows: [title ... back] then [trailing] (re-laid out at the available width).
    final titleWidth = (maxWidth - back.size.width - _gap).clamp(0.0, double.infinity);
    title.layout(loose.copyWith(minWidth: titleWidth, maxWidth: titleWidth), parentUsesSize: true);
    trailing.layout(loose.copyWith(maxWidth: maxWidth), parentUsesSize: true);
    final row1 = title.size.height > back.size.height ? title.size.height : back.size.height;
    _place(title, 0, (row1 - title.size.height) / 2, maxWidth);
    _place(back, maxWidth - back.size.width, (row1 - back.size.height) / 2, maxWidth);
    _place(trailing, 0, row1 + _rowGap, maxWidth);
    size = constraints.constrain(Size(maxWidth, row1 + _rowGap + trailing.size.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
