import '../constants/cargo_constants.dart';
enum CargoOrientationPreference {
  smartHybrid, // 🌟 Smart Hybrid (Allows flat, 90° rotation, and on-edge vertical standing to fill residual width/height channels)
  flatOnly,    // 📦 Flat Only (Strictly keeps original height axis vertical; only allows flat 2D rotation if length/width swap)
  onEdgeOnly,  // 📐 On-Edge Standing Only (Strictly places on side edge)
}

class CargoItem {
  final String itemId;
  final double length; // cm
  final double width;  // cm
  final double height; // cm
  final double weight; // kg
  final bool rotate;
  final bool isStackable;
  final CargoOrientationPreference orientationPreference;
  final String? packageType;
  final String? description;

  CargoItem({
    required this.itemId,
    required this.length,
    required this.width,
    required this.height,
    required this.weight,
    this.rotate = true,
    this.isStackable = true,
    this.orientationPreference = CargoOrientationPreference.smartHybrid,
    this.packageType,
    this.description,
  });

  double get volumeM3 => (length * width * height) / 1000000;
  double get floorAreaM2 => (length * width) / 10000;
}

class PlacedItem {
  final CargoItem item;
  final double x; // offset along length (cm)
  final double y; // offset along width (cm)
  final double z; // elevation from floor (cm)
  final double length; // placed length (cm) after possible rotation
  final double width;  // placed width (cm) after possible rotation
  final double height; // placed height (cm)
  final String orientationType; // 'flat', 'flat_rotated', 'on_edge_long', 'on_edge_short', 'upright'

  PlacedItem({
    required this.item,
    required this.x,
    required this.y,
    this.z = 0.0,
    required this.length,
    required this.width,
    required this.height,
    this.orientationType = 'flat',
  });

  bool get isOnFloor => z <= 0.01;
  bool get isStandingOnEdge => orientationType.contains('edge') || (height > item.height + 0.1);
  String get orientationBadgeAr {
    if (orientationType == 'flat') return 'مسطح أفقي';
    if (orientationType == 'flat_rotated') return 'مسطح مدار 90°';
    if (orientationType == 'on_edge_long') return 'رأسي على السيف الطولي';
    if (orientationType == 'on_edge_short') return 'رأسي على السيف العرضي';
    if (orientationType == 'upright') return 'رأسي كامل';
    return isStandingOnEdge ? 'على السيف' : 'مسطح';
  }
}

class ContainerPackingResult {
  final String containerCode;
  final ContainerSpec spec;
  final List<PlacedItem> placedItems;
  final List<CargoItem> unplacedItems;
  final double totalWeight;
  final double totalVolume;
  final bool fits;
  final String? failureReason;

  ContainerPackingResult({
    required this.containerCode,
    required this.spec,
    required this.placedItems,
    required this.unplacedItems,
    required this.totalWeight,
    required this.totalVolume,
    required this.fits,
    this.failureReason,
  });

  int get edgePlacedCount => placedItems.where((p) => p.isStandingOnEdge).length;
  int get flatPlacedCount => placedItems.where((p) => !p.isStandingOnEdge).length;

  List<GroupedPlacedItem> get groupedItems => ContainerRequirementEngine.groupPlacedItems(placedItems);

  String get placedItemsSummary {
    if (placedItems.isEmpty) return '-';
    final groups = groupedItems;
    return groups.map((g) => '${g.itemCodeOrDesc} (${g.count})').join(', ');
  }
}

/// Represents an aggregated grouping of placed cargo items in a container.
/// - Cartons / standard items are aggregated by item code / description.
/// - Pallets are aggregated ONLY if their length, width, and height are identical.
class GroupedPlacedItem {
  final String itemCodeOrDesc;
  final String packageType;
  final double length;
  final double width;
  final double height;
  final double totalWeight;
  final double unitWeight;
  final int count;
  final bool isStackable;
  final bool isPallet;

  GroupedPlacedItem({
    required this.itemCodeOrDesc,
    required this.packageType,
    required this.length,
    required this.width,
    required this.height,
    required this.totalWeight,
    required this.unitWeight,
    required this.count,
    required this.isStackable,
    required this.isPallet,
  });

