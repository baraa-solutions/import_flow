import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/container_requirement_engine.dart';

class ContainerLoadPlanPainter extends CustomPainter {
  final ContainerPackingResult plan;
  final bool isTopView;

  ContainerLoadPlanPainter({
    required this.plan,
    required this.isTopView,
  });

  // Vibrant palette matching the realistic container load reference design
  static const List<Color> packageColors = [
    Color(0xFFD94D4D), // 1: Crimson Red
    Color(0xFF2C7BE5), // 2: Royal Blue
    Color(0xFF67B035), // 3: Leaf Green
    Color(0xFF7E3794), // 4: Deep Purple
    Color(0xFF1BA39C), // 5: Ocean Teal
    Color(0xFFE67E22), // 6: Tangerine Orange
    Color(0xFFF1B70E), // 7: Golden Yellow
    Color(0xFFD63384), // 8: Rose Magenta
    Color(0xFF8DC63F), // 9: Bright Lime
    Color(0xFFA0522D), // 10: Terracotta
    Color(0xFF20B2AA), // 11: Light Sea Green
    Color(0xFFE74C3C), // 12: Bright Red
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final spec = plan.spec;
    final double contL = spec.internalLength;
    final double contH = isTopView ? spec.internalWidth : spec.internalHeight;

    // Header badge height reservation
    const double headerBadgeHeight = 24.0;
    const double marginHorizontal = 12.0;
    const double marginVertical = 8.0;

    final double availableW = size.width - (2 * marginHorizontal);
    final double availableH = size.height - (2 * marginVertical) - headerBadgeHeight;

    final double scaleX = availableW / contL;
    final double scaleY = availableH / contH;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double drawnContW = contL * scale;
    final double drawnContH = contH * scale;

    final double offsetX = marginHorizontal + (availableW - drawnContW) / 2;
    final double offsetY = marginVertical + headerBadgeHeight + (availableH - drawnContH) / 2;

    final Rect containerInnerRect = Rect.fromLTWH(offsetX, offsetY, drawnContW, drawnContH);

    // 1. Draw Container Outer Metallic Structure & Background
    _drawContainerStructure(canvas, containerInnerRect, scale, contL, contH);

    // 2. Draw Realistic Corrugated / Steel Back Wall
    _drawCorrugatedBackWall(canvas, containerInnerRect);

    // 3. Draw Header Title Badge ("SIDE VIEW (LEFT WALL REMOVED)" or "TOP VIEW (ROOF REMOVED)")
    _drawHeaderBadge(canvas, offsetX, marginVertical, containerInnerRect);

    // 4. Draw Wooden Pallets (for Side View)
    const double palletHeightCm = 12.0;
    final double palletHeightPx = palletHeightCm * scale;

    if (!isTopView) {
      _drawWoodenPallets(canvas, containerInnerRect, scale, palletHeightPx);
    }

    // 5. Draw Placed Cargo Items
    _drawCargoPackages(canvas, containerInnerRect, scale, contH, palletHeightPx);
  }

  void _drawContainerStructure(Canvas canvas, Rect innerRect, double scale, double contL, double contH) {
    const double beamThickness = 7.0;
    final Rect outerRect = Rect.fromLTRB(
      innerRect.left - beamThickness,
      innerRect.top - beamThickness,
      innerRect.right + beamThickness,
      innerRect.bottom + beamThickness,
    );

    // Container Outer Frame (Industrial Steel Slate)
    final Paint framePaint = Paint()
      ..color = const Color(0xFF2C3440)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(outerRect, const Radius.circular(3)), framePaint);

    // Corner Castings details (Top-Left, Top-Right, Bottom-Left, Bottom-Right)
    final Paint cornerPaint = Paint()..color = const Color(0xFF1E252E);
    const double cornerSize = 10.0;
    canvas.drawRect(Rect.fromLTWH(outerRect.left, outerRect.top, cornerSize, cornerSize), cornerPaint);
    canvas.drawRect(Rect.fromLTWH(outerRect.right - cornerSize, outerRect.top, cornerSize, cornerSize), cornerPaint);
    canvas.drawRect(Rect.fromLTWH(outerRect.left, outerRect.bottom - cornerSize, cornerSize, cornerSize), cornerPaint);
    canvas.drawRect(Rect.fromLTWH(outerRect.right - cornerSize, outerRect.bottom - cornerSize, cornerSize, cornerSize), cornerPaint);

