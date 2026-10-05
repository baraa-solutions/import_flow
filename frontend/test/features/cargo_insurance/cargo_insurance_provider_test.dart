import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/cargo_insurance/providers/cargo_insurance_provider.dart';

Map<String, dynamic> _cert(int id) => {
      'certificate_id': id,
      'certificate_code': 'INS-2026-$id',
      'insured_entity_name': 'E',
      'port_of_loading': 'A',
      'port_of_discharge': 'B',
    };

class _Adapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> calls = [];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    calls.add(Map<String, dynamic>.from(o.queryParameters));
    final skip = o.queryParameters['skip'] as int;
    final count = skip == 0 ? 50 : 10;
    final items = [for (var i = 0; i < count; i++) _cert(skip + i + 1)];
    return ResponseBody.fromString(
      '{"total":60,"items":${_json(items)}}', 200,
      headers: {Headers.contentTypeHeader: ['application/json']});
  }
  String _json(List<Map<String, dynamic>> l) =>
      '[${l.map((m) => '{"certificate_id":${m['certificate_id']},"certificate_code":"${m['certificate_code']}","insured_entity_name":"E","port_of_loading":"A","port_of_discharge":"B"}').join(',')}]';
  @override
  void close({bool force = false}) {}
}

void main() {
  test('pages with skip/limit and appends using total', () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final n = CargoInsuranceNotifier(dio);
    for (var i = 0; i < 100 && n.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(n.state is AsyncError, isFalse, reason: "${n.state}");
    expect(n.state.value!.length, 50);
    expect(n.total, 60);
    expect(n.hasMore, isTrue);
    expect(adapter.calls.first['limit'], CargoInsuranceNotifier.pageSize);

    await n.loadMore();
    expect(n.state.value!.length, 60);
    expect(adapter.calls.last['skip'], 50);
    expect(n.hasMore, isFalse);
  });
}