  double get volumeM3 => (length * width * height * count) / 1000000;
}

class ContainerSpec {
  final String code;
  final String name;
  final double internalVolumeCbm;
  final double maxPayloadKg;
  final double internalLength;
  final double internalWidth;
  final double internalHeight;

  const ContainerSpec({
    required this.code,
    required this.name,
    required this.internalVolumeCbm,
    required this.maxPayloadKg,
    required this.internalLength,
    required this.internalWidth,
    required this.internalHeight,
  });
}

class ShipmentModeRecommendation {
  final String recommendedMode; // 'Air', 'Sea LCL', 'Sea FCL'
  final String recommendedModeAr;
  final String reasonAr;
  final String reasonEn;
  final bool isAirSuggested;
  final bool isLclSuggested;

  ShipmentModeRecommendation({
    required this.recommendedMode,
    required this.recommendedModeAr,
    required this.reasonAr,
    this.reasonEn = '',
    required this.isAirSuggested,
    required this.isLclSuggested,
  });
}

class ContainerRecommendationResult {
  final bool isStackable;
  final String stackingLabel;
  final String recommendedContainerCode;
  final int requiredContainersCount;
  final double spaceUtilizationPercent;
  final double payloadUtilizationPercent;
  final String recommendationSummary;
  final String recommendationSummaryEn;
  final List<Map<String, dynamic>> comparisonDetails;
  final ShipmentModeRecommendation modeRecommendation;
  final CargoOrientationPreference orientationPreference;

  ContainerRecommendationResult({
    required this.isStackable,
    required this.stackingLabel,
    required this.recommendedContainerCode,
    required this.requiredContainersCount,
    required this.spaceUtilizationPercent,
    required this.payloadUtilizationPercent,
    required this.recommendationSummary,
    this.recommendationSummaryEn = '',
    required this.comparisonDetails,
    required this.modeRecommendation,
    this.orientationPreference = CargoOrientationPreference.smartHybrid,
  });
}

class ContainerDualRecommendationResult {
  final ContainerRecommendationResult stackableResult;
  final ContainerRecommendationResult nonStackableResult;
  final ContainerRecommendationResult? smartHybridResult;
  final ContainerRecommendationResult? flatOnlyResult;
  final ShipmentModeRecommendation modeRecommendation;

  ContainerDualRecommendationResult({
    required this.stackableResult,
    required this.nonStackableResult,
    this.smartHybridResult,
    this.flatOnlyResult,
    required this.modeRecommendation,
  });

  bool get hasHybridSavings {
    if (smartHybridResult == null || flatOnlyResult == null) return false;
    return smartHybridResult!.requiredContainersCount < flatOnlyResult!.requiredContainersCount;
  }

  int get containersSavedCount {
    if (!hasHybridSavings) return 0;
    return flatOnlyResult!.requiredContainersCount - smartHybridResult!.requiredContainersCount;
  }
}

/// MD-019.1 Container Requirement & Utilization Calculation Engine + Cargo Stacking Skill
class ContainerRequirementEngine {
  static const List<ContainerSpec> specs = [
    ContainerSpec(code: '20GP', name: "20' General Purpose Container", internalVolumeCbm: 33.2, maxPayloadKg: 21700.0, internalLength: 589.0, internalWidth: 235.0, internalHeight: 239.0),
    ContainerSpec(code: '40GP', name: "40' General Purpose Container", internalVolumeCbm: 67.7, maxPayloadKg: 26500.0, internalLength: 1203.0, internalWidth: 235.0, internalHeight: 239.0),
    ContainerSpec(code: '40HC', name: "40' High Cube Container", internalVolumeCbm: 76.4, maxPayloadKg: 26500.0, internalLength: 1203.0, internalWidth: 235.0, internalHeight: 269.0),
    ContainerSpec(code: '45HC', name: "45' High Cube Container", internalVolumeCbm: 86.0, maxPayloadKg: 27700.0, internalLength: 1355.6, internalWidth: 235.2, internalHeight: 269.8),
  ];

