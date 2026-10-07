import '../models/freight_booking_model.dart';

/// Result of building charges from quotation breakdown and allocated equipment.
class BookingChargeBuildResult {
  final List<BookingChargeModel> charges;
  final String? mismatchError;
  final bool has40ftMismatch;
  final bool has20ftMismatch;

  const BookingChargeBuildResult({
    required this.charges,
    this.mismatchError,
    this.has40ftMismatch = false,
    this.has20ftMismatch = false,
  });

  bool get hasError => mismatchError != null;
}

/// Pure helper that synchronizes and builds booking charges from quotation
/// breakdown lines and allocated containers.
class BookingChargeBuilder {
  BookingChargeBuilder._();

  /// Builds booking charges, dynamically mapping container types to sea freight
  /// charges and strictly validating that allocated equipment matches quoted sizes.
  ///
  /// Never drops a quoted freight line silently. If a quoted size (40ft or 20ft)
  /// has price > 0 and qty > 0 but no matching container is allocated, the line
  /// is kept and a [mismatchError] is recorded so the UI can block save.
  static BookingChargeBuildResult buildCharges({
    required List<ContainerAllocationModel> containers,
    // 40ft Quote
    bool container40ftApp = false,
    double container40ftPrice = 0.0,
    int container40ftQty = 0,
    String container40ftCur = 'USD',
    // 20ft Quote
    bool container20ftApp = false,
    double container20ftPrice = 0.0,
    int container20ftQty = 0,
    String container20ftCur = 'USD',
    // LCL
    bool lclCbmApp = false,
    double lclCbmPrice = 0.0,
    double lclCbmQty = 0.0,
    String lclCbmCur = 'USD',
    // Surcharges & additional fees
    bool dthcApp = false,
    double dthcPrice = 0.0,
    String dthcCur = 'USD',
    bool storagePerWeekApp = false,
    double storagePerWeekPrice = 0.0,
    String storagePerWeekCur = 'USD',
    bool extraDayStorageApp = false,
    double extraDayStoragePrice = 0.0,
    String extraDayStorageCur = 'USD',
    bool solasVgmApp = false,
    double solasVgmPrice = 0.0,
    String solasVgmCur = 'USD',
    bool vgmNotifApp = false,
    double vgmNotifPrice = 0.0,
    String vgmNotifCur = 'USD',
    bool telexReleaseApp = false,
    double telexReleasePrice = 0.0,
    String telexReleaseCur = 'USD',
    bool expressCourierApp = false,
    double expressCourierPrice = 0.0,
    String expressCourierCur = 'USD',
    bool eurAtrApp = false,
    double eurAtrPrice = 0.0,
    String eurAtrCur = 'USD',
    bool insuranceApp = false,
    double insurancePrice = 0.0,
    String insuranceCur = 'USD',
    bool docFeesApp = false,
    double docFeesPrice = 0.0,
    String docFeesCur = 'USD',
    bool waiverApp = false,
    double waiverPrice = 0.0,
    String waiverCur = 'USD',
    bool ics2App = false,
    double ics2Price = 0.0,
    String ics2Cur = 'USD',
    bool otherFeesApp = false,
    double otherFeesPrice = 0.0,
    String otherFeesCur = 'USD',
  }) {
    final List<BookingChargeModel> newCharges = [];
    bool has40ftMismatch = false;
    bool has20ftMismatch = false;

    // 40ft / 45ft sea freight
    if (container40ftApp && container40ftPrice > 0 && container40ftQty > 0) {
      final c40 = containers.cast<ContainerAllocationModel?>().firstWhere(
        (c) => c != null && (c.containerType.startsWith('40') || c.containerType.startsWith('45')),
        orElse: () => null,
      );

      final String tag;
      if (c40 != null) {
        tag = c40.containerType;
      } else {
        has40ftMismatch = true;
        // Keep default 40HC tag so line is NEVER silently dropped and freight cost is not understated
        tag = '40HC';
      }

      newCharges.add(BookingChargeModel(
        chargeType: 'Sea Freight 40ft',
        unit: 'Per Container',
        quantity: container40ftQty.toDouble(),
        containerType: tag,
        currency: container40ftCur,
        rate: container40ftPrice,
        total: container40ftPrice * container40ftQty,
      ));
    }

    // 20ft sea freight
    if (container20ftApp && container20ftPrice > 0 && container20ftQty > 0) {
      final c20 = containers.cast<ContainerAllocationModel?>().firstWhere(
        (c) => c != null && c.containerType.startsWith('20'),
        orElse: () => null,
      );

      final String tag;
      if (c20 != null) {
        tag = c20.containerType;
      } else {
        has20ftMismatch = true;
        // Keep default 20GP tag so line is NEVER silently dropped and freight total is not understated
        tag = '20GP';
      }

      newCharges.add(BookingChargeModel(
        chargeType: 'Sea Freight 20ft',
        unit: 'Per Container',
        quantity: container20ftQty.toDouble(),
        containerType: tag,
        currency: container20ftCur,
        rate: container20ftPrice,
        total: container20ftPrice * container20ftQty,
      ));
    }

    // LCL
    if (lclCbmApp && lclCbmPrice > 0) {
      newCharges.add(BookingChargeModel(
        chargeType: 'LCL CBM Freight',
        unit: 'Per CBM',
        quantity: lclCbmQty > 0 ? lclCbmQty : 1.0,
        currency: lclCbmCur,
        rate: lclCbmPrice,
        total: lclCbmPrice * (lclCbmQty > 0 ? lclCbmQty : 1.0),
      ));
    }

    // Surcharges & additional fees
    if (dthcApp && dthcPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'DTHC (Destination THC)', unit: 'Per Shipment', quantity: 1, currency: dthcCur, rate: dthcPrice, total: dthcPrice));
    }
    if (storagePerWeekApp && storagePerWeekPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Storage per one week', unit: 'Per Week', quantity: 1, currency: storagePerWeekCur, rate: storagePerWeekPrice, total: storagePerWeekPrice));
    }
    if (extraDayStorageApp && extraDayStoragePrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Extra day storage', unit: 'Per Day', quantity: 1, currency: extraDayStorageCur, rate: extraDayStoragePrice, total: extraDayStoragePrice));
    }
    if (solasVgmApp && solasVgmPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'SOLAS/VGM Fees', unit: 'Per Container', quantity: 1, currency: solasVgmCur, rate: solasVgmPrice, total: solasVgmPrice));
    }
    if (vgmNotifApp && vgmNotifPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'VGM Notification Fee', unit: 'Per Container', quantity: 1, currency: vgmNotifCur, rate: vgmNotifPrice, total: vgmNotifPrice));
    }
    if (telexReleaseApp && telexReleasePrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Telex Release', unit: 'Per Shipment', quantity: 1, currency: telexReleaseCur, rate: telexReleasePrice, total: telexReleasePrice));
    }
    if (expressCourierApp && expressCourierPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Express Courier', unit: 'Per Shipment', quantity: 1, currency: expressCourierCur, rate: expressCourierPrice, total: expressCourierPrice));
    }
    if (eurAtrApp && eurAtrPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'EUR.1 / ATR Certificate', unit: 'Per Certificate', quantity: 1, currency: eurAtrCur, rate: eurAtrPrice, total: eurAtrPrice));
    }
    if (insuranceApp && insurancePrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Marine Insurance', unit: 'Per Policy', quantity: 1, currency: insuranceCur, rate: insurancePrice, total: insurancePrice));
    }
    if (docFeesApp && docFeesPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Document Fees', unit: 'Per Shipment', quantity: 1, currency: docFeesCur, rate: docFeesPrice, total: docFeesPrice));
    }
    if (waiverApp && waiverPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Waiver Letter Fee', unit: 'Per Letter', quantity: 1, currency: waiverCur, rate: waiverPrice, total: waiverPrice));
    }
    if (ics2App && ics2Price > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'ICS2 Filing Fee', unit: 'Per Filing', quantity: 1, currency: ics2Cur, rate: ics2Price, total: ics2Price));
    }
    if (otherFeesApp && otherFeesPrice > 0) {
      newCharges.add(BookingChargeModel(chargeType: 'Other Fees', unit: 'Per Shipment', quantity: 1, currency: otherFeesCur, rate: otherFeesPrice, total: otherFeesPrice));
    }

    String? mismatchError;
    if (has40ftMismatch && has20ftMismatch) {
      mismatchError = 'The allocated equipment does not match the quoted container sizes (quoted 40ft and 20ft, but matching containers are missing). Please adjust equipment or re-apply quote.';
    } else if (has40ftMismatch) {
      mismatchError = 'The allocated equipment does not match the quoted container sizes (quoted 40ft, but no 40ft/45ft container is allocated). Please adjust equipment or re-apply quote.';
    } else if (has20ftMismatch) {
      mismatchError = 'The allocated equipment does not match the quoted container sizes (quoted 20ft, but no 20ft container is allocated). Please adjust equipment or re-apply quote.';
    }

    return BookingChargeBuildResult(
      charges: newCharges,
      mismatchError: mismatchError,
      has40ftMismatch: has40ftMismatch,
      has20ftMismatch: has20ftMismatch,
    );
  }
}