    // Steel highlight border
    final Paint innerBorderPaint = Paint()
      ..color = const Color(0xFF4A5568)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(innerRect, innerBorderPaint);
  }

  void _drawCorrugatedBackWall(Canvas canvas, Rect innerRect) {
    // Background Dark Metal
    final Paint bgPaint = Paint()..color = const Color(0xFF333D4B);
    canvas.drawRect(innerRect, bgPaint);

    // Vertical corrugated ridges
    const double ribWidth = 14.0;
    final int ribCount = (innerRect.width / ribWidth).ceil();

    final Paint lightRibPaint = Paint()..color = const Color(0xFF3B4656);
    final Paint darkRibPaint = Paint()..color = const Color(0xFF28313D);

    canvas.save();
    canvas.clipRect(innerRect);

    for (int i = 0; i < ribCount; i++) {
      final double x = innerRect.left + (i * ribWidth);
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(x, innerRect.top, ribWidth, innerRect.height), lightRibPaint);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, innerRect.top, ribWidth, innerRect.height), darkRibPaint);
      }
      // Shadow groove line
      final Paint linePaint = Paint()
        ..color = const Color(0xFF1F2630)
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(x, innerRect.top), Offset(x, innerRect.bottom), linePaint);
    }

    canvas.restore();
  }

  void _drawHeaderBadge(Canvas canvas, double leftX, double topY, Rect innerRect) {
    final String label = isTopView
        ? 'TOP VIEW (ROOF REMOVED) — Internal ${plan.spec.internalLength.toStringAsFixed(0)} x ${plan.spec.internalWidth.toStringAsFixed(0)} cm'
        : 'SIDE VIEW (LEFT WALL REMOVED) — Internal ${plan.spec.internalLength.toStringAsFixed(0)} x ${plan.spec.internalHeight.toStringAsFixed(0)} cm';

    const double badgeH = 18.0;
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double badgeW = math.max(tp.width + 16, 180.0);
    final RRect badgeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(innerRect.left, topY + 2, badgeW, badgeH),
      const Radius.circular(3),
    );

    // Dark Navy Blue Header Badge (as seen in the reference image)
    final Paint badgePaint = Paint()..color = const Color(0xFF0D253F);
    canvas.drawRRect(badgeRRect, badgePaint);

    final Paint badgeBorder = Paint()
      ..color = const Color(0xFF1E40AF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(badgeRRect, badgeBorder);

    tp.paint(canvas, Offset(innerRect.left + 8, topY + 2 + (badgeH - tp.height) / 2));
  }

  void _drawWoodenPallets(Canvas canvas, Rect innerRect, double scale, double palletHeightPx) {
    // Find unique floor item footprints along X axis
    final floorItems = plan.placedItems.where((p) => p.isOnFloor).toList();

    for (final p in floorItems) {
      final double itemX = innerRect.left + (p.x * scale);
      final double itemW = p.length * scale;
      final double palletTop = innerRect.bottom - palletHeightPx;

      if (itemW < 8) continue;

      final Rect palletRect = Rect.fromLTWH(itemX + 1, palletTop, itemW - 2, palletHeightPx);

      // Pallet Top Board (Warm Wood Tone)
      final Paint woodTopPaint = Paint()..color = const Color(0xFFD4A373);
      canvas.drawRect(Rect.fromLTWH(palletRect.left, palletRect.top, palletRect.width, palletHeightPx * 0.35), woodTopPaint);

      // Pallet Spacer Blocks (Left, Middle, Right)
      final Paint woodBlockPaint = Paint()..color = const Color(0xFF9C6B3C);
      final double blockW = math.min(10.0, palletRect.width / 4);
      final double blockH = palletHeightPx * 0.45;
      final double blockY = palletRect.top + (palletHeightPx * 0.35);

      // Left block
      canvas.drawRect(Rect.fromLTWH(palletRect.left + 2, blockY, blockW, blockH), woodBlockPaint);
      // Middle block
      if (palletRect.width > 24) {
        canvas.drawRect(Rect.fromLTWH(palletRect.left + (palletRect.width - blockW) / 2, blockY, blockW, blockH), woodBlockPaint);
      }
      // Right block
      canvas.drawRect(Rect.fromLTWH(palletRect.right - blockW - 2, blockY, blockW, blockH), woodBlockPaint);

      // Pallet Bottom Board
      final Paint woodBottomPaint = Paint()..color = const Color(0xFFB07D4E);
      canvas.drawRect(Rect.fromLTWH(palletRect.left, palletRect.bottom - (palletHeightPx * 0.2), palletRect.width, palletHeightPx * 0.2), woodBottomPaint);
    }
  }

  void _drawCargoPackages(Canvas canvas, Rect innerRect, double scale, double contH, double palletHeightPx) {
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Sort items by z ascending so bottom items draw first and top items overlay naturally
    final itemsToDraw = List<PlacedItem>.from(plan.placedItems)
      ..sort((a, b) => a.z.compareTo(b.z));

    for (int i = 0; i < itemsToDraw.length; i++) {
      final p = itemsToDraw[i];
      final Color baseColor = packageColors[i % packageColors.length];

      double itemX = innerRect.left + (p.x * scale);
      double itemY = 0.0;
      double itemW = p.length * scale;
      double itemH = 0.0;

      if (isTopView) {
        // 2.5D Elevation offset: shift stacked items slightly UP and RIGHT so lower layers remain visible underneath
        final double elevationShift = (p.z / plan.spec.internalHeight) * 14.0;
        itemX += elevationShift;
        itemY = innerRect.top + (contH - p.y - p.width) * scale - elevationShift;
        itemW = p.length * scale;
        itemH = p.width * scale;
      } else {
        final double elevation = p.z * scale;
        final double baseOffsetFromFloor = p.isOnFloor ? palletHeightPx : (palletHeightPx + elevation);
        itemY = innerRect.bottom - baseOffsetFromFloor - (p.height * scale);
        itemH = p.height * scale;
      }

      final Rect itemRect = Rect.fromLTWH(itemX + 1, itemY, math.max(itemW - 2, 2), math.max(itemH, 2));

      // 0. Draw Drop Shadow for Stacked Items (z > 0)
      if (p.z > 0.01) {
        final Paint shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawRect(itemRect.shift(const Offset(2, 3)), shadowPaint);
      }

      // 1. Cargo Box Base Fill with Subtle 3D Depth
      final Paint itemPaint = Paint()..color = baseColor;
      canvas.drawRRect(RRect.fromRectAndRadius(itemRect, const Radius.circular(2)), itemPaint);

      // 2. Realistic Top Shrink-Wrap / Glossy Highlight
      if (itemRect.height > 12 && itemRect.width > 12) {
        final Rect highlightRect = Rect.fromLTWH(itemRect.left, itemRect.top, itemRect.width, itemRect.height * 0.35);
        final Paint highlightPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.35),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(highlightRect);
        canvas.drawRRect(RRect.fromRectAndRadius(highlightRect, const Radius.circular(2)), highlightPaint);
      }

      // 3. Subtle Outer Border & High-Contrast Inner Edge
      final Paint borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(RRect.fromRectAndRadius(itemRect, const Radius.circular(2)), borderPaint);

      final Paint borderHighlight = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      canvas.drawRRect(RRect.fromRectAndRadius(itemRect.deflate(0.5), const Radius.circular(1.5)), borderHighlight);

      // 4. Circular Number Badge (Upper Center: (1), (2), (3)...)
      final String seqNumber = p.item.itemId;
      final double badgeRadius = math.min(11.0, math.min(itemRect.width / 4, itemRect.height / 3.5));

      if (badgeRadius >= 5.5 && itemRect.width >= 18 && itemRect.height >= 20) {
        final Offset badgeCenter = Offset(itemRect.left + (itemRect.width / 2), itemRect.top + badgeRadius + 3.0);

        // Circular background
        final Paint circleBgPaint = Paint()..color = Colors.white.withValues(alpha: 0.3);
        canvas.drawCircle(badgeCenter, badgeRadius, circleBgPaint);

        final Paint circleRingPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(badgeCenter, badgeRadius, circleRingPaint);

        // Number Text inside Circle
        final double numFontSize = math.max(7.5, badgeRadius * 1.05);
        textPainter.text = TextSpan(
          text: seqNumber,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: numFontSize,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(badgeCenter.dx - (textPainter.width / 2), badgeCenter.dy - (textPainter.height / 2)),
        );
      }

      // 5. Dimension & Weight Information Text (Under the badge)
      if (itemRect.width >= 35 && itemRect.height >= 36) {
        final double fontSize = math.min(9.5, math.max(6.5, itemRect.width / 16));
        final String dimText = '${p.length.toStringAsFixed(0)} x ${p.width.toStringAsFixed(0)} x ${p.height.toStringAsFixed(0)} cm';
        final String wtText = '${p.item.weight.toStringAsFixed(0)} kg';

        // Dimensions Text
        textPainter.text = TextSpan(
          text: dimText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            shadows: const [
              Shadow(color: Colors.black45, offset: Offset(0.5, 0.5), blurRadius: 1),
            ],
          ),
        );
        textPainter.layout(maxWidth: itemRect.width - 4);
        final double dimY = itemRect.top + (badgeRadius * 2) + 5;
        if (dimY + textPainter.height < itemRect.bottom - 4) {
          textPainter.paint(canvas, Offset(itemRect.left + (itemRect.width - textPainter.width) / 2, dimY));
        }

        // Weight & Elevation Text
        final String statusLabel = p.z > 0.01 ? '$wtText | 🥞 z:${p.z.toStringAsFixed(0)}cm' : wtText;
        textPainter.text = TextSpan(
          text: statusLabel,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize * 0.9,
            shadows: const [
              Shadow(color: Colors.black45, offset: Offset(0.5, 0.5), blurRadius: 1),
            ],
          ),
        );
        textPainter.layout(maxWidth: itemRect.width - 4);
        final double wtY = dimY + fontSize + 2;
        if (wtY + textPainter.height < itemRect.bottom - 2) {
          textPainter.paint(canvas, Offset(itemRect.left + (itemRect.width - textPainter.width) / 2, wtY));
        }
      }

      // 6. Non-Stackable / On-Edge Visual Badge
      if (!p.item.isStackable && itemRect.width >= 20 && itemRect.height >= 18) {
        final Paint noStackPaint = Paint()..color = Colors.red.shade900.withValues(alpha: 0.85);
        final Rect noStackRect = Rect.fromLTWH(itemRect.left + 2, itemRect.top + 2, 14, 12);
        canvas.drawRRect(RRect.fromRectAndRadius(noStackRect, const Radius.circular(2)), noStackPaint);

        textPainter.text = const TextSpan(
          text: '🚫',
          style: TextStyle(fontSize: 8),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(noStackRect.left + 1, noStackRect.top + 1));
      } else if (p.isStandingOnEdge && itemRect.width >= 22 && itemRect.height >= 18) {
        final Paint edgeBadgePaint = Paint()..color = const Color(0xFF0D9488).withValues(alpha: 0.9);
        final Rect edgeBadgeRect = Rect.fromLTWH(itemRect.left + 2, itemRect.top + 2, 18, 12);
        canvas.drawRRect(RRect.fromRectAndRadius(edgeBadgeRect, const Radius.circular(2)), edgeBadgePaint);

        textPainter.text = const TextSpan(
          text: '📐',
          style: TextStyle(fontSize: 8),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(edgeBadgeRect.left + 2, edgeBadgeRect.top + 1));
      }
    }
  }

  @override
  bool shouldRepaint(covariant ContainerLoadPlanPainter oldDelegate) {
    return oldDelegate.plan != plan || oldDelegate.isTopView != isTopView;
  }
}