  /// Groups placed cargo items according to the enterprise aggregation protocol:
  /// - Cartons / standard items are aggregated by item code / description.
  /// - Pallets are aggregated ONLY if their length, width, and height are identical.
  static List<GroupedPlacedItem> groupPlacedItems(List<PlacedItem> placedItems) {
    final Map<String, List<PlacedItem>> groups = {};

    for (final p in placedItems) {
      final pkgType = (p.item.packageType ?? '').toLowerCase();
      final isPallet = pkgType.contains('pallet') || pkgType.contains('بالت');

      // If pallet: group ONLY if length, width, height are identical
      // If carton/package: group by item description / code
      final String key;
      if (isPallet) {
        key = 'PALLET_${p.length.round()}_${p.width.round()}_${p.height.round()}_${p.item.isStackable}';
      } else {
        final desc = p.item.description ?? p.item.itemId;
        final cleanCode = desc.contains('(') ? desc.split('(').first.trim() : desc.trim();
        key = 'CARTON_${cleanCode}_${p.length.round()}_${p.width.round()}_${p.height.round()}_${p.item.isStackable}';
      }

      groups.putIfAbsent(key, () => []).add(p);
    }

    return groups.values.map((list) {
      final first = list.first;
      final pkgType = (first.item.packageType ?? '').toLowerCase();
      final isPallet = pkgType.contains('pallet') || pkgType.contains('بالت');
      final desc = first.item.description ?? first.item.itemId;
      final cleanDesc = desc.contains('(') ? desc.split('(').first.trim() : desc.trim();
      final totalWeight = list.fold<double>(0.0, (sum, item) => sum + item.item.weight);

      return GroupedPlacedItem(
        itemCodeOrDesc: cleanDesc,
        packageType: first.item.packageType ?? 'Carton',
        length: first.length,
        width: first.width,
        height: first.height,
        totalWeight: totalWeight,
        unitWeight: list.isNotEmpty ? (totalWeight / list.length) : first.item.weight,
        count: list.length,
        isStackable: first.item.isStackable,
        isPallet: isPallet,
      );
    }).toList();
  }

  /// Smart Shipment Mode Recommendation Rules
  static ShipmentModeRecommendation recommendShipmentMode({
    required double totalCbm,
    required double totalWeightKg,
  }) {
    final double airVolumetricWeightKg = totalCbm * kAirVolumetricKgPerCbm;
    final bool condition1AirHeavy = totalWeightKg > 0 && totalWeightKg >= airVolumetricWeightKg;
    final bool condition2AirSmallVol = totalCbm > 0 && totalCbm < 5.0;

    if (condition1AirHeavy && condition2AirSmallVol) {
      return ShipmentModeRecommendation(
        recommendedMode: 'Air',
        recommendedModeAr: 'Air (شحن جوي ✈️)',
        reasonAr: 'التوصية الذكية: اقتراح شحن جوي (AIR) لاكتمال الشرطين الحاسمين:\n1. الوزن الفعلي القائم (${totalWeightKg.toStringAsFixed(1)} kg) أكبر من/يغطي الوزن المحاسب عليه بالطيران (${airVolumetricWeightKg.toStringAsFixed(1)} kg).\n2. الحجم الفعلي (${totalCbm.toStringAsFixed(2)} m³) أقل من 5 m³.',
        isAirSuggested: true,
        isLclSuggested: false,
      );
    } else if (totalCbm > 0 && totalCbm < 15.0) {
      return ShipmentModeRecommendation(
        recommendedMode: 'Sea LCL',
        recommendedModeAr: 'Sea LCL (شحن بحري طرد/جزئي 📦)',
        reasonAr: 'التوصية الذكية: اقتراح شحن بحري جزئي (Sea LCL) لأن إجمالي الحجم (${totalCbm.toStringAsFixed(2)} m³) أقل من 15 m³ ولا يستدعي شحن حاوية كاملة (FCL).',
        isAirSuggested: false,
        isLclSuggested: true,
      );
    } else {
      return ShipmentModeRecommendation(
        recommendedMode: 'Sea FCL',
        recommendedModeAr: 'Sea FCL (شحن بحري حاوية كاملة 🚢)',
        reasonAr: 'التوصية الذكية: اقتراح شحن بحري حاوية كاملة (Sea FCL) لأن الحجم (${totalCbm.toStringAsFixed(2)} m³) يبلغ 15 m³ أو أكثر.',
        isAirSuggested: false,
        isLclSuggested: false,
      );
    }
  }

