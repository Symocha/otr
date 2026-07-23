import 'package:flutter_test/flutter_test.dart';
import 'package:off_the_record/net/hotspot_settings.dart';

void main() {
  group('buildWifiQrPayload', () {
    test('builds a standard WPA payload', () {
      expect(
        buildWifiQrPayload(ssid: 'PartyPhone', password: 'letmein123'),
        'WIFI:S:PartyPhone;T:WPA;P:letmein123;;',
      );
    });

    test('omits the password field for an open network', () {
      expect(
        buildWifiQrPayload(ssid: 'PartyPhone', password: ''),
        'WIFI:S:PartyPhone;T:nopass;;',
      );
    });

    test('marks hidden networks', () {
      final payload = buildWifiQrPayload(
        ssid: 'PartyPhone',
        password: 'pw',
        hidden: true,
      );
      expect(payload, 'WIFI:S:PartyPhone;T:WPA;P:pw;H:true;;');
    });

    test('escapes reserved characters in the password', () {
      // A raw ';' would terminate the field early and truncate the payload.
      final payload = buildWifiQrPayload(ssid: 'Net', password: r'a;b:c,d"e\f');
      expect(payload, r'WIFI:S:Net;T:WPA;P:a\;b\:c\,d\"e\\f;;');
    });

    test('escapes reserved characters in the SSID', () {
      expect(
        buildWifiQrPayload(ssid: 'My;Phone', password: 'pw'),
        r'WIFI:S:My\;Phone;T:WPA;P:pw;;',
      );
    });

    test('leaves ordinary spaces and unicode untouched', () {
      expect(
        buildWifiQrPayload(ssid: "Otran's iPhone", password: 'pâté 123'),
        "WIFI:S:Otran's iPhone;T:WPA;P:pâté 123;;",
      );
    });
  });

  group('HotspotSettings', () {
    test('is unconfigured until an SSID is set', () {
      final settings = HotspotSettings();
      expect(settings.isConfigured, isFalse);
      expect(settings.wifiQrPayload, isNull);
    });
  });
}
