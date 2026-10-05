import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/cargo_shipping/models/cargo_shipping_model.dart';

void main() {
  test('edit payload never carries status or owner', () {
    final p = buildCargoShippingPayload(
      importFileId: 1, shipmentType: 'FCL', containers: const [], isEdit: true);
    expect(p.containsKey('status'), isFalse);
    expect(p.containsKey('owner'), isFalse);
  });

  test('create payload sends initial status only, still no owner', () {
    final p = buildCargoShippingPayload(
      importFileId: 1, shipmentType: 'FCL', containers: const [], isEdit: false);
    expect(p['status'], 'Cargo Ready');
    expect(p.containsKey('owner'), isFalse);
    expect(p['lcl_tracking_data'], isNull);
  });
}