  static ContainerRecommendationResult calculate({
    required double totalCbm,
    required double totalWeightKg,
    bool isStackable = true,
    CargoOrientationPreference orientationPreference = CargoOrientationPreference.smartHybrid,
  }) {
    String modeTag;
    String modeTagEn;
    if (!isStackable) {
      modeTag = '🚫 غير قابل للرص (أرضي فقط Z=0)';
      modeTagEn = '🚫 Non-Stackable (Floor-Only Z=0)';
    } else if (orientationPreference == CargoOrientationPreference.smartHybrid) {
      modeTag = '🌟 رص ذكي هجين (أفقي + على السيف)';
      modeTagEn = '🌟 Smart Hybrid (Flat + On-Edge)';
    } else if (orientationPreference == CargoOrientationPreference.onEdgeOnly) {
      modeTag = '📐 رص على السيف فقط';
      modeTagEn = '📐 On-Edge Only';
    } else {
      modeTag = '📦 رص مسطح فقط';
      modeTagEn = '📦 Flat Only';
    }

    final modeRec = recommendShipmentMode(totalCbm: totalCbm, totalWeightKg: totalWeightKg);

    if (totalCbm <= 0 && totalWeightKg <= 0) {
      return ContainerRecommendationResult(
        isStackable: isStackable,
        stackingLabel: modeTag,
        recommendedContainerCode: '40HC',
        requiredContainersCount: 1,
        spaceUtilizationPercent: 0,
        payloadUtilizationPercent: 0,
        recommendationSummary: 'لم يتم تحديد حمولة لحساب الحاوية المقترحة [$modeTag]',
        recommendationSummaryEn: 'No cargo specified to calculate recommended container [$modeTagEn]',
        comparisonDetails: [],
        modeRecommendation: modeRec,
        orientationPreference: orientationPreference,
      );
    }

    final List<Map<String, dynamic>> comparisons = [];

    for (final spec in specs) {
      double volumeUsabilityFactor = 1.0;
      if (!isStackable) {
        volumeUsabilityFactor = (spec.code == '40HC' || spec.code == '45HC') ? 0.85 : 0.65;
      } else if (orientationPreference == CargoOrientationPreference.flatOnly) {
        // Flat only has lower volume usability due to dimensional width mismatches
        volumeUsabilityFactor = 0.70;
      } else {
        // Smart hybrid achieves high packing efficiency
        volumeUsabilityFactor = 0.95;
      }

      final double effectiveVolumeCbm = spec.internalVolumeCbm * volumeUsabilityFactor;
      final int countByVol = effectiveVolumeCbm > 0 ? (totalCbm / effectiveVolumeCbm).ceil() : 1;
      final int countByWeight = spec.maxPayloadKg > 0 ? (totalWeightKg / spec.maxPayloadKg).ceil() : 1;
      final int rawReq = countByVol > countByWeight ? countByVol : countByWeight;
      final int reqCount = rawReq < 1 ? 1 : rawReq;

      final double spaceUtil = (totalCbm / (reqCount * spec.internalVolumeCbm)) * 100;
      final double payloadUtil = (totalWeightKg / (reqCount * spec.maxPayloadKg)) * 100;

      double score = (reqCount * 100) - ((spaceUtil + payloadUtil) / 2);
      if (totalCbm > 30.0 && totalCbm <= 76.0 && spec.code == '40HC' && reqCount == 1) {
        score -= 50.0; // Boost 40HC
      }
      if (totalCbm <= 76.0 && spec.code == '45HC') {
        score += 30.0;
      }

      comparisons.add({
        'spec': spec,
        'reqCount': reqCount,
        'effectiveVolumeCbm': effectiveVolumeCbm,
        'spaceUtil': spaceUtil > 100 ? 100.0 : spaceUtil,
        'payloadUtil': payloadUtil > 100 ? 100.0 : payloadUtil,
        'score': score,
      });
    }

    comparisons.sort((a, b) => (a['score'] as double).compareTo(b['score'] as double));

    final best = comparisons.first;
    final bestSpec = best['spec'] as ContainerSpec;
    final int bestCount = best['reqCount'] as int;
    final double bestVol = best['spaceUtil'] as double;
    final double bestWeight = best['payloadUtil'] as double;

    String fleetCombination = '';
    if (isStackable) {
      if (orientationPreference == CargoOrientationPreference.smartHybrid) {
        final int count40HC = (totalCbm / 74.0).ceil();
        fleetCombination = '${count40HC < 1 ? 1 : count40HC} x 40HC Container(s)';
      } else {
        final int count40HC = (totalCbm / 53.0).ceil();
        fleetCombination = '${count40HC < 1 ? 1 : count40HC} x 40HC Container(s)';
      }
    } else {
      final int full40HC = (totalCbm / 50.0).floor();
      final double remCbm = totalCbm - (full40HC * 50.0);
      if (remCbm <= 0) {
        fleetCombination = '${full40HC < 1 ? 1 : full40HC} x 40HC';
      } else if (remCbm <= 25.0) {
        fleetCombination = full40HC > 0 ? '$full40HC x 40HC + 1 x 20GP' : '1 x 20GP';
      } else {
        fleetCombination = '${full40HC + 1} x 40HC';
      }
    }

    final summary = '$fleetCombination [$modeTag] — (استغلال المساحة: ${bestVol.toStringAsFixed(1)}% | استغلال الوزن: ${bestWeight.toStringAsFixed(1)}%)';
    final summaryEn = '$fleetCombination [$modeTagEn] — (Space Util: ${bestVol.toStringAsFixed(1)}% | Weight Util: ${bestWeight.toStringAsFixed(1)}%)';

    return ContainerRecommendationResult(
      isStackable: isStackable,
      stackingLabel: modeTag,
      recommendedContainerCode: bestSpec.code,
      requiredContainersCount: bestCount,
      spaceUtilizationPercent: bestVol,
      payloadUtilizationPercent: bestWeight,
      recommendationSummary: summary,
      recommendationSummaryEn: summaryEn,
      comparisonDetails: comparisons,
      modeRecommendation: modeRec,
      orientationPreference: orientationPreference,
    );
  }

