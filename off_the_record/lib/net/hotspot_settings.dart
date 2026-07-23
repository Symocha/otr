import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Builds the standard Wi-Fi network QR payload that stock Android/iOS
/// cameras parse natively to join a network (OffTheRecord_HANDOFF.md §4b).
///
/// Format: `WIFI:S:<ssid>;T:<auth>;P:<password>;;`
///
/// Modern Android blocks apps from reading their own hotspot credentials, so
/// the host types them once and they are persisted by [HotspotSettings].
String buildWifiQrPayload({
  required String ssid,
  required String password,
  bool hidden = false,
}) {
  // Open networks use an empty auth type and carry no password field.
  final auth = password.isEmpty ? 'nopass' : 'WPA';
  final buffer = StringBuffer('WIFI:S:${_escapeWifiValue(ssid)};T:$auth;');
  if (password.isNotEmpty) {
    buffer.write('P:${_escapeWifiValue(password)};');
  }
  if (hidden) buffer.write('H:true;');
  buffer.write(';');
  return buffer.toString();
}

/// The Wi-Fi QR spec reserves `\ ; , : "` — each must be backslash-escaped, or
/// a password containing one silently truncates the payload at that character.
String _escapeWifiValue(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (char == r'\' || char == ';' || char == ',' || char == ':' || char == '"') {
      buffer.write(r'\');
    }
    buffer.write(char);
  }
  return buffer.toString();
}

/// App-wide instance; loaded once from secure storage when a host lobby opens.
final hotspotSettings = HotspotSettings();

/// Host's Android hotspot credentials, remembered between games.
///
/// Stored in `flutter_secure_storage` rather than Hive because the passphrase
/// is a real credential.
class HotspotSettings extends ChangeNotifier {
  static const _ssidKey = 'hotspot_ssid';
  static const _passwordKey = 'hotspot_password';

  final FlutterSecureStorage _storage;

  HotspotSettings({FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;

  String ssid = '';
  String password = '';
  bool isLoaded = false;

  bool get isConfigured => ssid.isNotEmpty;

  /// The Wi-Fi join QR, or null when the host hasn't entered credentials yet.
  String? get wifiQrPayload =>
      isConfigured ? buildWifiQrPayload(ssid: ssid, password: password) : null;

  Future<void> load() async {
    ssid = await _storage.read(key: _ssidKey) ?? '';
    password = await _storage.read(key: _passwordKey) ?? '';
    isLoaded = true;
    notifyListeners();
  }

  Future<void> save({required String ssid, required String password}) async {
    this.ssid = ssid;
    this.password = password;
    await _storage.write(key: _ssidKey, value: ssid);
    await _storage.write(key: _passwordKey, value: password);
    notifyListeners();
  }

  Future<void> clear() async {
    ssid = '';
    password = '';
    await _storage.delete(key: _ssidKey);
    await _storage.delete(key: _passwordKey);
    notifyListeners();
  }
}
