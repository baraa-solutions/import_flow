import 'package:flutter/material.dart';

/// Supported business entity types across ImportFlow ERP.
enum EntityType {
  importFile,
  purchaseOrder,
  supplier,
  importCompany,
  partner,
  project,
  currency,
  incoterm,
  costItem,
  transportLocation,
  customsTariff,
  smartTask,
  clearancePriceItem,
  settlement,
  auditLog,
  cargoxEnvelope,
  freightBooking,
  freightQuotation,
  customsClearanceRfq,
  cargoInsurance,
  warehouseReceiving,
  fileClosure,
  shippingScenario,
  cbmCalculation,
  customsConsultation,
  stepConfig,
  user,
}

/// A universal, typed reference to an entity instance by its [type] and primary [id].
///
/// Used to address records across modules, audit logs, notifications, and AI assistant
/// without tightly coupling to specific routes or parent screens.
@immutable
class EntityRef {
  final EntityType type;
  final int id;
  final String? code;

  const EntityRef({
    required this.type,
    required this.id,
    this.code,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntityRef &&
          runtimeType == other.runtimeType &&
          other.type == type &&
          other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() =>
      'EntityRef(${type.name}, $id${code != null ? ', code: $code' : ''})';
}

/// Central registry mapping [EntityType] to its details viewer builder.
///
/// Each feature registers its viewer builder once:
/// ```dart
/// EntityDetailsRegistry.register(
///   EntityType.supplier,
///   (context, id) => SupplierDetailsView(id: id),
/// );
/// ```
///
/// Any screen, audit log, notification, or shortcut can then open it via:
/// ```dart
/// EntityDetailsRegistry.open(context, EntityRef(type: EntityType.supplier, id: 101));
/// ```
class EntityDetailsRegistry {
  EntityDetailsRegistry._();

  static final Map<EntityType, Widget Function(BuildContext context, int id)> _registry = {};

  /// Registers a details [builder] for [type].
  static void register(EntityType type, Widget Function(BuildContext context, int id) builder) {
    _registry[type] = builder;
  }

  /// Unregisters the details builder for [type].
  static void unregister(EntityType type) {
    _registry.remove(type);
  }

  /// Removes all registered builders (useful in test tearDown).
  static void clear() {
    _registry.clear();
  }

  /// Whether a details builder is registered for [type].
  static bool isRegistered(EntityType type) => _registry.containsKey(type);

  /// Alias for [isRegistered].
  static bool has(EntityType type) => isRegistered(type);

  /// Opens the details viewer for [ref] in a modal dialog / side-sheet.
  ///
  /// Throws [StateError] if no builder is registered for [ref.type].
  static Future<T?> open<T>(BuildContext context, EntityRef ref) {
    final builder = _registry[ref.type];
    if (builder == null) {
      throw StateError('No entity details builder registered for ${ref.type.name}');
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => builder(dialogContext, ref.id),
    );
  }
}