  static ContainerDualRecommendationResult calculateBoth({
    required double totalCbm,
    required double totalWeightKg,
  }) {
    final modeRec = recommendShipmentMode(totalCbm: totalCbm, totalWeightKg: totalWeightKg);
    final smartHybrid = calculate(totalCbm: totalCbm, totalWeightKg: totalWeightKg, isStackable: true, orientationPreference: CargoOrientationPreference.smartHybrid);
    final flatOnly = calculate(totalCbm: totalCbm, totalWeightKg: totalWeightKg, isStackable: true, orientationPreference: CargoOrientationPreference.flatOnly);
    final nonStackable = calculate(totalCbm: totalCbm, totalWeightKg: totalWeightKg, isStackable: false);

    return ContainerDualRecommendationResult(
      stackableResult: smartHybrid,
      nonStackableResult: nonStackable,
      smartHybridResult: smartHybrid,
      flatOnlyResult: flatOnly,
      modeRecommendation: modeRec,
    );
  }

  /// Advanced 3D/2.5D Cargo Packing Algorithm using 6-DOF Multi-Orientation Extreme-Point Bin Packing
  static ContainerPackingResult packCargo({
    required List<CargoItem> items,
    required ContainerSpec spec,
    CargoOrientationPreference? forceOrientation,
  }) {
    // Sort items primarily by largest volume and base footprint descending
    final sortedItems = List<CargoItem>.from(items)
      ..sort((a, b) {
        final volA = a.volumeM3;
        final volB = b.volumeM3;
        if ((volA - volB).abs() > 0.001) {
          return volB.compareTo(volA);
        }
        final areaA = a.length * a.width;
        final areaB = b.length * b.width;
        if ((areaA - areaB).abs() > 1.0) {
          return areaB.compareTo(areaA);
        }
        if (a.isStackable != b.isStackable) {
          return a.isStackable ? 1 : -1;
        }
        return b.length.compareTo(a.length);
      });

    final List<PlacedItem> placed = [];
    final List<CargoItem> unplaced = [];

    bool hasCollision(double x, double y, double z, double L, double W, double H) {
      for (final p in placed) {
        final bool overlapX = x < (p.x + p.length - 0.01) && (x + L - 0.01) > p.x;
        final bool overlapY = y < (p.y + p.width - 0.01) && (y + W - 0.01) > p.y;
        final bool overlapZ = z < (p.z + p.height - 0.01) && (z + H - 0.01) > p.z;
        if (overlapX && overlapY && overlapZ) return true;
        if (!p.item.isStackable && overlapX && overlapY && z >= (p.z + p.height - 0.01)) return true;
      }
      return false;
    }

    for (final rawItem in sortedItems) {
      final itemPref = forceOrientation ?? rawItem.orientationPreference;
      final l0 = rawItem.length;
      final w0 = rawItem.width;
      final h0 = rawItem.height;

      final candidateOrientations = <List<dynamic>>[];
      if (itemPref == CargoOrientationPreference.flatOnly || !rawItem.isStackable) {
        candidateOrientations.add([l0, w0, h0, 'flat']);
        if (rawItem.rotate && (l0 - w0).abs() > 0.1) {
          candidateOrientations.add([w0, l0, h0, 'flat_rotated']);
        }
      } else if (itemPref == CargoOrientationPreference.onEdgeOnly) {
        candidateOrientations.add([l0, h0, w0, 'on_edge_long']);
        if (rawItem.rotate && (l0 - w0).abs() > 0.1) {
          candidateOrientations.add([w0, h0, l0, 'on_edge_short']);
        }
      } else { // smartHybrid (stackable cargo)
        // 1. Flat orientations
        candidateOrientations.add([l0, w0, h0, 'flat']);
        if (rawItem.rotate && (l0 - w0).abs() > 0.1) {
          candidateOrientations.add([w0, l0, h0, 'flat_rotated']);
        }
        // 2. On-edge vertical standing orientations (fills residual width/height channels)
        candidateOrientations.add([l0, h0, w0, 'on_edge_long']);
        if (rawItem.rotate && (l0 - w0).abs() > 0.1) {
          candidateOrientations.add([w0, h0, l0, 'on_edge_short']);
          candidateOrientations.add([h0, l0, w0, 'on_edge_rotated']);
        }
        candidateOrientations.add([h0, w0, l0, 'upright']);
      }

      // Filter orientations that fit within container internal dimensions
      final validOrientations = candidateOrientations.where((o) {
        final double ol = (o[0] as num).toDouble();
        final double ow = (o[1] as num).toDouble();
        final double oh = (o[2] as num).toDouble();
        return ol <= spec.internalLength + 0.1 && ow <= spec.internalWidth + 0.1 && oh <= spec.internalHeight + 0.1;
      }).toList();

      if (validOrientations.isEmpty) {
        unplaced.add(rawItem);
        continue;
      }

      // Build 3D Extreme Points
      final Set<String> seenPoints = {};
      final List<List<double>> candidatePoints = [];

      void addPoint(double x, double y, double z) {
        final rx = (x * 100).round() / 100;
        final ry = (y * 100).round() / 100;
        final rz = (z * 100).round() / 100;
        if (rx <= spec.internalLength && ry <= spec.internalWidth && rz <= spec.internalHeight) {
          final key = '$rx,$ry,$rz';
          if (!seenPoints.contains(key)) {
            seenPoints.add(key);
            candidatePoints.add([rx, ry, rz]);
          }
        }
      }

      addPoint(0.0, 0.0, 0.0);

      for (final p in placed) {
        addPoint(p.x + p.length, p.y, p.z);
        addPoint(p.x, p.y + p.width, p.z);
        if (rawItem.isStackable && p.item.isStackable) {
          addPoint(p.x, p.y, p.z + p.height);
          addPoint(p.x + p.length, p.y, p.z + p.height);
          addPoint(p.x, p.y + p.width, p.z + p.height);
        }
        addPoint(p.x + p.length, p.y + p.width, p.z);
        addPoint(p.x + p.length, 0.0, 0.0);
        addPoint(p.x, p.y + p.width, 0.0);
      }

      // Sort candidate points: X ascending (bay-by-bay along container length), then Y ascending, then Z ascending
      candidatePoints.sort((a, b) {
        final cmpX = a[0].compareTo(b[0]);
        if (cmpX != 0) return cmpX;
        final cmpY = a[1].compareTo(b[1]);
        if (cmpY != 0) return cmpY;
        return a[2].compareTo(b[2]);
      });

      bool isPlaced = false;

      for (final pt in candidatePoints) {
        final cX = pt[0];
        final cY = pt[1];
        final cZ = pt[2];

        // Non-stackable cannot be elevated above floor
        if (!rawItem.isStackable && cZ > 0.01) continue;

        for (final orient in validOrientations) {
          final double L = (orient[0] as num).toDouble();
          final double W = (orient[1] as num).toDouble();
          final double H = (orient[2] as num).toDouble();
          final String oType = orient[3] as String;

          if ((cX + L) <= spec.internalLength + 0.1 && (cY + W) <= spec.internalWidth + 0.1 && (cZ + H) <= spec.internalHeight + 0.1) {
            if (!hasCollision(cX, cY, cZ, L, W, H)) {
              placed.add(PlacedItem(
                item: rawItem,
                x: cX,
                y: cY,
                z: cZ,
                length: L,
                width: W,
                height: H,
                orientationType: oType,
              ));
              isPlaced = true;
              break;
            }
          }
        }
        if (isPlaced) break;
      }

      if (!isPlaced) {
        unplaced.add(rawItem);
      }
    }

    final totalWeight = placed.fold(0.0, (sum, p) => sum + p.item.weight);
    final totalVolume = placed.fold(0.0, (sum, p) => sum + p.item.volumeM3);
    final fits = unplaced.isEmpty && totalWeight <= spec.maxPayloadKg;

    String? failureReason;
    if (unplaced.isNotEmpty) {
      final reasons = <String>[];
      for (final u in unplaced) {
        final bool fitsAny = u.length <= spec.internalLength && u.width <= spec.internalWidth && u.height <= spec.internalHeight;
        final bool fitsRot = u.rotate && u.width <= spec.internalLength && u.length <= spec.internalWidth && u.height <= spec.internalHeight;
        final bool fitsEdge = u.isStackable && (forceOrientation ?? u.orientationPreference) != CargoOrientationPreference.flatOnly && u.length <= spec.internalLength && u.height <= spec.internalWidth && u.width <= spec.internalHeight;

        if (!fitsAny && !fitsRot && !fitsEdge) {
          if (u.length > spec.internalWidth && u.width > spec.internalWidth) {
            reasons.add('فشل الرص: تجاوز الطول والعرض الأبعاد القياسية للحاوية (أبعاد الطرد: ${u.length.toStringAsFixed(0)} × ${u.width.toStringAsFixed(0)} سم - أقصى عرض مسموح للحاوية ${spec.internalWidth.toStringAsFixed(0)} سم)');
          } else if (u.length > spec.internalLength || u.width > spec.internalLength) {
            reasons.add('فشل الرص: أبعاد الطرد تتجاوز الطول الداخلي للحاوية (${spec.internalLength.toStringAsFixed(0)} سم)');
          } else {
            reasons.add('فشل الرص: أبعاد الطرد تتجاوز الأبعاد القياسية الداخلية للحاوية ${spec.code}');
          }
        } else {
          reasons.add('فشل الرص: يتعذر استيعاب الطرد داخل الحاوية بسبب تزاحم المساحة الأرضية وسعة الحاوية');
        }
      }
      failureReason = reasons.toSet().join(' | ');
    } else if (totalWeight > spec.maxPayloadKg) {
      failureReason = 'فشل الرص: إجمالي وزن الحمولة (${totalWeight.toStringAsFixed(0)} kg) يتجاوز الوزن المسموح للحاوية (${spec.maxPayloadKg.toStringAsFixed(0)} kg)';
    }

    return ContainerPackingResult(
      containerCode: spec.code,
      spec: spec,
      placedItems: placed,
      unplacedItems: unplaced,
      totalWeight: totalWeight,
      totalVolume: totalVolume,
      fits: fits,
      failureReason: failureReason,
    );
  }

