import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';

String _resolve({
  String define = '',
  String custom = '',
  bool isWeb = false,
  String host = '',
}) =>
    ApiConstants.resolveServerUrl(
      compileTimeUrl: define,
      customUrl: custom,
      isWeb: isWeb,
      webHost: host,
    );

void main() {
  group('ApiConstants.resolveServerUrl', () {
    test('no override resolves to the default production URL', () {
      expect(_resolve(), 'http://127.0.0.1:28080');
    });

    test('custom URL only is used', () {
      expect(_resolve(custom: 'http://10.0.0.5:9000'), 'http://10.0.0.5:9000');
    });

    test('dart-define beats saved custom URL', () {
      expect(
        _resolve(define: 'http://127.0.0.1:28090', custom: 'http://10.0.0.5:9000'),
        'http://127.0.0.1:28090',
      );
    });

    test('trailing slash is stripped', () {
      expect(_resolve(define: 'http://127.0.0.1:28090/'), 'http://127.0.0.1:28090');
      expect(_resolve(custom: 'http://10.0.0.5:9000/'), 'http://10.0.0.5:9000');
    });

    test('whitespace-only override is ignored', () {
      expect(_resolve(define: '   ', custom: 'http://10.0.0.5:9000'), 'http://10.0.0.5:9000');
      expect(_resolve(define: '  '), 'http://127.0.0.1:28080');
    });

    test('web default uses the page host', () {
      expect(_resolve(isWeb: true, host: 'erp.local'), 'http://erp.local:28080');
      expect(_resolve(isWeb: true), 'http://127.0.0.1:28080');
    });
  });

  group('ApiConstants.portOf', () {
    test('explicit override port', () {
      expect(ApiConstants.portOf('http://127.0.0.1:28090'), 28090);
    });

    test('URL without port or unparsable falls back to 28080', () {
      expect(ApiConstants.portOf('http://example.com'), 28080);
      expect(ApiConstants.portOf('http://[bad'), 28080);
    });
  });

  test('setCustomServerUrl trims and strips one trailing slash', () {
    addTearDown(() => ApiConstants.setCustomServerUrl(''));
    ApiConstants.setCustomServerUrl('  http://10.0.0.5:9000/ ');
    expect(ApiConstants.customServerUrl, 'http://10.0.0.5:9000');
  });
}