  static List<ContainerPackingResult> planShipment(
    List<CargoItem> items, {
    bool? forceStackable,
    CargoOrientationPreference? forceOrientation,
  }) {
    final List<CargoItem> effectiveItems = items.map((i) => CargoItem(
      itemId: i.itemId,
      length: i.length,
      width: i.width,
      height: i.height,
      weight: i.weight,
      rotate: i.rotate,
      isStackable: forceStackable ?? i.isStackable,
      orientationPreference: forceOrientation ?? i.orientationPreference,
      packageType: i.packageType,
      description: i.description,
    )).toList();

    List<CargoItem> remaining = List<CargoItem>.from(effectiveItems);
    final List<ContainerPackingResult> plan = [];
    int guard = 0;

    final spec20GP = specs.firstWhere((s) => s.code == '20GP');
    final spec40HC = specs.firstWhere((s) => s.code == '40HC');
    final spec40GP = specs.firstWhere((s) => s.code == '40GP');
    final spec45HC = specs.firstWhere((s) => s.code == '45HC');

    while (remaining.isNotEmpty && guard < items.length + 15) {
      guard++;

      // 1. Check if all remaining items fit in a 20GP
      final res20 = packCargo(items: remaining, spec: spec20GP, forceOrientation: forceOrientation);
      if (res20.fits) {
        plan.add(res20);
        break;
      }

      // 2. Check if all remaining items fit in a 40GP
      final res40 = packCargo(items: remaining, spec: spec40GP, forceOrientation: forceOrientation);
      if (res40.fits) {
        plan.add(res40);
        break;
      }

      // 3. Check if all remaining items fit in a 40HC (Universal standard high cube)
      final res40HC = packCargo(items: remaining, spec: spec40HC, forceOrientation: forceOrientation);
      if (res40HC.fits) {
        plan.add(res40HC);
        break;
      }

      // 4. Check if all remaining items fit in a 45HC (only if items exceed 40HC dimensions)
      final hasExtraLongItem = remaining.any((i) => i.length > 1203 || (i.rotate && i.width > 1203));
      if (hasExtraLongItem) {
        final res45HC = packCargo(items: remaining, spec: spec45HC, forceOrientation: forceOrientation);
        if (res45HC.fits) {
          plan.add(res45HC);
          break;
        }
      }

      // 5. Multi-container packing step: Fill a standard 40HC first (or 45HC if oversized)
      final targetSpec = hasExtraLongItem ? spec45HC : spec40HC;
      final res = packCargo(items: remaining, spec: targetSpec, forceOrientation: forceOrientation);

      if (res.placedItems.isEmpty) {
        final fallbackRes = packCargo(items: remaining, spec: spec45HC, forceOrientation: forceOrientation);
        if (fallbackRes.placedItems.isEmpty) {
          plan.add(ContainerPackingResult(
            containerCode: 'FAILED',
            spec: spec40HC,
            placedItems: [],
            unplacedItems: remaining,
            totalWeight: 0,
            totalVolume: 0,
            fits: false,
            failureReason: fallbackRes.failureReason ?? 'فشل الرص: تجاوز أبعاد الطرد الأبعاد القياسية المسموح بها داخل الحاوية',
          ));
          break;
        }
        plan.add(fallbackRes);
        final placedIds = fallbackRes.placedItems.map((p) => p.item.itemId).toSet();
        remaining = remaining.where((i) => !placedIds.contains(i.itemId)).toList();
      } else {
        plan.add(res);
        final placedIds = res.placedItems.map((p) => p.item.itemId).toSet();
        remaining = remaining.where((i) => !placedIds.contains(i.itemId)).toList();
      }
    }

    return plan;
  }
}


